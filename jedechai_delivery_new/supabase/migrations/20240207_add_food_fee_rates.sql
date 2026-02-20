-- Add food delivery fee rates to system_config
-- Allows admin to configure Platform Fee and Merchant GP rates

-- Add new columns to system_config table
ALTER TABLE system_config 
ADD COLUMN IF NOT EXISTS platform_fee_rate NUMERIC DEFAULT 0.15,
ADD COLUMN IF NOT EXISTS merchant_gp_rate NUMERIC DEFAULT 0.10;

-- Update existing record with default values if they don't exist
UPDATE system_config 
SET 
  platform_fee_rate = COALESCE(platform_fee_rate, 0.15),
  merchant_gp_rate = COALESCE(merchant_gp_rate, 0.10);

-- Add comment for documentation
COMMENT ON COLUMN system_config.platform_fee_rate IS 'Platform fee rate for food delivery (e.g., 0.15 = 15%)';
COMMENT ON COLUMN system_config.merchant_gp_rate IS 'Merchant GP rate for food delivery (e.g., 0.10 = 10%)';
