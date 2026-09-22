-- ═══════════════════════════════════════════════════════════════
-- ฝากซื้อ/ฝากหิ้ว — S2: ตรวจคนขับออนไลน์ + คำนวณราคาฝั่ง server (quote)
-- อ้างอิงแผน: Plan/Shop_Errand_Service_Feature_Plan_v4.html หัวข้อ 2, 3, 5
--
-- หลักการ:
--   * ทุกตัวเลขราคาคำนวณที่ server แอปแค่แสดงผล (หลักการเดียวกับ Batch 1)
--   * nearest_online_driver คืนแค่ตัวเลขสรุป ไม่คืนตำแหน่ง/ตัวตนคนขับ
--   * ไม่มีคนขับออนไลน์ = สั่งไม่ได้ (บังคับทั้งที่นี่และตอน create booking)
--   * shop_compute_fees ใช้ร่วมกันระหว่าง quote / create / settle -> ราคาไม่มีทางเพี้ยน
-- ═══════════════════════════════════════════════════════════════

BEGIN;

-- ─────────────────────────────────────────────────────────────
-- 0) อัตราค่าส่งของบริการฝากซื้อ (ใช้สูตรเดียวกับ vertical อื่น)
--    base_price เมื่อระยะ <= base_distance, เกินนั้นคิด price_per_km ต่อ กม.
-- ─────────────────────────────────────────────────────────────
INSERT INTO public.service_rates (service_type, base_price, base_distance, price_per_km)
VALUES ('shop', 25, 2, 7)
ON CONFLICT (service_type) DO NOTHING;

-- ─────────────────────────────────────────────────────────────
-- 1) driver_locations: ต้องรู้ว่าตำแหน่งสดแค่ไหน
--    (ตาราง DDL เดิมไม่ได้อยู่ใน repo — เพิ่มแบบ idempotent ไม่กระทบของเดิม)
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.driver_locations
  ADD COLUMN IF NOT EXISTS updated_at timestamptz NOT NULL DEFAULT now();

CREATE OR REPLACE FUNCTION public.driver_locations_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS driver_locations_touch ON public.driver_locations;
CREATE TRIGGER driver_locations_touch
  BEFORE UPDATE ON public.driver_locations
  FOR EACH ROW EXECUTE FUNCTION public.driver_locations_touch_updated_at();

CREATE INDEX IF NOT EXISTS driver_locations_online_idx
  ON public.driver_locations (is_online, is_available);

