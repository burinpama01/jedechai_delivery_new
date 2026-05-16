-- Add UNIQUE constraint on coupons.code to prevent duplicate codes at DB level.
-- Client-side validation was the only guard before this migration.

alter table if exists coupons
  add constraint coupons_code_unique unique (code);
