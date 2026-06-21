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
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_merchant_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'merchant_auth_mismatch');
  END IF;

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

  IF v_booking.status IN ('arrived_at_merchant', 'arrived') THEN
    UPDATE public.bookings
       SET status = 'ready_for_pickup',
           merchant_food_ready_at = now(),
           updated_at = now()
     WHERE id = p_booking_id
     RETURNING * INTO v_booking;

    RETURN jsonb_build_object(
      'success', true,
      'status', 'ready_for_pickup',
      'pending_driver_arrival', false
    );
  END IF;

  IF v_booking.status IN ('preparing', 'matched', 'driver_accepted', 'accepted') THEN
    IF v_booking.driver_id IS NULL THEN
      UPDATE public.bookings
         SET status = 'ready_for_pickup',
             merchant_food_ready_at = now(),
             updated_at = now()
       WHERE id = p_booking_id
       RETURNING * INTO v_booking;

      RETURN jsonb_build_object(
        'success', true,
        'status', 'ready_for_pickup',
        'pending_driver_arrival', false
      );
    END IF;

    UPDATE public.bookings
       SET merchant_food_ready_at = now(),
           updated_at = now()
     WHERE id = p_booking_id
     RETURNING * INTO v_booking;

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

GRANT EXECUTE ON FUNCTION public.mark_food_ready_guarded(uuid, uuid)
  TO authenticated, service_role;
