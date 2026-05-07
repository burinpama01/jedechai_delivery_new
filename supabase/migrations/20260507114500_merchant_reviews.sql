alter table if exists public.reviews
  add column if not exists merchant_rating integer check (merchant_rating between 1 and 5),
  add column if not exists merchant_comment text;

create index if not exists idx_reviews_merchant_rating_booking
  on public.reviews (booking_id, merchant_rating)
  where merchant_rating is not null;
