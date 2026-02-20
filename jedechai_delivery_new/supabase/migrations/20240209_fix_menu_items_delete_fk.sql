-- ============================================================
-- Fix: Allow menu items to be deleted even when referenced by booking_items
-- Change FK constraint from RESTRICT to SET NULL
-- ============================================================

-- Step 1: Make menu_item_id nullable in booking_items
ALTER TABLE booking_items ALTER COLUMN menu_item_id DROP NOT NULL;

-- Step 2: Drop old FK constraint
ALTER TABLE booking_items DROP CONSTRAINT IF EXISTS booking_items_menu_item_id_fkey;

-- Step 3: Re-add FK constraint with ON DELETE SET NULL
ALTER TABLE booking_items
  ADD CONSTRAINT booking_items_menu_item_id_fkey
  FOREIGN KEY (menu_item_id) REFERENCES menu_items(id)
  ON DELETE SET NULL;
