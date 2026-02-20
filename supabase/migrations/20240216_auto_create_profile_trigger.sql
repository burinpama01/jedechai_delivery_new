-- ============================================
-- Migration: Auto-create profile on auth.users insert
-- ============================================
-- ปัญหา: เมื่อสมัครสมาชิกแล้วเลือกประเภทบัญชีเป็นคนขับ
-- profile ไม่ถูกสร้างเพราะ RLS บล็อก INSERT (ไม่มี session หลัง signUp)
-- แก้ไข: สร้าง trigger บน auth.users ที่ทำงานด้วย SECURITY DEFINER
-- ============================================
-- profiles table columns (จาก schema จริง):
-- id, full_name, phone_number, role, created_at, updated_at,
-- vehicle_model, license_plate, is_online, shop_status, address,
-- latitude, longitude, avatar_url, fcm_token, approval_status,
-- approved_at, approved_by, rejection_reason, driver_license_url,
-- vehicle_registration_url, vehicle_type, vehicle_plate,
-- shop_license_url, shop_photo_url, shop_address,
-- bank_name, bank_account_number, bank_account_name,
-- admin_permissions, admin_level
-- หมายเหตุ: ไม่มี column email, shop_name, shop_phone
-- ============================================

-- 1. สร้าง function สำหรับสร้าง profile อัตโนมัติ
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
  v_role TEXT;
  v_full_name TEXT;
  v_phone TEXT;
  v_vehicle_type TEXT;
  v_license_plate TEXT;
  v_shop_address TEXT;
  v_approval_status TEXT;
BEGIN
  -- ดึงข้อมูลจาก user metadata ที่ส่งมาตอน signUp
  v_role := COALESCE(NEW.raw_user_meta_data->>'role', 'customer');
  v_full_name := COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1));
  v_phone := COALESCE(NEW.raw_user_meta_data->>'phone_number', '');
  v_vehicle_type := COALESCE(NEW.raw_user_meta_data->>'vehicle_type', '');
  v_license_plate := COALESCE(NEW.raw_user_meta_data->>'license_plate', '');
  v_shop_address := COALESCE(NEW.raw_user_meta_data->>'shop_address', '');

  -- กำหนด approval_status ตาม role
  IF v_role IN ('driver', 'merchant') THEN
    v_approval_status := 'pending';
  ELSE
    v_approval_status := 'approved';
  END IF;

  -- สร้าง profile (ใช้ ON CONFLICT เพื่อป้องกัน duplicate)
  -- ใช้เฉพาะ column ที่มีอยู่จริงใน profiles table
  INSERT INTO public.profiles (
    id, role, full_name, phone_number,
    vehicle_type, license_plate, shop_address,
    approval_status, created_at, updated_at
  ) VALUES (
    NEW.id, v_role, v_full_name, v_phone,
    v_vehicle_type, v_license_plate, v_shop_address,
    v_approval_status, NOW(), NOW()
  )
  ON CONFLICT (id) DO UPDATE SET
    role = EXCLUDED.role,
    full_name = EXCLUDED.full_name,
    phone_number = EXCLUDED.phone_number,
    vehicle_type = EXCLUDED.vehicle_type,
    license_plate = EXCLUDED.license_plate,
    shop_address = EXCLUDED.shop_address,
    approval_status = EXCLUDED.approval_status,
    updated_at = NOW();

  RAISE NOTICE 'Profile created for user % with role %', NEW.id, v_role;
  RETURN NEW;
END;
$$;

-- 2. สร้าง trigger บน auth.users
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_new_user();

-- 3. เพิ่ม RLS policy ให้ users สามารถ upsert profile ตัวเอง (สำหรับ fallback จาก app)
-- ถ้ายังไม่มี policy สำหรับ INSERT
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'profiles' 
    AND policyname = 'profiles_insert_own'
  ) THEN
    CREATE POLICY "profiles_insert_own" ON public.profiles
      FOR INSERT WITH CHECK (auth.uid() = id);
  END IF;
END $$;
