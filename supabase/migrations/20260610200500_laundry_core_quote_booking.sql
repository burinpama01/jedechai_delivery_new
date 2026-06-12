BEGIN;

ALTER TABLE IF EXISTS public.profiles
  ADD COLUMN IF NOT EXISTS merchant_service_types text[],
  ADD COLUMN IF NOT EXISTS laundry_quote_expiry_minutes integer DEFAULT 60,
  ADD COLUMN IF NOT EXISTS laundry_gp_rate numeric(6,4) DEFAULT 0.1000;

ALTER TABLE IF EXISTS public.profiles
  DROP CONSTRAINT IF EXISTS profiles_laundry_quote_expiry_minutes_check,
  ADD CONSTRAINT profiles_laundry_quote_expiry_minutes_check
    CHECK (laundry_quote_expiry_minutes IS NULL OR laundry_quote_expiry_minutes BETWEEN 5 AND 1440);

ALTER TABLE IF EXISTS public.profiles
  DROP CONSTRAINT IF EXISTS profiles_laundry_gp_rate_check,
  ADD CONSTRAINT profiles_laundry_gp_rate_check
    CHECK (laundry_gp_rate IS NULL OR (laundry_gp_rate >= 0 AND laundry_gp_rate <= 1));

CREATE TABLE IF NOT EXISTS public.laundry_packages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name text NOT NULL,
  description text,
  base_price numeric(12,2) NOT NULL DEFAULT 0 CHECK (base_price >= 0),
  unit text NOT NULL DEFAULT 'piece',
  is_active boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_laundry_packages_merchant_active
  ON public.laundry_packages (merchant_id, is_active, sort_order);

ALTER TABLE public.laundry_packages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "laundry packages are visible to authenticated users" ON public.laundry_packages;
CREATE POLICY "laundry packages are visible to authenticated users"
  ON public.laundry_packages
  FOR SELECT
  TO authenticated
  USING (is_active OR merchant_id = auth.uid());

DROP POLICY IF EXISTS "laundry merchants manage own packages" ON public.laundry_packages;
CREATE POLICY "laundry merchants manage own packages"
  ON public.laundry_packages
  FOR ALL
  TO authenticated
  USING (merchant_id = auth.uid())
  WITH CHECK (merchant_id = auth.uid());

