-- ═══════════════════════════════════════════════════════════════
-- ฝากซื้อ/ฝากหิ้ว — S8: เส้นทางแตก + คิวแอดมิน + แจ้งเตือน + รายงานคนขับ
-- อ้างอิง: Plan/Shop_Errand_S8_S9_Plan_v1.html
--
-- 1) หาคนขับไม่ได้   -> cron ยกเลิก + คืน hold เต็มจำนวนเมื่อเกิน shop_match_timeout_min
-- 2) เกินวงเงิน       -> คนขับขอเพิ่ม (server คำนวณยอดที่ขาด) -> ลูกค้าอนุมัติ/ปฏิเสธ
-- 3) ลูกค้าไม่ยืนยันรูป -> cron ยกธงให้แอดมินเมื่อเกิน shop_photo_escalate_min (ไม่มี auto-confirm)
-- 4) แจ้งเตือน         -> trigger สถานะออเดอร์ (ในแอป) + ธงตรวจสอบ (แอดมิน)
-- 5) แอดมิน           -> ปิดธงตรวจสอบ + รายงานคนขับ + ตั้ง trusted (บันทึกผู้ตั้ง)
--
-- หลักการเดิมยังอยู่ครบ: เงินคำนวณที่ server จาก fee_config_snapshot,
-- การเคลื่อนเงินทุกครั้งอยู่ใน transaction เดียวและลง ledger
-- ═══════════════════════════════════════════════════════════════

BEGIN;

-- ─────────────────────────────────────────────────────────────
-- 0) คอลัมน์ใหม่
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.shop_orders
  ADD COLUMN IF NOT EXISTS budget_increase_amount       numeric(12,2),
  ADD COLUMN IF NOT EXISTS budget_increase_status       text,
  ADD COLUMN IF NOT EXISTS budget_increase_requested_at timestamptz,
  ADD COLUMN IF NOT EXISTS budget_increase_responded_at timestamptz,
  ADD COLUMN IF NOT EXISTS review_escalated_at          timestamptz,
  ADD COLUMN IF NOT EXISTS admin_reviewed_at            timestamptz,
  ADD COLUMN IF NOT EXISTS admin_reviewed_by            uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS admin_review_note            text;

