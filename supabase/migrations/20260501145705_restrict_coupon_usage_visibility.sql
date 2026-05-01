-- Restrict coupon usage visibility by role.
--
-- Customers can see their own coupon usage, assigned drivers can see usage for
-- jobs they are handling, and admins can audit all rows. Merchants should not
-- see customer coupon usage rows through RLS; merchant coupon ownership is
-- handled on the coupons table itself.

ALTER TABLE IF EXISTS public.coupon_usages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS coupon_usage_select_own ON public.coupon_usages;
DROP POLICY IF EXISTS coupon_usage_insert ON public.coupon_usages;
DROP POLICY IF EXISTS cu_select_own ON public.coupon_usages;
DROP POLICY IF EXISTS cu_insert_own ON public.coupon_usages;
DROP POLICY IF EXISTS cu_admin_select ON public.coupon_usages;
DROP POLICY IF EXISTS coupon_usage_select_customer_driver_admin
  ON public.coupon_usages;
DROP POLICY IF EXISTS coupon_usage_insert_customer_own ON public.coupon_usages;

CREATE POLICY coupon_usage_select_customer_driver_admin
ON public.coupon_usages
FOR SELECT
USING (
  auth.uid() = user_id
  OR EXISTS (
    SELECT 1
    FROM public.bookings b
    WHERE b.id = coupon_usages.booking_id
      AND b.driver_id = auth.uid()
  )
  OR EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'
  )
);

CREATE POLICY coupon_usage_insert_customer_own
ON public.coupon_usages
FOR INSERT
WITH CHECK (auth.uid() = user_id);
