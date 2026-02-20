-- Check system_config schema and fix
-- Run this in Supabase SQL Editor

-- 1. Check system_config table structure
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_schema = 'public' AND table_name = 'system_config'
ORDER BY ordinal_position;

-- 2. Check existing data
SELECT * FROM public.system_config LIMIT 5;

-- 3. Fix RLS policies (without system_config insert)
DROP POLICY IF EXISTS "Admin full access" ON public.banners;
DROP POLICY IF EXISTS "Read active banners" ON public.banners;

CREATE POLICY "Admin full access" ON public.banners
  FOR ALL USING (
    auth.role() = 'authenticated'
  );

CREATE POLICY "Read active banners" ON public.banners
  FOR SELECT USING (
    is_active = true
  );

-- 4. Fix storage RLS
DROP POLICY IF EXISTS "Admin uploads" ON storage.objects;
DROP POLICY IF EXISTS "Public read" ON storage.objects;

CREATE POLICY "Admin uploads" ON storage.objects
  FOR ALL USING (
    bucket_id = 'admin-uploads' AND 
    auth.role() = 'authenticated'
  );

CREATE POLICY "Public read" ON storage.objects
  FOR SELECT USING (
    bucket_id = 'admin-uploads'
  );

-- 5. Verify policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  cmd
FROM pg_policies 
WHERE tablename IN ('banners', 'objects')
ORDER BY tablename, policyname;
