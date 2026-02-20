-- Create admin-uploads storage bucket
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'admin-uploads',
  'admin-uploads',
  true,
  5242880, -- 5MB
  ARRAY['image/png', 'image/jpeg', 'image/jpg', 'image/gif', 'image/webp']
) ON CONFLICT (id) DO NOTHING;

-- RLS Policies for storage
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' AND policyname = 'Admin full access to admin-uploads'
    ) THEN
        CREATE POLICY "Admin full access to admin-uploads" ON storage.objects
          FOR ALL USING (
            bucket_id = 'admin-uploads' AND
            EXISTS (
              SELECT 1 FROM public.profiles 
              WHERE id = auth.uid() AND role = 'admin'
            )
          );
    END IF;
END $$;

-- Public read access for all files in admin-uploads
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'objects' AND policyname = 'Public read access to admin-uploads'
    ) THEN
        CREATE POLICY "Public read access to admin-uploads" ON storage.objects
          FOR SELECT USING (
            bucket_id = 'admin-uploads'
          );
    END IF;
END $$;
