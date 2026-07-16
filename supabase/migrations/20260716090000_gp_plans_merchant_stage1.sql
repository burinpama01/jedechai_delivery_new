-- ═══════════════════════════════════════════════════════════════
-- GP Plans (แพ็กเกจ GP ให้ร้านเลือกเองตอนสมัคร) + merchant stage-1 flow
-- - ตาราง gp_plans: แอดมิน เพิ่ม/ลบ/แก้ไข ได้, merchant อ่านได้
-- - profiles.gp_plan_id: แพลนที่ร้านเลือก
-- - RPC merchant_select_gp_plan: copy ค่าจากแพลนลง profile ฝั่ง server
--   (เลือกได้เฉพาะร้านที่ยังไม่ approved — หลังอนุมัติให้แอดมินแก้เท่านั้น)
-- ═══════════════════════════════════════════════════════════════

-- 1) gp_plans table
CREATE TABLE IF NOT EXISTS public.gp_plans (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL,
  description text,
  gp_rate numeric NOT NULL CHECK (gp_rate >= 0 AND gp_rate <= 0.95),
  gp_system_rate numeric CHECK (gp_system_rate IS NULL OR (gp_system_rate >= 0 AND gp_system_rate <= 0.95)),
  gp_driver_rate numeric CHECK (gp_driver_rate IS NULL OR (gp_driver_rate >= 0 AND gp_driver_rate <= 0.95)),
  base_delivery_fee numeric NOT NULL DEFAULT 0 CHECK (base_delivery_fee >= 0),
  base_distance_km numeric NOT NULL DEFAULT 0 CHECK (base_distance_km >= 0),
  per_km_charge numeric NOT NULL DEFAULT 0 CHECK (per_km_charge >= 0),
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.gp_plans IS 'แพ็กเกจ GP สำหรับร้านค้าเลือกตอนสมัคร (แอดมินจัดการได้)';
COMMENT ON COLUMN public.gp_plans.gp_rate IS 'GP หักร้านค้ารวม (0.15 = 15%)';
COMMENT ON COLUMN public.gp_plans.gp_system_rate IS 'ส่วนแบ่ง GP เข้าระบบ (NULL = ใช้ default resolver)';
COMMENT ON COLUMN public.gp_plans.gp_driver_rate IS 'ส่วนแบ่ง GP ให้คนขับ (NULL = ใช้ default resolver)';
COMMENT ON COLUMN public.gp_plans.base_delivery_fee IS 'ค่าส่งเริ่มต้น (บาท) ภายใน base_distance_km';
COMMENT ON COLUMN public.gp_plans.base_distance_km IS 'ระยะทางที่รวมในค่าส่งเริ่มต้น (กม.)';
COMMENT ON COLUMN public.gp_plans.per_km_charge IS 'ค่าส่งส่วนเกิน (บาท/กม.) เมื่อเกิน base_distance_km';

ALTER TABLE public.gp_plans ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "gp_plans_select_all" ON public.gp_plans;
CREATE POLICY "gp_plans_select_all" ON public.gp_plans
  FOR SELECT USING (true);

DROP POLICY IF EXISTS "gp_plans_admin_manage" ON public.gp_plans;
CREATE POLICY "gp_plans_admin_manage" ON public.gp_plans
  FOR ALL USING (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  ) WITH CHECK (
    EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
  );

-- 2) Seed 3 แพลนตามโปสเตอร์ (idempotent ด้วย fixed UUID)
INSERT INTO public.gp_plans
  (id, name, description, gp_rate, gp_system_rate, gp_driver_rate,
   base_delivery_fee, base_distance_km, per_km_charge, sort_order, is_active)
VALUES
  ('a1000000-0000-4000-8000-000000000001', 'รูปแบบที่ 1', NULL,
   0.15, 0.15, 0.00, 10, 5, 3, 1, true),
  ('a1000000-0000-4000-8000-000000000002', 'รูปแบบที่ 2', NULL,
   0.20, 0.10, 0.10, 5, 7, 2, 2, true),
  ('a1000000-0000-4000-8000-000000000003', 'รูปแบบที่ 3', NULL,
   0.25, 0.13, 0.12, 0, 10, 1, 3, true)
ON CONFLICT (id) DO NOTHING;

