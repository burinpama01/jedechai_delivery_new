-- Notification coverage expansion (2026-07-18)
--
-- 1) trg_laundry_status_notify: ONE central AFTER UPDATE trigger on
--    laundry_orders.status that notifies customer/merchant for lifecycle
--    stages that today are silent (assigned/picked up/at merchant/washing/
--    ready for self-pickup/return legs/delivery completed). Statuses already
--    notified by their RPCs (quoted, quote_expired, outbound_pending via
--    accept, return_pending via create_return, self-pickup completed,
--    cancelled) are deliberately excluded to avoid duplicates. Because it is
--    a trigger it covers every path: merchant app, driver app, admin-web
--    act-on-behalf, and any future RPC.
--
-- 2) notify_admins(): in-app notifications to every profiles.role='admin'
--    + AFTER INSERT triggers for events admins currently learn about only by
--    opening the right page: new withdrawal requests, new top-up slips, new
--    support tickets, new driver/merchant applicants, new laundry quote
--    requests. (Rendered by the admin-web notification bell, 1.6.0.)
--
-- 3) notify_admins_stale_orders(): pure-SQL pg_cron watcher (every 5 min)
--    flagging bookings stuck >15 min without a driver and laundry quotes
--    ignored >15 min. Anti-spam via admin_stale_notified_at flag columns.
--
-- 4) Ensure notifications is in the supabase_realtime publication so the
--    admin-web bell updates live.

-- ─── 2a) notify_admins helper ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_admins(
  p_title text,
  p_body text,
  p_type text,
  p_data jsonb DEFAULT '{}'::jsonb
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer := 0;
BEGIN
  INSERT INTO public.notifications (user_id, title, body, type, data)
  SELECT p.id, p_title, p_body, p_type, COALESCE(p_data, '{}'::jsonb)
  FROM public.profiles p
  WHERE p.role = 'admin';
  GET DIAGNOSTICS v_count = ROW_COUNT;
  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.notify_admins(text, text, text, jsonb) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.notify_admins(text, text, text, jsonb) FROM anon;
REVOKE EXECUTE ON FUNCTION public.notify_admins(text, text, text, jsonb) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.notify_admins(text, text, text, jsonb) TO service_role;

-- ─── 1) laundry lifecycle notifications ─────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trg_fn_laundry_status_notify()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_short text := LEFT(NEW.id::text, 8);
  v_rows jsonb := '[]'::jsonb;
