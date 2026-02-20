-- ============================================================
-- Create Missing Tables for New Features
-- ============================================================
-- This migration creates tables that are referenced in the RLS policies
-- but don't exist in the current database.

-- ── REVIEWS TABLE ──
CREATE TABLE IF NOT EXISTS public.reviews (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  booking_id UUID NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  customer_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  driver_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  merchant_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  rating DOUBLE PRECISION NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes for reviews
CREATE INDEX IF NOT EXISTS idx_reviews_booking_id ON public.reviews(booking_id);
CREATE INDEX IF NOT EXISTS idx_reviews_customer_id ON public.reviews(customer_id);
CREATE INDEX IF NOT EXISTS idx_reviews_driver_id ON public.reviews(driver_id);
CREATE INDEX IF NOT EXISTS idx_reviews_merchant_id ON public.reviews(merchant_id);

-- Enable realtime for reviews
ALTER PUBLICATION supabase_realtime ADD TABLE public.reviews;

-- WALLET_TRANSACTIONS TABLE (already exists in 20240130_setup_pricing_wallet_v2.sql)
-- No need to create - just ensure it exists with proper structure

-- ── OPTION_GROUPS TABLE (if not exists)
CREATE TABLE IF NOT EXISTS public.option_groups (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  merchant_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  is_required BOOLEAN DEFAULT false,
  min_selections INT DEFAULT 1,
  max_selections INT DEFAULT 1,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes for option_groups
CREATE INDEX IF NOT EXISTS idx_option_groups_merchant_id ON public.option_groups(merchant_id);

-- ── OPTIONS TABLE (if not exists)
CREATE TABLE IF NOT EXISTS public.options (
  id UUID DEFAULT gen_random_uuid() PRIMARY KEY,
  option_group_id UUID NOT NULL REFERENCES public.option_groups(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  price DOUBLE PRECISION DEFAULT 0,
  is_available BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Indexes for options
CREATE INDEX IF NOT EXISTS idx_options_option_group_id ON public.options(option_group_id);

-- Enable realtime for option_groups and options
ALTER PUBLICATION supabase_realtime ADD TABLE public.option_groups;
ALTER PUBLICATION supabase_realtime ADD TABLE public.options;
