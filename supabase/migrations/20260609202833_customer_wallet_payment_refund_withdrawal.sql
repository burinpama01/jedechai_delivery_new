-- Customer wallet payment/refund/withdrawal RPCs.
-- These keep customer-facing wallet operations atomic and prevent negative
-- balances for customer payments and withdrawal requests.

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
  v_booking_customer_id uuid;
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

  SELECT customer_id INTO v_booking_customer_id
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF v_booking_customer_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF v_booking_customer_id <> p_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_owner_mismatch');
  END IF;

  INSERT INTO public.wallets (user_id, balance)
  VALUES (p_user_id, 0)
  ON CONFLICT (user_id) DO NOTHING;

  SELECT id, balance INTO v_wallet_id, v_old_balance
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
      'balance', v_old_balance
    );
  END IF;

  IF v_old_balance < p_amount THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'insufficient_balance',
      'balance', v_old_balance,
      'required', p_amount
    );
  END IF;

  v_new_balance := v_old_balance - p_amount;

  UPDATE public.wallets
  SET balance = v_new_balance, updated_at = now()
  WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (
    wallet_id, amount, type, description, related_booking_id
  )
  VALUES (
    v_wallet_id,
    -p_amount,
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
    'amount', p_amount
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.create_wallet_withdrawal_request(
  p_user_id uuid,
  p_amount numeric,
  p_bank_name text,
  p_bank_account_number text,
  p_bank_account_name text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid := auth.uid();
  v_wallet_id uuid;
  v_old_balance numeric;
  v_new_balance numeric;
  v_request_id uuid;
  v_tx_id uuid;
BEGIN
  IF v_auth_uid IS NOT NULL AND v_auth_uid <> p_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  IF p_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'missing_user_id');
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_amount');
  END IF;

  IF p_amount < 100 THEN
    RETURN jsonb_build_object('success', false, 'error', 'minimum_withdrawal_amount', 'minimum', 100);
  END IF;

  IF NULLIF(BTRIM(COALESCE(p_bank_name, '')), '') IS NULL
     OR NULLIF(BTRIM(COALESCE(p_bank_account_number, '')), '') IS NULL
     OR NULLIF(BTRIM(COALESCE(p_bank_account_name, '')), '') IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'missing_bank_account');
  END IF;

  SELECT id, balance INTO v_wallet_id, v_old_balance
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'wallet_not_found');
  END IF;

  IF v_old_balance < p_amount THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'insufficient_balance',
      'balance', v_old_balance,
      'required', p_amount
    );
  END IF;

  INSERT INTO public.withdrawal_requests (
    user_id,
    amount,
    bank_name,
    bank_account_number,
    bank_account_name,
    status,
    created_at,
    updated_at
  )
  VALUES (
    p_user_id,
    p_amount,
    BTRIM(p_bank_name),
    BTRIM(p_bank_account_number),
    BTRIM(p_bank_account_name),
    'pending',
    now(),
    now()
  )
  RETURNING id INTO v_request_id;

  v_new_balance := v_old_balance - p_amount;

  UPDATE public.wallets
  SET balance = v_new_balance, updated_at = now()
  WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (
    wallet_id, amount, type, description
  )
  VALUES (
    v_wallet_id,
    -p_amount,
    'withdrawal_pending',
    'ส่งคำขอถอนเงิน #' || LEFT(v_request_id::text, 8)
  )
  RETURNING id INTO v_tx_id;

  RETURN jsonb_build_object(
    'success', true,
    'request_id', v_request_id,
    'wallet_id', v_wallet_id,
    'transaction_id', v_tx_id,
    'old_balance', v_old_balance,
    'new_balance', v_new_balance,
    'amount', p_amount
  );
END;
$$;

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
BEGIN
  IF p_booking_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'missing_booking_id');
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_amount');
  END IF;

  SELECT customer_id INTO v_customer_id
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF v_customer_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  INSERT INTO public.wallets (user_id, balance)
  VALUES (v_customer_id, 0)
  ON CONFLICT (user_id) DO NOTHING;

  SELECT id, balance INTO v_wallet_id, v_old_balance
  FROM public.wallets
  WHERE user_id = v_customer_id
  FOR UPDATE;

  IF EXISTS (
    SELECT 1
    FROM public.wallet_transactions
    WHERE wallet_id = v_wallet_id
      AND type = 'refund'
      AND related_booking_id = p_booking_id
  ) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'already_refunded',
      'booking_id', p_booking_id,
      'wallet_id', v_wallet_id,
      'balance', v_old_balance
    );
  END IF;

  v_new_balance := v_old_balance + p_amount;

  UPDATE public.wallets
  SET balance = v_new_balance, updated_at = now()
  WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (
    wallet_id, amount, type, description, related_booking_id
  )
  VALUES (
    v_wallet_id,
    p_amount,
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
    'amount', p_amount
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.customer_wallet_pay_booking(uuid, uuid, numeric, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.create_wallet_withdrawal_request(uuid, numeric, text, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.refund_booking_to_customer_wallet(uuid, numeric, text) FROM PUBLIC;

REVOKE EXECUTE ON FUNCTION public.refund_booking_to_customer_wallet(uuid, numeric, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.refund_booking_to_customer_wallet(uuid, numeric, text) FROM authenticated;

GRANT EXECUTE ON FUNCTION public.customer_wallet_pay_booking(uuid, uuid, numeric, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.create_wallet_withdrawal_request(uuid, numeric, text, text, text) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.refund_booking_to_customer_wallet(uuid, numeric, text) TO service_role;
