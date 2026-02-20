-- ============================================================
-- Consolidated migration (squashed)
-- ============================================================
-- Purpose:
--   Reduce high-fragmentation migrations by consolidating common
--   schema additions + RLS fixes into one idempotent migration.
--
-- Notes:
--   - Safe to run on existing DB (uses IF NOT EXISTS / DROP+CREATE policies)
--   - Intended as the canonical "post-base" migration for this repo
-- ============================================================

-- ------------------------------------------------------------
-- 1) Core feature columns
-- ------------------------------------------------------------

ALTER TABLE IF EXISTS public.system_config
  ADD COLUMN IF NOT EXISTS commission_rate numeric DEFAULT 15,
  ADD COLUMN IF NOT EXISTS driver_min_wallet numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS logo_url text,
  ADD COLUMN IF NOT EXISTS splash_url text,
  ADD COLUMN IF NOT EXISTS promo_text text DEFAULT 'ส่งฟรี! สั่งครบ ฿200',
  ADD COLUMN IF NOT EXISTS promo_enabled boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS promptpay_number text,
  ADD COLUMN IF NOT EXISTS max_delivery_radius numeric(5,1) DEFAULT 20.0,
  ADD COLUMN IF NOT EXISTS admin_notification_email text,
  ADD COLUMN IF NOT EXISTS admin_notification_email_cc text;

UPDATE public.system_config
SET max_delivery_radius = 20.0
WHERE max_delivery_radius IS NULL;

ALTER TABLE IF EXISTS public.profiles
  ADD COLUMN IF NOT EXISTS custom_delivery_fee numeric,
  ADD COLUMN IF NOT EXISTS custom_service_fee numeric,
  ADD COLUMN IF NOT EXISTS custom_base_fare numeric,
  ADD COLUMN IF NOT EXISTS custom_per_km numeric,
  ADD COLUMN IF NOT EXISTS custom_base_distance numeric,
  ADD COLUMN IF NOT EXISTS gp_rate numeric,
  ADD COLUMN IF NOT EXISTS approval_status text DEFAULT 'pending',
  ADD COLUMN IF NOT EXISTS rejection_reason text,
  ADD COLUMN IF NOT EXISTS approved_at timestamptz,
  ADD COLUMN IF NOT EXISTS shop_open_time text DEFAULT '08:00',
  ADD COLUMN IF NOT EXISTS shop_close_time text DEFAULT '22:00',
  ADD COLUMN IF NOT EXISTS shop_status boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS deletion_status text DEFAULT NULL;

ALTER TABLE IF EXISTS public.bookings
  ADD COLUMN IF NOT EXISTS vehicle_type text,
  ADD COLUMN IF NOT EXISTS actual_distance_km double precision,
  ADD COLUMN IF NOT EXISTS trip_duration_minutes integer;

ALTER TABLE IF EXISTS public.menu_items
  ADD COLUMN IF NOT EXISTS sales_count integer DEFAULT 0;

CREATE INDEX IF NOT EXISTS idx_profiles_shop_status ON public.profiles(shop_status);
CREATE INDEX IF NOT EXISTS idx_bookings_vehicle_type ON public.bookings(vehicle_type);
CREATE INDEX IF NOT EXISTS idx_menu_items_sales_count ON public.menu_items(sales_count DESC);

COMMENT ON COLUMN public.profiles.shop_open_time IS 'เวลาเปิดร้าน (HH:mm format)';
COMMENT ON COLUMN public.profiles.shop_close_time IS 'เวลาปิดร้าน (HH:mm format)';
COMMENT ON COLUMN public.profiles.gp_rate IS 'Per-merchant GP rate override (e.g., 0.10 = 10%). NULL = use system default.';
COMMENT ON COLUMN public.profiles.custom_base_distance IS 'Per-merchant base distance override (km). NULL = use system default from service_rates.';

