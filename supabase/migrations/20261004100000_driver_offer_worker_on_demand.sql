-- worker คิวเสนองานคนขับ: รันเฉพาะตอนมีงาน + ล้าง log ทุก 3 วัน
--
-- ปัญหา: cron process-driver-offers-every-10-seconds รัน 8,640 ครั้ง/วันแม้ไม่มีออเดอร์
-- ทุกรอบเขียน cron.job_run_details + pg_net request/response + ยิง edge function
-- -> กิน Disk IO budget ของ Free plan (nano) จน DB ไม่ตอบสนอง (ISSUE-20261004-001)
--
-- วิธีแก้:
--   * driver_offer_worker_has_work(): มีออเดอร์รอคนขับ / offer ที่ยังเปิด / แจ้งเตือนรอส่ง push
--   * call_process_driver_offers(): ไม่มีงาน -> ปิด cron job ตัวเอง (ไม่ยิง HTTP)
--   * trigger บน bookings/notifications ปลุก job กลับทันทีเมื่อมีงานเข้า
--   * watchdog ทุก 1 นาที (SQL ล้วน ไม่ยิง HTTP) — กันปลุกพลาด + งานตั้งเวลาล่วงหน้าถึงเวลา
--
-- กัน race "worker ปิด job ขณะที่ออเดอร์ใหม่ยังไม่ commit":
--   ผู้ปลุกถือ advisory lock แบบ shared (ไม่บล็อกกันเอง) จนจบ transaction
--   worker ที่เห็นว่าไม่มีงาน ขอ lock แบบ exclusive แล้วเช็คซ้ำ -> ต้องรอผู้ปลุกที่ค้างอยู่ commit ก่อน
--   แล้ว has_work (statement ใหม่ = snapshot ใหม่) จะเห็นแถวนั้น
--
-- ย้อนกลับ: DROP TRIGGER ทั้งสอง + cron.unschedule watchdog + cron.alter_job(<id>, active := true)
--           + CREATE OR REPLACE call_process_driver_offers จาก 20260926090300

BEGIN;

DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM cron.job WHERE jobname = 'process-driver-offers-every-10-seconds') THEN
    RAISE EXCEPTION 'cron job process-driver-offers-every-10-seconds not found';
  END IF;
END;
$$;

-- งานที่ worker ต้องทำ — เงื่อนไขเดียวกับ process_driver_offer_queue / claim_driver_offer_pushes /
-- claim_pending_notification_pushes (ขยายกรอบเวลาเล็กน้อยเพื่อไม่ปิดเร็วเกิน)
CREATE OR REPLACE FUNCTION public.driver_offer_worker_has_work()
RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER SET search_path = public AS $$
  SELECT EXISTS (
      SELECT 1 FROM public.bookings b
       WHERE b.driver_id IS NULL
         AND b.origin_lat IS NOT NULL AND b.origin_lng IS NOT NULL
         AND ((b.service_type IN ('ride','parcel','laundry') AND b.status = 'pending')
           OR (b.service_type = 'food' AND b.status IN ('preparing','ready_for_pickup')))
         AND (b.scheduled_at IS NULL OR b.scheduled_at <= now() + interval '2 minutes')
         -- ออเดอร์ค้างนาน (ไม่มีคนขับ) ไม่ปลุก worker ตลอดไป; trigger บน bookings ยัง dispatch ได้ตามเดิม
         AND COALESCE(b.scheduled_at, b.created_at) > now() - interval '3 hours')
    OR EXISTS (
      SELECT 1 FROM public.driver_job_offers o
       WHERE o.status = 'offered' AND o.expires_at > now() - interval '30 seconds')
    OR EXISTS (
      SELECT 1 FROM public.notifications n
       WHERE n.push_claimed_at IS NULL
         AND n.created_at > now() - interval '15 minutes'
         AND COALESCE(n.type, '') <> 'driver.job.offer'
         AND NOT EXISTS (SELECT 1 FROM public.notification_deliveries d
                          WHERE d.notification_id = n.id));
$$;

-- เปิด job ถ้าปิดอยู่ (shared lock: ผู้ปลุกหลายคนไม่บล็อกกัน แต่ worker ต้องรอ)
CREATE OR REPLACE FUNCTION public.wake_driver_offer_worker()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_jobid bigint;
BEGIN
  PERFORM pg_advisory_xact_lock_shared(20261004, 1);
  SELECT jobid INTO v_jobid FROM cron.job
   WHERE jobname = 'process-driver-offers-every-10-seconds' AND NOT active;
  IF v_jobid IS NOT NULL THEN
    PERFORM cron.alter_job(job_id := v_jobid, active := true);
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.call_process_driver_offers()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_url constant text := 'https://tfwhfkfgekkkgamhvttk.supabase.co';
  v_secret text;
  v_jobid bigint;