DO $$
BEGIN
  ALTER TABLE public.shop_orders
    ADD CONSTRAINT shop_orders_budget_increase_status_check
    CHECK (budget_increase_status IS NULL
           OR budget_increase_status IN ('requested', 'approved', 'declined'));
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ─────────────────────────────────────────────────────────────
-- 1) เกินวงเงิน: คนขับขอเพิ่ม
--
-- ยอดที่ขาดคำนวณที่ server จากรายการที่ติ๊ก "ซื้อแล้ว/ทดแทน" + ค่าธรรมเนียมจาก snapshot
-- (สูตรเดียวกับ shop_mark_purchased) แอปส่งมาแค่ booking_id
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.shop_request_budget_increase(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid       uuid := auth.uid();
  v_booking   public.bookings%ROWTYPE;
  v_order     public.shop_orders%ROWTYPE;
  v_goods     numeric;
  v_fees      jsonb;
  v_total     numeric;
  v_extra     numeric;
  v_new_cap   numeric;
  v_snap      jsonb;
  v_trusted   boolean;
  v_done_jobs int;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND OR v_booking.service_type <> 'shop' THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;
  IF v_booking.driver_id IS DISTINCT FROM v_uid THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_your_job');
  END IF;
  IF v_booking.status <> 'shopping' THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_status',
      'current_status', v_booking.status);
  END IF;

  SELECT * INTO v_order FROM public.shop_orders WHERE booking_id = p_booking_id FOR UPDATE;
  v_snap := v_order.fee_config_snapshot;

  SELECT COALESCE(SUM(actual_price) FILTER (WHERE status IN ('bought','substituted')), 0)
    INTO v_goods
  FROM public.shop_order_items WHERE shop_order_id = v_order.id;

  IF v_goods <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'nothing_bought');
  END IF;

  v_fees := public.shop_compute_fees(
    v_snap, v_goods, v_order.store_category,
    v_order.quoted_distance_km,
    COALESCE(v_order.actual_driver_km, v_order.quoted_driver_km),
    v_order.vehicle_type
  );
  v_total := ROUND(v_goods + (v_fees ->> 'total_fees')::numeric, 2);

  IF v_total <= v_order.hold_amount THEN
    RETURN jsonb_build_object('success', false, 'error', 'within_hold',
      'total_amount', v_total, 'hold_amount', v_order.hold_amount);
  END IF;

  -- ปัดขึ้นเป็นบาทเต็ม ลูกค้าอ่านง่าย และกันเศษสตางค์ทำให้ยังขาดอยู่นิดเดียว
  v_extra   := CEIL(v_total - v_order.hold_amount);
  v_new_cap := v_order.budget_cap + v_extra;

  IF v_new_cap > COALESCE((v_snap ->> 'max_budget')::numeric, 5000) THEN
    RETURN jsonb_build_object('success', false, 'error', 'exceeds_max_budget',
      'max_budget', (v_snap ->> 'max_budget')::numeric, 'extra', v_extra);
  END IF;

  -- เพดานคนขับใหม่ต้องยังมีผล — ไม่งั้นรับงาน 500฿ แล้วขอเพิ่มเป็น 3,000฿ ได้
  SELECT COALESCE(trusted, false) INTO v_trusted
  FROM public.shop_driver_flags WHERE driver_id = v_uid;

  IF NOT COALESCE(v_trusted, false) THEN
    SELECT COUNT(*) INTO v_done_jobs
    FROM public.bookings
    WHERE driver_id = v_uid AND service_type = 'shop' AND status = 'completed';

    IF v_done_jobs < COALESCE((v_snap ->> 'new_driver_jobs')::numeric, 20)
       AND v_new_cap > COALESCE((v_snap ->> 'new_driver_max_budget')::numeric, 500)
    THEN
      RETURN jsonb_build_object('success', false, 'error', 'new_driver_budget_limit',
        'max_budget', (v_snap ->> 'new_driver_max_budget')::numeric);
    END IF;
  END IF;

  -- กันกดซ้ำรัว ๆ แล้วแจ้งลูกค้าซ้ำ: คำขอเดิมยังรอตอบอยู่ รับคำขอใหม่เฉพาะเมื่อยอดที่ขาด
  -- "เพิ่มขึ้น" (คนขับหยิบของเพิ่ม) ไม่งั้นให้รอลูกค้าตอบคำขอเดิม
  IF v_order.budget_increase_status = 'requested'
     AND v_extra <= COALESCE(v_order.budget_increase_amount, 0) THEN
    RETURN jsonb_build_object('success', false, 'error', 'already_requested',
      'extra', v_order.budget_increase_amount);
  END IF;

  UPDATE public.shop_orders
     SET budget_increase_amount       = v_extra,
         budget_increase_status       = 'requested',
         budget_increase_requested_at = now(),
         budget_increase_responded_at = NULL
   WHERE id = v_order.id;

  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (
    v_booking.customer_id,
    'คนขับขอเพิ่มวงเงินฝากซื้อ',
    'ยอดสินค้าเกินวงเงินที่กันไว้ ต้องเพิ่มอีก ฿' || to_char(v_extra, 'FM999,999,990')
      || ' — เปิดออเดอร์เพื่ออนุมัติหรือปฏิเสธ',
    'shop.budget_increase_requested',
    jsonb_build_object('booking_id', p_booking_id, 'extra', v_extra)
  );

  RETURN jsonb_build_object('success', true, 'extra', v_extra,
    'total_amount', v_total, 'hold_amount', v_order.hold_amount);
END;
$$;

