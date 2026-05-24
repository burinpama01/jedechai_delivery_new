-- Add 'preparing' to driver UPDATE policy on bookings
-- The accept_booking RPC (SECURITY DEFINER) already bypasses RLS,
-- but adding 'preparing' here prevents silent blocks for any future
-- direct driver-role operations on preparing food bookings.

DROP POLICY IF EXISTS "bookings_update_driver" ON public.bookings;

CREATE POLICY "bookings_update_driver" ON public.bookings
  FOR UPDATE USING (
    auth.uid() = driver_id
    OR (driver_id IS NULL AND status IN ('pending', 'preparing', 'ready_for_pickup'))
  );
