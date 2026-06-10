-- Sprint 4.4: Multi-stop Delivery
-- Stores individual delivery stops for bookings that have multiple destinations.

CREATE TABLE IF NOT EXISTS booking_stops (
  id           uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id   uuid NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
  stop_order   integer NOT NULL,
  address      text,
  lat          double precision,
  lng          double precision,
  status       text NOT NULL DEFAULT 'pending',  -- pending | arrived | completed
  completed_at timestamptz,
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_booking_stops_booking_id ON booking_stops(booking_id);
CREATE INDEX IF NOT EXISTS idx_booking_stops_status     ON booking_stops(booking_id, status);
ALTER TABLE booking_stops ENABLE ROW LEVEL SECURITY;
-- Customer can read stops for their own bookings
CREATE POLICY "customer_read_own_booking_stops" ON booking_stops
  FOR SELECT TO authenticated
  USING (
    booking_id IN (
      SELECT id FROM bookings WHERE customer_id = auth.uid()
    )
  );
-- Driver can read stops for bookings assigned to them
CREATE POLICY "driver_read_own_booking_stops" ON booking_stops
  FOR SELECT TO authenticated
  USING (
    booking_id IN (
      SELECT id FROM bookings WHERE driver_id = auth.uid()
    )
  );
-- Driver can update stop status for their assigned bookings
CREATE POLICY "driver_update_own_booking_stops" ON booking_stops
  FOR UPDATE TO authenticated
  USING (
    booking_id IN (
      SELECT id FROM bookings WHERE driver_id = auth.uid()
    )
  )
  WITH CHECK (
    booking_id IN (
      SELECT id FROM bookings WHERE driver_id = auth.uid()
    )
  );
-- Admin has full access
CREATE POLICY "admin_all_booking_stops" ON booking_stops
  FOR ALL TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
