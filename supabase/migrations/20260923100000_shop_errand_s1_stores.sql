-- ═══════════════════════════════════════════════════════════════
-- ฝากซื้อ/ฝากหิ้ว — S1: ร้านค้าที่แอดมินคุม + เวลาเปิดปิด + ค้นหาตามรัศมี
-- อ้างอิงแผน: Plan/Shop_Errand_Service_Feature_Plan_v4.html หัวข้อ 1-3
--
-- หลักการ:
--   * ตำแหน่งร้าน/เวลาเปิดปิด = แอดมินตั้งเท่านั้น ลูกค้า+คนขับ SELECT อย่างเดียว
--   * is_open_now คำนวณที่ server เสมอ (นาฬิกาเครื่อง client เชื่อไม่ได้)
--   * เวลาทั้งหมดเทียบ Asia/Bangkok (บทเรียน coupon timezone Batch 2)
--   * รองรับปิดพักกลางวัน (หลายช่วงต่อวัน) + ร้านข้ามเที่ยงคืน (close <= open)
--
-- หมายเหตุ: public.is_admin() มีอยู่บน production แล้ว (migration เดิมหลายไฟล์ใช้อยู่)
-- ═══════════════════════════════════════════════════════════════

BEGIN;

-- ─────────────────────────────────────────────────────────────
-- 0) helper อ่าน system_config แบบ key/value
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.shop_config_num(p_key text, p_fallback numeric)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_raw text;
  v_num numeric;
BEGIN
  SELECT max(value) INTO v_raw FROM public.system_config WHERE key = p_key;
  IF v_raw IS NULL OR btrim(v_raw) = '' THEN
    RETURN p_fallback;
  END IF;
  BEGIN
    v_num := btrim(v_raw)::numeric;
  EXCEPTION WHEN others THEN
    RETURN p_fallback;
  END;
  RETURN v_num;
END;
$$;

-- คืน NULL ได้ (สำหรับ config ที่ "ยังไม่กำหนด" เช่น เพดานค่าวิ่งไกล)
CREATE OR REPLACE FUNCTION public.shop_config_num_nullable(p_key text)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_raw text;
  v_num numeric;
BEGIN
  SELECT max(value) INTO v_raw FROM public.system_config WHERE key = p_key;
  IF v_raw IS NULL OR btrim(v_raw) = '' OR lower(btrim(v_raw)) = 'null' THEN
    RETURN NULL;
  END IF;
  BEGIN
    v_num := btrim(v_raw)::numeric;
  EXCEPTION WHEN others THEN
    RETURN NULL;
  END;
  RETURN v_num;
END;
$$;

CREATE OR REPLACE FUNCTION public.shop_config_bool(p_key text, p_fallback boolean)
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_raw text;
BEGIN
  SELECT max(value) INTO v_raw FROM public.system_config WHERE key = p_key;
  IF v_raw IS NULL OR btrim(v_raw) = '' THEN
    RETURN p_fallback;
  END IF;
  RETURN lower(btrim(v_raw)) IN ('true', 't', '1', 'yes');
END;
$$;

CREATE OR REPLACE FUNCTION public.shop_config_json(p_key text, p_fallback jsonb)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_raw text;
  v_json jsonb;
BEGIN
  SELECT max(value) INTO v_raw FROM public.system_config WHERE key = p_key;
  IF v_raw IS NULL OR btrim(v_raw) = '' THEN
    RETURN p_fallback;
  END IF;
  BEGIN
    v_json := btrim(v_raw)::jsonb;
  EXCEPTION WHEN others THEN
    RETURN p_fallback;
  END;
  RETURN v_json;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- 1) seed config ของฝากซื้อ (ไม่ทับค่าที่แอดมินตั้งไว้แล้ว)
