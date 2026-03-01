-- Grant execute permissions for booking RPCs used by the app

DO $$
BEGIN
  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'accept_booking'
      AND pg_get_function_identity_arguments(p.oid) = 'p_booking_id uuid, p_driver_id uuid, p_expected_status text'
  ) THEN
    GRANT EXECUTE ON FUNCTION public.accept_booking(uuid, uuid, text) TO authenticated, service_role;
  END IF;

  IF EXISTS (
    SELECT 1
    FROM pg_proc p
    JOIN pg_namespace n ON n.oid = p.pronamespace
    WHERE n.nspname = 'public'
      AND p.proname = 'complete_booking'
      AND pg_get_function_identity_arguments(p.oid) = 'p_booking_id uuid, p_driver_id uuid, p_commission_amount numeric, p_driver_earnings numeric, p_app_earnings numeric, p_description text'
  ) THEN
    GRANT EXECUTE ON FUNCTION public.complete_booking(uuid, uuid, numeric, numeric, numeric, text) TO authenticated, service_role;
  END IF;
END
$$;
