-- ทีมแอดมิน P1 (Plan/Admin_Staff_P1_Implementation_v1.html)
-- superadmin = profiles.role 'admin' (เดิม ไม่เปลี่ยน) · ผู้ช่วย/หัวหน้า = role ใหม่ 'staff'
-- deny by default: policy เดิม 73 จุด, verifyAdmin และหน้าแอดมินใน Flutter ไม่รู้จัก 'staff'
-- staff เขียนข้อมูลผ่าน edge function admin-actions เท่านั้น (ตรวจสิทธิ์ + ขออนุมัติ + audit)
-- ตารางใหม่ทั้งหมด: client อ่านได้ตาม RLS, เขียนได้เฉพาะ service_role

BEGIN;

-- ─── role ใหม่ ───
ALTER TABLE public.profiles DROP CONSTRAINT IF EXISTS profiles_role_check;
ALTER TABLE public.profiles ADD CONSTRAINT profiles_role_check
  CHECK (role = ANY (ARRAY['customer'::text, 'driver'::text, 'merchant'::text, 'admin'::text, 'staff'::text]));

-- ─── ต้องเหลือ superadmin ที่ใช้งานได้อย่างน้อย 1 คน ───
CREATE OR REPLACE FUNCTION public.guard_last_superadmin()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_losing boolean;
BEGIN
  IF TG_OP = 'DELETE' THEN
    v_losing := OLD.role = 'admin';
  ELSE
    v_losing := OLD.role = 'admin' AND (
      NEW.role IS DISTINCT FROM 'admin'
      OR (NEW.approval_status = 'suspended' AND OLD.approval_status IS DISTINCT FROM 'suspended')
    );
  END IF;

  IF v_losing THEN
    -- กันลดพร้อมกันสองคนจนเหลือ 0
    PERFORM pg_advisory_xact_lock(hashtext('public.guard_last_superadmin'));
    IF NOT EXISTS (
      SELECT 1 FROM public.profiles
      WHERE role = 'admin' AND id <> OLD.id
        AND COALESCE(approval_status, 'approved') <> 'suspended'
    ) THEN
      RAISE EXCEPTION 'last_superadmin';
    END IF;
  END IF;

  IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_guard_last_superadmin ON public.profiles;
CREATE TRIGGER trg_guard_last_superadmin
  BEFORE UPDATE OF role, approval_status OR DELETE ON public.profiles
  FOR EACH ROW EXECUTE FUNCTION public.guard_last_superadmin();

-- ─── ตาราง ───
CREATE TABLE public.admin_role_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name text NOT NULL UNIQUE CHECK (length(btrim(name)) BETWEEN 1 AND 80),
  description text NOT NULL DEFAULT '' CHECK (length(description) <= 500),
  page_levels jsonb NOT NULL DEFAULT '{}'::jsonb CHECK (jsonb_typeof(page_levels) = 'object'),
  is_system boolean NOT NULL DEFAULT false,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  updated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL
);

