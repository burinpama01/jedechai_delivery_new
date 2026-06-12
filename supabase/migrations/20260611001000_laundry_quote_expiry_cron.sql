-- Auto-expire laundry quotes that pass quote_expires_at before a booking is created.

CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

CREATE OR REPLACE FUNCTION public.expire_laundry_quotes(p_limit integer DEFAULT 200)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_limit integer := LEAST(GREATEST(COALESCE(p_limit, 200), 1), 1000);
  v_expired_count integer := 0;
BEGIN
  WITH expired AS (
    SELECT id, customer_id, merchant_id
    FROM public.laundry_orders
    WHERE status = 'quoted'
      AND quote_expires_at IS NOT NULL
      AND quote_expires_at <= now()
      AND outbound_booking_id IS NULL
    ORDER BY quote_expires_at ASC
    LIMIT v_limit
    FOR UPDATE SKIP LOCKED
  ),
  updated AS (
    UPDATE public.laundry_orders lo
    SET status = 'quote_expired',
        updated_at = now()
    FROM expired e
    WHERE lo.id = e.id
    RETURNING lo.id, lo.customer_id, lo.merchant_id
  ),
  notified AS (
    INSERT INTO public.notifications (user_id, title, body, type, data)
    SELECT target.user_id,
           'Quote ซักผ้าหมดอายุ',
           'คำขอซักผ้า #' || left(target.id::text, 8) || ' หมดอายุแล้ว',
           'laundry.quote_expired',
           jsonb_build_object('laundry_order_id', target.id)
    FROM (
      SELECT id, customer_id AS user_id FROM updated
      UNION ALL
      SELECT id, merchant_id AS user_id FROM updated
    ) target
    WHERE target.user_id IS NOT NULL
    RETURNING 1
  )
  SELECT count(*) INTO v_expired_count FROM updated;

  RETURN v_expired_count;
END;
$$;

REVOKE ALL ON FUNCTION public.expire_laundry_quotes(integer) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.expire_laundry_quotes(integer) TO service_role;

DO $$
DECLARE
  v_job_name constant text := 'laundry-quote-expire-every-minute';
  v_existing_job_id integer;
BEGIN
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
    'select public.expire_laundry_quotes(200);'
  );
END
$$;
