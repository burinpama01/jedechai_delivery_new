-- Temporary opt-in for Slip2Go masked PromptPay receiver values.
-- Keep disabled by default; admins must explicitly enable it from admin-web.

ALTER TABLE IF EXISTS public.system_config
  ADD COLUMN IF NOT EXISTS slip2go_allow_masked_receiver_account boolean NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS admin_telegram_enabled boolean DEFAULT false,
  ADD COLUMN IF NOT EXISTS admin_telegram_chat_id text;
