-- Check if current user has admin role
-- Run this in Supabase SQL Editor to debug

-- 1. Check profiles table for admin users
SELECT id, email, role, full_name, created_at 
FROM public.profiles 
WHERE role = 'admin';

-- 2. Check all users and their roles
SELECT 
  u.id as user_id,
  u.email,
  p.role,
  p.full_name,
  u.created_at as user_created,
  p.created_at as profile_created
FROM auth.users u
LEFT JOIN public.profiles p ON u.id = p.id
ORDER BY u.created_at DESC;

-- 3. Check if RLS is enabled
SELECT tablename, rowsecurity 
FROM pg_tables 
WHERE schemaname = 'public' AND tablename IN ('banners', 'objects');

-- 4. Check existing policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies 
WHERE tablename IN ('banners', 'objects');
