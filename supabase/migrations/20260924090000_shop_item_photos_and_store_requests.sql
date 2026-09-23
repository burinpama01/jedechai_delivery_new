-- ═══════════════════════════════════════════════════════════════
-- ฝากซื้อ/ฝากหิ้ว — รูปตัวอย่างต่อรายการ + คำขอเพิ่มร้านจากลูกค้า
--
-- 1) shop_order_items.ref_image_path
--    ลูกค้าแนบรูปตัวอย่างได้ (ไม่บังคับ) เพื่อให้คนขับหยิบของถูกยี่ห้อ/ถูกขนาด
--    เก็บเป็น "path ใน bucket ส่วนตัว" ไม่ใช่ URL — รูปอาจติดข้อมูลส่วนตัวได้
--    อ่านผ่าน signed URL เท่านั้น เหมือนรูปใบเสร็จ
--
--    ลำดับจริงคือ: สร้างออเดอร์ก่อน -> ได้ booking_id -> ค่อยอัปโหลด -> ผูก path
--    เพราะ policy ของ storage ตรวจสิทธิ์จาก booking_id ที่อยู่ใน path
--    ถ้าอัปโหลดก่อนมีออเดอร์จะไม่มีอะไรให้ตรวจสิทธิ์เลย
--
-- 2) shop_store_requests
--    ลูกค้าส่งคำขอเพิ่มหมุดร้านได้ แต่ **ไม่ได้สร้างร้านเอง**
--    ร้านยังคงเป็นของแอดมินอย่างเดียวตามข้อกำหนดเดิม (แผน v4 หัวข้อ 2)
--    แอดมินอนุมัติ -> ระบบสร้างร้านให้แบบ is_active = false
--    เพราะคำขอไม่มีเวลาเปิด-ปิด ถ้าเปิดใช้งานทันทีร้านจะ "ไม่เคยเปิด" ตลอดกาล
--    (opening_hours ว่าง = ปิดทุกวัน) แล้วลูกค้าจะเห็นร้านที่กดไม่ได้
-- ═══════════════════════════════════════════════════════════════

BEGIN;

-- ─────────────────────────────────────────────────────────────
-- 1) รูปตัวอย่างต่อรายการ
-- ─────────────────────────────────────────────────────────────
ALTER TABLE public.shop_order_items
  ADD COLUMN IF NOT EXISTS ref_image_path text;

-- ผูก path รูปกับรายการหลังอัปโหลดเสร็จ
--
-- แยกเป็น RPC ของตัวเองแทนที่จะยัดเข้า create_shop_booking เพราะ:
--   * อัปโหลดรูปช้าและล้มได้ง่าย (เน็ตมือถือ) ถ้าผูกไว้กับการสร้างออเดอร์
--     รูปล้ม = ออเดอร์ล้ม = เงินที่ hold ไว้ต้องคืน ซึ่งไม่คุ้มเลยกับของที่ "ไม่บังคับ"
--   * ต้องมี booking_id ก่อนถึงจะอัปโหลดผ่าน policy ได้
CREATE OR REPLACE FUNCTION public.shop_set_item_images(
  p_booking_id uuid,
  p_images     jsonb              -- [{line_no:int, path:text}]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid      uuid := auth.uid();
  v_status   text;
  v_order_id uuid;
  v_img      jsonb;
  v_line     int;
  v_path     text;
  v_updated  int := 0;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT b.status, o.id INTO v_status, v_order_id
    FROM public.bookings b
    JOIN public.shop_orders o ON o.booking_id = b.id
   WHERE b.id = p_booking_id
     AND b.customer_id = v_uid
     AND b.service_type = 'shop';

  IF v_order_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_found');
  END IF;

  -- แนบได้เฉพาะก่อนคนขับเริ่มซื้อของ หลังจากนั้นเปลี่ยนรูปคือเปลี่ยนโจทย์กลางคัน
  IF v_status NOT IN ('pending', 'searching', 'accepted') THEN
    RETURN jsonb_build_object('success', false, 'error', 'too_late', 'status', v_status);
  END IF;

  IF p_images IS NULL OR jsonb_typeof(p_images) <> 'array' THEN
    RETURN jsonb_build_object('success', false, 'error', 'images_required');
  END IF;

  FOR v_img IN SELECT jsonb_array_elements(p_images)
  LOOP
    BEGIN
      v_line := (v_img ->> 'line_no')::int;
    EXCEPTION WHEN others THEN
      CONTINUE;                                   -- บรรทัดพังตัวเดียว ไม่ล้มทั้งชุด
    END;
    v_path := btrim(COALESCE(v_img ->> 'path', ''));

    IF v_line IS NULL OR v_path = '' THEN
      CONTINUE;
    END IF;

    -- path ต้องอยู่ใต้ booking ของตัวเองเท่านั้น กัน path ของงานคนอื่นถูกยัดเข้ามา
    IF split_part(v_path, '/', 1) <> p_booking_id::text THEN
      CONTINUE;
    END IF;

    UPDATE public.shop_order_items
       SET ref_image_path = LEFT(v_path, 500),
           updated_at     = now()
     WHERE shop_order_id = v_order_id
       AND line_no       = v_line;

    IF FOUND THEN
      v_updated := v_updated + 1;
    END IF;
  END LOOP;

  RETURN jsonb_build_object('success', true, 'updated', v_updated);
END;
$$;

REVOKE ALL ON FUNCTION public.shop_set_item_images(uuid, jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.shop_set_item_images(uuid, jsonb)
  TO authenticated, service_role;

-- ลูกค้าอัปโหลดรูปตัวอย่างของงานตัวเองได้ เฉพาะใต้ <booking_id>/ref/
--
-- แยก prefix 'ref/' ออกจากรูปหลักฐานของคนขับ เพื่อให้ดูออกจาก path เดียว
-- ว่าไฟล์ไหนเป็นของใคร และกันลูกค้าเขียนทับรูปใบเสร็จที่คนขับอัปไว้
DROP POLICY IF EXISTS "shop ref images customer upload" ON storage.objects;
CREATE POLICY "shop ref images customer upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'shop-receipts'
    AND split_part(name, '/', 2) = 'ref'
    AND EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = public.shop_receipt_booking_id(name)
        AND b.service_type = 'shop'
        AND b.customer_id = auth.uid()
        AND b.status IN ('pending', 'searching', 'accepted')
    )
  );