CREATE TABLE IF NOT EXISTS public.laundry_orders (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  customer_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  merchant_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  package_id uuid REFERENCES public.laundry_packages(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'quote_requested'
    CHECK (status IN (
      'quote_requested',
      'quoted',
      'quote_expired',
      'quote_rejected',
      'outbound_pending',
      'outbound_assigned',
      'outbound_picked_up',
      'at_merchant',
      'washing',
      'ready_for_return',
      'return_pending',
      'return_assigned',
      'return_picked_up',
      'completed',
      'cancelled'
    )),
  requested_items jsonb NOT NULL DEFAULT '[]'::jsonb,
  attachment_urls jsonb NOT NULL DEFAULT '[]'::jsonb,
  customer_note text,
  merchant_note text,
  quote_message text,
  quote_expires_at timestamptz,
  quoted_at timestamptz,
  accepted_at timestamptz,
  pickup_lat double precision NOT NULL,
  pickup_lng double precision NOT NULL,
  pickup_address text NOT NULL,
  laundry_amount numeric(12,2),
  delivery_fee_outbound numeric(12,2) NOT NULL DEFAULT 0,
  delivery_fee_return numeric(12,2) NOT NULL DEFAULT 0,
  platform_gp_rate numeric(6,4) NOT NULL DEFAULT 0,
  platform_gp_amount numeric(12,2) NOT NULL DEFAULT 0,
  merchant_net_amount numeric(12,2) NOT NULL DEFAULT 0,
  payment_method text CHECK (payment_method IS NULL OR payment_method IN ('wallet')),
  outbound_booking_id uuid REFERENCES public.bookings(id) ON DELETE SET NULL,
  return_booking_id uuid REFERENCES public.bookings(id) ON DELETE SET NULL,
  return_mode text NOT NULL DEFAULT 'delivery' CHECK (return_mode IN ('delivery', 'self_pickup')),
  return_payment_method text NOT NULL DEFAULT 'cash' CHECK (return_payment_method IN ('cash', 'wallet')),
  return_wallet_hold_transaction_id uuid,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CHECK (jsonb_typeof(requested_items) = 'array'),
  CHECK (jsonb_typeof(attachment_urls) = 'array'),
  CHECK (laundry_amount IS NULL OR laundry_amount >= 0),
  CHECK (delivery_fee_outbound >= 0),
  CHECK (delivery_fee_return >= 0),
  CHECK (platform_gp_amount >= 0),
  CHECK (merchant_net_amount >= 0)
);

CREATE INDEX IF NOT EXISTS idx_laundry_orders_customer_created
  ON public.laundry_orders (customer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_laundry_orders_merchant_status
  ON public.laundry_orders (merchant_id, status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_laundry_orders_outbound_booking
  ON public.laundry_orders (outbound_booking_id);
CREATE INDEX IF NOT EXISTS idx_laundry_orders_return_booking
  ON public.laundry_orders (return_booking_id);

ALTER TABLE public.laundry_orders ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "laundry orders are visible to related users" ON public.laundry_orders;
CREATE POLICY "laundry orders are visible to related users"
  ON public.laundry_orders
  FOR SELECT
  TO authenticated
  USING (
    customer_id = auth.uid()
    OR merchant_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.role = 'admin'
    )
  );

DROP POLICY IF EXISTS "laundry customers create own orders" ON public.laundry_orders;
CREATE POLICY "laundry customers create own orders"
  ON public.laundry_orders
  FOR INSERT
  TO authenticated
  WITH CHECK (customer_id = auth.uid());

DROP POLICY IF EXISTS "laundry related users update through guarded flows" ON public.laundry_orders;
CREATE POLICY "laundry related users update through guarded flows"
  ON public.laundry_orders
  FOR UPDATE
  TO authenticated
  USING (
    customer_id = auth.uid()
    OR merchant_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.role = 'admin'
    )
  )
  WITH CHECK (
    customer_id = auth.uid()
    OR merchant_id = auth.uid()
    OR EXISTS (
      SELECT 1
      FROM public.profiles p
      WHERE p.id = auth.uid()
        AND p.role = 'admin'
    )
  );

ALTER TABLE IF EXISTS public.bookings
  ADD COLUMN IF NOT EXISTS laundry_order_id uuid REFERENCES public.laundry_orders(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS laundry_leg text,
  ADD COLUMN IF NOT EXISTS pickup_evidence_url text,
  ADD COLUMN IF NOT EXISTS pickup_evidence_uploaded_at timestamptz,
  ADD COLUMN IF NOT EXISTS platform_gp_amount numeric(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS merchant_net_amount numeric(12,2) NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS return_payment_method text;

ALTER TABLE IF EXISTS public.bookings
  DROP CONSTRAINT IF EXISTS bookings_laundry_leg_check,
  ADD CONSTRAINT bookings_laundry_leg_check
    CHECK (laundry_leg IS NULL OR laundry_leg IN ('outbound', 'return'));

ALTER TABLE IF EXISTS public.bookings
  DROP CONSTRAINT IF EXISTS bookings_return_payment_method_check,
  ADD CONSTRAINT bookings_return_payment_method_check
    CHECK (return_payment_method IS NULL OR return_payment_method IN ('cash', 'wallet'));

ALTER TABLE IF EXISTS public.bookings
  DROP CONSTRAINT IF EXISTS bookings_service_type_check,
  ADD CONSTRAINT bookings_service_type_check
    CHECK (service_type IN ('ride', 'food', 'parcel', 'laundry'));

CREATE INDEX IF NOT EXISTS idx_bookings_laundry_order_leg
  ON public.bookings (laundry_order_id, laundry_leg);

INSERT INTO public.service_rates (service_type, base_price, base_distance, price_per_km)
VALUES ('laundry', 0, 0, 0)
ON CONFLICT (service_type) DO NOTHING;

CREATE OR REPLACE FUNCTION public.create_laundry_quote_request(
  p_merchant_id uuid,
  p_pickup_lat double precision,
  p_pickup_lng double precision,
  p_pickup_address text,
  p_requested_items jsonb DEFAULT '[]'::jsonb,
  p_attachment_urls text[] DEFAULT ARRAY[]::text[],
  p_customer_note text DEFAULT NULL,
  p_package_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_customer_id uuid := auth.uid();
  v_order_id uuid;
BEGIN
  IF v_customer_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  IF p_merchant_id IS NULL
    OR p_pickup_lat IS NULL
    OR p_pickup_lng IS NULL
    OR NULLIF(BTRIM(p_pickup_address), '') IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'missing_required_fields');
  END IF;

  IF jsonb_typeof(COALESCE(p_requested_items, '[]'::jsonb)) <> 'array' THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_requested_items');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = p_merchant_id
      AND p.role = 'merchant'
      AND 'laundry' = ANY(COALESCE(p.merchant_service_types, ARRAY[]::text[]))
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'merchant_not_laundry');
  END IF;

  IF p_package_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1
      FROM public.laundry_packages lp
      WHERE lp.id = p_package_id
        AND lp.merchant_id = p_merchant_id
        AND lp.is_active = true
    ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'package_not_found');
  END IF;

  INSERT INTO public.laundry_orders (
    customer_id,
    merchant_id,
    package_id,
    requested_items,
    attachment_urls,
    customer_note,
    pickup_lat,
    pickup_lng,
    pickup_address
  )
  VALUES (
    v_customer_id,
    p_merchant_id,
    p_package_id,
    COALESCE(p_requested_items, '[]'::jsonb),
    to_jsonb(COALESCE(p_attachment_urls, ARRAY[]::text[])),
    p_customer_note,
    p_pickup_lat,
    p_pickup_lng,
    BTRIM(p_pickup_address)
  )
  RETURNING id INTO v_order_id;

  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (
    p_merchant_id,
    'มีคำขอประเมินราคาซักผ้าใหม่',
    'ลูกค้าส่งคำขอประเมินราคาซักผ้า รหัส #' || LEFT(v_order_id::text, 8),
    'laundry.quote_requested',
    jsonb_build_object('laundry_order_id', v_order_id)
  );

  RETURN jsonb_build_object('success', true, 'laundry_order_id', v_order_id);
END;
$$;

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
  v_gp_rate numeric;
  v_platform_gp_amount numeric;
  v_merchant_net_amount numeric;
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

  SELECT COALESCE(p_quote_expires_minutes, p.laundry_quote_expiry_minutes, 60),
         COALESCE(p_platform_gp_rate, p.laundry_gp_rate, 0.1000)
  INTO v_expiry_minutes, v_gp_rate
  FROM public.profiles p
  WHERE p.id = v_merchant_id;

  v_expiry_minutes := GREATEST(5, LEAST(COALESCE(v_expiry_minutes, 60), 1440));
  v_gp_rate := GREATEST(0, LEAST(COALESCE(v_gp_rate, 0.1000), 1));
  v_platform_gp_amount := ROUND((p_laundry_amount * v_gp_rate)::numeric, 2);
  v_merchant_net_amount := ROUND((p_laundry_amount - v_platform_gp_amount)::numeric, 2);

  UPDATE public.laundry_orders
  SET status = 'quoted',
      quote_message = p_quote_message,
      laundry_amount = ROUND(p_laundry_amount::numeric, 2),
      delivery_fee_outbound = ROUND(COALESCE(p_delivery_fee_outbound, 0)::numeric, 2),
      platform_gp_rate = v_gp_rate,
      platform_gp_amount = v_platform_gp_amount,
      merchant_net_amount = v_merchant_net_amount,
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
    'laundry_amount', ROUND(p_laundry_amount::numeric, 2),
    'delivery_fee_outbound', ROUND(COALESCE(p_delivery_fee_outbound, 0)::numeric, 2),
    'platform_gp_amount', v_platform_gp_amount,
    'merchant_net_amount', v_merchant_net_amount
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.customer_accept_laundry_quote(
  p_laundry_order_id uuid,
  p_payment_method text DEFAULT 'wallet',
  p_return_mode text DEFAULT 'delivery',
  p_return_payment_method text DEFAULT 'cash'
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
BEGIN
  IF v_customer_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  IF COALESCE(p_payment_method, 'wallet') <> 'wallet' THEN
    RETURN jsonb_build_object('success', false, 'error', 'unsupported_payment_method');
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
    'wallet',
    'Laundry outbound #' || LEFT(v_order.id::text, 8),
    v_order.id,
    'outbound',
    v_order.platform_gp_amount,
    v_order.merchant_net_amount,
    p_return_payment_method
  )
  RETURNING id INTO v_booking_id;

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

  UPDATE public.laundry_orders
  SET status = 'outbound_pending',
      accepted_at = now(),
      payment_method = 'wallet',
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
    jsonb_build_object('laundry_order_id', p_laundry_order_id, 'booking_id', v_booking_id, 'laundry_leg', 'outbound')
  );

  RETURN jsonb_build_object(
    'success', true,
    'laundry_order_id', p_laundry_order_id,
    'outbound_booking_id', v_booking_id,
    'wallet_result', v_wallet_result
  );