REVOKE ALL ON FUNCTION public.shop_request_budget_increase(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.shop_request_budget_increase(uuid) TO authenticated, service_role;

-- ─────────────────────────────────────────────────────────────
-- 2) เกินวงเงิน: ลูกค้าตอบ
--    อนุมัติ = กันเงินเพิ่มจาก Wallet เท่ากับยอดที่ server เก็บไว้ (ไม่รับยอดจากแอป)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.shop_customer_respond_budget_increase(
  p_booking_id uuid,
  p_approve    boolean
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid       uuid := auth.uid();
  v_booking   public.bookings%ROWTYPE;
  v_order     public.shop_orders%ROWTYPE;
  v_extra     numeric;
  v_wallet_id uuid;
  v_balance   numeric;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND OR v_booking.service_type <> 'shop' THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;
  IF v_booking.customer_id IS DISTINCT FROM v_uid THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_your_order');
  END IF;
  IF v_booking.status <> 'shopping' THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_status',
      'current_status', v_booking.status);
  END IF;

  SELECT * INTO v_order FROM public.shop_orders WHERE booking_id = p_booking_id FOR UPDATE;

  IF v_order.budget_increase_status IS DISTINCT FROM 'requested' THEN
    RETURN jsonb_build_object('success', false, 'error', 'no_pending_request');
  END IF;
  IF v_order.hold_released THEN
    RETURN jsonb_build_object('success', false, 'error', 'hold_already_released');
  END IF;

  IF NOT COALESCE(p_approve, false) THEN
    UPDATE public.shop_orders
       SET budget_increase_status = 'declined',
           budget_increase_responded_at = now()
     WHERE id = v_order.id;

    IF v_booking.driver_id IS NOT NULL THEN
      INSERT INTO public.notifications (user_id, title, body, type, data)
      VALUES (v_booking.driver_id, 'ลูกค้าไม่เพิ่มวงเงิน',
        'ตัดรายการให้อยู่ในวงเงินเดิม หรือติดต่อลูกค้า',
        'shop.budget_increase_declined', jsonb_build_object('booking_id', p_booking_id));
    END IF;

    RETURN jsonb_build_object('success', true, 'status', 'declined');
  END IF;

  v_extra := v_order.budget_increase_amount;
  IF v_extra IS NULL OR v_extra <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'no_pending_request');
  END IF;

  SELECT id, balance INTO v_wallet_id, v_balance
  FROM public.wallets WHERE user_id = v_uid FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'wallet_not_found');
  END IF;
  IF v_balance < v_extra THEN
    RETURN jsonb_build_object('success', false, 'error', 'insufficient_balance',
      'balance', ROUND(v_balance, 2), 'required', v_extra,
      'shortfall', ROUND(v_extra - v_balance, 2));
  END IF;

  UPDATE public.wallets SET balance = balance - v_extra, updated_at = now()
   WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (wallet_id, amount, type, description, related_booking_id)
  VALUES (v_wallet_id, -v_extra, 'hold',
    'กันวงเงินฝากซื้อเพิ่ม #' || LEFT(p_booking_id::text, 8), p_booking_id);

  -- hold รวมทุกก้อนอยู่ใน hold_amount -> ยกเลิก/ปิดงานคืนเงินจากยอดรวมถูกต้องอัตโนมัติ
  UPDATE public.shop_orders
     SET hold_amount = hold_amount + v_extra,
         budget_cap  = budget_cap + v_extra,
         budget_increase_status = 'approved',
         budget_increase_responded_at = now()
   WHERE id = v_order.id;

  UPDATE public.bookings SET price = price + v_extra, updated_at = now()
   WHERE id = p_booking_id;

  IF v_booking.driver_id IS NOT NULL THEN
    INSERT INTO public.notifications (user_id, title, body, type, data)
    VALUES (v_booking.driver_id, 'ลูกค้าเพิ่มวงเงินแล้ว',
      'วงเงินเพิ่มอีก ฿' || to_char(v_extra, 'FM999,999,990') || ' ยืนยันซื้อได้เลย',
      'shop.budget_increase_approved', jsonb_build_object('booking_id', p_booking_id));
  END IF;

  RETURN jsonb_build_object('success', true, 'status', 'approved',
    'extra', v_extra, 'hold_amount', v_order.hold_amount + v_extra);
END;
$$;

