-- StoreOS Connect รอบ #12 + fix flow ออเดอร์ขาออก
-- 1) menu_option_groups.source — แยกกลุ่มตัวเลือกที่ sync มาจาก StoreOS ออกจากที่ร้านสร้างเองใน JDC
-- 2) order.created ต้องมี items: ย้ายการยิง webhook จาก INSERT bookings (ตอนนั้น booking_items
--    ยังไม่ถูก insert — แอปสร้าง booking ก่อนแล้วค่อย insert items) ไปเป็น statement trigger
--    บน booking_items + claim ด้วย bookings.pos_order_created_at กันยิงซ้ำ
-- 3) ts ใน payload เป็นตัวเลข (เดิมส่ง string ทำให้ StoreOS ตีเป็น stale timestamp)

-- ── 1) กลุ่มตัวเลือกจาก StoreOS ─────────────────────────────────────────────
ALTER TABLE IF EXISTS public.menu_option_groups
  ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'jdc';

CREATE INDEX IF NOT EXISTS idx_menu_option_groups_source
  ON public.menu_option_groups (source);

COMMENT ON COLUMN public.menu_option_groups.source IS
  'jdc = ร้านสร้างเองใน JDC, storeos = sync มาจาก StoreOS Connect (ห้ามแก้ใน JDC — จะถูก replace ตอน sync)';

-- ── 2) claim flag สำหรับ order.created ──────────────────────────────────────
ALTER TABLE IF EXISTS public.bookings
  ADD COLUMN IF NOT EXISTS pos_order_created_at timestamptz;

COMMENT ON COLUMN public.bookings.pos_order_created_at IS
  'เวลาแจ้ง order.created ไป StoreOS แล้ว (กันยิงซ้ำเมื่อ booking_items ถูก insert หลายรอบ)';

-- ── helper: รายการอาหารของ booking ในรูปแบบ items ของ StoreOS Connect ───────
-- options ใน booking_items เก็บเป็น array ของชื่อ (string) → แปลงเป็น [{name}] ตาม contract
CREATE OR REPLACE FUNCTION public.connect_booking_items_json(p_booking_id uuid)
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
AS $$
  SELECT coalesce(jsonb_agg(jsonb_build_object(
    'menu_item_id', bi.menu_item_id,
    'external_ref', mi.external_ref,
    'name', bi.name,
    'qty', bi.quantity,
    'price', bi.price,
    'options', (
      SELECT coalesce(jsonb_agg(
        CASE
          WHEN jsonb_typeof(o.val) = 'string' THEN jsonb_build_object('name', o.val #>> '{}')
          ELSE o.val
        END
      ), '[]'::jsonb)
      FROM jsonb_array_elements(coalesce(bi.options, '[]'::jsonb)) AS o(val)
    )
  ) ORDER BY bi.created_at), '[]'::jsonb)
  FROM public.booking_items bi
  LEFT JOIN public.menu_items mi ON mi.id = bi.menu_item_id
  WHERE bi.booking_id = p_booking_id;
$$;

-- ── order.created: ยิงเมื่อ booking_items ถูก insert (มี items ครบแล้ว) ────────
CREATE OR REPLACE FUNCTION public.notify_storeos_order_created()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_conn public.pos_connections%ROWTYPE;
  v_booking public.bookings%ROWTYPE;
  v_body jsonb;
  v_sig text;
  v_event_id text;
BEGIN
  SELECT *
    INTO v_conn
    FROM public.pos_connections
   WHERE merchant_id IS NULL
     AND provider = 'storeos'
     AND status = 'active'
     AND storeos_webhook_url IS NOT NULL
   LIMIT 1;

  IF NOT FOUND THEN
    RETURN NULL;
  END IF;

  FOR v_booking IN
    SELECT b.*
      FROM public.bookings b
     WHERE b.id IN (SELECT DISTINCT ni.booking_id FROM new_items ni)
       AND b.service_type = 'food'
       AND b.merchant_id IS NOT NULL
       AND b.pos_order_created_at IS NULL
       FOR UPDATE
  LOOP
    -- claim กันยิงซ้ำ (insert items หลาย statement / retry)
    UPDATE public.bookings
       SET pos_order_created_at = now()
     WHERE id = v_booking.id
       AND pos_order_created_at IS NULL;
    IF NOT FOUND THEN
      CONTINUE;
    END IF;

    v_event_id := gen_random_uuid()::text;
    v_body := jsonb_build_object(
      'topic', 'order.created',
      'event_id', v_event_id,
      'booking_id', v_booking.id,
      'merchant_id', v_booking.merchant_id,
      'status', v_booking.status,
      'items', public.connect_booking_items_json(v_booking.id),
      -- price = ยอดอาหาร (ไม่รวมค่าส่ง) = ยอดที่ร้านได้รับ
      'merchant_total', v_booking.price,
      'total', coalesce(v_booking.price, 0) + coalesce(v_booking.delivery_fee, 0),
      'dropoff', jsonb_build_object('address', v_booking.destination_address),
      'paid', true,
      'ts', extract(epoch FROM now())::bigint
    );
    v_sig := encode(
      hmac(convert_to(v_body::text, 'UTF8'), convert_to(v_conn.webhook_secret, 'UTF8'), 'sha256'),
      'hex'
    );

    PERFORM net.http_post(
      url := v_conn.storeos_webhook_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'X-JDC-Connection-Key', v_conn.jdc_connection_key,
        'X-Connect-Event-Id', v_event_id,
        'X-Connect-Timestamp', extract(epoch FROM now())::bigint::text,
        'X-Connect-Signature', 'sha256=' || v_sig
      ),
      body := v_body
    );
  END LOOP;

  RETURN NULL;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_storeos_order_created ON public.booking_items;
