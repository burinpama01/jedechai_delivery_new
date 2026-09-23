-- ═══════════════════════════════════════════════════════════════
-- GP Plan: ร้านเปลี่ยนแพ็กเกจเองหลังอนุมัติ (เดือนละ 1 ครั้ง) + ประวัติ + backfill
--
-- - merchant_gp_plan_history: บันทึกทุกการเปลี่ยนค่า GP/ค่าส่งของร้าน (snapshot)
--   source = self (ร้านเลือกเอง) | admin (แอดมิน/service role) | backfill | system
-- - cooldown 30 วัน นับเฉพาะการเปลี่ยนเองของร้านที่อนุมัติแล้ว (source=self, was_approved)
--   การเปลี่ยนโดยแอดมิน/backfill ไม่นับ และไม่รีเซ็ต cooldown
-- - ร้านดีลตรง (อนุมัติแล้วแต่ gp_plan_id = NULL) เปลี่ยนเองไม่ได้ ต้องติดต่อแอดมิน
-- - ห้ามเปลี่ยนระหว่างมีออเดอร์ค้าง (GP ถูกคำนวณจาก profile ตอนจบงาน)
-- - invariant: ถ้าค่า GP/ค่าส่งของร้านไม่ตรงกับแพลนที่ผูกไว้ → gp_plan_id = NULL (กลายเป็นดีลตรง)
-- - backfill: ผูก gp_plan_id ให้ร้านเดิมที่ค่า GP + ค่าส่งตรงกับแพลนทุกค่า
-- ═══════════════════════════════════════════════════════════════

BEGIN;

-- 1) History table ------------------------------------------------
CREATE TABLE IF NOT EXISTS public.merchant_gp_plan_history (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  plan_id uuid REFERENCES public.gp_plans(id) ON DELETE SET NULL,
  previous_plan_id uuid REFERENCES public.gp_plans(id) ON DELETE SET NULL,
  source text NOT NULL CHECK (source IN ('self', 'admin', 'backfill', 'system')),
  was_approved boolean NOT NULL DEFAULT false,
  changed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  snapshot jsonb NOT NULL,
  previous_snapshot jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.merchant_gp_plan_history IS
  'ประวัติการเปลี่ยนแพ็กเกจ GP / ค่าส่งของร้าน (หลักฐานทางการเงิน + ใช้คำนวณ cooldown)';

CREATE INDEX IF NOT EXISTS idx_merchant_gp_plan_history_merchant
  ON public.merchant_gp_plan_history (merchant_id, source, created_at DESC);

ALTER TABLE public.merchant_gp_plan_history ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "gp_history_select_own" ON public.merchant_gp_plan_history;
CREATE POLICY "gp_history_select_own" ON public.merchant_gp_plan_history
  FOR SELECT USING (merchant_id = auth.uid());

DROP POLICY IF EXISTS "gp_history_select_admin" ON public.merchant_gp_plan_history;
CREATE POLICY "gp_history_select_admin" ON public.merchant_gp_plan_history
  FOR SELECT USING (public.is_admin());

-- เขียนได้เฉพาะผ่าน trigger (SECURITY DEFINER) เท่านั้น
REVOKE INSERT, UPDATE, DELETE ON public.merchant_gp_plan_history FROM anon, authenticated;

-- 2) Guard (BEFORE UPDATE): สิทธิ์ + invariant แพลน ↔ ค่า -------------
CREATE OR REPLACE FUNCTION public.guard_profile_gp_columns()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_is_admin boolean;
  v_changed boolean;
  v_plan record;
BEGIN
  v_changed :=
       NEW.gp_rate IS DISTINCT FROM OLD.gp_rate
    OR NEW.merchant_gp_system_rate IS DISTINCT FROM OLD.merchant_gp_system_rate
    OR NEW.merchant_gp_driver_rate IS DISTINCT FROM OLD.merchant_gp_driver_rate
    OR NEW.custom_base_fare IS DISTINCT FROM OLD.custom_base_fare
    OR NEW.custom_base_distance IS DISTINCT FROM OLD.custom_base_distance
    OR NEW.custom_per_km IS DISTINCT FROM OLD.custom_per_km
    OR NEW.gp_plan_id IS DISTINCT FROM OLD.gp_plan_id;

  IF NOT v_changed THEN
    RETURN NEW;
  END IF;

  -- สิทธิ์: RPC ที่ตั้ง flag / service role (ไม่มี JWT) / แอดมิน เท่านั้น
  IF COALESCE(current_setting('app.allow_gp_update', true), '') <> 'on'
     AND v_uid IS NOT NULL THEN
    SELECT EXISTS (
      SELECT 1 FROM public.profiles WHERE id = v_uid AND role = 'admin'
    ) INTO v_is_admin;

    IF NOT v_is_admin THEN
      RAISE EXCEPTION 'gp_columns_admin_only';
    END IF;
  END IF;

  -- invariant: ค่าที่ร้านเห็น (GP% + ค่าส่ง) ต้องตรงกับแพลนที่ผูกอยู่
  IF NEW.gp_plan_id IS NOT NULL THEN
    SELECT gp_rate, base_delivery_fee, base_distance_km, per_km_charge
      INTO v_plan
    FROM public.gp_plans WHERE id = NEW.gp_plan_id;

    IF NOT FOUND
       OR NEW.gp_rate IS DISTINCT FROM v_plan.gp_rate
       OR NEW.custom_base_fare IS DISTINCT FROM v_plan.base_delivery_fee
       OR NEW.custom_base_distance IS DISTINCT FROM v_plan.base_distance_km
       OR NEW.custom_per_km IS DISTINCT FROM v_plan.per_km_charge
    THEN
      NEW.gp_plan_id := NULL;
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

