-- ============================================
-- Migration: Top-up Requests + PromptPay Config
-- ============================================

-- 1. เพิ่มคอลัมน์ promptpay_number ใน system_config
ALTER TABLE system_config ADD COLUMN IF NOT EXISTS promptpay_number TEXT;

-- 2. เพิ่มคอลัมน์ approval_status และ rejection_reason ใน profiles (ถ้ายังไม่มี)
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS approval_status TEXT DEFAULT 'pending';
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS approved_at TIMESTAMPTZ;

-- 3. สร้างตาราง topup_requests
CREATE TABLE IF NOT EXISTS topup_requests (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
  amount NUMERIC NOT NULL DEFAULT 0,
  status TEXT NOT NULL DEFAULT 'pending', -- pending, completed, rejected
  admin_note TEXT,
  processed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. RLS policies สำหรับ topup_requests
ALTER TABLE topup_requests ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own topup requests"
  ON topup_requests FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own topup requests"
  ON topup_requests FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Service role can manage all topup requests"
  ON topup_requests FOR ALL
  USING (true)
  WITH CHECK (true);

-- 5. Enable realtime
ALTER PUBLICATION supabase_realtime ADD TABLE topup_requests;

-- 6. Index
CREATE INDEX IF NOT EXISTS idx_topup_requests_user_id ON topup_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_topup_requests_status ON topup_requests(status);
