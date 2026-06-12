-- Storage bucket for customer laundry quote request attachments.
-- Paths are scoped by uploader uid: <auth.uid()>/<order-or-temp>/<filename>.

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'laundry-quote-attachments',
  'laundry-quote-attachments',
  false,
  10485760,
  ARRAY['image/jpeg', 'image/png', 'image/webp']::text[]
)
ON CONFLICT (id) DO UPDATE
SET public = EXCLUDED.public,
    file_size_limit = EXCLUDED.file_size_limit,
    allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS "Authenticated users can upload laundry quote attachments"
  ON storage.objects;
CREATE POLICY "Authenticated users can upload laundry quote attachments"
ON storage.objects
FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'laundry-quote-attachments'
  AND (storage.foldername(name))[1] = auth.uid()::text
);

DROP POLICY IF EXISTS "Authenticated users can read laundry quote attachments"
  ON storage.objects;
CREATE POLICY "Authenticated users can read laundry quote attachments"
ON storage.objects
FOR SELECT
TO authenticated
USING (bucket_id = 'laundry-quote-attachments');

DROP POLICY IF EXISTS "Authenticated users can delete own laundry quote attachments"
  ON storage.objects;
CREATE POLICY "Authenticated users can delete own laundry quote attachments"
ON storage.objects
FOR DELETE
TO authenticated
USING (
  bucket_id = 'laundry-quote-attachments'
  AND (storage.foldername(name))[1] = auth.uid()::text
);
