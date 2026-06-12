-- Align laundry pickup evidence RPC with the existing driver navigation
-- status machine. Driver UI uses `in_transit` before `completed`.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'laundry-evidence',
  'laundry-evidence',
  true,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Authenticated users can upload laundry evidence" ON storage.objects;
CREATE POLICY "Authenticated users can upload laundry evidence"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'laundry-evidence'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Authenticated users can read laundry evidence" ON storage.objects;
CREATE POLICY "Authenticated users can read laundry evidence"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'laundry-evidence');

CREATE OR REPLACE FUNCTION public.driver_confirm_laundry_pickup(
  p_booking_id uuid,
  p_evidence_url text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_driver_id uuid := auth.uid();
  v_booking record;
  v_next_order_status text;
BEGIN
  IF v_driver_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  IF NULLIF(BTRIM(COALESCE(p_evidence_url, '')), '') IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'pickup_evidence_required');
  END IF;

  SELECT id, driver_id, service_type, status, laundry_order_id, laundry_leg
  INTO v_booking
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF v_booking.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF v_booking.service_type <> 'laundry' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_laundry_booking');
  END IF;

  IF v_booking.driver_id <> v_driver_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  IF v_booking.laundry_leg NOT IN ('outbound', 'return') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_laundry_leg');
  END IF;

  IF v_booking.status NOT IN ('arrived', 'ready_for_pickup') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_status', 'status', v_booking.status);
  END IF;

  UPDATE public.bookings
  SET status = 'in_transit',
      pickup_evidence_url = BTRIM(p_evidence_url),
      pickup_evidence_uploaded_at = now(),
      updated_at = now()
  WHERE id = p_booking_id;

  v_next_order_status := CASE
    WHEN v_booking.laundry_leg = 'outbound' THEN 'outbound_picked_up'
    ELSE 'return_picked_up'
  END;

  UPDATE public.laundry_orders
  SET status = v_next_order_status,
      updated_at = now()
  WHERE id = v_booking.laundry_order_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'laundry_order_id', v_booking.laundry_order_id,
    'booking_status', 'in_transit',
    'status', v_next_order_status
  );
END;
$$;