-- ------------------------------------------------------------
-- 2) Banners (consolidated)
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.banners (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  title text NOT NULL DEFAULT 'Banner',
  image_url text NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  sort_order integer DEFAULT 0 NOT NULL,
  page text DEFAULT 'home',
  coupon_code text DEFAULT NULL,
  created_at timestamptz DEFAULT now() NOT NULL,
  updated_at timestamptz DEFAULT now() NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_banners_sort ON public.banners(sort_order ASC, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_banners_active ON public.banners(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_banners_page ON public.banners(page);

CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'update_banners_updated_at'
  ) THEN
    CREATE TRIGGER update_banners_updated_at
      BEFORE UPDATE ON public.banners
      FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
  END IF;
END $$;

-- ------------------------------------------------------------
-- 3) Top-up / account deletion / reviews tables
-- ------------------------------------------------------------

CREATE TABLE IF NOT EXISTS public.topup_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
  amount numeric NOT NULL DEFAULT 0,
  status text NOT NULL DEFAULT 'pending',
  admin_note text,
  processed_at timestamptz,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_topup_requests_user_id ON public.topup_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_topup_requests_status ON public.topup_requests(status);

CREATE TABLE IF NOT EXISTS public.account_deletion_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reason text,
  status text NOT NULL DEFAULT 'pending',
  admin_note text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_account_deletion_requests_user_id ON public.account_deletion_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_account_deletion_requests_status ON public.account_deletion_requests(status);

CREATE TABLE IF NOT EXISTS public.reviews (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  booking_id uuid NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  driver_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  merchant_id uuid REFERENCES auth.users(id) ON DELETE SET NULL,
  rating double precision NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment text,
  created_at timestamptz DEFAULT now(),
  updated_at timestamptz DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_reviews_booking_id ON public.reviews(booking_id);
CREATE INDEX IF NOT EXISTS idx_reviews_customer_id ON public.reviews(customer_id);
CREATE INDEX IF NOT EXISTS idx_reviews_driver_id ON public.reviews(driver_id);
CREATE INDEX IF NOT EXISTS idx_reviews_merchant_id ON public.reviews(merchant_id);

CREATE UNIQUE INDEX IF NOT EXISTS uniq_reviews_booking_driver
  ON public.reviews(booking_id, customer_id, driver_id)
  WHERE driver_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uniq_reviews_booking_merchant
  ON public.reviews(booking_id, customer_id, merchant_id)
  WHERE merchant_id IS NOT NULL;

DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.topup_requests;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;

  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.reviews;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;

-- ------------------------------------------------------------
-- 4) RLS: service_rates / system_config
-- ------------------------------------------------------------

ALTER TABLE IF EXISTS public.service_rates ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can read service_rates" ON public.service_rates;
DROP POLICY IF EXISTS "Admin can manage service_rates" ON public.service_rates;
CREATE POLICY "Anyone can read service_rates" ON public.service_rates
  FOR SELECT USING (true);
CREATE POLICY "Admin can manage service_rates" ON public.service_rates
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

ALTER TABLE IF EXISTS public.system_config ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can read system_config" ON public.system_config;
DROP POLICY IF EXISTS "Admin can manage system_config" ON public.system_config;
CREATE POLICY "Anyone can read system_config" ON public.system_config
  FOR SELECT USING (true);
CREATE POLICY "Admin can manage system_config" ON public.system_config
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ------------------------------------------------------------
-- 5) RLS: profiles / driver_locations / driver_activity_logs
-- ------------------------------------------------------------

ALTER TABLE IF EXISTS public.profiles ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'profiles_insert_own') THEN
    CREATE POLICY "profiles_insert_own" ON public.profiles FOR INSERT WITH CHECK (auth.uid() = id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'profiles_select_own') THEN
    CREATE POLICY "profiles_select_own" ON public.profiles FOR SELECT USING (auth.uid() = id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'profiles_update_own') THEN
    CREATE POLICY "profiles_update_own" ON public.profiles FOR UPDATE USING (auth.uid() = id) WITH CHECK (auth.uid() = id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'profiles_select_public') THEN
    CREATE POLICY "profiles_select_public" ON public.profiles FOR SELECT USING (true);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'profiles' AND policyname = 'Merchants can update their shop status') THEN
    CREATE POLICY "Merchants can update their shop status" ON public.profiles
      FOR UPDATE USING (auth.uid() = id AND role = 'merchant')
      WITH CHECK (auth.uid() = id AND role = 'merchant');
  END IF;
END $$;

ALTER TABLE IF EXISTS public.driver_locations ENABLE ROW LEVEL SECURITY;
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'driver_locations' AND policyname = 'driver_locations_insert_own') THEN
    CREATE POLICY "driver_locations_insert_own" ON public.driver_locations FOR INSERT WITH CHECK (auth.uid() = driver_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'driver_locations' AND policyname = 'driver_locations_update_own') THEN
    CREATE POLICY "driver_locations_update_own" ON public.driver_locations FOR UPDATE USING (auth.uid() = driver_id) WITH CHECK (auth.uid() = driver_id);
  END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE tablename = 'driver_locations' AND policyname = 'driver_locations_select_all') THEN
    CREATE POLICY "driver_locations_select_all" ON public.driver_locations FOR SELECT USING (true);
  END IF;
END $$;

