-- ISSUE-051: Remove DEFAULT 0 from location_lat/lng.
-- Heartbeat now uses UPDATE (not UPSERT), so bare INSERT without lat/lng
-- no longer occurs. Dropping the default prevents future (0,0) ghost rows
-- if code accidentally tries a lat/lng-less INSERT.
ALTER TABLE public.driver_locations
  ALTER COLUMN location_lat DROP DEFAULT,
  ALTER COLUMN location_lng DROP DEFAULT;;
