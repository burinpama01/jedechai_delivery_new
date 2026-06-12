-- Separate Laundry GP into merchant-service GP and delivery-fee GP.
-- Merchant type remains stored in profiles.merchant_service_types for app/admin compatibility.

ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS laundry_merchant_gp_rate numeric(7,4),
  ADD COLUMN IF NOT EXISTS laundry_delivery_gp_rate numeric(7,4);

ALTER TABLE public.laundry_orders
  ADD COLUMN IF NOT EXISTS laundry_merchant_gp_rate numeric(7,4),
  ADD COLUMN IF NOT EXISTS laundry_delivery_gp_rate numeric(7,4),
  ADD COLUMN IF NOT EXISTS delivery_gp_amount_outbound numeric(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS delivery_net_amount_outbound numeric(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS delivery_gp_amount_return numeric(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS delivery_net_amount_return numeric(12,2) NOT NULL DEFAULT 0;

DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'profiles' AND column_name = 'merchant_service_types'
  ) THEN
    UPDATE public.profiles
    SET merchant_service_types = ARRAY['food']::text[],
        updated_at = COALESCE(updated_at, now())
    WHERE role = 'merchant'
      AND (merchant_service_types IS NULL OR cardinality(merchant_service_types) = 0);
  END IF;
END;
$$;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'profiles_laundry_merchant_gp_rate_range'
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_laundry_merchant_gp_rate_range
      CHECK (laundry_merchant_gp_rate IS NULL OR (laundry_merchant_gp_rate >= 0 AND laundry_merchant_gp_rate <= 1));
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'profiles_laundry_delivery_gp_rate_range'
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT profiles_laundry_delivery_gp_rate_range
      CHECK (laundry_delivery_gp_rate IS NULL OR (laundry_delivery_gp_rate >= 0 AND laundry_delivery_gp_rate <= 1));
  END IF;
END;
$$;

INSERT INTO public.system_config (key, value, updated_at)
SELECT 'laundry_merchant_gp_rate_default', '0.1000', now()
WHERE EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'system_config' AND column_name = 'key'
  )
  AND EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'system_config' AND column_name = 'value'
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.system_config WHERE key = 'laundry_merchant_gp_rate_default'
  );

INSERT INTO public.system_config (key, value, updated_at)
SELECT 'laundry_delivery_gp_rate_default', '0.0000', now()
WHERE EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'system_config' AND column_name = 'key'
  )
  AND EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'system_config' AND column_name = 'value'
  )
  AND NOT EXISTS (
    SELECT 1 FROM public.system_config WHERE key = 'laundry_delivery_gp_rate_default'
  );

