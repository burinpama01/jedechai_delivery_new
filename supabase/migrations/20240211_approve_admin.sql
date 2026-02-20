-- Approve admin user
-- Run this in Supabase SQL Editor

UPDATE public.profiles 
SET 
  approval_status = 'approved',
  admin_permissions = '["*"]',
  admin_level = 10,
  updated_at = now()
WHERE role = 'admin';

-- Verify the update
SELECT 
  u.email,
  p.role,
  p.full_name,
  p.approval_status,
  p.admin_level,
  p.admin_permissions
FROM auth.users u
JOIN public.profiles p ON u.id = p.id
WHERE p.role = 'admin';
