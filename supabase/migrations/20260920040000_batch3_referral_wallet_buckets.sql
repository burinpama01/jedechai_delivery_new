-- ═══════════════════════════════════════════════════════════════
-- Batch 3 — โปรโมชั่นชวนเพื่อนรับเงินเข้า Wallet (Referral_Wallet_Promotion_Plan_v2)
--
-- กระเป๋า 2 ถัง:
--   wallets.balance          = ยอดรวม (เดิม)
--   wallets.balance_system   = ถัง "จากระบบ" (รางวัล/ชดเชย/payout)
--   ถังเติม = balance − ถังระบบ
-- กติกา (ตัดสินใจแล้ว): ใช้จ่ายหักถังระบบก่อน · ถอนได้ทั้ง 2 ถัง (เติม min 100 / ระบบ min 200)
--   ขอถอน = hold ทันที · แอดมินอนุมัติ manual · ปฏิเสธ/ยกเลิก = คืนเข้าถังเดิม
-- การแยกถังทำใน trigger ของ wallet_transactions → ครอบคลุมทุกฟังก์ชันที่ขยับเงินโดยไม่ต้องแก้ทีละตัว
--   · เงินเข้า: type ถังระบบ = referral_reward, coupon_compensation, laundry_payout, job_payout
--     คืนเงิน (refund/release) ของออเดอร์ = คืนสัดส่วนถังระบบตามรายการที่เคยหักของออเดอร์นั้น
--   · เงินออก: หักถังระบบก่อน (ยกเว้นถอนที่ระบุถัง)
--   · ฟังก์ชันระบุถังเองได้ผ่าน GUC app.wallet_bucket = 'topup' | 'system' (เฉพาะใน transaction)
-- เงินเดิมทั้งหมด (รวม admin_adjustment ทดสอบของเจ้าของ) = ถังเติม, ถังระบบเริ่มที่ 0
--
-- รางวัลชวน (ฐานแอดมินตั้งได้ · default ฿20 · ขั้นบันได 1–5 ×1.0 / 6–15 ×1.25 / 16+ ×1.5):
--   S1 คนขับชวนร้าน (ร้านได้รับอนุมัติ) · S2 ลูกค้าชวนร้าน · S3 คนขับชวนคนขับ (งานแรกของคนขับใหม่ completed)
--   แคป N รายต่อเดือนต่อผู้ชวน → เกินแคป = pending_review ให้แอดมินกดจ่าย
-- ═══════════════════════════════════════════════════════════════

BEGIN;

-- 1) Buckets --------------------------------------------------------------
ALTER TABLE public.wallets
  ADD COLUMN IF NOT EXISTS balance_system numeric NOT NULL DEFAULT 0;
ALTER TABLE public.wallets DROP CONSTRAINT IF EXISTS chk_wallets_balance_system_nonneg;
ALTER TABLE public.wallets ADD CONSTRAINT chk_wallets_balance_system_nonneg CHECK (balance_system >= 0);
COMMENT ON COLUMN public.wallets.balance_system IS 'ถัง "จากระบบ" (รางวัล/ชดเชย/payout) — ถังเติม = balance − balance_system';

ALTER TABLE public.wallet_transactions
  ADD COLUMN IF NOT EXISTS system_amount numeric NOT NULL DEFAULT 0;
COMMENT ON COLUMN public.wallet_transactions.system_amount IS 'ส่วนของรายการนี้ที่เข้า(+)/ออก(−) ถังระบบ';

ALTER TABLE public.withdrawal_requests
  ADD COLUMN IF NOT EXISTS source_bucket text NOT NULL DEFAULT 'topup';
ALTER TABLE public.withdrawal_requests DROP CONSTRAINT IF EXISTS chk_withdrawal_source_bucket;
ALTER TABLE public.withdrawal_requests ADD CONSTRAINT chk_withdrawal_source_bucket
  CHECK (source_bucket IN ('topup', 'system'));