-- ─────────────────────────────────────────────────────────────
-- 2) หาคนขับออนไลน์ที่ใกล้ที่สุด — คืนเฉพาะตัวเลขสรุป
--    แทนที่ FareAdjustmentService.findNearestOnlineDriverDistanceKm() ฝั่ง Dart
--    ที่ดึงตำแหน่งคนขับทุกคนมาที่เครื่องลูกค้า (ดู ISSUE + memory: client->server)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.nearest_online_driver(
  p_lat          double precision,
  p_lng          double precision,
  p_vehicle_type text DEFAULT NULL,
  p_radius_km    numeric DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_radius     numeric;
  v_lat_delta  double precision;
  v_lng_delta  double precision;
  v_fresh_sec  numeric;
  v_nearest    numeric;
  v_in_radius  int;
  v_total      int;
BEGIN
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF p_lat IS NULL OR p_lng IS NULL OR (p_lat = 0 AND p_lng = 0) THEN
    RETURN jsonb_build_object('has_driver', false, 'error', 'invalid_coordinates');
  END IF;

  v_radius    := COALESCE(p_radius_km, public.shop_config_num('shop_driver_to_store_km', 20));
  v_fresh_sec := public.shop_config_num('shop_location_freshness_sec', 120);

  -- มองกว้างกว่ารัศมีมาก เพื่อให้รู้ว่ามีคนขับนอกรัศมีไหม (ใช้คิดค่าวิ่งไกล)
  -- 200 กม. เป็นขอบเขตกวาดข้อมูล ไม่ใช่เพดานธุรกิจ (เพดานจริงอยู่ที่ shop_max_pickup_distance_km)
  v_lat_delta := (200.0 / 111.0) * 1.2;
  v_lng_delta := (200.0 / (111.0 * GREATEST(cos(radians(p_lat)), 0.01))) * 1.2;

  WITH online AS (
    SELECT
      ROUND(
        (6371 * acos(
          LEAST(1.0, cos(radians(p_lat)) * cos(radians(dl.location_lat))
            * cos(radians(dl.location_lng) - radians(p_lng))
            + sin(radians(p_lat)) * sin(radians(dl.location_lat)))
        ))::numeric, 2
      ) AS dist_km
    FROM public.driver_locations dl
    JOIN public.profiles p ON p.id = dl.driver_id
    WHERE dl.is_online = true
      AND dl.is_available = true
      AND dl.location_lat IS NOT NULL
      AND dl.location_lng IS NOT NULL
      AND NOT (dl.location_lat = 0 AND dl.location_lng = 0)
      AND dl.updated_at >= now() - make_interval(secs => v_fresh_sec)
      AND p.is_online = true
      AND p.approval_status = 'approved'
      AND p.role = 'driver'
      AND (p_vehicle_type IS NULL OR p.vehicle_type = p_vehicle_type)
      AND dl.location_lat BETWEEN p_lat - v_lat_delta AND p_lat + v_lat_delta
      AND dl.location_lng BETWEEN p_lng - v_lng_delta AND p_lng + v_lng_delta
  )
  SELECT
    MIN(dist_km),
    COUNT(*) FILTER (WHERE dist_km <= v_radius),
    COUNT(*)
  INTO v_nearest, v_in_radius, v_total
  FROM online;

  IF v_nearest IS NULL THEN
    RETURN jsonb_build_object(
      'has_driver', false,
      'nearest_km', NULL,
      'driver_count_in_radius', 0,
      'driver_count_total', 0,
      'radius_km', v_radius
    );
  END IF;

  RETURN jsonb_build_object(
    'has_driver', true,
    'nearest_km', v_nearest,
    'driver_count_in_radius', COALESCE(v_in_radius, 0),
    'driver_count_total', COALESCE(v_total, 0),
    'radius_km', v_radius,
    'is_outside_radius', (v_nearest > v_radius)
  );
END;
$$;

REVOKE ALL ON FUNCTION public.nearest_online_driver(double precision, double precision, text, numeric)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.nearest_online_driver(double precision, double precision, text, numeric)
  TO authenticated, service_role;

-- ─────────────────────────────────────────────────────────────
-- 3) snapshot ค่า config ที่เกี่ยวกับเงิน ณ เวลาสร้างออเดอร์
--    ต้องคิดเงินจาก snapshot เสมอ ไม่ใช่ config ปัจจุบัน
--    (แอดมินแก้ค่าระหว่างวัน ออเดอร์ที่ทำอยู่ต้องไม่เปลี่ยนราคา)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.shop_fee_snapshot()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'fee_percent',        public.shop_config_num('shop_fee_percent', 10),
    'fee_tiers',          public.shop_config_json('shop_fee_tiers',
                            '[{"max":500,"fee":30},{"max":1500,"fee":50},{"max":null,"fee":80}]'::jsonb),
    'fee_min',            public.shop_config_num('shop_fee_min', 25),
    'fee_max',            public.shop_config_num('shop_fee_max', 200),
    'fee_multiplier',     public.shop_config_json('shop_fee_multiplier_by_category', '{}'::jsonb),
    'driver_share_pct',   public.shop_config_num('shop_driver_share_percent', 80),
    'far_enabled',        public.shop_config_bool('shop_far_pickup_enabled', true),
    'far_rate_moto',      public.shop_config_num('shop_far_pickup_rate_per_km_motorcycle', 5),
    'far_rate_car',       public.shop_config_num('shop_far_pickup_rate_per_km_car', 8),
    'far_max_fee',        public.shop_config_num_nullable('shop_far_pickup_max_fee'),
    'max_pickup_km',      public.shop_config_num_nullable('shop_max_pickup_distance_km'),
    'driver_radius_km',   public.shop_config_num('shop_driver_to_store_km', 20),
    'cancel_fee_pct',     public.shop_config_num('shop_cancel_fee_percent', 25),
    'cancel_fee_max',     public.shop_config_num('shop_cancel_fee_max', 100),
    'cancel_to_driver_pct', public.shop_config_num('shop_cancel_fee_to_driver_percent', 100),
    'min_budget',         public.shop_config_num('shop_min_budget', 100),
    'max_budget',         public.shop_config_num('shop_max_budget', 5000),
    'new_driver_max_budget', public.shop_config_num('shop_new_driver_max_budget', 500),
    'new_driver_jobs',    public.shop_config_num('shop_new_driver_completed_jobs', 20),
    'snapshot_at',        to_jsonb(now())
  );
