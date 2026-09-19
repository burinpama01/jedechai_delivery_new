-- ═══════════════════════════════════════════════════════════════
-- Batch 4 — ข้อมูลครบ ตรวจย้อนหลังได้ (Master_Plan_Summary_v1)
--   P3  webhook StoreOS ส่ง coupon_discount + net_total (POS เคยเห็นยอดสูงกว่าที่ลูกค้าจ่าย)
--   G4  backfill total_amount ของออเดอร์เดิม (price + delivery_fee − ส่วนลดคูปอง)
--   (G1 snapshot rate + audit การเปลี่ยน GP + G4 ของออเดอร์ใหม่ ทำไปแล้วใน Batch 1 /
--    merchant_gp_plan_history ของงาน GP)
-- ═══════════════════════════════════════════════════════════════

BEGIN;

-- 1) P3: ใส่ส่วนลดคูปองใน payload ของ StoreOS ----------------------------
CREATE OR REPLACE FUNCTION public.notify_storeos_order()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'extensions'
AS $function$
DECLARE
  v_conn public.pos_connections%ROWTYPE;
  v_body jsonb;
  v_sig text;
  v_event_id text;
  v_discount numeric := 0;
  v_gross numeric;
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

  SELECT COALESCE(SUM(discount_amount), 0) INTO v_discount
  FROM public.coupon_usages WHERE booking_id = NEW.id;
  v_discount := GREATEST(COALESCE(v_discount, 0), 0);
  v_gross := COALESCE(NEW.price, 0) + COALESCE(NEW.delivery_fee, 0);

  v_event_id := gen_random_uuid()::text;
  v_body := jsonb_build_object(
    'topic', 'order.status',
    'event_id', v_event_id,
    'booking_id', NEW.id,
    'merchant_id', NEW.merchant_id,
    'status', NEW.status,
    'total', v_gross,
    'coupon_discount', v_discount,
    'net_total', GREATEST(v_gross - v_discount, 0),
    'merchant_total', NEW.price,
    -- price เป็น double precision — ต้อง cast เป็น numeric ให้ตรง signature ของ fn
    'commission', public.connect_merchant_gp_amount(NEW.merchant_id, NEW.price::numeric),
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
$function$;

-- 2) G4 backfill: total_amount ของออเดอร์เดิม -----------------------------
-- ใช้ข้อเท็จจริงของออเดอร์ (ราคา + ค่าส่ง − ส่วนลด) ไม่คำนวณ GP ย้อนหลัง
-- เพราะอัตราปัจจุบันอาจไม่ใช่อัตราตอนสั่ง (ดู G1)
UPDATE public.bookings b
SET total_amount = GREATEST(
      COALESCE(b.price, 0) + COALESCE(b.delivery_fee, 0)
        - COALESCE((SELECT SUM(cu.discount_amount) FROM public.coupon_usages cu WHERE cu.booking_id = b.id), 0),
      0)
WHERE COALESCE(b.total_amount, 0) = 0
  AND COALESCE(b.price, 0) + COALESCE(b.delivery_fee, 0) > 0;

COMMIT;