-- 3) profiles.gp_plan_id
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS gp_plan_id uuid REFERENCES public.gp_plans(id) ON DELETE SET NULL;
COMMENT ON COLUMN public.profiles.gp_plan_id IS 'แพ็กเกจ GP ที่ร้านเลือกตอนสมัคร (NULL = ยังไม่เลือก/ตั้งค่าเอง)';

-- 4) RPC: merchant เลือกแพลนเอง (copy ค่าฝั่ง server — client ส่งได้แค่ plan id)
CREATE OR REPLACE FUNCTION public.merchant_select_gp_plan(p_plan_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_profile record;
  v_plan record;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT id, role, approval_status INTO v_profile
  FROM public.profiles WHERE id = v_uid;

  IF NOT FOUND OR v_profile.role <> 'merchant' THEN
    RAISE EXCEPTION 'not_merchant';
  END IF;

  -- หลังอนุมัติแล้ว การเปลี่ยน GP ต้องให้แอดมินทำเท่านั้น
  IF v_profile.approval_status = 'approved' THEN
    RAISE EXCEPTION 'already_approved_contact_admin';
  END IF;

  SELECT * INTO v_plan
  FROM public.gp_plans
  WHERE id = p_plan_id AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'plan_not_found';
  END IF;

  -- อนุญาตให้ trigger guard ผ่าน (flag มีผลเฉพาะ transaction นี้)
  PERFORM set_config('app.allow_gp_update', 'on', true);

  UPDATE public.profiles SET
    gp_plan_id = v_plan.id,
    gp_rate = v_plan.gp_rate,
    merchant_gp_system_rate = v_plan.gp_system_rate,
    merchant_gp_driver_rate = v_plan.gp_driver_rate,
    custom_base_fare = v_plan.base_delivery_fee,
    custom_base_distance = v_plan.base_distance_km,
    custom_per_km = v_plan.per_km_charge,
    updated_at = now()
  WHERE id = v_uid;

  RETURN jsonb_build_object(
    'success', true,
    'plan_id', v_plan.id,
    'plan_name', v_plan.name,
    'gp_rate', v_plan.gp_rate
  );
END;
$$;

REVOKE ALL ON FUNCTION public.merchant_select_gp_plan(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.merchant_select_gp_plan(uuid) TO authenticated;

-- 5) Trigger กันผู้ใช้ทั่วไปแก้คอลัมน์ GP ของตัวเองตรง ๆ ผ่าน API
--    (RLS profiles_update_own เดิมเปิดทุกคอลัมน์ — ช่องโหว่การเงิน)
--    อนุญาต: service role (auth.uid() IS NULL), แอดมิน, และ RPC ที่ตั้ง flag
CREATE OR REPLACE FUNCTION public.guard_profile_gp_columns()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_is_admin boolean;
BEGIN
  IF current_setting('app.allow_gp_update', true) = 'on' THEN
    RETURN NEW;
  END IF;

  -- service role / direct DB connection (ไม่มี JWT) ผ่านได้
  IF v_uid IS NULL THEN
    RETURN NEW;
  END IF;

  IF NEW.gp_rate IS DISTINCT FROM OLD.gp_rate
     OR NEW.merchant_gp_system_rate IS DISTINCT FROM OLD.merchant_gp_system_rate
     OR NEW.merchant_gp_driver_rate IS DISTINCT FROM OLD.merchant_gp_driver_rate
     OR NEW.custom_base_fare IS DISTINCT FROM OLD.custom_base_fare
     OR NEW.custom_base_distance IS DISTINCT FROM OLD.custom_base_distance
     OR NEW.custom_per_km IS DISTINCT FROM OLD.custom_per_km
     OR NEW.gp_plan_id IS DISTINCT FROM OLD.gp_plan_id
  THEN
    SELECT EXISTS (
      SELECT 1 FROM public.profiles WHERE id = v_uid AND role = 'admin'
    ) INTO v_is_admin;

    IF NOT v_is_admin THEN
      RAISE EXCEPTION 'gp_columns_admin_only';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_profile_gp_columns ON public.profiles;
CREATE TRIGGER trg_guard_profile_gp_columns
  BEFORE UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.guard_profile_gp_columns();
