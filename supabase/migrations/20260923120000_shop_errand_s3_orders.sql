-- ═══════════════════════════════════════════════════════════════
-- ฝากซื้อ/ฝากหิ้ว — S3: ตารางออเดอร์ + สร้าง/hold/ซื้อ/settle/ยกเลิก
-- อ้างอิงแผน: Plan/Shop_Errand_Service_Feature_Plan_v4.html หัวข้อ 4, 6, 7
--
-- หลักการ:
--   * เงินทุกบาทคำนวณที่ server จาก fee_config_snapshot ที่เก็บตอนสร้างออเดอร์
--   * client ส่งได้แค่ "ราคาที่อ่านจากบิล" ต่อรายการ ห้ามส่งยอดสรุป/ค่าบริการ
--   * ยกเลิกตอน shopping หัก 25% สูงสุด 100฿ เข้าคนขับ 100%
--   * กดถึงร้านต้องอยู่ใกล้ร้านจริง (server เช็คเอง ไม่พึ่ง client อย่างเดียว)
--   * ทุกอย่างเป็น transaction เดียว ถ้าล้มกลางทางห้ามมีเงินหาย
-- ═══════════════════════════════════════════════════════════════

BEGIN;

-- ─────────────────────────────────────────────────────────────
-- 1) ตารางออเดอร์
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.shop_orders (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id            uuid NOT NULL UNIQUE REFERENCES public.bookings(id) ON DELETE CASCADE,
  store_id              uuid NOT NULL REFERENCES public.shop_stores(id) ON DELETE RESTRICT,

  -- snapshot ข้อมูลร้าน ณ เวลาสั่ง (แอดมินอาจแก้/ปิดร้านทีหลัง)
  store_name            text NOT NULL,
  store_category        text NOT NULL,
  store_lat             double precision NOT NULL,
  store_lng             double precision NOT NULL,
  proof_mode            text NOT NULL,          -- 'receipt' | 'photo'  (จาก issues_receipt)

  -- เงิน (numeric เท่านั้น ห้าม double — บทเรียน bookings.price)
  budget_cap            numeric(12,2) NOT NULL,
  hold_amount           numeric(12,2) NOT NULL,
  actual_goods_amount   numeric(12,2),
  service_fee           numeric(12,2) NOT NULL DEFAULT 0,
  delivery_fee          numeric(12,2) NOT NULL DEFAULT 0,
  far_pickup_fee        numeric(12,2) NOT NULL DEFAULT 0,
  total_amount          numeric(12,2),
  refund_amount         numeric(12,2),
  cancel_fee            numeric(12,2),

  fee_config_snapshot   jsonb NOT NULL,
  quoted_distance_km    numeric(8,2),
  quoted_driver_km      numeric(8,2),   -- ระยะคนขับที่ใกล้ที่สุด ณ ตอน quote (ใช้ตั้ง hold)
  actual_driver_km      numeric(8,2),   -- ระยะของคนขับที่ "รับงานจริง" — ใช้คิดค่าวิ่งไกลตอน settle
  vehicle_type          text,

  -- หลักฐาน
  proof_urls            text[] NOT NULL DEFAULT '{}',
  ai_extract            jsonb,
  customer_confirmed_at timestamptz,
  confirmed_by          text,                   -- 'customer' | 'admin'
  proof_sent_at         timestamptz,

  -- geofence ถึงร้าน
  arrived_at            timestamptz,
  arrival_self_reported boolean NOT NULL DEFAULT false,
  arrival_distance_m    numeric(10,1),

  customer_note         text,
  needs_admin_review    boolean NOT NULL DEFAULT false,
  admin_review_reason   text,

  hold_transaction_id   uuid,
  refund_transaction_id uuid,
  hold_released         boolean NOT NULL DEFAULT false,

  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT shop_orders_proof_mode_check CHECK (proof_mode IN ('receipt', 'photo')),
  CONSTRAINT shop_orders_confirmed_by_check
    CHECK (confirmed_by IS NULL OR confirmed_by IN ('customer', 'admin')),
  CONSTRAINT shop_orders_budget_positive CHECK (budget_cap > 0),
  CONSTRAINT shop_orders_hold_positive   CHECK (hold_amount > 0)
);

CREATE INDEX IF NOT EXISTS shop_orders_booking_idx ON public.shop_orders (booking_id);
CREATE INDEX IF NOT EXISTS shop_orders_store_idx   ON public.shop_orders (store_id);
CREATE INDEX IF NOT EXISTS shop_orders_review_idx  ON public.shop_orders (needs_admin_review)
  WHERE needs_admin_review = true;

CREATE TABLE IF NOT EXISTS public.shop_order_items (
  id             uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  shop_order_id  uuid NOT NULL REFERENCES public.shop_orders(id) ON DELETE CASCADE,
  line_no        int  NOT NULL,
  name_text      text NOT NULL,
  quantity_text  text,                          -- text เพราะลูกค้าพิมพ์ "2 ขวด" / "ครึ่งโล"
  note           text,
  status         text NOT NULL DEFAULT 'pending',
  actual_price   numeric(12,2),
  substitute_name text,
  created_at     timestamptz NOT NULL DEFAULT now(),
  updated_at     timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT shop_order_items_status_check
    CHECK (status IN ('pending', 'bought', 'unavailable', 'substituted')),
  CONSTRAINT shop_order_items_price_check
    CHECK (actual_price IS NULL OR actual_price >= 0),
  CONSTRAINT shop_order_items_line_unique UNIQUE (shop_order_id, line_no)
);

CREATE INDEX IF NOT EXISTS shop_order_items_order_idx ON public.shop_order_items (shop_order_id);

