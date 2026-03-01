CREATE OR REPLACE FUNCTION public.get_nearby_drivers(
  p_lat double precision,
  p_lng double precision,
  p_radius_km double precision DEFAULT 10.0,
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
    p.id AS driver_id,
    p.full_name,
    p.phone_number,
    p.license_plate,
    p.vehicle_type,
    p.latitude,
    p.longitude,
    (6371 * acos(
      LEAST(1.0, cos(radians(p_lat)) * cos(radians(p.latitude))
        * cos(radians(p.longitude) - radians(p_lng))
        + sin(radians(p_lat)) * sin(radians(p.latitude)))
    )) AS distance_km,
    p.fcm_token
  FROM public.profiles p
  WHERE p.role = 'driver'
    AND p.approval_status = 'approved'
    AND p.is_online = true
    AND p.latitude IS NOT NULL
    AND p.longitude IS NOT NULL
    AND (6371 * acos(
      LEAST(1.0, cos(radians(p_lat)) * cos(radians(p.latitude))
        * cos(radians(p.longitude) - radians(p_lng))
        + sin(radians(p_lat)) * sin(radians(p.latitude)))
    )) <= p_radius_km
  ORDER BY distance_km ASC
  LIMIT p_limit;
$$;

GRANT EXECUTE ON FUNCTION public.get_nearby_drivers(double precision, double precision, double precision, integer) TO authenticated, service_role;
