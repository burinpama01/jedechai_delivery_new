-- Add RLS policy so merchants only see their own food bookings via realtime stream.
-- This removes the need for client-side filtering in watchOrders(), reducing
-- payload size and preventing cross-merchant data exposure.

-- Enable RLS on bookings if not already enabled
alter table if exists bookings enable row level security;

-- Merchant can select their own food bookings
create policy "merchant_select_own_food_bookings"
  on bookings
  for select
  using (
    -- cast both sides to text to handle mixed uuid/text column types
    merchant_id::text = auth.uid()::text
    or customer_id::text = auth.uid()::text
    or driver_id::text = auth.uid()::text
  );
