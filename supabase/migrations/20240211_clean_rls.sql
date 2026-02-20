-- Clean up RLS policies and test
-- Run this in Supabase SQL Editor

-- 1. Remove all storage policies except our new ones
DROP POLICY IF EXISTS "Public read access" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can upload to own folder" ON storage.objects;

-- 2. Keep only these two policies for storage
-- "Admin uploads" - FOR ALL
-- "Public read" - FOR SELECT

-- 3. Verify final policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  cmd
FROM pg_policies 
WHERE tablename IN ('banners', 'objects')
ORDER BY tablename, policyname;

-- 4. Test upload permission (should return 1 if policy works)
SELECT 
  'Test: Can upload to admin-uploads?' as test,
  CASE WHEN EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'objects' 
    AND policyname = 'Admin uploads'
    AND cmd = 'ALL'
  ) THEN 1 ELSE 0 END as can_upload;

-- 5. Test banners permission (should return 1 if policy works)
SELECT 
  'Test: Can insert banners?' as test,
  CASE WHEN EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'banners' 
    AND policyname = 'Admin full access'
    AND cmd = 'ALL'
  ) THEN 1 ELSE 0 END as can_insert;
