-- Add trip tracking columns to bookings table
-- These store actual trip data for the driver job detail screen
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS actual_distance_km DOUBLE PRECISION;
ALTER TABLE bookings ADD COLUMN IF NOT EXISTS trip_duration_minutes INTEGER;
