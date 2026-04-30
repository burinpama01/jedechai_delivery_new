-- Allow reliable key-value settings and per-driver food delivery fee deductions.

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS driver_delivery_system_rate numeric;

ALTER TABLE public.profiles
DROP CONSTRAINT IF EXISTS profiles_driver_delivery_system_rate_range;

ALTER TABLE public.profiles
ADD CONSTRAINT profiles_driver_delivery_system_rate_range
CHECK (
  driver_delivery_system_rate IS NULL
  OR (
    driver_delivery_system_rate >= 0
    AND driver_delivery_system_rate <= 1
  )
);

COMMENT ON COLUMN public.profiles.driver_delivery_system_rate IS
  'Optional per-driver override for the food delivery fee system deduction rate. NULL uses merchant/system default.';

WITH ranked_config AS (
  SELECT
    ctid,
    row_number() OVER (
      PARTITION BY key
      ORDER BY updated_at DESC NULLS LAST, ctid DESC
    ) AS row_num
  FROM public.system_config
  WHERE key IS NOT NULL
)
DELETE FROM public.system_config sc
USING ranked_config rc
WHERE sc.ctid = rc.ctid
  AND rc.row_num > 1;

CREATE UNIQUE INDEX IF NOT EXISTS system_config_key_unique_idx
ON public.system_config (key)
WHERE key IS NOT NULL;
