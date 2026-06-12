-- Complete laundry delivery legs with laundry-specific settlement.
-- Avoid generic non-food commission on the whole laundry quote amount.

CREATE OR REPLACE FUNCTION public.complete_laundry_booking(
  p_booking_id uuid,
  p_driver_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking record;
  v_order record;
  v_driver_wallet_id uuid;
  v_existing_payout boolean := false;
  v_wallet_credit numeric := 0;
  v_driver_earnings numeric := 0;
  v_app_earnings numeric := 0;
  v_tx_type text := 'laundry_payout';
  v_tx_description text;
  v_wallet_result jsonb := '{}'::jsonb;
  v_next_order_status text;
BEGIN
  IF p_driver_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'driver_required');
  END IF;

  SELECT id, driver_id, service_type, status, laundry_order_id, laundry_leg, return_payment_method
  INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF v_booking.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF v_booking.service_type <> 'laundry' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_laundry_booking');
  END IF;

  IF v_booking.driver_id <> p_driver_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  IF v_booking.status = 'completed' THEN
    RETURN jsonb_build_object('success', true, 'already_completed', true, 'booking_id', p_booking_id);
  END IF;

  IF v_booking.status NOT IN ('in_transit', 'arrived', 'ready_for_pickup') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_status', 'current_status', v_booking.status);
  END IF;

  SELECT *
  INTO v_order
  FROM public.laundry_orders
  WHERE id = v_booking.laundry_order_id
  FOR UPDATE;

  IF v_order.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'laundry_order_not_found');
  END IF;

  IF v_booking.laundry_leg = 'outbound' THEN
    v_wallet_credit := ROUND((COALESCE(v_order.merchant_net_amount, 0) + COALESCE(v_order.delivery_fee_outbound, 0))::numeric, 2);
    v_driver_earnings := ROUND(COALESCE(v_order.delivery_fee_outbound, 0)::numeric, 2);
    v_app_earnings := ROUND(COALESCE(v_order.platform_gp_amount, 0)::numeric, 2);
    v_tx_type := 'laundry_payout';
    v_tx_description := 'รับเงินงานซักผ้าขาไป #' || LEFT(v_order.id::text, 8) || ' (รวมยอดจ่ายร้าน)';
    v_next_order_status := 'at_merchant';
  ELSIF v_booking.laundry_leg = 'return' THEN
    v_driver_earnings := ROUND(COALESCE(v_order.delivery_fee_return, 0)::numeric, 2);
    v_app_earnings := 0;
    v_next_order_status := 'completed';

    IF COALESCE(v_booking.return_payment_method, v_order.return_payment_method, 'cash') = 'wallet' THEN
      v_wallet_credit := v_driver_earnings;
      v_tx_type := 'release';
      v_tx_description := 'ปล่อยยอดค่าส่งผ้ากลับ #' || LEFT(v_order.id::text, 8);
    ELSE
      v_wallet_credit := 0;
      v_tx_description := 'จบงานส่งผ้ากลับแบบเงินสด #' || LEFT(v_order.id::text, 8);
    END IF;
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'invalid_laundry_leg');
  END IF;

  IF v_wallet_credit > 0 THEN
    SELECT id
    INTO v_driver_wallet_id
    FROM public.wallets
    WHERE user_id = p_driver_id
    LIMIT 1;

    SELECT EXISTS (
      SELECT 1
      FROM public.wallet_transactions wt
      JOIN public.wallets w ON w.id = wt.wallet_id
      WHERE w.user_id = p_driver_id
        AND wt.related_booking_id = p_booking_id
        AND wt.type = v_tx_type
    )
    INTO v_existing_payout;

    IF NOT v_existing_payout THEN
      SELECT public.wallet_topup(
        p_driver_id,
        v_wallet_credit,
        v_tx_description,
        v_tx_type,
        p_booking_id
      )
      INTO v_wallet_result;

      IF COALESCE((v_wallet_result->>'success')::boolean, false) IS NOT TRUE THEN
        RETURN jsonb_build_object(
          'success', false,
          'error', 'wallet_release_failed',
          'wallet_result', v_wallet_result
        );
      END IF;
    END IF;
  END IF;

  UPDATE public.bookings
  SET status = 'completed',
      completed_at = now(),
      driver_earnings = v_driver_earnings,
      app_earnings = v_app_earnings,
      updated_at = now()
  WHERE id = p_booking_id;

  UPDATE public.laundry_orders
  SET status = v_next_order_status,
      updated_at = now()
  WHERE id = v_order.id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'laundry_order_id', v_order.id,
    'laundry_leg', v_booking.laundry_leg,
    'order_status', v_next_order_status,
    'wallet_credit', v_wallet_credit,
    'driver_earnings', v_driver_earnings,
    'app_earnings', v_app_earnings,
    'wallet_result', v_wallet_result
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.complete_laundry_booking(uuid, uuid) TO authenticated, service_role;
