-- ============================================================
-- Phase 2: Financial Atomicity — Atomic Wallet RPC Functions
-- ============================================================
-- Replaces read-then-write wallet operations with atomic
-- Postgres functions that run inside a single transaction.
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- 1) wallet_deduct — Atomic deduction with balance check
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.wallet_deduct(
  p_user_id uuid,
  p_amount numeric,
  p_description text DEFAULT '',
  p_type text DEFAULT 'commission',
  p_related_booking_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_wallet_id uuid;
  v_old_balance numeric;
  v_new_balance numeric;
  v_tx_id uuid;
BEGIN
  -- Lock the wallet row for update (prevents race conditions)
  SELECT id, balance INTO v_wallet_id, v_old_balance
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'wallet_not_found');
  END IF;

  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_amount');
  END IF;

  v_new_balance := v_old_balance - p_amount;

  -- Allow negative balance (business decision: don't block completed orders)
  -- but log a warning
  UPDATE public.wallets
  SET balance = v_new_balance, updated_at = now()
  WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (wallet_id, amount, type, description, related_booking_id)
  VALUES (v_wallet_id, -p_amount, p_type, p_description, p_related_booking_id)
  RETURNING id INTO v_tx_id;

  RETURN jsonb_build_object(
    'success', true,
    'wallet_id', v_wallet_id,
    'old_balance', v_old_balance,
    'new_balance', v_new_balance,
    'transaction_id', v_tx_id
  );
END;
$$;

-- ────────────────────────────────────────────────────────────
-- 2) wallet_topup — Atomic top-up
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.wallet_topup(
  p_user_id uuid,
  p_amount numeric,
  p_description text DEFAULT 'เติมเงินเข้ากระเป๋า',
  p_type text DEFAULT 'topup',
  p_related_booking_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_wallet_id uuid;
  v_old_balance numeric;
  v_new_balance numeric;
  v_tx_id uuid;
BEGIN
  -- Lock the wallet row
  SELECT id, balance INTO v_wallet_id, v_old_balance
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  -- Auto-create wallet if not exists
  IF v_wallet_id IS NULL THEN
    INSERT INTO public.wallets (user_id, balance)
    VALUES (p_user_id, 0)
    RETURNING id, balance INTO v_wallet_id, v_old_balance;
  END IF;

  IF p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_amount');
  END IF;

  v_new_balance := v_old_balance + p_amount;

  UPDATE public.wallets
  SET balance = v_new_balance, updated_at = now()
  WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (wallet_id, amount, type, description, related_booking_id)
  VALUES (v_wallet_id, p_amount, p_type, p_description, p_related_booking_id)
  RETURNING id INTO v_tx_id;

  RETURN jsonb_build_object(
    'success', true,
    'wallet_id', v_wallet_id,
    'old_balance', v_old_balance,
    'new_balance', v_new_balance,
    'transaction_id', v_tx_id
  );
END;
$$;

-- ────────────────────────────────────────────────────────────
-- 3) wallet_adjust — Admin adjustment (positive or negative)
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.wallet_adjust(
  p_user_id uuid,
  p_amount numeric,
  p_description text DEFAULT 'Admin adjustment'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_wallet_id uuid;
  v_old_balance numeric;
  v_new_balance numeric;
  v_tx_id uuid;
BEGIN
  SELECT id, balance INTO v_wallet_id, v_old_balance
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    INSERT INTO public.wallets (user_id, balance)
    VALUES (p_user_id, 0)
    RETURNING id, balance INTO v_wallet_id, v_old_balance;
  END IF;

  v_new_balance := v_old_balance + p_amount;

  UPDATE public.wallets
  SET balance = v_new_balance, updated_at = now()
  WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (wallet_id, amount, type, description)
  VALUES (v_wallet_id, p_amount, 'admin_adjustment', p_description)
  RETURNING id INTO v_tx_id;

  RETURN jsonb_build_object(
    'success', true,
    'wallet_id', v_wallet_id,
    'old_balance', v_old_balance,
    'new_balance', v_new_balance,
    'transaction_id', v_tx_id
  );
END;
$$;

-- ────────────────────────────────────────────────────────────
-- 4) approve_topup_request — Atomic topup approval
--    Checks status=pending, updates request, credits wallet
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.approve_topup_request(
  p_request_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_amount numeric;
  v_status text;
  v_wallet_result jsonb;
BEGIN
  -- Lock and fetch the request
  SELECT user_id, amount, status INTO v_user_id, v_amount, v_status
  FROM public.topup_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'request_not_found');
  END IF;

  IF v_status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'error', 'already_processed', 'current_status', v_status);
  END IF;

  -- Update request status
  UPDATE public.topup_requests
  SET status = 'completed', processed_at = now(), updated_at = now()
  WHERE id = p_request_id;

  -- Credit wallet atomically
  v_wallet_result := public.wallet_topup(v_user_id, v_amount, 'เติมเงินผ่าน Admin (฿' || v_amount || ')');

  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'amount', v_amount,
    'wallet', v_wallet_result
  );
