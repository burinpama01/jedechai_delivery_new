
ALTER TABLE public.driver_locations
  ADD COLUMN IF NOT EXISTS last_heartbeat_at timestamptz DEFAULT now();

SELECT cron.schedule(
  'auto-offline-stale-drivers',
  '*/2 * * * *',
  $$
    UPDATE public.driver_locations
    SET is_online    = false,
        is_available = false
    WHERE is_online = true
      AND (
        last_heartbeat_at IS NULL
        OR last_heartbeat_at < now() - interval '2 minutes'
      );
  $$
);
;
