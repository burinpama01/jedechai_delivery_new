-- Store customer-selected food options such as sweetness, spiciness, add-ons,
-- and other merchant-defined choices on each booking item.

ALTER TABLE IF EXISTS public.booking_items
  ADD COLUMN IF NOT EXISTS selected_options JSONB NOT NULL DEFAULT '[]'::jsonb;

ALTER TABLE IF EXISTS public.booking_items
  ADD COLUMN IF NOT EXISTS options JSONB NOT NULL DEFAULT '[]'::jsonb;

