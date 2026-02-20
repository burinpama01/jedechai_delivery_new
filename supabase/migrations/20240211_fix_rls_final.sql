-- Fix RLS policies - Final version
-- Run this in Supabase SQL Editor

-- 1. Drop existing policies
DROP POLICY IF EXISTS "Admin full access to admin-uploads" ON storage.objects;
DROP POLICY IF EXISTS "Public read access to admin-uploads" ON storage.objects;

-- 2. Create new admin policy with proper checks
CREATE POLICY "Admin full access to admin-uploads" ON storage.objects
  FOR ALL USING (
    bucket_id = 'admin-uploads' AND
    EXISTS (
      SELECT 1 FROM public.profiles 
      WHERE id = auth.uid() AND role = 'admin' AND approval_status = 'approved'
    )
  );

-- 3. Create public read policy
CREATE POLICY "Public read access to admin-uploads" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'admin-uploads'
  );

-- 4. Verify policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  cmd
FROM pg_policies 
WHERE tablename = 'objects'
ORDER BY policyname;

-- 5. Test policy (should return rows if admin is logged in)
SELECT 
  'Test: Can admin read admin-uploads?' as test,
  COUNT(*) as row_count
FROM storage.objects 
WHERE bucket_id = 'admin-uploads';
