-- 1) Create ENUMs for new coupon types and referral status if they don't exist
DO $$ BEGIN
    CREATE TYPE public.coupon_discount_base AS ENUM ('subtotal', 'delivery_fee');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE public.coupon_distribution_type AS ENUM ('code_only', 'claimable', 'auto_grant');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE public.user_coupon_status AS ENUM ('claimed', 'used', 'expired', 'revoked');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
    CREATE TYPE public.referral_status AS ENUM ('pending', 'qualified', 'revoked');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- 2) Update existing `coupons` table to support new requirements
ALTER TABLE IF EXISTS public.coupons
  -- Support for stacking matrix and financial routing
  ADD COLUMN IF NOT EXISTS discount_base public.coupon_discount_base DEFAULT 'subtotal',
  ADD COLUMN IF NOT EXISTS max_discount_amount numeric,
  ADD COLUMN IF NOT EXISTS stacking_group text,
  ADD COLUMN IF NOT EXISTS funding_source text DEFAULT 'platform', -- platform, merchant, driver, split
  ADD COLUMN IF NOT EXISTS driver_compensation_policy jsonb,
  -- Support for Claim & Wallet system
  ADD COLUMN IF NOT EXISTS distribution_type public.coupon_distribution_type DEFAULT 'code_only',
  ADD COLUMN IF NOT EXISTS claim_limit integer,
  ADD COLUMN IF NOT EXISTS claim_limit_per_user integer DEFAULT 1,
  ADD COLUMN IF NOT EXISTS current_claims integer DEFAULT 0;

-- Ensure constraints on coupons
DO $$ BEGIN
  ALTER TABLE public.coupons ADD CONSTRAINT check_current_claims_limit CHECK (current_claims <= COALESCE(claim_limit, 2147483647));
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- 3) Create `user_coupons` table for Coupon Wallet
CREATE TABLE IF NOT EXISTS public.user_coupons (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  coupon_id uuid NOT NULL REFERENCES public.coupons(id) ON DELETE CASCADE,
  status public.user_coupon_status NOT NULL DEFAULT 'claimed',
  claimed_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz,
  used_booking_id uuid REFERENCES public.bookings(id) ON DELETE SET NULL,
  used_at timestamptz,
  
  -- Prevent double claim on single use coupons (enforced by RPC, but this prevents duplicates if limit is 1)
  -- If claim_limit_per_user > 1, we rely on the RPC check, not a unique constraint here.
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_user_coupons_user_id ON public.user_coupons(user_id);
CREATE INDEX IF NOT EXISTS idx_user_coupons_coupon_id ON public.user_coupons(coupon_id);
CREATE INDEX IF NOT EXISTS idx_user_coupons_status ON public.user_coupons(status);

-- 4) Create Referral tables
-- 4.1) referral_codes: Stores the unique referral code for each user
CREATE TABLE IF NOT EXISTS public.referral_codes (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  code text NOT NULL UNIQUE,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_referral_codes_code ON public.referral_codes(code);

-- 4.2) referrals: Tracks the relationship between referrer and referee
CREATE TABLE IF NOT EXISTS public.referrals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referrer_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  referee_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE, -- One user can only be referred once
  referral_code_used text NOT NULL,
  status public.referral_status NOT NULL DEFAULT 'pending',
  qualified_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT check_not_self_referral CHECK (referrer_id != referee_id)
);
CREATE INDEX IF NOT EXISTS idx_referrals_referrer_id ON public.referrals(referrer_id);

-- 4.3) referral_rewards: Tracks the rewards granted from referrals
CREATE TABLE IF NOT EXISTS public.referral_rewards (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  referral_id uuid NOT NULL REFERENCES public.referrals(id) ON DELETE CASCADE,
  beneficiary_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  reward_type text NOT NULL, -- 'coupon', 'credit'
  amount numeric,
  coupon_id uuid REFERENCES public.coupons(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'granted', -- granted, revoked
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_referral_rewards_referral_id ON public.referral_rewards(referral_id);
CREATE INDEX IF NOT EXISTS idx_referral_rewards_beneficiary ON public.referral_rewards(beneficiary_user_id);

-- 5) Create Audit Log for Admin actions (if not exists)
CREATE TABLE IF NOT EXISTS public.admin_audit_logs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  admin_user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  action_type text NOT NULL,
  target_type text NOT NULL, -- 'coupon', 'referral', 'reward', 'user_coupon'
  target_id uuid,
  details jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_target ON public.admin_audit_logs(target_type, target_id);
CREATE INDEX IF NOT EXISTS idx_admin_audit_logs_admin ON public.admin_audit_logs(admin_user_id);

-- 6) RLS Policies

-- Enable RLS on new tables
ALTER TABLE IF EXISTS public.user_coupons ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.referral_codes ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.referral_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE IF EXISTS public.admin_audit_logs ENABLE ROW LEVEL SECURITY;

-- 6.1) user_coupons
CREATE POLICY "Users can view own coupons" ON public.user_coupons
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Admin can do all on user_coupons" ON public.user_coupons
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- 6.2) referral_codes
CREATE POLICY "Users can view own referral code" ON public.referral_codes
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Anyone can view referral codes (for validation)" ON public.referral_codes
  FOR SELECT USING (true); -- Needed during signup validation

CREATE POLICY "Admin can do all on referral_codes" ON public.referral_codes
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- 6.3) referrals
CREATE POLICY "Users can view own referrals (as referrer or referee)" ON public.referrals
  FOR SELECT USING (auth.uid() = referrer_id OR auth.uid() = referee_id);

CREATE POLICY "Admin can do all on referrals" ON public.referrals
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- 6.4) referral_rewards
CREATE POLICY "Users can view own rewards" ON public.referral_rewards
  FOR SELECT USING (auth.uid() = beneficiary_user_id);

CREATE POLICY "Admin can do all on referral_rewards" ON public.referral_rewards
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- 6.5) admin_audit_logs
CREATE POLICY "Admin can view audit logs" ON public.admin_audit_logs
  FOR SELECT USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Note: Insertions to these tables will mainly be handled via secure RPCs / Edge Functions 
-- to ensure atomicity, so we don't necessarily need generic INSERT policies for users.