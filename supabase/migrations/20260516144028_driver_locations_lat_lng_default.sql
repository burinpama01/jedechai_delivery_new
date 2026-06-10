
-- Add DEFAULT 0 so heartbeat-only UPSERTs won't fail NOT NULL constraint
ALTER TABLE public.driver_locations
  ALTER COLUMN location_lat SET DEFAULT 0,
  ALTER COLUMN location_lng SET DEFAULT 0;
;