CREATE TABLE public.admin_staff (
  user_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  tier text NOT NULL CHECK (tier IN ('lead', 'assistant')),
  template_id uuid REFERENCES public.admin_role_templates(id) ON DELETE SET NULL,
  active boolean NOT NULL DEFAULT true,
  note text NOT NULL DEFAULT '' CHECK (length(note) <= 500),
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE public.admin_staff_page_overrides (
  user_id uuid NOT NULL REFERENCES public.admin_staff(user_id) ON DELETE CASCADE,
  page text NOT NULL CHECK (page ~ '^[a-z_]{2,40}$'),
  level text NOT NULL CHECK (level IN ('none', 'view', 'edit', 'approve')),
  PRIMARY KEY (user_id, page)
);

CREATE TABLE public.admin_staff_action_overrides (
  user_id uuid NOT NULL REFERENCES public.admin_staff(user_id) ON DELETE CASCADE,
  action text NOT NULL CHECK (action ~ '^[a-z_]{2,60}$'),
  effect text NOT NULL CHECK (effect IN ('allow', 'deny', 'require_approval')),
  PRIMARY KEY (user_id, action)
);

CREATE TABLE public.admin_approval_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL, -- เก็บประวัติไว้แม้ลบบัญชี (requester_name คงอยู่)
  requester_name text NOT NULL DEFAULT '',
  action text NOT NULL,
  pages text[] NOT NULL DEFAULT '{}',
  payload jsonb NOT NULL,
  summary text NOT NULL DEFAULT '' CHECK (length(summary) <= 1000),
  status text NOT NULL DEFAULT 'pending'
    CHECK (status IN ('pending', 'approved', 'rejected', 'cancelled', 'expired', 'executed', 'failed')),
  decided_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  decided_by_name text,
  decision_note text CHECK (length(decision_note) <= 1000),
  decided_at timestamptz,
  result jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT now() + interval '48 hours'
);
CREATE INDEX admin_approval_requests_status_idx ON public.admin_approval_requests (status, created_at DESC);
CREATE INDEX admin_approval_requests_requester_idx ON public.admin_approval_requests (requester_id, created_at DESC);

CREATE TABLE public.admin_audit_log (
  id bigserial PRIMARY KEY,
  actor_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  actor_tier text,
  action text NOT NULL,
  pages text[] NOT NULL DEFAULT '{}',
  target text,
  summary text CHECK (length(summary) <= 1000),
  outcome text NOT NULL
    CHECK (outcome IN ('allowed', 'denied', 'pending_approval', 'approved', 'rejected', 'executed', 'failed', 'cancelled', 'error')),
  request_id uuid,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX admin_audit_log_created_idx ON public.admin_audit_log (created_at DESC);
CREATE INDEX admin_audit_log_actor_idx ON public.admin_audit_log (actor_id, created_at DESC);

-- admin_staff ต้องเป็นผู้ใช้ role staff เท่านั้น
CREATE OR REPLACE FUNCTION public.guard_admin_staff_role()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = NEW.user_id AND role = 'staff') THEN
    RAISE EXCEPTION 'admin_staff_requires_staff_role';
  END IF;
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

CREATE TRIGGER trg_guard_admin_staff_role
  BEFORE INSERT OR UPDATE ON public.admin_staff
  FOR EACH ROW EXECUTE FUNCTION public.guard_admin_staff_role();