$$;

-- ค่าส่งตามระยะ (สูตรเดียวกับ SystemConfigService.calculateDeliveryFee)
CREATE OR REPLACE FUNCTION public.shop_delivery_fee(p_distance_km numeric)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  r RECORD;
  v_rounded int;
BEGIN
  SELECT base_price, base_distance, price_per_km
    INTO r
  FROM public.service_rates
  WHERE service_type = 'shop';

  IF NOT FOUND THEN
    RETURN 0;
  END IF;

  -- ปัดเศษระยะทางแบบเดียวกับแอป (2.4 -> 2, 2.5 -> 3)
  v_rounded := ROUND(COALESCE(p_distance_km, 0))::int;

  IF v_rounded <= r.base_distance THEN
    RETURN r.base_price;
  END IF;

  RETURN r.base_price + ((v_rounded - r.base_distance) * r.price_per_km);
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- 4) เครื่องคิดค่าบริการกลาง — ใช้ทั้งตอน quote / create / settle
--
--    ค่าบริการฝากซื้อ = MAX(ขั้นบันได, % ของบิล) x multiplier ของหมวดร้าน
--                      แล้ว clamp ด้วย fee_min / fee_max
--    ค่าวิ่งไกล      = (ระยะคนขับ - รัศมี) x อัตราตามประเภทรถ  (clamp ด้วย far_max_fee ถ้ากำหนด)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.shop_compute_fees(
  p_snapshot     jsonb,
  p_goods_amount numeric,
  p_category     text,
  p_distance_km  numeric,
  p_driver_km    numeric,
  p_vehicle_type text
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_tier_fee   numeric := 0;
  v_pct_fee    numeric := 0;
  v_service    numeric := 0;
  v_mult       numeric := 1.0;
  v_delivery   numeric := 0;
  v_far        numeric := 0;
  v_far_rate   numeric;
  v_radius     numeric;
  v_far_max    numeric;
  v_tier       jsonb;
  v_tier_max   numeric;
  v_goods      numeric;
BEGIN
  v_goods := GREATEST(COALESCE(p_goods_amount, 0), 0);

  -- ขั้นบันได: ใช้ขั้นแรกที่ยอดบิลไม่เกิน max (max = null คือขั้นสุดท้าย)
  FOR v_tier IN SELECT jsonb_array_elements(COALESCE(p_snapshot -> 'fee_tiers', '[]'::jsonb))
  LOOP
    IF (v_tier ->> 'max') IS NULL OR lower(v_tier ->> 'max') = 'null' THEN
      v_tier_fee := COALESCE((v_tier ->> 'fee')::numeric, 0);
      EXIT;
    END IF;
    v_tier_max := (v_tier ->> 'max')::numeric;
    IF v_goods <= v_tier_max THEN
      v_tier_fee := COALESCE((v_tier ->> 'fee')::numeric, 0);
      EXIT;
    END IF;
  END LOOP;

  v_pct_fee := v_goods * COALESCE((p_snapshot ->> 'fee_percent')::numeric, 0) / 100.0;

  v_service := GREATEST(v_tier_fee, v_pct_fee);

  -- multiplier ตามหมวดร้าน (ค่าเริ่มต้นทุกหมวด = 1.0 จึงไม่เปลี่ยนอะไรตอนนี้)
  IF p_category IS NOT NULL
     AND (p_snapshot -> 'fee_multiplier' ->> p_category) IS NOT NULL THEN
    v_mult := COALESCE((p_snapshot -> 'fee_multiplier' ->> p_category)::numeric, 1.0);
  END IF;
  v_service := v_service * v_mult;

  -- clamp
  v_service := GREATEST(v_service, COALESCE((p_snapshot ->> 'fee_min')::numeric, 0));
  IF (p_snapshot ->> 'fee_max') IS NOT NULL THEN
    v_service := LEAST(v_service, (p_snapshot ->> 'fee_max')::numeric);
  END IF;

  v_delivery := public.shop_delivery_fee(p_distance_km);

  -- ค่าวิ่งไกล: เฉพาะส่วนที่คนขับอยู่เกินรัศมี
  IF COALESCE((p_snapshot ->> 'far_enabled')::boolean, true)
     AND p_driver_km IS NOT NULL THEN
    v_radius := COALESCE((p_snapshot ->> 'driver_radius_km')::numeric, 20);
    IF p_driver_km > v_radius THEN
      v_far_rate := CASE
        WHEN lower(COALESCE(p_vehicle_type, '')) IN ('car', 'sedan', 'suv', 'van')
          THEN COALESCE((p_snapshot ->> 'far_rate_car')::numeric, 8)
        ELSE COALESCE((p_snapshot ->> 'far_rate_moto')::numeric, 5)
      END;
      v_far := (p_driver_km - v_radius) * v_far_rate;

      -- เพดานค่าวิ่งไกล: ผู้ใช้ยังไม่กำหนด -> null = ไม่จำกัด
      v_far_max := (p_snapshot ->> 'far_max_fee')::numeric;
      IF v_far_max IS NOT NULL THEN
        v_far := LEAST(v_far, v_far_max);
      END IF;
    END IF;
  END IF;

  v_service  := ROUND(v_service, 2);
  v_delivery := ROUND(v_delivery, 2);
  v_far      := ROUND(v_far, 2);

  RETURN jsonb_build_object(
    'service_fee',    v_service,
    'delivery_fee',   v_delivery,
    'far_pickup_fee', v_far,
    'total_fees',     ROUND(v_service + v_delivery + v_far, 2)
  );
END;
$$;

-- ─────────────────────────────────────────────────────────────
-- 5) quote — ทุกบรรทัดที่ลูกค้าเห็นใน dialog มาจากที่นี่ที่เดียว
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.shop_quote(
  p_store_id     uuid,
  p_budget_cap   numeric,
  p_dest_lat     double precision,
  p_dest_lng     double precision,
  p_vehicle_type text DEFAULT 'motorcycle'
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid        uuid := auth.uid();
  s            public.shop_stores%ROWTYPE;
  v_open       boolean;
  v_snapshot   jsonb;
  v_driver     jsonb;
  v_driver_km  numeric;
  v_dist_km    numeric;
  v_fees       jsonb;
  v_hold       numeric;
  v_balance    numeric;
  v_cancel_fee numeric;
  v_max_pickup numeric;
BEGIN
  IF v_uid IS NULL THEN
    RAISE EXCEPTION 'not_authenticated';
  END IF;

  IF NOT public.shop_config_bool('shop_enabled', false) THEN
    RETURN jsonb_build_object('ok', false, 'error', 'shop_disabled');
  END IF;

  -- ร้าน ------------------------------------------------------
  SELECT * INTO s FROM public.shop_stores WHERE id = p_store_id;
  IF NOT FOUND OR NOT s.is_active THEN
    RETURN jsonb_build_object('ok', false, 'error', 'store_not_found');
  END IF;

  v_open := public.shop_store_is_open_at(s.opening_hours, s.is_24h, s.manual_closed_until, now());
  IF NOT v_open THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'store_closed',
      'next_open_at', public.shop_store_next_open_at(
                        s.opening_hours, s.is_24h, s.manual_closed_until, now())
    );
  END IF;

  v_snapshot := public.shop_fee_snapshot();

  -- วงเงิน ----------------------------------------------------
  IF p_budget_cap IS NULL
     OR p_budget_cap < (v_snapshot ->> 'min_budget')::numeric THEN
    RETURN jsonb_build_object(
      'ok', false, 'error', 'budget_below_min',
      'min_budget', (v_snapshot ->> 'min_budget')::numeric
    );
  END IF;

  IF p_budget_cap > (v_snapshot ->> 'max_budget')::numeric THEN
    RETURN jsonb_build_object(
      'ok', false, 'error', 'budget_above_max',
      'max_budget', (v_snapshot ->> 'max_budget')::numeric
    );
  END IF;

  -- คนขับ -----------------------------------------------------
  v_driver := public.nearest_online_driver(s.lat, s.lng, p_vehicle_type, NULL);

  IF NOT COALESCE((v_driver ->> 'has_driver')::boolean, false) THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'no_driver_available',
      'driver', v_driver
    );
  END IF;

  v_driver_km  := (v_driver ->> 'nearest_km')::numeric;
  v_max_pickup := (v_snapshot ->> 'max_pickup_km')::numeric;

  -- เพดานระยะ: ยังไม่กำหนด (null) = ไม่จำกัด
  IF v_max_pickup IS NOT NULL AND v_driver_km > v_max_pickup THEN
    RETURN jsonb_build_object(
      'ok', false,
      'error', 'no_driver_available',
      'reason', 'nearest_driver_too_far',
      'nearest_km', v_driver_km
    );
  END IF;

  -- ระยะส่ง: ร้าน -> ปลายทางลูกค้า -----------------------------
  v_dist_km := ROUND(
    (6371 * acos(
      LEAST(1.0, cos(radians(s.lat)) * cos(radians(p_dest_lat))
        * cos(radians(p_dest_lng) - radians(s.lng))
        + sin(radians(s.lat)) * sin(radians(p_dest_lat)))
    ))::numeric, 2
  );

  v_fees := public.shop_compute_fees(
    v_snapshot, p_budget_cap, s.category, v_dist_km, v_driver_km, p_vehicle_type
  );

  v_hold := ROUND(p_budget_cap + (v_fees ->> 'total_fees')::numeric, 2);

  -- ค่าปรับยกเลิกที่จะเกิดถ้ายกเลิกตอน shopping (แสดงเป็นจำนวนเงินจริงในคำเตือน)
  v_cancel_fee := ROUND(
    LEAST(
      v_hold * (v_snapshot ->> 'cancel_fee_pct')::numeric / 100.0,
      (v_snapshot ->> 'cancel_fee_max')::numeric
    ), 2
  );

  SELECT balance INTO v_balance FROM public.wallets WHERE user_id = v_uid;
  v_balance := COALESCE(v_balance, 0);

  RETURN jsonb_build_object(
    'ok',             true,
    'store', jsonb_build_object(
      'id', s.id, 'name', s.name, 'category', s.category,
      'lat', s.lat, 'lng', s.lng, 'issues_receipt', s.issues_receipt
    ),
    'budget_cap',     ROUND(p_budget_cap, 2),
    'distance_km',    v_dist_km,
    'delivery_fee',   (v_fees ->> 'delivery_fee')::numeric,
    'service_fee',    (v_fees ->> 'service_fee')::numeric,
    'far_pickup_fee', (v_fees ->> 'far_pickup_fee')::numeric,
    'total_fees',     (v_fees ->> 'total_fees')::numeric,
    'hold_amount',    v_hold,
    'wallet_balance', ROUND(v_balance, 2),
    'sufficient',     (v_balance >= v_hold),
    'shortfall',      GREATEST(ROUND(v_hold - v_balance, 2), 0),
    'cancel_fee_if_shopping', v_cancel_fee,
    'driver',         v_driver,
    'quoted_at',      now(),
    'quote_ttl_sec',  public.shop_config_num('shop_quote_ttl_sec', 120),
    'fee_snapshot',   v_snapshot
  );
END;
$$;

REVOKE ALL ON FUNCTION public.shop_quote(uuid, numeric, double precision, double precision, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.shop_quote(uuid, numeric, double precision, double precision, text)
  TO authenticated, service_role;

COMMIT;
