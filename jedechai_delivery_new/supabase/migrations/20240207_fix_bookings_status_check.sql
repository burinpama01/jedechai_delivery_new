-- Fix bookings_status_check constraint
-- The original constraint only allows 8 statuses but the app uses 13
-- This migration updates the constraint to match all statuses used by the app

-- Drop the old constraint
ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_status_check;

-- Add the updated constraint with all statuses used by the app
ALTER TABLE public.bookings ADD CONSTRAINT bookings_status_check 
  CHECK (status IN (
    'pending',
    'pending_merchant',
    'preparing',
    'matched',
    'ready_for_pickup',
    'accepted',
    'driver_accepted',
    'arrived',
    'arrived_at_merchant',
    'picking_up_order',
    'in_transit',
    'completed',
    'cancelled',
    -- Legacy statuses (kept for backward compatibility)
    'searching',
    'confirmed',
    'driver_assigned',
    'in_progress'
  ));
