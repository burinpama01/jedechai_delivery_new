-- ═══════════════════════════════════════════════════════════════
-- ปิดช่องโหว่ยกระดับสิทธิ์ผ่านตาราง profiles (ISSUE-20260919-RLS)
--
-- ก่อนแก้:
--  1) RLS UPDATE ของเจ้าของ row เปิดทุกคอลัมน์ → ผู้ใช้ตั้ง role='admin' / approval_status='approved' เองได้
--  2) handle_new_user เชื่อ raw_user_meta_data->>'role' → สมัครด้วย role 'admin' ได้ทันที (approved)
--
-- แก้:
--  - handle_new_user: รับเฉพาะ customer / driver / merchant (อื่น ๆ → customer)
--  - trigger guard_profile_privileged_columns (BEFORE INSERT/UPDATE, SECURITY INVOKER)
--    บังคับเฉพาะคำสั่งที่มาจาก client ตรง (current_user = authenticated/anon) และไม่ใช่แอดมิน
--    · INSERT: role ต้องเป็น customer/driver/merchant, approval_status ตาม role, คอลัมน์สิทธิ์/เงินเป็นค่าเริ่มต้น
--    · UPDATE: เปลี่ยน role ได้เฉพาะ customer → driver/merchant (สถานะกลับเป็น pending) อื่น ๆ = error
--              คอลัมน์สิทธิ์/เงิน/สถิติ ถูกคืนค่าเดิมเงียบ ๆ (ไม่ทำให้ client upsert เดิมพัง)
--    · SECURITY DEFINER RPC / trigger / service role / admin-actions ไม่ถูกกระทบ (current_user ไม่ใช่ authenticated)
-- ═══════════════════════════════════════════════════════════════

BEGIN;

-- 1) handle_new_user: ไม่เชื่อ role จาก metadata เกินกว่าที่สมัครได้ ------------
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $function$
DECLARE
  v_role TEXT;
  v_full_name TEXT;
  v_phone TEXT;
  v_vehicle_type TEXT;
  v_license_plate TEXT;
  v_shop_address TEXT;
  v_approval_status TEXT;
BEGIN
  -- ดึงข้อมูลจาก user metadata ที่ส่งมาตอน signUp (ผู้ใช้กำหนดเองได้ → ต้อง whitelist)
  v_role := COALESCE(NEW.raw_user_meta_data->>'role', 'customer');
  IF v_role NOT IN ('customer', 'driver', 'merchant') THEN
    v_role := 'customer';
  END IF;
  v_full_name := COALESCE(NEW.raw_user_meta_data->>'full_name', split_part(NEW.email, '@', 1));
  v_phone := COALESCE(NEW.raw_user_meta_data->>'phone_number', '');
  v_vehicle_type := COALESCE(NEW.raw_user_meta_data->>'vehicle_type', '');
  v_license_plate := COALESCE(NEW.raw_user_meta_data->>'license_plate', '');
  v_shop_address := COALESCE(NEW.raw_user_meta_data->>'shop_address', '');

  IF v_role IN ('driver', 'merchant') THEN
    v_approval_status := 'pending';
  ELSE
    v_approval_status := 'approved';
  END IF;

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

  RETURN NEW;
END;
$function$;

-- 2) Guard trigger ----------------------------------------------------------
CREATE OR REPLACE FUNCTION public.guard_profile_privileged_columns()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  -- บังคับเฉพาะคำสั่งจาก client ผ่าน PostgREST (ไม่ใช่ SECURITY DEFINER / service role / postgres)
  IF current_user NOT IN ('authenticated', 'anon') THEN
    RETURN NEW;
  END IF;

  IF public.is_admin() THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    IF NEW.role IS NULL OR NEW.role NOT IN ('customer', 'driver', 'merchant') THEN
      RAISE EXCEPTION 'role_not_allowed';
    END IF;
    NEW.approval_status := CASE WHEN NEW.role IN ('driver', 'merchant') THEN 'pending' ELSE 'approved' END;
    NEW.approved_at := NULL;
    NEW.approved_by := NULL;
    NEW.rejection_reason := NULL;
    NEW.admin_permissions := '[]'::jsonb;
    NEW.admin_level := 1;
    NEW.driver_delivery_system_rate := NULL;
    NEW.custom_delivery_fee := NULL;
    NEW.custom_service_fee := NULL;
    NEW.laundry_gp_rate := 0.1000;
    NEW.laundry_merchant_gp_rate := NULL;
    NEW.laundry_delivery_gp_rate := NULL;
    NEW.laundry_gp_driver_rate := NULL;
    NEW.total_completed_jobs := 0;
    NEW.acceptance_rate := NULL;
    NEW.completion_rate := NULL;
    NEW.average_rating := NULL;
    RETURN NEW;
  END IF;

  -- UPDATE
  IF NEW.role IS DISTINCT FROM OLD.role THEN
    IF OLD.role = 'customer' AND NEW.role IN ('driver', 'merchant') THEN
      -- สมัครเป็นคนขับ/ร้านค้าภายหลัง → ต้องรอแอดมินอนุมัติใหม่
      NEW.approval_status := 'pending';
      NEW.approved_at := NULL;
      NEW.approved_by := NULL;
    ELSE
      RAISE EXCEPTION 'role_change_not_allowed';
    END IF;
  ELSE
    NEW.approval_status := OLD.approval_status;
    NEW.approved_at := OLD.approved_at;
    NEW.approved_by := OLD.approved_by;
  END IF;

  NEW.rejection_reason := OLD.rejection_reason;
  NEW.admin_permissions := OLD.admin_permissions;
  NEW.admin_level := OLD.admin_level;
  NEW.driver_delivery_system_rate := OLD.driver_delivery_system_rate;
  NEW.custom_delivery_fee := OLD.custom_delivery_fee;
  NEW.custom_service_fee := OLD.custom_service_fee;
  NEW.laundry_gp_rate := OLD.laundry_gp_rate;
  NEW.laundry_merchant_gp_rate := OLD.laundry_merchant_gp_rate;
  NEW.laundry_delivery_gp_rate := OLD.laundry_delivery_gp_rate;
  NEW.laundry_gp_driver_rate := OLD.laundry_gp_driver_rate;
  NEW.total_completed_jobs := OLD.total_completed_jobs;
  NEW.acceptance_rate := OLD.acceptance_rate;
  NEW.completion_rate := OLD.completion_rate;
  NEW.average_rating := OLD.average_rating;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_profile_privileged_columns ON public.profiles;
CREATE TRIGGER trg_guard_profile_privileged_columns
  BEFORE INSERT OR UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_profile_privileged_columns();

COMMIT;
