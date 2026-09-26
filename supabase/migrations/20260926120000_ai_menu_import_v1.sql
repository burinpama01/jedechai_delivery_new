-- AI Menu Import V1 (แผน Plan/JDC_AI_Merchant_Quick_Setup_Plan_v7.html — Phase 2)
--
-- ร้านถ่ายรูปป้ายเมนู → Edge Function `merchant-ai-menu-import` อ่านด้วย OpenAI
-- → ลงตาราง import แบบร่าง → ร้านตรวจ/แก้ → เลือกชุดตัวเลือกแนะนำ (แม่แบบ)
-- → RPC merchant_publish_import สร้างเมนูจริงใน transaction เดียว
--
-- หลักการ:
--   * AI ไม่เขียน menu_* ตรง — ทุกอย่างผ่านตาราง import + RPC publish
--   * merchant_id มาจาก auth.uid() เท่านั้น
--   * โหมด append (ร้านที่อนุมัติแล้ว) = INSERT อย่างเดียว ไม่แก้/ลบเมนู หมวด
--     หรือ option group เดิม
--   * ปิด feature ไว้ตอน deploy (flag = false) เปิดเมื่อพร้อม
--
-- Rollback: drop ตาราง merchant_import_* / option_templates / ai_runs /
--   merchant_ai_import_quota, drop column menu_items.source_import_job_id,
--   drop functions ai_menu_* / merchant_*import*, ลบ bucket merchant-imports

-- ─────────────────────────────────────────────────────────────
-- 0) config (ไม่ทับค่าที่แอดมินตั้งไว้แล้ว)
-- ─────────────────────────────────────────────────────────────
INSERT INTO public.system_config (key, value)
VALUES
  ('ai_menu_import_onboarding_enabled', 'false'),
  ('ai_menu_import_append_enabled',     'false'),
  -- ว่าง = ทุกร้าน · มีค่า = เฉพาะ merchant id ที่คั่นด้วย comma (ช่วงทดลอง)
  ('ai_menu_import_allowlist',          ''),
  -- D5: onboarding 3 job สำเร็จ (ครั้งเดียว) + append 5 job ต่อเดือน
  ('ai_menu_import_quota_onboarding',   '3'),
  ('ai_menu_import_quota_append_month', '5'),
  ('ai_menu_import_max_files',          '8')
ON CONFLICT (key) WHERE key IS NOT NULL DO NOTHING;

CREATE OR REPLACE FUNCTION public.ai_import_cfg(p_key text, p_fallback text)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT coalesce(nullif(btrim((SELECT max(value) FROM public.system_config WHERE key = p_key)), ''), p_fallback);
$$;
REVOKE ALL ON FUNCTION public.ai_import_cfg(text, text) FROM PUBLIC, anon, authenticated;

-- normalize ชื่อสำหรับเทียบรายการซ้ำ: ตัวพิมพ์เล็ก, ตัดช่องว่าง/เครื่องหมาย, ตัดคำ "เมนู"
CREATE OR REPLACE FUNCTION public.ai_menu_norm_name(p_name text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT regexp_replace(
           replace(lower(coalesce(p_name, '')), 'เมนู', ''),
           '[[:space:][:punct:]]+', '', 'g');
$$;

-- ─────────────────────────────────────────────────────────────
-- 1) ตาราง
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.merchant_import_jobs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  mode text NOT NULL DEFAULT 'onboarding' CHECK (mode IN ('onboarding', 'append')),
  source_type text NOT NULL DEFAULT 'image' CHECK (source_type IN ('image', 'manual')),
  status text NOT NULL DEFAULT 'uploading' CHECK (status IN (
    'uploading', 'queued', 'processing', 'review_required', 'ready',
    'publishing', 'published', 'failed', 'cancelled')),
  store_type text CHECK (store_type IN ('cafe', 'made_to_order', 'noodle', 'isan', 'dessert', 'other')),
  store_type_guess text,
  store_type_confidence numeric(4, 3),
  visibility text CHECK (visibility IN ('hidden', 'live')),
  attempts integer NOT NULL DEFAULT 0,
  locked_at timestamptz,
  error text,
  total_files integer NOT NULL DEFAULT 0,
  total_items integer NOT NULL DEFAULT 0,
  low_confidence_items integer NOT NULL DEFAULT 0,
  existing_menu_count integer NOT NULL DEFAULT 0,
  unreadable_regions text[] NOT NULL DEFAULT '{}',
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz,
  completed_at timestamptz,
  published_at timestamptz,
  hidden_at timestamptz
);
CREATE INDEX IF NOT EXISTS idx_merchant_import_jobs_merchant
  ON public.merchant_import_jobs (merchant_id, created_at DESC);

