-- ============================================================
-- Comprehensive Row Level Security (RLS) Policies
-- Jedechai Delivery — All Tables
-- ============================================================
-- This migration ensures strict data isolation:
--   - Customers see only their own data
--   - Drivers see only their own data + assigned bookings
--   - Merchants see only their own data + their orders
--   - Admins have full access
-- ============================================================

-- ── Helper: Check if current user is admin ──
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean AS $$
  SELECT EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid()
      AND role = 'admin'
  );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ══════════════════════════════════════════
-- 1. PROFILES
-- ══════════════════════════════════════════
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Everyone can read profiles (needed for displaying names, avatars)
DROP POLICY IF EXISTS "profiles_select_all" ON public.profiles;
CREATE POLICY "profiles_select_all" ON public.profiles
  FOR SELECT USING (true);

-- Users can only update their own profile
DROP POLICY IF EXISTS "profiles_update_own" ON public.profiles;
CREATE POLICY "profiles_update_own" ON public.profiles
  FOR UPDATE USING (auth.uid() = id);

-- Admins can update any profile (for approval/suspension)
DROP POLICY IF EXISTS "profiles_update_admin" ON public.profiles;
CREATE POLICY "profiles_update_admin" ON public.profiles
  FOR UPDATE USING (public.is_admin());

-- Users can insert their own profile (on registration)
DROP POLICY IF EXISTS "profiles_insert_own" ON public.profiles;
CREATE POLICY "profiles_insert_own" ON public.profiles
  FOR INSERT WITH CHECK (auth.uid() = id);

-- ══════════════════════════════════════════
-- 2. BOOKINGS
-- ══════════════════════════════════════════
ALTER TABLE public.bookings ENABLE ROW LEVEL SECURITY;

-- Customers see their own bookings
DROP POLICY IF EXISTS "bookings_select_customer" ON public.bookings;
CREATE POLICY "bookings_select_customer" ON public.bookings
  FOR SELECT USING (auth.uid() = customer_id);

-- Drivers see bookings assigned to them OR pending bookings (for job matching)
DROP POLICY IF EXISTS "bookings_select_driver" ON public.bookings;
CREATE POLICY "bookings_select_driver" ON public.bookings
  FOR SELECT USING (
    auth.uid() = driver_id
    OR (
      driver_id IS NULL
      AND status IN ('pending', 'pending_merchant', 'preparing', 'ready_for_pickup')
    )
  );

-- Merchants see bookings for their store
DROP POLICY IF EXISTS "bookings_select_merchant" ON public.bookings;
CREATE POLICY "bookings_select_merchant" ON public.bookings
  FOR SELECT USING (auth.uid() = merchant_id);

-- Admins see all bookings
DROP POLICY IF EXISTS "bookings_select_admin" ON public.bookings;
CREATE POLICY "bookings_select_admin" ON public.bookings
  FOR SELECT USING (public.is_admin());

-- Customers can create bookings
DROP POLICY IF EXISTS "bookings_insert_customer" ON public.bookings;
CREATE POLICY "bookings_insert_customer" ON public.bookings
  FOR INSERT WITH CHECK (auth.uid() = customer_id);

-- Drivers can update bookings assigned to them (accept, status change)
DROP POLICY IF EXISTS "bookings_update_driver" ON public.bookings;
CREATE POLICY "bookings_update_driver" ON public.bookings
  FOR UPDATE USING (
    auth.uid() = driver_id
    OR (driver_id IS NULL AND status = 'pending')
  );

-- Customers can update their own bookings (cancel)
DROP POLICY IF EXISTS "bookings_update_customer" ON public.bookings;
CREATE POLICY "bookings_update_customer" ON public.bookings
  FOR UPDATE USING (auth.uid() = customer_id);

-- Merchants can update their bookings (confirm/reject order)
DROP POLICY IF EXISTS "bookings_update_merchant" ON public.bookings;
CREATE POLICY "bookings_update_merchant" ON public.bookings
  FOR UPDATE USING (auth.uid() = merchant_id);

