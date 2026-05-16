-- ISSUE-036: Fix RLS UPDATE policy to allow drivers to accept ready_for_pickup bookings
-- Previously the policy only allowed updating bookings with status='pending'
-- Food orders change to 'ready_for_pickup' before drivers can accept them

DROP POLICY IF EXISTS "bookings_update_driver" ON public.bookings;
CREATE POLICY "bookings_update_driver" ON public.bookings
  FOR UPDATE USING (
    auth.uid() = driver_id
    OR (driver_id IS NULL AND status IN ('pending', 'ready_for_pickup'))
  );
