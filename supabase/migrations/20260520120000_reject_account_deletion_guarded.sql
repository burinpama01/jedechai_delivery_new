CREATE SCHEMA IF NOT EXISTS private;

DROP FUNCTION IF EXISTS public.reject_account_deletion_guarded(text, uuid, text);

CREATE OR REPLACE FUNCTION private.reject_account_deletion_guarded(
  p_request_id text,
  p_admin_id uuid,
  p_reason text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_user_id uuid;
  v_profile_rows integer;
  v_request_status text;
BEGIN
  SELECT user_id, status
  INTO v_user_id, v_request_status
  FROM public.account_deletion_requests
  WHERE id::text = p_request_id
    AND status IN ('pending', 'rejected')
  FOR UPDATE;

  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'account deletion request is not pending/rejected or not found';
  END IF;

  UPDATE public.account_deletion_requests
  SET
    status = 'rejected',
    rejection_reason = COALESCE(p_reason, ''),
    reviewed_at = now(),
    reviewed_by = p_admin_id
  WHERE id::text = p_request_id
    AND status IN ('pending', 'rejected');

  IF EXISTS (
    SELECT 1
    FROM public.account_deletion_requests
    WHERE user_id = v_user_id
      AND id::text <> p_request_id
      AND status = 'pending'
  ) THEN
    RETURN jsonb_build_object(
      'success', true,
      'user_id', v_user_id,
      'previous_status', v_request_status,
      'profile_cleared', false,
      'reason', 'another_pending_request_exists'
    );
  END IF;

  UPDATE public.profiles
  SET deletion_status = NULL
  WHERE id = v_user_id;

  GET DIAGNOSTICS v_profile_rows = ROW_COUNT;
  IF v_profile_rows <> 1 THEN
    RAISE EXCEPTION 'profile deletion_status clear failed for user %', v_user_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'user_id', v_user_id,
    'previous_status', v_request_status,
    'profile_cleared', true
  );
END;
$$;

REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA private TO service_role;

REVOKE ALL ON FUNCTION private.reject_account_deletion_guarded(text, uuid, text)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION private.reject_account_deletion_guarded(text, uuid, text)
TO service_role;

CREATE OR REPLACE FUNCTION public.reject_account_deletion_guarded(
  p_request_id text,
  p_admin_id uuid,
  p_reason text DEFAULT ''
)
RETURNS jsonb
LANGUAGE sql
SECURITY INVOKER
SET search_path = public, private
AS $$
  SELECT private.reject_account_deletion_guarded(p_request_id, p_admin_id, p_reason);
$$;

REVOKE ALL ON FUNCTION public.reject_account_deletion_guarded(text, uuid, text)
FROM PUBLIC, anon, authenticated;

GRANT EXECUTE ON FUNCTION public.reject_account_deletion_guarded(text, uuid, text)
TO service_role;

UPDATE public.profiles p
SET deletion_status = NULL
WHERE p.deletion_status = 'pending'
  AND NOT EXISTS (
    SELECT 1
    FROM public.account_deletion_requests r
    WHERE r.user_id = p.id
      AND r.status = 'pending'
  )
  AND EXISTS (
    SELECT 1
    FROM public.account_deletion_requests r
    WHERE r.user_id = p.id
      AND r.status IN ('rejected', 'cancelled')
  );