-- 3) History logger (AFTER UPDATE) -----------------------------------
CREATE OR REPLACE FUNCTION public.log_profile_gp_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_source text;
BEGIN
  IF NEW.role IS DISTINCT FROM 'merchant' THEN
    RETURN NEW;
  END IF;

  IF NOT (
       NEW.gp_rate IS DISTINCT FROM OLD.gp_rate
    OR NEW.merchant_gp_system_rate IS DISTINCT FROM OLD.merchant_gp_system_rate
    OR NEW.merchant_gp_driver_rate IS DISTINCT FROM OLD.merchant_gp_driver_rate
    OR NEW.custom_base_fare IS DISTINCT FROM OLD.custom_base_fare
    OR NEW.custom_base_distance IS DISTINCT FROM OLD.custom_base_distance
    OR NEW.custom_per_km IS DISTINCT FROM OLD.custom_per_km
    OR NEW.gp_plan_id IS DISTINCT FROM OLD.gp_plan_id
  ) THEN
    RETURN NEW;
  END IF;

  v_source := NULLIF(current_setting('app.gp_change_source', true), '');
  IF v_source IS NULL OR v_source NOT IN ('self', 'admin', 'backfill', 'system') THEN
    v_source := 'admin';
  END IF;

  INSERT INTO public.merchant_gp_plan_history
    (merchant_id, plan_id, previous_plan_id, source, was_approved, changed_by,
     snapshot, previous_snapshot)
  VALUES (
    NEW.id, NEW.gp_plan_id, OLD.gp_plan_id, v_source,
    COALESCE(OLD.approval_status = 'approved', false),
    auth.uid(),
    jsonb_build_object(
      'gp_rate', NEW.gp_rate,
      'merchant_gp_system_rate', NEW.merchant_gp_system_rate,
      'merchant_gp_driver_rate', NEW.merchant_gp_driver_rate,
      'custom_base_fare', NEW.custom_base_fare,
      'custom_base_distance', NEW.custom_base_distance,
      'custom_per_km', NEW.custom_per_km),
    jsonb_build_object(
      'gp_rate', OLD.gp_rate,
      'merchant_gp_system_rate', OLD.merchant_gp_system_rate,
      'merchant_gp_driver_rate', OLD.merchant_gp_driver_rate,
      'custom_base_fare', OLD.custom_base_fare,
      'custom_base_distance', OLD.custom_base_distance,
      'custom_per_km', OLD.custom_per_km)
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_log_profile_gp_change ON public.profiles;
CREATE TRIGGER trg_log_profile_gp_change
  AFTER UPDATE ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.log_profile_gp_change();

-- 4) Cooldown helper (internal) ------------------------------------
CREATE OR REPLACE FUNCTION public._merchant_gp_next_change_at(p_merchant_id uuid)
RETURNS timestamptz
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT max(created_at) + interval '30 days'
  FROM public.merchant_gp_plan_history
  WHERE merchant_id = p_merchant_id
    AND source = 'self'
    AND was_approved = true;
$$;

REVOKE ALL ON FUNCTION public._merchant_gp_next_change_at(uuid) FROM public, anon, authenticated;