-- ธง "คนขับที่ไว้ใจได้" (ข้ามเพดานคนขับใหม่)
--
-- เก็บเป็นตารางแยกแทนคอลัมน์ใน profiles โดยตั้งใจ:
--   profiles มี trigger guard_profile_privileged_columns คุมคอลัมน์สิทธิ์อยู่ การเพิ่มคอลัมน์ใหม่
--   ต้องไปแก้ trigger นั้นด้วย ซึ่งเสี่ยงเขียนทับเวอร์ชันบน production ที่อาจไม่ตรงกับไฟล์ใน repo
--   ตารางแยก + RLS แอดมินเท่านั้น ให้ผลเหมือนกันโดยไม่ต้องแตะของเดิม
CREATE TABLE IF NOT EXISTS public.shop_driver_flags (
  driver_id  uuid PRIMARY KEY REFERENCES public.profiles(id) ON DELETE CASCADE,
  trusted    boolean NOT NULL DEFAULT false,
  note       text,
  set_by     uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  set_at     timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.shop_driver_flags ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS shop_driver_flags_select ON public.shop_driver_flags;
CREATE POLICY shop_driver_flags_select ON public.shop_driver_flags
  FOR SELECT TO authenticated
  USING (driver_id = auth.uid() OR public.is_admin());

DROP POLICY IF EXISTS shop_driver_flags_admin_write ON public.shop_driver_flags;
CREATE POLICY shop_driver_flags_admin_write ON public.shop_driver_flags
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

REVOKE ALL ON public.shop_driver_flags FROM anon;
GRANT SELECT ON public.shop_driver_flags TO authenticated;
GRANT ALL    ON public.shop_driver_flags TO service_role;

CREATE OR REPLACE FUNCTION public.shop_touch_updated_at()
RETURNS trigger LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END;
$$;

DROP TRIGGER IF EXISTS shop_orders_touch ON public.shop_orders;
CREATE TRIGGER shop_orders_touch BEFORE UPDATE ON public.shop_orders
  FOR EACH ROW EXECUTE FUNCTION public.shop_touch_updated_at();

DROP TRIGGER IF EXISTS shop_order_items_touch ON public.shop_order_items;
CREATE TRIGGER shop_order_items_touch BEFORE UPDATE ON public.shop_order_items
  FOR EACH ROW EXECUTE FUNCTION public.shop_touch_updated_at();

-- ─────────────────────────────────────────────────────────────
-- 2) RLS — อ่านได้เฉพาะคู่กรณี เขียนผ่าน RPC เท่านั้น
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.shop_orders      ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.shop_order_items ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS shop_orders_select_party ON public.shop_orders;
CREATE POLICY shop_orders_select_party ON public.shop_orders
  FOR SELECT TO authenticated
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = shop_orders.booking_id
        AND (b.customer_id = auth.uid() OR b.driver_id = auth.uid())
    )
  );

DROP POLICY IF EXISTS shop_order_items_select_party ON public.shop_order_items;
CREATE POLICY shop_order_items_select_party ON public.shop_order_items
  FOR SELECT TO authenticated
  USING (
    public.is_admin()
    OR EXISTS (
      SELECT 1
      FROM public.shop_orders so
      JOIN public.bookings b ON b.id = so.booking_id
      WHERE so.id = shop_order_items.shop_order_id
        AND (b.customer_id = auth.uid() OR b.driver_id = auth.uid())
    )
  );

-- ไม่มี policy INSERT/UPDATE/DELETE สำหรับ authenticated โดยเจตนา
-- ทุกการเขียนต้องผ่าน RPC (SECURITY DEFINER) ที่ตรวจสิทธิ์เอง
REVOKE ALL ON public.shop_orders, public.shop_order_items FROM anon;
GRANT SELECT ON public.shop_orders, public.shop_order_items TO authenticated;
GRANT ALL    ON public.shop_orders, public.shop_order_items TO service_role;

-- realtime: ลูกค้าเห็นคนขับติ๊กของทีละชิ้น
DO $$
BEGIN
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.shop_orders;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
  BEGIN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.shop_order_items;
  EXCEPTION WHEN duplicate_object THEN NULL;
  END;
END $$;

