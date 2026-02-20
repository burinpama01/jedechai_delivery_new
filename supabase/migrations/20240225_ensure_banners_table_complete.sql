-- Ensure banners table exists with ALL required columns
-- This is a consolidated migration for the banners feature

-- 1) Create table if not exists
CREATE TABLE IF NOT EXISTS public.banners (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  title text NOT NULL DEFAULT 'Banner',
  image_url text NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  sort_order integer DEFAULT 0 NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- 2) Add page column (might already exist)
ALTER TABLE public.banners ADD COLUMN IF NOT EXISTS page text DEFAULT 'home';

-- 3) Add coupon_code column (might already exist)
ALTER TABLE public.banners ADD COLUMN IF NOT EXISTS coupon_code text DEFAULT NULL;

-- 4) Indexes
CREATE INDEX IF NOT EXISTS idx_banners_sort ON public.banners(sort_order ASC, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_banners_active ON public.banners(is_active) WHERE is_active = true;
CREATE INDEX IF NOT EXISTS idx_banners_page ON public.banners(page);

-- 5) RLS
ALTER TABLE public.banners ENABLE ROW LEVEL SECURITY;

-- Allow anon/authenticated to read active banners
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'banners' AND policyname = 'Anyone can read active banners'
    ) THEN
        CREATE POLICY "Anyone can read active banners" ON public.banners
          FOR SELECT USING (is_active = true);
    END IF;
END $$;

-- Admin full CRUD
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'banners' AND policyname = 'Admin full access'
    ) THEN
        CREATE POLICY "Admin full access" ON public.banners
          FOR ALL USING (
            EXISTS (
              SELECT 1 FROM public.profiles 
              WHERE id = auth.uid() AND role = 'admin'
            )
          );
    END IF;
END $$;

-- Service role bypass (for admin-web using service_role key)
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'banners' AND policyname = 'Service role full access'
    ) THEN
        CREATE POLICY "Service role full access" ON public.banners
          FOR ALL USING (true) WITH CHECK (true);
    END IF;
END $$;

-- 6) Updated_at trigger
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$ language 'plpgsql';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_trigger 
        WHERE tgname = 'update_banners_updated_at'
    ) THEN
        CREATE TRIGGER update_banners_updated_at 
          BEFORE UPDATE ON public.banners 
          FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
    END IF;
END $$;
