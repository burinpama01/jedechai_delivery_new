-- Backfill missing/zero settlement fields so reports and dialogs read the same
-- driver_earnings/app_earnings values produced by the mobile completion flow.

WITH cfg AS (
  SELECT
    COALESCE(platform_fee_rate, 0.15)::numeric AS platform_fee_rate,
    COALESCE(merchant_gp_rate, 0.10)::numeric AS merchant_gp_rate,
    COALESCE(merchant_gp_system_rate_default, merchant_gp_rate, 0.10)::numeric
      AS default_merchant_system_rate,
    COALESCE(merchant_gp_driver_rate_default, 0)::numeric
      AS default_merchant_driver_rate,
    COALESCE(commission_rate, 15)::numeric AS commission_rate
  FROM (SELECT 1) seed
  LEFT JOIN LATERAL (
    SELECT *
    FROM public.system_config
    LIMIT 1
  ) sc ON true
),
food_calc AS (
  SELECT
    b.id,
    CEIL(COALESCE(b.delivery_fee, 0) * (
      CASE
        WHEN p.gp_rate IS NOT NULL AND ABS(p.gp_rate - 0.10) < 0.0001 THEN 0.02
        WHEN p.gp_rate IS NOT NULL AND ABS(p.gp_rate - 0.20) < 0.0001 THEN 0.01
        WHEN p.gp_rate IS NOT NULL AND ABS(p.gp_rate - 0.25) < 0.0001 THEN 0.00
        ELSE cfg.platform_fee_rate
      END
    ))::numeric AS delivery_system_fee,
    CEIL(COALESCE(b.price, 0) * COALESCE(
      p.merchant_gp_system_rate,
      CASE
        WHEN p.gp_rate IS NOT NULL AND ABS(p.gp_rate - 0.10) < 0.0001 THEN 0.10
        WHEN p.gp_rate IS NOT NULL AND ABS(p.gp_rate - 0.20) < 0.0001 THEN 0.10
        WHEN p.gp_rate IS NOT NULL AND ABS(p.gp_rate - 0.25) < 0.0001 THEN 0.13
        ELSE cfg.default_merchant_system_rate
      END
    ))::numeric AS merchant_system_gp,
    CEIL(COALESCE(b.price, 0) * COALESCE(
      p.merchant_gp_driver_rate,
      CASE
        WHEN p.gp_rate IS NOT NULL AND ABS(p.gp_rate - 0.10) < 0.0001 THEN 0.00
        WHEN p.gp_rate IS NOT NULL AND ABS(p.gp_rate - 0.20) < 0.0001 THEN 0.10
        WHEN p.gp_rate IS NOT NULL AND ABS(p.gp_rate - 0.25) < 0.0001 THEN 0.12
        ELSE cfg.default_merchant_driver_rate
      END
    ))::numeric AS merchant_driver_gp,
    COALESCE(b.delivery_fee, 0)::numeric AS delivery_fee
  FROM public.bookings b
  CROSS JOIN cfg
  LEFT JOIN public.profiles p ON p.id = b.merchant_id
  WHERE b.status = 'completed'
    AND b.service_type = 'food'
    AND (
      b.driver_earnings IS NULL OR b.driver_earnings <= 0
      OR b.app_earnings IS NULL OR b.app_earnings <= 0
    )
)
UPDATE public.bookings b
SET
  app_earnings = food_calc.delivery_system_fee + food_calc.merchant_system_gp,
  driver_earnings = GREATEST(
    food_calc.delivery_fee - food_calc.delivery_system_fee + food_calc.merchant_driver_gp,
    0
  )
FROM food_calc
WHERE b.id = food_calc.id;

WITH cfg AS (
  SELECT
    COALESCE(commission_rate, 15)::numeric AS commission_rate
  FROM (SELECT 1) seed
  LEFT JOIN LATERAL (
    SELECT *
    FROM public.system_config
    LIMIT 1
  ) sc ON true
),
non_food_calc AS (
  SELECT
    b.id,
    CEIL(COALESCE(b.price, 0) * (cfg.commission_rate / 100))::numeric AS app_earnings,
    GREATEST(
      COALESCE(b.price, 0) - CEIL(COALESCE(b.price, 0) * (cfg.commission_rate / 100)),
      0
    )::numeric AS driver_earnings
  FROM public.bookings b
  CROSS JOIN cfg
  WHERE b.status = 'completed'
    AND b.service_type <> 'food'
    AND (
      b.driver_earnings IS NULL OR b.driver_earnings <= 0
      OR b.app_earnings IS NULL OR b.app_earnings <= 0
    )
)
UPDATE public.bookings b
SET
  app_earnings = non_food_calc.app_earnings,
  driver_earnings = non_food_calc.driver_earnings
FROM non_food_calc
WHERE b.id = non_food_calc.id;