-- Admins can update any booking
DROP POLICY IF EXISTS "bookings_update_admin" ON public.bookings;
CREATE POLICY "bookings_update_admin" ON public.bookings
  FOR UPDATE USING (public.is_admin());

-- ══════════════════════════════════════════
-- 3. BOOKING_ITEMS
-- ══════════════════════════════════════════
ALTER TABLE public.booking_items ENABLE ROW LEVEL SECURITY;

-- Users can see items for bookings they have access to
DROP POLICY IF EXISTS "booking_items_select" ON public.booking_items;
CREATE POLICY "booking_items_select" ON public.booking_items
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = booking_items.booking_id
        AND (
          b.customer_id = auth.uid()
          OR b.driver_id = auth.uid()
          OR b.merchant_id = auth.uid()
          OR public.is_admin()
        )
    )
  );

-- Customers can insert items for their own bookings
DROP POLICY IF EXISTS "booking_items_insert" ON public.booking_items;
CREATE POLICY "booking_items_insert" ON public.booking_items
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = booking_items.booking_id
        AND b.customer_id = auth.uid()
    )
  );

-- ══════════════════════════════════════════
-- 4. MENU_ITEMS
-- ══════════════════════════════════════════
ALTER TABLE public.menu_items ENABLE ROW LEVEL SECURITY;

-- Everyone can see menu items (for browsing)
DROP POLICY IF EXISTS "menu_items_select_all" ON public.menu_items;
CREATE POLICY "menu_items_select_all" ON public.menu_items
  FOR SELECT USING (true);

-- Merchants can manage their own menu items
DROP POLICY IF EXISTS "menu_items_insert_merchant" ON public.menu_items;
CREATE POLICY "menu_items_insert_merchant" ON public.menu_items
  FOR INSERT WITH CHECK (auth.uid() = merchant_id);

DROP POLICY IF EXISTS "menu_items_update_merchant" ON public.menu_items;
CREATE POLICY "menu_items_update_merchant" ON public.menu_items
  FOR UPDATE USING (auth.uid() = merchant_id);

DROP POLICY IF EXISTS "menu_items_delete_merchant" ON public.menu_items;
CREATE POLICY "menu_items_delete_merchant" ON public.menu_items
  FOR DELETE USING (auth.uid() = merchant_id);

-- Admins can manage all menu items
DROP POLICY IF EXISTS "menu_items_all_admin" ON public.menu_items;
CREATE POLICY "menu_items_all_admin" ON public.menu_items
  FOR ALL USING (public.is_admin());

-- ══════════════════════════════════════════
-- 5. REVIEWS
-- ══════════════════════════════════════════
ALTER TABLE public.reviews ENABLE ROW LEVEL SECURITY;

-- Everyone can see reviews (for rating display)
DROP POLICY IF EXISTS "reviews_select_all" ON public.reviews;
CREATE POLICY "reviews_select_all" ON public.reviews
  FOR SELECT USING (true);

-- Customers can create reviews for their own bookings
DROP POLICY IF EXISTS "reviews_insert_customer" ON public.reviews;
CREATE POLICY "reviews_insert_customer" ON public.reviews
  FOR INSERT WITH CHECK (auth.uid() = customer_id);

-- Customers can update their own reviews
DROP POLICY IF EXISTS "reviews_update_customer" ON public.reviews;
CREATE POLICY "reviews_update_customer" ON public.reviews
  FOR UPDATE USING (auth.uid() = customer_id);

-- ══════════════════════════════════════════
-- 6. WALLETS
-- ══════════════════════════════════════════
ALTER TABLE public.wallets ENABLE ROW LEVEL SECURITY;

-- Drivers see only their own wallet
DROP POLICY IF EXISTS "wallets_select_own" ON public.wallets;
CREATE POLICY "wallets_select_own" ON public.wallets
  FOR SELECT USING (auth.uid() = user_id);

-- Drivers can update their own wallet (topup)
DROP POLICY IF EXISTS "wallets_update_own" ON public.wallets;
CREATE POLICY "wallets_update_own" ON public.wallets
  FOR UPDATE USING (auth.uid() = user_id);

