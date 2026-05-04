-- ============================================================
-- Sprint 2.2: Proximity Filter — Nearby Bookings RPC
-- ============================================================
-- Replaces client-side Haversine filtering in
-- driver_dashboard_screen.dart with a Postgres function.
-- Previously: Flutter fetched all bookings → filtered by radius.
-- Now: DB returns only bookings within p_radius_km of driver.
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_nearby_bookings(
  p_driver_lat double precision,
  p_driver_lng double precision,
  p_radius_km double precision DEFAULT 5.0,
  p_service_types text[] DEFAULT NULL
)
RETURNS SETOF public.bookings
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
BEGIN
  RETURN QUERY
  SELECT b.*
  FROM public.bookings b
  WHERE b.status IN ('pending', 'ready_for_pickup')
    AND b.driver_id IS NULL
    AND (p_service_types IS NULL OR b.service_type = ANY(p_service_types))
    AND b.origin_lat IS NOT NULL
    AND b.origin_lng IS NOT NULL
    AND (
      6371.0 * acos(
        LEAST(1.0,
          cos(radians(p_driver_lat)) * cos(radians(b.origin_lat))
          * cos(radians(b.origin_lng) - radians(p_driver_lng))
          + sin(radians(p_driver_lat)) * sin(radians(b.origin_lat))
        )
      )
    ) <= p_radius_km
  ORDER BY b.created_at DESC;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_nearby_bookings TO authenticated, service_role;