BEGIN
  -- ไม่มีงาน -> ขอ exclusive lock แล้วเช็คซ้ำ (lock ถือเฉพาะทางปิด job ซึ่งสั้นมาก
  -- ทางปกติที่มีงานไม่แตะ lock จึงไม่บล็อก trigger ปลุกบน bookings/notifications)
  IF NOT public.driver_offer_worker_has_work() THEN
    PERFORM pg_advisory_xact_lock(20261004, 1);
    IF public.driver_offer_worker_has_work() THEN
      -- มีงานเข้าระหว่างรอ lock: ปล่อยให้รอบถัดไป (10 วิ) ส่งงาน job ยัง active อยู่
      RETURN;
    END IF;
    SELECT jobid INTO v_jobid FROM cron.job
     WHERE jobname = 'process-driver-offers-every-10-seconds' AND active;
    IF v_jobid IS NOT NULL THEN
      PERFORM cron.alter_job(job_id := v_jobid, active := false);
    END IF;
    RETURN;
  END IF;

  SELECT decrypted_secret INTO v_secret FROM vault.decrypted_secrets
    WHERE name = 'jdc_driver_offer_cron_secret';
  IF NULLIF(v_secret, '') IS NULL THEN
    RAISE EXCEPTION 'driver offer cron secret is not configured';
  END IF;
  PERFORM net.http_post(
    url := rtrim(v_url, '/') || '/functions/v1/process-driver-offers',
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-cron-secret', v_secret),
    body := '{}'::jsonb
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.driver_offer_worker_watchdog()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF public.driver_offer_worker_has_work() THEN
    PERFORM public.wake_driver_offer_worker();
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.trg_wake_driver_offer_worker()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  PERFORM public.wake_driver_offer_worker();
  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS wake_driver_offer_worker_on_booking ON public.bookings;
CREATE TRIGGER wake_driver_offer_worker_on_booking
AFTER INSERT OR UPDATE OF status, driver_id, scheduled_at ON public.bookings
FOR EACH ROW
WHEN (NEW.driver_id IS NULL
  AND ((NEW.service_type IN ('ride','parcel','laundry') AND NEW.status = 'pending')
    OR (NEW.service_type = 'food' AND NEW.status IN ('preparing','ready_for_pickup'))))
EXECUTE FUNCTION public.trg_wake_driver_offer_worker();

DROP TRIGGER IF EXISTS wake_driver_offer_worker_on_notification ON public.notifications;
CREATE TRIGGER wake_driver_offer_worker_on_notification
AFTER INSERT ON public.notifications
FOR EACH ROW
WHEN (COALESCE(NEW.type, '') <> 'driver.job.offer')
EXECUTE FUNCTION public.trg_wake_driver_offer_worker();

-- ล้าง log ของ cron/pg_net ที่เก่ากว่า 3 วัน (รันทุก 3 วัน 03:00 เวลาไทย)
CREATE OR REPLACE FUNCTION public.purge_old_job_logs()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_rows integer; v_batches integer := 0;
BEGIN
  -- ลบทีละ 5,000 แถว สูงสุด 40 ชุด/รอบ (200k แถว) กัน IO พุ่ง; ที่เหลือไปรอบหน้า
  LOOP
    DELETE FROM cron.job_run_details
     WHERE runid IN (SELECT runid FROM cron.job_run_details
                      WHERE COALESCE(end_time, start_time) < now() - interval '3 days'
                      LIMIT 5000);
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    v_batches := v_batches + 1;
    EXIT WHEN v_rows = 0 OR v_batches >= 40;
    PERFORM pg_sleep(0.2);
  END LOOP;
  v_batches := 0;
  LOOP
    DELETE FROM net._http_response
     WHERE id IN (SELECT id FROM net._http_response
                   WHERE created < now() - interval '3 days'
                   LIMIT 5000);
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    v_batches := v_batches + 1;
    EXIT WHEN v_rows = 0 OR v_batches >= 40;
    PERFORM pg_sleep(0.2);
  END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.driver_offer_worker_has_work() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.wake_driver_offer_worker() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.call_process_driver_offers() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.driver_offer_worker_watchdog() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.trg_wake_driver_offer_worker() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.purge_old_job_logs() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.call_process_driver_offers() TO service_role;

SELECT cron.schedule('driver-offer-worker-watchdog', '* * * * *',
  'SELECT public.driver_offer_worker_watchdog();');
SELECT cron.schedule('purge-job-logs-every-3-days', '0 20 */3 * *',
  'SELECT public.purge_old_job_logs();');

COMMIT;
