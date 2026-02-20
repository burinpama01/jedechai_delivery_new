-- Add missing columns to system_config for admin panel compatibility
-- These columns are used by admin-web/app.js saveSettings and loadAppAssets

-- Settings columns (code uses these names)
ALTER TABLE public.system_config ADD COLUMN IF NOT EXISTS commission_rate numeric DEFAULT 15;
ALTER TABLE public.system_config ADD COLUMN IF NOT EXISTS driver_min_wallet numeric DEFAULT 0;

-- Logo & Splash columns
ALTER TABLE public.system_config ADD COLUMN IF NOT EXISTS logo_url text;
ALTER TABLE public.system_config ADD COLUMN IF NOT EXISTS splash_url text;

-- Promo tag (admin-configurable promotional text)
ALTER TABLE public.system_config ADD COLUMN IF NOT EXISTS promo_text text DEFAULT 'ส่งฟรี! สั่งครบ ฿200';
ALTER TABLE public.system_config ADD COLUMN IF NOT EXISTS promo_enabled boolean DEFAULT false;