CREATE OR REPLACE FUNCTION public.merchant_send_laundry_quote(
  p_laundry_order_id uuid,
  p_laundry_amount numeric,
  p_quote_message text DEFAULT NULL,
  p_quote_expires_minutes integer DEFAULT NULL,
  p_delivery_fee_outbound numeric DEFAULT 0,
  p_platform_gp_rate numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_merchant_id uuid := auth.uid();
  v_order public.laundry_orders%ROWTYPE;
  v_expiry_minutes integer;
  v_default_merchant_gp_rate numeric := 0.1000;
  v_default_delivery_gp_rate numeric := 0;
  v_merchant_gp_rate numeric;
  v_delivery_gp_rate numeric;
  v_laundry_amount numeric;
  v_delivery_fee_outbound numeric;
  v_platform_gp_amount numeric;
  v_merchant_net_amount numeric;
  v_delivery_gp_amount_outbound numeric;
  v_delivery_net_amount_outbound numeric;
BEGIN
  IF v_merchant_id IS NULL THEN
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

  IF v_order.merchant_id <> v_merchant_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  IF v_order.status NOT IN ('quote_requested', 'quoted') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_status', 'status', v_order.status);
  END IF;

  IF p_laundry_amount IS NULL OR p_laundry_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_laundry_amount');
  END IF;

  IF COALESCE(p_delivery_fee_outbound, 0) < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_delivery_fee');
  END IF;

  SELECT
    COALESCE(
      MAX(CASE WHEN key = 'laundry_merchant_gp_rate_default' AND value ~ '^[0-9]+(\.[0-9]+)?$' THEN value::numeric END),
      0.1000
    ),
    COALESCE(
      MAX(CASE WHEN key = 'laundry_delivery_gp_rate_default' AND value ~ '^[0-9]+(\.[0-9]+)?$' THEN value::numeric END),
      0
    )
  INTO v_default_merchant_gp_rate, v_default_delivery_gp_rate
  FROM public.system_config
  WHERE key IN ('laundry_merchant_gp_rate_default', 'laundry_delivery_gp_rate_default');

  SELECT COALESCE(p_quote_expires_minutes, p.laundry_quote_expiry_minutes, 60),
         COALESCE(p_platform_gp_rate, p.laundry_merchant_gp_rate, p.laundry_gp_rate, v_default_merchant_gp_rate, 0.1000),
         COALESCE(p.laundry_delivery_gp_rate, v_default_delivery_gp_rate, 0)
  INTO v_expiry_minutes, v_merchant_gp_rate, v_delivery_gp_rate
  FROM public.profiles p
  WHERE p.id = v_merchant_id;

  v_expiry_minutes := GREATEST(5, LEAST(COALESCE(v_expiry_minutes, 60), 1440));
  v_merchant_gp_rate := GREATEST(0, LEAST(COALESCE(v_merchant_gp_rate, 0.1000), 1));
  v_delivery_gp_rate := GREATEST(0, LEAST(COALESCE(v_delivery_gp_rate, 0), 1));
  v_laundry_amount := ROUND(p_laundry_amount::numeric, 2);
  v_delivery_fee_outbound := ROUND(COALESCE(p_delivery_fee_outbound, 0)::numeric, 2);
  v_platform_gp_amount := ROUND((v_laundry_amount * v_merchant_gp_rate)::numeric, 2);
  v_merchant_net_amount := ROUND((v_laundry_amount - v_platform_gp_amount)::numeric, 2);
  v_delivery_gp_amount_outbound := ROUND((v_delivery_fee_outbound * v_delivery_gp_rate)::numeric, 2);
  v_delivery_net_amount_outbound := ROUND((v_delivery_fee_outbound - v_delivery_gp_amount_outbound)::numeric, 2);

  UPDATE public.laundry_orders
  SET status = 'quoted',
      quote_message = p_quote_message,
      laundry_amount = v_laundry_amount,
      delivery_fee_outbound = v_delivery_fee_outbound,
      platform_gp_rate = v_merchant_gp_rate,
      platform_gp_amount = v_platform_gp_amount,
      merchant_net_amount = v_merchant_net_amount,
      laundry_merchant_gp_rate = v_merchant_gp_rate,
      laundry_delivery_gp_rate = v_delivery_gp_rate,
      delivery_gp_amount_outbound = v_delivery_gp_amount_outbound,
      delivery_net_amount_outbound = v_delivery_net_amount_outbound,
      quote_expires_at = now() + make_interval(mins => v_expiry_minutes),
      quoted_at = now(),
      updated_at = now()
  WHERE id = p_laundry_order_id;

  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (
    v_order.customer_id,
    'ร้านซักผ้าส่งราคาประเมินแล้ว',
    'กรุณาตรวจสอบและยืนยัน quote ก่อนหมดอายุ',
    'laundry.quote_ready',
    jsonb_build_object('laundry_order_id', p_laundry_order_id)
  );

  RETURN jsonb_build_object(
    'success', true,
    'laundry_order_id', p_laundry_order_id,
    'quote_expires_at', now() + make_interval(mins => v_expiry_minutes),
    'laundry_amount', v_laundry_amount,
    'delivery_fee_outbound', v_delivery_fee_outbound,
    'platform_gp_rate', v_merchant_gp_rate,
    'platform_gp_amount', v_platform_gp_amount,
    'merchant_net_amount', v_merchant_net_amount,
    'laundry_merchant_gp_rate', v_merchant_gp_rate,
    'laundry_delivery_gp_rate', v_delivery_gp_rate,
    'delivery_gp_amount_outbound', v_delivery_gp_amount_outbound,
    'delivery_net_amount_outbound', v_delivery_net_amount_outbound
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.merchant_send_laundry_quote(uuid, numeric, text, integer, numeric, numeric) TO authenticated;

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
  v_actor_id uuid := auth.uid();
  v_actor_role text := COALESCE(auth.role(), '');
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

  SELECT
    id,
    driver_id,
    service_type,
    status,
    payment_method,
    laundry_order_id,
    laundry_leg,
    return_payment_method,
    pickup_evidence_url,
    pickup_evidence_uploaded_at
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

  IF v_booking.driver_id IS DISTINCT FROM p_driver_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  IF v_actor_role <> 'service_role' AND v_actor_id IS DISTINCT FROM p_driver_id THEN
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

  IF v_booking.status <> 'in_transit' THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_status', 'status', v_booking.status);
  END IF;

  IF v_booking.pickup_evidence_url IS NULL
      OR BTRIM(v_booking.pickup_evidence_url) = ''
      OR v_booking.pickup_evidence_uploaded_at IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'pickup_evidence_required');
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
    v_app_earnings := ROUND((COALESCE(v_order.platform_gp_amount, 0) + COALESCE(v_order.delivery_gp_amount_outbound, 0))::numeric, 2);
    v_driver_earnings := ROUND((
      CASE
        WHEN v_order.laundry_delivery_gp_rate IS NULL THEN COALESCE(v_order.delivery_fee_outbound, 0)
        ELSE COALESCE(v_order.delivery_net_amount_outbound, 0)
      END
    )::numeric, 2);
    v_next_order_status := 'at_merchant';

    IF COALESCE(v_order.payment_method, v_booking.payment_method, 'wallet') = 'wallet' THEN
      v_wallet_credit := ROUND(
        (COALESCE(v_order.merchant_net_amount, 0) + v_driver_earnings)::numeric,
        2
      );
      v_tx_type := 'laundry_payout';
      v_tx_description := 'Laundry outbound payout #' || LEFT(v_order.id::text, 8) || ' including merchant net';
    ELSIF COALESCE(v_order.payment_method, v_booking.payment_method, 'wallet') = 'cash' THEN
      v_wallet_credit := 0;
      v_tx_description := 'Laundry outbound cash completion #' || LEFT(v_order.id::text, 8);
    ELSE
      RETURN jsonb_build_object('success', false, 'error', 'invalid_payment_method');
    END IF;
  ELSIF v_booking.laundry_leg = 'return' THEN
    v_driver_earnings := ROUND((
      CASE
        WHEN v_order.laundry_delivery_gp_rate IS NULL THEN COALESCE(v_order.delivery_fee_return, 0)
        ELSE COALESCE(v_order.delivery_net_amount_return, 0)
      END
    )::numeric, 2);
    v_app_earnings := ROUND(COALESCE(v_order.delivery_gp_amount_return, 0)::numeric, 2);
    v_next_order_status := 'completed';

    IF COALESCE(v_booking.return_payment_method, v_order.return_payment_method, 'cash') = 'wallet' THEN
      v_wallet_credit := v_driver_earnings;
      v_tx_type := 'release';
      v_tx_description := 'Laundry return delivery release #' || LEFT(v_order.id::text, 8);
    ELSIF COALESCE(v_booking.return_payment_method, v_order.return_payment_method, 'cash') = 'cash' THEN
      v_wallet_credit := 0;
      v_tx_description := 'Laundry return cash completion #' || LEFT(v_order.id::text, 8);
    ELSE
      RETURN jsonb_build_object('success', false, 'error', 'invalid_return_payment_method');
    END IF;
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'invalid_laundry_leg');
  END IF;

  IF v_wallet_credit > 0 THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.wallet_transactions wt
      JOIN public.wallets w ON w.id = wt.wallet_id
      WHERE w.user_id = p_driver_id
        AND wt.related_booking_id = p_booking_id::text
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
    'order_status', v_next_order_status,
    'wallet_credit', v_wallet_credit,
    'driver_earnings', v_driver_earnings,
    'app_earnings', v_app_earnings,
    'wallet_result', v_wallet_result
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.complete_laundry_booking(uuid, uuid) TO authenticated, service_role;

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
  v_delivery_fee_return numeric;
  v_delivery_gp_rate numeric;
  v_delivery_gp_amount_return numeric;
  v_delivery_net_amount_return numeric;
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

  IF v_order.status NOT IN ('washing', 'ready_for_return') THEN
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

  v_delivery_fee_return := ROUND(COALESCE(p_delivery_fee_return, 0)::numeric, 2);

  IF v_delivery_fee_return < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_delivery_fee');
  END IF;

  v_delivery_gp_rate := GREATEST(0, LEAST(COALESCE(v_order.laundry_delivery_gp_rate, 0), 1));
  v_delivery_gp_amount_return := ROUND((v_delivery_fee_return * v_delivery_gp_rate)::numeric, 2);
  v_delivery_net_amount_return := ROUND((v_delivery_fee_return - v_delivery_gp_amount_return)::numeric, 2);

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
    v_delivery_fee_return,
    v_delivery_fee_return,
    'pending',
    v_payment_method,
    'Laundry return #' || LEFT(v_order.id::text, 8),
    v_order.id,
    'return',
    v_payment_method
  )
  RETURNING id INTO v_booking_id;

  IF v_payment_method = 'wallet' AND v_delivery_fee_return > 0 THEN
    INSERT INTO public.wallets (user_id, balance)
    VALUES (v_order.customer_id, 0)
    ON CONFLICT (user_id) DO NOTHING;

    SELECT id, balance
    INTO v_wallet_id, v_old_balance
    FROM public.wallets
    WHERE user_id = v_order.customer_id
    FOR UPDATE;

    IF v_old_balance < v_delivery_fee_return THEN
      DELETE FROM public.bookings WHERE id = v_booking_id;
      RETURN jsonb_build_object(
        'success', false,
        'error', 'insufficient_balance',
        'balance', v_old_balance,
        'required', v_delivery_fee_return
      );
    END IF;

    v_new_balance := v_old_balance - v_delivery_fee_return;

    UPDATE public.wallets
    SET balance = v_new_balance, updated_at = now()
    WHERE id = v_wallet_id;

    INSERT INTO public.wallet_transactions (
      wallet_id, amount, type, description, related_booking_id
    )
    VALUES (
      v_wallet_id,
      -v_delivery_fee_return,
      'hold',
      'พักยอดค่าส่งผ้ากลับ #' || LEFT(v_order.id::text, 8),
      v_booking_id
    )
    RETURNING id INTO v_hold_tx_id;
  END IF;

  UPDATE public.laundry_orders
  SET status = 'return_pending',
      delivery_fee_return = v_delivery_fee_return,
      delivery_gp_amount_return = v_delivery_gp_amount_return,
      delivery_net_amount_return = v_delivery_net_amount_return,
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
    'return_wallet_hold_transaction_id', v_hold_tx_id,
    'laundry_delivery_gp_rate', v_delivery_gp_rate,
    'delivery_gp_amount_return', v_delivery_gp_amount_return,
    'delivery_net_amount_return', v_delivery_net_amount_return
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_laundry_return_booking(uuid, numeric, text) TO authenticated, service_role;
