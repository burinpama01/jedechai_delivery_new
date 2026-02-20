-- Debug RLS policies
-- Run this in Supabase SQL Editor

-- 1. Check current policies on storage.objects
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  roles,
  cmd,
  qual
FROM pg_policies 
WHERE tablename = 'objects'
ORDER BY policyname;

-- 2. Check if admin user is properly authenticated
SELECT 
  u.email,
  p.role,
  p.approval_status,
  p.admin_level
FROM auth.users u
JOIN public.profiles p ON u.id = p.id
WHERE p.role = 'admin';

-- 3. Test RLS with current user (run this while logged in as admin)
-- This should return rows if RLS is working
SELECT 
  bucket_id,
  name,
  owner
FROM storage.objects 
WHERE bucket_id = 'admin-uploads'
LIMIT 5;

-- 4. Drop and recreate policies if needed
DROP POLICY IF EXISTS "Admin full access to admin-uploads" ON storage.objects;
DROP POLICY IF EXISTS "Public read access to admin-uploads" ON storage.objects;

-- 5. Create new policies
CREATE POLICY "Admin full access to admin-uploads" ON storage.objects
  FOR ALL USING (
    bucket_id = 'admin-uploads' AND
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin' AND approval_status = 'approved'
    )
  );

CREATE POLICY "Public read access to admin-uploads" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'admin-uploads'
  );