CREATE TABLE IF NOT EXISTS public.merchant_import_sources (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  import_job_id uuid NOT NULL REFERENCES public.merchant_import_jobs(id) ON DELETE CASCADE,
  source_index integer NOT NULL,
  storage_path text NOT NULL UNIQUE,
  mime text,
  bytes integer,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_merchant_import_sources_job
  ON public.merchant_import_sources (import_job_id);

CREATE TABLE IF NOT EXISTS public.merchant_import_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  import_job_id uuid NOT NULL REFERENCES public.merchant_import_jobs(id) ON DELETE CASCADE,
  source_index integer,
  sort_order integer NOT NULL DEFAULT 0,
  category text,
  name text NOT NULL,
  description text,
  price numeric(10, 2),
  variant_group text,
  variants_json jsonb NOT NULL DEFAULT '[]'::jsonb,   -- [{label, price}]
  addons_json jsonb NOT NULL DEFAULT '[]'::jsonb,     -- [{group, label, price_delta}]
  price_text_raw text,
  confidence_json jsonb NOT NULL DEFAULT '{}'::jsonb, -- {name, price, category}
  issues text[] NOT NULL DEFAULT '{}',
  conflict_json jsonb,                                -- ราคาทางเลือกเมื่อรูปขัดกัน
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft', 'approved', 'edited', 'rejected', 'published')),
  match_type text NOT NULL DEFAULT 'new'
    CHECK (match_type IN ('new', 'exact_dup', 'price_changed', 'similar')),
  matched_menu_item_id uuid REFERENCES public.menu_items(id) ON DELETE SET NULL,
  matched_price numeric(10, 2),
  action text NOT NULL DEFAULT 'create' CHECK (action IN ('create', 'skip')),
  matched_category_id uuid REFERENCES public.menu_categories(id) ON DELETE SET NULL,
  is_new_category boolean NOT NULL DEFAULT false,
  published_menu_item_id uuid REFERENCES public.menu_items(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_merchant_import_items_job
  ON public.merchant_import_items (import_job_id, sort_order);

CREATE TABLE IF NOT EXISTS public.merchant_import_audit (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  import_job_id uuid NOT NULL REFERENCES public.merchant_import_jobs(id) ON DELETE CASCADE,
  actor_id uuid,
  action text NOT NULL,
  item_id uuid,
  diff jsonb,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_merchant_import_audit_job
  ON public.merchant_import_audit (import_job_id, created_at);

-- log ทุกการเรียก AI (อ่านได้เฉพาะแอดมิน)
CREATE TABLE IF NOT EXISTS public.ai_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  feature text NOT NULL,
  provider text NOT NULL DEFAULT 'openai',
  model text,
  merchant_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  import_job_id uuid REFERENCES public.merchant_import_jobs(id) ON DELETE SET NULL,
  input_tokens integer,
  output_tokens integer,
  estimated_cost_usd numeric(10, 5),
  latency_ms integer,
  status text NOT NULL,
  error text,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_ai_runs_created ON public.ai_runs (created_at DESC);

-- แม่แบบชุดตัวเลือกแนะนำ (แอดมินดูแล)
CREATE TABLE IF NOT EXISTS public.option_templates (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  store_type text NOT NULL CHECK (store_type IN ('cafe', 'made_to_order', 'noodle', 'isan', 'dessert', 'other')),
  name text NOT NULL,
  min_selection integer NOT NULL DEFAULT 0 CHECK (min_selection >= 0),
  max_selection integer NOT NULL DEFAULT 1 CHECK (max_selection >= 1),
  options jsonb NOT NULL DEFAULT '[]'::jsonb,       -- [{label, price}]
  match_keywords text[] NOT NULL DEFAULT '{}',
  exclude_keywords text[] NOT NULL DEFAULT '{}',
  sort_order integer NOT NULL DEFAULT 0,
  is_active boolean NOT NULL DEFAULT true,
  version integer NOT NULL DEFAULT 1,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT option_templates_options_array CHECK (jsonb_typeof(options) = 'array'),
  CONSTRAINT option_templates_min_le_max CHECK (min_selection <= max_selection)
);
CREATE INDEX IF NOT EXISTS idx_option_templates_type ON public.option_templates (store_type, sort_order);

CREATE TABLE IF NOT EXISTS public.merchant_import_template_selections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  import_job_id uuid NOT NULL REFERENCES public.merchant_import_jobs(id) ON DELETE CASCADE,
  template_id uuid REFERENCES public.option_templates(id) ON DELETE SET NULL,
  template_version integer,
  name text NOT NULL,
  min_selection integer NOT NULL,
  max_selection integer NOT NULL,
  options jsonb NOT NULL,
  import_item_ids uuid[] NOT NULL DEFAULT '{}',
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_import_template_sel_job
  ON public.merchant_import_template_selections (import_job_id);

-- โควตาเพิ่มรายร้าน (แอดมินตั้ง)
CREATE TABLE IF NOT EXISTS public.merchant_ai_import_quota (
  merchant_id uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  extra_onboarding integer NOT NULL DEFAULT 0,
  extra_append_monthly integer NOT NULL DEFAULT 0,
  updated_by uuid,
  updated_at timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.menu_items
  ADD COLUMN IF NOT EXISTS source_import_job_id uuid
    REFERENCES public.merchant_import_jobs(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_menu_items_source_import_job
  ON public.menu_items (source_import_job_id) WHERE source_import_job_id IS NOT NULL;

-- ─────────────────────────────────────────────────────────────
-- 2) RLS — client อ่านได้เฉพาะของตัวเอง เขียนผ่าน RPC/Edge Function เท่านั้น
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.merchant_import_jobs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_import_sources ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_import_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_import_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.option_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_import_template_selections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.merchant_ai_import_quota ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS import_jobs_select_own ON public.merchant_import_jobs;
CREATE POLICY import_jobs_select_own ON public.merchant_import_jobs
  FOR SELECT TO authenticated
  USING (merchant_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS import_sources_select_own ON public.merchant_import_sources;
CREATE POLICY import_sources_select_own ON public.merchant_import_sources
  FOR SELECT TO authenticated
  USING (public.is_admin() OR EXISTS (
    SELECT 1 FROM public.merchant_import_jobs j
    WHERE j.id = import_job_id AND j.merchant_id = auth.uid()));

DROP POLICY IF EXISTS import_items_select_own ON public.merchant_import_items;
CREATE POLICY import_items_select_own ON public.merchant_import_items
  FOR SELECT TO authenticated
  USING (public.is_admin() OR EXISTS (
    SELECT 1 FROM public.merchant_import_jobs j
    WHERE j.id = import_job_id AND j.merchant_id = auth.uid()));

DROP POLICY IF EXISTS import_audit_select_admin ON public.merchant_import_audit;
CREATE POLICY import_audit_select_admin ON public.merchant_import_audit
  FOR SELECT TO authenticated
  USING (public.is_admin());

DROP POLICY IF EXISTS ai_runs_select_admin ON public.ai_runs;
CREATE POLICY ai_runs_select_admin ON public.ai_runs
  FOR SELECT TO authenticated
  USING (public.is_admin());

DROP POLICY IF EXISTS option_templates_select ON public.option_templates;
CREATE POLICY option_templates_select ON public.option_templates
  FOR SELECT TO authenticated
  USING (is_active OR public.is_admin());

DROP POLICY IF EXISTS option_templates_admin_write ON public.option_templates;
CREATE POLICY option_templates_admin_write ON public.option_templates
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS import_template_sel_select_own ON public.merchant_import_template_selections;
CREATE POLICY import_template_sel_select_own ON public.merchant_import_template_selections
  FOR SELECT TO authenticated
  USING (public.is_admin() OR EXISTS (
    SELECT 1 FROM public.merchant_import_jobs j
    WHERE j.id = import_job_id AND j.merchant_id = auth.uid()));

DROP POLICY IF EXISTS ai_import_quota_select ON public.merchant_ai_import_quota;
CREATE POLICY ai_import_quota_select ON public.merchant_ai_import_quota
  FOR SELECT TO authenticated
  USING (merchant_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS ai_import_quota_admin_write ON public.merchant_ai_import_quota;
CREATE POLICY ai_import_quota_admin_write ON public.merchant_ai_import_quota
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ─────────────────────────────────────────────────────────────
-- 3) Storage bucket (private) — เขียน/อ่านได้เฉพาะโฟลเดอร์ {auth.uid()}/
-- ─────────────────────────────────────────────────────────────
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES ('merchant-imports', 'merchant-imports', false, 10485760,
        ARRAY['image/jpeg', 'image/png', 'image/webp'])
ON CONFLICT (id) DO UPDATE
  SET public = false,
      file_size_limit = EXCLUDED.file_size_limit,
      allowed_mime_types = EXCLUDED.allowed_mime_types;

DROP POLICY IF EXISTS merchant_imports_insert_own ON storage.objects;
CREATE POLICY merchant_imports_insert_own ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (bucket_id = 'merchant-imports'
              AND (storage.foldername(name))[1] = auth.uid()::text);

DROP POLICY IF EXISTS merchant_imports_select_own ON storage.objects;
CREATE POLICY merchant_imports_select_own ON storage.objects
  FOR SELECT TO authenticated
  USING (bucket_id = 'merchant-imports'
         AND ((storage.foldername(name))[1] = auth.uid()::text OR public.is_admin()));

-- ─────────────────────────────────────────────────────────────
-- 4) seed แม่แบบ (ข้อ 11.2 — D10: ใช้ราคาตามตาราง) ใส่เฉพาะตอนตารางว่าง
-- ─────────────────────────────────────────────────────────────
INSERT INTO public.option_templates
  (store_type, name, min_selection, max_selection, options, match_keywords, exclude_keywords, sort_order)
SELECT * FROM (VALUES
  ('cafe', 'ระดับความหวาน', 1, 1,
   '[{"label":"ไม่หวาน","price":0},{"label":"หวานน้อย","price":0},{"label":"หวานปกติ","price":0},{"label":"หวานมาก","price":0}]'::jsonb,
   ARRAY['กาแฟ','ชา','นม','โกโก้','มัทฉะ','ปั่น','สมูทตี้','ลาเต้','คาปูชิโน่','มอคค่า','coffee','tea','latte','cocoa','matcha'],
   ARRAY['อเมริกาโน่','americano','เอสเพรสโซ่','espresso','น้ำเปล่า'], 10),
  ('cafe', 'ท็อปปิ้ง', 0, 3,
   '[{"label":"ไข่มุก","price":10},{"label":"บุก","price":10},{"label":"วิปครีม","price":10}]'::jsonb,
   ARRAY['ชา','นม','โกโก้','ปั่น','มัทฉะ','tea','cocoa','matcha'],
   ARRAY['กาแฟดำ','อเมริกาโน่','americano','เอสเพรสโซ่'], 20),
  ('cafe', 'เพิ่มช็อต / เปลี่ยนนม', 0, 2,
   '[{"label":"เพิ่มช็อต","price":15},{"label":"เปลี่ยนเป็นนมโอ๊ต","price":15}]'::jsonb,
   ARRAY['กาแฟ','ลาเต้','คาปูชิโน่','มอคค่า','อเมริกาโน่','เอสเพรสโซ่','coffee','latte','cappuccino','mocha','americano','espresso'],
   ARRAY[]::text[], 30),
  ('made_to_order', 'ระดับเผ็ด', 1, 1,
   '[{"label":"ไม่เผ็ด","price":0},{"label":"เผ็ดน้อย","price":0},{"label":"เผ็ดกลาง","price":0},{"label":"เผ็ดมาก","price":0}]'::jsonb,
   ARRAY['กะเพรา','กระเพรา','ผัด','แกง','ยำ','ต้มยำ','พริก','ลาบ'],
   ARRAY['ผัดซีอิ๊ว','ข้าวผัด','ไข่เจียว'], 10),
  ('made_to_order', 'ไข่', 0, 1,
   '[{"label":"ไข่ดาว","price":10},{"label":"ไข่เจียว","price":15},{"label":"ไข่ดาวไม่สุก","price":10}]'::jsonb,
   ARRAY['ข้าว','กะเพรา','กระเพรา','ราดข้าว'],
   ARRAY['ข้าวต้ม','ข้าวเหนียว','ไข่เจียว','ข้าวไข่'], 20),
  ('made_to_order', 'พิเศษ / เพิ่มข้าว', 0, 2,
   '[{"label":"พิเศษ","price":10},{"label":"เพิ่มข้าว","price":10}]'::jsonb,
   ARRAY['ข้าว','กะเพรา','กระเพรา','ราดข้าว','ผัด'],
   ARRAY['ข้าวต้ม','ข้าวเหนียว'], 30),
  ('noodle', 'เส้น', 1, 1,
   '[{"label":"เส้นเล็ก","price":0},{"label":"เส้นใหญ่","price":0},{"label":"เส้นหมี่","price":0},{"label":"บะหมี่","price":0},{"label":"วุ้นเส้น","price":0}]'::jsonb,
   ARRAY['ก๋วยเตี๋ยว','เย็นตาโฟ','บะหมี่','เส้น'],
   ARRAY['เกาเหลา'], 10),
  ('noodle', 'แบบน้ำ', 1, 1,
   '[{"label":"น้ำใส","price":0},{"label":"น้ำตก","price":0},{"label":"ต้มยำ","price":0},{"label":"แห้ง","price":0}]'::jsonb,
   ARRAY['ก๋วยเตี๋ยว'],
   ARRAY['เย็นตาโฟ','ผัด'], 20),
  ('noodle', 'พิเศษ', 0, 1,
   '[{"label":"พิเศษ","price":10}]'::jsonb,
   ARRAY['ก๋วยเตี๋ยว','เย็นตาโฟ','บะหมี่','เกาเหลา'],
   ARRAY[]::text[], 30),
  ('isan', 'พริก', 1, 1,
   '[{"label":"ไม่ใส่พริก","price":0},{"label":"พริก 1 เม็ด","price":0},{"label":"พริก 3 เม็ด","price":0},{"label":"พริก 5 เม็ดขึ้นไป","price":0}]'::jsonb,
   ARRAY['ตำ','ยำ','ลาบ','น้ำตก'],
   ARRAY['ไก่ย่าง','คอหมูย่าง','ข้าวเหนียว'], 10),
  ('isan', 'ใส่เพิ่ม', 0, 2,
   '[{"label":"ปูดอง","price":0},{"label":"ปลาร้า","price":0}]'::jsonb,
   ARRAY['ตำ'],
   ARRAY[]::text[], 20),
  ('dessert', 'ท็อปปิ้งเพิ่ม', 0, 1,
   '[{"label":"ท็อปปิ้งเพิ่ม","price":10}]'::jsonb,
   ARRAY['บิงซู','ไอศกรีม','ไอติม','โทสต์','ปังเย็น','bingsu'],
   ARRAY[]::text[], 10),
  ('dessert', 'อุ่น', 1, 1,
   '[{"label":"อุ่น","price":0},{"label":"ไม่อุ่น","price":0}]'::jsonb,
   ARRAY['เค้ก','ขนมปัง','ครัวซองต์','บราวนี่','cake','croissant','brownie'],
   ARRAY[]::text[], 20),
  ('other', 'ระดับเผ็ด', 1, 1,
   '[{"label":"ไม่เผ็ด","price":0},{"label":"เผ็ดน้อย","price":0},{"label":"เผ็ดกลาง","price":0},{"label":"เผ็ดมาก","price":0}]'::jsonb,
   ARRAY[]::text[],
   ARRAY[]::text[], 10)
) AS seed(store_type, name, min_selection, max_selection, options, match_keywords, exclude_keywords, sort_order)
WHERE NOT EXISTS (SELECT 1 FROM public.option_templates);

-- ─────────────────────────────────────────────────────────────
-- 5) helper
-- ─────────────────────────────────────────────────────────────

-- signature ของ option group เพื่อ dedupe/reuse: ชื่อ|min|max|label:price,...
CREATE OR REPLACE FUNCTION public.ai_menu_group_sig_json(
  p_name text, p_min integer, p_max integer, p_options jsonb)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT public.ai_menu_norm_name(p_name) || '|' || p_min || '|' || p_max || '|' ||
         coalesce((SELECT string_agg(public.ai_menu_norm_name(o->>'label') || ':' ||
                                     round(coalesce((o->>'price')::numeric, 0))::int, ','
                                     ORDER BY public.ai_menu_norm_name(o->>'label'))
                   FROM jsonb_array_elements(p_options) o), '');
$$;

CREATE OR REPLACE FUNCTION public.ai_menu_group_sig(p_group_id uuid)
RETURNS text
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT public.ai_menu_norm_name(g.name) || '|' || coalesce(g.min_selection, 0) || '|' ||
         coalesce(g.max_selection, 1) || '|' ||
         coalesce((SELECT string_agg(public.ai_menu_norm_name(o.name) || ':' || round(coalesce(o.price, 0))::int, ','
                                     ORDER BY public.ai_menu_norm_name(o.name))
                   FROM public.menu_options o WHERE o.group_id = g.id), '')
  FROM public.menu_option_groups g WHERE g.id = p_group_id;
$$;
REVOKE ALL ON FUNCTION public.ai_menu_group_sig(uuid) FROM PUBLIC, anon, authenticated;

-- สิทธิ์/โควตาของร้าน (ใช้ทั้งหน้าแอปและตอนสร้าง job)
CREATE OR REPLACE FUNCTION public.merchant_ai_import_status()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_profile record;
  v_mode text;
  v_enabled boolean;
  v_allow text;
  v_limit integer;
  v_used integer;
  v_extra record;
  v_active uuid;
  v_month_start timestamptz := (date_trunc('month', now() AT TIME ZONE 'Asia/Bangkok') AT TIME ZONE 'Asia/Bangkok');
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'not_authenticated');
  END IF;
  SELECT id, role, approval_status, merchant_service_types INTO v_profile
  FROM public.profiles WHERE id = v_uid;
  IF v_profile.id IS NULL OR v_profile.role <> 'merchant' THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'not_merchant');
  END IF;
  -- D6: ร้านซักรีดยังไม่ใช้ใน V1
  IF NOT ('food' = ANY (coalesce(v_profile.merchant_service_types, ARRAY[]::text[]))) THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'not_food_merchant');
  END IF;

  v_mode := CASE WHEN v_profile.approval_status = 'approved' THEN 'append' ELSE 'onboarding' END;
  v_enabled := lower(public.ai_import_cfg(
    CASE WHEN v_mode = 'append' THEN 'ai_menu_import_append_enabled'
         ELSE 'ai_menu_import_onboarding_enabled' END, 'false')) = 'true';
  v_allow := public.ai_import_cfg('ai_menu_import_allowlist', '');

  IF NOT v_enabled THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'disabled', 'mode', v_mode);
  END IF;
  IF v_allow <> '' AND NOT (v_uid::text = ANY (string_to_array(replace(v_allow, ' ', ''), ','))) THEN
    RETURN jsonb_build_object('allowed', false, 'reason', 'not_in_beta', 'mode', v_mode);
  END IF;

  SELECT coalesce(extra_onboarding, 0) AS eo, coalesce(extra_append_monthly, 0) AS ea
  INTO v_extra FROM public.merchant_ai_import_quota WHERE merchant_id = v_uid;

  IF v_mode = 'append' THEN
    v_limit := public.ai_import_cfg('ai_menu_import_quota_append_month', '5')::integer + coalesce(v_extra.ea, 0);
    SELECT count(*) INTO v_used FROM public.merchant_import_jobs
    WHERE merchant_id = v_uid AND mode = 'append' AND processed_at >= v_month_start;
  ELSE
    v_limit := public.ai_import_cfg('ai_menu_import_quota_onboarding', '3')::integer + coalesce(v_extra.eo, 0);
    SELECT count(*) INTO v_used FROM public.merchant_import_jobs
    WHERE merchant_id = v_uid AND mode = 'onboarding' AND processed_at IS NOT NULL;
  END IF;

  -- job ที่ค้าง queued/processing เกิน 15 นาที (worker ตาย) ไม่นับว่ากำลังทำงาน
  SELECT id INTO v_active FROM public.merchant_import_jobs
  WHERE merchant_id = v_uid AND status IN ('queued', 'processing')
    AND updated_at > now() - interval '15 minutes'
  ORDER BY created_at DESC LIMIT 1;

  RETURN jsonb_build_object(
    'allowed', v_used < v_limit,
    'reason', CASE WHEN v_used < v_limit THEN NULL ELSE 'quota_exceeded' END,
    'mode', v_mode,
    'quota_used', v_used,
    'quota_limit', v_limit,
    'active_job_id', v_active,
    'max_files', public.ai_import_cfg('ai_menu_import_max_files', '8')::integer);
