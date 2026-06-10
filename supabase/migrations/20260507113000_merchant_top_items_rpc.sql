create or replace function public.get_merchant_top_items(
  p_merchant_id uuid,
  p_start_date timestamptz default null,
  p_end_date timestamptz default null
)
returns table (
  name text,
  order_count bigint,
  revenue numeric
)
language sql
stable
security definer
set search_path = public
as $$
  select
    coalesce(bi.name, mi.name, 'Unknown item') as name,
    count(*)::bigint as order_count,
    coalesce(sum(coalesce(bi.price, 0) * coalesce(bi.quantity, 1)), 0)::numeric as revenue
  from public.booking_items bi
  join public.bookings b on b.id = bi.booking_id
  left join public.menu_items mi on mi.id = bi.menu_item_id
  where b.merchant_id = p_merchant_id
    and auth.uid() = p_merchant_id
    and b.service_type = 'food'
    and b.status = 'completed'
    and (p_start_date is null or b.updated_at >= p_start_date)
    and (p_end_date is null or b.updated_at <= p_end_date)
  group by coalesce(bi.name, mi.name, 'Unknown item')
  order by order_count desc, revenue desc
  limit 10;
$$;
grant execute on function public.get_merchant_top_items(uuid, timestamptz, timestamptz) to authenticated;
