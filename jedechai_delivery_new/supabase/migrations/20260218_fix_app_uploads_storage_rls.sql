-- Fix Storage RLS for app-uploads to support profile and menu image paths.
-- Expected object paths from app code:
--   profiles/{auth.uid()}/{filename}
--   menu_items/{auth.uid()}/{filename}

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'app-uploads',
  'app-uploads',
  true,
  5242880,
  ARRAY['image/jpeg', 'image/png', 'image/gif', 'image/webp']
)
ON CONFLICT (id) DO NOTHING;

ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can upload to own folder" ON storage.objects;
DROP POLICY IF EXISTS "Users can update own files" ON storage.objects;
DROP POLICY IF EXISTS "Users can delete own files" ON storage.objects;
DROP POLICY IF EXISTS "Public read access" ON storage.objects;

CREATE POLICY "Users can upload to own folder"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'app-uploads'
  AND (
    (storage.foldername(name))[1] = 'profiles'
    AND (storage.foldername(name))[2] = auth.uid()::text
    OR
    (storage.foldername(name))[1] = 'menu_items'
    AND (storage.foldername(name))[2] = auth.uid()::text
  )
);

CREATE POLICY "Users can update own files"
ON storage.objects
FOR UPDATE
TO authenticated
USING (
  bucket_id = 'app-uploads'
  AND (
    (storage.foldername(name))[1] = 'profiles'
    AND (storage.foldername(name))[2] = auth.uid()::text
    OR
    (storage.foldername(name))[1] = 'menu_items'
    AND (storage.foldername(name))[2] = auth.uid()::text
  )
)
WITH CHECK (
  bucket_id = 'app-uploads'
  AND (
    (storage.foldername(name))[1] = 'profiles'
    AND (storage.foldername(name))[2] = auth.uid()::text
    OR
    (storage.foldername(name))[1] = 'menu_items'
    AND (storage.foldername(name))[2] = auth.uid()::text
  )
);

CREATE POLICY "Users can delete own files"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'app-uploads'
  AND (
    (storage.foldername(name))[1] = 'profiles'
    AND (storage.foldername(name))[2] = auth.uid()::text
    OR
    (storage.foldername(name))[1] = 'menu_items'
    AND (storage.foldername(name))[2] = auth.uid()::text
  )
);

CREATE POLICY "Public read access"
ON storage.objects
FOR SELECT
TO public
USING (bucket_id = 'app-uploads');