-- Admins see all wallets
DROP POLICY IF EXISTS "wallets_select_admin" ON public.wallets;
CREATE POLICY "wallets_select_admin" ON public.wallets
  FOR ALL USING (public.is_admin());

-- ══════════════════════════════════════════
-- 7. WALLET_TRANSACTIONS
-- ══════════════════════════════════════════
ALTER TABLE public.wallet_transactions ENABLE ROW LEVEL SECURITY;

-- Users see only their own transactions (via wallet_id)
DROP POLICY IF EXISTS "wallet_tx_select_own" ON public.wallet_transactions;
CREATE POLICY "wallet_tx_select_own" ON public.wallet_transactions
  FOR SELECT USING (
    wallet_id IN (
      SELECT id FROM public.wallets WHERE user_id = auth.uid()
    )
  );

-- System/admin can insert transactions
DROP POLICY IF EXISTS "wallet_tx_insert" ON public.wallet_transactions;
CREATE POLICY "wallet_tx_insert" ON public.wallet_transactions
  FOR INSERT WITH CHECK (
    wallet_id IN (
      SELECT id FROM public.wallets WHERE user_id = auth.uid()
    ) OR public.is_admin()
  );

-- Admins see all
DROP POLICY IF EXISTS "wallet_tx_admin" ON public.wallet_transactions;
CREATE POLICY "wallet_tx_admin" ON public.wallet_transactions
  FOR SELECT USING (public.is_admin());

-- ══════════════════════════════════════════
-- 8. DRIVER_LOCATIONS
-- ══════════════════════════════════════════
ALTER TABLE public.driver_locations ENABLE ROW LEVEL SECURITY;

-- Drivers can manage their own location
DROP POLICY IF EXISTS "driver_loc_own" ON public.driver_locations;
CREATE POLICY "driver_loc_own" ON public.driver_locations
  FOR ALL USING (auth.uid() = driver_id);

-- Customers can see driver locations (for tracking)
DROP POLICY IF EXISTS "driver_loc_select_customer" ON public.driver_locations;
CREATE POLICY "driver_loc_select_customer" ON public.driver_locations
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.driver_id = driver_locations.driver_id
        AND b.customer_id = auth.uid()
        AND b.status NOT IN ('completed', 'cancelled')
    )
  );

-- Admins see all
DROP POLICY IF EXISTS "driver_loc_admin" ON public.driver_locations;
CREATE POLICY "driver_loc_admin" ON public.driver_locations
  FOR SELECT USING (public.is_admin());

-- ══════════════════════════════════════════
-- 9. WITHDRAWAL_REQUESTS
-- ══════════════════════════════════════════
ALTER TABLE public.withdrawal_requests ENABLE ROW LEVEL SECURITY;

-- Users see only their own requests
DROP POLICY IF EXISTS "withdrawal_select_own" ON public.withdrawal_requests;
CREATE POLICY "withdrawal_select_own" ON public.withdrawal_requests
  FOR SELECT USING (auth.uid() = user_id);

-- Users can create their own requests
DROP POLICY IF EXISTS "withdrawal_insert_own" ON public.withdrawal_requests;
CREATE POLICY "withdrawal_insert_own" ON public.withdrawal_requests
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- Users can update their own pending requests (cancel)
DROP POLICY IF EXISTS "withdrawal_update_own" ON public.withdrawal_requests;
CREATE POLICY "withdrawal_update_own" ON public.withdrawal_requests
  FOR UPDATE USING (auth.uid() = user_id AND status = 'pending');

-- Admins can see and manage all
DROP POLICY IF EXISTS "withdrawal_admin" ON public.withdrawal_requests;
CREATE POLICY "withdrawal_admin" ON public.withdrawal_requests
  FOR ALL USING (public.is_admin());

-- ══════════════════════════════════════════
-- 10. SAVED_ADDRESSES (NEW)
-- ══════════════════════════════════════════
ALTER TABLE public.saved_addresses ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "saved_addr_own" ON public.saved_addresses;
CREATE POLICY "saved_addr_own" ON public.saved_addresses
  FOR ALL USING (auth.uid() = user_id);

