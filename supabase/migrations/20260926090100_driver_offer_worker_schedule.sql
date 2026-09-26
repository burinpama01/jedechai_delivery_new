-- Apply only after process-driver-offers and send-fcm-notification are deployed.
-- The service key must be provisioned in Supabase Vault before this migration.
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION public.call_process_driver_offers()
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_url constant text := 'https://tfwhfkfgekkkgamhvttk.supabase.co';
  v_key text;
BEGIN
  SELECT decrypted_secret INTO v_key FROM vault.decrypted_secrets
    WHERE name = 'jdc_driver_offer_service_role_key';
  IF NULLIF(v_key, '') IS NULL THEN RAISE EXCEPTION 'driver offer worker key is not configured'; END IF;
  PERFORM net.http_post(
    url := rtrim(v_url, '/') || '/functions/v1/process-driver-offers',
    headers := jsonb_build_object('Content-Type','application/json','Authorization','Bearer ' || v_key),
    body := '{}'::jsonb
  );
END;
$$;
REVOKE ALL ON FUNCTION public.call_process_driver_offers() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.call_process_driver_offers() TO service_role;

DO $$
DECLARE
  v_key_exists boolean;
BEGIN
  SELECT EXISTS (SELECT 1 FROM vault.decrypted_secrets
    WHERE name = 'jdc_driver_offer_service_role_key' AND NULLIF(decrypted_secret, '') IS NOT NULL)
    INTO v_key_exists;
  IF NOT v_key_exists THEN RAISE EXCEPTION 'driver offer worker key is not configured'; END IF;
  PERFORM cron.schedule('process-driver-offers-every-10-seconds',
    '10 seconds', 'SELECT public.call_process_driver_offers();');
END;
$$;
