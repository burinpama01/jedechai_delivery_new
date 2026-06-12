-- Final customer laundry quote acceptance guard.
-- Self pickup has no return driver leg, so return delivery wallet hold is invalid.

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

  IF COALESCE(p_return_mode, 'delivery') = 'self_pickup'
      AND COALESCE(p_return_payment_method, 'cash') = 'wallet' THEN
    RETURN jsonb_build_object('success', false, 'error', 'self_pickup_wallet_not_allowed');
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
