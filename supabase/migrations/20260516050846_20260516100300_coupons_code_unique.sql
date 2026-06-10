alter table if exists coupons
  add constraint coupons_code_unique unique (code);;
