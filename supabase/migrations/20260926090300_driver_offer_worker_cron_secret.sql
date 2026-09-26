-- worker คิวเสนองานคนขับ: ยืนยันตัวด้วย x-cron-secret แทน service role key
--
-- 20260926090100 ส่ง Bearer <service key จาก Vault> แต่ worker เทียบกับ
-- SUPABASE_SERVICE_ROLE_KEY ของ runtime แบบตรงตัว และ runtime ไม่ได้ใช้ legacy JWT
-- ตัวที่ Dashboard แสดง -> 401 ทุกครั้ง; ใช้ secret เฉพาะของ cron แบบเดียวกับ
-- notify-admin-events แทน
--
-- ต้องมีก่อน apply:
--   * Edge secret  DRIVER_OFFER_CRON_SECRET  (supabase secrets set)
--   * Vault secret jdc_driver_offer_cron_secret  (ค่าเดียวกัน)
--   * deploy process-driver-offers เวอร์ชันที่อ่าน x-cron-secret
BEGIN;

-- ตรวจก่อนทำอะไร: ไม่มี secret = ไม่แตะ function เดิมเลย
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM vault.decrypted_secrets
      WHERE name = 'jdc_driver_offer_cron_secret'
        AND length(decrypted_secret) >= 32) THEN
    RAISE EXCEPTION 'driver offer cron secret is not configured';
  END IF;
END;
$$;

CREATE OR REPLACE FUNCTION public.call_process_driver_offers()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_url constant text := 'https://tfwhfkfgekkkgamhvttk.supabase.co';
  v_secret text;
BEGIN
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
REVOKE ALL ON FUNCTION public.call_process_driver_offers() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.call_process_driver_offers() TO service_role;

COMMIT;
