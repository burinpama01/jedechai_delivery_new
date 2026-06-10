CREATE OR REPLACE FUNCTION public.update_booking_status_driver_guarded(
  p_booking_id uuid,
  p_new_status text,
  p_expected_statuses text[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT * INTO v_booking
    FROM public.bookings
   WHERE id = p_booking_id
   FOR UPDATE;

  IF v_booking.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF v_booking.driver_id IS NULL OR v_booking.driver_id <> auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'driver_mismatch');
  END IF;

  IF NOT (v_booking.status = ANY(p_expected_statuses)) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'status_mismatch',
      'current_status', v_booking.status
    );
  END IF;

  UPDATE public.bookings
     SET status = p_new_status,
         updated_at = now()
   WHERE id = p_booking_id;

  RETURN jsonb_build_object('success', true, 'status', p_new_status);
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_booking_status_driver_guarded(uuid, text, text[])
  TO authenticated;;
