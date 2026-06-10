create or replace function apply_coupon_atomic(
  p_coupon_id uuid,
  p_user_id uuid,
  p_booking_id uuid,
  p_discount_amount numeric
) returns void
language plpgsql
security definer
as $$
declare
  v_usage_limit int;
  v_used_count int;
  v_per_user_limit int;
  v_user_usage_count int;
  v_start_date timestamptz;
  v_end_date timestamptz;
begin
  select usage_limit, used_count, per_user_limit, start_date, end_date
  into v_usage_limit, v_used_count, v_per_user_limit, v_start_date, v_end_date
  from coupons
  where id = p_coupon_id and is_active = true
  for update;

  if not found then
    raise exception 'COUPON_NOT_FOUND: Coupon not found or inactive';
  end if;

  if v_start_date is not null and now() < v_start_date then
    raise exception 'COUPON_NOT_STARTED: Coupon is not yet valid';
  end if;

  if v_end_date is not null and now() > v_end_date then
    raise exception 'COUPON_EXPIRED: Coupon has expired';
  end if;

  if v_usage_limit > 0 and v_used_count >= v_usage_limit then
    raise exception 'COUPON_EXHAUSTED: Coupon usage limit exceeded';
  end if;

  if v_per_user_limit > 0 then
    select count(*)
    into v_user_usage_count
    from coupon_usages
    where coupon_id = p_coupon_id and user_id = p_user_id;

    if v_user_usage_count >= v_per_user_limit then
      raise exception 'COUPON_USER_LIMIT: Per-user coupon limit exceeded';
    end if;
  end if;

  insert into coupon_usages (coupon_id, user_id, booking_id, discount_amount)
  values (p_coupon_id, p_user_id, p_booking_id, p_discount_amount);

  update coupons
  set used_count = used_count + 1
  where id = p_coupon_id;
end;
$$;

grant execute on function apply_coupon_atomic(uuid, uuid, uuid, numeric) to authenticated;;
