-- ============================================================
-- Add landing page dynamic config column to system_config
-- ============================================================

ALTER TABLE IF EXISTS public.system_config
  ADD COLUMN IF NOT EXISTS landing_config jsonb DEFAULT '{}'::jsonb;

UPDATE public.system_config
SET landing_config = '{}'::jsonb
WHERE landing_config IS NULL;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'system_config_landing_config_object_chk'
  ) THEN
    ALTER TABLE public.system_config
      ADD CONSTRAINT system_config_landing_config_object_chk
      CHECK (jsonb_typeof(landing_config) = 'object');
  END IF;
END $$;

COMMENT ON COLUMN public.system_config.landing_config IS
  'Dynamic public landing page configuration: brand text, hero copy, store URLs, icons, reviews, and asset URLs.';