REVOKE ALL ON FUNCTION public.shop_customer_respond_budget_increase(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.shop_customer_respond_budget_increase(uuid, boolean)
  TO authenticated, service_role;

-- ─────────────────────────────────────────────────────────────
-- 3) หาคนขับไม่ได้ -> ยกเลิก + คืนเต็มจำนวน (เรียกจาก cron)
--    ไม่มีคนขับ = ไม่มีค่าปรับ ไม่มีค่าสินค้า -> คืน hold_amount ทั้งก้อน
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.shop_expire_unmatched(p_limit int DEFAULT 100)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_timeout numeric := public.shop_config_num('shop_match_timeout_min', 10);
  r         record;
  v_wallet  uuid;
  v_tx      uuid;
  v_count   int := 0;
BEGIN
  FOR r IN
    SELECT b.id AS booking_id, b.customer_id, o.id AS order_id, o.hold_amount
    FROM public.bookings b
    JOIN public.shop_orders o ON o.booking_id = b.id
    WHERE b.service_type = 'shop'
      AND b.status = 'pending'
      AND b.driver_id IS NULL
      AND o.hold_released = false
      AND b.created_at < now() - make_interval(mins => v_timeout::int)
    ORDER BY b.created_at
    LIMIT LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500)
    -- คนขับกดรับพร้อมกันพอดี -> ข้ามแถวนั้นไป รอบหน้าค่อยดู (สถานะจะไม่ใช่ pending แล้ว)
    FOR UPDATE OF b, o SKIP LOCKED
  LOOP
    SELECT id INTO v_wallet FROM public.wallets
     WHERE user_id = r.customer_id FOR UPDATE;
    IF v_wallet IS NULL THEN
      -- ไม่ควรเกิด (สร้างออเดอร์ต้องมี wallet) — ให้แอดมินดูแทนที่จะเงียบ
      UPDATE public.shop_orders
         SET needs_admin_review = true,
             admin_review_reason = COALESCE(admin_review_reason || ' | ', '') || 'expire_wallet_missing'
       WHERE id = r.order_id AND needs_admin_review = false;
      CONTINUE;
    END IF;

    UPDATE public.wallets SET balance = balance + r.hold_amount, updated_at = now()
     WHERE id = v_wallet;

    INSERT INTO public.wallet_transactions (wallet_id, amount, type, description, related_booking_id)
    VALUES (v_wallet, r.hold_amount, 'refund',
      'คืนเงินฝากซื้อ — หาคนขับไม่ได้ #' || LEFT(r.booking_id::text, 8), r.booking_id)
    RETURNING id INTO v_tx;

    UPDATE public.shop_orders
       SET cancel_fee = 0,
           refund_amount = r.hold_amount,
           refund_transaction_id = v_tx,
           hold_released = true
     WHERE id = r.order_id;

    UPDATE public.bookings
       SET status = 'cancelled',
           notes = COALESCE(notes || ' | ', '') || 'ยกเลิกอัตโนมัติ: หาคนขับไม่ได้',
           updated_at = now()
     WHERE id = r.booking_id;

    v_count := v_count + 1;
  END LOOP;

  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.shop_expire_unmatched(int) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.shop_expire_unmatched(int) TO service_role;

-- ─────────────────────────────────────────────────────────────
-- 4) ลูกค้าไม่ยืนยันรูปนานเกิน -> ยกธงให้แอดมิน (ครั้งเดียวต่อออเดอร์)
--    ไม่ auto-confirm ตามข้อกำหนดเดิม — แอดมินยืนยันแทนได้ผ่าน shop_customer_confirm_proof
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.shop_escalate_unconfirmed(p_limit int DEFAULT 100)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_minutes numeric := public.shop_config_num('shop_photo_escalate_min', 20);
  v_count   int;
