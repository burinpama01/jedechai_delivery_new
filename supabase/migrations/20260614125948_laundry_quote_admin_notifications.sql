ALTER TABLE public.laundry_orders
  ADD COLUMN IF NOT EXISTS admin_external_notification_claimed_at timestamptz,
  ADD COLUMN IF NOT EXISTS admin_external_notification_error text,
  ADD COLUMN IF NOT EXISTS admin_external_notified_at timestamptz;

COMMENT ON COLUMN public.laundry_orders.admin_external_notification_claimed_at IS
  'Timestamp when a server-side LINE/Telegram admin notification attempt was atomically claimed.';

COMMENT ON COLUMN public.laundry_orders.admin_external_notification_error IS
  'Last server-side LINE/Telegram admin notification delivery error for a laundry quote request.';

COMMENT ON COLUMN public.laundry_orders.admin_external_notified_at IS
  'Timestamp of the first server-side LINE/Telegram admin notification for a laundry quote request.';
