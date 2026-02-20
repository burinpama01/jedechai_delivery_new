-- Check if bucket exists and create if needed
-- Run this in Supabase SQL Editor

-- 1. Check if admin-uploads bucket exists
SELECT * FROM storage.buckets WHERE id = 'admin-uploads';

-- 2. If bucket doesn't exist, create it
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'admin-uploads',
  'admin-uploads',
  true,
  5242880, -- 5MB
  ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/gif', 'image/webp']
) ON CONFLICT (id) DO NOTHING;

-- 3. Verify bucket exists
SELECT id, name, public, file_size_limit FROM storage.buckets WHERE id = 'admin-uploads';

-- 4. Test with a simpler policy (temporarily disable RLS for testing)
ALTER TABLE storage.objects DISABLE ROW LEVEL SECURITY;

-- 5. Test if we can see the bucket now
SELECT 
  'Test: Can read admin-uploads without RLS?' as test,
  COUNT(*) as row_count
FROM storage.objects 
WHERE bucket_id = 'admin-uploads';

-- 6. Re-enable RLS with a simpler policy
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- 7. Create a simple admin policy
DROP POLICY IF EXISTS "Admin full access to admin-uploads" ON storage.objects;
CREATE POLICY "Admin full access to admin-uploads" ON storage.objects
  FOR ALL USING (
    bucket_id = 'admin-uploads' AND 
    auth.uid() IS NOT NULL
  );

-- 8. Test again
SELECT 
  'Test: Can admin read with simple policy?' as test,
  COUNT(*) as row_count
FROM storage.objects 
WHERE bucket_id = 'admin-uploads';