-- ─────────────────────────────────────────────────────────────
-- 4) สร้างออเดอร์ + กันวงเงินจาก Wallet (atomic)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.create_shop_booking(
  p_store_id     uuid,
  p_budget_cap   numeric,
  p_dest_lat     double precision,
  p_dest_lng     double precision,
  p_dest_address text,
  p_items        jsonb,             -- [{name, quantity, note}]
  p_note         text DEFAULT NULL,
  p_vehicle_type text DEFAULT 'motorcycle'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid        uuid := auth.uid();
  s            public.shop_stores%ROWTYPE;
  v_snapshot   jsonb;
  v_driver     jsonb;
  v_driver_km  numeric;
  v_dist_km    numeric;
  v_fees       jsonb;
  v_hold       numeric;
  v_max_items  int;
  v_item_count int;
  v_booking_id uuid;
  v_order_id   uuid;
  v_wallet_id  uuid;
  v_balance    numeric;
  v_tx_id      uuid;
  v_item       jsonb;
  v_line       int := 0;
  v_max_pickup numeric;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  IF NOT public.shop_config_bool('shop_enabled', false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'shop_disabled');
  END IF;

  -- ปลายทางต้องเป็นพิกัดจริง ไม่งั้นค่าส่งจะถูกคิดจากระยะไปเกาะ null island
  IF p_dest_lat IS NULL OR p_dest_lng IS NULL
     OR (p_dest_lat = 0 AND p_dest_lng = 0)
     OR p_dest_lat < -90 OR p_dest_lat > 90
     OR p_dest_lng < -180 OR p_dest_lng > 180 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_destination');
  END IF;

  -- ร้านต้องมีอยู่ เปิดใช้งาน และ "เปิดอยู่ตอนนี้" (เช็คซ้ำจาก UI — ปิดช่องว่างเวลา)
  SELECT * INTO s FROM public.shop_stores WHERE id = p_store_id;
  IF NOT FOUND OR NOT s.is_active THEN
    RETURN jsonb_build_object('success', false, 'error', 'store_not_found');
  END IF;

  IF NOT public.shop_store_is_open_at(s.opening_hours, s.is_24h, s.manual_closed_until, now()) THEN
    RETURN jsonb_build_object(
      'success', false, 'error', 'store_closed',
      'next_open_at', public.shop_store_next_open_at(
                        s.opening_hours, s.is_24h, s.manual_closed_until, now())
    );
  END IF;

  v_snapshot := public.shop_fee_snapshot();

  -- วงเงิน
  IF p_budget_cap IS NULL OR p_budget_cap < (v_snapshot ->> 'min_budget')::numeric THEN
    RETURN jsonb_build_object('success', false, 'error', 'budget_below_min',
      'min_budget', (v_snapshot ->> 'min_budget')::numeric);
  END IF;
  IF p_budget_cap > (v_snapshot ->> 'max_budget')::numeric THEN
    RETURN jsonb_build_object('success', false, 'error', 'budget_above_max',
      'max_budget', (v_snapshot ->> 'max_budget')::numeric);
  END IF;

  -- รายการของ
  IF p_items IS NULL OR jsonb_typeof(p_items) <> 'array' OR jsonb_array_length(p_items) = 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'items_required');
  END IF;

  v_max_items  := public.shop_config_num('shop_max_items', 30)::int;
  v_item_count := jsonb_array_length(p_items);
  IF v_item_count > v_max_items THEN
    RETURN jsonb_build_object('success', false, 'error', 'too_many_items', 'max_items', v_max_items);
  END IF;

  -- ต้องมีคนขับออนไลน์ ไม่งั้นสั่งไม่ได้ (Q8)
  v_driver := public.nearest_online_driver(s.lat, s.lng, p_vehicle_type, NULL);
  IF NOT COALESCE((v_driver ->> 'has_driver')::boolean, false) THEN
    RETURN jsonb_build_object('success', false, 'error', 'no_driver_available');
  END IF;

  v_driver_km  := (v_driver ->> 'nearest_km')::numeric;
  v_max_pickup := (v_snapshot ->> 'max_pickup_km')::numeric;
  IF v_max_pickup IS NOT NULL AND v_driver_km > v_max_pickup THEN
    RETURN jsonb_build_object('success', false, 'error', 'no_driver_available',
      'reason', 'nearest_driver_too_far');
  END IF;

  -- ระยะ + ค่าธรรมเนียม (คำนวณใหม่เสมอ ไม่เชื่อตัวเลขจาก client)
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

  -- กันวงเงินจาก Wallet -------------------------------------------------
  SELECT id, balance INTO v_wallet_id, v_balance
  FROM public.wallets WHERE user_id = v_uid
  FOR UPDATE;

  IF v_wallet_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'wallet_not_found');
  END IF;

  IF v_balance < v_hold THEN
    RETURN jsonb_build_object(
      'success', false, 'error', 'insufficient_balance',
      'balance', ROUND(v_balance, 2),
      'required', v_hold,
      'shortfall', ROUND(v_hold - v_balance, 2)
    );
  END IF;

  -- booking ------------------------------------------------------------
  INSERT INTO public.bookings (
    customer_id, service_type, status,
    origin_lat, origin_lng, pickup_address,
    dest_lat, dest_lng, destination_address,
    distance_km, price, delivery_fee, payment_method, notes
  ) VALUES (
    v_uid, 'shop', 'pending',
    s.lat, s.lng, COALESCE(s.address, s.name),
    p_dest_lat, p_dest_lng, p_dest_address,
    v_dist_km, v_hold, (v_fees ->> 'delivery_fee')::numeric, 'wallet', p_note
  )
  RETURNING id INTO v_booking_id;

  -- หักเงิน + ลง ledger เป็น hold
  UPDATE public.wallets
     SET balance = balance - v_hold, updated_at = now()
   WHERE id = v_wallet_id;

  INSERT INTO public.wallet_transactions (
    wallet_id, amount, type, description, related_booking_id
  ) VALUES (
    v_wallet_id, -v_hold, 'hold',
    'กันวงเงินฝากซื้อ #' || LEFT(v_booking_id::text, 8),
    v_booking_id
  )
  RETURNING id INTO v_tx_id;

  -- shop_order ---------------------------------------------------------
  INSERT INTO public.shop_orders (
    booking_id, store_id,
    store_name, store_category, store_lat, store_lng, proof_mode,
    budget_cap, hold_amount,
    service_fee, delivery_fee, far_pickup_fee,
    fee_config_snapshot, quoted_distance_km, quoted_driver_km, vehicle_type,
    customer_note, hold_transaction_id
  ) VALUES (
    v_booking_id, s.id,
    s.name, s.category, s.lat, s.lng,
    CASE WHEN s.issues_receipt THEN 'receipt' ELSE 'photo' END,
    ROUND(p_budget_cap, 2), v_hold,
    (v_fees ->> 'service_fee')::numeric,
    (v_fees ->> 'delivery_fee')::numeric,
    (v_fees ->> 'far_pickup_fee')::numeric,
    v_snapshot, v_dist_km, v_driver_km, p_vehicle_type,
    p_note, v_tx_id
  )
  RETURNING id INTO v_order_id;

  -- รายการของ -----------------------------------------------------------
  FOR v_item IN SELECT jsonb_array_elements(p_items)
  LOOP
    v_line := v_line + 1;
    IF COALESCE(btrim(v_item ->> 'name'), '') = '' THEN
      RAISE EXCEPTION 'item_name_required_at_line_%', v_line;
    END IF;

    INSERT INTO public.shop_order_items (
      shop_order_id, line_no, name_text, quantity_text, note
    ) VALUES (
      v_order_id, v_line,
      LEFT(btrim(v_item ->> 'name'), 200),
      LEFT(COALESCE(btrim(v_item ->> 'quantity'), ''), 60),
      LEFT(COALESCE(btrim(v_item ->> 'note'), ''), 300)
    );
  END LOOP;

  RETURN jsonb_build_object(
    'success',       true,
    'booking_id',    v_booking_id,
    'shop_order_id', v_order_id,
    'hold_amount',   v_hold,
    'proof_mode',    CASE WHEN s.issues_receipt THEN 'receipt' ELSE 'photo' END,
    'items',         v_line
  );
