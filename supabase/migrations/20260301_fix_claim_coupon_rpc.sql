-- Fix claim_coupon RPC to use correct column names (start_date/end_date)
-- and allow authenticated users to create their own referral code row.

CREATE OR REPLACE FUNCTION public.claim_coupon(p_user_id UUID, p_coupon_code TEXT)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_coupon record;
    v_claims_count int;
    v_new_user_coupon_id uuid;
BEGIN
    -- Lock the coupon row for atomicity
    SELECT * INTO v_coupon FROM public.coupons 
    WHERE code = UPPER(p_coupon_code) AND is_active = true 
    FOR UPDATE;

    IF v_coupon IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'ไม่พบคูปองนี้หรือถูกปิดใช้งาน');
    END IF;

    -- Only claimable coupons should be claimable into wallet
    IF v_coupon.distribution_type IS DISTINCT FROM 'claimable' THEN
        RETURN jsonb_build_object('success', false, 'error', 'คูปองนี้ไม่สามารถกดเก็บได้');
    END IF;

    -- Check validity dates (schema uses start_date/end_date)
    IF v_coupon.start_date IS NOT NULL AND v_coupon.start_date > now() THEN
        RETURN jsonb_build_object('success', false, 'error', 'คูปองนี้ยังไม่เริ่มใช้งาน');
    END IF;

    IF v_coupon.end_date IS NOT NULL AND v_coupon.end_date < now() THEN
        RETURN jsonb_build_object('success', false, 'error', 'คูปองนี้หมดอายุแล้ว');
    END IF;

    -- Check total claim limit
    IF v_coupon.claim_limit IS NOT NULL AND COALESCE(v_coupon.current_claims, 0) >= v_coupon.claim_limit THEN
        RETURN jsonb_build_object('success', false, 'error', 'คูปองถูกเก็บครบจำนวนแล้ว');
    END IF;

    -- Check per user claim limit
    SELECT count(*) INTO v_claims_count FROM public.user_coupons 
    WHERE coupon_id = v_coupon.id AND user_id = p_user_id;

    IF v_claims_count >= COALESCE(v_coupon.claim_limit_per_user, 1) THEN
        RETURN jsonb_build_object('success', false, 'error', 'คุณเก็บคูปองนี้ครบจำนวนที่กำหนดแล้ว');
    END IF;

    -- Insert claim
    INSERT INTO public.user_coupons (user_id, coupon_id, status, expires_at)
    VALUES (
        p_user_id, 
        v_coupon.id, 
        'claimed', 
        v_coupon.end_date
    )
    RETURNING id INTO v_new_user_coupon_id;

    -- Increment claims
    UPDATE public.coupons 
    SET current_claims = COALESCE(current_claims, 0) + 1 
    WHERE id = v_coupon.id;

    RETURN jsonb_build_object('success', true, 'user_coupon_id', v_new_user_coupon_id);
END;
$$;

-- Referral codes: allow authenticated users to create their own row (one-time)
DO $$ BEGIN
  CREATE POLICY "Users can insert own referral code" ON public.referral_codes
    FOR INSERT TO authenticated
    WITH CHECK (auth.uid() = user_id);
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;
