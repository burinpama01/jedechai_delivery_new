create table if not exists public.customer_favorites (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references auth.users(id) on delete cascade,
  merchant_id uuid not null references auth.users(id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (customer_id, merchant_id)
);

create index if not exists idx_customer_favorites_customer
  on public.customer_favorites(customer_id);

create index if not exists idx_customer_favorites_merchant
  on public.customer_favorites(merchant_id);

alter table public.customer_favorites enable row level security;

create policy "Customers can read own favorites"
  on public.customer_favorites
  for select
  using (auth.uid() = customer_id);

create policy "Customers can add own favorites"
  on public.customer_favorites
  for insert
  with check (
    auth.uid() = customer_id
    and exists (
      select 1
      from public.profiles customer_profile
      where customer_profile.id = customer_id
        and customer_profile.role = 'customer'
    )
    and exists (
      select 1
      from public.profiles merchant_profile
      where merchant_profile.id = merchant_id
        and merchant_profile.role = 'merchant'
        and merchant_profile.approval_status = 'approved'
    )
  );

create policy "Customers can update own favorites"
  on public.customer_favorites
  for update
  using (auth.uid() = customer_id)
  with check (
    auth.uid() = customer_id
    and exists (
      select 1
      from public.profiles customer_profile
      where customer_profile.id = customer_id
        and customer_profile.role = 'customer'
    )
    and exists (
      select 1
      from public.profiles merchant_profile
      where merchant_profile.id = merchant_id
        and merchant_profile.role = 'merchant'
        and merchant_profile.approval_status = 'approved'
    )
  );

create policy "Customers can delete own favorites"
  on public.customer_favorites
  for delete
  using (auth.uid() = customer_id);
