-- ISSUE-103: RPC ฝั่งเงินเปิดให้ `authenticated` โดยไม่เช็คตัวตน
-- ISSUE-109: หักค่าคอมซ้ำได้ เพราะ wallet_deduct ไม่มี idempotency
--
-- เดิม public.wallet_deduct(...) และ public.complete_booking(...) เป็น
-- SECURITY DEFINER + GRANT ให้ authenticated แต่ไม่เคยเทียบ auth.uid() กับ
-- p_user_id / p_driver_id เลย ผู้ใช้ที่ล็อกอินคนไหนก็ได้จึงเรียก RPC ตรงด้วย
-- anon key เพื่อหักเงินออกจาก wallet ของคนอื่น หรือปิดงานของคนขับคนอื่นได้
--
-- นอกจากนี้ wallet_deduct ไม่เคยเช็คว่าเคยหักค่าคอมของ booking นี้ไปแล้วหรือยัง
-- การเรียกซ้ำ (retry / กดซ้ำ / เส้นทางเก่า updateBookingStatus) จึงหักเงินซ้ำได้
--
-- หมายเหตุ: auth.uid() เป็น NULL เมื่อเรียกด้วย service_role (Edge Function /
-- admin-actions) การ์ดจึงข้ามให้กรณีนั้นเหมือนเดิม

-- ────────────────────────────────────────────────────────────
-- 1) wallet_deduct — เพิ่ม actor check + idempotency ของค่าคอม
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.wallet_deduct(
  p_user_id uuid,
  p_amount numeric,
  p_description text DEFAULT '',
  p_type text DEFAULT 'commission',
  p_related_booking_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid := auth.uid();
  v_wallet_id uuid;
  v_old_balance numeric;
  v_new_balance numeric;
  v_tx_id uuid;
  v_existing_tx_id uuid;
BEGIN
  -- ISSUE-103: ผู้ใช้ที่ล็อกอินหักได้เฉพาะกระเป๋าตัวเองเท่านั้น
  -- (service_role → auth.uid() IS NULL → ข้ามการ์ด)
  IF v_auth_uid IS NOT NULL AND v_auth_uid <> p_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  -- Lock the wallet row for update (prevents race conditions)
  SELECT id, balance INTO v_wallet_id, v_old_balance
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'wallet_not_found');
  END IF;

  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_amount');
  END IF;

  -- ISSUE-109: ค่าคอมของ booking หนึ่งหักได้ครั้งเดียว
  -- related_booking_id เป็น text จึงต้อง cast (ดู 20260610220000_*)
  IF p_related_booking_id IS NOT NULL AND p_type = 'commission' THEN
    SELECT id INTO v_existing_tx_id
    FROM public.wallet_transactions
    WHERE wallet_id = v_wallet_id
      AND type = 'commission'
      AND related_booking_id = p_related_booking_id::text
    LIMIT 1;

    IF v_existing_tx_id IS NOT NULL THEN
      RETURN jsonb_build_object(
        'success', true,
        'already_settled', true,
        'wallet_id', v_wallet_id,
        'old_balance', v_old_balance,
        'new_balance', v_old_balance,
        'transaction_id', v_existing_tx_id
      );
    END IF;
  END IF;

  v_new_balance := v_old_balance - p_amount;

  -- Allow negative balance (business decision: don't block completed orders)
  UPDATE public.wallets
  SET balance = v_new_balance, updated_at = now()
  WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (wallet_id, amount, type, description, related_booking_id)
  VALUES (v_wallet_id, -p_amount, p_type, p_description, p_related_booking_id)
  RETURNING id INTO v_tx_id;

  RETURN jsonb_build_object(
    'success', true,
    'wallet_id', v_wallet_id,
    'old_balance', v_old_balance,
    'new_balance', v_new_balance,
    'transaction_id', v_tx_id
  );
END;
$$;

-- ────────────────────────────────────────────────────────────
-- 2) complete_booking — เพิ่ม actor check + ผูกกับ driver ของงานจริง
--    (ยึดตามเวอร์ชันล่าสุดใน 20260630055943_storeos_connect_jdc_keys.sql)
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.complete_booking(
  p_booking_id uuid,
  p_driver_id uuid,
  p_commission_amount numeric DEFAULT 0,
  p_driver_earnings numeric DEFAULT 0,
  p_app_earnings numeric DEFAULT 0,
  p_description text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid := auth.uid();
  v_status text;
  v_booking_driver_id uuid;
  v_wallet_result jsonb;
BEGIN
  -- ISSUE-103: ปิดงานได้เฉพาะในนามตัวเอง (service_role ข้ามได้)
  IF v_auth_uid IS NOT NULL AND v_auth_uid <> p_driver_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  SELECT status, driver_id INTO v_status, v_booking_driver_id
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF v_status IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  -- ISSUE-103: p_driver_id ต้องเป็นคนขับของงานนี้จริง
  IF v_booking_driver_id IS DISTINCT FROM p_driver_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_booking_driver');
  END IF;

  IF v_status NOT IN ('in_transit', 'arrived', 'picking_up_order', 'driver_accepted', 'ready_for_pickup', 'arrived_at_merchant') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_status', 'current_status', v_status);
  END IF;

  IF p_commission_amount > 0 THEN
    v_wallet_result := public.wallet_deduct(
      p_driver_id, p_commission_amount,
      COALESCE(p_description, 'หักค่าบริการระบบ ออเดอร์ ' || LEFT(p_booking_id::text, 8)),
      'commission', p_booking_id
    );

    IF NOT (v_wallet_result->>'success')::boolean THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'settlement_failed',
        'wallet_error', v_wallet_result->>'error'
      );
    END IF;
  END IF;

  UPDATE public.bookings
  SET status = 'completed',
      status_origin = 'jdc',
      completed_at = now(),
      driver_earnings = p_driver_earnings,
      app_earnings = p_app_earnings,
      updated_at = now()
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'wallet', COALESCE(v_wallet_result, '{}'::jsonb)
  );
END;
$$;

-- ────────────────────────────────────────────────────────────
-- 3) Backstop ระดับ DB: ค่าคอมต่อ booking ต่อ wallet มีได้แถวเดียว
--    ถ้ามีข้อมูลซ้ำค้างอยู่ index จะสร้างไม่ได้ — แจ้งเตือนแทนการล้ม migration
--    แล้วให้แอดมินไปเคลียร์ซ้ำก่อนรันซ้ำอีกรอบ
-- ────────────────────────────────────────────────────────────
DO $$
BEGIN
  CREATE UNIQUE INDEX IF NOT EXISTS uniq_wallet_tx_commission_per_booking
    ON public.wallet_transactions (wallet_id, related_booking_id)
    WHERE type = 'commission' AND related_booking_id IS NOT NULL;
EXCEPTION WHEN unique_violation THEN
  RAISE WARNING 'uniq_wallet_tx_commission_per_booking not created: duplicate commission rows already exist. Clean them up, then re-run this migration.';
END
$$;

-- Grants เดิม (ประกาศซ้ำให้ชัดว่าใครเรียกได้)
REVOKE EXECUTE ON FUNCTION public.wallet_deduct(uuid, numeric, text, text, uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.wallet_deduct(uuid, numeric, text, text, uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.wallet_deduct(uuid, numeric, text, text, uuid) TO authenticated, service_role;

REVOKE EXECUTE ON FUNCTION public.complete_booking(uuid, uuid, numeric, numeric, numeric, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.complete_booking(uuid, uuid, numeric, numeric, numeric, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.complete_booking(uuid, uuid, numeric, numeric, numeric, text) TO authenticated, service_role;