END;
$$;
REVOKE ALL ON FUNCTION public.merchant_ai_import_status() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.merchant_ai_import_status() TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- 6) RPC ฝั่งร้าน
-- ─────────────────────────────────────────────────────────────

-- สร้าง job ใหม่ (สถานะ uploading) → client อัปโหลดรูปไป {uid}/{job_id}/n.jpg
CREATE OR REPLACE FUNCTION public.merchant_create_import_job(p_file_count integer)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_status jsonb;
  v_job_id uuid;
  v_max integer;
BEGIN
  v_status := public.merchant_ai_import_status();
  IF NOT coalesce((v_status->>'allowed')::boolean, false) THEN
    RAISE EXCEPTION 'ai_import_not_allowed:%', coalesce(v_status->>'reason', 'unknown');
  END IF;
  IF v_status->>'active_job_id' IS NOT NULL THEN
    RAISE EXCEPTION 'ai_import_job_in_progress';
  END IF;
  v_max := (v_status->>'max_files')::integer;
  IF p_file_count IS NULL OR p_file_count < 1 OR p_file_count > v_max THEN
    RAISE EXCEPTION 'ai_import_invalid_file_count';
  END IF;

  -- job ที่ค้าง queued/processing เกิน 15 นาที = worker ตาย → failed (ให้ลองใหม่ได้)
  UPDATE public.merchant_import_jobs
     SET status = 'failed', error = coalesce(error, 'stale_worker'), locked_at = NULL, updated_at = now()
   WHERE merchant_id = v_uid AND status IN ('queued', 'processing')
     AND updated_at < now() - interval '15 minutes';

  -- ทำได้ทีละ flow: job ที่ยังค้างขั้นอัปโหลด (ยังไม่ประมวลผล ไม่กินโควตา) ถือว่าทิ้งแล้ว
  UPDATE public.merchant_import_jobs
     SET status = 'cancelled', updated_at = now(), completed_at = now()
   WHERE merchant_id = v_uid AND status = 'uploading';

  INSERT INTO public.merchant_import_jobs (merchant_id, mode, total_files, existing_menu_count)
  VALUES (v_uid, v_status->>'mode', p_file_count,
          (SELECT count(*) FROM public.menu_items WHERE merchant_id = v_uid))
  RETURNING id INTO v_job_id;

  INSERT INTO public.merchant_import_audit (import_job_id, actor_id, action, diff)
  VALUES (v_job_id, v_uid, 'create_job', jsonb_build_object('files', p_file_count, 'mode', v_status->>'mode'));

  RETURN jsonb_build_object('job_id', v_job_id, 'mode', v_status->>'mode',
                            'upload_prefix', v_uid::text || '/' || v_job_id::text || '/');