BEGIN
  WITH due AS (
    SELECT o.id, b.customer_id, b.id AS booking_id
    FROM public.shop_orders o
    JOIN public.bookings b ON b.id = o.booking_id
    WHERE b.status = 'receipt_review'
      AND o.customer_confirmed_at IS NULL
      AND o.review_escalated_at IS NULL
      AND o.proof_sent_at < now() - make_interval(mins => v_minutes::int)
    ORDER BY o.proof_sent_at
    LIMIT LEAST(GREATEST(COALESCE(p_limit, 100), 1), 500)
    -- ล็อก bookings ด้วย: สถานะเปลี่ยนพร้อมกัน (ลูกค้ากดยืนยันพอดี) จะถูกข้าม ไม่ยกธงผิด
    FOR UPDATE OF o, b SKIP LOCKED
  ),
  flagged AS (
    UPDATE public.shop_orders o
       SET review_escalated_at = now(),
           needs_admin_review  = true,
           admin_review_reason = COALESCE(o.admin_review_reason || ' | ', '') || 'customer_no_confirm'
      FROM due
     WHERE o.id = due.id
    RETURNING due.customer_id, due.booking_id
  ),
  reminded AS (
    INSERT INTO public.notifications (user_id, title, body, type, data)
    SELECT customer_id, 'รอคุณยืนยันรูปสินค้าฝากซื้อ',
           'คนขับซื้อของแล้วและรอให้ยืนยันรูป — แอดมินจะช่วยติดต่อหากยังไม่ได้ยืนยัน',
           'shop.proof_reminder', jsonb_build_object('booking_id', booking_id)
    FROM flagged
    RETURNING 1
  )
  SELECT count(*) INTO v_count FROM flagged;

  RETURN v_count;
END;
$$;

REVOKE ALL ON FUNCTION public.shop_escalate_unconfirmed(int) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.shop_escalate_unconfirmed(int) TO service_role;

CREATE OR REPLACE FUNCTION public.shop_run_timeouts()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_expired   int;
  v_escalated int;
BEGIN
  -- แยกกันล้ม: งานหนึ่งพัง (เช่น lock timeout) อีกงานยังต้องทำในรอบนี้
  BEGIN
    v_expired := public.shop_expire_unmatched(100);
  EXCEPTION WHEN others THEN
    RAISE WARNING 'shop_expire_unmatched failed: %', SQLERRM;
    v_expired := -1;
  END;
  BEGIN
    v_escalated := public.shop_escalate_unconfirmed(100);
  EXCEPTION WHEN others THEN
    RAISE WARNING 'shop_escalate_unconfirmed failed: %', SQLERRM;
    v_escalated := -1;
  END;
  RETURN jsonb_build_object('expired', v_expired, 'escalated', v_escalated);
END;
$$;

REVOKE ALL ON FUNCTION public.shop_run_timeouts() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.shop_run_timeouts() TO service_role;

DO $$
DECLARE
  v_job_name constant text := 'shop-timeouts-every-minute';
  v_job_id   int;
BEGIN
  FOR v_job_id IN SELECT jobid FROM cron.job WHERE jobname = v_job_name LOOP
    PERFORM cron.unschedule(v_job_id);
  END LOOP;
  PERFORM cron.schedule(v_job_name, '* * * * *', 'select public.shop_run_timeouts();');
END $$;

-- ─────────────────────────────────────────────────────────────
-- 5) แจ้งเตือนตามสถานะ (ในแอป)
--    เป็น trigger จึงครอบทุกทาง: แอปลูกค้า แอปคนขับ แอดมิน และ cron
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trg_fn_shop_status_notify()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ref   text := LEFT(NEW.id::text, 8);
  v_title text;
  v_body  text;
