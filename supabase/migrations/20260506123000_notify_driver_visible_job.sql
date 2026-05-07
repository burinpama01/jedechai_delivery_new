DELETE FROM public.notifications n
USING public.notifications newer
WHERE n.type = 'driver.job.available'
  AND newer.type = 'driver.job.available'
  AND n.user_id = newer.user_id
  AND n.data->>'booking_id' = newer.data->>'booking_id'
  AND n.id <> newer.id
  AND (
    n.created_at < newer.created_at
    OR (n.created_at = newer.created_at AND n.id::text < newer.id::text)
  );

CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_driver_job_available_once
ON public.notifications (user_id, type, ((data->>'booking_id')))
WHERE type = 'driver.job.available';

CREATE OR REPLACE FUNCTION public.notify_driver_visible_job(
  p_booking_id uuid,
  p_title text DEFAULT NULL,
  p_body text DEFAULT NULL,
  p_radius_km double precision DEFAULT 5.0
)
RETURNS TABLE (
  driver_id uuid,
  notification_id uuid
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_caller_role text;
  v_title text;
  v_body text;
  v_payload jsonb;
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
    AND auth.uid() <> v_booking.customer_id
    AND COALESCE(v_caller_role, '') <> 'admin'
  THEN
    RAISE EXCEPTION 'not allowed to notify drivers for this booking'
      USING ERRCODE = '42501';
  END IF;

  v_title := COALESCE(p_title, 'งานใหม่');
  v_body := COALESCE(
    p_body,
    concat(
      'มีงาน',
      CASE
        WHEN v_booking.service_type = 'food' THEN 'ส่งอาหาร'
        WHEN v_booking.service_type = 'ride' THEN 'รับส่งผู้โดยสาร'
        WHEN v_booking.service_type = 'parcel' THEN 'ส่งพัสดุ'
        ELSE ''
      END
    )
  );
  v_payload := jsonb_build_object(
    'type', 'driver.job.available',
    'recipient_role', 'driver',
    'booking_id', v_booking.id::text,
    'service_type', v_booking.service_type,
    'legacy_type', 'new_booking',
    'customer_id', v_booking.customer_id::text,
    'origin_lat', COALESCE(v_booking.origin_lat::text, ''),
    'origin_lng', COALESCE(v_booking.origin_lng::text, ''),
    'dest_lat', COALESCE(v_booking.dest_lat::text, ''),
    'dest_lng', COALESCE(v_booking.dest_lng::text, ''),
    'price', COALESCE(v_booking.price::text, ''),
    'pickup_address', COALESCE(v_booking.pickup_address, ''),
    'destination_address', COALESCE(v_booking.destination_address, ''),
    'distance_km', COALESCE(v_booking.distance_km::text, '')
  );

  RETURN QUERY
  WITH candidates AS (
    SELECT
      dl.driver_id,
      p.accepted_service_types,
      p.vehicle_type AS driver_vehicle_type,
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
    FROM public.driver_locations dl
    JOIN public.profiles p ON p.id = dl.driver_id
    WHERE p.role = 'driver'
      AND p.approval_status = 'approved'
  ),
  visible AS (
    SELECT c.driver_id
    FROM candidates c
    WHERE v_booking.status NOT IN ('completed', 'cancelled')
      AND (v_booking.driver_id IS NULL OR v_booking.driver_id = c.driver_id)
      AND (
        COALESCE(array_length(c.accepted_service_types, 1), 0) = 0
        OR v_booking.service_type = ANY(c.accepted_service_types)
      )
      AND (
        v_booking.driver_id = c.driver_id
        OR (
          c.is_online = true
          AND (
            (v_booking.service_type IN ('ride', 'parcel') AND v_booking.status = 'pending')
            OR (v_booking.service_type = 'food' AND v_booking.status = 'ready_for_pickup')
          )
          AND c.location_lat IS NOT NULL
          AND c.location_lng IS NOT NULL
          AND v_booking.origin_lat IS NOT NULL
          AND v_booking.origin_lng IS NOT NULL
          AND (
            v_booking.service_type <> 'ride'
            OR v_booking.vehicle_type IS NULL
            OR v_booking.vehicle_type = ''
            OR c.driver_vehicle_type IS NULL
            OR c.driver_vehicle_type = ''
            OR v_booking.vehicle_type = c.driver_vehicle_type
          )
          AND c.radius_distance_km <= p_radius_km
        )
      )
  ),
  inserted AS (
    INSERT INTO public.notifications (user_id, title, body, type, data)
    SELECT
      v.driver_id,
      v_title,
      v_body,
      'driver.job.available',
      v_payload
    FROM visible v
    ON CONFLICT DO NOTHING
    RETURNING user_id, id
  )
  SELECT
    i.user_id AS driver_id,
    i.id AS notification_id
  FROM inserted i
  ORDER BY i.user_id;
END;
$$;

GRANT EXECUTE ON FUNCTION public.notify_driver_visible_job(
  uuid,
  text,
  text,
  double precision
) TO authenticated, service_role;