-- 5) RPC: ร้านเลือก/เปลี่ยนแพลน --------------------------------------
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
  v_next timestamptz;
  v_is_approved boolean;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT id, role, approval_status, gp_plan_id INTO v_profile
  FROM public.profiles WHERE id = v_uid
  FOR UPDATE;

  IF NOT FOUND OR v_profile.role <> 'merchant' THEN
    RAISE EXCEPTION 'not_merchant';
  END IF;

  SELECT * INTO v_plan
  FROM public.gp_plans
  WHERE id = p_plan_id AND is_active = true;

  IF NOT FOUND THEN
    RAISE EXCEPTION 'plan_not_found';
  END IF;

  v_is_approved := v_profile.approval_status = 'approved';

  IF v_is_approved THEN
    -- ดีลตรง: แอดมินตั้งค่าเฉพาะไว้ ร้านเปลี่ยนเองไม่ได้
    IF v_profile.gp_plan_id IS NULL THEN
      RAISE EXCEPTION 'custom_deal_contact_admin';
    END IF;

    IF v_profile.gp_plan_id = p_plan_id THEN
      RAISE EXCEPTION 'same_plan';
    END IF;

    v_next := public._merchant_gp_next_change_at(v_uid);
    IF v_next IS NOT NULL AND v_next > now() THEN
      RAISE EXCEPTION 'gp_plan_cooldown' USING DETAIL = v_next::text;
    END IF;

    IF EXISTS (
      SELECT 1 FROM public.bookings
      WHERE merchant_id = v_uid
        AND status NOT IN ('completed', 'cancelled', 'rejected', 'expired', 'failed')
    ) THEN
      RAISE EXCEPTION 'active_orders_exist';
    END IF;
  END IF;

  -- อนุญาตให้ trigger guard ผ่าน + บอก logger ว่าเป็นการเปลี่ยนเอง (มีผลเฉพาะ transaction นี้)
  PERFORM set_config('app.allow_gp_update', 'on', true);
  PERFORM set_config('app.gp_change_source', 'self', true);

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

  PERFORM set_config('app.allow_gp_update', '', true);
  PERFORM set_config('app.gp_change_source', '', true);

  RETURN jsonb_build_object(
    'success', true,
    'plan_id', v_plan.id,
    'plan_name', v_plan.name,
    'gp_rate', v_plan.gp_rate,
    'next_change_at', CASE WHEN v_is_approved THEN now() + interval '30 days' ELSE NULL END
  );
END;
$$;

REVOKE ALL ON FUNCTION public.merchant_select_gp_plan(uuid) FROM public;
GRANT EXECUTE ON FUNCTION public.merchant_select_gp_plan(uuid) TO authenticated;

-- 6) RPC: สถานะแพ็กเกจของร้าน (ใช้แสดงนับถอยหลัง) ----------------------
CREATE OR REPLACE FUNCTION public.merchant_gp_plan_status()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_profile record;
  v_next timestamptz;
  v_active boolean;
  v_reason text := NULL;
  v_is_approved boolean;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT id, role, approval_status, gp_plan_id, gp_rate,
         custom_base_fare, custom_base_distance, custom_per_km
    INTO v_profile
  FROM public.profiles WHERE id = v_uid;

  IF NOT FOUND OR v_profile.role <> 'merchant' THEN
    RAISE EXCEPTION 'not_merchant';
  END IF;

  v_is_approved := v_profile.approval_status = 'approved';
  v_next := public._merchant_gp_next_change_at(v_uid);
  IF v_next IS NOT NULL AND v_next <= now() THEN
    v_next := NULL;
  END IF;

  SELECT EXISTS (
    SELECT 1 FROM public.bookings
    WHERE merchant_id = v_uid
      AND status NOT IN ('completed', 'cancelled', 'rejected', 'expired', 'failed')
  ) INTO v_active;

  IF v_is_approved THEN
    IF v_profile.gp_plan_id IS NULL THEN
      v_reason := 'custom_deal';
    ELSIF v_next IS NOT NULL THEN
      v_reason := 'cooldown';
    ELSIF v_active THEN
      v_reason := 'active_orders';
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'plan_id', v_profile.gp_plan_id,
    'approval_status', v_profile.approval_status,
    'is_custom_deal', v_is_approved AND v_profile.gp_plan_id IS NULL,
    'gp_rate', v_profile.gp_rate,
    'custom_base_fare', v_profile.custom_base_fare,
    'custom_base_distance', v_profile.custom_base_distance,
    'custom_per_km', v_profile.custom_per_km,
    'can_change', v_reason IS NULL,
    'blocked_reason', v_reason,
    'next_change_at', v_next,
    'has_active_orders', v_active,
    'cooldown_days', 30,
    'server_now', now()
  );
END;
$$;

REVOKE ALL ON FUNCTION public.merchant_gp_plan_status() FROM public;
GRANT EXECUTE ON FUNCTION public.merchant_gp_plan_status() TO authenticated;

-- 7) Backfill ร้านเดิมที่ค่าตรงกับแพลนทุกค่า (ร้านอื่น = ดีลตรง ปล่อยไว้) ----
SELECT set_config('app.gp_change_source', 'backfill', true);

UPDATE public.profiles p
SET gp_plan_id = gp.id
FROM public.gp_plans gp
WHERE p.role = 'merchant'
  AND p.gp_plan_id IS NULL
  AND gp.is_active = true
  AND NOT ('laundry' = ANY (COALESCE(p.merchant_service_types, ARRAY[]::text[])))
  AND (p.custom_delivery_fee IS NULL OR p.custom_delivery_fee = 0)
  AND p.gp_rate = gp.gp_rate
  AND p.custom_base_fare = gp.base_delivery_fee
  AND p.custom_base_distance = gp.base_distance_km
  AND p.custom_per_km = gp.per_km_charge;

SELECT set_config('app.gp_change_source', '', true);

COMMIT;