-- ลบได้เฉพาะรูปตัวอย่างของตัวเอง และยังอยู่ในช่วงที่แก้ได้
DROP POLICY IF EXISTS "shop ref images customer delete" ON storage.objects;
CREATE POLICY "shop ref images customer delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'shop-receipts'
    AND split_part(name, '/', 2) = 'ref'
    AND EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = public.shop_receipt_booking_id(name)
        AND b.service_type = 'shop'
        AND b.customer_id = auth.uid()
        AND b.status IN ('pending', 'searching', 'accepted')
    )
  );

-- policy ของคนขับเดิม (S6) ครอบทั้ง <booking_id>/ -> รวม ref/ ไปด้วย
-- ทำให้คนขับลบรูปตัวอย่างของลูกค้าทิ้งได้ระหว่างซื้อของ -> ตัด ref/ ออก
DROP POLICY IF EXISTS "shop receipts driver upload" ON storage.objects;
CREATE POLICY "shop receipts driver upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'shop-receipts'
    AND split_part(name, '/', 2) <> 'ref'
    AND EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = public.shop_receipt_booking_id(name)
        AND b.service_type = 'shop'
        AND b.driver_id = auth.uid()
        AND b.status = 'shopping'
    )
  );

DROP POLICY IF EXISTS "shop receipts driver delete" ON storage.objects;
CREATE POLICY "shop receipts driver delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'shop-receipts'
    AND split_part(name, '/', 2) <> 'ref'
    AND EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = public.shop_receipt_booking_id(name)
        AND b.service_type = 'shop'
        AND b.driver_id = auth.uid()
        AND b.status = 'shopping'
    )
  );

-- ─────────────────────────────────────────────────────────────
-- 2) คำขอเพิ่มร้านจากลูกค้า
-- ─────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS public.shop_store_requests (
  id            uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  requester_id  uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  name          text NOT NULL,
  category      text NOT NULL DEFAULT 'grocery',
  address       text,
  lat           double precision NOT NULL,
  lng           double precision NOT NULL,
  maps_url      text,
  is_24h        boolean NOT NULL DEFAULT false,
  note          text,

  status        text NOT NULL DEFAULT 'pending',
  admin_note    text,
  reviewed_by   uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  reviewed_at   timestamptz,
  created_store_id uuid REFERENCES public.shop_stores(id) ON DELETE SET NULL,

  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT shop_store_requests_category_check
    CHECK (category IN ('grocery', 'mall', 'market', 'convenience', 'pharmacy')),
  CONSTRAINT shop_store_requests_status_check
    CHECK (status IN ('pending', 'approved', 'rejected')),
  CONSTRAINT shop_store_requests_lat_check CHECK (lat BETWEEN -90 AND 90),
  CONSTRAINT shop_store_requests_lng_check CHECK (lng BETWEEN -180 AND 180),
  CONSTRAINT shop_store_requests_not_null_island CHECK (NOT (lat = 0 AND lng = 0))
);