-- ยอดที่ใช้ได้ต่อถัง (balance ติดลบได้จากค่าคอม → ถังระบบใช้ได้ไม่เกินยอดบวก)
CREATE OR REPLACE FUNCTION public.wallet_bucket_balances(p_balance numeric, p_system numeric)
RETURNS TABLE(available_system numeric, available_topup numeric)
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT LEAST(GREATEST(COALESCE(p_system, 0), 0), GREATEST(COALESCE(p_balance, 0), 0)),
         GREATEST(COALESCE(p_balance, 0), 0)
           - LEAST(GREATEST(COALESCE(p_system, 0), 0), GREATEST(COALESCE(p_balance, 0), 0));
$$;

CREATE OR REPLACE FUNCTION public.apply_wallet_tx_bucket()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_bucket text := NULLIF(current_setting('app.wallet_bucket', true), '');
  v_system numeric;
  v_portion numeric := 0;
  v_prev_debit numeric;
BEGIN
  SELECT balance_system INTO v_system FROM public.wallets WHERE id = NEW.wallet_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN NEW;
  END IF;
  v_system := COALESCE(v_system, 0);

  IF NEW.amount < 0 THEN
    IF v_bucket = 'topup' THEN
      v_portion := 0;
    ELSIF v_bucket = 'system' THEN
      v_portion := LEAST(-NEW.amount, v_system);
    ELSE
      v_portion := LEAST(-NEW.amount, v_system);   -- หักถังระบบก่อน
    END IF;
    NEW.system_amount := -v_portion;
    UPDATE public.wallets SET balance_system = v_system - v_portion WHERE id = NEW.wallet_id;
  ELSIF NEW.amount > 0 THEN
    IF v_bucket = 'system' THEN
      v_portion := NEW.amount;
    ELSIF v_bucket = 'topup' THEN
      v_portion := 0;
    ELSIF NEW.type IN ('referral_reward', 'coupon_compensation', 'laundry_payout', 'job_payout') THEN
      v_portion := NEW.amount;
    ELSIF NEW.type IN ('refund', 'release') AND NEW.related_booking_id IS NOT NULL THEN
      -- คืนสัดส่วนถังระบบของเงินที่เคยหักจากออเดอร์นี้ (หักคืนที่คืนไปแล้วออก)
      SELECT COALESCE(-SUM(system_amount), 0) INTO v_prev_debit
      FROM public.wallet_transactions
      WHERE wallet_id = NEW.wallet_id
        AND related_booking_id = NEW.related_booking_id
        AND type IN ('payment', 'hold', 'refund', 'release');
      v_portion := LEAST(NEW.amount, GREATEST(v_prev_debit, 0));
    END IF;
    NEW.system_amount := v_portion;
    UPDATE public.wallets SET balance_system = v_system + v_portion WHERE id = NEW.wallet_id;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_apply_wallet_tx_bucket ON public.wallet_transactions;
CREATE TRIGGER trg_apply_wallet_tx_bucket
  BEFORE INSERT ON public.wallet_transactions
  FOR EACH ROW
  EXECUTE FUNCTION public.apply_wallet_tx_bucket();

-- 2) Config (KV) ------------------------------------------------------------
INSERT INTO public.system_config (key, value)
SELECT k, v FROM (VALUES
  ('referral_reward_base_driver_invite_merchant', '20'),
  ('referral_reward_base_customer_invite_merchant', '20'),
  ('referral_reward_base_driver_invite_driver_referrer', '20'),
  ('referral_reward_base_driver_invite_driver_newdriver', '20'),
  ('referral_reward_tiers', '[{"from":1,"to":5,"multiplier":1.0},{"from":6,"to":15,"multiplier":1.25},{"from":16,"to":null,"multiplier":1.5}]'),
  ('referral_max_rewards_per_month', '20'),
  ('withdrawal_min_topup', '100'),
  ('withdrawal_min_system', '200')
) AS d(k, v)
WHERE NOT EXISTS (SELECT 1 FROM public.system_config sc WHERE sc.key = d.k);

