alter table if exists bookings enable row level security;

create policy "merchant_select_own_food_bookings"
  on bookings
  for select
  using (
    merchant_id::text = auth.uid()::text
    or customer_id::text = auth.uid()::text
    or driver_id::text = auth.uid()::text
  );;