CREATE INDEX IF NOT EXISTS shop_store_requests_status_idx
  ON public.shop_store_requests (status, created_at DESC);
CREATE INDEX IF NOT EXISTS shop_store_requests_requester_idx
  ON public.shop_store_requests (requester_id, created_at DESC);

CREATE OR REPLACE FUNCTION public.shop_store_requests_touch_updated_at()
RETURNS trigger
LANGUAGE plpgsql
SET search_path = public
AS $$
BEGIN
  NEW.updated_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS shop_store_requests_touch ON public.shop_store_requests;
CREATE TRIGGER shop_store_requests_touch
  BEFORE UPDATE ON public.shop_store_requests
  FOR EACH ROW EXECUTE FUNCTION public.shop_store_requests_touch_updated_at();

ALTER TABLE public.shop_store_requests ENABLE ROW LEVEL SECURITY;

-- อ่านได้: คำขอของตัวเอง หรือแอดมิน  (เขียนผ่าน RPC เท่านั้น ไม่มี policy INSERT/UPDATE)
DROP POLICY IF EXISTS shop_store_requests_select ON public.shop_store_requests;
CREATE POLICY shop_store_requests_select ON public.shop_store_requests
  FOR SELECT TO authenticated
  USING (requester_id = auth.uid() OR public.is_admin());

-- เปิด/ปิดปุ่มขอเพิ่มร้านได้จากหน้า Settings
INSERT INTO public.system_config (key, value)
VALUES ('shop_store_request_enabled', 'true'),
       ('shop_store_request_daily_limit', '5')
ON CONFLICT (key) WHERE key IS NOT NULL DO NOTHING;

-- ลูกค้าส่งคำขอ ---------------------------------------------------------
CREATE OR REPLACE FUNCTION public.create_shop_store_request(
  p_name     text,
  p_category text,
  p_lat      double precision,
  p_lng      double precision,
  p_address  text DEFAULT NULL,
  p_maps_url text DEFAULT NULL,
  p_is_24h   boolean DEFAULT false,
  p_note     text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid    uuid := auth.uid();
  v_name   text := LEFT(btrim(COALESCE(p_name, '')), 200);
  v_cat    text := lower(btrim(COALESCE(p_category, 'grocery')));
  v_limit  int;
  v_today  int;
  v_id     uuid;
BEGIN
  IF v_uid IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  IF NOT public.shop_config_bool('shop_store_request_enabled', true) THEN
    RETURN jsonb_build_object('success', false, 'error', 'requests_disabled');
  END IF;

  IF v_name = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'name_required');
  END IF;

  IF v_cat NOT IN ('grocery', 'mall', 'market', 'convenience', 'pharmacy') THEN
    v_cat := 'grocery';
  END IF;

  IF p_lat IS NULL OR p_lng IS NULL
     OR (p_lat = 0 AND p_lng = 0)
     OR p_lat < -90 OR p_lat > 90
     OR p_lng < -180 OR p_lng > 180 THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_location');
  END IF;

  -- ร้านนี้มีอยู่แล้วไหม (ชื่อ+พิกัดใกล้กันมาก) — บอกตรง ๆ ดีกว่าให้แอดมินมานั่งปิดซ้ำ
  IF EXISTS (
    SELECT 1 FROM public.shop_stores s
     WHERE btrim(lower(s.name)) = btrim(lower(v_name))
       AND abs(s.lat - p_lat) < 0.0005
       AND abs(s.lng - p_lng) < 0.0005
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'store_exists');
  END IF;

  IF EXISTS (
    SELECT 1 FROM public.shop_store_requests r
     WHERE r.status = 'pending'
       AND btrim(lower(r.name)) = btrim(lower(v_name))
       AND abs(r.lat - p_lat) < 0.0005
       AND abs(r.lng - p_lng) < 0.0005
  ) THEN
    RETURN jsonb_build_object('success', false, 'error', 'request_exists');
  END IF;

  -- กันสแปม: นับเฉพาะของวันนี้ตามเวลาไทย (ทั้งระบบใช้ Asia/Bangkok)
  -- นับคำขอที่ถูกปฏิเสธด้วยโดยตั้งใจ ไม่งั้นคนที่ส่งมั่วจะส่งซ้ำได้ไม่จบทุกครั้งที่แอดมินกดปฏิเสธ
  v_limit := public.shop_config_num('shop_store_request_daily_limit', 5)::int;
  SELECT count(*) INTO v_today
    FROM public.shop_store_requests r
   WHERE r.requester_id = v_uid
     AND (r.created_at AT TIME ZONE 'Asia/Bangkok')::date
         = (now() AT TIME ZONE 'Asia/Bangkok')::date;

  IF v_today >= v_limit THEN
    RETURN jsonb_build_object('success', false, 'error', 'daily_limit_reached',
                              'limit', v_limit);
  END IF;

  INSERT INTO public.shop_store_requests (
    requester_id, name, category, address, lat, lng, maps_url, is_24h, note
  ) VALUES (
    v_uid, v_name, v_cat,
    NULLIF(LEFT(btrim(COALESCE(p_address, '')), 300), ''),
    p_lat, p_lng,
    NULLIF(LEFT(btrim(COALESCE(p_maps_url, '')), 1000), ''),
    COALESCE(p_is_24h, false),
    NULLIF(LEFT(btrim(COALESCE(p_note, '')), 500), '')
  )
  RETURNING id INTO v_id;

  RETURN jsonb_build_object('success', true, 'request_id', v_id);