BEGIN
  IF OLD.status IS NOT DISTINCT FROM NEW.status THEN
    RETURN NEW;
  END IF;

  IF NEW.status = 'outbound_assigned' THEN
    INSERT INTO public.notifications (user_id, title, body, type, data) VALUES
      (NEW.customer_id, 'จับคู่คนขับแล้ว 🛵', 'คนขับรับงานไปรับผ้าของคุณแล้ว (คำขอ #' || v_short || ')',
       'laundry.outbound_assigned', jsonb_build_object('laundry_order_id', NEW.id));

  ELSIF NEW.status = 'outbound_picked_up' THEN
    INSERT INTO public.notifications (user_id, title, body, type, data) VALUES
      (NEW.customer_id, 'คนขับรับผ้าของคุณแล้ว', 'กำลังนำผ้าไปส่งที่ร้านซัก (คำขอ #' || v_short || ')',
       'laundry.outbound_picked_up', jsonb_build_object('laundry_order_id', NEW.id)),
      (NEW.merchant_id, 'ผ้ากำลังมาที่ร้าน 🧺', 'คนขับรับผ้าจากลูกค้าแล้ว กำลังนำมาส่งที่ร้าน (คำขอ #' || v_short || ')',
       'laundry.outbound_picked_up', jsonb_build_object('laundry_order_id', NEW.id));

  ELSIF NEW.status = 'at_merchant' THEN
    INSERT INTO public.notifications (user_id, title, body, type, data) VALUES
      (NEW.customer_id, 'ผ้าถึงร้านซักแล้ว', 'ผ้าของคุณถึงร้านเรียบร้อย รอร้านเริ่มซัก (คำขอ #' || v_short || ')',
       'laundry.at_merchant', jsonb_build_object('laundry_order_id', NEW.id)),
      (NEW.merchant_id, 'ผ้าถึงร้านแล้ว — เริ่มซักได้เลย', 'กดปุ่ม "เริ่มซัก" ในแอปเมื่อรับผ้าเข้าเครื่อง (คำขอ #' || v_short || ')',
       'laundry.at_merchant', jsonb_build_object('laundry_order_id', NEW.id));

  ELSIF NEW.status = 'washing' THEN
    INSERT INTO public.notifications (user_id, title, body, type, data) VALUES
      (NEW.customer_id, 'ร้านเริ่มซักผ้าแล้ว 🫧', 'คำขอ #' || v_short || ' กำลังซัก เดี๋ยวเสร็จแล้วแจ้งอีกครั้ง',
       'laundry.washing', jsonb_build_object('laundry_order_id', NEW.id));

  ELSIF NEW.status = 'ready_for_return' AND NEW.return_mode = 'self_pickup' THEN
    INSERT INTO public.notifications (user_id, title, body, type, data) VALUES
      (NEW.customer_id, 'ผ้าซักเสร็จแล้ว ✨', 'มารับผ้าได้ที่ร้านเลย (คำขอ #' || v_short || ')',
       'laundry.ready_self_pickup', jsonb_build_object('laundry_order_id', NEW.id));

  ELSIF NEW.status = 'return_assigned' THEN
    INSERT INTO public.notifications (user_id, title, body, type, data) VALUES
      (NEW.customer_id, 'จับคู่คนขับส่งผ้ากลับแล้ว 🛵', 'คนขับรับงานนำผ้ากลับไปส่งคุณแล้ว (คำขอ #' || v_short || ')',
       'laundry.return_assigned', jsonb_build_object('laundry_order_id', NEW.id));

  ELSIF NEW.status = 'return_picked_up' THEN
    INSERT INTO public.notifications (user_id, title, body, type, data) VALUES
      (NEW.customer_id, 'คนขับรับผ้าจากร้านแล้ว', 'ผ้าซักเสร็จกำลังเดินทางไปหาคุณ (คำขอ #' || v_short || ')',
       'laundry.return_picked_up', jsonb_build_object('laundry_order_id', NEW.id));

  ELSIF NEW.status = 'completed' AND NEW.return_mode = 'delivery' THEN
    -- self_pickup completed ถูกแจ้งโดย merchant_update_laundry_status แล้ว
    INSERT INTO public.notifications (user_id, title, body, type, data) VALUES
      (NEW.customer_id, 'ผ้าส่งถึงเรียบร้อย ✅', 'คำขอซักผ้า #' || v_short || ' เสร็จสมบูรณ์ ขอบคุณที่ใช้บริการ',
       'laundry.completed', jsonb_build_object('laundry_order_id', NEW.id)),
      (NEW.merchant_id, 'งานซักผ้าปิดเรียบร้อย', 'คำขอ #' || v_short || ' ส่งคืนลูกค้าแล้ว',
       'laundry.completed', jsonb_build_object('laundry_order_id', NEW.id));

  ELSIF NEW.status = 'quote_rejected' THEN
    INSERT INTO public.notifications (user_id, title, body, type, data) VALUES
      (NEW.merchant_id, 'ลูกค้าปฏิเสธใบเสนอราคา', 'คำขอซักผ้า #' || v_short || ' ถูกปฏิเสธโดยลูกค้า',
       'laundry.quote_rejected', jsonb_build_object('laundry_order_id', NEW.id));
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_laundry_status_notify ON public.laundry_orders;
CREATE TRIGGER trg_laundry_status_notify
AFTER UPDATE OF status ON public.laundry_orders
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_laundry_status_notify();