END;
$$;

REVOKE ALL ON FUNCTION public.create_shop_booking(uuid, numeric, double precision, double precision, text, jsonb, text, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_shop_booking(uuid, numeric, double precision, double precision, text, jsonb, text, text)
  TO authenticated, service_role;

-- ─────────────────────────────────────────────────────────────
-- 5) คนขับรับงาน — บังคับเพดานคนขับใหม่ที่ server
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.shop_driver_accept(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid       uuid := auth.uid();
  v_booking   public.bookings%ROWTYPE;
  v_order     public.shop_orders%ROWTYPE;
  v_trusted   boolean;
  v_done_jobs int;
  v_snapshot  jsonb;
  v_actual_km numeric;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND OR v_booking.service_type <> 'shop' THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF v_booking.status <> 'pending' OR v_booking.driver_id IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'already_taken',
      'current_status', v_booking.status);
  END IF;

  SELECT * INTO v_order FROM public.shop_orders WHERE booking_id = p_booking_id;
  v_snapshot := v_order.fee_config_snapshot;

  -- เพดานคนขับใหม่: นับเฉพาะงานฝากซื้อที่สำเร็จ + แอดมินปลดล็อกมือได้
  SELECT COALESCE(trusted, false) INTO v_trusted
  FROM public.shop_driver_flags WHERE driver_id = v_uid;

  IF NOT COALESCE(v_trusted, false) THEN
    SELECT COUNT(*) INTO v_done_jobs
    FROM public.bookings
    WHERE driver_id = v_uid AND service_type = 'shop' AND status = 'completed';

    IF v_done_jobs < COALESCE((v_snapshot ->> 'new_driver_jobs')::numeric, 20)
       AND v_order.budget_cap > COALESCE((v_snapshot ->> 'new_driver_max_budget')::numeric, 500)
    THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'new_driver_budget_limit',
        'max_budget', (v_snapshot ->> 'new_driver_max_budget')::numeric,
        'completed_jobs', v_done_jobs,
        'required_jobs', (v_snapshot ->> 'new_driver_jobs')::numeric
      );
    END IF;
  END IF;

  -- บันทึกระยะของคนขับที่รับงานจริง ณ ตอนกดรับ
  -- ห้ามใช้ quoted_driver_km ตอน settle เพราะนั่นคือคนขับที่ใกล้ที่สุด ณ ตอน quote
  -- ซึ่งอาจไม่ใช่คนเดียวกับคนที่รับงาน -> ค่าวิ่งไกลจะจ่ายผิดคน (รั่วทั้งสองทาง)
  SELECT ROUND(
           (6371 * acos(
             LEAST(1.0, cos(radians(dl.location_lat)) * cos(radians(v_order.store_lat))
               * cos(radians(v_order.store_lng) - radians(dl.location_lng))
               + sin(radians(dl.location_lat)) * sin(radians(v_order.store_lat)))
           ))::numeric, 2)
    INTO v_actual_km
  FROM public.driver_locations dl
  WHERE dl.driver_id = v_uid
    AND dl.location_lat IS NOT NULL
    AND dl.location_lng IS NOT NULL
    AND NOT (dl.location_lat = 0 AND dl.location_lng = 0);

  UPDATE public.bookings
     SET driver_id = v_uid, status = 'accepted', assigned_at = now(), updated_at = now()
   WHERE id = p_booking_id;

  -- ถ้าอ่านตำแหน่งคนขับไม่ได้ ให้ fallback เป็น quoted (ไม่ทำให้รับงานไม่ได้)
  UPDATE public.shop_orders
     SET actual_driver_km = COALESCE(v_actual_km, quoted_driver_km)
   WHERE booking_id = p_booking_id;

  RETURN jsonb_build_object('success', true, 'status', 'accepted',
    'driver_distance_km', COALESCE(v_actual_km, v_order.quoted_driver_km));
END;
$$;

REVOKE ALL ON FUNCTION public.shop_driver_accept(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.shop_driver_accept(uuid) TO authenticated, service_role;

-- ─────────────────────────────────────────────────────────────
-- 6) คนขับถึงร้าน — ตรวจ "ลำดับสถานะ + ตำแหน่งจริง"
--    (ของเดิมฝั่งอาหารตรวจแค่สถานะ ดู ISSUE-20260923-001)
--    สถานะนี้คือเส้นที่ลูกค้าเริ่มโดนค่าปรับ จึงต้องบังคับที่ server
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.shop_driver_arrived_at_store(
  p_booking_id   uuid,
  p_self_reported boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid      uuid := auth.uid();
  v_booking  public.bookings%ROWTYPE;
  v_order    public.shop_orders%ROWTYPE;
  v_lat      double precision;
  v_lng      double precision;
  v_seen     timestamptz;
  v_dist_m   numeric;
  v_radius_m numeric;
  v_fresh    numeric;
  v_enabled  boolean;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND OR v_booking.service_type <> 'shop' THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF v_booking.driver_id IS DISTINCT FROM v_uid THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_your_job');
  END IF;

  IF v_booking.status <> 'accepted' THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_status',
      'current_status', v_booking.status);
  END IF;

  SELECT * INTO v_order FROM public.shop_orders WHERE booking_id = p_booking_id;

  v_enabled  := public.shop_config_bool('shop_arrival_geofence_enabled', true);
  v_radius_m := public.shop_config_num('shop_arrival_radius_m', 150);
  v_fresh    := public.shop_config_num('shop_location_freshness_sec', 120);

  IF v_enabled AND NOT COALESCE(p_self_reported, false) THEN
    SELECT location_lat, location_lng, updated_at
      INTO v_lat, v_lng, v_seen
    FROM public.driver_locations WHERE driver_id = v_uid;

    IF v_lat IS NULL OR v_lng IS NULL OR (v_lat = 0 AND v_lng = 0) THEN
      RETURN jsonb_build_object('success', false, 'error', 'driver_location_unknown');
    END IF;

    IF v_seen IS NULL OR v_seen < now() - make_interval(secs => v_fresh) THEN
      RETURN jsonb_build_object('success', false, 'error', 'driver_location_stale');
    END IF;

    v_dist_m := ROUND(
      (6371000 * acos(
        LEAST(1.0, cos(radians(v_lat)) * cos(radians(v_order.store_lat))
          * cos(radians(v_order.store_lng) - radians(v_lng))
          + sin(radians(v_lat)) * sin(radians(v_order.store_lat)))
      ))::numeric, 1
    );

    IF v_dist_m > v_radius_m THEN
      RETURN jsonb_build_object(
        'success', false, 'error', 'too_far_from_store',
        'distance_m', v_dist_m, 'allowed_m', v_radius_m
      );
    END IF;
  END IF;

  UPDATE public.bookings
     SET status = 'shopping', started_at = COALESCE(started_at, now()), updated_at = now()
   WHERE id = p_booking_id;

  UPDATE public.shop_orders
     SET arrived_at = now(),
         arrival_self_reported = COALESCE(p_self_reported, false),
         arrival_distance_m = v_dist_m,
         -- ยืนยันตำแหน่งเองให้ขึ้นคิวแอดมินไว้ก่อน เพื่อจับพฤติกรรมผิดปกติ
         needs_admin_review = needs_admin_review OR COALESCE(p_self_reported, false),
         admin_review_reason = CASE
           WHEN COALESCE(p_self_reported, false)
             THEN COALESCE(admin_review_reason || ' | ', '') || 'arrival_self_reported'
           ELSE admin_review_reason END
   WHERE booking_id = p_booking_id;

  RETURN jsonb_build_object('success', true, 'status', 'shopping', 'distance_m', v_dist_m);
