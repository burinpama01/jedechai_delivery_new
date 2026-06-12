BEGIN;

ALTER TABLE IF EXISTS public.profiles
  ALTER COLUMN laundry_quote_sound_key SET DEFAULT 'merchant_laundry_quote_new';

UPDATE public.profiles
SET laundry_quote_sound_key = 'merchant_laundry_quote_new'
WHERE laundry_quote_sound_key IS NULL
   OR laundry_quote_sound_key = 'merchant_new_laundry_quote';

CREATE OR REPLACE FUNCTION public.create_laundry_quote_request(
  p_merchant_id uuid,
  p_pickup_lat double precision,
  p_pickup_lng double precision,
  p_pickup_address text,
  p_requested_items jsonb DEFAULT '[]'::jsonb,
  p_attachment_urls text[] DEFAULT ARRAY[]::text[],
  p_customer_note text DEFAULT NULL,
  p_package_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_customer_id uuid := auth.uid();
  v_order_id uuid;
  v_sound_enabled boolean := true;
  v_sound_key text := 'merchant_laundry_quote_new';
BEGIN
  IF v_customer_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  IF p_merchant_id IS NULL
    OR p_pickup_lat IS NULL
    OR p_pickup_lng IS NULL
    OR NULLIF(BTRIM(p_pickup_address), '') IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'missing_required_fields');
  END IF;

  IF jsonb_typeof(COALESCE(p_requested_items, '[]'::jsonb)) <> 'array' THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_requested_items');
  END IF;

  SELECT
    COALESCE(p.laundry_quote_sound_enabled, true),
    COALESCE(NULLIF(BTRIM(p.laundry_quote_sound_key), ''), 'merchant_laundry_quote_new')
  INTO v_sound_enabled, v_sound_key
  FROM public.profiles p
  WHERE p.id = p_merchant_id
    AND p.role = 'merchant'
    AND 'laundry' = ANY(COALESCE(p.merchant_service_types, ARRAY[]::text[]));

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'merchant_not_laundry');
  END IF;

  IF p_package_id IS NOT NULL
    AND NOT EXISTS (
      SELECT 1
      FROM public.laundry_packages lp
      WHERE lp.id = p_package_id
        AND lp.merchant_id = p_merchant_id
        AND lp.is_active = true
    ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'package_not_found');
  END IF;

  INSERT INTO public.laundry_orders (
    customer_id,
    merchant_id,
    package_id,
    requested_items,
    attachment_urls,
    customer_note,
    pickup_lat,
    pickup_lng,
    pickup_address
  )
  VALUES (
    v_customer_id,
    p_merchant_id,
    p_package_id,
    COALESCE(p_requested_items, '[]'::jsonb),
    to_jsonb(COALESCE(p_attachment_urls, ARRAY[]::text[])),
    p_customer_note,
    p_pickup_lat,
    p_pickup_lng,
    BTRIM(p_pickup_address)
  )
  RETURNING id INTO v_order_id;

  INSERT INTO public.notifications (user_id, title, body, type, data)
  VALUES (
    p_merchant_id,
    'มีคำขอประเมินราคาซักผ้าใหม่',
    'ลูกค้าส่งคำขอประเมินราคาซักผ้า รหัส #' || LEFT(v_order_id::text, 8),
    'laundry.quote_requested',
    jsonb_build_object(
      'laundry_order_id', v_order_id,
      'service_type', 'laundry',
      'recipient_role', 'merchant',
      'sound_enabled', v_sound_enabled,
      'play_sound', v_sound_enabled,
      'sound_key', CASE WHEN v_sound_enabled THEN v_sound_key ELSE NULL END,
      'notification_channel', 'laundry_quote'
    )
  );

  RETURN jsonb_build_object('success', true, 'laundry_order_id', v_order_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.create_laundry_quote_request(uuid, double precision, double precision, text, jsonb, text[], text, uuid) TO authenticated;

COMMIT;
