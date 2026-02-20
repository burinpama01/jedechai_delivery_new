-- ============================================
-- Fix RLS policies for profiles and driver_locations
-- ============================================
-- ปัญหา: คนขับ update is_online ไม่ได้เพราะไม่มี UPDATE policy
-- ทำให้แอดมินแมพเห็นว่าคนขับออฟไลน์ตลอด
-- ============================================

-- 1) Allow users to UPDATE their own profile
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'profiles' 
    AND policyname = 'profiles_update_own'
  ) THEN
    CREATE POLICY "profiles_update_own" ON public.profiles
      FOR UPDATE USING (auth.uid() = id)
      WITH CHECK (auth.uid() = id);
  END IF;
END $$;

-- 2) Allow users to SELECT their own profile
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'profiles' 
    AND policyname = 'profiles_select_own'
  ) THEN
    CREATE POLICY "profiles_select_own" ON public.profiles
      FOR SELECT USING (auth.uid() = id);
  END IF;
END $$;

-- 3) Allow any authenticated user to read driver/merchant profiles (for customer app)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'profiles' 
    AND policyname = 'profiles_select_public'
  ) THEN
    CREATE POLICY "profiles_select_public" ON public.profiles
      FOR SELECT USING (true);
  END IF;
END $$;

-- ============================================
-- driver_locations RLS policies
-- ============================================

-- Enable RLS if not already
ALTER TABLE IF EXISTS public.driver_locations ENABLE ROW LEVEL SECURITY;

-- 4) Drivers can INSERT their own location
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'driver_locations' 
    AND policyname = 'driver_locations_insert_own'
  ) THEN
    CREATE POLICY "driver_locations_insert_own" ON public.driver_locations
      FOR INSERT WITH CHECK (auth.uid() = driver_id);
  END IF;
END $$;

-- 5) Drivers can UPDATE their own location
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'driver_locations' 
    AND policyname = 'driver_locations_update_own'
  ) THEN
    CREATE POLICY "driver_locations_update_own" ON public.driver_locations
      FOR UPDATE USING (auth.uid() = driver_id)
      WITH CHECK (auth.uid() = driver_id);
  END IF;
END $$;

-- 6) Anyone can read driver_locations (for admin map + customer tracking)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'driver_locations' 
    AND policyname = 'driver_locations_select_all'
  ) THEN
    CREATE POLICY "driver_locations_select_all" ON public.driver_locations
      FOR SELECT USING (true);
  END IF;
END $$;
