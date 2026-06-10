DROP POLICY IF EXISTS "bookings_update_driver" ON public.bookings;
CREATE POLICY "bookings_update_driver" ON public.bookings
  FOR UPDATE USING (
    auth.uid() = driver_id
    OR (driver_id IS NULL AND status IN ('pending', 'ready_for_pickup'))
  );;
