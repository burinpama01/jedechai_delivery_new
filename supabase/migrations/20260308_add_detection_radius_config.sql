-- Add configurable detection radius settings for admin-web
-- Used by system_config.detection_radius_config (JSONB)

ALTER TABLE IF EXISTS public.system_config
  ADD COLUMN IF NOT EXISTS detection_radius_config jsonb;

UPDATE public.system_config
SET detection_radius_config = COALESCE(
  detection_radius_config,
  jsonb_build_object(
    'driver_to_customer_km', 20,
    'customer_to_driver_km', 30,
    'customer_to_merchant_km', 30,
    'driver_to_order_km', 20,
    'parcel_driver_to_pickup_km', 30
  )
);

ALTER TABLE IF EXISTS public.system_config
  ALTER COLUMN detection_radius_config SET DEFAULT jsonb_build_object(
    'driver_to_customer_km', 20,
    'customer_to_driver_km', 30,
    'customer_to_merchant_km', 30,
    'driver_to_order_km', 20,
    'parcel_driver_to_pickup_km', 30
  );

-- Optional shape check (must be JSON object when provided)
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1
    FROM pg_constraint
    WHERE conname = 'system_config_detection_radius_config_is_object'
  ) THEN
    ALTER TABLE public.system_config
      ADD CONSTRAINT system_config_detection_radius_config_is_object
      CHECK (
        detection_radius_config IS NULL
        OR jsonb_typeof(detection_radius_config) = 'object'
      );
  END IF;
END $$;
