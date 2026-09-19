-- ═══════════════════════════════════════════════════════════════
-- Batch 0 — ปิดช่องโหว่เงิน/ออเดอร์ (W2 + RPC lockdown)
--
-- พบบน production (2026-09-20):
--  - wallets: ผู้ใช้ UPDATE balance ของตัวเองได้ (2 policy)
--  - wallet_transactions: ผู้ใช้ INSERT ledger ของตัวเองได้
--  - withdrawal_requests: ผู้ใช้ INSERT คำขอเอง (ไม่ถูกหักเงิน) และแก้คำขอ pending ได้ (เช่นเพิ่มยอด)
--  - bookings: "Allow all updates" (ALL, public, true) + "Allow all selects" (anon อ่านทุกออเดอร์)
--              + "Allow drivers to update bookings they accepted" (USING true)
--  - RPC SECURITY DEFINER ที่ PUBLIC/anon เรียกได้โดยไม่ตรวจสิทธิ์:
--      wallet_adjust (เสกเงินเข้ากระเป๋าใครก็ได้), wallet_deduct (ดูดเงินใครก็ได้),
--      approve/reject_withdrawal_request (ไม่เช็คแอดมิน), complete_booking (ปิดงาน/หักเงินใครก็ได้),
--      create_wallet_withdrawal_request / customer_wallet_pay_booking (ข้ามเช็คเมื่อ auth.uid() เป็น NULL = anon)
--
-- แก้: เขียนเงินผ่าน RPC เท่านั้น + ตรวจสิทธิ์ใน RPC + ถอดสิทธิ์ anon
-- ═══════════════════════════════════════════════════════════════

BEGIN;

-- 1) Policies -----------------------------------------------------------
DROP POLICY IF EXISTS "Users can update own wallet balance" ON public.wallets;
DROP POLICY IF EXISTS "wallets_update_own" ON public.wallets;

DROP POLICY IF EXISTS "Users can insert own transactions" ON public.wallet_transactions;
DROP POLICY IF EXISTS "wallet_tx_insert" ON public.wallet_transactions;
CREATE POLICY "wallet_tx_insert" ON public.wallet_transactions
  FOR INSERT TO authenticated
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Users can insert own withdrawal requests" ON public.withdrawal_requests;
DROP POLICY IF EXISTS "withdrawal_insert_own" ON public.withdrawal_requests;
DROP POLICY IF EXISTS "withdrawal_update_own" ON public.withdrawal_requests;

-- สถานะ cancelled (ผู้ใช้ยกเลิกเอง) — แอปแสดงสถานะนี้อยู่แล้วแต่ constraint เดิมไม่อนุญาต
ALTER TABLE public.withdrawal_requests DROP CONSTRAINT IF EXISTS withdrawal_requests_status_check;
ALTER TABLE public.withdrawal_requests ADD CONSTRAINT withdrawal_requests_status_check
  CHECK (status IN ('pending', 'approved', 'rejected', 'completed', 'cancelled'));

DROP POLICY IF EXISTS "Allow all updates on bookings" ON public.bookings;
DROP POLICY IF EXISTS "Allow all selects on bookings" ON public.bookings;
DROP POLICY IF EXISTS "Allow drivers to update bookings they accepted" ON public.bookings;

-- 2) wallet_deduct: หักได้เฉพาะกระเป๋าตัวเอง (หรือแอดมิน / service role) -------
CREATE OR REPLACE FUNCTION public.wallet_deduct(
  p_user_id uuid,
  p_amount numeric,
  p_description text DEFAULT ''::text,
  p_type text DEFAULT 'commission'::text,
  p_related_booking_id uuid DEFAULT NULL::uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_wallet_id uuid;
  v_old_balance numeric;
  v_new_balance numeric;
  v_tx_id uuid;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_user_id AND NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  SELECT id, balance INTO v_wallet_id, v_old_balance
  FROM public.wallets
  WHERE user_id = p_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'wallet_not_found');
  END IF;

  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_amount');
  END IF;

  v_new_balance := v_old_balance - p_amount;

  -- Allow negative balance (business decision: don't block completed orders)
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
$function$;

-- 3) complete_booking: เฉพาะคนขับของออเดอร์นั้น (หรือแอดมิน / service role) ------
CREATE OR REPLACE FUNCTION public.complete_booking(
  p_booking_id uuid,
  p_driver_id uuid,
  p_commission_amount numeric DEFAULT 0,
  p_driver_earnings numeric DEFAULT 0,
  p_app_earnings numeric DEFAULT 0,
  p_description text DEFAULT ''::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_status text;
  v_driver_id uuid;
  v_wallet_result jsonb;
BEGIN
  SELECT status, driver_id INTO v_status, v_driver_id
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF v_status IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF auth.uid() IS NOT NULL AND NOT public.is_admin() THEN
    IF auth.uid() <> p_driver_id OR v_driver_id IS DISTINCT FROM p_driver_id THEN
      RETURN jsonb_build_object('success', false, 'error', 'forbidden');
    END IF;
  END IF;

  IF v_status NOT IN ('in_transit', 'arrived', 'picking_up_order', 'driver_accepted', 'ready_for_pickup', 'arrived_at_merchant') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_status', 'current_status', v_status);
  END IF;

  IF p_commission_amount > 0 THEN
    v_wallet_result := public.wallet_deduct(
      p_driver_id, p_commission_amount,
      COALESCE(p_description, 'หักค่าบริการระบบ ออเดอร์ ' || LEFT(p_booking_id::text, 8)),
      'commission', p_booking_id
    );

    IF NOT (v_wallet_result->>'success')::boolean THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'settlement_failed',
        'wallet_error', v_wallet_result->>'error'
      );
    END IF;
  END IF;

  UPDATE public.bookings
  SET status = 'completed',
      status_origin = 'jdc',
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
$function$;

