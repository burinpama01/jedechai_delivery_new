-- Fix all RLS policies
-- Run this in Supabase SQL Editor

-- 1. Fix banners table RLS
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

-- 2. Fix storage RLS (already done but verify)
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

-- 3. Check system_config table
SELECT * FROM public.system_config LIMIT 5;

-- 4. Create system_config record if not exists
INSERT INTO public.system_config (id, platform_fee_rate, merchant_gp_rate, minimum_wallet, standard_commission)
VALUES (1, 0.15, 0.10, 100, 20)
ON CONFLICT (id) DO NOTHING;

-- 5. Verify all policies
SELECT 
  schemaname,
  tablename,
  policyname,
  permissive,
  cmd,
  roles
FROM pg_policies 
WHERE tablename IN ('banners', 'objects')
ORDER BY tablename, policyname;
