-- Create banners table for admin web app
CREATE TABLE IF NOT EXISTS public.banners (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  title text NOT NULL DEFAULT 'Banner',
  image_url text NOT NULL,
  is_active boolean DEFAULT true NOT NULL,
  sort_order integer DEFAULT 0 NOT NULL,
  created_at timestamp with time zone DEFAULT now() NOT NULL,
  updated_at timestamp with time zone DEFAULT now() NOT NULL
);

-- Create index for ordering
CREATE INDEX IF NOT EXISTS idx_banners_sort ON public.banners(sort_order ASC, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_banners_active ON public.banners(is_active) WHERE is_active = true;

-- RLS Policies
ALTER TABLE public.banners ENABLE ROW LEVEL SECURITY;

-- Admin users can do everything
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

-- Everyone can read active banners
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'banners' AND policyname = 'Read active banners'
    ) THEN
        CREATE POLICY "Read active banners" ON public.banners
          FOR SELECT USING (
            is_active = true
          );
    END IF;
END $$;

-- Trigger to update updated_at
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

-- Note: Admin can upload banners via admin web interface
-- No sample data inserted to avoid broken image URLs
