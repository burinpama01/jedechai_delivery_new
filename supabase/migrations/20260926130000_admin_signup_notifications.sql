-- แจ้งแอดมินเรื่องสมาชิกใหม่ (2026-09-26)
--
-- 1) ผู้สมัครคนขับ/ร้านค้า (trigger เดิม) — เพิ่ม data.admin_page ให้ notify-admin-events
--    แนบลิงก์เปิดหน้าอนุมัติใน Telegram/LINE/อีเมล
-- 2) สรุปสมาชิกใหม่รายวัน (รวมลูกค้า ซึ่งเดิมไม่มีแจ้งเลย) — pg_cron 20:00 น. (13:00 UTC)
--    ส่งผ่าน notify_admins เดิม → กระดิ่ง admin-web + คิว Telegram/LINE/อีเมล
--    กันส่งซ้ำ: วันละครั้งตามวันที่ไทย · ไม่มีสมาชิกใหม่เลย = ไม่ส่ง
--
-- Rollback: SELECT cron.unschedule('admin-daily-signup-summary');
--   DROP FUNCTION public.notify_admins_daily_signup_summary();
--   และคืน trg_fn_admin_event_applicant ตาม migration 20260718230000

-- ─── 1) applicant: แนบหน้าที่ต้องเปิด ─────────────────────────────────────
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
    jsonb_build_object(
      'profile_id', NEW.id,
      'role', NEW.role,
      'admin_page', CASE WHEN NEW.role = 'driver' THEN 'drivers' ELSE 'merchants' END)
  );
  RETURN NEW;
END;
$$;

-- ─── 2) สรุปสมาชิกใหม่รายวัน ──────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.notify_admins_daily_signup_summary()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_since timestamptz := now() - interval '24 hours';
  v_customers integer;
  v_drivers integer;
  v_merchants integer;
  v_pending_drivers integer;
  v_pending_merchants integer;
  v_body text;
BEGIN
  -- กันส่งซ้ำ: วันละครั้งตามวันที่ไทย (cron รันซ้ำ / เรียกมือ ไม่ทำให้ของวันถัดไปถูกข้าม)
  IF EXISTS (SELECT 1 FROM public.admin_event_external_queue
             WHERE event_type = 'admin.daily_signup_summary'
               AND (created_at AT TIME ZONE 'Asia/Bangkok')::date = (now() AT TIME ZONE 'Asia/Bangkok')::date) THEN
    RETURN jsonb_build_object('sent', false, 'reason', 'already_sent');
  END IF;

  SELECT count(*) FILTER (WHERE role = 'customer'),
         count(*) FILTER (WHERE role = 'driver'),
         count(*) FILTER (WHERE role = 'merchant')
    INTO v_customers, v_drivers, v_merchants
  FROM public.profiles
  WHERE created_at >= v_since;

  -- ค้างอนุมัติทั้งหมด (ไม่ใช่แค่ 24 ชม.) ให้แอดมินเห็นงานที่ต้องทำ
  SELECT count(*) FILTER (WHERE role = 'driver'),
         count(*) FILTER (WHERE role = 'merchant')
    INTO v_pending_drivers, v_pending_merchants
  FROM public.profiles
  WHERE approval_status = 'pending' AND role IN ('driver', 'merchant');

  IF v_customers + v_drivers + v_merchants = 0 THEN
    RETURN jsonb_build_object('sent', false, 'reason', 'no_signups');
  END IF;

  v_body := 'ลูกค้า ' || v_customers || ' · คนขับ ' || v_drivers || ' · ร้านค้า ' || v_merchants
         || ' (24 ชม.ล่าสุด)';
  IF v_pending_drivers + v_pending_merchants > 0 THEN
    v_body := v_body || E'\nรออนุมัติทั้งหมด: คนขับ ' || v_pending_drivers
           || ' · ร้านค้า ' || v_pending_merchants;
  END IF;

  PERFORM public.notify_admins(
    'สรุปสมาชิกใหม่วันนี้ 👥',
    v_body,
    'admin.daily_signup_summary',
    jsonb_build_object(
      'customers', v_customers, 'drivers', v_drivers, 'merchants', v_merchants,
      'pending_drivers', v_pending_drivers, 'pending_merchants', v_pending_merchants,
      'admin_page', CASE WHEN v_pending_drivers + v_pending_merchants > 0
                         THEN CASE WHEN v_pending_merchants > 0 THEN 'merchants' ELSE 'drivers' END
                         ELSE 'users' END));

  RETURN jsonb_build_object('sent', true, 'customers', v_customers,
                            'drivers', v_drivers, 'merchants', v_merchants);
END;
$$;

REVOKE ALL ON FUNCTION public.notify_admins_daily_signup_summary() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.notify_admins_daily_signup_summary() TO service_role;

-- 20:00 น. เวลาไทย = 13:00 UTC
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'admin-daily-signup-summary') THEN
    PERFORM cron.unschedule('admin-daily-signup-summary');
  END IF;
  PERFORM cron.schedule(
    'admin-daily-signup-summary',
    '0 13 * * *',
    'SELECT public.notify_admins_daily_signup_summary();');
END;
$$;
