-- Add topup_mode column to system_config
-- Values: 'omise' (automatic via Omise PromptPay) or 'admin_approve' (manual admin approval)
-- Default: 'admin_approve' for safety

ALTER TABLE system_config
ADD COLUMN IF NOT EXISTS topup_mode TEXT NOT NULL DEFAULT 'admin_approve';

COMMENT ON COLUMN system_config.topup_mode IS 'Wallet topup mode: omise = automatic via Omise, admin_approve = manual admin approval';
