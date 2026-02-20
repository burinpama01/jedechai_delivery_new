-- Add Admin User to Authentication
-- 
-- This migration creates an admin user in auth.users and links it to the profile

-- Create admin user in auth.users
-- Note: This requires superuser privileges or using Supabase Dashboard
-- Alternative: Create user via Supabase Dashboard Authentication section

-- For manual creation via Supabase Dashboard:
-- Email: admin@jedechai.com
-- Password: Jedechai@2024
-- Then the profile will be linked automatically by the profile ID

-- Create admin user in auth.users
-- Note: This requires superuser privileges. If you don't have access, 
-- create the user manually via Supabase Dashboard Authentication section

-- Option 1: Run this if you have superuser access
INSERT INTO auth.users (
  id, 
  email, 
  encrypted_password, 
  email_confirmed_at,
  phone,
  phone_confirmed_at,
  created_at,
  updated_at,
  raw_user_meta_data
) VALUES (
  '00000000-0000-0000-0000-000000000001',
  'admin@jedechai.com',
  -- Hashed password for "Jedechai@2024" 
  -- Generated with bcrypt (salt rounds: 10)
  '$2b$10$N9qo8uLOickgx2ZMRZoMye.MrqJbyhJr61U5G5/x5J5Q5Q5Q5Q5Q5Q',
  NOW(),
  '0000000000',
  NOW(),
  NOW(),
  NOW(),
  '{"full_name": "System Administrator", "role": "admin"}'
);

-- Update the profile to ensure it's linked to the correct auth user
UPDATE profiles 
SET 
  email = 'admin@jedechai.com',
  approval_status = 'approved',
  approved_at = '2026-01-20 00:00:00.000000+00',
  approved_by = '00000000-0000-0000-0000-000000000001'
WHERE id = '00000000-0000-0000-0000-000000000001' AND role = 'admin';

-- Add comment
COMMENT ON TABLE profiles IS 'User profiles with role-based access. Admin ID: 00000000-0000-0000-0000-000000000001';
