-- Harden customer wallet payment and admin force-cancel refund paths.
-- This migration supersedes the first customer-wallet RPC version without
-- mutating already-applied migration history.

CREATE OR REPLACE FUNCTION public.customer_wallet_pay_booking(
  p_user_id uuid,
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
  v_auth_uid uuid := auth.uid();
  v_booking record;
  v_coupon_discount numeric := 0;
  v_expected_amount numeric := 0;
  v_wallet_id uuid;
  v_old_balance numeric;
  v_new_balance numeric;
  v_tx_id uuid;
BEGIN
  IF v_auth_uid IS NOT NULL AND v_auth_uid <> p_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  IF p_user_id IS NULL OR p_booking_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'missing_required_fields');
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_amount');
  END IF;

  SELECT id, customer_id, service_type, price, delivery_fee
  INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF v_booking.customer_id <> p_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_owner_mismatch');
  END IF;

  SELECT COALESCE(SUM(discount_amount), 0)
  INTO v_coupon_discount
  FROM public.coupon_usages
  WHERE booking_id = p_booking_id;

  IF v_booking.service_type = 'food' THEN
    v_expected_amount := GREATEST(
      COALESCE(v_booking.price, 0) + COALESCE(v_booking.delivery_fee, 0) - COALESCE(v_coupon_discount, 0),
      0
    );
  ELSE
    v_expected_amount := GREATEST(
      COALESCE(v_booking.price, 0) - COALESCE(v_coupon_discount, 0),
      0
    );
  END IF;

  IF v_expected_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_expected_amount');
  END IF;

  IF ABS(p_amount - v_expected_amount) > 0.01 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'amount_mismatch',
      'expected_amount', v_expected_amount,
      'provided_amount', p_amount
    );
  END IF;

  SELECT id, balance
  INTO v_wallet_id, v_old_balance
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'wallet_not_found');
  END IF;

  IF EXISTS (
    SELECT 1
    FROM public.wallet_transactions
    WHERE wallet_id = v_wallet_id
      AND type = 'payment'
      AND related_booking_id = p_booking_id
  ) THEN
    RETURN jsonb_build_object(
      'success', true,
      'already_paid', true,
      'booking_id', p_booking_id,
      'wallet_id', v_wallet_id,
      'balance', v_old_balance,
      'amount', v_expected_amount
    );
  END IF;

  IF v_old_balance < v_expected_amount THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'insufficient_balance',
      'balance', v_old_balance,
      'required', v_expected_amount
    );
  END IF;

  v_new_balance := v_old_balance - v_expected_amount;

  UPDATE public.wallets
  SET balance = v_new_balance, updated_at = now()
  WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (
    wallet_id, amount, type, description, related_booking_id
  )
  VALUES (
    v_wallet_id,
    -v_expected_amount,
    'payment',
    COALESCE(p_description, 'ชำระค่าออเดอร์ด้วย Wallet #' || LEFT(p_booking_id::text, 8)),
    p_booking_id
  )
  RETURNING id INTO v_tx_id;

  UPDATE public.bookings
  SET payment_method = 'wallet', updated_at = now()
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'wallet_id', v_wallet_id,
    'transaction_id', v_tx_id,
    'old_balance', v_old_balance,
    'new_balance', v_new_balance,
    'amount', v_expected_amount
  );
END;
$$;

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
  v_refund_result jsonb;
  v_should_refund boolean := false;
BEGIN
  IF p_booking_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'missing_booking_id');
  END IF;

  SELECT id, customer_id, status, payment_method
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
      AND wt.related_booking_id = p_booking_id
    LIMIT 1;

    IF COALESCE(v_payment_amount, 0) <= 0 THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'wallet_payment_not_found',
        'booking_id', p_booking_id
      );
    END IF;

    SELECT public.refund_booking_to_customer_wallet(
      p_booking_id,
      v_payment_amount,
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

  IF v_booking.status <> 'cancelled' THEN
    UPDATE public.bookings
    SET
      status = 'cancelled',
      cancellation_reason = 'admin_force_cancel: ' || COALESCE(p_reason, ''),
      updated_at = now()
    WHERE id = p_booking_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'cancelled', true,
    'refunded', v_should_refund,
    'refund_amount', CASE WHEN v_should_refund THEN v_payment_amount ELSE 0 END,
    'refund_result', v_refund_result
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_force_cancel_booking_with_wallet_refund(uuid, text, boolean) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_force_cancel_booking_with_wallet_refund(uuid, text, boolean) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_force_cancel_booking_with_wallet_refund(uuid, text, boolean) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_force_cancel_booking_with_wallet_refund(uuid, text, boolean) TO service_role;
