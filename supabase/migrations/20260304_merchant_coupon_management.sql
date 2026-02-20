-- Merchant coupon management + settlement metadata
-- Safe/idempotent additions for existing coupons table.

ALTER TABLE IF EXISTS public.coupons
  ADD COLUMN IF NOT EXISTS created_by_role text DEFAULT 'admin',
  ADD COLUMN IF NOT EXISTS merchant_gp_charge_rate numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS merchant_gp_system_rate numeric DEFAULT 0,
  ADD COLUMN IF NOT EXISTS merchant_gp_driver_rate numeric DEFAULT 0;

-- Backfill for existing merchant coupons
UPDATE public.coupons
SET created_by_role = 'merchant'
WHERE merchant_id IS NOT NULL
  AND (created_by_role IS NULL OR created_by_role = 'admin');

UPDATE public.coupons
SET created_by_role = COALESCE(created_by_role, 'admin')
WHERE created_by_role IS NULL;

-- For merchant free-delivery coupons, set sensible defaults if missing
UPDATE public.coupons
SET
  merchant_gp_charge_rate = COALESCE(NULLIF(merchant_gp_charge_rate, 0), 0.25),
  merchant_gp_system_rate = COALESCE(NULLIF(merchant_gp_system_rate, 0), 0.10),
  merchant_gp_driver_rate = COALESCE(NULLIF(merchant_gp_driver_rate, 0), 0.15)
WHERE merchant_id IS NOT NULL
  AND discount_type = 'free_delivery';

CREATE INDEX IF NOT EXISTS idx_coupons_merchant_id ON public.coupons(merchant_id);
CREATE INDEX IF NOT EXISTS idx_coupons_created_by_role ON public.coupons(created_by_role);
