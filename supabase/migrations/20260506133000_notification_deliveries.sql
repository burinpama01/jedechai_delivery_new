CREATE TABLE IF NOT EXISTS public.notification_deliveries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  notification_id uuid REFERENCES public.notifications(id) ON DELETE SET NULL,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  channel text NOT NULL DEFAULT 'fcm',
  status text NOT NULL,
  provider_message_id text,
  error text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_notification_deliveries_user_created_at
ON public.notification_deliveries (user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notification_deliveries_status_created_at
ON public.notification_deliveries (status, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_notification_deliveries_notification_id
ON public.notification_deliveries (notification_id);
ALTER TABLE public.notification_deliveries ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "Users can read own notification deliveries" ON public.notification_deliveries;
DROP POLICY IF EXISTS "Admins can read notification deliveries" ON public.notification_deliveries;
CREATE POLICY "Users can read own notification deliveries"
ON public.notification_deliveries
FOR SELECT
TO authenticated
USING (auth.uid() = user_id);
CREATE POLICY "Admins can read notification deliveries"
ON public.notification_deliveries
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'
  )
);
COMMENT ON TABLE public.notification_deliveries IS
'Delivery attempts for notification channels such as FCM.';
