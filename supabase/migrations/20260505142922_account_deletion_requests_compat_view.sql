-- Compatibility alias for older deployed clients that still query
-- public.deletion_requests instead of public.account_deletion_requests.
--
-- security_invoker keeps RLS enforced by the underlying table policies.
CREATE OR REPLACE VIEW public.deletion_requests
WITH (security_invoker = true)
AS
SELECT *
FROM public.account_deletion_requests;

COMMENT ON VIEW public.deletion_requests IS
  'Compatibility view for legacy clients. Canonical table: public.account_deletion_requests.';

GRANT SELECT, INSERT, UPDATE, DELETE ON public.deletion_requests TO authenticated;

NOTIFY pgrst, 'reload schema';
