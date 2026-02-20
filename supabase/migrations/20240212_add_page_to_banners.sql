-- Add 'page' column to banners table for page-specific banner targeting
ALTER TABLE public.banners ADD COLUMN IF NOT EXISTS page text DEFAULT 'home';

-- Create index for page filtering
CREATE INDEX IF NOT EXISTS idx_banners_page ON public.banners(page);

-- Update existing banners to default to 'home'
UPDATE public.banners SET page = 'home' WHERE page IS NULL;