CREATE OR REPLACE FUNCTION public._config_num(p_key text, p_default numeric)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v text;
BEGIN
  SELECT value INTO v FROM public.system_config WHERE key = p_key LIMIT 1;
  IF v IS NULL OR btrim(v) = '' THEN RETURN p_default; END IF;
  RETURN btrim(v)::numeric;
EXCEPTION WHEN others THEN
  RETURN p_default;
END;
$$;

-- 3) Withdrawals per bucket -------------------------------------------------
CREATE OR REPLACE FUNCTION public.request_wallet_withdrawal(
  p_amount numeric,
  p_bucket text,
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
  v_uid uuid := auth.uid();
  v_wallet record;
  v_avail record;
  v_min numeric;
  v_request_id uuid;
  v_tx_id uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;
  IF p_bucket NOT IN ('topup', 'system') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_bucket');
  END IF;
  IF p_amount IS NULL OR p_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_amount');
  END IF;

  v_min := CASE WHEN p_bucket = 'system'
                THEN public._config_num('withdrawal_min_system', 200)
                ELSE public._config_num('withdrawal_min_topup', 100) END;
  IF p_amount < v_min THEN
    RETURN jsonb_build_object('success', false, 'error', 'minimum_withdrawal_amount', 'minimum', v_min, 'bucket', p_bucket);
  END IF;

  IF NULLIF(BTRIM(COALESCE(p_bank_name, '')), '') IS NULL
     OR NULLIF(BTRIM(COALESCE(p_bank_account_number, '')), '') IS NULL
     OR NULLIF(BTRIM(COALESCE(p_bank_account_name, '')), '') IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'missing_bank_account');
  END IF;

  SELECT id, balance, balance_system INTO v_wallet
  FROM public.wallets WHERE user_id = v_uid FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'wallet_not_found');
  END IF;

  SELECT * INTO v_avail FROM public.wallet_bucket_balances(v_wallet.balance, v_wallet.balance_system);
  IF p_amount > (CASE WHEN p_bucket = 'system' THEN v_avail.available_system ELSE v_avail.available_topup END) THEN
    RETURN jsonb_build_object('success', false, 'error', 'insufficient_balance', 'bucket', p_bucket,
      'available', CASE WHEN p_bucket = 'system' THEN v_avail.available_system ELSE v_avail.available_topup END);
  END IF;

  INSERT INTO public.withdrawal_requests (
    user_id, amount, bank_name, bank_account_number, bank_account_name,
    status, source_bucket, created_at, updated_at)
  VALUES (v_uid, p_amount, BTRIM(p_bank_name), BTRIM(p_bank_account_number), BTRIM(p_bank_account_name),
    'pending', p_bucket, now(), now())
  RETURNING id INTO v_request_id;

  PERFORM set_config('app.wallet_bucket', p_bucket, true);
  UPDATE public.wallets SET balance = balance - p_amount, updated_at = now() WHERE id = v_wallet.id;
  INSERT INTO public.wallet_transactions (wallet_id, amount, type, description)
  VALUES (v_wallet.id, -p_amount, 'withdrawal_pending',
          'ส่งคำขอถอนเงิน (' || CASE WHEN p_bucket = 'system' THEN 'ถังระบบ' ELSE 'ถังเติม' END || ') #' || LEFT(v_request_id::text, 8))
  RETURNING id INTO v_tx_id;
  PERFORM set_config('app.wallet_bucket', '', true);

  RETURN jsonb_build_object('success', true, 'request_id', v_request_id, 'transaction_id', v_tx_id,
                            'amount', p_amount, 'bucket', p_bucket);
END;
$$;