BEGIN
  CASE NEW.status
    WHEN 'accepted' THEN
      v_title := 'คนขับรับงานฝากซื้อแล้ว';
      v_body  := 'คนขับกำลังไปที่ร้าน #' || v_ref;
    WHEN 'shopping' THEN
      v_title := 'คนขับถึงร้านแล้ว';
      v_body  := 'กำลังซื้อของตามรายการ #' || v_ref;
    WHEN 'receipt_review' THEN
      v_title := 'รอคุณยืนยันรูปสินค้า';
      v_body  := 'คนขับส่งรูปสินค้าแล้ว เปิดออเดอร์เพื่อยืนยัน #' || v_ref;
    WHEN 'purchased' THEN
      v_title := 'ซื้อของเรียบร้อยแล้ว';
      v_body  := 'คนขับกำลังเตรียมนำส่ง #' || v_ref;
    WHEN 'delivering', 'in_transit' THEN
      v_title := 'กำลังนำส่งของฝากซื้อ';
      v_body  := 'คนขับกำลังไปที่อยู่จัดส่ง #' || v_ref;
    WHEN 'completed' THEN
      v_title := 'ส่งของฝากซื้อสำเร็จ';
      v_body  := 'ส่วนต่างที่ไม่ได้ใช้คืนเข้า Wallet แล้ว #' || v_ref;
    WHEN 'cancelled' THEN
      v_title := 'ออเดอร์ฝากซื้อถูกยกเลิก';
      v_body  := CASE
        WHEN COALESCE(NEW.notes, '') LIKE '%หาคนขับไม่ได้%'
          THEN 'ไม่มีคนขับรับงานในเวลาที่กำหนด คืนเงินที่กันไว้เต็มจำนวนแล้ว #' || v_ref
        ELSE 'ดูยอดคืนเงินได้ที่หน้าออเดอร์ #' || v_ref
      END;
    ELSE
      RETURN NEW;
  END CASE;

  -- ไม่แจ้งคนที่เป็นคนกดเอง (เช่น ลูกค้ากดยกเลิกเอง) — cron/แอดมินไม่ใช่คู่กรณีจึงแจ้งเสมอ
  IF NEW.customer_id IS NOT NULL AND NEW.customer_id IS DISTINCT FROM auth.uid() THEN
    INSERT INTO public.notifications (user_id, title, body, type, data)
    VALUES (NEW.customer_id, v_title, v_body, 'shop.status',
      jsonb_build_object('booking_id', NEW.id, 'status', NEW.status));
  END IF;

  -- คนขับรู้เรื่องตัวเองอยู่แล้วแทบทุกสถานะ ยกเว้นถูกยกเลิกโดยคนอื่น
  IF NEW.status = 'cancelled' AND NEW.driver_id IS NOT NULL
     AND NEW.driver_id IS DISTINCT FROM auth.uid() THEN
    INSERT INTO public.notifications (user_id, title, body, type, data)
    VALUES (NEW.driver_id, 'งานฝากซื้อถูกยกเลิก',
      'ดูค่าชดเชย (ถ้ามี) ได้ที่ Wallet #' || v_ref, 'shop.status',
      jsonb_build_object('booking_id', NEW.id, 'status', NEW.status));
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_shop_status_notify ON public.bookings;
CREATE TRIGGER trg_shop_status_notify
  AFTER UPDATE OF status ON public.bookings
  FOR EACH ROW
  WHEN (NEW.service_type = 'shop' AND OLD.status IS DISTINCT FROM NEW.status)
  EXECUTE FUNCTION public.trg_fn_shop_status_notify();

-- ธงตรวจสอบขึ้น -> แจ้งแอดมิน (กระดิ่ง admin-web)
CREATE OR REPLACE FUNCTION public.trg_fn_shop_review_notify()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  PERFORM public.notify_admins(
    'ออเดอร์ฝากซื้อต้องตรวจสอบ',
    'ออเดอร์ #' || LEFT(NEW.booking_id::text, 8) || ' · '
      || COALESCE(NEW.admin_review_reason, '-'),
    'shop.needs_review',
    jsonb_build_object('booking_id', NEW.booking_id, 'reason', NEW.admin_review_reason)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_shop_review_notify ON public.shop_orders;
CREATE TRIGGER trg_shop_review_notify
  AFTER UPDATE OF needs_admin_review ON public.shop_orders
  FOR EACH ROW
  WHEN (NEW.needs_admin_review = true AND OLD.needs_admin_review = false)
  EXECUTE FUNCTION public.trg_fn_shop_review_notify();

-- ─────────────────────────────────────────────────────────────
-- 6) แอดมิน
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.shop_admin_resolve_review(
  p_booking_id uuid,
  p_note       text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL OR NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
  END IF;

  UPDATE public.shop_orders
     SET needs_admin_review = false,
         admin_reviewed_at  = now(),
         admin_reviewed_by  = v_uid,
         admin_review_note  = NULLIF(LEFT(btrim(COALESCE(p_note, '')), 500), '')
   WHERE booking_id = p_booking_id
     AND needs_admin_review = true;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'nothing_to_resolve');
  END IF;

  RETURN jsonb_build_object('success', true);
END;
$$;

