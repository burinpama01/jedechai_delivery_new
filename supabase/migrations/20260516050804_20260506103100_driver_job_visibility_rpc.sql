DROP FUNCTION IF EXISTS public.get_driver_job_visibility_debug(
  uuid,
  double precision,
  double precision,
  double precision,
  text[]
);

CREATE OR REPLACE FUNCTION public.get_driver_job_visibility_debug(
  p_driver_id uuid,
  p_driver_lat double precision DEFAULT NULL,
  p_driver_lng double precision DEFAULT NULL,
  p_radius_km double precision DEFAULT 5.0,
  p_service_types text[] DEFAULT NULL,
  p_driver_online boolean DEFAULT true,
  p_job_vehicle_type text DEFAULT NULL,
  p_driver_vehicle_type text DEFAULT NULL
)
RETURNS TABLE (
  booking_id uuid,
  service_type text,
  status text,
  driver_id uuid,
  origin_lat double precision,
  origin_lng double precision,
  distance_km double precision,
  visible_to_driver boolean,
  hidden_reason text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  WITH candidate AS (
    SELECT
      b.id AS booking_id,
      b.service_type,
      b.status,
      b.driver_id,
      b.origin_lat,
      b.origin_lng,
      CASE
        WHEN p_driver_lat IS NULL
          OR p_driver_lng IS NULL
          OR b.origin_lat IS NULL
          OR b.origin_lng IS NULL
        THEN NULL
        ELSE (
          6371.0 * acos(
            LEAST(
              1.0,
              GREATEST(
                -1.0,
                cos(radians(p_driver_lat)) * cos(radians(b.origin_lat))
                * cos(radians(b.origin_lng) - radians(p_driver_lng))
                + sin(radians(p_driver_lat)) * sin(radians(b.origin_lat))
              )
            )
          )
        )
      END AS distance_km
    FROM public.bookings b
    WHERE b.status NOT IN ('completed', 'cancelled')
      AND (
        b.driver_id IS NULL
        OR b.driver_id = p_driver_id
      )
  )
  SELECT
    c.booking_id,
    c.service_type,
    c.status,
    c.driver_id,
    c.origin_lat,
    c.origin_lng,
    c.distance_km,
    CASE
      WHEN c.driver_id = p_driver_id THEN true
      WHEN c.driver_id IS NOT NULL THEN false
      WHEN NOT p_driver_online THEN false
      WHEN p_service_types IS NOT NULL AND NOT c.service_type = ANY(p_service_types)
        THEN false
      WHEN c.service_type IN ('ride', 'parcel') AND c.status <> 'pending'
        THEN false
      WHEN c.service_type = 'food' AND c.status <> 'ready_for_pickup'
        THEN false
      WHEN p_driver_lat IS NULL OR p_driver_lng IS NULL
        THEN false
      WHEN c.origin_lat IS NULL OR c.origin_lng IS NULL
        THEN false
      WHEN c.service_type = 'ride'
        AND NULLIF(trim(COALESCE(p_job_vehicle_type, '')), '') IS NOT NULL
        AND NULLIF(trim(COALESCE(p_driver_vehicle_type, '')), '') IS NOT NULL
        AND p_job_vehicle_type <> p_driver_vehicle_type
        THEN false
      WHEN c.distance_km > p_radius_km
        THEN false
      ELSE true
    END AS visible_to_driver,
    CASE
      WHEN c.driver_id = p_driver_id THEN NULL
      WHEN c.driver_id IS NOT NULL THEN 'alreadyAssignedToOtherDriver'
      WHEN NOT p_driver_online THEN 'driverOffline'
      WHEN p_service_types IS NOT NULL AND NOT c.service_type = ANY(p_service_types)
        THEN 'serviceTypeNotAccepted'
      WHEN c.service_type = 'food' AND c.status = 'pending_merchant'
        THEN 'waitingMerchantAccept'
      WHEN c.service_type = 'food' AND c.status = 'preparing'
        THEN 'merchantPreparing'
      WHEN c.service_type = 'food' AND c.status IN ('matched', 'driver_accepted', 'arrived_at_merchant')
        THEN 'waitingDriverArrival'
      WHEN c.service_type IN ('ride', 'parcel') AND c.status <> 'pending'
        THEN 'unsupportedStatus'
      WHEN c.service_type = 'food' AND c.status <> 'ready_for_pickup'
        THEN 'unsupportedStatus'
      WHEN p_driver_lat IS NULL OR p_driver_lng IS NULL
        THEN 'driverLocationMissing'
      WHEN c.origin_lat IS NULL OR c.origin_lng IS NULL
        THEN 'driverLocationMissing'
      WHEN c.service_type = 'ride'
        AND NULLIF(trim(COALESCE(p_job_vehicle_type, '')), '') IS NOT NULL
        AND NULLIF(trim(COALESCE(p_driver_vehicle_type, '')), '') IS NOT NULL
        AND p_job_vehicle_type <> p_driver_vehicle_type
        THEN 'vehicleTypeMismatch'
      WHEN c.distance_km > p_radius_km
        THEN 'outsideRadius'
      ELSE NULL
    END AS hidden_reason
  FROM candidate c
  ORDER BY c.booking_id DESC;
$$;

GRANT EXECUTE ON FUNCTION public.get_driver_job_visibility_debug(
  uuid,
  double precision,
  double precision,
  double precision,
  text[],
  boolean,
  text,
  text
) TO authenticated, service_role;;
