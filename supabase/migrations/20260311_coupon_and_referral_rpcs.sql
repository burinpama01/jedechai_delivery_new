-- RPC Functions for Atomic Operations (Phase 1A)

-- 1. claim_coupon
-- Allows a user to atomically claim a coupon code, enforcing claim limits and expiry.
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
        RETURN jsonb_build_object('success', false, 'error', 'Coupon not found or inactive');
    END IF;

    -- Check validity dates
    IF v_coupon.valid_from IS NOT NULL AND v_coupon.valid_from > now() THEN
        RETURN jsonb_build_object('success', false, 'error', 'Coupon not yet valid');
    END IF;

    IF v_coupon.valid_until IS NOT NULL AND v_coupon.valid_until < now() THEN
        RETURN jsonb_build_object('success', false, 'error', 'Coupon expired');
    END IF;

    -- Check total claim limit
    IF v_coupon.claim_limit IS NOT NULL AND v_coupon.current_claims >= v_coupon.claim_limit THEN
        RETURN jsonb_build_object('success', false, 'error', 'Coupon claim limit reached');
    END IF;

    -- Check per user claim limit
    SELECT count(*) INTO v_claims_count FROM public.user_coupons 
    WHERE coupon_id = v_coupon.id AND user_id = p_user_id;

    IF v_claims_count >= v_coupon.claim_limit_per_user THEN
        RETURN jsonb_build_object('success', false, 'error', 'User claim limit reached');
    END IF;

    -- Insert claim
    INSERT INTO public.user_coupons (user_id, coupon_id, status, expires_at)
    VALUES (
        p_user_id, 
        v_coupon.id, 
        'claimed', 
        v_coupon.valid_until -- Use coupon's valid_until as user_coupon's expires_at
    )
    RETURNING id INTO v_new_user_coupon_id;

    -- Increment claims
    UPDATE public.coupons 
    SET current_claims = COALESCE(current_claims, 0) + 1 
    WHERE id = v_coupon.id;

    RETURN jsonb_build_object('success', true, 'user_coupon_id', v_new_user_coupon_id);
END;
$$;

-- 2. process_referral
-- Atomically links a new user (referee) to a referrer using their code.
CREATE OR REPLACE FUNCTION public.process_referral(p_referee_id UUID, p_referral_code TEXT)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_referrer record;
    v_existing_referral record;
    v_referral_id uuid;
BEGIN
    -- Check if referee already referred
    SELECT * INTO v_existing_referral FROM public.referrals WHERE referee_id = p_referee_id;
    IF v_existing_referral IS NOT NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'User has already been referred by someone else');
    END IF;

    -- Find referrer by code
    SELECT * INTO v_referrer FROM public.referral_codes WHERE code = UPPER(p_referral_code);
    IF v_referrer IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Invalid referral code');
    END IF;

    IF v_referrer.user_id = p_referee_id THEN
        RETURN jsonb_build_object('success', false, 'error', 'Cannot refer yourself');
    END IF;

    -- Create referral
    INSERT INTO public.referrals (referrer_id, referee_id, referral_code_used, status)
    VALUES (v_referrer.user_id, p_referee_id, UPPER(p_referral_code), 'pending')
    RETURNING id INTO v_referral_id;

    RETURN jsonb_build_object('success', true, 'referral_id', v_referral_id);
END;
$$;

-- 3. consume_coupon (skeleton for locking and marking a user_coupon as used)
-- Note: Real financial logic and stacking rules will likely be processed in Edge Functions, 
-- but this RPC provides a safe atomic way to mark the coupon as consumed.
CREATE OR REPLACE FUNCTION public.consume_user_coupon(p_user_id UUID, p_user_coupon_id UUID, p_booking_id UUID)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    v_user_coupon record;
BEGIN
    -- Lock the user_coupon
    SELECT * INTO v_user_coupon FROM public.user_coupons
    WHERE id = p_user_coupon_id AND user_id = p_user_id FOR UPDATE;

    IF v_user_coupon IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'Coupon not found or does not belong to user');
    END IF;

    IF v_user_coupon.status != 'claimed' THEN
        RETURN jsonb_build_object('success', false, 'error', 'Coupon is not in a claimable state (already used, expired, or revoked)');
    END IF;

    IF v_user_coupon.expires_at IS NOT NULL AND v_user_coupon.expires_at < now() THEN
        -- Auto-expire if past date
        UPDATE public.user_coupons SET status = 'expired' WHERE id = p_user_coupon_id;
        RETURN jsonb_build_object('success', false, 'error', 'Coupon has expired');
    END IF;

    -- Mark as used
    UPDATE public.user_coupons
    SET status = 'used',
        used_booking_id = p_booking_id,
        used_at = now(),
        updated_at = now()
    WHERE id = p_user_coupon_id;

    -- We might also want to log into coupon_usages here, or leave that to the Edge Function.
    
    RETURN jsonb_build_object('success', true);
END;
$$;