-- ─── ฟังก์ชันสิทธิ์ ───
-- สิทธิ์รวมของผู้ใช้: บทบาทสำเร็จรูป ทับด้วย override รายหน้า + override ราย action
CREATE OR REPLACE FUNCTION public.admin_staff_access(p_user uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT CASE
    WHEN p.role = 'admin' THEN jsonb_build_object(
      'tier', 'superadmin',
      'active', COALESCE(p.approval_status, 'approved') <> 'suspended',
      'pages', '{}'::jsonb,
      'actions', '{}'::jsonb
    )
    WHEN p.role = 'staff' AND s.user_id IS NOT NULL THEN jsonb_build_object(
      'tier', s.tier,
      'active', s.active AND COALESCE(p.approval_status, 'approved') <> 'suspended',
      'template_id', s.template_id,
      'template_name', t.name,
      'pages', COALESCE(t.page_levels, '{}'::jsonb)
        || COALESCE((SELECT jsonb_object_agg(o.page, o.level)
                     FROM public.admin_staff_page_overrides o WHERE o.user_id = p.id), '{}'::jsonb),
      'actions', COALESCE((SELECT jsonb_object_agg(a.action, a.effect)
                           FROM public.admin_staff_action_overrides a WHERE a.user_id = p.id), '{}'::jsonb)
    )
    ELSE NULL
  END
  FROM public.profiles p
  LEFT JOIN public.admin_staff s ON s.user_id = p.id
  LEFT JOIN public.admin_role_templates t ON t.id = s.template_id
  WHERE p.id = p_user;
$$;

CREATE OR REPLACE FUNCTION public.my_admin_access()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT public.admin_staff_access(auth.uid());
$$;

-- ระดับของผู้ใช้ปัจจุบันในหน้าหนึ่ง (ไว้ใช้ใน policy อ่านของ staff ใน P2)
CREATE OR REPLACE FUNCTION public.staff_page_level(p_page text)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_access jsonb := public.admin_staff_access(auth.uid());
  v_level text;
BEGIN
  IF v_access IS NULL OR (v_access->>'active')::boolean IS NOT TRUE THEN
    RETURN 'none';
  END IF;
  IF v_access->>'tier' = 'superadmin' THEN
    RETURN 'approve';
  END IF;
  v_level := v_access->'pages'->>p_page;
  IF v_level IN ('view', 'edit', 'approve') THEN
    RETURN v_level;
  END IF;
  RETURN 'none';
END;
$$;

-- หัวหน้าที่อนุมัติได้ในหน้าใดหน้าหนึ่งของคำขอ (ผู้ใช้ปัจจุบัน)
CREATE OR REPLACE FUNCTION public.staff_can_approve(p_pages text[])
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_access jsonb := public.admin_staff_access(auth.uid());
  v_page text;
BEGIN
  IF v_access IS NULL OR (v_access->>'active')::boolean IS NOT TRUE THEN
    RETURN false;
  END IF;
  IF v_access->>'tier' = 'superadmin' THEN
    RETURN true;
  END IF;
  IF v_access->>'tier' <> 'lead' THEN
    RETURN false;
  END IF;
  FOREACH v_page IN ARRAY COALESCE(p_pages, '{}') LOOP
    IF v_access->'pages'->>v_page = 'approve' THEN
      RETURN true;
    END IF;
  END LOOP;
  RETURN false;
END;
$$;

-- ผู้อนุมัติของคำขอ: superadmin ทุกคน + หัวหน้าที่มีระดับอนุมัติในหน้านั้น
CREATE OR REPLACE FUNCTION public.admin_approvers_for_pages(p_pages text[])
RETURNS TABLE (user_id uuid)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
  SELECT p.id
  FROM public.profiles p
  WHERE p.role = 'admin' AND COALESCE(p.approval_status, 'approved') <> 'suspended'
  UNION
  SELECT s.user_id
  FROM public.admin_staff s
  JOIN public.profiles p ON p.id = s.user_id
  WHERE s.active AND s.tier = 'lead'
    AND COALESCE(p.approval_status, 'approved') <> 'suspended'
    AND EXISTS (
      SELECT 1 FROM unnest(COALESCE(p_pages, '{}')) pg(page)
      WHERE (public.admin_staff_access(s.user_id)->'pages'->>pg.page) = 'approve'
    );
$$;

-- ค้นผู้ใช้ด้วยอีเมล (ใช้ตอนแปลงบัญชีเดิมเป็นทีมแอดมิน)
CREATE OR REPLACE FUNCTION public.admin_find_user_by_email(p_email text)
RETURNS TABLE (id uuid, role text, full_name text, approval_status text)
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
  SELECT p.id, p.role, p.full_name, p.approval_status
  FROM auth.users u
  JOIN public.profiles p ON p.id = u.id
  WHERE lower(u.email) = lower(btrim(p_email))
  LIMIT 1;
$$;

REVOKE ALL ON FUNCTION public.guard_last_superadmin() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.guard_admin_staff_role() FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_staff_access(uuid) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_approvers_for_pages(text[]) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.admin_find_user_by_email(text) FROM PUBLIC, anon, authenticated;
REVOKE ALL ON FUNCTION public.my_admin_access() FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.staff_page_level(text) FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.staff_can_approve(text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_staff_access(uuid) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_approvers_for_pages(text[]) TO service_role;
GRANT EXECUTE ON FUNCTION public.admin_find_user_by_email(text) TO service_role;
GRANT EXECUTE ON FUNCTION public.my_admin_access() TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_page_level(text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.staff_can_approve(text[]) TO authenticated;

-- ─── RLS: อ่านตามสิทธิ์, เขียนผ่าน service_role (admin-actions) เท่านั้น ───
ALTER TABLE public.admin_role_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_staff ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_staff_page_overrides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_staff_action_overrides ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_approval_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admin_audit_log ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.admin_role_templates, public.admin_staff, public.admin_staff_page_overrides,
  public.admin_staff_action_overrides, public.admin_approval_requests, public.admin_audit_log
  FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.admin_role_templates, public.admin_staff, public.admin_staff_page_overrides,
  public.admin_staff_action_overrides, public.admin_approval_requests, public.admin_audit_log
  TO authenticated;
GRANT ALL ON public.admin_role_templates, public.admin_staff, public.admin_staff_page_overrides,
  public.admin_staff_action_overrides, public.admin_approval_requests, public.admin_audit_log
  TO service_role;
GRANT USAGE, SELECT ON SEQUENCE public.admin_audit_log_id_seq TO service_role;

CREATE POLICY admin_role_templates_read ON public.admin_role_templates
  FOR SELECT TO authenticated
  USING (
    public.is_admin()
    OR EXISTS (SELECT 1 FROM public.admin_staff s WHERE s.user_id = auth.uid() AND s.template_id = admin_role_templates.id)
  );

CREATE POLICY admin_staff_read ON public.admin_staff
  FOR SELECT TO authenticated USING (public.is_admin() OR user_id = auth.uid());

CREATE POLICY admin_staff_page_overrides_read ON public.admin_staff_page_overrides
  FOR SELECT TO authenticated USING (public.is_admin() OR user_id = auth.uid());

CREATE POLICY admin_staff_action_overrides_read ON public.admin_staff_action_overrides
  FOR SELECT TO authenticated USING (public.is_admin() OR user_id = auth.uid());

CREATE POLICY admin_approval_requests_read ON public.admin_approval_requests
  FOR SELECT TO authenticated
  USING (public.is_admin() OR requester_id = auth.uid() OR public.staff_can_approve(pages));

CREATE POLICY admin_audit_log_read ON public.admin_audit_log
  FOR SELECT TO authenticated USING (public.is_admin());

-- ─── บทบาทสำเร็จรูปตั้งต้น ───
INSERT INTO public.admin_role_templates (name, description, page_levels, is_system) VALUES
  ('ฝ่ายบัญชี/การเงิน', 'เติมเงิน ถอนเงิน กระเป๋าลูกค้า รายได้',
   '{"topups":"edit","withdrawals":"edit","customer_wallets":"edit","revenue":"view","users":"view","orders":"view","approvals":"view"}', true),
  ('ฝ่ายดูแลร้าน', 'ร้านค้า เมนู AI นำเข้าเมนู ร้านฝากซื้อ',
   '{"merchants":"edit","menus":"edit","ai_menu_import":"edit","shop_stores":"edit","orders":"view","reviews":"view","approvals":"view"}', true),
  ('ฝ่ายดูแลคนขับ', 'คนขับ แผนที่',
   '{"drivers":"edit","map":"view","orders":"view","approvals":"view"}', true),
  ('ฝ่ายบริการลูกค้า', 'ร้องเรียน ออเดอร์ ฝากซื้อ ซักรีด รีวิว',
   '{"complaints":"edit","orders":"edit","pending_orders":"edit","shop_orders":"edit","laundry":"edit","reviews":"edit","users":"view","drivers":"view","merchants":"view","approvals":"view"}', true),
  ('ฝ่ายการตลาด', 'โปรโมชัน ประกาศ ชวนเพื่อน',
   '{"promos":"edit","broadcast":"edit","referrals":"edit","dashboard":"view","approvals":"view"}', true)
ON CONFLICT (name) DO NOTHING;

COMMIT;
