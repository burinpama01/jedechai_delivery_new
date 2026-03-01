-- Phase 12: Driver referral wallet reward (topup 100) on referee first completed booking
-- Updates referral qualification function to support referee as customer or driver.
-- Reward type is based on profiles.role:
--  - customer: coupon (WELCOME20 / REFERRER20)
--  - driver: wallet topup 100

CREATE OR REPLACE FUNCTION public.referral_qualify_on_booking_completed(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking record;
  v_results jsonb := '{}'::jsonb;

  v_welcome_code text;
  v_referrer_reward_code text;
BEGIN
  SELECT id, customer_id, driver_id, status INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id;

  IF v_booking IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF v_booking.status IS DISTINCT FROM 'completed' THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_completed');
  END IF;

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

  -- ────────────────────────────────────────────────────────────
  -- Case A) Referee = customer_id (customer-first-completed)
  -- ────────────────────────────────────────────────────────────
  IF v_booking.customer_id IS NOT NULL THEN
    DECLARE
      v_referee_id uuid := v_booking.customer_id;
      v_prev_completed_count int;
      v_referral record;
      v_referee_role text;
      v_referrer_role text;
      v_coupon_referee record;
      v_coupon_referrer record;
    BEGIN
      -- Only on first completed booking as customer
      SELECT count(*) INTO v_prev_completed_count
      FROM public.bookings
      WHERE customer_id = v_referee_id
        AND status = 'completed'
        AND id <> p_booking_id;

      IF v_prev_completed_count = 0 THEN
        SELECT * INTO v_referral
        FROM public.referrals
        WHERE referee_id = v_referee_id
          AND status = 'pending'
        LIMIT 1;

        IF v_referral IS NOT NULL THEN
          UPDATE public.referrals
          SET status = 'qualified',
              qualified_at = now(),
              updated_at = now()
          WHERE id = v_referral.id
            AND status = 'pending';

          SELECT role INTO v_referee_role
          FROM public.profiles
          WHERE id = v_referee_id
          LIMIT 1;

          SELECT role INTO v_referrer_role
          FROM public.profiles
          WHERE id = v_referral.referrer_id
          LIMIT 1;

          -- Reward for referee (role-based)
          IF COALESCE(v_referee_role, '') = 'customer' THEN
            SELECT * INTO v_coupon_referee
            FROM public.coupons
            WHERE code = UPPER(v_welcome_code)
              AND is_active = true
            LIMIT 1;

            IF v_coupon_referee IS NOT NULL THEN
              IF NOT EXISTS (
                SELECT 1 FROM public.user_coupons
                WHERE user_id = v_referee_id AND coupon_id = v_coupon_referee.id
              ) THEN
                INSERT INTO public.user_coupons (user_id, coupon_id, status, expires_at)
                VALUES (v_referee_id, v_coupon_referee.id, 'claimed', v_coupon_referee.end_date);
              END IF;

              IF NOT EXISTS (
                SELECT 1
                FROM public.notifications
                WHERE user_id = v_referee_id
                  AND type = 'referral_reward_referee'
                  AND (data->>'referral_id') = v_referral.id::text
              ) THEN
                INSERT INTO public.notifications (user_id, title, body, type, data)
                VALUES (
                  v_referee_id,
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
          ELSIF COALESCE(v_referee_role, '') = 'driver' THEN
            PERFORM public.wallet_topup(v_referee_id, 100, 'Referral reward');

            IF NOT EXISTS (
              SELECT 1
              FROM public.notifications
              WHERE user_id = v_referee_id
                AND type = 'referral_wallet_reward_referee'
                AND (data->>'referral_id') = v_referral.id::text
            ) THEN
              INSERT INTO public.notifications (user_id, title, body, type, data)
              VALUES (
                v_referee_id,
                'คุณได้รับเงินแล้ว',
                'รับเงินรางวัลเข้ากระเป๋า 100 บาทเรียบร้อยแล้ว',
                'referral_wallet_reward_referee',
                jsonb_build_object(
                  'referral_id', v_referral.id::text,
                  'amount', 100,
                  'booking_id', p_booking_id::text
                )
              );
            END IF;
          END IF;

          -- Reward for referrer (role-based)
          IF COALESCE(v_referrer_role, '') = 'customer' THEN
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
                    'referee_id', v_referee_id::text
                  )
                );
              END IF;
            END IF;
          ELSIF COALESCE(v_referrer_role, '') = 'driver' THEN
            PERFORM public.wallet_topup(v_referral.referrer_id, 100, 'Referral reward');

            IF NOT EXISTS (
              SELECT 1
              FROM public.notifications
              WHERE user_id = v_referral.referrer_id
                AND type = 'referral_wallet_reward_referrer'
                AND (data->>'referral_id') = v_referral.id::text
            ) THEN
              INSERT INTO public.notifications (user_id, title, body, type, data)
              VALUES (
                v_referral.referrer_id,
                'คุณได้รับเงินแล้ว',
                'เพื่อนของคุณทำรายการสำเร็จแล้ว รับเงินรางวัลเข้ากระเป๋า 100 บาทเรียบร้อยแล้ว',
                'referral_wallet_reward_referrer',
                jsonb_build_object(
                  'referral_id', v_referral.id::text,
                  'amount', 100,
                  'booking_id', p_booking_id::text,
                  'referee_id', v_referee_id::text
                )
              );
            END IF;
          END IF;

          v_results := v_results || jsonb_build_object(
            'customer_case', jsonb_build_object(
              'success', true,
              'referral_id', v_referral.id,
              'referee_id', v_referee_id,
              'referrer_id', v_referral.referrer_id
            )
          );
        END IF;
      END IF;
    END;
  END IF;

  -- ────────────────────────────────────────────────────────────
  -- Case B) Referee = driver_id (driver-first-completed)
  -- ────────────────────────────────────────────────────────────
  IF v_booking.driver_id IS NOT NULL THEN
    DECLARE
      v_referee_id uuid := v_booking.driver_id;
      v_prev_completed_count int;
      v_referral record;
      v_referee_role text;
      v_referrer_role text;
      v_coupon_referee record;
      v_coupon_referrer record;
    BEGIN
      -- Only on first completed booking as driver
      SELECT count(*) INTO v_prev_completed_count
      FROM public.bookings
      WHERE driver_id = v_referee_id
        AND status = 'completed'
        AND id <> p_booking_id;

      IF v_prev_completed_count = 0 THEN
        SELECT * INTO v_referral
        FROM public.referrals
        WHERE referee_id = v_referee_id
          AND status = 'pending'
        LIMIT 1;

        IF v_referral IS NOT NULL THEN
          UPDATE public.referrals
          SET status = 'qualified',
              qualified_at = now(),
              updated_at = now()
          WHERE id = v_referral.id
            AND status = 'pending';

          SELECT role INTO v_referee_role
          FROM public.profiles
          WHERE id = v_referee_id
          LIMIT 1;

          SELECT role INTO v_referrer_role
          FROM public.profiles
          WHERE id = v_referral.referrer_id
          LIMIT 1;

          -- Reward for referee (role-based)
          IF COALESCE(v_referee_role, '') = 'customer' THEN
            SELECT * INTO v_coupon_referee
            FROM public.coupons
            WHERE code = UPPER(v_welcome_code)
              AND is_active = true
            LIMIT 1;

            IF v_coupon_referee IS NOT NULL THEN
              IF NOT EXISTS (
                SELECT 1 FROM public.user_coupons
                WHERE user_id = v_referee_id AND coupon_id = v_coupon_referee.id
              ) THEN
                INSERT INTO public.user_coupons (user_id, coupon_id, status, expires_at)
                VALUES (v_referee_id, v_coupon_referee.id, 'claimed', v_coupon_referee.end_date);
              END IF;

              IF NOT EXISTS (
                SELECT 1
                FROM public.notifications
                WHERE user_id = v_referee_id
                  AND type = 'referral_reward_referee'
                  AND (data->>'referral_id') = v_referral.id::text
              ) THEN
                INSERT INTO public.notifications (user_id, title, body, type, data)
                VALUES (
                  v_referee_id,
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
          ELSIF COALESCE(v_referee_role, '') = 'driver' THEN
            PERFORM public.wallet_topup(v_referee_id, 100, 'Referral reward');

            IF NOT EXISTS (
              SELECT 1
              FROM public.notifications
              WHERE user_id = v_referee_id
                AND type = 'referral_wallet_reward_referee'
                AND (data->>'referral_id') = v_referral.id::text
            ) THEN
              INSERT INTO public.notifications (user_id, title, body, type, data)
              VALUES (
                v_referee_id,
                'คุณได้รับเงินแล้ว',
                'รับเงินรางวัลเข้ากระเป๋า 100 บาทเรียบร้อยแล้ว',
                'referral_wallet_reward_referee',
                jsonb_build_object(
                  'referral_id', v_referral.id::text,
                  'amount', 100,
                  'booking_id', p_booking_id::text
                )
              );
            END IF;
          END IF;

          -- Reward for referrer (role-based)
          IF COALESCE(v_referrer_role, '') = 'customer' THEN
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
                    'referee_id', v_referee_id::text
                  )
                );
              END IF;
            END IF;
          ELSIF COALESCE(v_referrer_role, '') = 'driver' THEN
            PERFORM public.wallet_topup(v_referral.referrer_id, 100, 'Referral reward');

            IF NOT EXISTS (
              SELECT 1
              FROM public.notifications
              WHERE user_id = v_referral.referrer_id
                AND type = 'referral_wallet_reward_referrer'
                AND (data->>'referral_id') = v_referral.id::text
            ) THEN
              INSERT INTO public.notifications (user_id, title, body, type, data)
              VALUES (
                v_referral.referrer_id,
                'คุณได้รับเงินแล้ว',
                'เพื่อนของคุณทำรายการสำเร็จแล้ว รับเงินรางวัลเข้ากระเป๋า 100 บาทเรียบร้อยแล้ว',
                'referral_wallet_reward_referrer',
                jsonb_build_object(
                  'referral_id', v_referral.id::text,
                  'amount', 100,
                  'booking_id', p_booking_id::text,
                  'referee_id', v_referee_id::text
                )
              );
            END IF;
          END IF;

          v_results := v_results || jsonb_build_object(
            'driver_case', jsonb_build_object(
              'success', true,
              'referral_id', v_referral.id,
              'referee_id', v_referee_id,
              'referrer_id', v_referral.referrer_id
            )
          );
        END IF;
      END IF;
    END;
  END IF;

  RETURN jsonb_build_object('success', true, 'results', v_results);
END;
$$;
