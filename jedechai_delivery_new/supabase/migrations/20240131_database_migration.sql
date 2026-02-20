-- Database Migration Script for New Status Values
-- Run this script in your Supabase SQL Editor to add missing status values

-- ==========================================================
-- STEP 1: INVESTIGATION - Check Current Database Structure
-- ==========================================================

-- Check current status values in the database
SELECT DISTINCT status 
FROM bookings 
WHERE service_type = 'food'
ORDER BY status;

-- Check if status column has constraints
SELECT 
    column_name,
    data_type,
    is_nullable,
    column_default
FROM information_schema.columns 
WHERE table_name = 'bookings' 
    AND column_name = 'status';

-- Check for check constraints on status
SELECT 
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'bookings'::regclass 
    AND contype = 'c'
    AND conname LIKE '%status%';

-- Check if status uses enum type
SELECT 
    t.typname as enum_name,
    e.enumlabel as enum_value,
    e.enumsortorder
FROM pg_type t 
JOIN pg_enum e ON t.oid = e.enumtypid  
WHERE t.typtype = 'e'
    AND (t.typname LIKE '%status%' OR t.typname LIKE '%booking%')
ORDER BY t.typname, e.enumsortorder;

-- ==========================================================
-- STEP 2: MIGRATION - Add New Status Values
-- ==========================================================

-- OPTION A: If status is an ENUM type
-- Uncomment and modify the enum name if needed

-- Find the actual enum name first (run the query above to get the name)
-- Then add new values:
-- ALTER TYPE booking_status_enum ADD VALUE 'traveling_to_merchant';
-- ALTER TYPE booking_status_enum ADD VALUE 'arrived_at_merchant'; 
-- ALTER TYPE booking_status_enum ADD VALUE 'picking_up_order';

-- OPTION B: If status has a CHECK constraint
-- Drop existing constraint and recreate with new values

-- Drop existing status constraint (if exists)
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_status_check;

-- Drop any other status-related constraints
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_status_check_constraint;
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS check_status;
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS status_check;

-- Create new comprehensive constraint
ALTER TABLE bookings ADD CONSTRAINT bookings_status_check 
CHECK (status IN (
    -- Original statuses
    'pending', 
    'accepted', 
    'confirmed', 
    'driver_accepted', 
    'matched', 
    'preparing', 
    'ready_for_pickup', 
    'in_transit', 
    'completed', 
    'cancelled',
    -- New statuses for detailed driver flow
    'traveling_to_merchant',
    'arrived_at_merchant', 
    'picking_up_order'
));

-- ==========================================================
-- STEP 3: VERIFICATION - Confirm Changes
-- ==========================================================

-- Verify all status values are now accepted
SELECT DISTINCT status 
FROM bookings 
ORDER BY status;

-- Test new status with a temporary record (commented out - uncomment to test)
-- INSERT INTO bookings (id, status, service_type, created_at, updated_at) 
-- VALUES ('test-traveling', 'traveling_to_merchant', 'food', NOW(), NOW());
-- 
-- INSERT INTO bookings (id, status, service_type, created_at, updated_at) 
-- VALUES ('test-arrived', 'arrived_at_merchant', 'food', NOW(), NOW());
-- 
-- INSERT INTO bookings (id, status, service_type, created_at, updated_at) 
-- VALUES ('test-picking', 'picking_up_order', 'food', NOW(), NOW());
-- 
-- -- Clean up test records
-- DELETE FROM bookings WHERE id LIKE 'test-%';

-- Check final constraint
SELECT 
    conname as constraint_name,
    contype as constraint_type,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'bookings'::regclass 
    AND conname LIKE '%status%'
ORDER BY conname;

-- ==========================================================
-- STEP 4: ROLLBACK (if needed)
-- ==========================================================

-- If you need to rollback, run these commands:
-- ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_status_check;
-- -- Then recreate the old constraint with only original values
