-- Create storage buckets needed by the app
-- menu-images: for menu item photos uploaded by admin
-- admin-uploads: for logo, splash, banners uploaded by admin

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('menu-images', 'menu-images', true, 5242880, ARRAY['image/jpeg','image/png','image/webp','image/gif'])
ON CONFLICT (id) DO NOTHING;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('admin-uploads', 'admin-uploads', true, 10485760, ARRAY['image/jpeg','image/png','image/webp','image/gif','video/mp4'])
ON CONFLICT (id) DO NOTHING;

-- Allow public read access to menu-images
CREATE POLICY IF NOT EXISTS "Public read menu-images" ON storage.objects
  FOR SELECT USING (bucket_id = 'menu-images');

-- Allow authenticated users to upload to menu-images
CREATE POLICY IF NOT EXISTS "Auth upload menu-images" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'menu-images' AND auth.role() = 'authenticated');

-- Allow authenticated users to update menu-images
CREATE POLICY IF NOT EXISTS "Auth update menu-images" ON storage.objects
  FOR UPDATE USING (bucket_id = 'menu-images' AND auth.role() = 'authenticated');

-- Allow public read access to admin-uploads
CREATE POLICY IF NOT EXISTS "Public read admin-uploads" ON storage.objects
  FOR SELECT USING (bucket_id = 'admin-uploads');

-- Allow authenticated users to upload to admin-uploads
CREATE POLICY IF NOT EXISTS "Auth upload admin-uploads" ON storage.objects
  FOR INSERT WITH CHECK (bucket_id = 'admin-uploads' AND auth.role() = 'authenticated');

-- Allow authenticated users to update admin-uploads
CREATE POLICY IF NOT EXISTS "Auth update admin-uploads" ON storage.objects
  FOR UPDATE USING (bucket_id = 'admin-uploads' AND auth.role() = 'authenticated');
