-- ============================================================
-- Phase 1C: RLS Hardening
-- ============================================================
-- Adds proper RLS policies for tables that currently have
-- USING(true) or no policies at all.
-- Three access levels: owner, admin, service (Edge Functions)
-- ============================================================

-- ────────────────────────────────────────────────────────────
-- Helper: reusable admin check expression
-- ────────────────────────────────────────────────────────────
-- (used inline below as: EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'))

-- ────────────────────────────────────────────────────────────
-- 1) wallets
-- ────────────────────────────────────────────────────────────
ALTER TABLE IF EXISTS public.wallets ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wallets_select_own" ON public.wallets;
DROP POLICY IF EXISTS "wallets_update_own" ON public.wallets;
DROP POLICY IF EXISTS "wallets_admin_select" ON public.wallets;
DROP POLICY IF EXISTS "wallets_service_all" ON public.wallets;
DROP POLICY IF EXISTS "Users can view own wallet" ON public.wallets;
DROP POLICY IF EXISTS "Service role full access" ON public.wallets;

CREATE POLICY "wallets_select_own" ON public.wallets
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "wallets_admin_select" ON public.wallets
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Wallet writes go through Edge Functions (service role) only
-- No direct INSERT/UPDATE/DELETE for authenticated users

-- ────────────────────────────────────────────────────────────
-- 2) wallet_transactions
-- ────────────────────────────────────────────────────────────
ALTER TABLE IF EXISTS public.wallet_transactions ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wallet_tx_select_own" ON public.wallet_transactions;
DROP POLICY IF EXISTS "wallet_tx_admin_select" ON public.wallet_transactions;
DROP POLICY IF EXISTS "Service role full access" ON public.wallet_transactions;

CREATE POLICY "wallet_tx_select_own" ON public.wallet_transactions
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.wallets w
      WHERE w.id = wallet_transactions.wallet_id AND w.user_id = auth.uid()
    )
  );

CREATE POLICY "wallet_tx_admin_select" ON public.wallet_transactions
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Wallet transaction writes go through Edge Functions / RPC only

-- ────────────────────────────────────────────────────────────
-- 3) bookings
-- ────────────────────────────────────────────────────────────
ALTER TABLE IF EXISTS public.bookings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "bookings_select_involved" ON public.bookings;
DROP POLICY IF EXISTS "bookings_insert_customer" ON public.bookings;
DROP POLICY IF EXISTS "bookings_update_involved" ON public.bookings;
DROP POLICY IF EXISTS "bookings_admin_all" ON public.bookings;
DROP POLICY IF EXISTS "Service role full access" ON public.bookings;
DROP POLICY IF EXISTS "Authenticated users can read bookings" ON public.bookings;
DROP POLICY IF EXISTS "Authenticated users can insert bookings" ON public.bookings;
DROP POLICY IF EXISTS "Authenticated users can update bookings" ON public.bookings;

-- Users can read bookings they are involved in (customer, driver, or merchant)
CREATE POLICY "bookings_select_involved" ON public.bookings
  FOR SELECT USING (
    auth.uid() = customer_id
    OR auth.uid() = driver_id
    OR auth.uid() = merchant_id
  );

-- Customers can create bookings
CREATE POLICY "bookings_insert_customer" ON public.bookings
  FOR INSERT WITH CHECK (auth.uid() = customer_id);

-- Involved parties can update bookings (status transitions validated in app/Edge Function)
CREATE POLICY "bookings_update_involved" ON public.bookings
  FOR UPDATE USING (
    auth.uid() = customer_id
    OR auth.uid() = driver_id
    OR auth.uid() = merchant_id
  );

