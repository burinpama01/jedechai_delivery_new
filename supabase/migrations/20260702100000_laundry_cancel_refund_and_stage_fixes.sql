-- Laundry cancel/refund and stage fixes:
-- 1) refund_booking_to_customer_wallet + cancel_wallet_booking_with_refund:
--    ledger lookups compared text = uuid (wallet_transactions.related_booking_id
--    is text in production) which fails at runtime; the 20260610220000 patch
--    never covered these. Recreated with ::text casts, keeping the ledger-only
--    hardening and additionally accepting 'hold' ledger rows for laundry
--    return-leg refunds.
-- 2) admin_force_cancel_booking_with_wallet_refund: same text = uuid runtime bug,
--    plus it never refunded the laundry return-leg wallet 'hold' and never synced
--    public.laundry_orders when a laundry booking was force-cancelled.
-- 3) merchant_update_laundry_status: allow closing self_pickup orders
--    (ready_for_return -> completed). Previously self_pickup orders could never
--    reach 'completed'.
-- 4) merchant_send_laundry_quote: allow re-quoting after 'quote_expired' so an
--    expired quote is not a dead end.
-- 5) complete_laundry_booking: cash completions now deduct the platform GP from
--    the driver wallet ('commission', like food) instead of recording
--    app_earnings without any real settlement. The driver collects the full
--    cash amount and pays the merchant net in cash at the shop.

