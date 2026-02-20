-- Add category column to menu_items table
-- This column is used by merchant to categorize menu items
-- and by customer to browse menu by category

ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS category TEXT DEFAULT 'อื่นๆ';

-- Create index for category
CREATE INDEX IF NOT EXISTS idx_menu_items_category ON menu_items(category);
