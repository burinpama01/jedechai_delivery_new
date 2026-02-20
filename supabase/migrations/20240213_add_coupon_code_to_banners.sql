-- Add coupon_code column to banners table for linking promo codes to banners
ALTER TABLE public.banners ADD COLUMN IF NOT EXISTS coupon_code text DEFAULT NULL;

-- When customer taps a banner with a coupon_code, the app will show/copy the promo code