-- ─────────────────────────────────────────────────────────────
INSERT INTO public.system_config (key, value)
VALUES
  -- เปิด/ปิดบริการ — ปล่อย false ตอน deploy เปิดเมื่อพร้อม (ต้องมีร้านก่อน)
  ('shop_enabled',                      'false'),
  ('shop_ai_receipt_enabled',           'false'),
  -- ร้าน
  ('shop_store_radius_km',              '10'),
  ('shop_store_radius_max_km',          '25'),
  ('shop_show_closed_stores',           'true'),
  -- geofence ถึงร้าน (150 = ให้ผ่อนเท่ากับ effective radius สูงสุดของ client 100+50)
  ('shop_arrival_radius_m',             '150'),
  ('shop_location_freshness_sec',       '120'),
  ('shop_arrival_geofence_enabled',     'true'),
  -- ค่าบริการ
  ('shop_fee_percent',                  '10'),
  ('shop_fee_tiers',                    '[{"max":500,"fee":30},{"max":1500,"fee":50},{"max":null,"fee":80}]'),
  ('shop_fee_min',                      '25'),
  ('shop_fee_max',                      '200'),
  ('shop_fee_multiplier_by_category',   '{"grocery":1.0,"mall":1.0,"market":1.0,"convenience":1.0,"pharmacy":1.0}'),
  ('shop_driver_share_percent',         '80'),
  -- วงเงิน
  ('shop_min_budget',                   '100'),
  ('shop_max_budget',                   '5000'),
  ('shop_new_driver_max_budget',        '500'),
  ('shop_new_driver_completed_jobs',    '20'),
  ('shop_budget_buffer_percent',        '15'),
  ('shop_max_items',                    '30'),
  -- คนขับ/ระยะ  (เพดาน 2 ตัวนี้ "ยังไม่กำหนด" ตามที่ผู้ใช้สั่ง = ไม่จำกัด)
  ('shop_driver_to_store_km',           '20'),
  ('shop_far_pickup_enabled',           'true'),
  ('shop_far_pickup_rate_per_km_motorcycle', '5'),
  ('shop_far_pickup_rate_per_km_car',   '8'),
  ('shop_far_pickup_max_fee',           'null'),
  ('shop_max_pickup_distance_km',       'null'),
  -- ยกเลิก / จับคู่
  ('shop_cancel_fee_percent',           '25'),
  ('shop_cancel_fee_max',               '100'),
  ('shop_cancel_fee_to_driver_percent', '100'),
  ('shop_match_timeout_min',            '10'),
  -- หลักฐาน
  ('shop_photo_confirm_min',            '5'),
  ('shop_photo_escalate_min',           '20'),
  ('shop_receipt_tolerance_baht',       '5'),
  ('shop_receipt_tolerance_percent',    '2'),
  ('shop_receipt_review_threshold_percent', '10'),
  ('shop_substitution_timeout_min',     '5'),
  -- quote
  ('shop_quote_ttl_sec',                '120')
-- system_config มี unique เป็น "partial index" (key) WHERE key IS NOT NULL
-- -> ON CONFLICT ต้องระบุ predicate ให้ตรง ไม่งั้นได้ error
--    "no unique or exclusion constraint matching the ON CONFLICT specification"
ON CONFLICT (key) WHERE key IS NOT NULL DO NOTHING;

-- ─────────────────────────────────────────────────────────────
-- 2) ตารางร้านค้า
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.shop_stores (
  id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  name                text        NOT NULL,
  category            text        NOT NULL DEFAULT 'grocery',
  address             text,
  lat                 double precision NOT NULL,
  lng                 double precision NOT NULL,
  -- {"mon":[{"open":"08:00","close":"20:00"}], ... , "sun":[]}
  opening_hours       jsonb       NOT NULL DEFAULT '{}'::jsonb,
  is_24h              boolean     NOT NULL DEFAULT false,
  -- ร้านออกใบเสร็จไหม -> ตัดสินว่าใช้หลักฐานแบบ receipt หรือ photo
  issues_receipt      boolean     NOT NULL DEFAULT true,
  is_active           boolean     NOT NULL DEFAULT true,
  manual_closed_until timestamptz,
  service_radius_km   numeric(6,2),
  photo_url           text,
  note                text,
  -- เตรียมไว้สำหรับ Phase 2 (รับ request ร้านใหม่) ใส่ตอนนี้จะได้ไม่ต้อง migrate ทีหลัง
  source              text        NOT NULL DEFAULT 'admin',
  created_by          uuid        REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT shop_stores_category_check
    CHECK (category IN ('grocery', 'mall', 'market', 'convenience', 'pharmacy')),
  CONSTRAINT shop_stores_source_check
    CHECK (source IN ('admin', 'request')),
  CONSTRAINT shop_stores_lat_check CHECK (lat BETWEEN -90 AND 90),
  CONSTRAINT shop_stores_lng_check CHECK (lng BETWEEN -180 AND 180),
  -- กันพิกัด (0,0) ที่เป็นค่าว่างปลอม (แอปกรองทิ้งอยู่แล้ว แต่กันที่ DB ด้วย)
  CONSTRAINT shop_stores_coord_not_null_island CHECK (NOT (lat = 0 AND lng = 0)),
  CONSTRAINT shop_stores_radius_check
    CHECK (service_radius_km IS NULL OR service_radius_km > 0)
);

