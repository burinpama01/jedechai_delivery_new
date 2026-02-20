-- Migration: แก้ไข infinite recursion ใน RLS policy ของ profiles
-- วันที่: 2024-02-03
-- คำอธิบาย: RLS policy บน profiles ที่ query profiles เอง ทำให้เกิด infinite recursion
--           แก้โดยใช้ SECURITY DEFINER function ที่ bypass RLS เพื่อตรวจสอบ role

-- ========================================
-- 1. สร้าง SECURITY DEFINER function สำหรับตรวจสอบ admin role
--    function นี้ bypass RLS เพราะเป็น SECURITY DEFINER
-- ========================================
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS BOOLEAN AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.profiles
        WHERE id = auth.uid() AND role = 'admin'
    );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ========================================
-- 2. สร้าง function สำหรับดึง role ของ user ปัจจุบัน (bypass RLS)
-- ========================================
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS TEXT AS $$
DECLARE
    user_role TEXT;
BEGIN
    SELECT role INTO user_role FROM public.profiles WHERE id = auth.uid();
    RETURN user_role;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER STABLE;

-- ========================================
-- 3. ลบ RLS policies เดิมที่มีปัญหา infinite recursion บน profiles
-- ========================================
DROP POLICY IF EXISTS "Admins can view all profiles" ON profiles;
DROP POLICY IF EXISTS "Admins can update all profiles" ON profiles;

-- ========================================
-- 4. สร้าง RLS policies ใหม่บน profiles โดยใช้ is_admin() function
-- ========================================

-- ผู้ใช้ดูโปรไฟล์ตัวเอง
DROP POLICY IF EXISTS "Users can view own profile" ON profiles;
CREATE POLICY "Users can view own profile" ON profiles
    FOR SELECT USING (auth.uid() = id);

-- ผู้ใช้อัปเดตโปรไฟล์ตัวเอง
DROP POLICY IF EXISTS "Users can update own profile" ON profiles;
CREATE POLICY "Users can update own profile" ON profiles
    FOR UPDATE USING (auth.uid() = id);

-- Admin ดูโปรไฟล์ทุกคน (ใช้ is_admin() แทน subquery)
CREATE POLICY "Admins can view all profiles" ON profiles
    FOR SELECT USING (public.is_admin());

-- Admin อัปเดตโปรไฟล์ทุกคน (ใช้ is_admin() แทน subquery)
CREATE POLICY "Admins can update all profiles" ON profiles
    FOR UPDATE USING (public.is_admin());

-- Merchant ดูโปรไฟล์ตัวเอง (สำหรับ food service — ลูกค้าต้องเห็นร้านค้า)
DROP POLICY IF EXISTS "Anyone can view merchant profiles" ON profiles;
CREATE POLICY "Anyone can view merchant profiles" ON profiles
    FOR SELECT USING (role = 'merchant');

-- ลูกค้าต้องเห็นโปรไฟล์คนขับ (เมื่อมี booking)
DROP POLICY IF EXISTS "Anyone can view driver profiles" ON profiles;
CREATE POLICY "Anyone can view driver profiles" ON profiles
    FOR SELECT USING (role = 'driver');

-- ========================================
-- 5. แก้ไข RLS policies บน withdrawal_requests ที่ query profiles
-- ========================================
DROP POLICY IF EXISTS "Admins can view all withdrawal requests" ON withdrawal_requests;
CREATE POLICY "Admins can view all withdrawal requests" ON withdrawal_requests
    FOR SELECT USING (public.is_admin());

DROP POLICY IF EXISTS "Admins can update all withdrawal requests" ON withdrawal_requests;
CREATE POLICY "Admins can update all withdrawal requests" ON withdrawal_requests
    FOR UPDATE USING (public.is_admin());

-- ========================================
-- 6. แก้ไข RLS policies บน admin_actions ที่ query profiles
-- ========================================
DROP POLICY IF EXISTS "Admins can view all admin actions" ON admin_actions;
CREATE POLICY "Admins can view all admin actions" ON admin_actions
    FOR SELECT USING (public.is_admin());

DROP POLICY IF EXISTS "Admins can insert admin actions" ON admin_actions;
CREATE POLICY "Admins can insert admin actions" ON admin_actions
    FOR INSERT WITH CHECK (public.is_admin());

-- ========================================
-- 7. ตรวจสอบว่า profiles มี RLS เปิดอยู่
-- ========================================
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

-- ========================================
-- 8. Grant execute permissions
-- ========================================
GRANT EXECUTE ON FUNCTION public.is_admin() TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_my_role() TO authenticated;