DO $$
DECLARE
  has_table boolean;
  has_driver_id boolean;
  has_user_id boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'driver_activity_logs'
  ) INTO has_table;

  IF NOT has_table THEN
    RETURN;
  END IF;

  EXECUTE 'ALTER TABLE public.driver_activity_logs ENABLE ROW LEVEL SECURITY';

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'driver_activity_logs' AND column_name = 'driver_id'
  ) INTO has_driver_id;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'driver_activity_logs' AND column_name = 'user_id'
  ) INTO has_user_id;

  IF has_driver_id THEN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='driver_activity_logs' AND policyname='driver_activity_logs_insert_own') THEN
      EXECUTE 'CREATE POLICY "driver_activity_logs_insert_own" ON public.driver_activity_logs FOR INSERT WITH CHECK (auth.uid() = driver_id)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='driver_activity_logs' AND policyname='driver_activity_logs_select_own') THEN
      EXECUTE 'CREATE POLICY "driver_activity_logs_select_own" ON public.driver_activity_logs FOR SELECT USING (auth.uid() = driver_id)';
    END IF;
  ELSIF has_user_id THEN
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='driver_activity_logs' AND policyname='driver_activity_logs_insert_own') THEN
      EXECUTE 'CREATE POLICY "driver_activity_logs_insert_own" ON public.driver_activity_logs FOR INSERT WITH CHECK (auth.uid() = user_id)';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='driver_activity_logs' AND policyname='driver_activity_logs_select_own') THEN
      EXECUTE 'CREATE POLICY "driver_activity_logs_select_own" ON public.driver_activity_logs FOR SELECT USING (auth.uid() = user_id)';
    END IF;
  ELSE
    IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='driver_activity_logs' AND policyname='driver_activity_logs_insert_auth') THEN
      EXECUTE 'CREATE POLICY "driver_activity_logs_insert_auth" ON public.driver_activity_logs FOR INSERT WITH CHECK (auth.role() = ''authenticated'')';
    END IF;
  END IF;

  IF NOT EXISTS (SELECT 1 FROM pg_policies WHERE schemaname='public' AND tablename='driver_activity_logs' AND policyname='driver_activity_logs_admin_read') THEN
    EXECUTE 'CREATE POLICY "driver_activity_logs_admin_read" ON public.driver_activity_logs FOR SELECT USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = ''admin''))';
  END IF;
END $$;

-- ------------------------------------------------------------
-- 6) RLS: banners / topup / account deletion / reviews
-- ------------------------------------------------------------

ALTER TABLE IF EXISTS public.banners ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Anyone can read active banners" ON public.banners;
DROP POLICY IF EXISTS "Admin full access" ON public.banners;
DROP POLICY IF EXISTS "Service role full access" ON public.banners;
CREATE POLICY "Anyone can read active banners" ON public.banners FOR SELECT USING (is_active = true);
CREATE POLICY "Admin full access" ON public.banners
  FOR ALL USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));
CREATE POLICY "Service role full access" ON public.banners
  FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE IF EXISTS public.topup_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view their own topup requests" ON public.topup_requests;
DROP POLICY IF EXISTS "Users can insert their own topup requests" ON public.topup_requests;
DROP POLICY IF EXISTS "Service role can manage all topup requests" ON public.topup_requests;
CREATE POLICY "Users can view their own topup requests"
  ON public.topup_requests FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can insert their own topup requests"
  ON public.topup_requests FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Service role can manage all topup requests"
  ON public.topup_requests FOR ALL USING (true) WITH CHECK (true);

ALTER TABLE IF EXISTS public.account_deletion_requests ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can view own deletion requests" ON public.account_deletion_requests;
DROP POLICY IF EXISTS "Users can create own deletion requests" ON public.account_deletion_requests;
DROP POLICY IF EXISTS "Admin can manage all deletion requests" ON public.account_deletion_requests;
CREATE POLICY "Users can view own deletion requests"
  ON public.account_deletion_requests FOR SELECT USING (auth.uid() = user_id);
CREATE POLICY "Users can create own deletion requests"
  ON public.account_deletion_requests FOR INSERT WITH CHECK (auth.uid() = user_id);
CREATE POLICY "Admin can manage all deletion requests"
  ON public.account_deletion_requests FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

ALTER TABLE IF EXISTS public.reviews ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "reviews_select_all" ON public.reviews;
DROP POLICY IF EXISTS "reviews_insert_customer" ON public.reviews;
DROP POLICY IF EXISTS "reviews_update_customer" ON public.reviews;
CREATE POLICY "reviews_select_all" ON public.reviews FOR SELECT USING (true);
CREATE POLICY "reviews_insert_customer" ON public.reviews
  FOR INSERT WITH CHECK (auth.uid() = customer_id);
CREATE POLICY "reviews_update_customer" ON public.reviews
  FOR UPDATE USING (auth.uid() = customer_id)
  WITH CHECK (auth.uid() = customer_id);
