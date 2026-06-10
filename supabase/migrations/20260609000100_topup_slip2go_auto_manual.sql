-- Top-up auto manual verification via Slip2Go.

ALTER TABLE IF EXISTS public.system_config
  ADD COLUMN IF NOT EXISTS slip2go_receiver_account text;

ALTER TABLE IF EXISTS public.topup_requests
  ADD COLUMN IF NOT EXISTS verification_provider text,
  ADD COLUMN IF NOT EXISTS verification_reason text,
  ADD COLUMN IF NOT EXISTS slip2go_code text,
  ADD COLUMN IF NOT EXISTS slip2go_message text,
  ADD COLUMN IF NOT EXISTS slip2go_trans_ref text,
  ADD COLUMN IF NOT EXISTS verified_amount numeric,
  ADD COLUMN IF NOT EXISTS verified_receiver_name text,
  ADD COLUMN IF NOT EXISTS verified_receiver_account text,
  ADD COLUMN IF NOT EXISTS slip_image_path text,
  ADD COLUMN IF NOT EXISTS verified_at timestamptz;

CREATE TABLE IF NOT EXISTS public.topup_verification_attempts (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  amount numeric NOT NULL DEFAULT 0,
  provider text NOT NULL DEFAULT 'slip2go',
  status text NOT NULL,
  reason text,
  slip2go_trans_ref text,
  created_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_topup_verification_attempts_user_created
  ON public.topup_verification_attempts(user_id, created_at DESC);

ALTER TABLE IF EXISTS public.topup_verification_attempts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "topup_verification_attempts_service_role_all" ON public.topup_verification_attempts;
CREATE POLICY "topup_verification_attempts_service_role_all"
  ON public.topup_verification_attempts FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('topup-slips', 'topup-slips', false, 8388608, ARRAY['image/jpeg','image/png','image/webp'])
ON CONFLICT (id) DO UPDATE
SET
  public = false,
  file_size_limit = 8388608,
  allowed_mime_types = ARRAY['image/jpeg','image/png','image/webp'];

CREATE UNIQUE INDEX IF NOT EXISTS topup_requests_slip2go_trans_ref_unique_idx
  ON public.topup_requests(slip2go_trans_ref)
  WHERE slip2go_trans_ref IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_topup_requests_verified_at
  ON public.topup_requests(verified_at)
  WHERE verified_at IS NOT NULL;

-- Atomic completion for both admin approval and Slip2Go auto-credit.
-- The topup row is locked first; only pending requests can credit wallet.
CREATE OR REPLACE FUNCTION public.complete_topup_request(
  p_request_id uuid,
  p_description text DEFAULT NULL,
  p_admin_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_amount numeric;
  v_status text;
  v_description text;
  v_wallet_result jsonb;
BEGIN
  SELECT user_id, amount, status
  INTO v_user_id, v_amount, v_status
  FROM public.topup_requests
  WHERE id = p_request_id
  FOR UPDATE;

  IF v_user_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'request_not_found');
  END IF;

  IF v_status <> 'pending' THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'already_processed',
      'current_status', v_status
    );
  END IF;

  IF v_amount <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_amount');
  END IF;

  v_description := COALESCE(NULLIF(p_description, ''), 'เติมเงินผ่าน Admin (฿' || v_amount || ')');
  v_wallet_result := public.wallet_topup(v_user_id, v_amount, v_description, 'topup', NULL);

  IF COALESCE((v_wallet_result->>'success')::boolean, false) IS NOT TRUE THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', COALESCE(v_wallet_result->>'error', 'wallet_topup_failed'),
      'wallet', v_wallet_result
    );
  END IF;

  UPDATE public.topup_requests
  SET
    status = 'completed',
    processed_at = now(),
    updated_at = now(),
    admin_note = COALESCE(NULLIF(p_admin_note, ''), admin_note)
  WHERE id = p_request_id;

  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'amount', v_amount,
    'wallet', v_wallet_result
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.approve_topup_request(
  p_request_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN public.complete_topup_request(p_request_id, NULL, NULL);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.complete_topup_request(uuid, text, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.complete_topup_request(uuid, text, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.complete_topup_request(uuid, text, text) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.approve_topup_request(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.approve_topup_request(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.approve_topup_request(uuid) FROM authenticated;
REVOKE EXECUTE ON FUNCTION public.wallet_topup(uuid, numeric, text, text, uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.wallet_topup(uuid, numeric, text, text, uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public.wallet_topup(uuid, numeric, text, text, uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.complete_topup_request(uuid, text, text) TO service_role;
GRANT EXECUTE ON FUNCTION public.approve_topup_request(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.wallet_topup(uuid, numeric, text, text, uuid) TO service_role;