CREATE INDEX IF NOT EXISTS shop_stores_active_idx   ON public.shop_stores (is_active);
CREATE INDEX IF NOT EXISTS shop_stores_category_idx ON public.shop_stores (category);
-- bounding-box pre-filter ก่อนคิด haversine (แบบเดียวกับ nearby อื่น ๆ ในระบบ)
CREATE INDEX IF NOT EXISTS shop_stores_latlng_idx   ON public.shop_stores (lat, lng);

CREATE OR REPLACE FUNCTION public.shop_stores_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS shop_stores_touch ON public.shop_stores;
CREATE TRIGGER shop_stores_touch
  BEFORE UPDATE ON public.shop_stores
  FOR EACH ROW EXECUTE FUNCTION public.shop_stores_touch_updated_at();

-- ─────────────────────────────────────────────────────────────
-- 3) RLS — ลูกค้า/คนขับอ่านได้เฉพาะร้านที่เปิดใช้งาน เขียนได้เฉพาะแอดมิน
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.shop_stores ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS shop_stores_select_active ON public.shop_stores;
CREATE POLICY shop_stores_select_active ON public.shop_stores
  FOR SELECT TO authenticated
  USING (is_active = true OR public.is_admin());

DROP POLICY IF EXISTS shop_stores_admin_insert ON public.shop_stores;
CREATE POLICY shop_stores_admin_insert ON public.shop_stores
  FOR INSERT TO authenticated
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS shop_stores_admin_update ON public.shop_stores;
CREATE POLICY shop_stores_admin_update ON public.shop_stores
  FOR UPDATE TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS shop_stores_admin_delete ON public.shop_stores;
CREATE POLICY shop_stores_admin_delete ON public.shop_stores
  FOR DELETE TO authenticated
  USING (public.is_admin());

REVOKE ALL ON public.shop_stores FROM anon;
GRANT SELECT ON public.shop_stores TO authenticated;
GRANT ALL    ON public.shop_stores TO service_role;

-- ─────────────────────────────────────────────────────────────
-- 4) เวลาเปิด-ปิด
-- ─────────────────────────────────────────────────────────────

-- คีย์วันใน opening_hours จากเวลาไทย
CREATE OR REPLACE FUNCTION public.shop_dow_key(p_local timestamp)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
  SELECT (ARRAY['sun','mon','tue','wed','thu','fri','sat'])[
    EXTRACT(DOW FROM p_local)::int + 1
  ];
$$;

-- ช่วงเวลาของวันหนึ่ง ๆ เป็นนาทีนับจากเที่ยงคืน; close <= open หมายถึงข้ามวัน
CREATE OR REPLACE FUNCTION public._shop_minutes(p_hhmm text)
RETURNS integer
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_parts text[];
BEGIN
  IF p_hhmm IS NULL OR btrim(p_hhmm) = '' THEN RETURN NULL; END IF;
  v_parts := string_to_array(btrim(p_hhmm), ':');
  IF array_length(v_parts, 1) < 2 THEN RETURN NULL; END IF;
  RETURN (v_parts[1]::int * 60) + v_parts[2]::int;
EXCEPTION WHEN others THEN
  RETURN NULL;
END;
$$;

-- ร้านเปิดอยู่ ณ เวลาที่กำหนดหรือไม่ (เทียบเวลาไทยเสมอ)
CREATE OR REPLACE FUNCTION public.shop_store_is_open_at(
  p_opening_hours       jsonb,
  p_is_24h              boolean,
  p_manual_closed_until timestamptz,
  p_at                  timestamptz DEFAULT now()
)
RETURNS boolean
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_local     timestamp;
  v_minutes   int;
  v_today     text;
  v_yesterday text;
  v_range     jsonb;
  v_open      int;
  v_close     int;
