-- ═══════════════════════════════════════════════════════════════
-- Beam Checkout สำหรับเติมเงิน Wallet (สลับกับโหมดแนบสลิปได้จาก admin-web)
--
-- - payment_gateway_settings: เก็บ Merchant ID / API Key / Webhook HMAC Key
--   ไม่มี policy ใด ๆ → client (anon/authenticated) อ่าน/เขียนไม่ได้เลย
--   อ่าน/เขียนผ่าน Edge Function (service role) เท่านั้น: admin-actions, beam-topup, beam-webhook
-- - system_config.topup_mode: 'admin_approve' (แนบสลิป + Slip2Go/แอดมิน) | 'beam'
-- - topup_requests: คอลัมน์ Beam + สถานะ awaiting_payment / expired / failed
-- - ปิดช่องโหว่ RLS: policy "Service role can manage all topup requests" เดิมเปิดให้ทุก role
--   (roles = public, USING true) → ผู้ใช้ทุกคนแก้/โอนคำขอเติมเงินของคนอื่นได้
-- - RPC complete_beam_topup: เติมเงินแบบ idempotent + ตรวจยอดที่จ่ายจริง (satang)
-- ═══════════════════════════════════════════════════════════════

BEGIN;

-- 1) Gateway settings (secret) -------------------------------------
CREATE TABLE IF NOT EXISTS public.payment_gateway_settings (
  provider text PRIMARY KEY CHECK (provider IN ('beam')),
  environment text NOT NULL DEFAULT 'playground'
    CHECK (environment IN ('playground', 'production')),
  merchant_id text,
  api_key text,
  webhook_hmac_key text,
  qr_expiry_minutes integer NOT NULL DEFAULT 15
    CHECK (qr_expiry_minutes BETWEEN 5 AND 60),
  last_test_at timestamptz,
  last_test_ok boolean,
  last_test_message text,
  updated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.payment_gateway_settings IS
  'คีย์ payment gateway (secret) — ไม่มี RLS policy: เข้าถึงได้เฉพาะ service role ผ่าน Edge Function';

ALTER TABLE public.payment_gateway_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.payment_gateway_settings FROM anon, authenticated;

INSERT INTO public.payment_gateway_settings (provider)
VALUES ('beam')
ON CONFLICT (provider) DO NOTHING;

-- 2) topup_mode switch ---------------------------------------------
UPDATE public.system_config
SET topup_mode = 'admin_approve'
WHERE topup_mode IS NULL OR topup_mode NOT IN ('admin_approve', 'beam');

ALTER TABLE public.system_config
  DROP CONSTRAINT IF EXISTS chk_system_config_topup_mode;
ALTER TABLE public.system_config
  ADD CONSTRAINT chk_system_config_topup_mode
  CHECK (topup_mode IN ('admin_approve', 'beam'));

COMMENT ON COLUMN public.system_config.topup_mode IS
  'โหมดเติมเงิน Wallet: admin_approve = PromptPay + แนบสลิป (Slip2Go/แอดมิน), beam = Beam Checkout QR PromptPay อัตโนมัติ';

-- 3) topup_requests: Beam columns ----------------------------------
ALTER TABLE public.topup_requests
  ADD COLUMN IF NOT EXISTS payment_provider text NOT NULL DEFAULT 'slip',
  ADD COLUMN IF NOT EXISTS beam_charge_id text,
  ADD COLUMN IF NOT EXISTS beam_environment text,
  ADD COLUMN IF NOT EXISTS beam_expires_at timestamptz,
  ADD COLUMN IF NOT EXISTS beam_paid_satang bigint;

ALTER TABLE public.topup_requests
  DROP CONSTRAINT IF EXISTS chk_topup_requests_payment_provider;
ALTER TABLE public.topup_requests
  ADD CONSTRAINT chk_topup_requests_payment_provider
  CHECK (payment_provider IN ('slip', 'beam', 'admin'));