END;
$$;

REVOKE ALL ON FUNCTION public.create_shop_store_request(
  text, text, double precision, double precision, text, text, boolean, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.create_shop_store_request(
  text, text, double precision, double precision, text, text, boolean, text)
  TO authenticated, service_role;

-- แอดมินตรวจคำขอ --------------------------------------------------------
CREATE OR REPLACE FUNCTION public.shop_review_store_request(
  p_request_id uuid,
  p_approve    boolean,
  p_admin_note text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_uid      uuid := auth.uid();
  r          public.shop_store_requests%ROWTYPE;
  v_store_id uuid;
BEGIN
  IF v_uid IS NULL OR NOT public.is_admin() THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authorized');
  END IF;

  SELECT * INTO r FROM public.shop_store_requests
   WHERE id = p_request_id FOR UPDATE;

  IF NOT FOUND THEN
    RETURN jsonb_build_object('success', false, 'error', 'request_not_found');
  END IF;

  IF r.status <> 'pending' THEN
    RETURN jsonb_build_object('success', false, 'error', 'already_reviewed',
                              'status', r.status);
  END IF;

  IF p_approve THEN
    -- unique index กันชื่อ+พิกัดซ้ำอยู่แล้ว ถ้าชนแปลว่าแอดมินสร้างร้านนี้ไปแล้ว
    BEGIN
      INSERT INTO public.shop_stores (
        name, category, address, lat, lng, is_24h, note, source, created_by,
        -- ยังไม่รู้เวลาเปิด-ปิด -> ปิดไว้ก่อน ให้แอดมินตั้งเวลาแล้วค่อยเปิดใช้งาน
        is_active
      ) VALUES (
        r.name, r.category, r.address, r.lat, r.lng, r.is_24h, r.note,
        -- created_by = แอดมินที่อนุมัติ ให้ตรงกับร้านที่แอดมินสร้างเอง
        -- ส่วนลูกค้าที่ขอ ย้อนดูได้จาก shop_store_requests.created_store_id
        'request', v_uid,
        false
      )
      RETURNING id INTO v_store_id;
    EXCEPTION WHEN unique_violation THEN
      RETURN jsonb_build_object('success', false, 'error', 'store_exists');
    END;
  END IF;

  UPDATE public.shop_store_requests
     SET status           = CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
         admin_note       = NULLIF(LEFT(btrim(COALESCE(p_admin_note, '')), 500), ''),
         reviewed_by      = v_uid,
         reviewed_at      = now(),
         created_store_id = v_store_id
   WHERE id = p_request_id;

  RETURN jsonb_build_object(
    'success',  true,
    'status',   CASE WHEN p_approve THEN 'approved' ELSE 'rejected' END,
    'store_id', v_store_id
  );
END;
$$;

REVOKE ALL ON FUNCTION public.shop_review_store_request(uuid, boolean, text)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.shop_review_store_request(uuid, boolean, text)
  TO authenticated, service_role;

COMMIT;