BEGIN
  -- ปิดชั่วคราวโดยแอดมิน ชนะทุกเงื่อนไข
  IF p_manual_closed_until IS NOT NULL AND p_manual_closed_until > p_at THEN
    RETURN false;
  END IF;

  IF COALESCE(p_is_24h, false) THEN
    RETURN true;
  END IF;

  IF p_opening_hours IS NULL OR jsonb_typeof(p_opening_hours) <> 'object' THEN
    RETURN false;
  END IF;

  v_local     := p_at AT TIME ZONE 'Asia/Bangkok';
  v_minutes   := EXTRACT(HOUR FROM v_local)::int * 60 + EXTRACT(MINUTE FROM v_local)::int;
  v_today     := public.shop_dow_key(v_local);
  v_yesterday := public.shop_dow_key(v_local - interval '1 day');

  -- ช่วงของ "วันนี้"
  FOR v_range IN
    SELECT jsonb_array_elements(COALESCE(p_opening_hours -> v_today, '[]'::jsonb))
  LOOP
    v_open  := public._shop_minutes(v_range ->> 'open');
    v_close := public._shop_minutes(v_range ->> 'close');
    CONTINUE WHEN v_open IS NULL OR v_close IS NULL;

    IF v_close > v_open THEN
      -- ช่วงปกติภายในวันเดียว
      IF v_minutes >= v_open AND v_minutes < v_close THEN RETURN true; END IF;
    ELSE
      -- ข้ามเที่ยงคืน เช่น 18:00-02:00 -> ตั้งแต่ open ถึงสิ้นวัน
      IF v_minutes >= v_open THEN RETURN true; END IF;
    END IF;
  END LOOP;

  -- ช่วงข้ามเที่ยงคืนที่เริ่มตั้งแต่ "เมื่อวาน" แล้วลากมาถึงเช้าวันนี้
  FOR v_range IN
    SELECT jsonb_array_elements(COALESCE(p_opening_hours -> v_yesterday, '[]'::jsonb))
  LOOP
    v_open  := public._shop_minutes(v_range ->> 'open');
    v_close := public._shop_minutes(v_range ->> 'close');
    CONTINUE WHEN v_open IS NULL OR v_close IS NULL;

    IF v_close <= v_open AND v_minutes < v_close THEN RETURN true; END IF;
  END LOOP;

  RETURN false;
END;
$$;

-- เปิดอีกครั้งเมื่อไหร่ (มองไปข้างหน้า 8 วัน) — ใช้แสดง "เปิดอีกครั้ง 08:00 พรุ่งนี้"
CREATE OR REPLACE FUNCTION public.shop_store_next_open_at(
  p_opening_hours       jsonb,
  p_is_24h              boolean,
  p_manual_closed_until timestamptz,
  p_at                  timestamptz DEFAULT now()
)
RETURNS timestamptz
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_local  timestamp;
  v_day    date;
  v_key    text;
  v_range  jsonb;
  v_open   int;
  v_cand   timestamp;
  v_cand_tz timestamptz;
  v_best   timestamptz;
  i        int;