-- ══════════════════════════════════════════
-- 11. CHAT_ROOMS (NEW)
-- ══════════════════════════════════════════
ALTER TABLE public.chat_rooms ENABLE ROW LEVEL SECURITY;

-- Participants can see their chat rooms
DROP POLICY IF EXISTS "chat_rooms_select" ON public.chat_rooms;
CREATE POLICY "chat_rooms_select" ON public.chat_rooms
  FOR SELECT USING (
    auth.uid() = customer_id
    OR auth.uid() = driver_id
    OR public.is_admin()
  );

-- Participants can create chat rooms
DROP POLICY IF EXISTS "chat_rooms_insert" ON public.chat_rooms;
CREATE POLICY "chat_rooms_insert" ON public.chat_rooms
  FOR INSERT WITH CHECK (
    auth.uid() = customer_id
    OR auth.uid() = driver_id
    OR public.is_admin()
  );

-- Participants can update (close) their chat rooms
DROP POLICY IF EXISTS "chat_rooms_update" ON public.chat_rooms;
CREATE POLICY "chat_rooms_update" ON public.chat_rooms
  FOR UPDATE USING (
    auth.uid() = customer_id
    OR auth.uid() = driver_id
    OR public.is_admin()
  );

-- ══════════════════════════════════════════
-- 12. CHAT_MESSAGES (NEW)
-- ══════════════════════════════════════════
ALTER TABLE public.chat_messages ENABLE ROW LEVEL SECURITY;

-- Realtime publications handled in:
-- - 20240210_create_missing_tables.sql (reviews, option_groups, options)
-- - 20240210_create_new_feature_tables.sql (chat_rooms, chat_messages)
-- Participants of the chat room can see messages
DROP POLICY IF EXISTS "chat_msg_select" ON public.chat_messages;
CREATE POLICY "chat_msg_select" ON public.chat_messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.chat_rooms cr
      WHERE cr.id = chat_messages.chat_room_id
        AND (
          cr.customer_id = auth.uid()
          OR cr.driver_id = auth.uid()
          OR public.is_admin()
        )
    )
  );

-- Participants can send messages
DROP POLICY IF EXISTS "chat_msg_insert" ON public.chat_messages;
CREATE POLICY "chat_msg_insert" ON public.chat_messages
  FOR INSERT WITH CHECK (auth.uid() = sender_id);

-- Participants can mark messages as read
DROP POLICY IF EXISTS "chat_msg_update" ON public.chat_messages;
CREATE POLICY "chat_msg_update" ON public.chat_messages
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.chat_rooms cr
      WHERE cr.id = chat_messages.chat_room_id
        AND (
          cr.customer_id = auth.uid()
          OR cr.driver_id = auth.uid()
          OR public.is_admin()
        )
    )
  );

-- ══════════════════════════════════════════
-- 13. COUPONS (NEW)
-- ══════════════════════════════════════════
ALTER TABLE public.coupons ENABLE ROW LEVEL SECURITY;

-- Everyone can see active coupons
DROP POLICY IF EXISTS "coupons_select_active" ON public.coupons;
CREATE POLICY "coupons_select_active" ON public.coupons
  FOR SELECT USING (is_active = true OR public.is_admin());

-- Only admins can manage coupons
DROP POLICY IF EXISTS "coupons_admin" ON public.coupons;
CREATE POLICY "coupons_admin" ON public.coupons
  FOR ALL USING (public.is_admin());

-- ══════════════════════════════════════════
-- 14. COUPON_USAGES (NEW)
-- ══════════════════════════════════════════
ALTER TABLE public.coupon_usages ENABLE ROW LEVEL SECURITY;

-- Users see their own usage
DROP POLICY IF EXISTS "coupon_usage_select_own" ON public.coupon_usages;
CREATE POLICY "coupon_usage_select_own" ON public.coupon_usages
  FOR SELECT USING (auth.uid() = user_id OR public.is_admin());

