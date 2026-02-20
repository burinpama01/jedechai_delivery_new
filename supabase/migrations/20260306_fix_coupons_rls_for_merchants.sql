-- Fix RLS for coupons so merchants can manage their own coupons
-- while keeping admin full access and public active-coupon visibility.

ALTER TABLE IF EXISTS public.coupons ENABLE ROW LEVEL SECURITY;

-- Clean up legacy policies if they exist
DROP POLICY IF EXISTS coupons_select_active ON public.coupons;
DROP POLICY IF EXISTS coupons_admin ON public.coupons;
DROP POLICY IF EXISTS coupons_admin_all ON public.coupons;
DROP POLICY IF EXISTS coupons_select_active_or_admin ON public.coupons;
DROP POLICY IF EXISTS coupons_select_merchant_own ON public.coupons;
DROP POLICY IF EXISTS coupons_insert_merchant_own ON public.coupons;
DROP POLICY IF EXISTS coupons_update_merchant_own ON public.coupons;
DROP POLICY IF EXISTS coupons_delete_merchant_own ON public.coupons;

-- Public / authenticated users can view active coupons.
CREATE POLICY coupons_select_active_or_admin
ON public.coupons
FOR SELECT
USING (
  is_active = true
  OR EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'
  )
);

-- Admin can do everything on coupons.
CREATE POLICY coupons_admin_all
ON public.coupons
FOR ALL
USING (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'
  )
)
WITH CHECK (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'
  )
);

-- Merchant can view all of their own coupons (including inactive/expired).
CREATE POLICY coupons_select_merchant_own
ON public.coupons
FOR SELECT
USING (
  merchant_id = auth.uid()
  AND created_by_role = 'merchant'
);

-- Merchant can create only own merchant coupon rows.
CREATE POLICY coupons_insert_merchant_own
ON public.coupons
FOR INSERT
WITH CHECK (
  merchant_id = auth.uid()
  AND created_by_role = 'merchant'
  AND (service_type IS NULL OR service_type = 'food')
);

-- Merchant can update only own merchant coupon rows.
CREATE POLICY coupons_update_merchant_own
ON public.coupons
FOR UPDATE
USING (
  merchant_id = auth.uid()
  AND created_by_role = 'merchant'
)
WITH CHECK (
  merchant_id = auth.uid()
  AND created_by_role = 'merchant'
  AND (service_type IS NULL OR service_type = 'food')
);

-- Merchant can delete only own merchant coupon rows.
CREATE POLICY coupons_delete_merchant_own
ON public.coupons
FOR DELETE
USING (
  merchant_id = auth.uid()
  AND created_by_role = 'merchant'
);
