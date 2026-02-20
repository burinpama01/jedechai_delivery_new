-- Fix booking_items INSERT RLS policy
-- The original policy blocks ALL direct inserts (WITH CHECK (false))
-- This prevents the app from creating food order items
-- Replace with a policy that allows authenticated users to insert items for their own bookings

DROP POLICY IF EXISTS "Restrict direct insert to booking_items" ON booking_items;

CREATE POLICY "Authenticated users can insert booking items for own bookings" ON booking_items
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM bookings 
            WHERE bookings.id = booking_items.booking_id 
            AND bookings.customer_id = auth.uid()
        )
    );