END;
$$;

-- ────────────────────────────────────────────────────────────
-- 5) reject_topup_request — Atomic topup rejection
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.reject_topup_request(
  p_request_id uuid,
  p_reason text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_status text;
BEGIN
  SELECT status INTO v_status
  FROM public.topup_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF v_status IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'request_not_found');
  END IF;

  IF v_status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'error', 'already_processed', 'current_status', v_status);
  END IF;

  UPDATE public.topup_requests
  SET status = 'rejected', admin_note = p_reason, processed_at = now(), updated_at = now()
  WHERE id = p_request_id;

  RETURN jsonb_build_object('success', true);
END;
$$;

-- ────────────────────────────────────────────────────────────
-- 6) approve_withdrawal_request — Atomic withdrawal approval
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.approve_withdrawal_request(
  p_request_id uuid,
  p_transfer_slip_url text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_amount numeric;
  v_status text;
BEGIN
  SELECT user_id, amount, status INTO v_user_id, v_amount, v_status
  FROM public.withdrawal_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'request_not_found');
  END IF;

  IF v_status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'error', 'already_processed', 'current_status', v_status);
  END IF;

  UPDATE public.withdrawal_requests
  SET status = 'completed',
      processed_at = now(),
      transfer_slip_url = COALESCE(p_transfer_slip_url, transfer_slip_url)
  WHERE id = p_request_id;

  -- Balance was already deducted when the withdrawal was created
  -- No wallet operation needed here

  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'amount', v_amount
  );
END;
$$;

-- ────────────────────────────────────────────────────────────
-- 7) reject_withdrawal_request — Atomic rejection + refund
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.reject_withdrawal_request(
  p_request_id uuid,
  p_reason text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id uuid;
  v_amount numeric;
  v_status text;
  v_wallet_result jsonb;
BEGIN
  SELECT user_id, amount, status INTO v_user_id, v_amount, v_status
  FROM public.withdrawal_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'request_not_found');
  END IF;

  IF v_status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'error', 'already_processed', 'current_status', v_status);
  END IF;

  UPDATE public.withdrawal_requests
  SET status = 'rejected', admin_note = p_reason, processed_at = now()
  WHERE id = p_request_id;

  -- Refund the amount back to wallet
  v_wallet_result := public.wallet_topup(
    v_user_id, v_amount,
    'คืนเงินจากคำขอถอนที่ถูกปฏิเสธ: ' || COALESCE(p_reason, ''),
    'refund'
  );

  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'amount', v_amount,
    'wallet', v_wallet_result
  );
END;
$$;

