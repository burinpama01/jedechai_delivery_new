-- Migration: Parcel Service Fixes
-- Date: 2026-05-16
-- Issues: ISSUE-052, ISSUE-055, ISSUE-057, ISSUE-059

-- ========================================
-- ISSUE-055: Add delivery_notes column
-- ========================================
ALTER TABLE parcel_details
  ADD COLUMN IF NOT EXISTS delivery_notes TEXT;

COMMENT ON COLUMN parcel_details.delivery_notes IS 'หมายเหตุจากคนขับตอนส่งของ';

-- ========================================
-- ISSUE-057: Auto-set picked_up_at / delivered_at on status change
-- ========================================
CREATE OR REPLACE FUNCTION set_parcel_timestamps()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.parcel_status = 'picked_up'
     AND OLD.parcel_status IS DISTINCT FROM 'picked_up'
     AND NEW.picked_up_at IS NULL
  THEN
    NEW.picked_up_at = NOW();
  END IF;
  IF NEW.parcel_status = 'delivered'
     AND OLD.parcel_status IS DISTINCT FROM 'delivered'
     AND NEW.delivered_at IS NULL
  THEN
    NEW.delivered_at = NOW();
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_set_parcel_timestamps ON parcel_details;
CREATE TRIGGER trigger_set_parcel_timestamps
  BEFORE UPDATE ON parcel_details
  FOR EACH ROW
  EXECUTE FUNCTION set_parcel_timestamps();

-- ========================================
-- ISSUE-059: Admin RLS policy on parcel_details
-- ========================================
DROP POLICY IF EXISTS "Admins can do everything on parcel_details" ON parcel_details;
CREATE POLICY "Admins can do everything on parcel_details" ON parcel_details
  FOR ALL
  USING (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ========================================
-- ISSUE-052: Atomic create_parcel_booking RPC
-- ========================================
CREATE OR REPLACE FUNCTION create_parcel_booking(
  p_origin_lat          FLOAT8,
  p_origin_lng          FLOAT8,
  p_dest_lat            FLOAT8,
  p_dest_lng            FLOAT8,
  p_distance_km         FLOAT8,
  p_price               FLOAT8,
  p_pickup_address      TEXT,
  p_destination_address TEXT,
  p_notes               TEXT,
  p_scheduled_at        TIMESTAMPTZ,
  p_sender_name         TEXT,
  p_sender_phone        TEXT,
  p_recipient_name      TEXT,
  p_recipient_phone     TEXT,
  p_parcel_size         TEXT,
  p_description         TEXT,
  p_estimated_weight_kg FLOAT8,
  p_parcel_photo_url    TEXT
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY INVOKER
AS $$
DECLARE
  v_customer_id UUID;
  v_booking_id  UUID;
  v_booking     JSON;
BEGIN
  v_customer_id := auth.uid();
  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  INSERT INTO bookings (
    customer_id, service_type,
    origin_lat, origin_lng, dest_lat, dest_lng,
    distance_km, price,
    pickup_address, destination_address,
    notes, status, payment_method, scheduled_at
  ) VALUES (
    v_customer_id, 'parcel',
    p_origin_lat, p_origin_lng, p_dest_lat, p_dest_lng,
    p_distance_km, p_price,
    p_pickup_address, p_destination_address,
    p_notes, 'pending', 'cash', p_scheduled_at
  )
  RETURNING id INTO v_booking_id;

  INSERT INTO parcel_details (
    booking_id,
    sender_name, sender_phone, sender_address,
    recipient_name, recipient_phone, recipient_address,
    description, parcel_size,
    estimated_weight_kg, parcel_photo_url,
    parcel_status
  ) VALUES (
    v_booking_id,
    p_sender_name, p_sender_phone, p_pickup_address,
    p_recipient_name, p_recipient_phone, p_destination_address,
    p_description, p_parcel_size,
    p_estimated_weight_kg, p_parcel_photo_url,
    'created'
  );

  SELECT row_to_json(b) INTO v_booking
  FROM bookings b
  WHERE b.id = v_booking_id;

  RETURN v_booking;
END;
$$;

GRANT EXECUTE ON FUNCTION create_parcel_booking(
  FLOAT8, FLOAT8, FLOAT8, FLOAT8, FLOAT8, FLOAT8,
  TEXT, TEXT, TEXT, TIMESTAMPTZ,
  TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, FLOAT8, TEXT
) TO authenticated;
