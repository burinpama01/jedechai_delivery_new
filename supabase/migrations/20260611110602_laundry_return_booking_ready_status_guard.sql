CREATE OR REPLACE FUNCTION public.create_laundry_return_booking(
  p_laundry_order_id uuid,
  p_delivery_fee_return numeric DEFAULT 0,
  p_return_payment_method text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_order public.laundry_orders%ROWTYPE;
  v_merchant record;
  v_booking_id uuid;
  v_payment_method text;
  v_wallet_id uuid;
  v_old_balance numeric;
  v_new_balance numeric;
  v_hold_tx_id uuid;
  v_distance_km double precision;
BEGIN
  IF v_actor_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  SELECT *
  INTO v_order
  FROM public.laundry_orders
  WHERE id = p_laundry_order_id
  FOR UPDATE;

  IF v_order.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_found');
  END IF;

  IF v_order.merchant_id <> v_actor_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  IF v_order.return_booking_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_created', true,
      'return_booking_id', v_order.return_booking_id
    );
  END IF;

  IF v_order.status NOT IN ('at_merchant', 'washing', 'ready_for_return') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'laundry_not_ready_for_return',
      'status', v_order.status
    );
  END IF;

  IF v_order.return_mode = 'self_pickup' THEN
    UPDATE public.laundry_orders
    SET status = 'ready_for_return',
        updated_at = now()
    WHERE id = p_laundry_order_id;

    RETURN jsonb_build_object('success', true, 'self_pickup', true, 'laundry_order_id', p_laundry_order_id);
  END IF;

  IF COALESCE(p_delivery_fee_return, 0) < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_delivery_fee');
  END IF;

  v_payment_method := COALESCE(p_return_payment_method, v_order.return_payment_method, 'cash');
  IF v_payment_method NOT IN ('cash', 'wallet') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_return_payment_method');
  END IF;

  SELECT id, latitude, longitude, shop_address, full_name
  INTO v_merchant
  FROM public.profiles
  WHERE id = v_order.merchant_id;

  IF v_merchant.latitude IS NULL OR v_merchant.longitude IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'merchant_location_missing');
  END IF;

  v_distance_km := 6371 * acos(
    LEAST(
      1,
      GREATEST(
        -1,
        cos(radians(v_merchant.latitude)) * cos(radians(v_order.pickup_lat)) *
        cos(radians(v_order.pickup_lng) - radians(v_merchant.longitude)) +
        sin(radians(v_merchant.latitude)) * sin(radians(v_order.pickup_lat))
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
    return_payment_method
  )
  VALUES (
    v_order.customer_id,
    v_order.merchant_id,
    'laundry',
    v_merchant.latitude,
    v_merchant.longitude,
    v_order.pickup_lat,
    v_order.pickup_lng,
    COALESCE(NULLIF(BTRIM(v_merchant.shop_address), ''), v_merchant.full_name, 'Laundry merchant'),
    v_order.pickup_address,
    v_distance_km,
    ROUND(COALESCE(p_delivery_fee_return, 0)::numeric, 2),
    ROUND(COALESCE(p_delivery_fee_return, 0)::numeric, 2),
    'pending',
    v_payment_method,
    'Laundry return #' || LEFT(v_order.id::text, 8),
    v_order.id,
    'return',
    v_payment_method
  )
  RETURNING id INTO v_booking_id;

  IF v_payment_method = 'wallet' AND COALESCE(p_delivery_fee_return, 0) > 0 THEN
    INSERT INTO public.wallets (user_id, balance)
    VALUES (v_order.customer_id, 0)
    ON CONFLICT (user_id) DO NOTHING;

    SELECT id, balance
    INTO v_wallet_id, v_old_balance
    FROM public.wallets
    WHERE user_id = v_order.customer_id
    FOR UPDATE;

    IF v_old_balance < p_delivery_fee_return THEN
      DELETE FROM public.bookings WHERE id = v_booking_id;
      RETURN jsonb_build_object(
        'success', false,
        'error', 'insufficient_balance',
        'balance', v_old_balance,
        'required', p_delivery_fee_return
      );
    END IF;

    v_new_balance := v_old_balance - p_delivery_fee_return;

    UPDATE public.wallets
    SET balance = v_new_balance, updated_at = now()
    WHERE id = v_wallet_id;

    INSERT INTO public.wallet_transactions (
      wallet_id, amount, type, description, related_booking_id
    )
    VALUES (
      v_wallet_id,
      -ROUND(p_delivery_fee_return::numeric, 2),
      'hold',
      'พักยอดค่าส่งผ้ากลับ #' || LEFT(v_order.id::text, 8),
      v_booking_id
    )
    RETURNING id INTO v_hold_tx_id;
  END IF;

  UPDATE public.laundry_orders
  SET status = 'return_pending',
      delivery_fee_return = ROUND(COALESCE(p_delivery_fee_return, 0)::numeric, 2),
      return_payment_method = v_payment_method,
      return_booking_id = v_booking_id,
      return_wallet_hold_transaction_id = v_hold_tx_id,
      updated_at = now()
  WHERE id = p_laundry_order_id;

  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (
    v_order.customer_id,
    'ร้านซักผ้าสร้างงานส่งผ้ากลับแล้ว',
    'ระบบกำลังหาคนขับสำหรับส่งผ้ากลับ',
    'laundry.return_booking_created',
    jsonb_build_object('laundry_order_id', p_laundry_order_id, 'booking_id', v_booking_id, 'laundry_leg', 'return')
  );

  RETURN jsonb_build_object(
    'success', true,
    'laundry_order_id', p_laundry_order_id,
    'return_booking_id', v_booking_id,
    'return_wallet_hold_transaction_id', v_hold_tx_id
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_laundry_return_booking(uuid, numeric, text) TO authenticated, service_role;
