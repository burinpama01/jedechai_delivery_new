alter table if exists public.menu_items
  add column if not exists is_available boolean not null default true,
  add column if not exists unavailable_reason text,
  add column if not exists prep_time_minutes integer not null default 15;
create table if not exists public.menu_categories (
  id uuid primary key default gen_random_uuid(),
  merchant_id uuid not null references public.profiles(id) on delete cascade,
  name text not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
alter table if exists public.menu_items
  add column if not exists category_id uuid references public.menu_categories(id) on delete set null,
  add column if not exists sort_order integer not null default 0;
create index if not exists idx_menu_items_merchant_available
  on public.menu_items (merchant_id, is_available);
create index if not exists idx_menu_items_category_sort
  on public.menu_items (category_id, sort_order);
create index if not exists idx_menu_categories_merchant_sort
  on public.menu_categories (merchant_id, sort_order);
alter table public.menu_categories enable row level security;
drop policy if exists "Merchants manage own menu categories" on public.menu_categories;
create policy "Merchants manage own menu categories"
  on public.menu_categories
  for all
  using (auth.uid() = merchant_id)
  with check (auth.uid() = merchant_id);
drop policy if exists "Active menu categories are readable" on public.menu_categories;
create policy "Active menu categories are readable"
  on public.menu_categories
  for select
  using (is_active = true);
