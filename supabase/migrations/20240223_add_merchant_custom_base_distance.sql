-- Add per-merchant custom base distance column to profiles table
-- This allows admin to set a custom base distance per merchant (overrides system default)
-- Base distance = ระยะเริ่มต้นที่รวมในค่าส่งเริ่มต้น (กม.)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS custom_base_distance numeric;

COMMENT ON COLUMN public.profiles.custom_base_distance IS 'Per-merchant base distance override (km). NULL = use system default from service_rates.';
