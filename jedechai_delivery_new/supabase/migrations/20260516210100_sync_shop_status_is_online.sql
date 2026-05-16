-- ISSUE-048: Keep shop_status and is_online in sync for merchant profiles.
-- Any UPDATE on profiles that changes shop_status but not is_online will
-- have is_online corrected by this trigger.

CREATE OR REPLACE FUNCTION public.sync_merchant_online_status()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  -- Only fire for merchant profiles (role = 'merchant')
  IF NEW.role IS DISTINCT FROM 'merchant' THEN
    RETURN NEW;
  END IF;

  -- If shop_status changed, mirror it to is_online
  IF NEW.shop_status IS DISTINCT FROM OLD.shop_status THEN
    NEW.is_online := NEW.shop_status;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_merchant_online_status ON public.profiles;

CREATE TRIGGER trg_sync_merchant_online_status
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_merchant_online_status();