REVOKE ALL ON FUNCTION public.shop_admin_resolve_review(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.shop_admin_resolve_review(uuid, text) TO authenticated, service_role;

-- ตั้ง/ถอน trusted พร้อมบันทึกผู้ตั้ง (แผน v4 หัวข้อ 7.2)
CREATE OR REPLACE FUNCTION public.shop_admin_set_trusted(
  p_driver_id uuid,
  p_trusted   boolean,
  p_note      text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
BEGIN
  IF v_uid IS NULL OR NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
  END IF;

  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_driver_id AND role = 'driver') THEN
    RETURN jsonb_build_object('success', false, 'error', 'driver_not_found');
  END IF;

  INSERT INTO public.shop_driver_flags (driver_id, trusted, note, set_by, set_at)
  VALUES (p_driver_id, COALESCE(p_trusted, false),
          NULLIF(LEFT(btrim(COALESCE(p_note, '')), 300), ''), v_uid, now())
  ON CONFLICT (driver_id) DO UPDATE
     SET trusted = EXCLUDED.trusted,
         note    = COALESCE(EXCLUDED.note, public.shop_driver_flags.note),
         set_by  = EXCLUDED.set_by,
         set_at  = EXCLUDED.set_at;

  RETURN jsonb_build_object('success', true, 'trusted', COALESCE(p_trusted, false));
END;
$$;

REVOKE ALL ON FUNCTION public.shop_admin_set_trusted(uuid, boolean, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.shop_admin_set_trusted(uuid, boolean, text) TO authenticated, service_role;

-- รายงานคนขับ: หาคนที่ถูกยกเลิกตอนซื้อของ (มีค่าปรับ) บ่อยผิดปกติ
-- กันการสมคบกดถึงร้านแล้วชวนลูกค้ายกเลิกเพื่อแบ่งค่าปรับ (แผน v4 หัวข้อ 6.2)
CREATE OR REPLACE FUNCTION public.shop_admin_driver_stats(p_days int DEFAULT 30)
RETURNS TABLE (
  driver_id              uuid,
  full_name              text,
  phone_number           text,
  trusted                boolean,
  total_jobs             bigint,
  completed_jobs         bigint,
  cancelled_jobs         bigint,
  cancelled_with_fee     bigint,
  cancel_fee_total       numeric,
  self_reported_arrivals bigint,
  fee_cancel_rate        numeric
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
#variable_conflict use_column
BEGIN
  IF auth.uid() IS NULL OR NOT public.is_admin() THEN
    RAISE EXCEPTION 'not_authorized';
  END IF;

  RETURN QUERY
  SELECT
    p.id,
    p.full_name,
    p.phone_number,
    COALESCE(f.trusted, false),
    COUNT(b.id),
    COUNT(b.id) FILTER (WHERE b.status = 'completed'),
    COUNT(b.id) FILTER (WHERE b.status = 'cancelled'),
    COUNT(b.id) FILTER (WHERE b.status = 'cancelled' AND COALESCE(o.cancel_fee, 0) > 0),
    COALESCE(SUM(o.cancel_fee) FILTER (WHERE b.status = 'cancelled'), 0),
    COUNT(b.id) FILTER (WHERE o.arrival_self_reported),
    CASE WHEN COUNT(b.id) = 0 THEN 0
         ELSE ROUND(100.0 * COUNT(b.id) FILTER (
                WHERE b.status = 'cancelled' AND COALESCE(o.cancel_fee, 0) > 0)
              / COUNT(b.id), 1)
    END
  FROM public.profiles p
  LEFT JOIN public.shop_driver_flags f ON f.driver_id = p.id
  LEFT JOIN public.bookings b
         ON b.driver_id = p.id
        AND b.service_type = 'shop'
        AND b.created_at >= now() - make_interval(days => GREATEST(COALESCE(p_days, 30), 1))
  LEFT JOIN public.shop_orders o ON o.booking_id = b.id
  WHERE p.role = 'driver'
  GROUP BY p.id, p.full_name, p.phone_number, f.trusted;
END;
$$;

REVOKE ALL ON FUNCTION public.shop_admin_driver_stats(int) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.shop_admin_driver_stats(int) TO authenticated, service_role;

COMMIT;