END;
$$;
REVOKE ALL ON FUNCTION public.merchant_create_import_job(integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.merchant_create_import_job(integer) TO authenticated;

-- ตรวจ/แก้รายการ
-- p_action: approve | edit | reject | restore | choose_price | skip | create
CREATE OR REPLACE FUNCTION public.merchant_review_import_item(
  p_item_id uuid, p_action text, p_patch jsonb DEFAULT '{}'::jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_item public.merchant_import_items;
  v_job public.merchant_import_jobs;
  v_name text;
  v_price numeric;
  v_before jsonb;
BEGIN
  SELECT * INTO v_item FROM public.merchant_import_items WHERE id = p_item_id FOR UPDATE;
  IF v_item.id IS NULL THEN RAISE EXCEPTION 'ai_import_item_not_found'; END IF;
  SELECT * INTO v_job FROM public.merchant_import_jobs WHERE id = v_item.import_job_id;
  IF v_job.merchant_id IS DISTINCT FROM v_uid THEN RAISE EXCEPTION 'ai_import_forbidden'; END IF;
  IF v_job.status NOT IN ('review_required', 'ready') THEN
    RAISE EXCEPTION 'ai_import_job_not_editable';
  END IF;
  v_before := to_jsonb(v_item);
  p_patch := coalesce(p_patch, '{}'::jsonb);

  IF p_action = 'approve' THEN
    IF 'price_conflict' = ANY (v_item.issues) THEN
      RAISE EXCEPTION 'ai_import_price_conflict_unresolved';
    END IF;
    IF v_item.price IS NULL OR v_item.price <= 0 THEN
      RAISE EXCEPTION 'ai_import_price_required';
    END IF;
    UPDATE public.merchant_import_items SET status = 'approved', updated_at = now() WHERE id = p_item_id;

  ELSIF p_action IN ('edit', 'choose_price') THEN
    v_name := CASE WHEN p_patch ? 'name' THEN btrim(p_patch->>'name') ELSE v_item.name END;
    v_price := CASE WHEN p_patch ? 'price' THEN (p_patch->>'price')::numeric ELSE v_item.price END;
    IF v_name IS NULL OR v_name = '' OR length(v_name) > 120 THEN
      RAISE EXCEPTION 'ai_import_invalid_name';
    END IF;
    IF v_price IS NULL OR v_price <= 0 OR v_price > 100000 THEN
      RAISE EXCEPTION 'ai_import_invalid_price';
    END IF;
    IF p_patch ? 'variants_json' AND jsonb_typeof(p_patch->'variants_json') <> 'array' THEN
      RAISE EXCEPTION 'ai_import_invalid_variants';
    END IF;
    IF p_patch ? 'addons_json' AND jsonb_typeof(p_patch->'addons_json') <> 'array' THEN
      RAISE EXCEPTION 'ai_import_invalid_addons';
    END IF;
    IF p_action = 'choose_price' AND NOT (p_patch ? 'price') THEN
      RAISE EXCEPTION 'ai_import_price_required';
    END IF;
    UPDATE public.merchant_import_items
       SET name = v_name,
           price = round(v_price),
           category = CASE WHEN p_patch ? 'category' THEN nullif(btrim(p_patch->>'category'), '') ELSE category END,
           description = CASE WHEN p_patch ? 'description' THEN nullif(btrim(p_patch->>'description'), '') ELSE description END,
           variant_group = CASE WHEN p_patch ? 'variant_group' THEN nullif(btrim(p_patch->>'variant_group'), '') ELSE variant_group END,
           variants_json = CASE WHEN p_patch ? 'variants_json' THEN p_patch->'variants_json' ELSE variants_json END,
           addons_json = CASE WHEN p_patch ? 'addons_json' THEN p_patch->'addons_json' ELSE addons_json END,
           issues = '{}',
           conflict_json = NULL,
           status = 'edited',
           updated_at = now()
     WHERE id = p_item_id;

  ELSIF p_action = 'reject' THEN
    UPDATE public.merchant_import_items SET status = 'rejected', updated_at = now() WHERE id = p_item_id;
  ELSIF p_action = 'restore' THEN
    UPDATE public.merchant_import_items SET status = 'draft', updated_at = now() WHERE id = p_item_id;
  ELSIF p_action = 'skip' THEN
    UPDATE public.merchant_import_items SET action = 'skip', updated_at = now() WHERE id = p_item_id;
  ELSIF p_action = 'create' THEN
    -- รายการที่ชื่อ+ราคาตรงเมนูเดิม เพิ่มซ้ำไม่ได้
    IF v_item.match_type = 'exact_dup' THEN
      RAISE EXCEPTION 'ai_import_duplicate_item';
    END IF;
    UPDATE public.merchant_import_items SET action = 'create', updated_at = now() WHERE id = p_item_id;
  ELSE
    RAISE EXCEPTION 'ai_import_invalid_action';
  END IF;

  INSERT INTO public.merchant_import_audit (import_job_id, actor_id, action, item_id, diff)
  SELECT v_job.id, v_uid, 'item_' || p_action, p_item_id,
         jsonb_build_object('before', v_before - 'created_at' - 'updated_at',
                            'after', to_jsonb(i) - 'created_at' - 'updated_at')
  FROM public.merchant_import_items i WHERE i.id = p_item_id;

  RETURN (SELECT to_jsonb(i) FROM public.merchant_import_items i WHERE i.id = p_item_id);
END;
$$;
REVOKE ALL ON FUNCTION public.merchant_review_import_item(uuid, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.merchant_review_import_item(uuid, text, jsonb) TO authenticated;

-- อนุมัติทั้งหมดที่ "พร้อม" (ไม่มี issue, จะสร้าง, ยังเป็น draft)
CREATE OR REPLACE FUNCTION public.merchant_bulk_approve_import(p_job_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_job public.merchant_import_jobs;
  v_count integer;
BEGIN
  SELECT * INTO v_job FROM public.merchant_import_jobs WHERE id = p_job_id FOR UPDATE;
  IF v_job.merchant_id IS DISTINCT FROM v_uid THEN RAISE EXCEPTION 'ai_import_forbidden'; END IF;
  IF v_job.status NOT IN ('review_required', 'ready') THEN RAISE EXCEPTION 'ai_import_job_not_editable'; END IF;

  UPDATE public.merchant_import_items
     SET status = 'approved', updated_at = now()
   WHERE import_job_id = p_job_id AND status = 'draft' AND action = 'create'
     AND cardinality(issues) = 0 AND price IS NOT NULL AND price > 0;
  GET DIAGNOSTICS v_count = ROW_COUNT;

  INSERT INTO public.merchant_import_audit (import_job_id, actor_id, action, diff)
  VALUES (p_job_id, v_uid, 'bulk_approve', jsonb_build_object('count', v_count));
  RETURN v_count;
END;
$$;
REVOKE ALL ON FUNCTION public.merchant_bulk_approve_import(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.merchant_bulk_approve_import(uuid) TO authenticated;

-- บันทึกชุดตัวเลือกแนะนำที่ร้านเลือก (แทนที่ทั้งชุด)
-- p_selections: [{template_id, name, min_selection, max_selection, options:[{label,price}], import_item_ids:[uuid]}]
CREATE OR REPLACE FUNCTION public.merchant_save_template_selections(
  p_job_id uuid, p_store_type text, p_selections jsonb)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_job public.merchant_import_jobs;
  v_sel jsonb;
  v_opt jsonb;
  v_ids uuid[];
  v_min integer;
  v_max integer;
  v_n integer := 0;
  v_tpl public.option_templates;
BEGIN
  SELECT * INTO v_job FROM public.merchant_import_jobs WHERE id = p_job_id FOR UPDATE;
  IF v_job.merchant_id IS DISTINCT FROM v_uid THEN RAISE EXCEPTION 'ai_import_forbidden'; END IF;
  IF v_job.status NOT IN ('review_required', 'ready') THEN RAISE EXCEPTION 'ai_import_job_not_editable'; END IF;
  IF p_store_type IS NOT NULL AND p_store_type NOT IN ('cafe', 'made_to_order', 'noodle', 'isan', 'dessert', 'other') THEN
    RAISE EXCEPTION 'ai_import_invalid_store_type';
  END IF;
  IF p_selections IS NULL OR jsonb_typeof(p_selections) <> 'array' THEN
    RAISE EXCEPTION 'ai_import_invalid_selections';
  END IF;

  UPDATE public.merchant_import_jobs SET store_type = p_store_type, updated_at = now() WHERE id = p_job_id;
  DELETE FROM public.merchant_import_template_selections WHERE import_job_id = p_job_id;

  FOR v_sel IN SELECT * FROM jsonb_array_elements(p_selections) LOOP
    v_tpl := NULL;
    IF nullif(v_sel->>'template_id', '') IS NOT NULL THEN
      SELECT * INTO v_tpl FROM public.option_templates
      WHERE id = (v_sel->>'template_id')::uuid AND is_active;
    END IF;
    IF btrim(coalesce(v_sel->>'name', '')) = '' OR length(v_sel->>'name') > 80 THEN
      RAISE EXCEPTION 'ai_import_invalid_selection_name';
    END IF;
    IF jsonb_typeof(v_sel->'options') <> 'array' OR jsonb_array_length(v_sel->'options') = 0
       OR jsonb_array_length(v_sel->'options') > 30 THEN
      RAISE EXCEPTION 'ai_import_invalid_selection_options';
    END IF;
    FOR v_opt IN SELECT * FROM jsonb_array_elements(v_sel->'options') LOOP
      IF btrim(coalesce(v_opt->>'label', '')) = ''
         OR coalesce((v_opt->>'price')::numeric, -1) < 0
         OR (v_opt->>'price')::numeric > 10000 THEN
        RAISE EXCEPTION 'ai_import_invalid_selection_option';
      END IF;
    END LOOP;
    v_min := coalesce((v_sel->>'min_selection')::integer, 0);
    v_max := coalesce((v_sel->>'max_selection')::integer, 1);
    IF v_min < 0 OR v_max < 1 OR v_min > v_max OR v_max > jsonb_array_length(v_sel->'options') THEN
      RAISE EXCEPTION 'ai_import_invalid_selection_minmax';
    END IF;
    SELECT coalesce(array_agg(x::uuid), '{}') INTO v_ids
    FROM jsonb_array_elements_text(coalesce(v_sel->'import_item_ids', '[]'::jsonb)) x;
    IF cardinality(v_ids) = 0 THEN CONTINUE; END IF;
    IF EXISTS (SELECT 1 FROM unnest(v_ids) u(id)
               WHERE NOT EXISTS (SELECT 1 FROM public.merchant_import_items i
                                 WHERE i.id = u.id AND i.import_job_id = p_job_id)) THEN
      RAISE EXCEPTION 'ai_import_selection_item_not_in_job';
    END IF;

    INSERT INTO public.merchant_import_template_selections
      (import_job_id, template_id, template_version, name, min_selection, max_selection,
       options, import_item_ids, sort_order)
    VALUES (p_job_id, v_tpl.id, v_tpl.version, btrim(v_sel->>'name'), v_min, v_max,
            (SELECT jsonb_agg(jsonb_build_object('label', btrim(o->>'label'),
                                                 'price', round((o->>'price')::numeric)::int))
             FROM jsonb_array_elements(v_sel->'options') o),
            v_ids, v_n);
    v_n := v_n + 1;
  END LOOP;

  INSERT INTO public.merchant_import_audit (import_job_id, actor_id, action, diff)
  VALUES (p_job_id, v_uid, 'save_template_selections',
          jsonb_build_object('store_type', p_store_type, 'count', v_n, 'selections', p_selections));
  RETURN v_n;
END;
$$;
REVOKE ALL ON FUNCTION public.merchant_save_template_selections(uuid, text, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.merchant_save_template_selections(uuid, text, jsonb) TO authenticated;

-- ยกเลิก job ที่ยังไม่ publish
CREATE OR REPLACE FUNCTION public.merchant_cancel_import_job(p_job_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_job public.merchant_import_jobs;
BEGIN
  SELECT * INTO v_job FROM public.merchant_import_jobs WHERE id = p_job_id FOR UPDATE;
  IF v_job.merchant_id IS DISTINCT FROM auth.uid() THEN RAISE EXCEPTION 'ai_import_forbidden'; END IF;
  IF v_job.status IN ('published', 'publishing', 'cancelled') THEN RETURN; END IF;
  UPDATE public.merchant_import_jobs
     SET status = 'cancelled', updated_at = now(), completed_at = coalesce(completed_at, now())
   WHERE id = p_job_id;
  INSERT INTO public.merchant_import_audit (import_job_id, actor_id, action)
  VALUES (p_job_id, auth.uid(), 'cancel_job');
END;
$$;
REVOKE ALL ON FUNCTION public.merchant_cancel_import_job(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.merchant_cancel_import_job(uuid) TO authenticated;

-- ─────────────────────────────────────────────────────────────
-- 7) Publish — transaction เดียว, idempotent, insert-only
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.merchant_publish_import(
  p_job_id uuid, p_visibility text DEFAULT 'hidden', p_confirmed boolean DEFAULT false)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid uuid := auth.uid();
  v_job public.merchant_import_jobs;
  v_item public.merchant_import_items;
  v_sel public.merchant_import_template_selections;
  v_profile record;
  v_cat_key text;
  v_cat_id uuid;
  v_cat_map jsonb := '{}'::jsonb;         -- norm(category) -> category_id
  v_item_map jsonb := '{}'::jsonb;        -- import_item_id -> menu_item_id
  v_sig_map jsonb := '{}'::jsonb;         -- signature -> group_id
  v_defs jsonb := '[]'::jsonb;            -- [{name,min,max,options,item_ids}]
  v_def jsonb;
  v_sig text;
  v_group_id uuid;
  v_opt jsonb;
  v_menu_id uuid;
  v_sort integer;
  v_cat_sort integer;
  v_dups jsonb;
  v_created_items integer := 0;
  v_created_groups integer := 0;
  v_reused_groups integer := 0;
  v_created_cats integer := 0;
  v_links integer := 0;
  v_addon_group record;
  v_link_item text;
BEGIN
  SELECT * INTO v_job FROM public.merchant_import_jobs WHERE id = p_job_id FOR UPDATE;
  IF v_job.id IS NULL THEN RAISE EXCEPTION 'ai_import_job_not_found'; END IF;
  IF v_job.merchant_id IS DISTINCT FROM v_uid THEN RAISE EXCEPTION 'ai_import_forbidden'; END IF;

  -- idempotent: publish ซ้ำคืนผลเดิม ไม่สร้างซ้ำ
  IF v_job.status = 'published' THEN
    RETURN jsonb_build_object('ok', true, 'already_published', true,
      'created_items', (SELECT count(*) FROM public.merchant_import_items
                        WHERE import_job_id = p_job_id AND status = 'published'));
  END IF;
  IF v_job.status NOT IN ('review_required', 'ready') THEN
    RAISE EXCEPTION 'ai_import_job_not_publishable';
  END IF;
  IF p_visibility NOT IN ('hidden', 'live') THEN RAISE EXCEPTION 'ai_import_invalid_visibility'; END IF;
  IF NOT coalesce(p_confirmed, false) THEN RAISE EXCEPTION 'ai_import_confirm_required'; END IF;

  -- กันกด publish จากหลายเครื่องพร้อมกันต่อร้าน
  PERFORM pg_advisory_xact_lock(hashtext('ai_menu_publish:' || v_uid::text));

  IF EXISTS (SELECT 1 FROM public.merchant_import_items
             WHERE import_job_id = p_job_id AND action = 'create'
               AND status NOT IN ('approved', 'edited', 'rejected')) THEN
    RAISE EXCEPTION 'ai_import_items_pending_review';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.merchant_import_items
                 WHERE import_job_id = p_job_id AND action = 'create'
                   AND status IN ('approved', 'edited')) THEN
    RAISE EXCEPTION 'ai_import_nothing_to_publish';
  END IF;

  -- ชื่อซ้ำกันเองภายใน job
  IF EXISTS (SELECT 1 FROM public.merchant_import_items
             WHERE import_job_id = p_job_id AND action = 'create' AND status IN ('approved', 'edited')
             GROUP BY public.ai_menu_norm_name(name) HAVING count(*) > 1) THEN
    RAISE EXCEPTION 'ai_import_duplicate_in_import';
  END IF;

  -- เทียบซ้ำอีกรอบกับเมนูปัจจุบัน (ร้านอาจเพิ่มเองระหว่าง review)
  -- เจอ → ติดป้าย + ตั้งเป็นข้าม แล้วคืนให้ร้านกลับไปตรวจ (ยังไม่สร้างอะไร)
  WITH d AS (
    SELECT i.id, m.id AS menu_id, m.price AS menu_price,
           CASE WHEN round(m.price::numeric) = round(i.price) THEN 'exact_dup' ELSE 'price_changed' END AS mt
    FROM public.merchant_import_items i
    JOIN LATERAL (
      SELECT mi.id, mi.price FROM public.menu_items mi
      WHERE mi.merchant_id = v_uid
        AND public.ai_menu_norm_name(mi.name) = public.ai_menu_norm_name(i.name)
      ORDER BY mi.created_at DESC LIMIT 1) m ON true
    WHERE i.import_job_id = p_job_id AND i.action = 'create' AND i.status IN ('approved', 'edited')
  ), u AS (
    UPDATE public.merchant_import_items i
       SET match_type = d.mt, matched_menu_item_id = d.menu_id, matched_price = d.menu_price,
           action = 'skip', updated_at = now()
      FROM d WHERE i.id = d.id
    RETURNING i.name
  )
  SELECT jsonb_agg(name) INTO v_dups FROM u;
  IF v_dups IS NOT NULL THEN
    INSERT INTO public.merchant_import_audit (import_job_id, actor_id, action, diff)
    VALUES (p_job_id, v_uid, 'publish_blocked_duplicates', jsonb_build_object('names', v_dups));
    RETURN jsonb_build_object('ok', false, 'reason', 'duplicates_found', 'names', v_dups);
  END IF;

  UPDATE public.merchant_import_jobs SET status = 'publishing', updated_at = now() WHERE id = p_job_id;

  SELECT coalesce(max(sort_order), 0) INTO v_sort FROM public.menu_items WHERE merchant_id = v_uid;
  SELECT coalesce(max(sort_order), 0) INTO v_cat_sort FROM public.menu_categories WHERE merchant_id = v_uid;

  -- (1) หมวด + เมนู
  FOR v_item IN
    SELECT * FROM public.merchant_import_items
    WHERE import_job_id = p_job_id AND action = 'create' AND status IN ('approved', 'edited')
    ORDER BY sort_order, created_at
  LOOP
    v_cat_key := public.ai_menu_norm_name(coalesce(nullif(btrim(v_item.category), ''), 'อื่นๆ'));
    IF v_cat_map ? v_cat_key THEN
      v_cat_id := (v_cat_map->>v_cat_key)::uuid;
    ELSE
      SELECT id INTO v_cat_id FROM public.menu_categories
      WHERE merchant_id = v_uid AND public.ai_menu_norm_name(name) = v_cat_key
      ORDER BY sort_order LIMIT 1;
      IF v_cat_id IS NULL THEN
        v_cat_sort := v_cat_sort + 1;
        INSERT INTO public.menu_categories (merchant_id, name, sort_order)
        VALUES (v_uid, coalesce(nullif(btrim(v_item.category), ''), 'อื่นๆ'), v_cat_sort)
        RETURNING id INTO v_cat_id;
        v_created_cats := v_created_cats + 1;
      END IF;
      v_cat_map := v_cat_map || jsonb_build_object(v_cat_key, v_cat_id);
    END IF;

    v_sort := v_sort + 1;
    INSERT INTO public.menu_items
      (merchant_id, name, description, price, category, category_id, is_available,
       sort_order, source_import_job_id)
    VALUES
      (v_uid, btrim(v_item.name), v_item.description, round(v_item.price),
       (SELECT name FROM public.menu_categories WHERE id = v_cat_id), v_cat_id,
       p_visibility = 'live', v_sort, p_job_id)
    RETURNING id INTO v_menu_id;

    UPDATE public.merchant_import_items
       SET status = 'published', published_menu_item_id = v_menu_id, updated_at = now()
     WHERE id = v_item.id;
    v_item_map := v_item_map || jsonb_build_object(v_item.id::text, v_menu_id);
    v_created_items := v_created_items + 1;

    -- variants → กลุ่มต้องเลือก 1 (ราคา = ส่วนต่างจากราคาเมนู)
    IF jsonb_typeof(v_item.variants_json) = 'array' AND jsonb_array_length(v_item.variants_json) >= 2 THEN
      v_defs := v_defs || jsonb_build_array(jsonb_build_object(
        'name', coalesce(nullif(btrim(v_item.variant_group), ''), 'ตัวเลือก'),
        'min', 1, 'max', 1,
        'options', (SELECT jsonb_agg(jsonb_build_object(
                       'label', btrim(v->>'label'),
                       'price', greatest(0, round(coalesce((v->>'price')::numeric, v_item.price) - v_item.price))::int))
                    FROM jsonb_array_elements(v_item.variants_json) v
                    WHERE btrim(coalesce(v->>'label', '')) <> ''),
        'item_ids', jsonb_build_array(v_item.id)));
    END IF;

    -- add-ons → กลุ่มไม่บังคับ ตามชื่อกลุ่ม
    IF jsonb_typeof(v_item.addons_json) = 'array' AND jsonb_array_length(v_item.addons_json) > 0 THEN
      FOR v_addon_group IN
        SELECT coalesce(nullif(btrim(a->>'group'), ''), 'เพิ่มเติม') AS gname,
               jsonb_agg(jsonb_build_object(
                 'label', btrim(a->>'label'),
                 'price', greatest(0, round(coalesce((a->>'price_delta')::numeric, 0)))::int)) AS opts
        FROM jsonb_array_elements(v_item.addons_json) a
        WHERE btrim(coalesce(a->>'label', '')) <> ''
        GROUP BY 1
      LOOP
        v_defs := v_defs || jsonb_build_array(jsonb_build_object(
          'name', v_addon_group.gname, 'min', 0,
          'max', jsonb_array_length(v_addon_group.opts),
          'options', v_addon_group.opts,
          'item_ids', jsonb_build_array(v_item.id)));
      END LOOP;
    END IF;
  END LOOP;

  -- (2) ชุดตัวเลือกแนะนำที่ร้านเลือก
  FOR v_sel IN
    SELECT * FROM public.merchant_import_template_selections
    WHERE import_job_id = p_job_id ORDER BY sort_order
  LOOP
    v_defs := v_defs || jsonb_build_array(jsonb_build_object(
      'name', v_sel.name, 'min', v_sel.min_selection, 'max', v_sel.max_selection,
      'options', v_sel.options, 'item_ids', to_jsonb(v_sel.import_item_ids),
      'template_id', v_sel.template_id, 'template_version', v_sel.template_version));
  END LOOP;

  -- (3) สร้าง/ใช้ซ้ำ option group แล้วผูกกับเมนู
  FOR v_def IN SELECT * FROM jsonb_array_elements(v_defs) LOOP
    CONTINUE WHEN v_def->'options' IS NULL OR jsonb_typeof(v_def->'options') <> 'array'
                  OR jsonb_array_length(v_def->'options') = 0;
    -- ไม่สร้างกลุ่มที่ไม่มีเมนูไหนถูกสร้างจริง (ผูกกับรายการที่ข้าม/ไม่ใช้ทั้งหมด)
    CONTINUE WHEN NOT EXISTS (SELECT 1 FROM jsonb_array_elements_text(v_def->'item_ids') x
                              WHERE v_item_map ? x);
    v_sig := public.ai_menu_group_sig_json(v_def->>'name', (v_def->>'min')::int,
                                           least((v_def->>'max')::int, jsonb_array_length(v_def->'options')),
                                           v_def->'options');
    IF v_sig_map ? v_sig THEN
      v_group_id := (v_sig_map->>v_sig)::uuid;
    ELSE
      -- ใช้ group เดิมในคลังของร้านเมื่อค่าตรงทุกค่า (ไม่แก้ group เดิม)
      SELECT g.id INTO v_group_id FROM public.menu_option_groups g
      WHERE g.merchant_id = v_uid AND g.source = 'jdc'
        AND public.ai_menu_norm_name(g.name) = public.ai_menu_norm_name(v_def->>'name')
        AND public.ai_menu_group_sig(g.id) = v_sig
      ORDER BY g.created_at LIMIT 1;
      IF v_group_id IS NULL THEN
        INSERT INTO public.menu_option_groups (merchant_id, name, min_selection, max_selection)
        VALUES (v_uid, btrim(v_def->>'name'), (v_def->>'min')::int,
                greatest(1, least((v_def->>'max')::int, jsonb_array_length(v_def->'options'))))
        RETURNING id INTO v_group_id;
        INSERT INTO public.menu_options (group_id, name, price)
        SELECT v_group_id, btrim(o->>'label'), greatest(0, round(coalesce((o->>'price')::numeric, 0)))::int
        FROM jsonb_array_elements(v_def->'options') o;
        v_created_groups := v_created_groups + 1;
      ELSE
        v_reused_groups := v_reused_groups + 1;
      END IF;
      v_sig_map := v_sig_map || jsonb_build_object(v_sig, v_group_id);
    END IF;

    FOR v_link_item IN SELECT * FROM jsonb_array_elements_text(v_def->'item_ids') LOOP
      CONTINUE WHEN NOT (v_item_map ? v_link_item);   -- รายการที่ถูกข้าม/ไม่ใช้
      INSERT INTO public.menu_item_option_links (menu_item_id, option_group_id, sort_order)
      VALUES ((v_item_map->>v_link_item)::uuid, v_group_id,
              (SELECT count(*) FROM public.menu_item_option_links
               WHERE menu_item_id = (v_item_map->>v_link_item)::uuid))
      ON CONFLICT (menu_item_id, option_group_id) DO NOTHING;
      v_links := v_links + 1;
    END LOOP;
  END LOOP;

  UPDATE public.merchant_import_jobs
     SET status = 'published', visibility = p_visibility, published_at = now(),
         completed_at = now(), updated_at = now()
   WHERE id = p_job_id;

  INSERT INTO public.merchant_import_audit (import_job_id, actor_id, action, diff)
  VALUES (p_job_id, v_uid, 'publish', jsonb_build_object(
    'visibility', p_visibility, 'items', v_created_items, 'groups_created', v_created_groups,
    'groups_reused', v_reused_groups, 'categories_created', v_created_cats, 'links', v_links));

  -- ร้านที่อนุมัติแล้ว: เมนูถึงลูกค้าโดยไม่มีแอดมินกั้น → แจ้งแอดมิน
  SELECT full_name, approval_status INTO v_profile FROM public.profiles WHERE id = v_uid;
  IF v_profile.approval_status = 'approved' THEN
    BEGIN
      PERFORM public.notify_admins(
        'ร้านเพิ่มเมนูด้วย AI',
        coalesce(v_profile.full_name, 'ร้านค้า') || ' เพิ่ม ' || v_created_items || ' เมนู (' ||
          CASE WHEN p_visibility = 'live' THEN 'เปิดขายทันที' ELSE 'ซ่อนไว้ก่อน' END || ')',
        'ai_menu_import',
        jsonb_build_object('import_job_id', p_job_id, 'merchant_id', v_uid,
                           'items', v_created_items, 'visibility', p_visibility));
    EXCEPTION WHEN others THEN
      RAISE WARNING 'notify_admins failed for ai import %: %', p_job_id, SQLERRM;
    END;
  END IF;

  RETURN jsonb_build_object('ok', true, 'created_items', v_created_items,
    'created_groups', v_created_groups, 'reused_groups', v_reused_groups,
    'created_categories', v_created_cats, 'visibility', p_visibility);
END;
$$;
REVOKE ALL ON FUNCTION public.merchant_publish_import(uuid, text, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.merchant_publish_import(uuid, text, boolean) TO authenticated;

-- ซ่อนเมนูทั้งชุดที่มาจาก import นี้ (ไม่ลบ ไม่กระทบออเดอร์เก่า) — ร้านเจ้าของหรือแอดมิน
CREATE OR REPLACE FUNCTION public.merchant_hide_import_items(p_job_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_job public.merchant_import_jobs;
  v_count integer;
BEGIN
  SELECT * INTO v_job FROM public.merchant_import_jobs WHERE id = p_job_id FOR UPDATE;
  IF v_job.id IS NULL THEN RAISE EXCEPTION 'ai_import_job_not_found'; END IF;
  IF v_job.merchant_id IS DISTINCT FROM auth.uid() AND NOT public.is_admin() THEN
    RAISE EXCEPTION 'ai_import_forbidden';
  END IF;
  UPDATE public.menu_items
     SET is_available = false, updated_at = now()
   WHERE source_import_job_id = p_job_id AND merchant_id = v_job.merchant_id AND is_available;
  GET DIAGNOSTICS v_count = ROW_COUNT;
  UPDATE public.merchant_import_jobs SET hidden_at = now(), updated_at = now() WHERE id = p_job_id;
  INSERT INTO public.merchant_import_audit (import_job_id, actor_id, action, diff)
  VALUES (p_job_id, auth.uid(), 'hide_items', jsonb_build_object('count', v_count));
  RETURN v_count;
END;
$$;
REVOKE ALL ON FUNCTION public.merchant_hide_import_items(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.merchant_hide_import_items(uuid) TO authenticated;
