-- Laundry E2E rollback harness.
-- Purpose: prove production/staging DB runtime flow without leaving data behind.
-- Run with psql against the target DB:
--   psql "$SUPABASE_DB_URL" -f scripts/laundry_e2e_rollback.sql
--
-- The script wraps all changes in a transaction and ends with ROLLBACK.
-- It temporarily opens one merchant for laundry, creates a package/order,
-- sends quote, verifies wallet/cash pickup payment rules, creates outbound/
-- return bookings, assigns a driver, records pickup evidence, and completes
-- the delivery legs.

BEGIN;

DO $$
DECLARE
  v_customer_id uuid;
  v_merchant_id uuid;
  v_driver_id uuid;
  v_package_id uuid;
  v_order_id uuid;
  v_cash_order_id uuid;
  v_outbound_booking_id uuid;
  v_cash_outbound_booking_id uuid;
  v_return_booking_id uuid;
  v_return_origin_lat double precision;
  v_return_origin_lng double precision;
  v_result jsonb;
  v_visible_count integer;
  v_driver_wallet_before numeric;
  v_driver_wallet_after numeric;
  v_driver_wallet_after_duplicate numeric;
  v_customer_wallet_before numeric;
  v_customer_wallet_after numeric;
  v_return_hold_amount numeric;
  v_wallet_tx_count integer;
  v_other_user_id uuid;