REVOKE ALL ON FUNCTION public.request_wallet_withdrawal(numeric, text, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_wallet_withdrawal(numeric, text, text, text, text) TO authenticated, service_role;

-- แอปเดิม: ถอนจากถังเติม (min ตามถังเติม)
CREATE OR REPLACE FUNCTION public.create_wallet_withdrawal_request(
  p_user_id uuid, p_amount numeric, p_bank_name text, p_bank_account_number text, p_bank_account_name text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
BEGIN
  IF auth.uid() IS NULL OR auth.uid() <> p_user_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;
  RETURN public.request_wallet_withdrawal(p_amount, 'topup', p_bank_name, p_bank_account_number, p_bank_account_name);
END;
$$;

REVOKE ALL ON FUNCTION public.create_wallet_withdrawal_request(uuid, numeric, text, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_wallet_withdrawal_request(uuid, numeric, text, text, text) TO authenticated, service_role;

-- คืนเงินเข้าถังเดิมเมื่อปฏิเสธ/ยกเลิก
CREATE OR REPLACE FUNCTION public.reject_withdrawal_request(p_request_id uuid, p_reason text DEFAULT ''::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_req record;
  v_wallet_result jsonb;
BEGIN
  IF auth.uid() IS NOT NULL AND NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  SELECT user_id, amount, status, source_bucket INTO v_req
  FROM public.withdrawal_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'request_not_found');
  END IF;
  IF v_req.status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'error', 'already_processed', 'current_status', v_req.status);
  END IF;

  UPDATE public.withdrawal_requests
  SET status = 'rejected', admin_note = p_reason, processed_at = now()
  WHERE id = p_request_id;

  PERFORM set_config('app.wallet_bucket', COALESCE(v_req.source_bucket, 'topup'), true);
  v_wallet_result := public.wallet_topup(
    v_req.user_id, v_req.amount,
    'คืนเงินจากคำขอถอนที่ถูกปฏิเสธ: ' || COALESCE(p_reason, ''), 'refund');
  PERFORM set_config('app.wallet_bucket', '', true);

  IF COALESCE((v_wallet_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'withdrawal_refund_failed: %', COALESCE(v_wallet_result->>'error', 'unknown');
  END IF;

  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (v_req.user_id, 'คำขอถอนเงินถูกปฏิเสธ',
          'คืนเงิน ฿' || trim(to_char(v_req.amount, 'FM999G999D00')) || ' เข้ากระเป๋าแล้ว' ||
          CASE WHEN COALESCE(p_reason, '') <> '' THEN ' — ' || p_reason ELSE '' END,
          'withdrawal_result',
          jsonb_build_object('type', 'withdrawal_result', 'status', 'rejected', 'request_id', p_request_id));

  RETURN jsonb_build_object('success', true, 'user_id', v_req.user_id, 'amount', v_req.amount, 'wallet', v_wallet_result);
END;
$function$;

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

  SELECT id, user_id, amount, status, source_bucket INTO v_req
  FROM public.withdrawal_requests WHERE id = p_request_id FOR UPDATE;
  IF NOT FOUND OR v_req.user_id <> v_uid THEN
    RETURN jsonb_build_object('success', false, 'error', 'request_not_found');
  END IF;
  IF v_req.status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'error', 'already_processed', 'current_status', v_req.status);
  END IF;

  UPDATE public.withdrawal_requests SET status = 'cancelled', processed_at = now() WHERE id = p_request_id;

  PERFORM set_config('app.wallet_bucket', COALESCE(v_req.source_bucket, 'topup'), true);
  v_wallet_result := public.wallet_topup(
    v_uid, v_req.amount, 'ยกเลิกคำขอถอนเงิน #' || LEFT(p_request_id::text, 8), 'withdrawal_refund');
  PERFORM set_config('app.wallet_bucket', '', true);

  IF COALESCE((v_wallet_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'withdrawal_refund_failed: %', COALESCE(v_wallet_result->>'error', 'unknown');
  END IF;

  RETURN jsonb_build_object('success', true, 'amount', v_req.amount, 'wallet', v_wallet_result);
END;
$function$;

CREATE OR REPLACE FUNCTION public.approve_withdrawal_request(p_request_id uuid, p_transfer_slip_url text DEFAULT NULL::text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_user_id uuid; v_amount numeric; v_status text;
BEGIN
  IF auth.uid() IS NOT NULL AND NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  SELECT user_id, amount, status INTO v_user_id, v_amount, v_status
  FROM public.withdrawal_requests WHERE id = p_request_id FOR UPDATE;
  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'request_not_found');
  END IF;
  IF v_status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'error', 'already_processed', 'current_status', v_status);
  END IF;

  UPDATE public.withdrawal_requests
  SET status = 'completed', processed_at = now(),
      transfer_slip_url = COALESCE(p_transfer_slip_url, transfer_slip_url)
  WHERE id = p_request_id;

  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (v_user_id, 'โอนเงินถอนแล้ว',
          'แอดมินอนุมัติและโอนเงิน ฿' || trim(to_char(v_amount, 'FM999G999D00')) || ' ให้คุณแล้ว',
          'withdrawal_result',
          jsonb_build_object('type', 'withdrawal_result', 'status', 'completed', 'request_id', p_request_id));

  RETURN jsonb_build_object('success', true, 'user_id', v_user_id, 'amount', v_amount);
END;
$function$;

REVOKE ALL ON FUNCTION public.reject_withdrawal_request(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.reject_withdrawal_request(uuid, text) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.cancel_wallet_withdrawal_request(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_wallet_withdrawal_request(uuid) TO authenticated, service_role;
REVOKE ALL ON FUNCTION public.approve_withdrawal_request(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.approve_withdrawal_request(uuid, text) TO authenticated, service_role;

-- 4) Referral rewards -------------------------------------------------------
ALTER TABLE public.referrals ADD COLUMN IF NOT EXISTS scenario text;
ALTER TABLE public.referral_rewards
  ADD COLUMN IF NOT EXISTS tier integer,
  ADD COLUMN IF NOT EXISTS base_amount numeric,
  ADD COLUMN IF NOT EXISTS multiplier numeric,
  ADD COLUMN IF NOT EXISTS wallet_transaction_id uuid,
  ADD COLUMN IF NOT EXISTS paid_at timestamptz,
  ADD COLUMN IF NOT EXISTS reviewed_by uuid;
CREATE UNIQUE INDEX IF NOT EXISTS uq_referral_rewards_once
  ON public.referral_rewards (referral_id, beneficiary_user_id, reward_type);

-- ขั้นของ "รายที่ n" ตาม config JSON
CREATE OR REPLACE FUNCTION public.referral_tier_for(p_nth integer)
RETURNS TABLE(tier integer, multiplier numeric)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_json jsonb;
  v_el jsonb;
  v_i integer := 0;
BEGIN
  BEGIN
    SELECT value::jsonb INTO v_json FROM public.system_config WHERE key = 'referral_reward_tiers' LIMIT 1;
  EXCEPTION WHEN others THEN
    v_json := NULL;
  END;
  v_json := COALESCE(v_json, '[{"from":1,"to":5,"multiplier":1.0},{"from":6,"to":15,"multiplier":1.25},{"from":16,"to":null,"multiplier":1.5}]'::jsonb);
  FOR v_el IN SELECT * FROM jsonb_array_elements(v_json) LOOP
    v_i := v_i + 1;
    IF p_nth >= COALESCE((v_el->>'from')::int, 1)
       AND (v_el->>'to' IS NULL OR p_nth <= (v_el->>'to')::int) THEN
      tier := v_i;
      multiplier := COALESCE((v_el->>'multiplier')::numeric, 1);
      RETURN NEXT;
      RETURN;
    END IF;
  END LOOP;
  tier := GREATEST(v_i, 1);
  multiplier := 1;
  RETURN NEXT;
END;
$$;

-- จ่าย/บันทึกรางวัล 1 รายการ (idempotent) — p_apply_tier = ผู้ชวน (คิดขั้นบันได)
CREATE OR REPLACE FUNCTION public._grant_referral_reward(
  p_referral_id uuid, p_beneficiary uuid, p_reward_type text, p_base_key text, p_apply_tier boolean)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_base numeric;
  v_nth integer;
  v_tier_no integer;
  v_mult numeric := 1;
  v_amount numeric;
  v_cap numeric;
  v_month_count integer;
  v_reward_id uuid;
  v_status text := 'paid';
  v_result jsonb;
BEGIN
  IF EXISTS (SELECT 1 FROM public.referral_rewards
             WHERE referral_id = p_referral_id AND beneficiary_user_id = p_beneficiary AND reward_type = p_reward_type) THEN
    RETURN jsonb_build_object('success', true, 'skipped', 'already_granted');
  END IF;

  v_base := public._config_num(p_base_key, 20);
  IF v_base <= 0 THEN
    RETURN jsonb_build_object('success', true, 'skipped', 'reward_disabled');
  END IF;

  IF p_apply_tier THEN
    SELECT count(*) + 1 INTO v_nth FROM public.referral_rewards
    WHERE beneficiary_user_id = p_beneficiary AND reward_type LIKE 'referrer_%' AND status = 'paid';
    SELECT t.tier, t.multiplier INTO v_tier_no, v_mult FROM public.referral_tier_for(v_nth) t;
  END IF;
  v_amount := round(v_base * COALESCE(v_mult, 1), 2);

  v_cap := public._config_num('referral_max_rewards_per_month', 20);
  -- กันสองรางวัลของคนเดียวกันอ่าน count พร้อมกันแล้วทะลุแคป (hard cap)
  PERFORM pg_advisory_xact_lock(hashtext(p_beneficiary::text || ':referral_cap'));
  SELECT count(*) INTO v_month_count FROM public.referral_rewards
  WHERE beneficiary_user_id = p_beneficiary
    AND created_at >= date_trunc('month', now())
    AND status IN ('paid', 'pending_review');
  IF v_month_count >= v_cap THEN
    v_status := 'pending_review';
  END IF;

  INSERT INTO public.referral_rewards (referral_id, beneficiary_user_id, reward_type, amount, status,
                                       tier, base_amount, multiplier)
  VALUES (p_referral_id, p_beneficiary, p_reward_type, v_amount, v_status,
          v_tier_no, v_base, COALESCE(v_mult, 1))
  ON CONFLICT (referral_id, beneficiary_user_id, reward_type) DO NOTHING
  RETURNING id INTO v_reward_id;

  IF v_reward_id IS NULL THEN
    RETURN jsonb_build_object('success', true, 'skipped', 'already_granted');
  END IF;

  IF v_status = 'paid' THEN
    v_result := public._pay_referral_reward(v_reward_id);
  END IF;

  RETURN jsonb_build_object('success', true, 'reward_id', v_reward_id, 'status', v_status, 'amount', v_amount);
END;
$$;

CREATE OR REPLACE FUNCTION public._pay_referral_reward(p_reward_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r record;
  v_result jsonb;
BEGIN
  SELECT * INTO r FROM public.referral_rewards WHERE id = p_reward_id FOR UPDATE;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'reward_not_found');
  END IF;
  IF r.wallet_transaction_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', true, 'skipped', 'already_paid');
  END IF;

  v_result := public.wallet_topup(
    r.beneficiary_user_id, r.amount,
    'รางวัลชวนเพื่อน' || CASE WHEN r.tier IS NOT NULL THEN ' (ขั้น ' || r.tier || ')' ELSE '' END,
    'referral_reward', NULL);
  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'referral_reward_payment_failed: %', COALESCE(v_result->>'error', 'unknown');
  END IF;

  UPDATE public.referral_rewards
  SET status = 'paid', paid_at = now(),
      wallet_transaction_id = (v_result->>'transaction_id')::uuid
  WHERE id = p_reward_id;

  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (r.beneficiary_user_id, '🎉 ได้รับเงินรางวัลชวนเพื่อน',
          'ได้รับเงินรางวัล ฿' || trim(to_char(r.amount, 'FM999G999D00')) || ' เข้ากระเป๋า (ถังระบบ) แล้ว',
          'referral_reward',
          jsonb_build_object('type', 'referral_reward', 'reward_id', p_reward_id, 'amount', r.amount, 'screen', 'wallet'));

  RETURN jsonb_build_object('success', true, 'reward_id', p_reward_id, 'amount', r.amount);
END;
$$;

REVOKE ALL ON FUNCTION public._grant_referral_reward(uuid, uuid, text, text, boolean) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public._pay_referral_reward(uuid) FROM PUBLIC, anon, authenticated;

-- แอดมินกดจ่ายรางวัลที่เกินแคป (pending_review)
CREATE OR REPLACE FUNCTION public.admin_release_referral_reward(p_reward_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_status text;
BEGIN
  IF auth.uid() IS NOT NULL AND NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;
  SELECT status INTO v_status FROM public.referral_rewards WHERE id = p_reward_id FOR UPDATE;
  IF v_status IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'reward_not_found');
  END IF;
  IF v_status <> 'pending_review' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_pending_review', 'status', v_status);
  END IF;
  UPDATE public.referral_rewards SET reviewed_by = auth.uid() WHERE id = p_reward_id;
  RETURN public._pay_referral_reward(p_reward_id);
END;
$$;

REVOKE ALL ON FUNCTION public.admin_release_referral_reward(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_release_referral_reward(uuid) TO authenticated, service_role;

-- S1/S2: ร้านที่ถูกชวนได้รับอนุมัติ
CREATE OR REPLACE FUNCTION public.referral_on_merchant_approved()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ref record;
  v_referrer_role text;
BEGIN
  IF NEW.role <> 'merchant' OR NEW.approval_status IS DISTINCT FROM 'approved'
     OR OLD.approval_status IS NOT DISTINCT FROM 'approved' THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_ref FROM public.referrals WHERE referee_id = NEW.id AND status = 'pending' FOR UPDATE;
  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  SELECT role INTO v_referrer_role FROM public.profiles WHERE id = v_ref.referrer_id;
  IF v_referrer_role NOT IN ('driver', 'customer') THEN
    RETURN NEW;
  END IF;

  UPDATE public.referrals
  SET status = 'qualified', qualified_at = now(), updated_at = now(),
      scenario = CASE WHEN v_referrer_role = 'driver' THEN 'S1' ELSE 'S2' END
  WHERE id = v_ref.id;

  PERFORM public._grant_referral_reward(
    v_ref.id, v_ref.referrer_id,
    CASE WHEN v_referrer_role = 'driver' THEN 'referrer_driver_invite_merchant' ELSE 'referrer_customer_invite_merchant' END,
    CASE WHEN v_referrer_role = 'driver' THEN 'referral_reward_base_driver_invite_merchant' ELSE 'referral_reward_base_customer_invite_merchant' END,
    true);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_referral_on_merchant_approved ON public.profiles;
CREATE TRIGGER trg_referral_on_merchant_approved
  AFTER UPDATE OF approval_status ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.referral_on_merchant_approved();

-- S3: คนขับใหม่ที่ถูกคนขับชวน จบงานแรก
CREATE OR REPLACE FUNCTION public.referral_on_driver_first_job()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ref record;
  v_referrer_role text;
  v_referee_role text;
BEGIN
  IF NEW.status IS DISTINCT FROM 'completed' OR OLD.status IS NOT DISTINCT FROM 'completed'
     OR NEW.driver_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF EXISTS (SELECT 1 FROM public.bookings
             WHERE driver_id = NEW.driver_id AND status = 'completed' AND id <> NEW.id) THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_ref FROM public.referrals WHERE referee_id = NEW.driver_id AND status = 'pending' FOR UPDATE;
  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  SELECT role INTO v_referrer_role FROM public.profiles WHERE id = v_ref.referrer_id;
  SELECT role INTO v_referee_role FROM public.profiles WHERE id = NEW.driver_id;
  IF v_referrer_role <> 'driver' OR v_referee_role <> 'driver' THEN
    RETURN NEW;
  END IF;

  UPDATE public.referrals
  SET status = 'qualified', qualified_at = now(), updated_at = now(), scenario = 'S3'
  WHERE id = v_ref.id;

  PERFORM public._grant_referral_reward(v_ref.id, v_ref.referrer_id, 'referrer_driver_invite_driver',
                                        'referral_reward_base_driver_invite_driver_referrer', true);
  PERFORM public._grant_referral_reward(v_ref.id, NEW.driver_id, 'referee_new_driver',
                                        'referral_reward_base_driver_invite_driver_newdriver', false);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_referral_on_driver_first_job ON public.bookings;
CREATE TRIGGER trg_referral_on_driver_first_job
  AFTER UPDATE OF status ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION public.referral_on_driver_first_job();

-- 5) process_referral: ผูกได้เฉพาะตัวเอง ------------------------------------
CREATE OR REPLACE FUNCTION public.process_referral(p_referee_id uuid, p_referral_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $function$
DECLARE
  v_referrer record;
  v_referral_id uuid;
BEGIN
  IF auth.uid() IS NULL OR (auth.uid() <> p_referee_id AND NOT public.is_admin()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  IF EXISTS (SELECT 1 FROM public.referrals WHERE referee_id = p_referee_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'User has already been referred by someone else');
  END IF;

  SELECT * INTO v_referrer FROM public.referral_codes WHERE code = UPPER(BTRIM(p_referral_code));
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'Invalid referral code');
  END IF;

  IF v_referrer.user_id = p_referee_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'Cannot refer yourself');
  END IF;

  INSERT INTO public.referrals (referrer_id, referee_id, referral_code_used, status)
  VALUES (v_referrer.user_id, p_referee_id, UPPER(BTRIM(p_referral_code)), 'pending')
  RETURNING id INTO v_referral_id;

  RETURN jsonb_build_object('success', true, 'referral_id', v_referral_id);
END;
$function$;

REVOKE ALL ON FUNCTION public.process_referral(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.process_referral(uuid, text) TO authenticated, service_role;

-- 6) สรุปสำหรับหน้าแชร์โค้ด --------------------------------------------------
CREATE OR REPLACE FUNCTION public.my_referral_summary()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_paid integer;
  v_tier record;
  v_next record;
  v_json jsonb;
  v_to integer;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('error', 'not_authenticated');
  END IF;
  SELECT count(*) INTO v_paid FROM public.referral_rewards
  WHERE beneficiary_user_id = v_uid AND reward_type LIKE 'referrer_%' AND status = 'paid';
  SELECT * INTO v_tier FROM public.referral_tier_for(v_paid + 1);
  BEGIN
    SELECT value::jsonb INTO v_json FROM public.system_config WHERE key = 'referral_reward_tiers' LIMIT 1;
  EXCEPTION WHEN others THEN v_json := NULL;
  END;
  v_to := (COALESCE(v_json, '[]'::jsonb) -> (v_tier.tier - 1) ->> 'to')::int;

  RETURN jsonb_build_object(
    'successful_referrals', v_paid,
    'current_tier', v_tier.tier,
    'current_multiplier', v_tier.multiplier,
    'referrals_to_next_tier', CASE WHEN v_to IS NULL THEN NULL ELSE GREATEST(v_to - v_paid, 0) END,
    'tiers', COALESCE(v_json, '[]'::jsonb),
    'base', jsonb_build_object(
      'driver_invite_merchant', public._config_num('referral_reward_base_driver_invite_merchant', 20),
      'customer_invite_merchant', public._config_num('referral_reward_base_customer_invite_merchant', 20),
      'driver_invite_driver_referrer', public._config_num('referral_reward_base_driver_invite_driver_referrer', 20),
      'driver_invite_driver_newdriver', public._config_num('referral_reward_base_driver_invite_driver_newdriver', 20)),
    'total_earned', COALESCE((SELECT SUM(amount) FROM public.referral_rewards
                              WHERE beneficiary_user_id = v_uid AND status = 'paid'), 0),
    'pending_review', (SELECT count(*) FROM public.referral_rewards
                       WHERE beneficiary_user_id = v_uid AND status = 'pending_review'),
    'withdrawal_min', jsonb_build_object(
      'topup', public._config_num('withdrawal_min_topup', 100),
      'system', public._config_num('withdrawal_min_system', 200))
  );
END;
$$;

REVOKE ALL ON FUNCTION public.my_referral_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.my_referral_summary() TO authenticated;

COMMIT;
