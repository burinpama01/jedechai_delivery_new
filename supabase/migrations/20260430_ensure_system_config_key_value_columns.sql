-- Some legacy triggers/RPCs still read system_config as key/value rows.
-- Keep these nullable columns available alongside the newer single-row config
-- columns so completing bookings cannot fail with "column value does not exist".

ALTER TABLE IF EXISTS public.system_config
  ADD COLUMN IF NOT EXISTS key TEXT;

ALTER TABLE IF EXISTS public.system_config
  ADD COLUMN IF NOT EXISTS value TEXT;

CREATE INDEX IF NOT EXISTS idx_system_config_key
  ON public.system_config(key)
  WHERE key IS NOT NULL;

