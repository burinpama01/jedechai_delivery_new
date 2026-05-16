-- ISSUE-042: Add last_heartbeat_at column to driver_locations
-- Driver app upserts this every 60 s while online.
-- A pg_cron job runs every 2 minutes and marks stale drivers offline.

ALTER TABLE public.driver_locations
  ADD COLUMN IF NOT EXISTS last_heartbeat_at timestamptz DEFAULT now();

-- Auto-offline stale drivers: heartbeat not updated in last 2 minutes
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
