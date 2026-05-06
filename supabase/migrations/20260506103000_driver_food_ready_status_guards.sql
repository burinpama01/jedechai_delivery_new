ALTER TABLE public.bookings
ADD COLUMN IF NOT EXISTS merchant_food_ready_at timestamptz;

CREATE OR REPLACE FUNCTION public.mark_food_ready_guarded(
  p_booking_id uuid,
  p_merchant_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
BEGIN
  SELECT *
    INTO v_booking
    FROM public.bookings
   WHERE id = p_booking_id
   FOR UPDATE;

  IF v_booking.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF v_booking.service_type <> 'food' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_food_order');
  END IF;

  IF v_booking.merchant_id <> p_merchant_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'merchant_mismatch');
  END IF;

  IF v_booking.status = 'arrived_at_merchant' THEN
    UPDATE public.bookings
       SET status = 'ready_for_pickup',
           merchant_food_ready_at = now(),
           updated_at = now()
     WHERE id = p_booking_id;

    RETURN jsonb_build_object(
      'success', true,
      'status', 'ready_for_pickup',
      'pending_driver_arrival', false
    );
  END IF;

  IF v_booking.status IN ('preparing', 'matched', 'driver_accepted') THEN
    UPDATE public.bookings
       SET merchant_food_ready_at = now(),
           updated_at = now()
     WHERE id = p_booking_id;

    RETURN jsonb_build_object(
      'success', true,
      'status', v_booking.status,
      'pending_driver_arrival', true
    );
  END IF;

  RETURN jsonb_build_object(
    'success', false,
    'error', 'invalid_status',
    'current_status', v_booking.status
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.driver_arrived_at_merchant_guarded(
  p_booking_id uuid,
  p_driver_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_next_status text;
BEGIN
  SELECT *
    INTO v_booking
    FROM public.bookings
   WHERE id = p_booking_id
   FOR UPDATE;

  IF v_booking.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF v_booking.service_type <> 'food' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_food_order');
  END IF;

  IF v_booking.driver_id <> p_driver_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'driver_mismatch');
  END IF;

  IF v_booking.status NOT IN ('driver_accepted', 'accepted') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'invalid_status',
      'current_status', v_booking.status
    );
  END IF;

  v_next_status := CASE
    WHEN v_booking.merchant_food_ready_at IS NOT NULL THEN 'ready_for_pickup'
    ELSE 'arrived_at_merchant'
  END;

  UPDATE public.bookings
     SET status = v_next_status,
         updated_at = now()
   WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', v_next_status,
    'food_ready_pending_driver_arrival',
    v_booking.merchant_food_ready_at IS NOT NULL
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_food_ready_guarded(uuid, uuid)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.driver_arrived_at_merchant_guarded(uuid, uuid)
  TO authenticated, service_role;
