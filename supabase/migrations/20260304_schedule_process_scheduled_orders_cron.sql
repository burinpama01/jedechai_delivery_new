-- ============================================
-- Schedule process-scheduled-orders Edge Function via pg_cron
-- ============================================
-- This migration is idempotent and safe to run multiple times.
-- It will:
-- 1) Ensure pg_net / pg_cron extensions exist
-- 2) Remove old job with same name (if exists)
-- 3) Schedule every-minute invocation to Edge Function

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

DO $$
DECLARE
  v_job_name constant text := 'process-scheduled-orders-every-minute';
  v_supabase_url text;
  v_service_role_key text;
  v_target_url text;
  v_existing_job_id integer;
BEGIN
  v_supabase_url := current_setting('app.settings.supabase_url', true);
  v_service_role_key := current_setting('app.settings.service_role_key', true);

  IF v_supabase_url IS NULL OR v_service_role_key IS NULL THEN
    RAISE NOTICE 'Skipping cron schedule: app.settings.supabase_url or app.settings.service_role_key not available';
    RETURN;
  END IF;

  v_target_url := rtrim(v_supabase_url, '/') || '/functions/v1/process-scheduled-orders';

  FOR v_existing_job_id IN
    SELECT jobid
    FROM cron.job
    WHERE jobname = v_job_name
  LOOP
    PERFORM cron.unschedule(v_existing_job_id);
  END LOOP;

  PERFORM cron.schedule(
    v_job_name,
    '* * * * *',
    format(
      $cron$
      select net.http_post(
        url := %L,
        headers := jsonb_build_object(
          'Content-Type', 'application/json',
          'Authorization', 'Bearer %s'
        ),
        body := '{}'::jsonb
      );
      $cron$,
      v_target_url,
      v_service_role_key
    )
  );
END
$$;
