CREATE OR REPLACE FUNCTION public.get_booking_driver_notification_debug(
  p_booking_id uuid,
  p_radius_km double precision DEFAULT 5.0
)
RETURNS TABLE (
  driver_id uuid,
  driver_name text,
  is_online boolean,
  is_available boolean,
  accepted_service_types text[],
  driver_vehicle_type text,
  distance_km double precision,
  has_fcm_token boolean,
  visible_to_driver boolean,
  hidden_reason text,
  notification_id uuid,
  delivery_status text,
  delivery_error text,
  delivery_created_at timestamptz
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_caller_role text;
BEGIN
  SELECT *
  INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id;

  IF NOT FOUND THEN
    RETURN;
  END IF;

  SELECT role
  INTO v_caller_role
  FROM public.profiles
  WHERE id = auth.uid();

  IF auth.role() <> 'service_role'
    AND COALESCE(v_caller_role, '') <> 'admin'
  THEN
    RAISE EXCEPTION 'admin role required'
      USING ERRCODE = '42501';
  END IF;

  RETURN QUERY
  WITH candidates AS (
    SELECT
      p.id AS driver_id,
      p.full_name AS driver_name,
      p.accepted_service_types,
      p.vehicle_type AS driver_vehicle_type,
      p.fcm_token,
      dl.is_online,
      dl.is_available,
      dl.location_lat,
      dl.location_lng,
      CASE
        WHEN dl.location_lat IS NULL
          OR dl.location_lng IS NULL
          OR v_booking.origin_lat IS NULL
          OR v_booking.origin_lng IS NULL
        THEN NULL
        ELSE (
          6371.0 * acos(
            LEAST(
              1.0,
              GREATEST(
                -1.0,
                cos(radians(dl.location_lat)) * cos(radians(v_booking.origin_lat))
                * cos(radians(v_booking.origin_lng) - radians(dl.location_lng))
                + sin(radians(dl.location_lat)) * sin(radians(v_booking.origin_lat))
              )
            )
          )
        )
      END AS radius_distance_km
    FROM public.profiles p
    LEFT JOIN public.driver_locations dl ON dl.driver_id = p.id
    WHERE p.role = 'driver'
      AND p.approval_status = 'approved'
  ),
  evaluated AS (
    SELECT
      c.*,
      CASE
        WHEN v_booking.status IN ('completed', 'cancelled') THEN false
        WHEN v_booking.driver_id IS NOT NULL AND v_booking.driver_id <> c.driver_id THEN false
        WHEN COALESCE(array_length(c.accepted_service_types, 1), 0) > 0
          AND NOT v_booking.service_type = ANY(c.accepted_service_types) THEN false
        WHEN v_booking.driver_id = c.driver_id THEN true
        WHEN c.is_online IS NOT TRUE THEN false
        WHEN v_booking.service_type IN ('ride', 'parcel') AND v_booking.status <> 'pending' THEN false
        WHEN v_booking.service_type = 'food' AND v_booking.status <> 'ready_for_pickup' THEN false
        WHEN c.location_lat IS NULL OR c.location_lng IS NULL THEN false
        WHEN v_booking.origin_lat IS NULL OR v_booking.origin_lng IS NULL THEN false
        WHEN v_booking.service_type = 'ride'
          AND COALESCE(v_booking.vehicle_type, '') <> ''
          AND COALESCE(c.driver_vehicle_type, '') <> ''
          AND v_booking.vehicle_type <> c.driver_vehicle_type THEN false
        WHEN c.radius_distance_km > p_radius_km THEN false
        ELSE true
      END AS visible_to_driver,
      CASE
        WHEN v_booking.status IN ('completed', 'cancelled') THEN 'not_visible_status'
        WHEN v_booking.driver_id IS NOT NULL AND v_booking.driver_id <> c.driver_id THEN 'assigned_to_other_driver'
        WHEN COALESCE(array_length(c.accepted_service_types, 1), 0) > 0
          AND NOT v_booking.service_type = ANY(c.accepted_service_types) THEN 'service_mismatch'
        WHEN v_booking.driver_id = c.driver_id THEN NULL
        WHEN c.is_online IS NOT TRUE THEN 'offline'
        WHEN v_booking.service_type = 'food' AND v_booking.status = 'pending_merchant' THEN 'waiting_merchant_accept'
        WHEN v_booking.service_type = 'food' AND v_booking.status = 'preparing' THEN 'merchant_preparing'
        WHEN v_booking.service_type = 'food' AND v_booking.status <> 'ready_for_pickup' THEN 'not_driver_visible_food_status'
        WHEN v_booking.service_type IN ('ride', 'parcel') AND v_booking.status <> 'pending' THEN 'not_driver_visible_status'
        WHEN c.location_lat IS NULL OR c.location_lng IS NULL THEN 'driver_location_missing'
        WHEN v_booking.origin_lat IS NULL OR v_booking.origin_lng IS NULL THEN 'booking_location_missing'
        WHEN v_booking.service_type = 'ride'
          AND COALESCE(v_booking.vehicle_type, '') <> ''
          AND COALESCE(c.driver_vehicle_type, '') <> ''
          AND v_booking.vehicle_type <> c.driver_vehicle_type THEN 'vehicle_mismatch'
        WHEN c.radius_distance_km > p_radius_km THEN 'out_of_radius'
        ELSE NULL
      END AS hidden_reason
    FROM candidates c
  ),
  latest_notification AS (
    SELECT DISTINCT ON (n.user_id)
      n.user_id,
      n.id
    FROM public.notifications n
    WHERE n.type = 'driver.job.available'
      AND n.data->>'booking_id' = p_booking_id::text
    ORDER BY n.user_id, n.created_at DESC
  ),
  latest_delivery AS (
    SELECT DISTINCT ON (nd.user_id)
      nd.user_id,
      nd.status,
      nd.error,
      nd.created_at
    FROM public.notification_deliveries nd
    JOIN latest_notification ln ON ln.id = nd.notification_id
    ORDER BY nd.user_id, nd.created_at DESC
  )
  SELECT
    e.driver_id,
    e.driver_name,
    COALESCE(e.is_online, false),
    COALESCE(e.is_available, false),
    e.accepted_service_types,
    e.driver_vehicle_type,
    e.radius_distance_km,
    e.fcm_token IS NOT NULL AND e.fcm_token <> '',
    e.visible_to_driver,
    CASE
      WHEN e.visible_to_driver AND (e.fcm_token IS NULL OR e.fcm_token = '') THEN 'no_token'
      ELSE e.hidden_reason
    END,
    ln.id,
    ld.status,
    ld.error,
    ld.created_at
  FROM evaluated e
  LEFT JOIN latest_notification ln ON ln.user_id = e.driver_id
  LEFT JOIN latest_delivery ld ON ld.user_id = e.driver_id
  ORDER BY e.visible_to_driver DESC, e.radius_distance_km NULLS LAST, e.driver_name NULLS LAST;
END;
$$;

GRANT EXECUTE ON FUNCTION public.get_booking_driver_notification_debug(
  uuid,
  double precision
) TO authenticated, service_role;
