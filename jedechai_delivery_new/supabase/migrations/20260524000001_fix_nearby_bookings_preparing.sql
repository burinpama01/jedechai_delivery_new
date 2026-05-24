-- Add 'preparing' to get_nearby_bookings so drivers can discover food jobs
-- while merchant is still preparing (driver can head over early)

CREATE OR REPLACE FUNCTION public.get_nearby_bookings(
  p_driver_lat   double precision,
  p_driver_lng   double precision,
  p_radius_km    double precision DEFAULT 20.0,
  p_service_types text[]          DEFAULT NULL
)
RETURNS SETOF public.bookings
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT *
  FROM public.bookings
  WHERE
    driver_id IS NULL
    AND status IN ('pending', 'preparing', 'ready_for_pickup', 'matched')
    AND origin_lat IS NOT NULL
    AND origin_lng IS NOT NULL
    AND (
      p_service_types IS NULL
      OR service_type = ANY(p_service_types)
    )
    AND (
      6371.0 * acos(
        LEAST(1.0,
          cos(radians(p_driver_lat)) * cos(radians(origin_lat)) *
          cos(radians(origin_lng) - radians(p_driver_lng)) +
          sin(radians(p_driver_lat)) * sin(radians(origin_lat))
        )
      )
    ) <= p_radius_km
  ORDER BY created_at DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_nearby_bookings TO authenticated;
