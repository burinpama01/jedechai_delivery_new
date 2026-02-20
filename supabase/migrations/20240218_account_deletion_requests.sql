-- ตาราง account_deletion_requests สำหรับจัดการคำขอลบบัญชี
CREATE TABLE IF NOT EXISTS public.account_deletion_requests (
  id BIGSERIAL PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  user_email TEXT,
  user_role TEXT,
  user_name TEXT,
  reason TEXT,
  status TEXT NOT NULL DEFAULT 'pending', -- pending, approved, rejected
  requested_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  reviewed_at TIMESTAMPTZ,
  reviewed_by UUID,
  rejection_reason TEXT,
  profile_backup JSONB -- เก็บข้อมูลโปรไฟล์ก่อนลบ
);

-- เพิ่มคอลัมน์ deletion_status ใน profiles
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS deletion_status TEXT DEFAULT NULL;
-- NULL = ปกติ, 'pending' = รอลบ, 'approved' = อนุมัติแล้ว

-- RLS policies
ALTER TABLE public.account_deletion_requests ENABLE ROW LEVEL SECURITY;

-- ผู้ใช้เห็นเฉพาะคำขอของตัวเอง
DROP POLICY IF EXISTS "Users can view own deletion requests" ON public.account_deletion_requests;
CREATE POLICY "Users can view own deletion requests"
  ON public.account_deletion_requests FOR SELECT
  USING (auth.uid() = user_id);

-- ผู้ใช้สร้างคำขอลบของตัวเอง
DROP POLICY IF EXISTS "Users can create own deletion requests" ON public.account_deletion_requests;
CREATE POLICY "Users can create own deletion requests"
  ON public.account_deletion_requests FOR INSERT
  WITH CHECK (auth.uid() = user_id);

-- แอดมินจัดการได้ทั้งหมด
DROP POLICY IF EXISTS "Admin can manage all deletion requests" ON public.account_deletion_requests;
CREATE POLICY "Admin can manage all deletion requests"
  ON public.account_deletion_requests FOR ALL
  USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- Index
CREATE INDEX IF NOT EXISTS idx_deletion_requests_status ON public.account_deletion_requests(status);
CREATE INDEX IF NOT EXISTS idx_deletion_requests_user ON public.account_deletion_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_profiles_deletion_status ON public.profiles(deletion_status) WHERE deletion_status IS NOT NULL;
