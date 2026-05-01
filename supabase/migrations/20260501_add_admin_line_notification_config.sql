-- Admin LINE notification settings.
-- LINE channel access token is stored as an Edge Function secret, not in the database.

ALTER TABLE IF EXISTS public.system_config
  ADD COLUMN IF NOT EXISTS admin_line_enabled BOOLEAN DEFAULT false;

ALTER TABLE IF EXISTS public.system_config
  ADD COLUMN IF NOT EXISTS admin_line_recipient_id TEXT;

UPDATE public.system_config
SET admin_line_enabled = false
WHERE admin_line_enabled IS NULL;

COMMENT ON COLUMN public.system_config.admin_line_enabled IS
'Enable LINE Messaging API push notifications for admin alerts.';

COMMENT ON COLUMN public.system_config.admin_line_recipient_id IS
'LINE userId, groupId, or roomId that receives admin alerts.';