END;
$$;

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

  IF v_order.return_mode = 'self_pickup' THEN
    UPDATE public.laundry_orders
    SET status = 'ready_for_return',
        updated_at = now()
    WHERE id = p_laundry_order_id;

    RETURN jsonb_build_object('success', true, 'self_pickup', true, 'laundry_order_id', p_laundry_order_id);
  END IF;

  IF v_order.return_booking_id IS NOT NULL THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_created', true,
      'return_booking_id', v_order.return_booking_id
    );
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

CREATE OR REPLACE FUNCTION public.driver_confirm_laundry_pickup(
  p_booking_id uuid,
  p_evidence_url text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid := auth.uid();
  v_booking record;
  v_next_order_status text;
BEGIN
  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  IF NULLIF(BTRIM(COALESCE(p_evidence_url, '')), '') IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'pickup_evidence_required');
  END IF;

  SELECT id, driver_id, service_type, status, laundry_order_id, laundry_leg
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

  IF v_booking.driver_id <> v_driver_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  IF v_booking.laundry_leg NOT IN ('outbound', 'return') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_laundry_leg');
  END IF;

  UPDATE public.bookings
  SET status = 'in_progress',
      pickup_evidence_url = BTRIM(p_evidence_url),
      pickup_evidence_uploaded_at = now(),
      updated_at = now()
  WHERE id = p_booking_id;

  v_next_order_status := CASE
    WHEN v_booking.laundry_leg = 'outbound' THEN 'outbound_picked_up'
    ELSE 'return_picked_up'
  END;

  UPDATE public.laundry_orders
  SET status = v_next_order_status,
      updated_at = now()
  WHERE id = v_booking.laundry_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'laundry_order_id', v_booking.laundry_order_id,
    'status', v_next_order_status
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.get_nearby_bookings(
  p_driver_lat double precision,
  p_driver_lng double precision,
  p_radius_km double precision DEFAULT 20.0,
  p_service_types text[] DEFAULT NULL
)
RETURNS SETOF public.bookings
LANGUAGE sql
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT b.*
  FROM public.bookings b
  WHERE b.driver_id IS NULL
    AND b.status IN ('pending', 'ready_for_pickup', 'preparing')
    AND b.origin_lat IS NOT NULL
    AND b.origin_lng IS NOT NULL
    AND (
      p_service_types IS NULL
      OR b.service_type = ANY(p_service_types)
    )
    AND (
      b.service_type <> 'laundry'
      OR (service_type = 'laundry' AND laundry_leg IN ('outbound', 'return'))
    )
    AND (
      6371 * acos(
        LEAST(
          1,
          GREATEST(
            -1,
            cos(radians(p_driver_lat)) * cos(radians(b.origin_lat)) *
            cos(radians(b.origin_lng) - radians(p_driver_lng)) +
            sin(radians(p_driver_lat)) * sin(radians(b.origin_lat))
          )
        )
      )
    ) <= p_radius_km
  ORDER BY (
    6371 * acos(
      LEAST(
        1,
        GREATEST(
          -1,
          cos(radians(p_driver_lat)) * cos(radians(b.origin_lat)) *
          cos(radians(b.origin_lng) - radians(p_driver_lng)) +
          sin(radians(p_driver_lat)) * sin(radians(b.origin_lat))
        )
      )
    )
  ) ASC, b.created_at ASC;
$$;

GRANT SELECT, INSERT, UPDATE, DELETE ON public.laundry_packages TO authenticated, service_role;
GRANT SELECT, INSERT, UPDATE ON public.laundry_orders TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_laundry_quote_request(uuid, double precision, double precision, text, jsonb, text[], text, uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.merchant_send_laundry_quote(uuid, numeric, text, integer, numeric, numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.customer_accept_laundry_quote(uuid, text, text, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.create_laundry_return_booking(uuid, numeric, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.driver_confirm_laundry_pickup(uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_nearby_bookings(double precision, double precision, double precision, text[]) TO authenticated;

COMMIT;
