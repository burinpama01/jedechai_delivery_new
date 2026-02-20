-- Check existing admin user
-- Run this in Supabase SQL Editor

-- 1. Check if admin user exists and has correct role
SELECT 
  u.id,
  u.email,
  p.role,
  p.full_name,
  p.approval_status,
  p.admin_level,
  p.admin_permissions
FROM auth.users u
JOIN public.profiles p ON u.id = p.id
WHERE u.email = 'admin@jedechai.com'
   OR p.role = 'admin';

-- 2. If admin exists but role is wrong, update it
UPDATE public.profiles 
SET 
  role = 'admin',
  approval_status = 'approved',
  admin_permissions = '["*"]',
  admin_level = 10,
  updated_at = now()
WHERE id = '00000000-0000-0000-0000-000000000001';

-- 3. Verify the update
SELECT 
  u.email,
  p.role,
  p.full_name,
  p.approval_status,
  p.admin_level
FROM auth.users u
JOIN public.profiles p ON u.id = p.id
WHERE p.role = 'admin';