CREATE UNIQUE INDEX IF NOT EXISTS topup_requests_beam_charge_id_unique_idx
  ON public.topup_requests (beam_charge_id)
  WHERE beam_charge_id IS NOT NULL;

-- 4) RLS fix -----------------------------------------------------------
DROP POLICY IF EXISTS "Service role can manage all topup requests" ON public.topup_requests;

DROP POLICY IF EXISTS "Admins can manage topup requests" ON public.topup_requests;
CREATE POLICY "Admins can manage topup requests" ON public.topup_requests
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ผู้ใช้สร้างคำขอเองได้เฉพาะแบบสลิปที่ยังรอตรวจ (ไม่มี client flow ใช้อยู่ แต่คงไว้แบบจำกัด)
DROP POLICY IF EXISTS "Users can insert their own topup requests" ON public.topup_requests;
CREATE POLICY "Users can insert their own topup requests" ON public.topup_requests
  FOR INSERT TO authenticated
  WITH CHECK (
    auth.uid() = user_id
    AND status = 'pending'
    AND payment_provider = 'slip'
    AND beam_charge_id IS NULL
    AND beam_paid_satang IS NULL
  );

DROP POLICY IF EXISTS "Users can view their own topup requests" ON public.topup_requests;
CREATE POLICY "Users can view their own topup requests" ON public.topup_requests
  FOR SELECT TO authenticated
  USING (auth.uid() = user_id);

-- 5) RPC: complete Beam topup (service role only) -------------------
CREATE OR REPLACE FUNCTION public.complete_beam_topup(
  p_charge_id text,
  p_paid_satang bigint
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_req record;
  v_result jsonb;
BEGIN
  SELECT id, amount, status, payment_provider
    INTO v_req
  FROM public.topup_requests
  WHERE beam_charge_id = p_charge_id
  FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'request_not_found');
  END IF;

  IF v_req.status = 'completed' THEN
    RETURN jsonb_build_object('success', true, 'already_completed', true,
                              'request_id', v_req.id);
  END IF;

  IF v_req.payment_provider <> 'beam'
     OR v_req.status NOT IN ('awaiting_payment', 'expired', 'failed') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_state',
                              'current_status', v_req.status);
  END IF;

  -- ยอดที่ Beam ยืนยันว่าจ่ายจริงต้องตรงกับยอดคำขอ (หน่วยสตางค์)
  IF p_paid_satang IS NULL OR p_paid_satang <> round(v_req.amount * 100)::bigint THEN
    UPDATE public.topup_requests
    SET admin_note = 'Beam paid amount mismatch: paid_satang=' || COALESCE(p_paid_satang::text, 'null'),
        beam_paid_satang = p_paid_satang,
        updated_at = now()
    WHERE id = v_req.id;
    RETURN jsonb_build_object('success', false, 'error', 'amount_mismatch',
                              'request_id', v_req.id);
  END IF;

  -- จ่ายสำเร็จแม้ QR หมดเวลาแล้ว (จ่ายก่อนหมดอายุแต่ webhook มาช้า) → ยังเติมให้
  UPDATE public.topup_requests
  SET status = 'pending',
      beam_paid_satang = p_paid_satang,
      verification_provider = 'beam',
      verified_amount = p_paid_satang / 100.0,
      verified_at = now(),
      updated_at = now()
  WHERE id = v_req.id;

  v_result := public.complete_topup_request(
    v_req.id,
    'เติมเงินผ่าน Beam (' || p_charge_id || ')',
    'Beam charge succeeded — auto credited'
  );

  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'beam_topup_credit_failed: %', COALESCE(v_result->>'error', 'unknown');
  END IF;

  RETURN v_result || jsonb_build_object('request_id', v_req.id);
END;
$$;

REVOKE ALL ON FUNCTION public.complete_beam_topup(text, bigint) FROM public, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.complete_beam_topup(text, bigint) TO service_role;

COMMIT;
