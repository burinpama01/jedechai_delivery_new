-- Migration: ระบบ Admin Back-office
-- วันที่: 2024-02-02
-- คำอธิบาย: เพิ่ม admin role, ระบบอนุมัติคนขับ/ร้านค้า, ระบบถอนเงิน

-- ========================================
-- 1. เพิ่มคอลัมน์ approval ในตาราง profiles
-- ========================================
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS approval_status TEXT DEFAULT 'pending'
    CHECK (approval_status IN ('pending', 'approved', 'rejected', 'suspended'));
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP WITH TIME ZONE;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS approved_by UUID REFERENCES auth.users(id);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS rejection_reason TEXT;

-- เพิ่มคอลัมน์เอกสารคนขับ
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS driver_license_url TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS vehicle_registration_url TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS vehicle_type TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS vehicle_plate TEXT;

-- เพิ่มคอลัมน์เอกสารร้านค้า
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS shop_license_url TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS shop_photo_url TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS shop_address TEXT;

-- เพิ่มคอลัมน์ bank info สำหรับถอนเงิน
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS bank_name TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS bank_account_number TEXT;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS bank_account_name TEXT;

-- ========================================
-- 2. ตาราง Withdrawal Requests (คำขอถอนเงิน)
-- ========================================
CREATE TABLE IF NOT EXISTS withdrawal_requests (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    amount NUMERIC(10,2) NOT NULL CHECK (amount > 0),
    
    -- ข้อมูลบัญชีธนาคาร (snapshot ตอนขอถอน)
    bank_name TEXT NOT NULL,
    bank_account_number TEXT NOT NULL,
    bank_account_name TEXT NOT NULL,
    
    -- สถานะ
    status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected', 'completed')),
    
    -- Admin ที่ดำเนินการ
    processed_by UUID REFERENCES auth.users(id),
    processed_at TIMESTAMP WITH TIME ZONE,
    admin_note TEXT,
    transfer_slip_url TEXT,  -- รูปสลิปโอนเงิน
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- ========================================
-- 3. ตาราง Admin Actions Log (บันทึกการกระทำของ Admin)
-- ========================================
CREATE TABLE IF NOT EXISTS admin_actions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    admin_id UUID NOT NULL REFERENCES auth.users(id),
    action_type TEXT NOT NULL,  -- 'approve_driver', 'reject_driver', 'approve_merchant', 'approve_withdrawal', etc.
    target_user_id UUID REFERENCES auth.users(id),
    target_entity_id UUID,     -- ID ของ entity ที่ถูกดำเนินการ (เช่น withdrawal_request id)
    details JSONB DEFAULT '{}',
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL
);

-- ========================================
-- 4. Indexes
-- ========================================
CREATE INDEX IF NOT EXISTS idx_profiles_approval_status ON profiles(approval_status);
CREATE INDEX IF NOT EXISTS idx_profiles_role ON profiles(role);
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_user_id ON withdrawal_requests(user_id);
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_status ON withdrawal_requests(status);
CREATE INDEX IF NOT EXISTS idx_withdrawal_requests_created_at ON withdrawal_requests(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_admin_actions_admin_id ON admin_actions(admin_id);
CREATE INDEX IF NOT EXISTS idx_admin_actions_created_at ON admin_actions(created_at DESC);

-- ========================================
-- 5. Triggers
-- ========================================
CREATE OR REPLACE FUNCTION update_withdrawal_requests_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_withdrawal_requests_updated_at ON withdrawal_requests;
CREATE TRIGGER trigger_update_withdrawal_requests_updated_at
    BEFORE UPDATE ON withdrawal_requests
    FOR EACH ROW
    EXECUTE FUNCTION update_withdrawal_requests_updated_at();

-- ========================================
-- 6. RLS (Row Level Security)
-- ========================================
ALTER TABLE withdrawal_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_actions ENABLE ROW LEVEL SECURITY;

-- withdrawal_requests: ผู้ใช้ดูของตัวเอง
CREATE POLICY "Users can view own withdrawal requests" ON withdrawal_requests
    FOR SELECT USING (auth.uid() = user_id);

-- withdrawal_requests: ผู้ใช้สร้างของตัวเอง
CREATE POLICY "Users can insert own withdrawal requests" ON withdrawal_requests
    FOR INSERT WITH CHECK (auth.uid() = user_id);

-- withdrawal_requests: Admin ดูทั้งหมด
CREATE POLICY "Admins can view all withdrawal requests" ON withdrawal_requests
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- withdrawal_requests: Admin อัปเดตทั้งหมด
CREATE POLICY "Admins can update all withdrawal requests" ON withdrawal_requests
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- admin_actions: Admin ดูทั้งหมด
CREATE POLICY "Admins can view all admin actions" ON admin_actions
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- admin_actions: Admin สร้าง
CREATE POLICY "Admins can insert admin actions" ON admin_actions
    FOR INSERT WITH CHECK (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- profiles: Admin ดูทุกคน
CREATE POLICY "Admins can view all profiles" ON profiles
    FOR SELECT USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- profiles: Admin อัปเดตทุกคน (อนุมัติ/ปฏิเสธ)
CREATE POLICY "Admins can update all profiles" ON profiles
    FOR UPDATE USING (
        EXISTS (SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'admin')
    );

-- ========================================
-- 7. Grant permissions
-- ========================================
GRANT ALL ON withdrawal_requests TO authenticated;
GRANT ALL ON admin_actions TO authenticated;

-- ========================================
-- 8. อัปเดต bookings status constraint เพิ่ม driver_assigned
-- ========================================
ALTER TABLE bookings DROP CONSTRAINT IF EXISTS bookings_status_check;
ALTER TABLE bookings ADD CONSTRAINT bookings_status_check 
CHECK (status IN (
    'pending', 'searching', 'confirmed', 'accepted',
    'driver_assigned', 'driver_accepted',
    'in_progress', 'in_transit',
    'traveling_to_merchant', 'arrived_at_merchant', 'picking_up_order',
    'preparing', 'ready_for_pickup',
    'completed', 'cancelled'
));

-- ========================================
-- 9. Comments
-- ========================================
COMMENT ON TABLE withdrawal_requests IS 'คำขอถอนเงินจากคนขับ/ร้านค้า';
COMMENT ON TABLE admin_actions IS 'บันทึกการกระทำของ Admin ทั้งหมด';
COMMENT ON COLUMN profiles.approval_status IS 'สถานะการอนุมัติ: pending, approved, rejected, suspended';
