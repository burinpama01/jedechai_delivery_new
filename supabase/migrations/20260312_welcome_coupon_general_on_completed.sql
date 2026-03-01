-- Phase 2 (TODO): Auto-grant welcome coupon for non-referral new customers
-- Trigger-based so it works regardless of how booking status is updated.
--
-- Config keys (system_config key-value rows):
--  - welcome_coupon_code_general: coupon code to grant to new customers (non-referral) after first completed booking

CREATE OR REPLACE FUNCTION public.welcome_coupon_general_on_booking_completed(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking record;
  v_customer_id uuid;
  v_prev_completed_count int;

  v_welcome_code text;
  v_coupon record;
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

  -- Skip if this customer ever used referral (pending/qualified/any)
  IF EXISTS (
    SELECT 1
    FROM public.referrals
    WHERE referee_id = v_customer_id
  ) THEN
    RETURN jsonb_build_object('success', true, 'skipped', true, 'reason', 'has_referral');
  END IF;

  -- Load coupon code from config (KV rows)
  SELECT value INTO v_welcome_code
  FROM public.system_config
  WHERE key = 'welcome_coupon_code_general'
  LIMIT 1;

  -- Fallback (so dev environment still works)
  v_welcome_code := COALESCE(NULLIF(TRIM(v_welcome_code), ''), 'WELCOME20');

  -- Grant welcome coupon to customer (insert into user_coupons if coupon exists)
  SELECT * INTO v_coupon
  FROM public.coupons
  WHERE code = UPPER(v_welcome_code)
    AND is_active = true
  LIMIT 1;

  IF v_coupon IS NULL THEN
    RETURN jsonb_build_object('success', true, 'skipped', true, 'reason', 'coupon_not_found');
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.user_coupons
    WHERE user_id = v_customer_id AND coupon_id = v_coupon.id
  ) THEN
    INSERT INTO public.user_coupons (user_id, coupon_id, status, expires_at)
    VALUES (v_customer_id, v_coupon.id, 'claimed', v_coupon.end_date);
  END IF;

  -- One-time in-app notification for general welcome coupon
  IF NOT EXISTS (
    SELECT 1
    FROM public.notifications
    WHERE user_id = v_customer_id
      AND type = 'welcome_coupon_general'
      AND (data->>'coupon_code') = UPPER(v_welcome_code)
  ) THEN
    INSERT INTO public.notifications (user_id, title, body, type, data)
    VALUES (
      v_customer_id,
      'คุณได้รับคูปองแล้ว',
      'คูปองต้อนรับ ' || UPPER(v_welcome_code) || ' ถูกเพิ่มในคูปองของคุณแล้ว',
      'welcome_coupon_general',
      jsonb_build_object(
        'coupon_code', UPPER(v_welcome_code),
        'booking_id', p_booking_id::text
      )
    );
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'customer_id', v_customer_id,
    'welcome_coupon_code', v_welcome_code
  );
END;
$$;

-- Trigger: on bookings status transition to completed
CREATE OR REPLACE FUNCTION public.trg_welcome_coupon_general_on_completed()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF (TG_OP = 'UPDATE')
     AND (OLD.status IS DISTINCT FROM 'completed')
     AND (NEW.status = 'completed') THEN
    PERFORM public.welcome_coupon_general_on_booking_completed(NEW.id);
  END IF;

  RETURN NEW;
END;
$$;

DO $$ BEGIN
  CREATE TRIGGER welcome_coupon_general_on_completed
  AFTER UPDATE OF status ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION public.trg_welcome_coupon_general_on_completed();
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;