-- Admin can read all bookings
CREATE POLICY "bookings_admin_all" ON public.bookings
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ────────────────────────────────────────────────────────────
-- 4) withdrawal_requests
-- ────────────────────────────────────────────────────────────
ALTER TABLE IF EXISTS public.withdrawal_requests ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "wr_select_own" ON public.withdrawal_requests;
DROP POLICY IF EXISTS "wr_insert_own" ON public.withdrawal_requests;
DROP POLICY IF EXISTS "wr_admin_select" ON public.withdrawal_requests;
DROP POLICY IF EXISTS "Service role full access" ON public.withdrawal_requests;
DROP POLICY IF EXISTS "Users can view own withdrawals" ON public.withdrawal_requests;
DROP POLICY IF EXISTS "Users can create own withdrawals" ON public.withdrawal_requests;

CREATE POLICY "wr_select_own" ON public.withdrawal_requests
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "wr_insert_own" ON public.withdrawal_requests
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "wr_admin_select" ON public.withdrawal_requests
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Withdrawal approve/reject goes through Edge Functions only

-- ────────────────────────────────────────────────────────────
-- 5) coupons
-- ────────────────────────────────────────────────────────────
ALTER TABLE IF EXISTS public.coupons ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "coupons_select_all" ON public.coupons;
DROP POLICY IF EXISTS "coupons_admin_all" ON public.coupons;
DROP POLICY IF EXISTS "Service role full access" ON public.coupons;
DROP POLICY IF EXISTS "Anyone can read coupons" ON public.coupons;

-- All authenticated users can read active coupons (for validation)
CREATE POLICY "coupons_select_all" ON public.coupons
  FOR SELECT USING (true);

-- Admin can manage coupons (CRUD goes through Edge Functions, but admin reads need this)
CREATE POLICY "coupons_admin_all" ON public.coupons
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ────────────────────────────────────────────────────────────
-- 6) coupon_usages
-- ────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'coupon_usages') THEN
    EXECUTE 'ALTER TABLE public.coupon_usages ENABLE ROW LEVEL SECURITY';

    EXECUTE 'DROP POLICY IF EXISTS "cu_select_own" ON public.coupon_usages';
    EXECUTE 'DROP POLICY IF EXISTS "cu_insert_own" ON public.coupon_usages';
    EXECUTE 'DROP POLICY IF EXISTS "cu_admin_select" ON public.coupon_usages';

    EXECUTE 'CREATE POLICY "cu_select_own" ON public.coupon_usages FOR SELECT USING (auth.uid() = user_id)';
    EXECUTE 'CREATE POLICY "cu_insert_own" ON public.coupon_usages FOR INSERT WITH CHECK (auth.uid() = user_id)';
    EXECUTE 'CREATE POLICY "cu_admin_select" ON public.coupon_usages FOR SELECT USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = ''admin''))';
  END IF;
END $$;

-- ────────────────────────────────────────────────────────────
-- 7) notifications
-- ────────────────────────────────────────────────────────────
ALTER TABLE IF EXISTS public.notifications ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "notif_select_own" ON public.notifications;
DROP POLICY IF EXISTS "notif_update_own" ON public.notifications;
DROP POLICY IF EXISTS "notif_admin_select" ON public.notifications;
DROP POLICY IF EXISTS "Service role full access" ON public.notifications;
DROP POLICY IF EXISTS "Users can read own notifications" ON public.notifications;

CREATE POLICY "notif_select_own" ON public.notifications
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "notif_update_own" ON public.notifications
  FOR UPDATE USING (auth.uid() = user_id);

CREATE POLICY "notif_admin_select" ON public.notifications
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Notification inserts go through Edge Functions only

-- ────────────────────────────────────────────────────────────
-- 8) menu_items
-- ────────────────────────────────────────────────────────────
ALTER TABLE IF EXISTS public.menu_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "menu_items_select_all" ON public.menu_items;
DROP POLICY IF EXISTS "menu_items_merchant_manage" ON public.menu_items;
DROP POLICY IF EXISTS "menu_items_admin_manage" ON public.menu_items;
DROP POLICY IF EXISTS "Service role full access" ON public.menu_items;
DROP POLICY IF EXISTS "Anyone can read menu items" ON public.menu_items;

CREATE POLICY "menu_items_select_all" ON public.menu_items
  FOR SELECT USING (true);

