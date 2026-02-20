-- Simple RLS fix without disabling RLS
-- Run this in Supabase SQL Editor

-- 1. Check bucket exists
SELECT id, name, public FROM storage.buckets WHERE id = 'admin-uploads';

-- 2. Create bucket if not exists
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'admin-uploads',
  'admin-uploads',
  true,
  5242880,
  ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/gif', 'image/webp']
) ON CONFLICT (id) DO NOTHING;

-- 3. Drop all existing policies on storage.objects
DROP POLICY IF EXISTS "Admin full access to admin-uploads" ON storage.objects;
DROP POLICY IF EXISTS "Public read access to admin-uploads" ON storage.objects;

-- 4. Create very simple policy - any authenticated user can upload to admin-uploads
CREATE POLICY "Admin uploads" ON storage.objects
  FOR ALL USING (
    bucket_id = 'admin-uploads' AND 
    auth.role() = 'authenticated'
  );

-- 5. Create public read policy
CREATE POLICY "Public read" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'admin-uploads'
  );

-- 6. Verify policies
SELECT policyname, permissive, cmd, roles 
FROM pg_policies 
WHERE tablename = 'objects' AND schemaname = 'storage'
ORDER BY policyname;

-- 7. Test with current user
SELECT 
  'Test: Can read admin-uploads?' as test,
  COUNT(*) as row_count
FROM storage.objects 
WHERE bucket_id = 'admin-uploads';