CREATE TRIGGER trg_notify_storeos_order_created
AFTER INSERT ON public.booking_items
REFERENCING NEW TABLE AS new_items
FOR EACH STATEMENT
EXECUTE FUNCTION public.notify_storeos_order_created();

-- ── order.status: เหลือเฉพาะตอนสถานะเปลี่ยน (INSERT ไม่ยิงแล้ว) + ts เป็นตัวเลข ──
CREATE OR REPLACE FUNCTION public.notify_storeos_order()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_conn public.pos_connections%ROWTYPE;
  v_body jsonb;
  v_sig text;
  v_event_id text;
BEGIN
  IF NEW.service_type <> 'food' THEN
    RETURN NEW;
  END IF;

  IF NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  -- กัน echo loop: สถานะที่ StoreOS เป็นคนสั่งมา ไม่ต้องสะท้อนกลับ
  IF NEW.status_origin = 'storeos' THEN
    RETURN NEW;
  END IF;

  SELECT *
    INTO v_conn
    FROM public.pos_connections
   WHERE merchant_id IS NULL
     AND provider = 'storeos'
     AND status = 'active'
     AND storeos_webhook_url IS NOT NULL
   LIMIT 1;

  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  v_event_id := gen_random_uuid()::text;
  v_body := jsonb_build_object(
    'topic', 'order.status',
    'event_id', v_event_id,
    'booking_id', NEW.id,
    'merchant_id', NEW.merchant_id,
    'status', NEW.status,
    'total', coalesce(NEW.price, 0) + coalesce(NEW.delivery_fee, 0),
    'merchant_total', NEW.price,
    'paid', true,
    'ts', extract(epoch FROM now())::bigint
  );
  v_sig := encode(
    hmac(convert_to(v_body::text, 'UTF8'), convert_to(v_conn.webhook_secret, 'UTF8'), 'sha256'),
    'hex'
  );

  PERFORM net.http_post(
    url := v_conn.storeos_webhook_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-JDC-Connection-Key', v_conn.jdc_connection_key,
      'X-Connect-Event-Id', v_event_id,
      'X-Connect-Timestamp', extract(epoch FROM now())::bigint::text,
      'X-Connect-Signature', 'sha256=' || v_sig
    ),
    body := v_body
  );

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_notify_storeos_order ON public.bookings;
CREATE TRIGGER trg_notify_storeos_order
AFTER UPDATE OF status ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.notify_storeos_order();
