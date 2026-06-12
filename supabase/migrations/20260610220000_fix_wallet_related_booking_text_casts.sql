-- Runtime fix for wallet_transactions.related_booking_id.
-- The column is text in production, while wallet/laundry RPC params use uuid.
-- Comparing text = uuid fails at runtime, so patch current function bodies to
-- compare against p_booking_id::text without changing the ledger schema.

DO $$
DECLARE
  v_function_sql text;
BEGIN
  SELECT pg_get_functiondef('public.customer_wallet_pay_booking(uuid, uuid, numeric, text)'::regprocedure)
  INTO v_function_sql;

  IF v_function_sql IS NULL THEN
    RAISE EXCEPTION 'customer_wallet_pay_booking(uuid, uuid, numeric, text) not found';
  END IF;

  v_function_sql := replace(
    v_function_sql,
    'AND related_booking_id = p_booking_id',
    'AND related_booking_id = p_booking_id::text'
  );

  EXECUTE v_function_sql;

  SELECT pg_get_functiondef('public.complete_laundry_booking(uuid, uuid)'::regprocedure)
  INTO v_function_sql;

  IF v_function_sql IS NULL THEN
    RAISE EXCEPTION 'complete_laundry_booking(uuid, uuid) not found';
  END IF;

  v_function_sql := replace(
    v_function_sql,
    'AND wt.related_booking_id = p_booking_id',
    'AND wt.related_booking_id = p_booking_id::text'
  );

  EXECUTE v_function_sql;
END $$;

GRANT EXECUTE ON FUNCTION public.customer_wallet_pay_booking(uuid, uuid, numeric, text)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.complete_laundry_booking(uuid, uuid)
  TO authenticated, service_role;