-- Keeps the ledger-only hardening from 20260610082357 (amount derived from and
-- validated against the original wallet ledger, reconciliation guard on prior
-- refunds) while also accepting 'hold' ledger rows so laundry return-leg holds
-- can be refunded, and fixing the text = uuid comparisons.
CREATE OR REPLACE FUNCTION public.refund_booking_to_customer_wallet(
  p_booking_id uuid,
  p_amount numeric,
  p_description text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_customer_id uuid;
  v_wallet_id uuid;
  v_old_balance numeric;
  v_new_balance numeric;
  v_tx_id uuid;
  v_wallet_payment_amount numeric := 0;
  v_wallet_hold_amount numeric := 0;
  v_ledger_amount numeric := 0;
  v_existing_refund_amount numeric := 0;
BEGIN
  IF p_booking_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'missing_booking_id');
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_amount');
  END IF;

  SELECT customer_id
  INTO v_customer_id
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF v_customer_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  SELECT id, balance
  INTO v_wallet_id, v_old_balance
  FROM public.wallets
  WHERE user_id = v_customer_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'wallet_payment_not_found',
      'booking_id', p_booking_id
    );
  END IF;

  SELECT COALESCE(SUM(ABS(wt.amount)), 0)
  INTO v_wallet_payment_amount
  FROM public.wallet_transactions wt
  WHERE wt.wallet_id = v_wallet_id
    AND wt.type = 'payment'
    AND wt.amount < 0
    AND wt.related_booking_id = p_booking_id::text;

  SELECT COALESCE(SUM(ABS(wt.amount)), 0)
  INTO v_wallet_hold_amount
  FROM public.wallet_transactions wt
  WHERE wt.wallet_id = v_wallet_id
    AND wt.type = 'hold'
    AND wt.amount < 0
    AND wt.related_booking_id = p_booking_id::text;

  v_ledger_amount := CASE
    WHEN COALESCE(v_wallet_payment_amount, 0) > 0 THEN v_wallet_payment_amount
    ELSE COALESCE(v_wallet_hold_amount, 0)
  END;

  IF v_ledger_amount <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'wallet_payment_not_found',
      'booking_id', p_booking_id
    );
  END IF;

  IF ABS(p_amount - v_ledger_amount) > 0.01 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'wallet_refund_amount_mismatch',
      'booking_id', p_booking_id,
      'requested_amount', p_amount,
      'wallet_payment_amount', v_ledger_amount
    );
  END IF;

  SELECT COALESCE(SUM(ABS(wt.amount)), 0)
  INTO v_existing_refund_amount
  FROM public.wallet_transactions wt
  WHERE wt.wallet_id = v_wallet_id
    AND wt.type = 'refund'
    AND wt.related_booking_id = p_booking_id::text;

  IF v_existing_refund_amount > 0 THEN
    IF ABS(v_existing_refund_amount - v_ledger_amount) > 0.01 THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'refund_reconciliation_required',
        'booking_id', p_booking_id,
        'wallet_id', v_wallet_id,
        'existing_refund_amount', v_existing_refund_amount,
        'wallet_payment_amount', v_ledger_amount
      );
    END IF;

    RETURN jsonb_build_object(
      'success', false,
      'error', 'already_refunded',
      'booking_id', p_booking_id,
      'wallet_id', v_wallet_id,
      'balance', v_old_balance,
      'amount', v_existing_refund_amount
    );
  END IF;

  v_new_balance := v_old_balance + v_ledger_amount;

  UPDATE public.wallets
  SET balance = v_new_balance, updated_at = now()
  WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (
    wallet_id, amount, type, description, related_booking_id
  )
  VALUES (
    v_wallet_id,
    v_ledger_amount,
    'refund',
    COALESCE(p_description, 'คืนเงินออเดอร์ #' || LEFT(p_booking_id::text, 8)),
    p_booking_id::text
  )
  RETURNING id INTO v_tx_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'wallet_id', v_wallet_id,
    'transaction_id', v_tx_id,
    'old_balance', v_old_balance,
    'new_balance', v_new_balance,
    'amount', v_ledger_amount
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.refund_booking_to_customer_wallet(uuid, numeric, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.refund_booking_to_customer_wallet(uuid, numeric, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.refund_booking_to_customer_wallet(uuid, numeric, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.refund_booking_to_customer_wallet(uuid, numeric, text) TO service_role;

-- Same text = uuid runtime bug existed in the customer self-cancel path; the
-- 20260610220000 runtime patch never covered this function. Identical body to
-- 20260610082357 except the ::text cast on the ledger lookup.
CREATE OR REPLACE FUNCTION public.cancel_wallet_booking_with_refund(
  p_booking_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid := auth.uid();
  v_booking record;
  v_refund_amount numeric := 0;
  v_refund_result jsonb := NULL;
BEGIN
  IF v_auth_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  SELECT
    id,
    customer_id,
    status,
    service_type,
    payment_method
  INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF v_booking.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF v_booking.customer_id <> v_auth_uid THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  IF NOT (v_booking.status = ANY (ARRAY['pending', 'pending_merchant', 'preparing'])) THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_cancellable');
  END IF;

  IF lower(COALESCE(v_booking.payment_method, '')) = 'wallet' THEN
    SELECT COALESCE(SUM(ABS(wt.amount)), 0)
    INTO v_refund_amount
    FROM public.wallet_transactions wt
    JOIN public.wallets w ON w.id = wt.wallet_id
    WHERE wt.related_booking_id = p_booking_id::text
      AND wt.type = 'payment'
      AND wt.amount < 0
      AND w.user_id = v_booking.customer_id;

    IF COALESCE(v_refund_amount, 0) <= 0 THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'wallet_payment_not_found',
        'booking_id', p_booking_id
      );
    END IF;

    v_refund_result := public.refund_booking_to_customer_wallet(
      p_booking_id,
      v_refund_amount,
      'คืนเงินจากการยกเลิกออเดอร์'
    );

    IF COALESCE((v_refund_result->>'success')::boolean, false) IS NOT TRUE
      AND COALESCE(v_refund_result->>'error', '') <> 'already_refunded' THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'wallet_refund_failed',
        'booking_id', p_booking_id,
        'refund', v_refund_result
      );
    END IF;
  END IF;

  UPDATE public.bookings
  SET
    status = 'cancelled',
    cancellation_reason = COALESCE(p_reason, ''),
    notes = COALESCE(p_reason, notes),
    updated_at = now()
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'refunded', v_refund_result IS NOT NULL,
    'refund_amount', v_refund_amount,
    'refund', v_refund_result
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.cancel_wallet_booking_with_refund(uuid, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.cancel_wallet_booking_with_refund(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.cancel_wallet_booking_with_refund(uuid, text) TO authenticated;

CREATE OR REPLACE FUNCTION public.admin_force_cancel_booking_with_wallet_refund(
  p_booking_id uuid,
  p_reason text DEFAULT NULL,
  p_do_refund boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_booking record;
  v_payment_amount numeric := 0;
  v_hold_amount numeric := 0;
  v_refund_amount numeric := 0;
  v_refund_result jsonb;
  v_should_refund boolean := false;
BEGIN
  IF p_booking_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'missing_booking_id');
  END IF;

  SELECT id, customer_id, status, payment_method, service_type, laundry_order_id, laundry_leg
  INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  v_should_refund := p_do_refund IS TRUE
    AND lower(COALESCE(v_booking.payment_method, '')) = 'wallet';

  IF v_should_refund THEN
    SELECT ABS(wt.amount)
    INTO v_payment_amount
    FROM public.wallet_transactions wt
    JOIN public.wallets w ON w.id = wt.wallet_id
    WHERE w.user_id = v_booking.customer_id
      AND wt.type = 'payment'
      AND wt.amount < 0
      AND wt.related_booking_id = p_booking_id::text
    LIMIT 1;

    -- Laundry return-leg delivery fees are deducted as a wallet 'hold', not a
    -- 'payment'. Refund the hold when the booking is cancelled before release.
    SELECT ABS(wt.amount)
    INTO v_hold_amount
    FROM public.wallet_transactions wt
    JOIN public.wallets w ON w.id = wt.wallet_id
    WHERE w.user_id = v_booking.customer_id
      AND wt.type = 'hold'
      AND wt.amount < 0
      AND wt.related_booking_id = p_booking_id::text
    LIMIT 1;

    v_refund_amount := COALESCE(NULLIF(COALESCE(v_payment_amount, 0), 0), COALESCE(v_hold_amount, 0));

    IF v_refund_amount <= 0 THEN
      -- Laundry return legs with a zero delivery fee never create a hold, so
      -- there is legitimately nothing to refund; other wallet bookings without
      -- a ledger entry indicate a data problem and must fail loudly.
      IF v_booking.service_type = 'laundry' AND v_booking.laundry_leg = 'return' THEN
        v_should_refund := false;
      ELSE
        RETURN jsonb_build_object(
          'success', false,
          'error', 'wallet_payment_not_found',
          'booking_id', p_booking_id
        );
      END IF;
    END IF;

    IF v_should_refund THEN
      IF COALESCE(v_payment_amount, 0) <= 0
        AND COALESCE(v_hold_amount, 0) > 0
        AND EXISTS (
          SELECT 1
          FROM public.wallet_transactions wt
          WHERE wt.related_booking_id = p_booking_id::text
            AND wt.type = 'release'
        )
      THEN
        RETURN jsonb_build_object(
          'success', false,
          'error', 'hold_already_released',
          'booking_id', p_booking_id
        );
      END IF;

      SELECT public.refund_booking_to_customer_wallet(
        p_booking_id,
        v_refund_amount,
        'คืนเงินจากยกเลิกออเดอร์ #' || LEFT(p_booking_id::text, 8) || ' (Admin)'
      )
      INTO v_refund_result;

      IF COALESCE((v_refund_result->>'success')::boolean, false) IS NOT TRUE
        AND COALESCE(v_refund_result->>'error', '') <> 'already_refunded'
      THEN
        RETURN jsonb_build_object(
          'success', false,
          'error', COALESCE(v_refund_result->>'error', 'wallet_refund_failed'),
          'booking_id', p_booking_id,
          'refund_result', v_refund_result
        );
      END IF;
    END IF;
  END IF;

  IF v_booking.status <> 'cancelled' THEN
    UPDATE public.bookings
    SET
      status = 'cancelled',
      cancellation_reason = 'admin_force_cancel: ' || COALESCE(p_reason, ''),
      updated_at = now()
    WHERE id = p_booking_id;
  END IF;

  -- Keep the laundry order state machine in sync with the cancelled booking.
  IF v_booking.service_type = 'laundry' AND v_booking.laundry_order_id IS NOT NULL THEN
    IF v_booking.laundry_leg = 'outbound' THEN
      UPDATE public.laundry_orders
      SET status = 'cancelled',
          updated_at = now()
      WHERE id = v_booking.laundry_order_id
        AND status IN ('outbound_pending', 'outbound_assigned', 'outbound_picked_up');
    ELSIF v_booking.laundry_leg = 'return' THEN
      UPDATE public.laundry_orders
      SET status = 'ready_for_return',
          return_booking_id = NULL,
          return_wallet_hold_transaction_id = NULL,
          updated_at = now()
      WHERE id = v_booking.laundry_order_id
        AND status IN ('return_pending', 'return_assigned', 'return_picked_up');
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'cancelled', true,
    'refunded', v_should_refund,
    'refund_amount', CASE WHEN v_should_refund THEN v_refund_amount ELSE 0 END,
    'refund_result', v_refund_result
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_force_cancel_booking_with_wallet_refund(uuid, text, boolean) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_force_cancel_booking_with_wallet_refund(uuid, text, boolean) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_force_cancel_booking_with_wallet_refund(uuid, text, boolean) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_force_cancel_booking_with_wallet_refund(uuid, text, boolean) TO service_role;

CREATE OR REPLACE FUNCTION public.merchant_update_laundry_status(
  p_laundry_order_id uuid,
  p_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_order public.laundry_orders%ROWTYPE;
BEGIN
  IF v_actor_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  IF COALESCE(p_status, '') NOT IN ('washing', 'completed') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_laundry_stage');
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

  IF p_status = 'washing' AND v_order.status <> 'at_merchant' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'invalid_laundry_stage',
      'status', v_order.status
    );
  END IF;

  -- 'completed' via this RPC is only for self_pickup orders where the customer
  -- collects at the shop, so no return booking (and no driver leg) exists.
  IF p_status = 'completed'
    AND NOT (v_order.return_mode = 'self_pickup' AND v_order.status = 'ready_for_return')
  THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'invalid_laundry_stage',
      'status', v_order.status
    );
  END IF;

  UPDATE public.laundry_orders
  SET status = p_status,
      updated_at = now()
  WHERE id = p_laundry_order_id;

  IF p_status = 'completed' THEN
    INSERT INTO public.notifications (user_id, title, body, type, data)
    VALUES (
      v_order.customer_id,
      'ปิดงานซักผ้าแล้ว',
      'ร้านยืนยันว่าคุณรับผ้าคืนแล้ว รหัส #' || LEFT(v_order.id::text, 8),
      'laundry.completed',
      jsonb_build_object('laundry_order_id', p_laundry_order_id)
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'laundry_order_id', p_laundry_order_id,
    'status', p_status
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.merchant_update_laundry_status(uuid, text) TO authenticated, service_role;

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
  v_default_driver_gp_rate numeric := 0;
  v_merchant_gp_rate numeric;
  v_delivery_gp_rate numeric;
  v_laundry_gp_driver_raw_rate numeric;
  v_laundry_gp_driver_rate numeric;
  v_laundry_amount numeric;
  v_delivery_fee_outbound numeric;
  v_platform_gp_amount numeric;
  v_merchant_net_amount numeric;
  v_laundry_driver_gp_amount numeric;
  v_laundry_system_gp_amount numeric;
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

  -- 'quote_expired' is allowed so merchants can re-send a fresh quote instead of
  -- the order dead-ending after the expiry cron fires.
  IF v_order.status NOT IN ('quote_requested', 'quoted', 'quote_expired') THEN
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
    ),
    COALESCE(
      MAX(CASE WHEN key = 'laundry_gp_driver_rate_default' AND value ~ '^[0-9]+(\.[0-9]+)?$' THEN value::numeric END),
      0
    )
  INTO v_default_merchant_gp_rate, v_default_delivery_gp_rate, v_default_driver_gp_rate
  FROM public.system_config
  WHERE key IN (
    'laundry_merchant_gp_rate_default',
    'laundry_delivery_gp_rate_default',
    'laundry_gp_driver_rate_default'
  );

  SELECT COALESCE(p_quote_expires_minutes, p.laundry_quote_expiry_minutes, 60),
         COALESCE(p_platform_gp_rate, p.laundry_merchant_gp_rate, p.laundry_gp_rate, v_default_merchant_gp_rate, 0.1000),
         COALESCE(p.laundry_delivery_gp_rate, v_default_delivery_gp_rate, 0),
         COALESCE(p.laundry_gp_driver_rate, v_default_driver_gp_rate, 0)
  INTO v_expiry_minutes, v_merchant_gp_rate, v_delivery_gp_rate, v_laundry_gp_driver_raw_rate
  FROM public.profiles p
  WHERE p.id = v_merchant_id;

  v_expiry_minutes := GREATEST(5, LEAST(COALESCE(v_expiry_minutes, 60), 1440));
  v_merchant_gp_rate := GREATEST(0, LEAST(COALESCE(v_merchant_gp_rate, 0.1000), 1));
  v_delivery_gp_rate := GREATEST(0, LEAST(COALESCE(v_delivery_gp_rate, 0), 1));
  v_laundry_gp_driver_rate := GREATEST(0, LEAST(v_merchant_gp_rate, COALESCE(v_laundry_gp_driver_raw_rate, 0)));
  v_laundry_amount := ROUND(p_laundry_amount::numeric, 2);
  v_delivery_fee_outbound := ROUND(COALESCE(p_delivery_fee_outbound, 0)::numeric, 2);
  v_platform_gp_amount := ROUND((v_laundry_amount * v_merchant_gp_rate)::numeric, 2);
  v_laundry_driver_gp_amount := ROUND((v_laundry_amount * v_laundry_gp_driver_rate)::numeric, 2);
  v_laundry_driver_gp_amount := LEAST(v_laundry_driver_gp_amount, v_platform_gp_amount);
  v_laundry_system_gp_amount := ROUND((v_platform_gp_amount - v_laundry_driver_gp_amount)::numeric, 2);
  v_merchant_net_amount := ROUND((v_laundry_amount - v_platform_gp_amount)::numeric, 2);
  v_delivery_gp_amount_outbound := ROUND((v_delivery_fee_outbound * v_delivery_gp_rate)::numeric, 2);
  v_delivery_net_amount_outbound := ROUND((v_delivery_fee_outbound - v_delivery_gp_amount_outbound)::numeric, 2);

  UPDATE public.laundry_orders
  SET status = 'quoted',
      quote_message = p_quote_message,
      laundry_amount = v_laundry_amount,
      delivery_fee_outbound = v_delivery_fee_outbound,
      platform_gp_amount = v_platform_gp_amount,
      merchant_net_amount = v_merchant_net_amount,
      laundry_merchant_gp_rate = v_merchant_gp_rate,
      laundry_delivery_gp_rate = v_delivery_gp_rate,
      laundry_gp_driver_rate = v_laundry_gp_driver_rate,
      laundry_driver_gp_amount = v_laundry_driver_gp_amount,
      laundry_system_gp_amount = v_laundry_system_gp_amount,
      delivery_gp_amount_outbound = v_delivery_gp_amount_outbound,
      delivery_net_amount_outbound = v_delivery_net_amount_outbound,
      quote_expires_at = now() + make_interval(mins => v_expiry_minutes),
      quoted_at = now(),
      updated_at = now()
  WHERE id = p_laundry_order_id;

  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (
    v_order.customer_id,
    'ร้านซักผ้าส่งราคาแล้ว',
    'ร้านซักผ้าส่งราคาให้ตรวจสอบและยืนยัน',
    'laundry.quote_sent',
    jsonb_build_object('laundry_order_id', p_laundry_order_id, 'merchant_id', v_merchant_id)
  );

  RETURN jsonb_build_object(
    'success', true,
    'laundry_order_id', p_laundry_order_id,
    'laundry_amount', v_laundry_amount,
    'delivery_fee_outbound', v_delivery_fee_outbound,
    'platform_gp_amount', v_platform_gp_amount,
    'merchant_net_amount', v_merchant_net_amount,
    'laundry_merchant_gp_rate', v_merchant_gp_rate,
    'laundry_delivery_gp_rate', v_delivery_gp_rate,
    'laundry_gp_driver_rate', v_laundry_gp_driver_rate,
    'laundry_driver_gp_amount', v_laundry_driver_gp_amount,
    'laundry_system_gp_amount', v_laundry_system_gp_amount,
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
  v_existing_commission boolean := false;
  v_wallet_credit numeric := 0;
  v_cash_commission numeric := 0;
  v_driver_earnings numeric := 0;
  v_app_earnings numeric := 0;
  v_delivery_net_earnings numeric := 0;
  v_laundry_driver_bonus numeric := 0;
  v_tx_type text := 'laundry_payout';
  v_tx_description text;
  v_wallet_result jsonb := '{}'::jsonb;
  v_deduct_result jsonb := '{}'::jsonb;
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
    v_app_earnings := ROUND((
      CASE WHEN v_order.laundry_gp_driver_rate IS NULL THEN COALESCE(v_order.platform_gp_amount, 0)
           ELSE COALESCE(v_order.laundry_system_gp_amount, 0)
      END + COALESCE(v_order.delivery_gp_amount_outbound, 0)
    )::numeric, 2);
    v_delivery_net_earnings := ROUND((
      CASE
        WHEN v_order.laundry_delivery_gp_rate IS NULL THEN COALESCE(v_order.delivery_fee_outbound, 0)
        ELSE COALESCE(v_order.delivery_net_amount_outbound, 0)
      END
    )::numeric, 2);
    v_laundry_driver_bonus := ROUND((
      CASE
        WHEN v_order.laundry_gp_driver_rate IS NULL THEN 0
        ELSE COALESCE(v_order.laundry_driver_gp_amount, 0)
      END
    )::numeric, 2);
    v_driver_earnings := ROUND((v_delivery_net_earnings + v_laundry_driver_bonus)::numeric, 2);
    v_next_order_status := 'at_merchant';

    IF COALESCE(v_order.payment_method, v_booking.payment_method, 'wallet') = 'wallet' THEN
      v_wallet_credit := ROUND(
        (COALESCE(v_order.merchant_net_amount, 0) + v_driver_earnings)::numeric,
        2
      );
      v_tx_type := 'laundry_payout';
      v_tx_description := 'Laundry outbound payout #' || LEFT(v_order.id::text, 8) || ' including merchant net';
    ELSIF COALESCE(v_order.payment_method, v_booking.payment_method, 'wallet') = 'cash' THEN
      -- Cash: the driver collected laundry_amount + delivery fee in cash and
      -- pays the merchant net in cash at the shop, so the platform GP must be
      -- deducted from the driver wallet like food cash orders.
      v_wallet_credit := 0;
      v_cash_commission := v_app_earnings;
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
      v_cash_commission := v_app_earnings;
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

  IF v_cash_commission > 0 THEN
    SELECT EXISTS (
      SELECT 1
      FROM public.wallet_transactions wt
      JOIN public.wallets w ON w.id = wt.wallet_id
      WHERE w.user_id = p_driver_id
        AND wt.related_booking_id = p_booking_id::text
        AND wt.type = 'commission'
    )
    INTO v_existing_commission;

    IF NOT v_existing_commission THEN
      v_deduct_result := public.wallet_deduct(
        p_driver_id,
        v_cash_commission,
        'หักค่าบริการระบบ laundry #' || LEFT(v_order.id::text, 8),
        'commission',
        p_booking_id
      );

      IF COALESCE((v_deduct_result->>'success')::boolean, false) IS NOT TRUE THEN
        RETURN jsonb_build_object(
          'success', false,
          'error', 'commission_deduct_failed',
          'wallet_result', v_deduct_result
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
    'cash_commission', v_cash_commission,
    'driver_earnings', v_driver_earnings,
    'app_earnings', v_app_earnings,
    'wallet_result', v_wallet_result,
    'commission_result', v_deduct_result
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.complete_laundry_booking(uuid, uuid) TO authenticated, service_role;