CREATE POLICY "menu_items_merchant_manage" ON public.menu_items
  FOR ALL USING (auth.uid() = merchant_id)
  WITH CHECK (auth.uid() = merchant_id);

CREATE POLICY "menu_items_admin_manage" ON public.menu_items
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ────────────────────────────────────────────────────────────
-- 9) menu_options
-- ────────────────────────────────────────────────────────────
ALTER TABLE IF EXISTS public.menu_options ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "menu_options_select_all" ON public.menu_options;
DROP POLICY IF EXISTS "menu_options_admin_manage" ON public.menu_options;
DROP POLICY IF EXISTS "Service role full access" ON public.menu_options;

CREATE POLICY "menu_options_select_all" ON public.menu_options
  FOR SELECT USING (true);

CREATE POLICY "menu_options_admin_manage" ON public.menu_options
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ────────────────────────────────────────────────────────────
-- 10) menu_option_groups
-- ────────────────────────────────────────────────────────────
ALTER TABLE IF EXISTS public.menu_option_groups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "menu_option_groups_select_all" ON public.menu_option_groups;
DROP POLICY IF EXISTS "menu_option_groups_admin_manage" ON public.menu_option_groups;
DROP POLICY IF EXISTS "Service role full access" ON public.menu_option_groups;

CREATE POLICY "menu_option_groups_select_all" ON public.menu_option_groups
  FOR SELECT USING (true);

CREATE POLICY "menu_option_groups_admin_manage" ON public.menu_option_groups
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ────────────────────────────────────────────────────────────
-- 11) menu_item_option_links
-- ────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'menu_item_option_links') THEN
    EXECUTE 'ALTER TABLE public.menu_item_option_links ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "links_select_all" ON public.menu_item_option_links';
    EXECUTE 'DROP POLICY IF EXISTS "links_admin_manage" ON public.menu_item_option_links';
    EXECUTE 'CREATE POLICY "links_select_all" ON public.menu_item_option_links FOR SELECT USING (true)';
    EXECUTE 'CREATE POLICY "links_admin_manage" ON public.menu_item_option_links FOR ALL USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = ''admin''))';
  END IF;
END $$;

-- ────────────────────────────────────────────────────────────
-- 12) support_tickets
-- ────────────────────────────────────────────────────────────
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'support_tickets') THEN
    EXECUTE 'ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY';
    EXECUTE 'DROP POLICY IF EXISTS "tickets_select_own" ON public.support_tickets';
    EXECUTE 'DROP POLICY IF EXISTS "tickets_insert_own" ON public.support_tickets';
    EXECUTE 'DROP POLICY IF EXISTS "tickets_admin_all" ON public.support_tickets';
    EXECUTE 'DROP POLICY IF EXISTS "Service role full access" ON public.support_tickets';
    EXECUTE 'CREATE POLICY "tickets_select_own" ON public.support_tickets FOR SELECT USING (auth.uid() = user_id)';
    EXECUTE 'CREATE POLICY "tickets_insert_own" ON public.support_tickets FOR INSERT WITH CHECK (auth.uid() = user_id)';
    EXECUTE 'CREATE POLICY "tickets_admin_all" ON public.support_tickets FOR ALL USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = ''admin''))';
  END IF;
END $$;

-- ────────────────────────────────────────────────────────────
-- 13) Fix overly-permissive "Service role full access" policies
--     on banners and topup_requests (replace USING(true) with
--     proper role checks — service role bypasses RLS anyway)
-- ────────────────────────────────────────────────────────────
DROP POLICY IF EXISTS "Service role full access" ON public.banners;
DROP POLICY IF EXISTS "Service role can manage all topup requests" ON public.topup_requests;

-- topup_requests: admin can read all for the dashboard
CREATE POLICY "topup_admin_select" ON public.topup_requests
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- ────────────────────────────────────────────────────────────
-- 14) Ensure admin-web reads work: admin can SELECT on key tables
-- ────────────────────────────────────────────────────────────
-- (Already covered above via admin_select policies on each table)

-- Done.
