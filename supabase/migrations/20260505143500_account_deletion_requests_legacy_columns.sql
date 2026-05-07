-- Legacy admin web compatibility for old deployed bundles that still write
-- deletion_requests.processed_at and related consolidated-schema columns.
ALTER TABLE public.account_deletion_requests
  ADD COLUMN IF NOT EXISTS processed_at timestamptz,
  ADD COLUMN IF NOT EXISTS admin_note text,
  ADD COLUMN IF NOT EXISTS created_at timestamptz,
  ADD COLUMN IF NOT EXISTS updated_at timestamptz;

UPDATE public.account_deletion_requests
SET
  processed_at = COALESCE(processed_at, reviewed_at),
  created_at = COALESCE(created_at, requested_at),
  updated_at = COALESCE(updated_at, reviewed_at, requested_at)
WHERE
  processed_at IS NULL
  OR created_at IS NULL
  OR updated_at IS NULL;

CREATE OR REPLACE FUNCTION public.sync_account_deletion_legacy_timestamps()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF NEW.reviewed_at IS NULL AND NEW.processed_at IS NOT NULL THEN
    NEW.reviewed_at := NEW.processed_at;
  ELSIF NEW.processed_at IS NULL AND NEW.reviewed_at IS NOT NULL THEN
    NEW.processed_at := NEW.reviewed_at;
  END IF;

  IF NEW.created_at IS NULL THEN
    NEW.created_at := COALESCE(NEW.requested_at, now());
  END IF;

  NEW.updated_at := now();

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trigger_sync_account_deletion_legacy_timestamps
  ON public.account_deletion_requests;

CREATE TRIGGER trigger_sync_account_deletion_legacy_timestamps
  BEFORE INSERT OR UPDATE ON public.account_deletion_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_account_deletion_legacy_timestamps();

CREATE OR REPLACE VIEW public.deletion_requests
WITH (security_invoker = true)
AS
SELECT *
FROM public.account_deletion_requests;

COMMENT ON VIEW public.deletion_requests IS
  'Compatibility view for legacy clients. Canonical table: public.account_deletion_requests.';

GRANT SELECT, INSERT, UPDATE, DELETE ON public.deletion_requests TO authenticated;

NOTIFY pgrst, 'reload schema';