BEGIN
  IF COALESCE(p_is_24h, false) THEN
    -- 24 ชม. แต่ถูกปิดชั่วคราว -> เปิดอีกครั้งตอนหมดเวลาปิด
    IF p_manual_closed_until IS NOT NULL AND p_manual_closed_until > p_at THEN
      RETURN p_manual_closed_until;
    END IF;
    RETURN NULL;
  END IF;

  IF p_opening_hours IS NULL OR jsonb_typeof(p_opening_hours) <> 'object' THEN
    RETURN NULL;
  END IF;

  v_local := p_at AT TIME ZONE 'Asia/Bangkok';

  FOR i IN 0..7 LOOP
    v_day := (v_local + (i || ' days')::interval)::date;
    v_key := public.shop_dow_key(v_day::timestamp);

    FOR v_range IN
      SELECT jsonb_array_elements(COALESCE(p_opening_hours -> v_key, '[]'::jsonb))
    LOOP
      v_open := public._shop_minutes(v_range ->> 'open');
      CONTINUE WHEN v_open IS NULL;

      v_cand    := v_day::timestamp + (v_open || ' minutes')::interval;
      v_cand_tz := v_cand AT TIME ZONE 'Asia/Bangkok';

      -- ต้องอยู่ในอนาคต และไม่ตกอยู่ในช่วงที่แอดมินสั่งปิด
      IF v_cand_tz > p_at
         AND (p_manual_closed_until IS NULL OR v_cand_tz >= p_manual_closed_until)
         AND (v_best IS NULL OR v_cand_tz < v_best)
      THEN
        v_best := v_cand_tz;
      END IF;
    END LOOP;

    IF v_best IS NOT NULL THEN
      RETURN v_best;
    END IF;
  END LOOP;

  RETURN NULL;
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- 5) RPC ค้นหาร้านในรัศมี
--    เรียง: ร้านที่เปิดอยู่ก่อน แล้วค่อยเรียงตามระยะทาง
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.shop_nearby_stores(
  p_lat      double precision,
  p_lng      double precision,
  p_category text DEFAULT NULL
)
RETURNS TABLE (
  id             uuid,
  name           text,
  category       text,
  address        text,
  lat            double precision,
  lng            double precision,
  distance_km    numeric,
  is_open_now    boolean,
  next_open_at   timestamptz,
  issues_receipt boolean,
  photo_url      text,
  note           text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_default_radius numeric;
  v_show_closed    boolean;
  v_lat_delta      double precision;
  v_lng_delta      double precision;
  v_max_radius     numeric;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  -- ปิดบริการอยู่ = ไม่ต้องคืนร้านเลย กันลูกค้าเห็นร้านก่อนระบบพร้อม
  IF NOT public.shop_config_bool('shop_enabled', false) THEN
    RETURN;
  END IF;

  IF p_lat IS NULL OR p_lng IS NULL OR (p_lat = 0 AND p_lng = 0) THEN
    RETURN;
  END IF;

  v_default_radius := public.shop_config_num('shop_store_radius_km', 10);
  v_max_radius     := public.shop_config_num('shop_store_radius_max_km', 25);
  v_show_closed    := public.shop_config_bool('shop_show_closed_stores', true);

  -- bounding box เผื่อ 20% กันขอบ (เดียวกับ pattern ที่ใช้อยู่ในแอป)
  v_lat_delta := (v_max_radius / 111.0) * 1.2;
  v_lng_delta := (v_max_radius / (111.0 * GREATEST(cos(radians(p_lat)), 0.01))) * 1.2;

  RETURN QUERY
  WITH candidates AS (
    SELECT
      s.*,
      ROUND(
        (6371 * acos(
          LEAST(1.0, cos(radians(p_lat)) * cos(radians(s.lat))
            * cos(radians(s.lng) - radians(p_lng))
            + sin(radians(p_lat)) * sin(radians(s.lat)))
        ))::numeric, 2
      ) AS dist_km
    FROM public.shop_stores s
    WHERE s.is_active = true
      AND (p_category IS NULL OR s.category = p_category)
      AND s.lat BETWEEN p_lat - v_lat_delta AND p_lat + v_lat_delta
      AND s.lng BETWEEN p_lng - v_lng_delta AND p_lng + v_lng_delta
  ),
  scoped AS (
    SELECT
      c.*,
      public.shop_store_is_open_at(
        c.opening_hours, c.is_24h, c.manual_closed_until, now()
      ) AS open_now
    FROM candidates c
    WHERE c.dist_km <= LEAST(COALESCE(c.service_radius_km, v_default_radius), v_max_radius)
  )
  SELECT
    x.id,
    x.name,
    x.category,
    x.address,
    x.lat,
    x.lng,
    x.dist_km,
    x.open_now,
    CASE
      WHEN x.open_now THEN NULL
      ELSE public.shop_store_next_open_at(
             x.opening_hours, x.is_24h, x.manual_closed_until, now()
           )
    END,
    x.issues_receipt,
    x.photo_url,
    x.note
  FROM scoped x
  WHERE v_show_closed = true OR x.open_now = true
  ORDER BY x.open_now DESC, x.dist_km ASC
  LIMIT 100;
END;
$$;

REVOKE ALL ON FUNCTION public.shop_nearby_stores(double precision, double precision, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.shop_nearby_stores(double precision, double precision, text)
  TO authenticated, service_role;

-- ─────────────────────────────────────────────────────────────
-- 6) RPC อ่านร้านเดี่ยว (ใช้ตอน quote / ตอนคนขับเปิดงาน)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.shop_store_status(p_store_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  s public.shop_stores%ROWTYPE;
  v_open boolean;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  SELECT * INTO s FROM public.shop_stores WHERE id = p_store_id;
  IF NOT FOUND THEN
    RETURN jsonb_build_object('found', false, 'error', 'store_not_found');
  END IF;

  v_open := s.is_active
            AND public.shop_store_is_open_at(s.opening_hours, s.is_24h, s.manual_closed_until, now());

  RETURN jsonb_build_object(
    'found',          true,
    'id',             s.id,
    'name',           s.name,
    'category',       s.category,
    'address',        s.address,
    'lat',            s.lat,
    'lng',            s.lng,
    'is_active',      s.is_active,
    'is_open_now',    v_open,
    'next_open_at',   CASE WHEN v_open THEN NULL
                           ELSE public.shop_store_next_open_at(
                                  s.opening_hours, s.is_24h, s.manual_closed_until, now())
                      END,
    'issues_receipt', s.issues_receipt,
    'photo_url',      s.photo_url,
    'note',           s.note
  );
END;
$$;

REVOKE ALL ON FUNCTION public.shop_store_status(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.shop_store_status(uuid) TO authenticated, service_role;

COMMIT;
