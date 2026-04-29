-- Ensure driver/admin cancellation fields exist on the active Supabase project.
-- Older app builds used cancel_reason, while admin actions use cancellation_reason.

ALTER TABLE IF EXISTS public.bookings
  ADD COLUMN IF NOT EXISTS cancellation_reason text,
  ADD COLUMN IF NOT EXISTS cancel_reason text,
  ADD COLUMN IF NOT EXISTS cancelled_by text,
  ADD COLUMN IF NOT EXISTS cancelled_at timestamptz;

CREATE OR REPLACE FUNCTION public.sync_booking_cancellation_fields()
RETURNS trigger AS $$
BEGIN
  IF NEW.status = 'cancelled' THEN
    IF NEW.cancelled_at IS NULL THEN
      NEW.cancelled_at = now();
    END IF;

    IF NEW.cancellation_reason IS NULL AND NEW.cancel_reason IS NOT NULL THEN
      NEW.cancellation_reason = NEW.cancel_reason;
    END IF;

    IF NEW.cancel_reason IS NULL AND NEW.cancellation_reason IS NOT NULL THEN
      NEW.cancel_reason = NEW.cancellation_reason;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS sync_booking_cancellation_fields ON public.bookings;
CREATE TRIGGER sync_booking_cancellation_fields
  BEFORE INSERT OR UPDATE ON public.bookings
  FOR EACH ROW
  EXECUTE FUNCTION public.sync_booking_cancellation_fields();

COMMENT ON COLUMN public.bookings.cancellation_reason IS 'Canonical cancellation reason used by admin actions and current app code.';
COMMENT ON COLUMN public.bookings.cancel_reason IS 'Backward-compatible cancellation reason for older driver app builds.';
COMMENT ON COLUMN public.bookings.cancelled_by IS 'Actor that cancelled the booking, for example customer, driver, merchant, or admin.';
COMMENT ON COLUMN public.bookings.cancelled_at IS 'Timestamp when booking first entered cancelled status.';
