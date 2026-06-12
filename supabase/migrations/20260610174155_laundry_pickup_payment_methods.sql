/*
Superseded by 20260611003000_laundry_pickup_payment_methods_final_guard.sql.

This migration originally shipped before the laundry core migration that creates
public.laundry_orders. Keep the original body commented out so a fresh replay
does not touch public.laundry_orders before it exists. The effective schema and
RPC changes are reapplied by the final guard migration.

-- Align laundry quote acceptance with the plan:
-- - remote pickup must pay outbound by wallet
-- - customer at pickup can pay outbound by cash or wallet
-- - wallet outbound releases driver/merchant pass-through on completion
-- - cash outbound does not top up the driver's wallet on completion

ALTER TABLE public.laundry_orders
  ADD COLUMN IF NOT EXISTS pickup_presence text NOT NULL DEFAULT 'remote_pickup';

ALTER TABLE public.laundry_orders
  DROP CONSTRAINT IF EXISTS laundry_orders_pickup_presence_check;

ALTER TABLE public.laundry_orders
  ADD CONSTRAINT laundry_orders_pickup_presence_check
  CHECK (pickup_presence IN ('remote_pickup', 'customer_at_pickup'));

ALTER TABLE public.laundry_orders
  DROP CONSTRAINT IF EXISTS laundry_orders_payment_method_check;

ALTER TABLE public.laundry_orders
  ADD CONSTRAINT laundry_orders_payment_method_check
  CHECK (payment_method IS NULL OR payment_method IN ('cash', 'wallet'));

DROP FUNCTION IF EXISTS public.customer_accept_laundry_quote(uuid, text, text, text);

CREATE OR REPLACE FUNCTION public.customer_accept_laundry_quote(
  p_laundry_order_id uuid,
  p_payment_method text DEFAULT 'wallet',
  p_return_mode text DEFAULT 'delivery',
  p_return_payment_method text DEFAULT 'cash',
  p_pickup_presence text DEFAULT 'remote_pickup'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_customer_id uuid := auth.uid();
  v_order public.laundry_orders%ROWTYPE;
  v_merchant record;
  v_booking_id uuid;
  v_total_amount numeric;
  v_distance_km double precision;
  v_wallet_result jsonb;
  v_payment_method text := COALESCE(p_payment_method, 'wallet');
  v_pickup_presence text := COALESCE(p_pickup_presence, 'remote_pickup');
BEGIN
  IF v_customer_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  IF v_payment_method NOT IN ('cash', 'wallet') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_payment_method');
  END IF;

  IF v_pickup_presence NOT IN ('remote_pickup', 'customer_at_pickup') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_pickup_presence');
  END IF;

  IF v_pickup_presence = 'remote_pickup' AND v_payment_method <> 'wallet' THEN
    RETURN jsonb_build_object('success', false, 'error', 'pickup_cash_not_allowed');
  END IF;

  IF COALESCE(p_return_mode, 'delivery') NOT IN ('delivery', 'self_pickup') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_return_mode');
  END IF;

  IF COALESCE(p_return_payment_method, 'cash') NOT IN ('cash', 'wallet') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_return_payment_method');
  END IF;

  SELECT *
  INTO v_order
  FROM public.laundry_orders
  WHERE id = p_laundry_order_id
  FOR UPDATE;

  IF v_order.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_found');
  END IF;

  IF v_order.customer_id <> v_customer_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  IF v_order.status <> 'quoted' THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_status', 'status', v_order.status);
  END IF;

  IF v_order.quote_expires_at IS NULL OR v_order.quote_expires_at <= now() THEN
    UPDATE public.laundry_orders
    SET status = 'quote_expired', updated_at = now()
    WHERE id = p_laundry_order_id;

    RETURN jsonb_build_object('success', false, 'error', 'quote_expired');
  END IF;

  IF v_order.laundry_amount IS NULL OR v_order.laundry_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_laundry_amount');
  END IF;

  SELECT id, latitude, longitude, shop_address, full_name
  INTO v_merchant
  FROM public.profiles
  WHERE id = v_order.merchant_id;

  IF v_merchant.latitude IS NULL OR v_merchant.longitude IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'merchant_location_missing');
  END IF;

  v_total_amount := ROUND((v_order.laundry_amount + v_order.delivery_fee_outbound)::numeric, 2);
  v_distance_km := 6371 * acos(
    LEAST(
      1,
      GREATEST(
        -1,
        cos(radians(v_order.pickup_lat)) * cos(radians(v_merchant.latitude)) *
        cos(radians(v_merchant.longitude) - radians(v_order.pickup_lng)) +
        sin(radians(v_order.pickup_lat)) * sin(radians(v_merchant.latitude))
      )
    )
  );

  INSERT INTO public.bookings (
    customer_id,
    merchant_id,
    service_type,
    origin_lat,
    origin_lng,
    dest_lat,
    dest_lng,
    pickup_address,
    destination_address,
    distance_km,
    price,
    delivery_fee,
    status,
    payment_method,
    notes,
    laundry_order_id,
    laundry_leg,
    platform_gp_amount,
    merchant_net_amount,
    return_payment_method
  )
  VALUES (
    v_order.customer_id,
    v_order.merchant_id,
    'laundry',
    v_order.pickup_lat,
    v_order.pickup_lng,
    v_merchant.latitude,
    v_merchant.longitude,
    v_order.pickup_address,
    COALESCE(NULLIF(BTRIM(v_merchant.shop_address), ''), v_merchant.full_name, 'Laundry merchant'),
    v_distance_km,
    v_total_amount,
    v_order.delivery_fee_outbound,
    'pending',
    v_payment_method,
    'Laundry outbound #' || LEFT(v_order.id::text, 8),
    v_order.id,
    'outbound',
    v_order.platform_gp_amount,
    v_order.merchant_net_amount,
    p_return_payment_method
  )
  RETURNING id INTO v_booking_id;

  IF v_payment_method = 'wallet' THEN
    v_wallet_result := public.customer_wallet_pay_booking(
      v_customer_id,
      v_booking_id,
      v_total_amount,
      'ชำระค่าซักผ้าและค่าส่งขาไป #' || LEFT(v_order.id::text, 8)
    );

    IF COALESCE((v_wallet_result->>'success')::boolean, false) IS NOT TRUE THEN
      DELETE FROM public.bookings WHERE id = v_booking_id;
      RETURN jsonb_build_object(
        'success', false,
        'error', COALESCE(v_wallet_result->>'error', 'wallet_payment_failed'),
        'wallet_result', v_wallet_result
      );
    END IF;
  ELSE
    v_wallet_result := jsonb_build_object('success', true, 'skipped', true, 'payment_method', 'cash');
  END IF;

  UPDATE public.laundry_orders
  SET status = 'outbound_pending',
      accepted_at = now(),
      payment_method = v_payment_method,
      pickup_presence = v_pickup_presence,
      outbound_booking_id = v_booking_id,
      return_mode = COALESCE(p_return_mode, 'delivery'),
      return_payment_method = COALESCE(p_return_payment_method, 'cash'),
      updated_at = now()
  WHERE id = p_laundry_order_id;

  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (
    v_order.merchant_id,
    'ลูกค้ายืนยัน quote ซักผ้าแล้ว',
    'ระบบสร้างงานคนขับขาไปแล้ว รหัส #' || LEFT(v_booking_id::text, 8),
    'laundry.quote_accepted',
    jsonb_build_object(
      'laundry_order_id', p_laundry_order_id,
      'booking_id', v_booking_id,
      'laundry_leg', 'outbound',
      'payment_method', v_payment_method,
      'pickup_presence', v_pickup_presence
    )
  );

  RETURN jsonb_build_object(
    'success', true,
    'laundry_order_id', p_laundry_order_id,
    'outbound_booking_id', v_booking_id,
    'payment_method', v_payment_method,
    'pickup_presence', v_pickup_presence,
    'wallet_result', v_wallet_result
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.customer_accept_laundry_quote(uuid, text, text, text, text) TO authenticated, service_role;

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

  SELECT id, driver_id, service_type, status, payment_method, laundry_order_id, laundry_leg, return_payment_method
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
    RETURN jsonb_build_object(
      'success', true,
      'already_completed', true,
      'booking_id', p_booking_id,
      'laundry_order_id', v_booking.laundry_order_id
    );
  END IF;

  IF v_booking.status NOT IN ('driver_accepted', 'in_progress', 'arrived_pickup', 'picked_up', 'delivering') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_status', 'status', v_booking.status);
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
    v_driver_earnings := ROUND(COALESCE(v_order.delivery_fee_outbound, 0)::numeric, 2);
    v_app_earnings := ROUND(COALESCE(v_order.platform_gp_amount, 0)::numeric, 2);
    v_next_order_status := 'at_merchant';

    IF COALESCE(v_order.payment_method, v_booking.payment_method, 'wallet') = 'wallet' THEN
      v_wallet_credit := ROUND((COALESCE(v_order.merchant_net_amount, 0) + COALESCE(v_order.delivery_fee_outbound, 0))::numeric, 2);
      v_tx_type := 'laundry_payout';
      v_tx_description := 'รับเงินงานซักผ้าขาไป #' || LEFT(v_order.id::text, 8) || ' (รวมยอดจ่ายร้าน)';
    ELSIF COALESCE(v_order.payment_method, v_booking.payment_method, 'wallet') = 'cash' THEN
      v_wallet_credit := 0;
      v_tx_description := 'จบงานซักผ้าขาไปแบบเงินสด #' || LEFT(v_order.id::text, 8);
    ELSE
      RETURN jsonb_build_object('success', false, 'error', 'invalid_payment_method');
    END IF;
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
*/

-- Replay-safe no-op. See 20260611003000_laundry_pickup_payment_methods_final_guard.sql.
SELECT 1;
