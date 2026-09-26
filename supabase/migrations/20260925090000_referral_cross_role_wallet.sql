-- Cross-role referral Wallet rewards. Apply only after staging payout/UAT review.
BEGIN;

INSERT INTO public.system_config (key, value)
SELECT k, v FROM (VALUES
  ('referral_reward_base_customer_invite_merchant', '10'),
  ('referral_reward_base_customer_invite_customer', '10'),
  ('referral_reward_base_driver_invite_customer', '20'),
  ('referral_reward_base_customer_invite_driver', '10')
) AS d(k, v)
WHERE NOT EXISTS (SELECT 1 FROM public.system_config sc WHERE sc.key = d.k);

-- Existing customer→merchant values are intentionally preserved: 20 may be an
-- explicit Admin choice. Inspect existing values before changing them in Admin.

-- The March trigger consumes the same pending referral and pays fixed rewards.
-- Its old function remains for historical compatibility but is not executed.
DROP TRIGGER IF EXISTS referral_qualify_on_completed ON public.bookings;
REVOKE ALL ON FUNCTION public.referral_qualify_on_booking_completed(uuid)
  FROM PUBLIC, anon, authenticated;

-- S4/S5: a referred customer completes their first booking.
CREATE OR REPLACE FUNCTION public.referral_on_customer_first_job()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_ref record;
  v_referrer_role text;
  v_referee_role text;
  v_base_key text;
BEGIN
  IF NEW.status IS DISTINCT FROM 'completed'
     OR OLD.status IS NOT DISTINCT FROM 'completed'
     OR NEW.customer_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF EXISTS (SELECT 1 FROM public.bookings
             WHERE customer_id = NEW.customer_id AND status = 'completed' AND id <> NEW.id) THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_ref FROM public.referrals
  WHERE referee_id = NEW.customer_id AND status = 'pending' FOR UPDATE;
  IF NOT FOUND THEN RETURN NEW; END IF;

  SELECT role INTO v_referee_role FROM public.profiles WHERE id = NEW.customer_id;
  SELECT role INTO v_referrer_role FROM public.profiles WHERE id = v_ref.referrer_id;
  IF v_referee_role IS DISTINCT FROM 'customer'
     OR v_referrer_role IS NULL
     OR v_referrer_role NOT IN ('customer', 'driver') THEN
    RETURN NEW;
  END IF;

  v_base_key := CASE WHEN v_referrer_role = 'customer'
    THEN 'referral_reward_base_customer_invite_customer'
    ELSE 'referral_reward_base_driver_invite_customer' END;
  -- Missing config disables this new scenario instead of falling back to 20.
  IF NOT EXISTS (SELECT 1 FROM public.system_config WHERE key = v_base_key) THEN
    RETURN NEW;
  END IF;

  UPDATE public.referrals
  SET status = 'qualified', qualified_at = now(), updated_at = now(),
      scenario = CASE WHEN v_referrer_role = 'customer' THEN 'S4' ELSE 'S5' END
  WHERE id = v_ref.id;

  PERFORM public._grant_referral_reward(
    v_ref.id, v_ref.referrer_id,
    CASE WHEN v_referrer_role = 'customer'
      THEN 'referrer_customer_invite_customer'
      ELSE 'referrer_driver_invite_customer' END,
    v_base_key, true);
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_referral_on_customer_first_job ON public.bookings;
CREATE TRIGGER trg_referral_on_customer_first_job
  AFTER UPDATE OF status ON public.bookings
  FOR EACH ROW EXECUTE FUNCTION public.referral_on_customer_first_job();

-- S3/S6: a referred driver completes their first booking. A customer referrer
-- receives the configurable reward; a driver referrer keeps the existing S3
-- two-sided reward.
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

  SELECT * INTO v_ref FROM public.referrals
  WHERE referee_id = NEW.driver_id AND status = 'pending' FOR UPDATE;
  IF NOT FOUND THEN RETURN NEW; END IF;

  SELECT role INTO v_referrer_role FROM public.profiles WHERE id = v_ref.referrer_id;
  SELECT role INTO v_referee_role FROM public.profiles WHERE id = NEW.driver_id;
  IF v_referee_role IS DISTINCT FROM 'driver'
     OR v_referrer_role IS NULL
     OR v_referrer_role NOT IN ('driver', 'customer') THEN
    RETURN NEW;
  END IF;

  IF v_referrer_role = 'customer' AND NOT EXISTS (
    SELECT 1 FROM public.system_config
    WHERE key = 'referral_reward_base_customer_invite_driver'
  ) THEN RETURN NEW; END IF;

  UPDATE public.referrals
  SET status = 'qualified', qualified_at = now(), updated_at = now(),
      scenario = CASE WHEN v_referrer_role = 'driver' THEN 'S3' ELSE 'S6' END
  WHERE id = v_ref.id;

  IF v_referrer_role = 'driver' THEN
    PERFORM public._grant_referral_reward(v_ref.id, v_ref.referrer_id,
      'referrer_driver_invite_driver',
      'referral_reward_base_driver_invite_driver_referrer', true);
    PERFORM public._grant_referral_reward(v_ref.id, NEW.driver_id,
      'referee_new_driver',
      'referral_reward_base_driver_invite_driver_newdriver', false);
  ELSE
    PERFORM public._grant_referral_reward(v_ref.id, v_ref.referrer_id,
      'referrer_customer_invite_driver',
      'referral_reward_base_customer_invite_driver', true);
  END IF;
  RETURN NEW;
