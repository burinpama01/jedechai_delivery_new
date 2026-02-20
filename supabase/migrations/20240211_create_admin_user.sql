-- Create admin user
-- Run this in Supabase SQL Editor

-- 1. Create admin user in auth.users
INSERT INTO auth.users (
  id,
  email,
  email_confirmed_at,
  phone,
  phone_confirmed_at,
  created_at,
  updated_at,
  last_sign_in_at,
  raw_user_meta_data
) VALUES (
  '00000000-0000-0000-0000-000000000001', -- Fixed admin UUID
  'admin@jedechai.com',
  now(),
  null,
  null,
  now(),
  now(),
  now(),
  '{"role": "admin"}'
);

-- 2. Create corresponding profile
INSERT INTO public.profiles (
  id,
  full_name,
  role,
  approval_status,
  admin_permissions,
  admin_level,
  created_at,
  updated_at
) VALUES (
  '00000000-0000-0000-0000-000000000001', -- Same UUID as above
  'System Administrator',
  'admin',
  'approved',
  '["*"]', -- All permissions in JSONB format
  10, -- Highest admin level
  now(),
  now()
);

-- 3. Check if admin user was created
SELECT 
  u.email,
  p.role,
  p.full_name,
  p.approval_status,
  p.admin_level
FROM auth.users u
JOIN public.profiles p ON u.id = p.id
WHERE p.role = 'admin';