BEGIN
  SELECT p.id
  INTO v_customer_id
  FROM public.profiles p
  WHERE p.role = 'customer'
  ORDER BY p.created_at DESC NULLS LAST
  LIMIT 1;

  SELECT p.id
  INTO v_merchant_id
  FROM public.profiles p
  WHERE p.role = 'merchant'
  ORDER BY p.created_at DESC NULLS LAST
  LIMIT 1;

  SELECT p.id
  INTO v_driver_id
  FROM public.profiles p
  WHERE p.role = 'driver'
  ORDER BY p.created_at DESC NULLS LAST
  LIMIT 1;

  IF v_customer_id IS NULL OR v_merchant_id IS NULL OR v_driver_id IS NULL THEN
    RAISE EXCEPTION 'Need at least one customer, merchant, and driver profile';
  END IF;

  SELECT p.id
  INTO v_other_user_id
  FROM public.profiles p
  WHERE p.id <> v_driver_id
  ORDER BY p.created_at DESC NULLS LAST
  LIMIT 1;

  IF v_other_user_id IS NULL THEN
    RAISE EXCEPTION 'Need at least one non-driver actor for authorization probe';
  END IF;

  INSERT INTO public.wallets (user_id, balance)
  VALUES (v_customer_id, 10000), (v_driver_id, 1000)
  ON CONFLICT (user_id) DO UPDATE
  SET balance = GREATEST(public.wallets.balance, EXCLUDED.balance);

  UPDATE public.profiles
  SET merchant_service_types = ARRAY(
        SELECT DISTINCT unnest(
          COALESCE(merchant_service_types, ARRAY[]::text[]) || ARRAY['laundry']
        )
      ),
      shop_status = true,
      is_online = true,
      latitude = COALESCE(latitude, 13.7563),
      longitude = COALESCE(longitude, 100.5018),
      shop_address = COALESCE(NULLIF(BTRIM(shop_address), ''), 'Rollback laundry merchant'),
      updated_at = now()
  WHERE id = v_merchant_id;

  UPDATE public.profiles
  SET accepted_service_types = ARRAY(
        SELECT DISTINCT unnest(
          COALESCE(accepted_service_types, ARRAY[]::text[]) || ARRAY['laundry']
        )
      ),
      is_online = true,
      updated_at = now()
  WHERE id = v_driver_id;

  INSERT INTO public.laundry_packages (
    merchant_id,
    name,
    description,
    base_price,
    sort_order,
    is_active
  )
  VALUES (
    v_merchant_id,
    'Rollback wash fold',
    'Rollback-only package for E2E verification',
    50,
    1,
    true
  )
  RETURNING id INTO v_package_id;

  PERFORM set_config('request.jwt.claim.sub', v_customer_id::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);

  v_result := public.create_laundry_quote_request(
    v_merchant_id,
    13.7563,
    100.5018,
    'Rollback pickup address',
    '[{"item":"shirts","qty":3}]'::jsonb,
    ARRAY['rollback/customer/quote-photo.jpg']::text[],
    'Rollback E2E request',
    v_package_id
  );
  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'create_laundry_quote_request failed: %', v_result;
  END IF;
  v_order_id := (v_result->>'laundry_order_id')::uuid;

  IF NOT EXISTS (
    SELECT 1
    FROM public.notifications n
    WHERE n.user_id = v_merchant_id
      AND n.type = 'laundry.quote_requested'
      AND (n.data->>'laundry_order_id')::uuid = v_order_id
      AND (n.data->>'play_sound')::boolean IS TRUE
      AND n.data->>'sound_key' = 'merchant_laundry_quote_new'
      AND n.data->>'recipient_role' = 'merchant'
      AND n.data->>'service_type' = 'laundry'
  ) THEN
    RAISE EXCEPTION 'laundry quote notification sound metadata was not stored';
  END IF;

  v_result := public.send_laundry_quote_message(
    v_order_id,
    'Rollback customer chat message before quote',
    'text'
  );
  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'send_laundry_quote_message customer failed: %', v_result;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.laundry_orders
    WHERE id = v_order_id
      AND attachment_urls @> '["rollback/customer/quote-photo.jpg"]'::jsonb
  ) THEN
    RAISE EXCEPTION 'laundry quote attachment path was not stored';
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_merchant_id::text, true);
  v_result := public.send_laundry_quote_message(
    v_order_id,
    'Rollback merchant chat reply before quote',
    'text'
  );
  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'send_laundry_quote_message merchant failed: %', v_result;
  END IF;

  IF (
    SELECT COUNT(*)
    FROM public.laundry_quote_messages
    WHERE laundry_order_id = v_order_id
  ) < 2 THEN
    RAISE EXCEPTION 'laundry quote chat messages were not stored';
  END IF;

  v_result := public.merchant_send_laundry_quote(
    v_order_id,
    50,
    'Rollback quote',
    60,
    20,
    NULL
  );
  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'merchant_send_laundry_quote failed: %', v_result;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_customer_id::text, true);
  v_result := public.create_laundry_quote_request(
    v_merchant_id,
    13.7564,
    100.5019,
    'Rollback cash pickup address',
    '[{"item":"cash-test","qty":1}]'::jsonb,
    ARRAY['rollback/customer/cash-quote-photo.jpg']::text[],
    'Rollback cash pickup request',
    v_package_id
  );
  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'create_laundry_quote_request cash failed: %', v_result;
  END IF;
  v_cash_order_id := (v_result->>'laundry_order_id')::uuid;

  PERFORM set_config('request.jwt.claim.sub', v_merchant_id::text, true);
  v_result := public.merchant_send_laundry_quote(
    v_cash_order_id,
    40,
    'Rollback cash quote',
    60,
    15,
    NULL
  );
  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'merchant_send_laundry_quote cash failed: %', v_result;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_customer_id::text, true);
  v_result := public.customer_accept_laundry_quote(
    v_cash_order_id,
    'cash',
    'delivery',
    'cash',
    'remote_pickup'
  );
  IF COALESCE((v_result->>'success')::boolean, false) IS TRUE
      OR COALESCE(v_result->>'error', '') <> 'pickup_cash_not_allowed' THEN
    RAISE EXCEPTION 'remote pickup cash guard failed: %', v_result;
  END IF;

  v_result := public.customer_accept_laundry_quote(
    v_cash_order_id,
    'wallet',
    'self_pickup',
    'wallet',
    'remote_pickup'
  );
  IF COALESCE((v_result->>'success')::boolean, false) IS TRUE
      OR COALESCE(v_result->>'error', '') <> 'self_pickup_wallet_not_allowed' THEN
    RAISE EXCEPTION 'self pickup wallet guard failed: %', v_result;
  END IF;

  v_result := public.customer_accept_laundry_quote(
    v_cash_order_id,
    'cash',
    'delivery',
    'cash',
    'customer_at_pickup'
  );
  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'cash pickup accept failed: %', v_result;
  END IF;
  v_cash_outbound_booking_id := (v_result->>'outbound_booking_id')::uuid;

  IF NOT EXISTS (
    SELECT 1
    FROM public.laundry_orders
    WHERE id = v_cash_order_id
      AND payment_method = 'cash'
      AND pickup_presence = 'customer_at_pickup'
      AND outbound_booking_id = v_cash_outbound_booking_id
  ) THEN
    RAISE EXCEPTION 'cash pickup order did not store payment/presence fields';
  END IF;

  SELECT balance
  INTO v_driver_wallet_before
  FROM public.wallets
  WHERE user_id = v_driver_id;

  UPDATE public.bookings
  SET driver_id = v_driver_id,
      status = 'arrived'
  WHERE id = v_cash_outbound_booking_id;

  PERFORM set_config('request.jwt.claim.sub', v_driver_id::text, true);
  v_result := public.driver_confirm_laundry_pickup(
    v_cash_outbound_booking_id,
    'rollback://cash-outbound-evidence.jpg'
  );
  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'driver_confirm_laundry_pickup cash outbound failed: %', v_result;
  END IF;

  v_result := public.complete_laundry_booking(v_cash_outbound_booking_id, v_driver_id);
  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'complete_laundry_booking cash outbound failed: %', v_result;
  END IF;
  IF COALESCE((v_result->>'wallet_credit')::numeric, -1) <> 0 THEN
    RAISE EXCEPTION 'cash outbound completion credited wallet unexpectedly: %', v_result;
  END IF;

  SELECT balance
  INTO v_driver_wallet_after
  FROM public.wallets
  WHERE user_id = v_driver_id;

  IF COALESCE(v_driver_wallet_after, -1) <> COALESCE(v_driver_wallet_before, -1) THEN
    RAISE EXCEPTION 'cash outbound changed driver wallet balance before %, after %',
      v_driver_wallet_before,
      v_driver_wallet_after;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_customer_id::text, true);
  v_result := public.customer_accept_laundry_quote(
    v_order_id,
    'wallet',
    'delivery',
    'wallet'
  );
  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'customer_accept_laundry_quote failed: %', v_result;
  END IF;
  v_outbound_booking_id := (v_result->>'outbound_booking_id')::uuid;

  SELECT COUNT(*)
  INTO v_visible_count
  FROM public.get_nearby_bookings(13.7563, 100.5018, 20, ARRAY['laundry'])
  WHERE id::uuid = v_outbound_booking_id;
  IF v_visible_count <> 1 THEN
    RAISE EXCEPTION 'outbound booking not visible to laundry driver discovery';
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_driver_id::text, true);
  UPDATE public.bookings
  SET driver_id = NULL,
      status = 'arrived',
      pickup_evidence_url = NULL,
      pickup_evidence_uploaded_at = NULL
  WHERE id = v_outbound_booking_id;

  v_result := public.driver_confirm_laundry_pickup(
    v_outbound_booking_id,
    'rollback://unassigned-outbound-evidence.jpg'
  );
  IF COALESCE((v_result->>'success')::boolean, false) IS TRUE
      OR COALESCE(v_result->>'error', '') <> 'forbidden' THEN
    RAISE EXCEPTION 'unassigned driver confirm was allowed: %', v_result;
  END IF;

  UPDATE public.bookings
  SET driver_id = NULL,
      status = 'in_transit',
      pickup_evidence_url = 'rollback://unassigned-outbound-evidence.jpg',
      pickup_evidence_uploaded_at = now()
  WHERE id = v_outbound_booking_id;

  v_result := public.complete_laundry_booking(v_outbound_booking_id, v_driver_id);
  IF COALESCE((v_result->>'success')::boolean, false) IS TRUE
      OR COALESCE(v_result->>'error', '') <> 'forbidden' THEN
    RAISE EXCEPTION 'unassigned completion was allowed: %', v_result;
  END IF;

  UPDATE public.bookings
  SET driver_id = NULL,
      status = 'pending',
      pickup_evidence_url = NULL,
      pickup_evidence_uploaded_at = NULL
  WHERE id = v_outbound_booking_id;

  v_result := public.accept_booking(v_outbound_booking_id, v_driver_id, 'pending');
  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'accept outbound booking failed: %', v_result;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_driver_id::text, true);
  v_result := public.complete_laundry_booking(v_outbound_booking_id, v_driver_id);
  IF COALESCE((v_result->>'success')::boolean, false) IS TRUE
      OR COALESCE(v_result->>'error', '') NOT IN ('invalid_status', 'pickup_evidence_required') THEN
    RAISE EXCEPTION 'pre-evidence completion was allowed: %', v_result;
  END IF;

  UPDATE public.bookings
  SET status = 'arrived'
  WHERE id = v_outbound_booking_id;

  v_result := public.driver_confirm_laundry_pickup(
    v_outbound_booking_id,
    'rollback://outbound-evidence.jpg'
  );
  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'driver_confirm_laundry_pickup outbound failed: %', v_result;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_merchant_id::text, true);
  v_result := public.create_laundry_return_booking(v_order_id, 20, 'wallet');
  IF COALESCE((v_result->>'success')::boolean, false) IS TRUE
      OR COALESCE(v_result->>'error', '') <> 'laundry_not_ready_for_return' THEN
    RAISE EXCEPTION 'early return booking guard failed: %', v_result;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_other_user_id::text, true);
  v_result := public.complete_laundry_booking(v_outbound_booking_id, v_driver_id);
  IF COALESCE((v_result->>'success')::boolean, false) IS TRUE
      OR COALESCE(v_result->>'error', '') <> 'forbidden' THEN
    RAISE EXCEPTION 'unauthorized completion was allowed: %', v_result;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_driver_id::text, true);
  SELECT balance
  INTO v_driver_wallet_before
  FROM public.wallets
  WHERE user_id = v_driver_id;

  v_result := public.complete_laundry_booking(v_outbound_booking_id, v_driver_id);
  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'complete outbound failed: %', v_result;
  END IF;
  SELECT balance
  INTO v_driver_wallet_after
  FROM public.wallets
  WHERE user_id = v_driver_id;

  IF ROUND((COALESCE(v_driver_wallet_after, 0) - COALESCE(v_driver_wallet_before, 0))::numeric, 2)
      <> ROUND(COALESCE((v_result->>'wallet_credit')::numeric, 0), 2) THEN
    RAISE EXCEPTION 'outbound wallet delta mismatch: before %, after %, result %',
      v_driver_wallet_before,
      v_driver_wallet_after,
      v_result;
  END IF;

  SELECT COUNT(*)
  INTO v_wallet_tx_count
  FROM public.wallet_transactions wt
  JOIN public.wallets w ON w.id = wt.wallet_id
  WHERE w.user_id = v_driver_id
    AND wt.related_booking_id = v_outbound_booking_id::text
    AND wt.type = 'laundry_payout';
  IF v_wallet_tx_count <> 1 THEN
    RAISE EXCEPTION 'outbound wallet transaction count mismatch: %', v_wallet_tx_count;
  END IF;

  v_result := public.complete_laundry_booking(v_outbound_booking_id, v_driver_id);
  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'duplicate outbound completion failed: %', v_result;
  END IF;
  SELECT balance
  INTO v_driver_wallet_after_duplicate
  FROM public.wallets
  WHERE user_id = v_driver_id;
  IF COALESCE(v_driver_wallet_after_duplicate, -1) <> COALESCE(v_driver_wallet_after, -1) THEN
    RAISE EXCEPTION 'duplicate completion changed wallet balance: before %, after %',
      v_driver_wallet_after,
      v_driver_wallet_after_duplicate;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_merchant_id::text, true);
  v_result := public.create_laundry_return_booking(v_order_id, 20, 'wallet');
  IF COALESCE((v_result->>'success')::boolean, false) IS TRUE
      OR COALESCE(v_result->>'error', '') <> 'laundry_not_ready_for_return' THEN
    RAISE EXCEPTION 'pre-washing return booking guard failed: %', v_result;
  END IF;

  v_result := public.merchant_update_laundry_status(v_order_id, NULL);
  IF COALESCE((v_result->>'success')::boolean, false) IS TRUE
      OR COALESCE(v_result->>'error', '') <> 'invalid_laundry_stage' THEN
    RAISE EXCEPTION 'null merchant status guard failed: %', v_result;
  END IF;

  v_result := public.merchant_update_laundry_status(v_order_id, 'washing');
  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE
      OR COALESCE(v_result->>'status', '') <> 'washing' THEN
    RAISE EXCEPTION 'merchant_update_laundry_status failed: %', v_result;
  END IF;

  SELECT balance
  INTO v_customer_wallet_before
  FROM public.wallets
  WHERE user_id = v_customer_id;

  v_result := public.create_laundry_return_booking(v_order_id, 20.009, 'wallet');
  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'create_laundry_return_booking failed: %', v_result;
  END IF;
  v_return_booking_id := (v_result->>'return_booking_id')::uuid;

  SELECT balance
  INTO v_customer_wallet_after
  FROM public.wallets
  WHERE user_id = v_customer_id;

  SELECT ABS(amount)
  INTO v_return_hold_amount
  FROM public.wallet_transactions wt
  JOIN public.wallets w ON w.id = wt.wallet_id
  WHERE w.user_id = v_customer_id
    AND wt.related_booking_id = v_return_booking_id::text
    AND wt.type = 'hold';

  IF ROUND((COALESCE(v_customer_wallet_before, 0) - COALESCE(v_customer_wallet_after, 0))::numeric, 2) <> 20.01 THEN
    RAISE EXCEPTION 'decimal return wallet delta mismatch: before %, after %',
      v_customer_wallet_before,
      v_customer_wallet_after;
  END IF;

  IF ROUND(COALESCE(v_return_hold_amount, -1)::numeric, 2) <> 20.01 THEN
    RAISE EXCEPTION 'decimal return ledger mismatch: %', v_return_hold_amount;
  END IF;

  v_result := public.create_laundry_return_booking(v_order_id, 20.009, 'wallet');
  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE
      OR COALESCE((v_result->>'already_created')::boolean, false) IS NOT TRUE
      OR (v_result->>'return_booking_id')::uuid IS DISTINCT FROM v_return_booking_id THEN
    RAISE EXCEPTION 'duplicate return booking changed id: first %, duplicate %',
      v_return_booking_id,
      v_result;
  END IF;

  SELECT origin_lat, origin_lng
  INTO v_return_origin_lat, v_return_origin_lng
  FROM public.bookings
  WHERE id = v_return_booking_id;

  SELECT COUNT(*)
  INTO v_visible_count
  FROM public.get_nearby_bookings(v_return_origin_lat, v_return_origin_lng, 20, ARRAY['laundry'])
  WHERE id::uuid = v_return_booking_id;
  IF v_visible_count <> 1 THEN
    RAISE EXCEPTION 'return booking not visible to laundry driver discovery';
  END IF;

  v_result := public.accept_booking(v_return_booking_id, v_driver_id, 'pending');
  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'accept return booking failed: %', v_result;
  END IF;

  PERFORM set_config('request.jwt.claim.sub', v_driver_id::text, true);
  UPDATE public.bookings
  SET status = 'arrived'
  WHERE id = v_return_booking_id;

  v_result := public.driver_confirm_laundry_pickup(
    v_return_booking_id,
    'rollback://return-evidence.jpg'
  );
  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'driver_confirm_laundry_pickup return failed: %', v_result;
  END IF;

  SELECT balance
  INTO v_driver_wallet_before
  FROM public.wallets
  WHERE user_id = v_driver_id;

  v_result := public.complete_laundry_booking(v_return_booking_id, v_driver_id);
  IF COALESCE((v_result->>'success')::boolean, false) IS NOT TRUE THEN
    RAISE EXCEPTION 'complete return failed: %', v_result;
  END IF;
  SELECT balance
  INTO v_driver_wallet_after
  FROM public.wallets
  WHERE user_id = v_driver_id;

  IF ROUND((COALESCE(v_driver_wallet_after, 0) - COALESCE(v_driver_wallet_before, 0))::numeric, 2)
      <> ROUND(COALESCE((v_result->>'wallet_credit')::numeric, 0), 2) THEN
    RAISE EXCEPTION 'return wallet delta mismatch: before %, after %, result %',
      v_driver_wallet_before,
      v_driver_wallet_after,
      v_result;
  END IF;

  SELECT COUNT(*)
  INTO v_wallet_tx_count
  FROM public.wallet_transactions wt
  JOIN public.wallets w ON w.id = wt.wallet_id
  WHERE w.user_id = v_driver_id
    AND wt.related_booking_id = v_return_booking_id::text
    AND wt.type = 'release';
  IF v_wallet_tx_count <> 1 THEN
    RAISE EXCEPTION 'return wallet transaction count mismatch: %', v_wallet_tx_count;
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM public.laundry_orders
    WHERE id = v_order_id
      AND status = 'completed'
      AND outbound_booking_id = v_outbound_booking_id
      AND return_booking_id = v_return_booking_id
  ) THEN
    RAISE EXCEPTION 'laundry order did not reach completed with both booking ids';
  END IF;

  RAISE NOTICE 'Laundry rollback E2E passed: order %, outbound %, return %',
    v_order_id,
    v_outbound_booking_id,
    v_return_booking_id;
END $$;

ROLLBACK;

SELECT 'laundry_rollback_e2e_passed' AS result;