END;
$$;

REVOKE ALL ON FUNCTION public.shop_driver_arrived_at_store(uuid, boolean) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.shop_driver_arrived_at_store(uuid, boolean) TO authenticated, service_role;

-- ─────────────────────────────────────────────────────────────
-- 7) คนขับติ๊กของ + กรอกราคาต่อรายการ
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.shop_driver_update_items(
  p_booking_id uuid,
  p_items      jsonb   -- [{line_no, status, actual_price, substitute_name}]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid     uuid := auth.uid();
  v_booking public.bookings%ROWTYPE;
  v_order   public.shop_orders%ROWTYPE;
  v_item    jsonb;
  v_status  text;
  v_price   numeric;
  v_total   numeric;
  v_line    int;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  -- FOR UPDATE: กัน race กับ cancel_shop_booking ที่อาจเปลี่ยนสถานะ/ปล่อย hold พร้อมกัน
  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND OR v_booking.service_type <> 'shop' THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;
  IF v_booking.driver_id IS DISTINCT FROM v_uid THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_your_job');
  END IF;
  IF v_booking.status <> 'shopping' THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_status',
      'current_status', v_booking.status);
  END IF;

  SELECT * INTO v_order FROM public.shop_orders WHERE booking_id = p_booking_id;

  FOR v_item IN SELECT jsonb_array_elements(COALESCE(p_items, '[]'::jsonb))
  LOOP
    v_status := COALESCE(v_item ->> 'status', 'pending');
    IF v_status NOT IN ('pending', 'bought', 'unavailable', 'substituted') THEN
      RETURN jsonb_build_object('success', false, 'error', 'invalid_item_status');
    END IF;

    v_line := NULL;
    BEGIN
      v_line := (v_item ->> 'line_no')::int;
    EXCEPTION WHEN others THEN
      RETURN jsonb_build_object('success', false, 'error', 'invalid_line_no');
    END;
    IF v_line IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'invalid_line_no');
    END IF;

    -- client ส่งค่าที่ไม่ใช่ตัวเลขมาได้ ต้องตอบเป็น error ปกติ ไม่ใช่ปล่อยให้ request พัง
    BEGIN
      v_price := NULLIF(v_item ->> 'actual_price', '')::numeric;
    EXCEPTION WHEN others THEN
      RETURN jsonb_build_object('success', false, 'error', 'invalid_price',
        'line_no', v_line);
    END;

    IF v_price IS NOT NULL AND v_price < 0 THEN
      RETURN jsonb_build_object('success', false, 'error', 'negative_price');
    END IF;
    -- ราคาต่อชิ้นห้ามเกินวงเงินทั้งออเดอร์ (กันพิมพ์ผิดหลักพัน)
    IF v_price IS NOT NULL AND v_price > v_order.budget_cap THEN
      RETURN jsonb_build_object('success', false, 'error', 'item_price_exceeds_budget',
        'budget_cap', v_order.budget_cap);
    END IF;

    UPDATE public.shop_order_items
       SET status          = v_status,
           actual_price    = CASE WHEN v_status IN ('bought','substituted') THEN v_price ELSE NULL END,
           substitute_name = LEFT(NULLIF(btrim(COALESCE(v_item ->> 'substitute_name','')), ''), 200)
     WHERE shop_order_id = v_order.id
       AND line_no = v_line;

    -- line_no ที่ไม่มีอยู่จริง ต้องไม่เงียบ ไม่งั้นคนขับคิดว่าบันทึกแล้วแต่ข้อมูลหาย
    IF NOT FOUND THEN
      RETURN jsonb_build_object('success', false, 'error', 'item_not_found',
        'line_no', v_line);
    END IF;
  END LOOP;

  SELECT COALESCE(SUM(actual_price), 0) INTO v_total
  FROM public.shop_order_items
  WHERE shop_order_id = v_order.id AND status IN ('bought', 'substituted');

  RETURN jsonb_build_object(
    'success', true,
    'goods_subtotal', ROUND(v_total, 2),
    'budget_cap', v_order.budget_cap,
    'over_budget', (v_total > v_order.budget_cap),
    'unavailable_count', (
      SELECT COUNT(*) FROM public.shop_order_items
      WHERE shop_order_id = v_order.id AND status = 'unavailable'
    )
  );
END;
$$;

