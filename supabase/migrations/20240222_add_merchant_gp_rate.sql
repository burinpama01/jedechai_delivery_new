-- Add per-merchant GP rate column to profiles table
-- This allows admin to set a custom GP rate per merchant (overrides system default)
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS gp_rate numeric;

COMMENT ON COLUMN public.profiles.gp_rate IS 'Per-merchant GP rate override (e.g., 0.10 = 10%). NULL = use system default.';