-- ────────────────────────────────────────────────────────────
-- 8) complete_booking — Atomic booking completion
--    Settlement-first: deduct commission THEN update status
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.complete_booking(
  p_booking_id uuid,
  p_driver_id uuid,
  p_commission_amount numeric DEFAULT 0,
  p_driver_earnings numeric DEFAULT 0,
  p_app_earnings numeric DEFAULT 0,
  p_description text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_status text;
  v_wallet_result jsonb;
BEGIN
  -- Lock the booking
  SELECT status INTO v_status
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF v_status IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  -- Allow completion only from expected pre-completion states
  IF v_status NOT IN ('in_transit', 'arrived', 'picking_up_order', 'driver_accepted', 'ready_for_pickup', 'arrived_at_merchant') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_status', 'current_status', v_status);
  END IF;

  -- Step 1: Deduct commission (settlement first)
  IF p_commission_amount > 0 THEN
    v_wallet_result := public.wallet_deduct(
      p_driver_id, p_commission_amount,
      COALESCE(p_description, 'หักค่าบริการระบบ ออเดอร์ ' || LEFT(p_booking_id::text, 8)),
      'commission', p_booking_id
    );

    IF NOT (v_wallet_result->>'success')::boolean THEN
      -- Settlement failed — do NOT complete the booking
      RETURN jsonb_build_object(
        'success', false,
        'error', 'settlement_failed',
        'wallet_error', v_wallet_result->>'error'
      );
    END IF;
  END IF;

  -- Step 2: Update booking status to completed (only after settlement succeeds)
  UPDATE public.bookings
  SET status = 'completed',
      completed_at = now(),
      driver_earnings = p_driver_earnings,
      app_earnings = p_app_earnings,
      updated_at = now()
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'wallet', COALESCE(v_wallet_result, '{}'::jsonb)
  );
END;
$$;

-- ────────────────────────────────────────────────────────────
-- 9) accept_booking — Optimistic concurrency for job assignment
--    Only succeeds if booking has no driver and expected status
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.accept_booking(
  p_booking_id uuid,
  p_driver_id uuid,
  p_expected_status text DEFAULT 'pending'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_rows_affected integer;
BEGIN
  UPDATE public.bookings
  SET driver_id = p_driver_id,
      status = 'driver_accepted',
      assigned_at = now(),
      updated_at = now()
  WHERE id = p_booking_id
    AND driver_id IS NULL
    AND status = p_expected_status;

  GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

  IF v_rows_affected = 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'already_taken',
      'message', 'งานนี้ถูกรับไปแล้ว หรือสถานะเปลี่ยนไปแล้ว'
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'booking_id', p_booking_id);
END;
$$;

-- ────────────────────────────────────────────────────────────
-- 10) Nearby drivers function (Haversine) — Phase 5 prereq
-- ────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.get_nearby_drivers(
  p_lat double precision,
  p_lng double precision,
  p_radius_km double precision DEFAULT 10.0,
  p_limit integer DEFAULT 50
)
RETURNS TABLE (
  driver_id uuid,
  full_name text,
  phone_number text,
  license_plate text,
  vehicle_type text,
  latitude double precision,
  longitude double precision,
  distance_km double precision,
  fcm_token text
)
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT
    dl.driver_id,
    p.full_name,
    p.phone_number,
    p.license_plate,
    p.vehicle_type,
    dl.latitude,
    dl.longitude,
    (6371 * acos(
      LEAST(1.0, cos(radians(p_lat)) * cos(radians(dl.latitude))
        * cos(radians(dl.longitude) - radians(p_lng))
        + sin(radians(p_lat)) * sin(radians(dl.latitude)))
    )) AS distance_km,
    p.fcm_token
  FROM public.driver_locations dl
  JOIN public.profiles p ON p.id = dl.driver_id
  WHERE dl.is_online = true
    AND dl.is_available = true
    AND p.role = 'driver'
    AND p.approval_status = 'approved'
    AND dl.latitude IS NOT NULL
    AND dl.longitude IS NOT NULL
    AND (6371 * acos(
      LEAST(1.0, cos(radians(p_lat)) * cos(radians(dl.latitude))
        * cos(radians(dl.longitude) - radians(p_lng))
        + sin(radians(p_lat)) * sin(radians(dl.latitude)))
    )) <= p_radius_km
  ORDER BY distance_km ASC
  LIMIT p_limit;
$$;

-- Grant execute to authenticated users and service role
GRANT EXECUTE ON FUNCTION public.wallet_deduct TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.wallet_topup TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.wallet_adjust TO service_role;
GRANT EXECUTE ON FUNCTION public.approve_topup_request TO service_role;
GRANT EXECUTE ON FUNCTION public.reject_topup_request TO service_role;
GRANT EXECUTE ON FUNCTION public.approve_withdrawal_request TO service_role;
GRANT EXECUTE ON FUNCTION public.reject_withdrawal_request TO service_role;
GRANT EXECUTE ON FUNCTION public.complete_booking TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.accept_booking TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_nearby_drivers TO authenticated, service_role;