-- Users can record their own usage
DROP POLICY IF EXISTS "coupon_usage_insert" ON public.coupon_usages;
CREATE POLICY "coupon_usage_insert" ON public.coupon_usages
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ══════════════════════════════════════════
-- 15. SUPPORT_TICKETS (NEW)
-- ══════════════════════════════════════════
ALTER TABLE public.support_tickets ENABLE ROW LEVEL SECURITY;

-- Users see their own tickets
DROP POLICY IF EXISTS "tickets_select_own" ON public.support_tickets;
CREATE POLICY "tickets_select_own" ON public.support_tickets
  FOR SELECT USING (auth.uid() = user_id);

-- Admins see all tickets
DROP POLICY IF EXISTS "tickets_select_admin" ON public.support_tickets;
CREATE POLICY "tickets_select_admin" ON public.support_tickets
  FOR ALL USING (public.is_admin());

-- Users can create tickets
DROP POLICY IF EXISTS "tickets_insert_own" ON public.support_tickets;
CREATE POLICY "tickets_insert_own" ON public.support_tickets
  FOR INSERT WITH CHECK (auth.uid() = user_id);

-- ══════════════════════════════════════════
-- 16. SYSTEM_CONFIG
-- ══════════════════════════════════════════
ALTER TABLE public.system_config ENABLE ROW LEVEL SECURITY;

-- Everyone can read config (needed for fee calculation, version check)
DROP POLICY IF EXISTS "config_select_all" ON public.system_config;
CREATE POLICY "config_select_all" ON public.system_config
  FOR SELECT USING (true);

-- Only admins can modify config
DROP POLICY IF EXISTS "config_admin" ON public.system_config;
CREATE POLICY "config_admin" ON public.system_config
  FOR ALL USING (public.is_admin());

-- ══════════════════════════════════════════
-- 17. PARCEL_DETAILS
-- ══════════════════════════════════════════
ALTER TABLE public.parcel_details ENABLE ROW LEVEL SECURITY;

-- Same access as parent booking
DROP POLICY IF EXISTS "parcel_select" ON public.parcel_details;
CREATE POLICY "parcel_select" ON public.parcel_details
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = parcel_details.booking_id
        AND (
          b.customer_id = auth.uid()
          OR b.driver_id = auth.uid()
          OR public.is_admin()
        )
    )
  );

DROP POLICY IF EXISTS "parcel_insert" ON public.parcel_details;
CREATE POLICY "parcel_insert" ON public.parcel_details
  FOR INSERT WITH CHECK (
    EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = parcel_details.booking_id
        AND b.customer_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "parcel_update" ON public.parcel_details;
CREATE POLICY "parcel_update" ON public.parcel_details
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = parcel_details.booking_id
        AND (
          b.customer_id = auth.uid()
          OR b.driver_id = auth.uid()
          OR public.is_admin()
        )
    )
  );

-- ══════════════════════════════════════════
-- 18. OPTION_GROUPS & OPTIONS (Menu)
-- ══════════════════════════════════════════
ALTER TABLE public.option_groups ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "option_groups_select" ON public.option_groups;
CREATE POLICY "option_groups_select" ON public.option_groups
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "option_groups_manage" ON public.option_groups;
CREATE POLICY "option_groups_manage" ON public.option_groups
  FOR ALL USING (auth.uid() = merchant_id OR public.is_admin());

ALTER TABLE public.options ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "options_select" ON public.options;
CREATE POLICY "options_select" ON public.options
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "options_manage" ON public.options;
CREATE POLICY "options_manage" ON public.options
  FOR ALL USING (
    EXISTS (
      SELECT 1 FROM public.option_groups og
      WHERE og.id = options.option_group_id
        AND (og.merchant_id = auth.uid() OR public.is_admin())
    )
  );

-- ══════════════════════════════════════════
-- Coupon increment function (for CouponService)
-- ══════════════════════════════════════════
CREATE OR REPLACE FUNCTION public.increment_coupon_usage(coupon_id_param UUID)
RETURNS void AS $$
  UPDATE public.coupons
  SET used_count = used_count + 1
  WHERE id = coupon_id_param;
