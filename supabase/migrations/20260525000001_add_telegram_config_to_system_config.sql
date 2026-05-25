-- Add Telegram notification config columns to system_config
ALTER TABLE public.system_config
  ADD COLUMN IF NOT EXISTS admin_telegram_enabled boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS admin_telegram_chat_id text;