END;
$$;

-- A code may be attached only while the referred role can still meet its
-- first-success condition. This prevents permanently pending referrals from
-- accounts that completed a job or merchant approval before using the code.
CREATE OR REPLACE FUNCTION public.process_referral(p_referee_id uuid, p_referral_code text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_referrer record;
  v_referral_id uuid;
  v_role text;
  v_approval text;
  v_referrer_role text;
BEGIN
  IF auth.uid() IS NULL OR (auth.uid() <> p_referee_id AND NOT public.is_admin()) THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;
  IF EXISTS (SELECT 1 FROM public.referrals WHERE referee_id = p_referee_id) THEN
    RETURN jsonb_build_object('success', false, 'error', 'already_referred');
  END IF;

  SELECT role, approval_status INTO v_role, v_approval
  FROM public.profiles WHERE id = p_referee_id;
  IF v_role IS NULL OR v_role NOT IN ('customer', 'driver', 'merchant') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_referee_role');
  END IF;
  IF (v_role = 'customer' AND EXISTS (
      SELECT 1 FROM public.bookings
      WHERE customer_id = p_referee_id AND status = 'completed'))
     OR (v_role = 'driver' AND EXISTS (
      SELECT 1 FROM public.bookings
      WHERE driver_id = p_referee_id AND status = 'completed'))
     OR (v_role = 'merchant' AND v_approval = 'approved') THEN
    RETURN jsonb_build_object('success', false, 'error', 'referral_window_closed');
  END IF;

  SELECT * INTO v_referrer FROM public.referral_codes
  WHERE code = UPPER(BTRIM(p_referral_code));
  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_referral_code');
  END IF;
  IF v_referrer.user_id = p_referee_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'self_referral');
  END IF;
  SELECT role INTO v_referrer_role FROM public.profiles WHERE id = v_referrer.user_id;
  IF v_referrer_role IS NULL OR v_referrer_role NOT IN ('customer', 'driver') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_referrer_role');
  END IF;

  INSERT INTO public.referrals (referrer_id, referee_id, referral_code_used, status)
  VALUES (v_referrer.user_id, p_referee_id, UPPER(BTRIM(p_referral_code)), 'pending')
  RETURNING id INTO v_referral_id;
  RETURN jsonb_build_object('success', true, 'referral_id', v_referral_id);
END;
$$;

REVOKE ALL ON FUNCTION public.process_referral(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.process_referral(uuid, text) TO authenticated, service_role;

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
    SELECT value::jsonb INTO v_json FROM public.system_config
    WHERE key = 'referral_reward_tiers' LIMIT 1;
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
      'customer_invite_merchant', public._config_num('referral_reward_base_customer_invite_merchant', 10),
      'driver_invite_driver_referrer', public._config_num('referral_reward_base_driver_invite_driver_referrer', 20),
      'driver_invite_driver_newdriver', public._config_num('referral_reward_base_driver_invite_driver_newdriver', 20),
      'customer_invite_customer', public._config_num('referral_reward_base_customer_invite_customer', 10),
      'driver_invite_customer', public._config_num('referral_reward_base_driver_invite_customer', 20),
      'customer_invite_driver', public._config_num('referral_reward_base_customer_invite_driver', 10)),
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

-- Preserve the existing merchant approval flow while rejecting missing referrer profiles.
CREATE OR REPLACE FUNCTION public.referral_on_merchant_approved()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_ref record;
  v_referrer_role text;
BEGIN
  IF NEW.role <> 'merchant' OR NEW.approval_status IS DISTINCT FROM 'approved'
     OR OLD.approval_status IS NOT DISTINCT FROM 'approved' THEN
    RETURN NEW;
  END IF;

  SELECT * INTO v_ref FROM public.referrals
  WHERE referee_id = NEW.id AND status = 'pending' FOR UPDATE;
  IF NOT FOUND THEN RETURN NEW; END IF;

  SELECT role INTO v_referrer_role FROM public.profiles WHERE id = v_ref.referrer_id;
  IF v_referrer_role IS NULL OR v_referrer_role NOT IN ('driver', 'customer') THEN
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

COMMIT;