REVOKE ALL ON FUNCTION public.shop_driver_update_items(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.shop_driver_update_items(uuid, jsonb) TO authenticated, service_role;

-- ─────────────────────────────────────────────────────────────
-- 8) คนขับยืนยันซื้อแล้ว — ต้องมีหลักฐาน และห้ามเกินวงเงินที่ hold
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.shop_mark_purchased(
  p_booking_id uuid,
  p_proof_urls text[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid       uuid := auth.uid();
  v_booking   public.bookings%ROWTYPE;
  v_order     public.shop_orders%ROWTYPE;
  v_goods     numeric;
  v_pending   int;
  v_fees      jsonb;
  v_total     numeric;
  v_next      text;
  v_threshold numeric;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND OR v_booking.service_type <> 'shop' THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;
  IF v_booking.driver_id IS DISTINCT FROM v_uid THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_your_job');
  END IF;
  IF v_booking.status <> 'shopping' THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_status',
      'current_status', v_booking.status);
  END IF;

  IF p_proof_urls IS NULL OR array_length(p_proof_urls, 1) IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'proof_required');
  END IF;

  SELECT * INTO v_order FROM public.shop_orders WHERE booking_id = p_booking_id;

  SELECT COUNT(*) FILTER (WHERE status = 'pending'),
         COALESCE(SUM(actual_price) FILTER (WHERE status IN ('bought','substituted')), 0)
    INTO v_pending, v_goods
  FROM public.shop_order_items WHERE shop_order_id = v_order.id;

  IF v_pending > 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'items_still_pending',
      'pending_count', v_pending);
  END IF;

  IF v_goods <= 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'nothing_bought');
  END IF;

  -- ค่าบริการคิดใหม่จาก "ยอดจริง" โดยใช้ snapshot เดิม
  -- ใช้ระยะของคนขับที่รับงานจริง ไม่ใช่ระยะตอน quote
  v_fees := public.shop_compute_fees(
    v_order.fee_config_snapshot, v_goods, v_order.store_category,
    v_order.quoted_distance_km,
    COALESCE(v_order.actual_driver_km, v_order.quoted_driver_km),
    v_order.vehicle_type
  );
  v_total := ROUND(v_goods + (v_fees ->> 'total_fees')::numeric, 2);

  -- ห้ามเกินยอดที่กันไว้ — ต้องให้ลูกค้าเพิ่มวงเงินก่อน
  IF v_total > v_order.hold_amount THEN
    RETURN jsonb_build_object(
      'success', false, 'error', 'exceeds_hold',
      'total_amount', v_total, 'hold_amount', v_order.hold_amount,
      'shortfall', ROUND(v_total - v_order.hold_amount, 2)
    );
  END IF;

  -- ร้านไม่มีใบเสร็จ -> ต้องให้ลูกค้ายืนยันรูปก่อน
  v_next := CASE WHEN v_order.proof_mode = 'photo' THEN 'receipt_review' ELSE 'purchased' END;

  v_threshold := public.shop_config_num('shop_receipt_review_threshold_percent', 10);

  UPDATE public.shop_orders
     SET proof_urls          = p_proof_urls,
         actual_goods_amount = ROUND(v_goods, 2),
         service_fee         = (v_fees ->> 'service_fee')::numeric,
         delivery_fee        = (v_fees ->> 'delivery_fee')::numeric,
         far_pickup_fee      = (v_fees ->> 'far_pickup_fee')::numeric,
         total_amount        = v_total,
         proof_sent_at       = now(),
         -- ยอดจริงต่างจากวงเงินที่ตั้งไว้มากผิดปกติ -> ให้แอดมินดู
         needs_admin_review  = needs_admin_review
           OR (v_order.budget_cap > 0
               AND abs(v_goods - v_order.budget_cap) / v_order.budget_cap * 100 > v_threshold),
         admin_review_reason = CASE
           WHEN v_order.budget_cap > 0
            AND abs(v_goods - v_order.budget_cap) / v_order.budget_cap * 100 > v_threshold
           THEN COALESCE(admin_review_reason || ' | ', '') || 'amount_variance'
           ELSE admin_review_reason END
   WHERE booking_id = p_booking_id;

  UPDATE public.bookings
     SET status = v_next, updated_at = now()
   WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'status', v_next,
    'goods_amount', ROUND(v_goods, 2),
    'total_amount', v_total,
    'awaiting_customer', (v_next = 'receipt_review')
  );
END;
$$;

