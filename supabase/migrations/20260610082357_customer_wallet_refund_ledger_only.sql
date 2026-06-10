-- Guard customer wallet refunds so refund amount is always derived from the
-- original wallet payment ledger, never from booking price or prior refund rows.

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
    AND wt.related_booking_id = p_booking_id;

  IF COALESCE(v_wallet_payment_amount, 0) <= 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'wallet_payment_not_found',
      'booking_id', p_booking_id
    );
  END IF;

  IF ABS(p_amount - v_wallet_payment_amount) > 0.01 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'wallet_refund_amount_mismatch',
      'booking_id', p_booking_id,
      'requested_amount', p_amount,
      'wallet_payment_amount', v_wallet_payment_amount
    );
  END IF;

  SELECT COALESCE(SUM(ABS(wt.amount)), 0)
  INTO v_existing_refund_amount
  FROM public.wallet_transactions wt
  WHERE wt.wallet_id = v_wallet_id
    AND wt.type = 'refund'
    AND wt.related_booking_id = p_booking_id;

  IF v_existing_refund_amount > 0 THEN
    IF ABS(v_existing_refund_amount - v_wallet_payment_amount) > 0.01 THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'refund_reconciliation_required',
        'booking_id', p_booking_id,
        'wallet_id', v_wallet_id,
        'existing_refund_amount', v_existing_refund_amount,
        'wallet_payment_amount', v_wallet_payment_amount
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

  v_new_balance := v_old_balance + v_wallet_payment_amount;

  UPDATE public.wallets
  SET balance = v_new_balance, updated_at = now()
  WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (
    wallet_id, amount, type, description, related_booking_id
  )
  VALUES (
    v_wallet_id,
    v_wallet_payment_amount,
    'refund',
    COALESCE(p_description, 'คืนเงินออเดอร์ #' || LEFT(p_booking_id::text, 8)),
    p_booking_id
  )
  RETURNING id INTO v_tx_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'wallet_id', v_wallet_id,
    'transaction_id', v_tx_id,
    'old_balance', v_old_balance,
    'new_balance', v_new_balance,
    'amount', v_wallet_payment_amount
  );
END;
$$;

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
    WHERE wt.related_booking_id = p_booking_id
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

REVOKE EXECUTE ON FUNCTION public.refund_booking_to_customer_wallet(uuid, numeric, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.refund_booking_to_customer_wallet(uuid, numeric, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.refund_booking_to_customer_wallet(uuid, numeric, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.refund_booking_to_customer_wallet(uuid, numeric, text) TO service_role;

REVOKE EXECUTE ON FUNCTION public.cancel_wallet_booking_with_refund(uuid, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.cancel_wallet_booking_with_refund(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.cancel_wallet_booking_with_refund(uuid, text) TO authenticated;