-- ─── 2b) admin event triggers ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.trg_fn_admin_event_withdrawal()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_name text;
BEGIN
  IF COALESCE(NEW.status, 'pending') <> 'pending' THEN RETURN NEW; END IF;
  SELECT full_name INTO v_name FROM public.profiles WHERE id = NEW.user_id;
  PERFORM public.notify_admins(
    'คำขอถอนเงินใหม่ 💸',
    '฿' || TO_CHAR(COALESCE(NEW.amount, 0), 'FM999,999,990') || ' จาก ' || COALESCE(v_name, 'ไม่ทราบชื่อ'),
    'admin.withdrawal_new',
    jsonb_build_object('withdrawal_id', NEW.id, 'user_id', NEW.user_id)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_admin_event_withdrawal ON public.withdrawal_requests;
CREATE TRIGGER trg_admin_event_withdrawal
AFTER INSERT ON public.withdrawal_requests
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_admin_event_withdrawal();

CREATE OR REPLACE FUNCTION public.trg_fn_admin_event_topup()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_name text;
BEGIN
  -- manual topup ของแอดมิน insert เป็น completed — ไม่ต้องแจ้งตัวเอง
  IF COALESCE(NEW.status, 'pending') <> 'pending' THEN RETURN NEW; END IF;
  SELECT full_name INTO v_name FROM public.profiles WHERE id = NEW.user_id;
  PERFORM public.notify_admins(
    'คำขอเติมเงินใหม่ 🧾',
    '฿' || TO_CHAR(COALESCE(NEW.amount, 0), 'FM999,999,990') || ' จาก ' || COALESCE(v_name, 'ไม่ทราบชื่อ') || ' รอตรวจสลิป',
    'admin.topup_new',
    jsonb_build_object('topup_id', NEW.id, 'user_id', NEW.user_id)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_admin_event_topup ON public.topup_requests;
CREATE TRIGGER trg_admin_event_topup
AFTER INSERT ON public.topup_requests
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_admin_event_topup();

CREATE OR REPLACE FUNCTION public.trg_fn_admin_event_ticket()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_name text;
BEGIN
  SELECT full_name INTO v_name FROM public.profiles WHERE id = NEW.user_id;
  PERFORM public.notify_admins(
    'เรื่องร้องเรียนใหม่ 📣',
    COALESCE(NULLIF(btrim(NEW.subject), ''), 'ไม่มีหัวข้อ') || ' — จาก ' || COALESCE(v_name, 'ไม่ทราบชื่อ'),
    'admin.ticket_new',
    jsonb_build_object('ticket_id', NEW.id, 'user_id', NEW.user_id)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_admin_event_ticket ON public.support_tickets;
CREATE TRIGGER trg_admin_event_ticket
AFTER INSERT ON public.support_tickets
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_admin_event_ticket();

CREATE OR REPLACE FUNCTION public.trg_fn_admin_event_applicant()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NEW.role NOT IN ('driver', 'merchant') THEN RETURN NEW; END IF;
  IF COALESCE(NEW.approval_status, '') <> 'pending' THEN RETURN NEW; END IF;
  IF TG_OP = 'UPDATE'
    AND OLD.approval_status IS NOT DISTINCT FROM NEW.approval_status
    AND OLD.role IS NOT DISTINCT FROM NEW.role THEN
    RETURN NEW;
  END IF;

  PERFORM public.notify_admins(
    CASE WHEN NEW.role = 'driver' THEN 'คนขับสมัครใหม่รออนุมัติ 🛵' ELSE 'ร้านค้าสมัครใหม่รออนุมัติ 🏪' END,
    COALESCE(NULLIF(btrim(NEW.full_name), ''), NEW.phone_number, LEFT(NEW.id::text, 8)) || ' รอการตรวจสอบเอกสาร',
    'admin.applicant_pending',
    jsonb_build_object('profile_id', NEW.id, 'role', NEW.role)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_admin_event_applicant_ins ON public.profiles;
CREATE TRIGGER trg_admin_event_applicant_ins
AFTER INSERT ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_admin_event_applicant();

DROP TRIGGER IF EXISTS trg_admin_event_applicant_upd ON public.profiles;
CREATE TRIGGER trg_admin_event_applicant_upd
AFTER UPDATE OF approval_status, role ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_admin_event_applicant();

CREATE OR REPLACE FUNCTION public.trg_fn_admin_event_laundry_quote()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_name text;
BEGIN
  SELECT full_name INTO v_name FROM public.profiles WHERE id = NEW.customer_id;
  PERFORM public.notify_admins(
    'คำขอซักผ้าใหม่ 🧺',
    'จาก ' || COALESCE(v_name, 'ไม่ทราบชื่อ') || ' รอร้านประเมินราคา (#' || LEFT(NEW.id::text, 8) || ')',
    'admin.laundry_quote_new',
    jsonb_build_object('laundry_order_id', NEW.id)
  );
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_admin_event_laundry_quote ON public.laundry_orders;
CREATE TRIGGER trg_admin_event_laundry_quote
AFTER INSERT ON public.laundry_orders
FOR EACH ROW
EXECUTE FUNCTION public.trg_fn_admin_event_laundry_quote();

-- ─── 3) stale-order watcher (pure SQL cron) ─────────────────────────────────
ALTER TABLE public.bookings
  ADD COLUMN IF NOT EXISTS admin_stale_notified_at timestamptz;
ALTER TABLE public.laundry_orders
  ADD COLUMN IF NOT EXISTS admin_stale_notified_at timestamptz;

CREATE OR REPLACE FUNCTION public.notify_admins_stale_orders()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking record;
  v_laundry record;
  v_booking_count integer := 0;
  v_laundry_count integer := 0;
BEGIN
  FOR v_booking IN
    SELECT b.id, b.service_type
    FROM public.bookings b
    WHERE b.status IN ('pending', 'pending_merchant')
      AND b.driver_id IS NULL
      AND b.admin_stale_notified_at IS NULL
      AND b.created_at < now() - interval '15 minutes'
      AND (b.scheduled_at IS NULL OR b.scheduled_at < now())
    ORDER BY b.created_at
    LIMIT 10
    FOR UPDATE SKIP LOCKED
  LOOP
    UPDATE public.bookings
    SET admin_stale_notified_at = now()
    WHERE id = v_booking.id;

    PERFORM public.notify_admins(
      'ออเดอร์ค้างเกิน 15 นาที ⏱',
      'ออเดอร์ ' || COALESCE(v_booking.service_type, '-') || ' #' || LEFT(v_booking.id::text, 8) || ' ยังไม่มีคนขับรับ — เข้าไปช่วยจัดการที่หน้าออเดอร์รอจัดการ',
      'admin.stale_order',
      jsonb_build_object('order_id', v_booking.id, 'service_type', v_booking.service_type)
    );
    v_booking_count := v_booking_count + 1;
  END LOOP;

  FOR v_laundry IN
    SELECT l.id
    FROM public.laundry_orders l
    WHERE l.status = 'quote_requested'
      AND l.admin_stale_notified_at IS NULL
      AND l.created_at < now() - interval '15 minutes'
    ORDER BY l.created_at
    LIMIT 10
    FOR UPDATE SKIP LOCKED
  LOOP
    UPDATE public.laundry_orders
    SET admin_stale_notified_at = now()
    WHERE id = v_laundry.id;

    PERFORM public.notify_admins(
      'คำขอซักผ้ารอร้านเกิน 15 นาที ⏱',
      'คำขอ #' || LEFT(v_laundry.id::text, 8) || ' ร้านยังไม่ส่ง quote — ส่งแทนร้านได้ที่หน้า Laundry',
      'admin.stale_laundry',
      jsonb_build_object('laundry_order_id', v_laundry.id)
    );
    v_laundry_count := v_laundry_count + 1;
  END LOOP;

  RETURN jsonb_build_object('stale_bookings', v_booking_count, 'stale_laundry', v_laundry_count);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.notify_admins_stale_orders() FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.notify_admins_stale_orders() FROM anon;
REVOKE EXECUTE ON FUNCTION public.notify_admins_stale_orders() FROM authenticated;
GRANT EXECUTE ON FUNCTION public.notify_admins_stale_orders() TO service_role;

DO $$
DECLARE
  v_job_id int;
BEGIN
  FOR v_job_id IN SELECT jobid FROM cron.job WHERE jobname = 'admin-stale-orders-watch' LOOP
    PERFORM cron.unschedule(v_job_id);
  END LOOP;
  PERFORM cron.schedule(
    'admin-stale-orders-watch',
    '*/5 * * * *',
    $cron$SELECT public.notify_admins_stale_orders();$cron$
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'cron schedule skipped: %', SQLERRM;
END
$$;

-- ─── 5) notifications read performance ──────────────────────────────────────
-- วัดจริง: SELECT ของ user เดียวใช้เวลา ~14s เพราะ policy เรียก auth.uid()
-- ต่อแถว (per-row STABLE call) — ห่อเป็น (SELECT auth.uid()) ให้ planner ทำ
-- initplan ครั้งเดียว (semantics เท่าเดิม) + เพิ่ม index รองรับ eq+order+limit
DROP POLICY IF EXISTS "Users can read own notifications" ON public.notifications;
CREATE POLICY "Users can read own notifications"
ON public.notifications
FOR SELECT
USING ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can insert own notifications" ON public.notifications;
CREATE POLICY "Users can insert own notifications"
ON public.notifications
FOR INSERT
WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can update own notifications" ON public.notifications;
CREATE POLICY "Users can update own notifications"
ON public.notifications
FOR UPDATE
USING ((SELECT auth.uid()) = user_id)
WITH CHECK ((SELECT auth.uid()) = user_id);

DROP POLICY IF EXISTS "Users can delete own notifications" ON public.notifications;
CREATE POLICY "Users can delete own notifications"
ON public.notifications
FOR DELETE
USING ((SELECT auth.uid()) = user_id);

CREATE INDEX IF NOT EXISTS idx_notifications_user_created
ON public.notifications (user_id, created_at DESC);

-- ─── 4) realtime for the admin-web bell ─────────────────────────────────────
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;
END
$$;