REVOKE ALL ON FUNCTION public.shop_mark_purchased(uuid, text[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.shop_mark_purchased(uuid, text[]) TO authenticated, service_role;

-- ─────────────────────────────────────────────────────────────
-- 9) ลูกค้ายืนยันรูปสินค้า (ร้านที่ไม่มีใบเสร็จ)
--    ไม่มี auto-confirm ตามที่ผู้ใช้สั่ง — ครบ 5 นาทีแค่ขึ้นช่องทางติดต่อคนขับ
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.shop_customer_confirm_proof(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid     uuid := auth.uid();
  v_booking public.bookings%ROWTYPE;
  v_is_admin boolean := public.is_admin();
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND OR v_booking.service_type <> 'shop' THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF NOT v_is_admin AND v_booking.customer_id IS DISTINCT FROM v_uid THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_your_order');
  END IF;

  IF v_booking.status <> 'receipt_review' THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_status',
      'current_status', v_booking.status);
  END IF;

  UPDATE public.shop_orders
     SET customer_confirmed_at = now(),
         confirmed_by = CASE WHEN v_is_admin AND v_booking.customer_id IS DISTINCT FROM v_uid
                             THEN 'admin' ELSE 'customer' END
   WHERE booking_id = p_booking_id;

  UPDATE public.bookings
     SET status = 'purchased', updated_at = now()
   WHERE id = p_booking_id;

  RETURN jsonb_build_object('success', true, 'status', 'purchased');
END;
$$;

REVOKE ALL ON FUNCTION public.shop_customer_confirm_proof(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.shop_customer_confirm_proof(uuid) TO authenticated, service_role;

-- ─────────────────────────────────────────────────────────────
-- 10) ปิดงาน — settle + คืนส่วนต่าง + จ่ายคนขับ (transaction เดียว)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.complete_shop_booking(p_booking_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid          uuid := auth.uid();
  v_booking      public.bookings%ROWTYPE;
  v_order        public.shop_orders%ROWTYPE;
  v_refund       numeric;
  v_driver_share numeric;
  v_driver_pay   numeric;
  v_cust_wallet  uuid;
  v_drv_wallet   uuid;
  v_refund_tx    uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND OR v_booking.service_type <> 'shop' THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF NOT public.is_admin() AND v_booking.driver_id IS DISTINCT FROM v_uid THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_your_job');
  END IF;

  -- กัน double settle
  IF v_booking.status = 'completed' OR v_booking.completed_at IS NOT NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'already_completed');
  END IF;

  IF v_booking.status NOT IN ('purchased', 'delivering') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_status',
      'current_status', v_booking.status);
  END IF;

  SELECT * INTO v_order FROM public.shop_orders WHERE booking_id = p_booking_id FOR UPDATE;

  IF v_order.hold_released THEN
    RETURN jsonb_build_object('success', false, 'error', 'hold_already_released');
  END IF;
  IF v_order.total_amount IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_settled_yet');
  END IF;

  v_refund := ROUND(v_order.hold_amount - v_order.total_amount, 2);
  IF v_refund < 0 THEN
    -- ไม่ควรเกิด เพราะ shop_mark_purchased กันไว้แล้ว — fail closed
    RETURN jsonb_build_object('success', false, 'error', 'total_exceeds_hold');
  END IF;

  -- คืนส่วนต่างให้ลูกค้า
  IF v_refund > 0 THEN
    SELECT id INTO v_cust_wallet FROM public.wallets
     WHERE user_id = v_booking.customer_id FOR UPDATE;

    IF v_cust_wallet IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'customer_wallet_not_found');
    END IF;

    UPDATE public.wallets SET balance = balance + v_refund, updated_at = now()
     WHERE id = v_cust_wallet;

    INSERT INTO public.wallet_transactions (
      wallet_id, amount, type, description, related_booking_id
    ) VALUES (
      v_cust_wallet, v_refund, 'refund',
      'คืนส่วนต่างฝากซื้อ #' || LEFT(p_booking_id::text, 8),
      p_booking_id
    )
    RETURNING id INTO v_refund_tx;
  END IF;

  -- จ่ายคนขับ: คืนค่าสินค้าที่สำรอง + ส่วนแบ่งค่าบริการ + ค่าส่ง + ค่าวิ่งไกล
  v_driver_share := COALESCE((v_order.fee_config_snapshot ->> 'driver_share_pct')::numeric, 80);
  v_driver_pay := ROUND(
      v_order.actual_goods_amount
    + (v_order.service_fee * v_driver_share / 100.0)
    + v_order.delivery_fee
    + v_order.far_pickup_fee
  , 2);

  IF v_booking.driver_id IS NOT NULL AND v_driver_pay > 0 THEN
    SELECT id INTO v_drv_wallet FROM public.wallets
     WHERE user_id = v_booking.driver_id FOR UPDATE;

    IF v_drv_wallet IS NULL THEN
      RETURN jsonb_build_object('success', false, 'error', 'driver_wallet_not_found');
    END IF;

    UPDATE public.wallets SET balance = balance + v_driver_pay, updated_at = now()
     WHERE id = v_drv_wallet;

    INSERT INTO public.wallet_transactions (
      wallet_id, amount, type, description, related_booking_id
    ) VALUES (
      v_drv_wallet, v_driver_pay, 'job_payout',
      'รายได้งานฝากซื้อ #' || LEFT(p_booking_id::text, 8),
      p_booking_id
    );
  END IF;

  UPDATE public.shop_orders
     SET refund_amount = v_refund,
         refund_transaction_id = v_refund_tx,
         hold_released = true
   WHERE booking_id = p_booking_id;

  UPDATE public.bookings
     SET status = 'completed',
         completed_at = now(),
         driver_earnings = v_driver_pay,
         app_earnings = ROUND(v_order.service_fee * (100 - v_driver_share) / 100.0, 2),
         updated_at = now()
   WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'total_amount', v_order.total_amount,
    'refund_amount', v_refund,
    'driver_payout', v_driver_pay
  );
END;
$$;