$$ LANGUAGE sql SECURITY DEFINER;

-- ══════════════════════════════════════════
-- NEW TABLE SCHEMAS (for new features)
-- ══════════════════════════════════════════

-- saved_addresses
CREATE TABLE IF NOT EXISTS public.saved_addresses (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  label TEXT NOT NULL DEFAULT 'other',
  name TEXT NOT NULL,
  address TEXT NOT NULL,
  latitude DOUBLE PRECISION NOT NULL,
  longitude DOUBLE PRECISION NOT NULL,
  note TEXT,
  icon_name TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- chat_rooms
CREATE TABLE IF NOT EXISTS public.chat_rooms (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  booking_id UUID REFERENCES public.bookings(id) ON DELETE SET NULL,
  customer_id UUID NOT NULL REFERENCES auth.users(id),
  driver_id UUID REFERENCES auth.users(id),
  room_type TEXT NOT NULL DEFAULT 'booking', -- 'booking' or 'support'
  is_active BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  closed_at TIMESTAMPTZ
);

-- chat_messages
CREATE TABLE IF NOT EXISTS public.chat_messages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  chat_room_id UUID NOT NULL REFERENCES public.chat_rooms(id) ON DELETE CASCADE,
  sender_id UUID NOT NULL REFERENCES auth.users(id),
  sender_role TEXT NOT NULL DEFAULT 'customer',
  message TEXT NOT NULL,
  image_url TEXT,
  is_read BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- coupons
CREATE TABLE IF NOT EXISTS public.coupons (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  code TEXT NOT NULL UNIQUE,
  name TEXT NOT NULL,
  description TEXT,
  discount_type TEXT NOT NULL, -- 'percentage', 'fixed', 'free_delivery'
  discount_value DOUBLE PRECISION NOT NULL,
  min_order_amount DOUBLE PRECISION,
  max_discount_amount DOUBLE PRECISION,
  service_type TEXT, -- null=all, 'food', 'ride', 'parcel'
  merchant_id UUID REFERENCES auth.users(id),
  usage_limit INT DEFAULT 0,
  used_count INT DEFAULT 0,
  per_user_limit INT DEFAULT 1,
  is_active BOOLEAN DEFAULT true,
  start_date TIMESTAMPTZ NOT NULL,
  end_date TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- coupon_usages
CREATE TABLE IF NOT EXISTS public.coupon_usages (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  coupon_id UUID NOT NULL REFERENCES public.coupons(id),
  user_id UUID NOT NULL REFERENCES auth.users(id),
  booking_id UUID REFERENCES public.bookings(id),
  discount_amount DOUBLE PRECISION NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now()
);

-- support_tickets
CREATE TABLE IF NOT EXISTS public.support_tickets (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  booking_id UUID REFERENCES public.bookings(id),
  category TEXT NOT NULL DEFAULT 'other',
  subject TEXT NOT NULL,
  description TEXT NOT NULL,
  status TEXT NOT NULL DEFAULT 'open', -- 'open', 'in_progress', 'resolved', 'closed'
  priority TEXT NOT NULL DEFAULT 'medium',
  assigned_admin_id UUID REFERENCES auth.users(id),
  resolution TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now(),
  resolved_at TIMESTAMPTZ
);

-- Indexes for performance
CREATE INDEX IF NOT EXISTS idx_saved_addresses_user ON public.saved_addresses(user_id);
CREATE INDEX IF NOT EXISTS idx_chat_rooms_booking ON public.chat_rooms(booking_id);
CREATE INDEX IF NOT EXISTS idx_chat_messages_room ON public.chat_messages(chat_room_id);
CREATE INDEX IF NOT EXISTS idx_coupons_code ON public.coupons(code);
CREATE INDEX IF NOT EXISTS idx_coupon_usages_coupon ON public.coupon_usages(coupon_id, user_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_user ON public.support_tickets(user_id);
CREATE INDEX IF NOT EXISTS idx_support_tickets_status ON public.support_tickets(status);

-- realtime for chat_messages handled in 20240210_create_new_feature_tables.sql
