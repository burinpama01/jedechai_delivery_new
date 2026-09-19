-- ISSUE-101: ยกเลิกคำขอถอนเงินซ้ำได้ → คืนเงินเข้า wallet หลายรอบ
--
-- ปัญหาเดิม: WithdrawalService.cancelWithdrawalRequest() ทำงานฝั่งแอปแบบ
-- read-modify-write (อ่าน request ที่ status='pending' → อ่าน balance →
-- เขียน balance = balance + amount → เขียน status='cancelled') โดย
--   1) ไม่ได้ล็อกแถว จึงกดยกเลิกซ้ำเร็ว ๆ แล้วอ่านเจอ 'pending' ได้ทั้งสอง
--      request → คืนเงินสองรอบ
--   2) UPDATE สถานะไม่มีเงื่อนไข status='pending' จึงไม่กันการยิงซ้ำ
--   3) UPDATE balance เป็น lost update ทับยอดหักที่เกิดพร้อมกัน
--
-- แก้โดยย้ายทั้งก้อนมาเป็น RPC เดียวที่ล็อกแถว request ก่อน แล้วเปลี่ยน
-- สถานะแบบมีเงื่อนไข ถ้า ROW_COUNT = 0 แปลว่ามีคนยกเลิกไปแล้ว → ไม่คืนเงิน

CREATE OR REPLACE FUNCTION public.cancel_wallet_withdrawal_request(
  p_request_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid := auth.uid();
  v_user_id uuid;
  v_amount numeric;
  v_status text;
  v_rows_affected integer;
  v_wallet_id uuid;
  v_old_balance numeric;
  v_new_balance numeric;
  v_tx_id uuid;
BEGIN
  IF p_request_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'missing_request_id');
  END IF;

  -- ล็อกคำขอไว้ก่อน เพื่อให้การยิงซ้ำพร้อมกันต้องรอคิว
  SELECT user_id, amount, status
  INTO v_user_id, v_amount, v_status
  FROM public.withdrawal_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'request_not_found');
  END IF;

  IF v_auth_uid IS NOT NULL AND v_auth_uid <> v_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  IF v_status <> 'pending' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'not_cancellable',
      'current_status', v_status
    );
  END IF;

  -- เปลี่ยนสถานะแบบมีเงื่อนไขก่อนคืนเงิน: ผู้ชนะมีได้รายเดียวเท่านั้น
  UPDATE public.withdrawal_requests
  SET status = 'cancelled', updated_at = now()
  WHERE id = p_request_id
    AND status = 'pending';

  GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

  IF v_rows_affected = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_cancellable');
  END IF;

  SELECT id, balance INTO v_wallet_id, v_old_balance
  FROM public.wallets
  WHERE user_id = v_user_id
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    -- ยกเลิกไม่สำเร็จทั้งก้อน (ทั้งฟังก์ชันอยู่ใน transaction เดียว)
    RAISE EXCEPTION 'wallet_not_found for user %', v_user_id;
  END IF;

  v_new_balance := v_old_balance + v_amount;

  UPDATE public.wallets
  SET balance = v_new_balance, updated_at = now()
  WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (
    wallet_id, amount, type, description
  )
  VALUES (
    v_wallet_id,
    v_amount,
    'withdrawal_refund',
    'ยกเลิกคำขอถอนเงิน #' || LEFT(p_request_id::text, 8)
  )
  RETURNING id INTO v_tx_id;

  RETURN jsonb_build_object(
    'success', true,
    'request_id', p_request_id,
    'wallet_id', v_wallet_id,
    'transaction_id', v_tx_id,
    'old_balance', v_old_balance,
    'new_balance', v_new_balance,
    'amount', v_amount
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.cancel_wallet_withdrawal_request(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.cancel_wallet_withdrawal_request(uuid) FROM anon;
GRANT EXECUTE ON FUNCTION public.cancel_wallet_withdrawal_request(uuid) TO authenticated, service_role;
