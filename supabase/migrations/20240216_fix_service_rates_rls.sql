-- Fix RLS policies for service_rates table
-- ปัญหา: admin-web ไม่สามารถบันทึกค่าบริการได้ (403 Forbidden / 42501 RLS violation)
-- วิธีแก้: เพิ่ม RLS policies ให้ service_rates table

-- 1. Enable RLS (ถ้ายังไม่ได้เปิด)
ALTER TABLE public.service_rates ENABLE ROW LEVEL SECURITY;

-- 2. Drop existing policies (ถ้ามี)
DROP POLICY IF EXISTS "Anyone can read service_rates" ON public.service_rates;
DROP POLICY IF EXISTS "Authenticated users can read service_rates" ON public.service_rates;
DROP POLICY IF EXISTS "Admin can manage service_rates" ON public.service_rates;
DROP POLICY IF EXISTS "Service role full access service_rates" ON public.service_rates;

-- 3. SELECT: ทุกคน (รวม anon) อ่านได้ — ใช้สำหรับคำนวณราคาในแอป
CREATE POLICY "Anyone can read service_rates" ON public.service_rates
  FOR SELECT USING (true);

-- 4. INSERT/UPDATE/DELETE: เฉพาะ admin ที่ authenticated
CREATE POLICY "Admin can manage service_rates" ON public.service_rates
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );

-- 5. ทำเหมือนกันกับ system_config (ถ้ายังไม่มี policy)
ALTER TABLE public.system_config ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can read system_config" ON public.system_config;
DROP POLICY IF EXISTS "Admin can manage system_config" ON public.system_config;

CREATE POLICY "Anyone can read system_config" ON public.system_config
  FOR SELECT USING (true);

CREATE POLICY "Admin can manage system_config" ON public.system_config
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.profiles
      WHERE id = auth.uid() AND role = 'admin'
    )
  );
