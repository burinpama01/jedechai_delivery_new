-- ============================================
-- Ensure merchant shop status columns + RLS
-- ============================================
-- บาง environment อาจยังไม่มี shop_status (อยู่คนละ migrations folder)
-- และทำให้ฝั่งลูกค้าไม่เห็นร้าน / ฝั่งร้านเปลี่ยนสถานะไม่ได้

-- 1) Column
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS shop_status boolean DEFAULT false;

-- 2) Index
CREATE INDEX IF NOT EXISTS idx_profiles_shop_status ON public.profiles(shop_status);

-- 3) Merchant can update own shop_status (only when role=merchant)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'profiles'
      AND policyname = 'Merchants can update their shop status'
  ) THEN
    CREATE POLICY "Merchants can update their shop status" ON public.profiles
      FOR UPDATE
      USING (auth.uid() = id AND role = 'merchant')
      WITH CHECK (auth.uid() = id AND role = 'merchant');
  END IF;
END $$;
