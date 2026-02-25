-- Add explicit GP split columns for merchant profiles + default split columns in system_config
-- This migration makes GP split persistence schema-safe without relying only on key/value rows.

ALTER TABLE IF EXISTS public.profiles
  ADD COLUMN IF NOT EXISTS merchant_gp_system_rate numeric,
  ADD COLUMN IF NOT EXISTS merchant_gp_driver_rate numeric;

ALTER TABLE IF EXISTS public.system_config
  ADD COLUMN IF NOT EXISTS merchant_gp_system_rate_default numeric,
  ADD COLUMN IF NOT EXISTS merchant_gp_driver_rate_default numeric;

COMMENT ON COLUMN public.profiles.merchant_gp_system_rate IS 'Per-merchant GP split to system (0..1). NULL = use default split.';
COMMENT ON COLUMN public.profiles.merchant_gp_driver_rate IS 'Per-merchant GP split to driver (0..1). NULL = use default split.';
COMMENT ON COLUMN public.system_config.merchant_gp_system_rate_default IS 'Default merchant GP split to system (0..1).';
COMMENT ON COLUMN public.system_config.merchant_gp_driver_rate_default IS 'Default merchant GP split to driver (0..1).';

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_profiles_merchant_gp_system_rate_range'
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT chk_profiles_merchant_gp_system_rate_range
      CHECK (
        merchant_gp_system_rate IS NULL
        OR (merchant_gp_system_rate >= 0 AND merchant_gp_system_rate <= 1)
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_profiles_merchant_gp_driver_rate_range'
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT chk_profiles_merchant_gp_driver_rate_range
      CHECK (
        merchant_gp_driver_rate IS NULL
        OR (merchant_gp_driver_rate >= 0 AND merchant_gp_driver_rate <= 1)
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_profiles_merchant_gp_split_not_exceed_gp'
  ) THEN
    ALTER TABLE public.profiles
      ADD CONSTRAINT chk_profiles_merchant_gp_split_not_exceed_gp
      CHECK (
        gp_rate IS NULL
        OR (
          COALESCE(merchant_gp_system_rate, 0) + COALESCE(merchant_gp_driver_rate, 0)
          <= gp_rate + 0.0001
        )
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_system_config_merchant_gp_system_rate_default_range'
  ) THEN
    ALTER TABLE public.system_config
      ADD CONSTRAINT chk_system_config_merchant_gp_system_rate_default_range
      CHECK (
        merchant_gp_system_rate_default IS NULL
        OR (merchant_gp_system_rate_default >= 0 AND merchant_gp_system_rate_default <= 1)
      );
  END IF;

  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'chk_system_config_merchant_gp_driver_rate_default_range'
  ) THEN
    ALTER TABLE public.system_config
      ADD CONSTRAINT chk_system_config_merchant_gp_driver_rate_default_range
      CHECK (
        merchant_gp_driver_rate_default IS NULL
        OR (merchant_gp_driver_rate_default >= 0 AND merchant_gp_driver_rate_default <= 1)
      );
  END IF;
END $$;

-- Backfill profile split from existing gp_rate when split is still empty.
UPDATE public.profiles
SET
  merchant_gp_system_rate = COALESCE(merchant_gp_system_rate, gp_rate),
  merchant_gp_driver_rate = COALESCE(merchant_gp_driver_rate, 0)
WHERE gp_rate IS NOT NULL
  AND merchant_gp_system_rate IS NULL
  AND merchant_gp_driver_rate IS NULL;

-- Backfill system defaults if not set.
UPDATE public.system_config
SET
  merchant_gp_system_rate_default = COALESCE(merchant_gp_system_rate_default, merchant_gp_rate, 0.10),
  merchant_gp_driver_rate_default = COALESCE(merchant_gp_driver_rate_default, 0)
WHERE merchant_gp_system_rate_default IS NULL
   OR merchant_gp_driver_rate_default IS NULL;

-- Backfill from key/value schema when available.
DO $$
DECLARE
  has_key_col boolean;
  has_value_col boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'system_config'
      AND column_name = 'key'
  ) INTO has_key_col;

  SELECT EXISTS (
    SELECT 1
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'system_config'
      AND column_name = 'value'
  ) INTO has_value_col;

  IF has_key_col AND has_value_col THEN
    UPDATE public.system_config cfg
    SET
      merchant_gp_system_rate_default = COALESCE(
        merchant_gp_system_rate_default,
        (
          SELECT sc.value::numeric
          FROM public.system_config sc
          WHERE sc.key = 'merchant_gp_system_rate_default'
            AND sc.value IS NOT NULL
            AND sc.value <> ''
          LIMIT 1
        )
      ),
      merchant_gp_driver_rate_default = COALESCE(
        merchant_gp_driver_rate_default,
        (
          SELECT sc.value::numeric
          FROM public.system_config sc
          WHERE sc.key = 'merchant_gp_driver_rate_default'
            AND sc.value IS NOT NULL
            AND sc.value <> ''
          LIMIT 1
        )
      );

    UPDATE public.profiles p
    SET
      merchant_gp_system_rate = COALESCE(
        merchant_gp_system_rate,
        (
          SELECT sc.value::numeric
          FROM public.system_config sc
          WHERE sc.key = 'merchant_gp_system_rate_' || p.id::text
            AND sc.value IS NOT NULL
            AND sc.value <> ''
          LIMIT 1
        )
      ),
      merchant_gp_driver_rate = COALESCE(
        merchant_gp_driver_rate,
        (
          SELECT sc.value::numeric
          FROM public.system_config sc
          WHERE sc.key = 'merchant_gp_driver_rate_' || p.id::text
            AND sc.value IS NOT NULL
            AND sc.value <> ''
          LIMIT 1
        )
      )
    WHERE p.role = 'merchant';
  END IF;
END $$;
