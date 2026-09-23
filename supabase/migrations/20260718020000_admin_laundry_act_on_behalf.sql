-- Admin act-on-behalf for laundry orders (admin-web).
--
-- Why: merchant_send_laundry_quote / merchant_update_laundry_status /
-- create_laundry_return_booking all verify auth.uid() = laundry_orders.merchant_id,
-- so the admin dashboard (which performs privileged writes through the
-- admin-actions edge function using service_role) has no way to act when a
-- merchant is unresponsive. There is also no way at all to cancel a laundry
-- order in stages that have no active booking (quote_requested/quoted/washing).
--
-- Approach: thin SECURITY DEFINER wrappers that impersonate the order's
-- merchant via transaction-local JWT GUCs and then call the existing merchant
-- functions, so quote/GP/stage logic stays single-source. All wrappers are
-- EXECUTE-granted to service_role ONLY — they are reachable exclusively through
-- the admin-actions edge function, which has already verified the caller is an
-- admin. set_config(..., true) is transaction-local, so the impersonation
-- cannot leak past the RPC transaction.

-- ─── helper: impersonate a user for the rest of the transaction ─────────────
CREATE OR REPLACE FUNCTION public._impersonate_for_admin_action(p_user_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  -- Cover both auth.uid() lookup paths (legacy claim GUC and claims JSON).
  PERFORM set_config('request.jwt.claim.sub', p_user_id::text, true);
  PERFORM set_config('request.jwt.claim.role', 'authenticated', true);
  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', p_user_id, 'role', 'authenticated')::text,
    true
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public._impersonate_for_admin_action(uuid) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public._impersonate_for_admin_action(uuid) FROM anon;
REVOKE EXECUTE ON FUNCTION public._impersonate_for_admin_action(uuid) FROM authenticated;
GRANT EXECUTE ON FUNCTION public._impersonate_for_admin_action(uuid) TO service_role;

-- ─── admin_send_laundry_quote ───────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_send_laundry_quote(
  p_laundry_order_id uuid,
  p_laundry_amount numeric,
  p_quote_message text DEFAULT NULL,
  p_quote_expires_minutes integer DEFAULT NULL,
  p_delivery_fee_outbound numeric DEFAULT 0,
  p_platform_gp_rate numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_merchant_id uuid;
BEGIN
  SELECT merchant_id INTO v_merchant_id
  FROM public.laundry_orders
  WHERE id = p_laundry_order_id;

  IF v_merchant_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_found');
  END IF;

  PERFORM public._impersonate_for_admin_action(v_merchant_id);

  RETURN public.merchant_send_laundry_quote(
    p_laundry_order_id,
    p_laundry_amount,
    p_quote_message,
    p_quote_expires_minutes,
    p_delivery_fee_outbound,
    p_platform_gp_rate
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_send_laundry_quote(uuid, numeric, text, integer, numeric, numeric) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_send_laundry_quote(uuid, numeric, text, integer, numeric, numeric) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_send_laundry_quote(uuid, numeric, text, integer, numeric, numeric) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_send_laundry_quote(uuid, numeric, text, integer, numeric, numeric) TO service_role;

-- ─── admin_update_laundry_status ────────────────────────────────────────────
-- Same allowed transitions and stage guards as the merchant path
-- ('washing' from at_merchant; 'completed' only for self_pickup ready_for_return).
CREATE OR REPLACE FUNCTION public.admin_update_laundry_status(
  p_laundry_order_id uuid,
  p_status text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_merchant_id uuid;
BEGIN
  SELECT merchant_id INTO v_merchant_id
  FROM public.laundry_orders
  WHERE id = p_laundry_order_id;

  IF v_merchant_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_found');
  END IF;

  PERFORM public._impersonate_for_admin_action(v_merchant_id);

  RETURN public.merchant_update_laundry_status(p_laundry_order_id, p_status);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_update_laundry_status(uuid, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_update_laundry_status(uuid, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_update_laundry_status(uuid, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_update_laundry_status(uuid, text) TO service_role;

-- ─── admin_create_laundry_return_booking ────────────────────────────────────
CREATE OR REPLACE FUNCTION public.admin_create_laundry_return_booking(
  p_laundry_order_id uuid,
  p_delivery_fee_return numeric DEFAULT 0,
  p_return_payment_method text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_merchant_id uuid;
BEGIN
  SELECT merchant_id INTO v_merchant_id
  FROM public.laundry_orders
  WHERE id = p_laundry_order_id;

  IF v_merchant_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_found');
  END IF;

  PERFORM public._impersonate_for_admin_action(v_merchant_id);

  RETURN public.create_laundry_return_booking(
    p_laundry_order_id,
    p_delivery_fee_return,
    p_return_payment_method
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_create_laundry_return_booking(uuid, numeric, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_create_laundry_return_booking(uuid, numeric, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_create_laundry_return_booking(uuid, numeric, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_create_laundry_return_booking(uuid, numeric, text) TO service_role;

-- ─── admin_cancel_laundry_order ─────────────────────────────────────────────
-- Cancels a laundry order in any non-terminal stage. Active bookings (outbound
-- and/or return leg) are cancelled through the existing guarded
-- admin_force_cancel_booking_with_wallet_refund, which derives refundable
-- amounts strictly from the wallet ledger ('payment' rows and return-leg
-- 'hold' rows) and is idempotent against double refunds.
--
-- Deliberate non-goal: if the outbound leg has already COMPLETED, its wallet
-- payment is NOT auto-refunded here (driver/merchant settlement already ran);
-- the result reports refund_skipped so the admin can decide on a manual
-- wallet adjustment instead. Cancellation itself still proceeds.
CREATE OR REPLACE FUNCTION public.admin_cancel_laundry_order(
  p_laundry_order_id uuid,
  p_reason text DEFAULT NULL,
  p_do_refund boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_order public.laundry_orders%ROWTYPE;
  v_booking record;
  v_cancel_result jsonb;
  v_cancelled_bookings jsonb := '[]'::jsonb;
  v_driver_ids uuid[] := '{}';
  v_refund_skipped boolean := false;
  v_refund_skipped_reason text := NULL;
  v_reason_suffix text := '';
BEGIN
  IF p_laundry_order_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'missing_laundry_order_id');
  END IF;

  SELECT *
  INTO v_order
  FROM public.laundry_orders
  WHERE id = p_laundry_order_id
  FOR UPDATE;

  IF v_order.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_found');
  END IF;

  IF v_order.status IN ('completed', 'cancelled') THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'order_not_cancellable',
      'status', v_order.status
    );
  END IF;

  -- Cancel any still-active leg bookings (refund handled inside, ledger-driven).
  FOR v_booking IN
    SELECT b.id, b.status, b.driver_id, b.laundry_leg
    FROM public.bookings b
    WHERE b.id IN (v_order.outbound_booking_id, v_order.return_booking_id)
      AND b.id IS NOT NULL
  LOOP
    IF v_booking.status NOT IN ('completed', 'cancelled') THEN
      -- แจ้งเฉพาะคนขับของ booking ที่ถูกยกเลิกจริง (ขาที่จบงานแล้วไม่เกี่ยว)
      IF v_booking.driver_id IS NOT NULL THEN
        v_driver_ids := array_append(v_driver_ids, v_booking.driver_id);
      END IF;

      v_cancel_result := public.admin_force_cancel_booking_with_wallet_refund(
        v_booking.id,
        COALESCE(p_reason, 'laundry order cancelled by admin'),
        p_do_refund
      );

      IF COALESCE((v_cancel_result->>'success')::boolean, false) IS NOT TRUE THEN
        -- Abort: transaction rollback keeps order/bookings/wallets consistent.
        RETURN jsonb_build_object(
          'success', false,
          'error', COALESCE(v_cancel_result->>'error', 'booking_cancel_failed'),
          'booking_id', v_booking.id,
          'cancel_result', v_cancel_result
        );
      END IF;

      v_cancelled_bookings := v_cancelled_bookings || jsonb_build_array(
        jsonb_build_object(
          'booking_id', v_booking.id,
          'laundry_leg', v_booking.laundry_leg,
          'refunded', COALESCE((v_cancel_result->>'refunded')::boolean, false),
          'refund_amount', COALESCE((v_cancel_result->>'refund_amount')::numeric, 0)
        )
      );
    ELSIF v_booking.status = 'completed'
      AND p_do_refund IS TRUE
      AND v_booking.laundry_leg = 'outbound'
      AND EXISTS (
        SELECT 1
        FROM public.wallet_transactions wt
        WHERE wt.related_booking_id = v_booking.id::text
          AND wt.type = 'payment'
          AND wt.amount < 0
      )
      AND NOT EXISTS (
        SELECT 1
        FROM public.wallet_transactions wt
        WHERE wt.related_booking_id = v_booking.id::text
          AND wt.type = 'refund'
      )
    THEN
      v_refund_skipped := true;
      v_refund_skipped_reason := 'outbound_leg_completed_manual_adjust_required';
    END IF;
  END LOOP;

  -- The return-leg branch of admin_force_cancel_booking_with_wallet_refund
  -- resets the order to 'ready_for_return'; the final state here must win.
  UPDATE public.laundry_orders
  SET status = 'cancelled',
      updated_at = now()
  WHERE id = p_laundry_order_id;

  IF NULLIF(btrim(COALESCE(p_reason, '')), '') IS NOT NULL THEN
    v_reason_suffix := ' เหตุผล: ' || btrim(p_reason);
  END IF;

  INSERT INTO public.notifications (user_id, title, body, type, data)
  SELECT DISTINCT target_user_id,
         'คำขอซักผ้าถูกยกเลิกโดยแอดมิน',
         'คำขอซักผ้า #' || LEFT(p_laundry_order_id::text, 8) || ' ถูกยกเลิกแล้ว' || v_reason_suffix,
         'laundry.cancelled',
         jsonb_build_object('laundry_order_id', p_laundry_order_id)
  FROM unnest(
    array_cat(ARRAY[v_order.customer_id, v_order.merchant_id], v_driver_ids)
  ) AS targets(target_user_id)
  WHERE target_user_id IS NOT NULL;

  RETURN jsonb_build_object(
    'success', true,
    'laundry_order_id', p_laundry_order_id,
    'previous_status', v_order.status,
    'cancelled_bookings', v_cancelled_bookings,
    'refund_skipped', v_refund_skipped,
    'refund_skipped_reason', v_refund_skipped_reason
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.admin_cancel_laundry_order(uuid, text, boolean) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.admin_cancel_laundry_order(uuid, text, boolean) FROM anon;
REVOKE EXECUTE ON FUNCTION public.admin_cancel_laundry_order(uuid, text, boolean) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.admin_cancel_laundry_order(uuid, text, boolean) TO service_role;
