-- ============================================
-- Add scheduled_at support for bookings
-- ============================================
-- Enables scheduled orders for ride/food/parcel flows.

ALTER TABLE public.bookings
ADD COLUMN IF NOT EXISTS scheduled_at timestamptz;

CREATE INDEX IF NOT EXISTS idx_bookings_scheduled_at
ON public.bookings(scheduled_at);

COMMENT ON COLUMN public.bookings.scheduled_at IS
'Optional scheduled delivery datetime. NULL = immediate order.';
