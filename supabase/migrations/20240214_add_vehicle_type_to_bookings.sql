-- Add vehicle_type column to bookings for ride job dispatching
-- This allows filtering ride requests by vehicle type (motorcycle vs car)
ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS vehicle_type text;

-- Create index for vehicle_type filtering
CREATE INDEX IF NOT EXISTS idx_bookings_vehicle_type ON public.bookings(vehicle_type);
