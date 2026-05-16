-- Reviewer advisory: location_lat/lng are NOT NULL with no DEFAULT.
-- Heartbeat-only UPSERTs (which omit lat/lng) would fail on INSERT if row
-- doesn't exist yet. Set DEFAULT 0 as safe fallback.
ALTER TABLE public.driver_locations
  ALTER COLUMN location_lat SET DEFAULT 0,
  ALTER COLUMN location_lng SET DEFAULT 0;
