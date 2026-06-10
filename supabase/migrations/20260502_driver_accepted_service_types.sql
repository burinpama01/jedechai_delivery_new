-- Sprint 3.5: Driver service type preference
-- Adds accepted_service_types column to profiles
-- Updates get_nearby_drivers to filter by service type
-- Adds RLS policy for drivers to update their own service types

-- 1. Add column to profiles (backward compatible: NULL = accept all types)
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS accepted_service_types text[] DEFAULT NULL;
-- 2. Update get_nearby_drivers to support service_type filtering
--    Drop old 4-param version first (different signature = different overload)
DROP FUNCTION IF EXISTS public.get_nearby_drivers(double precision, double precision, double precision, integer);
CREATE OR REPLACE FUNCTION public.get_nearby_drivers(
  p_lat double precision,
  p_lng double precision,
  p_radius_km double precision DEFAULT 10.0,
  p_service_type text DEFAULT NULL,
  p_limit integer DEFAULT 50
)
RETURNS TABLE (
  driver_id uuid,
  full_name text,
  phone_number text,
  license_plate text,
  vehicle_type text,
  latitude double precision,
  longitude double precision,
  distance_km double precision,
  fcm_token text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    dl.driver_id,
    p.full_name,
    p.phone_number,
    p.license_plate,
    p.vehicle_type,
    dl.location_lat AS latitude,
    dl.location_lng AS longitude,
    (6371.0 * acos(
      LEAST(1.0,
        cos(radians(p_lat)) * cos(radians(dl.location_lat))
        * cos(radians(dl.location_lng) - radians(p_lng))
        + sin(radians(p_lat)) * sin(radians(dl.location_lat))
      )
    )) AS distance_km,
    p.fcm_token
  FROM public.driver_locations dl
  JOIN public.profiles p ON p.id = dl.driver_id
  WHERE dl.is_online = true
    AND dl.is_available = true
    AND p.role = 'driver'
    AND p.approval_status = 'approved'
    AND (
      p.accepted_service_types IS NULL
      OR p_service_type IS NULL
      OR p_service_type = ANY(p.accepted_service_types)
    )
    AND dl.location_lat IS NOT NULL
    AND dl.location_lng IS NOT NULL
    AND (6371.0 * acos(
      LEAST(1.0,
        cos(radians(p_lat)) * cos(radians(dl.location_lat))
        * cos(radians(dl.location_lng) - radians(p_lng))
        + sin(radians(p_lat)) * sin(radians(dl.location_lat))
      )
    )) <= p_radius_km
  ORDER BY distance_km ASC
  LIMIT p_limit;
$$;
-- 3. RLS: drivers can update their own accepted_service_types
--    (only if update policy doesn't already exist)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE tablename = 'profiles'
      AND policyname = 'driver_update_own_service_types'
  ) THEN
    EXECUTE $policy$
      CREATE POLICY "driver_update_own_service_types" ON public.profiles
      FOR UPDATE TO authenticated
      USING (id = auth.uid() AND role = 'driver')
      WITH CHECK (id = auth.uid())
    $policy$;
  END IF;
END;
$$;
-- 4. Grant
GRANT EXECUTE ON FUNCTION public.get_nearby_drivers TO authenticated, service_role;
