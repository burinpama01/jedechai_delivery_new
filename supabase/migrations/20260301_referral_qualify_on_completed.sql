-- Phase 2: Referral qualification + coupon grant on first completed booking
-- Trigger-based so it works regardless of how booking status is updated.

-- Config keys (system_config key-value rows):
--  - welcome_coupon_code_referral: coupon code to grant to referee (new user) after first completed booking
--  - referrer_reward_coupon_code: coupon code to grant to referrer after referee's first completed booking

CREATE OR REPLACE FUNCTION public.referral_qualify_on_booking_completed(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking record;
  v_customer_id uuid;
  v_referral record;
  v_prev_completed_count int;

  v_welcome_code text;
  v_referrer_reward_code text;
  v_coupon_referee record;
  v_coupon_referrer record;
BEGIN
  SELECT id, customer_id, status INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id;

  IF v_booking IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF v_booking.status IS DISTINCT FROM 'completed' THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_completed');
  END IF;

  v_customer_id := v_booking.customer_id;
  IF v_customer_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'missing_customer');
  END IF;

  -- Only on first completed booking
  SELECT count(*) INTO v_prev_completed_count
  FROM public.bookings
  WHERE customer_id = v_customer_id
    AND status = 'completed'
    AND id <> p_booking_id;

  IF v_prev_completed_count > 0 THEN
    RETURN jsonb_build_object('success', true, 'skipped', true, 'reason', 'not_first_completed');
  END IF;

  -- Find referral relationship (referee = this customer)
  SELECT * INTO v_referral
  FROM public.referrals
  WHERE referee_id = v_customer_id
    AND status = 'pending'
  LIMIT 1;

  IF v_referral IS NULL THEN
    RETURN jsonb_build_object('success', true, 'skipped', true, 'reason', 'no_pending_referral');
  END IF;

  -- Mark qualified
  UPDATE public.referrals
  SET status = 'qualified',
      qualified_at = now(),
      updated_at = now()
  WHERE id = v_referral.id
    AND status = 'pending';

  -- Load coupon codes from config (KV rows)
  SELECT value INTO v_welcome_code
  FROM public.system_config
  WHERE key = 'welcome_coupon_code_referral'
  LIMIT 1;

  SELECT value INTO v_referrer_reward_code
  FROM public.system_config
  WHERE key = 'referrer_reward_coupon_code'
  LIMIT 1;

  -- Fallbacks (so dev environment still works)
  v_welcome_code := COALESCE(NULLIF(TRIM(v_welcome_code), ''), 'WELCOME20');
  v_referrer_reward_code := COALESCE(NULLIF(TRIM(v_referrer_reward_code), ''), 'REFERRER20');

  -- Grant welcome coupon to referee (insert into user_coupons if coupon exists)
  SELECT * INTO v_coupon_referee
  FROM public.coupons
  WHERE code = UPPER(v_welcome_code)
    AND is_active = true
  LIMIT 1;

  IF v_coupon_referee IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.user_coupons
      WHERE user_id = v_customer_id AND coupon_id = v_coupon_referee.id
    ) THEN
      INSERT INTO public.user_coupons (user_id, coupon_id, status, expires_at)
      VALUES (v_customer_id, v_coupon_referee.id, 'claimed', v_coupon_referee.end_date);
    END IF;

    -- One-time in-app notification for referee
    IF NOT EXISTS (
      SELECT 1
      FROM public.notifications
      WHERE user_id = v_customer_id
        AND type = 'referral_reward_referee'
        AND (data->>'referral_id') = v_referral.id::text
    ) THEN
      INSERT INTO public.notifications (user_id, title, body, type, data)
      VALUES (
        v_customer_id,
        'คุณได้รับคูปองแล้ว',
        'คูปองต้อนรับ ' || UPPER(v_welcome_code) || ' ถูกเพิ่มในคูปองของคุณแล้ว',
        'referral_reward_referee',
        jsonb_build_object(
          'referral_id', v_referral.id::text,
          'coupon_code', UPPER(v_welcome_code)
        )
      );
    END IF;
  END IF;

  -- Grant reward coupon to referrer
  SELECT * INTO v_coupon_referrer
  FROM public.coupons
  WHERE code = UPPER(v_referrer_reward_code)
    AND is_active = true
  LIMIT 1;

  IF v_coupon_referrer IS NOT NULL THEN
    IF NOT EXISTS (
      SELECT 1 FROM public.user_coupons
      WHERE user_id = v_referral.referrer_id AND coupon_id = v_coupon_referrer.id
    ) THEN
      INSERT INTO public.user_coupons (user_id, coupon_id, status, expires_at)
      VALUES (v_referral.referrer_id, v_coupon_referrer.id, 'claimed', v_coupon_referrer.end_date);
    END IF;

    -- One-time in-app notification for referrer
    IF NOT EXISTS (
      SELECT 1
      FROM public.notifications
      WHERE user_id = v_referral.referrer_id
        AND type = 'referral_reward_referrer'
        AND (data->>'referral_id') = v_referral.id::text
    ) THEN
      INSERT INTO public.notifications (user_id, title, body, type, data)
      VALUES (
        v_referral.referrer_id,
        'คุณได้รับคูปองแล้ว',
        'เพื่อนของคุณสั่งสำเร็จแล้ว คูปอง ' || UPPER(v_referrer_reward_code) || ' ถูกเพิ่มในคูปองของคุณแล้ว',
        'referral_reward_referrer',
        jsonb_build_object(
          'referral_id', v_referral.id::text,
          'coupon_code', UPPER(v_referrer_reward_code),
          'referee_id', v_customer_id::text
        )
      );
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'referral_id', v_referral.id,
    'referee_id', v_customer_id,
    'referrer_id', v_referral.referrer_id,
    'welcome_coupon_code', v_welcome_code,
    'referrer_coupon_code', v_referrer_reward_code
  );
END;
$$;

-- Trigger: on bookings status transition to completed
CREATE OR REPLACE FUNCTION public.trg_referral_qualify_on_completed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF (TG_OP = 'UPDATE')
     AND (OLD.status IS DISTINCT FROM 'completed')
     AND (NEW.status = 'completed') THEN
    PERFORM public.referral_qualify_on_booking_completed(NEW.id);
  END IF;

  RETURN NEW;
END;
$$;

DO $$ BEGIN
  CREATE TRIGGER referral_qualify_on_completed
  AFTER UPDATE OF status ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_referral_qualify_on_completed();
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;