-- 4) approve / reject withdrawal: แอดมินเท่านั้น ---------------------------
CREATE OR REPLACE FUNCTION public.approve_withdrawal_request(
  p_request_id uuid,
  p_transfer_slip_url text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_user_id uuid;
  v_amount numeric;
  v_status text;
BEGIN
  IF auth.uid() IS NOT NULL AND NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

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

  -- เงินถูกหักตอนสร้างคำขอแล้ว (create_wallet_withdrawal_request)
  RETURN jsonb_build_object('success', true, 'user_id', v_user_id, 'amount', v_amount);
END;
$function$;

CREATE OR REPLACE FUNCTION public.reject_withdrawal_request(
  p_request_id uuid,
  p_reason text DEFAULT ''::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_user_id uuid;
  v_amount numeric;
  v_status text;
  v_wallet_result jsonb;
BEGIN
  IF auth.uid() IS NOT NULL AND NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

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

  v_wallet_result := public.wallet_topup(
    v_user_id, v_amount,
    'คืนเงินจากคำขอถอนที่ถูกปฏิเสธ: ' || COALESCE(p_reason, ''),
    'refund'
  );

  IF COALESCE((v_wallet_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'withdrawal_refund_failed: %', COALESCE(v_wallet_result->>'error', 'unknown');
  END IF;

  RETURN jsonb_build_object('success', true, 'user_id', v_user_id, 'amount', v_amount, 'wallet', v_wallet_result);
END;
$function$;

-- 5) ผู้ใช้ยกเลิกคำขอถอนของตัวเอง (แทนการเขียนตารางตรงจากแอป) -------------
CREATE OR REPLACE FUNCTION public.cancel_wallet_withdrawal_request(p_request_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_uid uuid := auth.uid();
  v_req record;
  v_wallet_result jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT id, user_id, amount, status INTO v_req
  FROM public.withdrawal_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF NOT FOUND OR v_req.user_id <> v_uid THEN
    RETURN jsonb_build_object('success', false, 'error', 'request_not_found');
  END IF;

  IF v_req.status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'error', 'already_processed', 'current_status', v_req.status);
  END IF;

  UPDATE public.withdrawal_requests
  SET status = 'cancelled', processed_at = now()
  WHERE id = p_request_id;

  v_wallet_result := public.wallet_topup(
    v_uid, v_req.amount,
    'ยกเลิกคำขอถอนเงิน #' || LEFT(p_request_id::text, 8),
    'withdrawal_refund'
  );

  IF COALESCE((v_wallet_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'withdrawal_refund_failed: %', COALESCE(v_wallet_result->>'error', 'unknown');
  END IF;

  RETURN jsonb_build_object('success', true, 'amount', v_req.amount, 'wallet', v_wallet_result);
END;
$function$;

-- 6) EXECUTE privileges: ไม่มี RPC เงินตัวไหนให้ anon/PUBLIC ------------------
REVOKE ALL ON FUNCTION public.wallet_adjust(uuid, numeric, text) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.wallet_adjust(uuid, numeric, text) TO service_role;

REVOKE ALL ON FUNCTION public.wallet_deduct(uuid, numeric, text, text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.wallet_deduct(uuid, numeric, text, text, uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.complete_booking(uuid, uuid, numeric, numeric, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_booking(uuid, uuid, numeric, numeric, numeric, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.approve_withdrawal_request(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.approve_withdrawal_request(uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.reject_withdrawal_request(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reject_withdrawal_request(uuid, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.cancel_wallet_withdrawal_request(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_wallet_withdrawal_request(uuid) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.create_wallet_withdrawal_request(uuid, numeric, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_wallet_withdrawal_request(uuid, numeric, text, text, text) TO authenticated, service_role;

REVOKE ALL ON FUNCTION public.customer_wallet_pay_booking(uuid, uuid, numeric, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.customer_wallet_pay_booking(uuid, uuid, numeric, text) TO authenticated, service_role;

DO $$
BEGIN
  IF to_regprocedure('public.complete_laundry_booking(uuid, uuid)') IS NOT NULL THEN
    EXECUTE 'REVOKE ALL ON FUNCTION public.complete_laundry_booking(uuid, uuid) FROM PUBLIC, anon';
    EXECUTE 'GRANT EXECUTE ON FUNCTION public.complete_laundry_booking(uuid, uuid) TO authenticated, service_role';
  END IF;
END $$;

COMMIT;
