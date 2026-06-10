-- Customer-side cancellation for bookings paid with customer wallet.
-- Cancels only the authenticated customer's own cancellable booking and
-- refunds the exact wallet payment ledger amount once through the existing
-- idempotent refund RPC.

CREATE OR REPLACE FUNCTION public.cancel_wallet_booking_with_refund(
  p_booking_id uuid,
  p_reason text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid := auth.uid();
  v_booking record;
  v_refund_amount numeric := 0;
  v_refund_result jsonb := NULL;
BEGIN
  IF v_auth_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  SELECT
    id,
    customer_id,
    status,
    service_type,
    payment_method,
    COALESCE(price, 0) AS price,
    COALESCE(delivery_fee, 0) AS delivery_fee
  INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF v_booking.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF v_booking.customer_id <> v_auth_uid THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  IF NOT (v_booking.status = ANY (ARRAY['pending', 'pending_merchant', 'preparing'])) THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_cancellable');
  END IF;

  UPDATE public.bookings
  SET
    status = 'cancelled',
    cancellation_reason = COALESCE(p_reason, ''),
    notes = COALESCE(p_reason, notes),
    updated_at = now()
  WHERE id = p_booking_id;

  IF v_booking.payment_method = 'wallet'
    OR lower(COALESCE(v_booking.payment_method, '')) = 'wallet' THEN
    SELECT ABS(wt.amount)
    INTO v_refund_amount
    FROM public.wallet_transactions wt
    JOIN public.wallets w ON w.id = wt.wallet_id
    WHERE wt.related_booking_id = p_booking_id
      AND wt.type = 'payment'
      AND wt.amount < 0
      AND w.user_id = v_booking.customer_id
    ORDER BY wt.created_at ASC
    LIMIT 1;

    IF v_refund_amount IS NULL OR v_refund_amount <= 0 THEN
      v_refund_amount := CASE
        WHEN v_booking.service_type = 'food' THEN v_booking.price + v_booking.delivery_fee
        ELSE v_booking.price
      END;
    END IF;

    IF v_refund_amount > 0 THEN
      v_refund_result := public.refund_booking_to_customer_wallet(
        p_booking_id,
        v_refund_amount,
        'คืนเงินจากการยกเลิกออเดอร์'
      );
      IF COALESCE((v_refund_result->>'success')::boolean, false) IS NOT TRUE
        AND v_refund_result->>'error' <> 'already_refunded' THEN
        RETURN jsonb_build_object(
          'success', false,
          'error', 'wallet_refund_failed',
          'refund', v_refund_result
        );
      END IF;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'refunded', v_refund_result IS NOT NULL,
    'refund_amount', v_refund_amount,
    'refund', v_refund_result
  );
END;
$$;

REVOKE EXECUTE ON FUNCTION public.cancel_wallet_booking_with_refund(uuid, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.cancel_wallet_booking_with_refund(uuid, text) FROM anon;
GRANT EXECUTE ON FUNCTION public.cancel_wallet_booking_with_refund(uuid, text) TO authenticated;