REVOKE ALL ON FUNCTION public.complete_shop_booking(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.complete_shop_booking(uuid) TO authenticated, service_role;

-- ─────────────────────────────────────────────────────────────
-- 11) ยกเลิก — คืน hold ตามนโยบาย (25% สูงสุด 100฿ เข้าคนขับ 100%)
-- ─────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION public.cancel_shop_booking(
  p_booking_id uuid,
  p_reason     text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid         uuid := auth.uid();
  v_is_admin    boolean := public.is_admin();
  v_booking     public.bookings%ROWTYPE;
  v_order       public.shop_orders%ROWTYPE;
  v_fee         numeric := 0;
  v_goods_due   numeric := 0;   -- ค่าสินค้าที่คนขับสำรองไปแล้ว ต้องคืนคนขับ
  v_refund      numeric;
  v_cust_wallet uuid;
  v_drv_wallet  uuid;
  v_to_driver   numeric;
  v_refund_tx   uuid;
  v_snap        jsonb;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND OR v_booking.service_type <> 'shop' THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF NOT v_is_admin
     AND v_booking.customer_id IS DISTINCT FROM v_uid
     AND v_booking.driver_id IS DISTINCT FROM v_uid THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_your_order');
  END IF;

  IF v_booking.status IN ('completed', 'cancelled') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_status',
      'current_status', v_booking.status);
  END IF;

  -- ซื้อของแล้วยกเลิกไม่ได้ ต้องผ่านแอดมินเท่านั้น
  IF v_booking.status IN ('receipt_review', 'purchased', 'delivering') AND NOT v_is_admin THEN
    RETURN jsonb_build_object('success', false, 'error', 'cannot_cancel_after_purchase',
      'current_status', v_booking.status);
  END IF;

  SELECT * INTO v_order FROM public.shop_orders WHERE booking_id = p_booking_id FOR UPDATE;

  IF v_order.hold_released THEN
    RETURN jsonb_build_object('success', false, 'error', 'hold_already_released');
  END IF;

  v_snap := v_order.fee_config_snapshot;

  -- ค่าปรับเฉพาะตอน shopping และเฉพาะเมื่อลูกค้าเป็นคนยกเลิก
  -- (คนขับยกเลิกเอง / แอดมินยกเลิก ไม่ควรให้ลูกค้าจ่าย)
  IF v_booking.status = 'shopping' AND v_booking.customer_id = v_uid THEN
    v_fee := ROUND(
      LEAST(
        v_order.hold_amount * COALESCE((v_snap ->> 'cancel_fee_pct')::numeric, 25) / 100.0,
        COALESCE((v_snap ->> 'cancel_fee_max')::numeric, 100)
      ), 2);
  END IF;

  -- แอดมินยกเลิกหลังคนขับจ่ายเงินที่ร้านไปแล้ว:
  -- คนขับสำรองเงินค่าสินค้าไปจริง ถ้าคืนลูกค้าเต็มจำนวนคนขับจะขาดทุนเท่ากับค่าของ
  -- จึงต้องกันค่าสินค้าจริงไว้คืนคนขับก่อน แล้วคืนส่วนที่เหลือให้ลูกค้า
  -- (ของตกเป็นของลูกค้าหรือคนขับ แอดมินเป็นผู้ตัดสินนอกระบบ — ทางเลือกเต็มรูปแบบอยู่ใน S8)
  IF v_booking.status IN ('receipt_review', 'purchased', 'delivering') THEN
    v_goods_due := COALESCE(v_order.actual_goods_amount, 0);
    IF v_goods_due > v_order.hold_amount THEN
      v_goods_due := v_order.hold_amount;   -- fail closed: ห้ามจ่ายเกินที่กันไว้
    END IF;
  END IF;

  v_refund := ROUND(v_order.hold_amount - v_fee - v_goods_due, 2);
  IF v_refund < 0 THEN
    RETURN jsonb_build_object('success', false, 'error', 'refund_would_be_negative');
  END IF;

  -- คืนเงินลูกค้า
  SELECT id INTO v_cust_wallet FROM public.wallets
   WHERE user_id = v_booking.customer_id FOR UPDATE;
  IF v_cust_wallet IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'customer_wallet_not_found');
  END IF;

  IF v_refund > 0 THEN
    UPDATE public.wallets SET balance = balance + v_refund, updated_at = now()
     WHERE id = v_cust_wallet;

    INSERT INTO public.wallet_transactions (
      wallet_id, amount, type, description, related_booking_id
    ) VALUES (
      v_cust_wallet, v_refund, 'refund',
      'คืนเงินฝากซื้อที่ยกเลิก #' || LEFT(p_booking_id::text, 8),
      p_booking_id
    )
    RETURNING id INTO v_refund_tx;
  END IF;

  -- เงินเข้าคนขับ = ค่าปรับ (ค่าชดเชยเวลา) + ค่าสินค้าที่สำรองไป (คืนทุน)
  -- type แยกจาก job_payout เพราะไม่ใช่รายได้ที่ต้องหักค่าคอม
  IF v_booking.driver_id IS NOT NULL THEN
    v_to_driver := ROUND(
      v_fee * COALESCE((v_snap ->> 'cancel_to_driver_pct')::numeric, 100) / 100.0
      + v_goods_due, 2);

    IF v_to_driver > 0 THEN
      SELECT id INTO v_drv_wallet FROM public.wallets
       WHERE user_id = v_booking.driver_id FOR UPDATE;

      IF v_drv_wallet IS NULL THEN
        RETURN jsonb_build_object('success', false, 'error', 'driver_wallet_not_found');
      END IF;

      UPDATE public.wallets SET balance = balance + v_to_driver, updated_at = now()
       WHERE id = v_drv_wallet;

      INSERT INTO public.wallet_transactions (
        wallet_id, amount, type, description, related_booking_id
      ) VALUES (
        v_drv_wallet, v_to_driver, 'compensation',
        CASE WHEN v_goods_due > 0
          THEN 'คืนค่าสินค้าที่สำรอง + ค่าชดเชย ฝากซื้อที่ถูกยกเลิก #' || LEFT(p_booking_id::text, 8)
          ELSE 'ค่าชดเชยงานฝากซื้อที่ถูกยกเลิก #' || LEFT(p_booking_id::text, 8)
        END,
        p_booking_id
      );
    END IF;
  END IF;

  UPDATE public.shop_orders
     SET cancel_fee = v_fee,
         refund_amount = v_refund,
         refund_transaction_id = v_refund_tx,
         hold_released = true,
         -- ยกเลิกหลังซื้อของแล้วต้องมีคนดูเสมอ (ของอยู่กับใคร ใครรับผิดชอบ)
         needs_admin_review = needs_admin_review OR (v_goods_due > 0),
         admin_review_reason = CASE
           WHEN v_goods_due > 0
             THEN COALESCE(admin_review_reason || ' | ', '') || 'cancelled_after_purchase'
           ELSE admin_review_reason END
   WHERE booking_id = p_booking_id;

  UPDATE public.bookings
     SET status = 'cancelled',
         notes = COALESCE(notes || ' | ', '') || COALESCE('ยกเลิก: ' || p_reason, 'ยกเลิก'),
         updated_at = now()
   WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'cancel_fee', v_fee,
    'goods_reimbursed_to_driver', v_goods_due,
    'driver_credit', COALESCE(v_to_driver, 0),
    'refund_amount', v_refund
  );
END;
$$;

REVOKE ALL ON FUNCTION public.cancel_shop_booking(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_shop_booking(uuid, text) TO authenticated, service_role;

COMMIT;
