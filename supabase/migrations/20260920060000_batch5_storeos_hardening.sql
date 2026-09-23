-- ═══════════════════════════════════════════════════════════════
-- Batch 5 — ความทนทาน/นโยบาย StoreOS (Master_Plan_Summary_v1)
--   F4  pos_outbound_events: log ทุก event ที่ยิงไป StoreOS (มองเห็นได้ ไม่ทำ retry engine ในรอบนี้)
--   F5  ส่งเฉพาะร้านที่ลงทะเบียน: ถ้ามี connection ของร้านนั้นใช้ตัวนั้น
--       ถ้าไม่มี ใช้ connection ระบบ (merchant_id IS NULL) ต่อเมื่อ config storeos_push_all_merchants = true
--   F8  profiles.shop_status_source: รู้ว่าสถานะร้านล่าสุดมาจาก POS หรือ JDC (กัน last-write-wins แบบเงียบ)
-- ═══════════════════════════════════════════════════════════════

BEGIN;

-- 1) F4: ตาราง log ----------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.pos_outbound_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id text NOT NULL,
  topic text NOT NULL,
  booking_id uuid,
  merchant_id uuid,
  connection_id uuid,
  status text,
  target_url text,
  payload jsonb,
  http_request_id bigint,
  created_at timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pos_outbound_events_created ON public.pos_outbound_events (created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pos_outbound_events_booking ON public.pos_outbound_events (booking_id);
COMMENT ON TABLE public.pos_outbound_events IS 'log ของ webhook ที่ JDC ยิงไป StoreOS (F4)';

ALTER TABLE public.pos_outbound_events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "pos_outbound_events_admin" ON public.pos_outbound_events;
CREATE POLICY "pos_outbound_events_admin" ON public.pos_outbound_events
  FOR SELECT TO authenticated USING (public.is_admin());
REVOKE INSERT, UPDATE, DELETE ON public.pos_outbound_events FROM anon, authenticated;

-- 2) F8: แหล่งที่มาของสถานะร้าน ---------------------------------------------
ALTER TABLE public.profiles
  ADD COLUMN IF NOT EXISTS shop_status_source text,
  ADD COLUMN IF NOT EXISTS shop_status_changed_at timestamptz;
COMMENT ON COLUMN public.profiles.shop_status_source IS 'ใครเปลี่ยนสถานะร้านล่าสุด: merchant | admin | storeos | schedule (F8)';

CREATE OR REPLACE FUNCTION public.track_shop_status_source()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_src text;
BEGIN
  IF NEW.shop_status IS NOT DISTINCT FROM OLD.shop_status THEN
    RETURN NEW;
  END IF;

  -- ผู้เรียกระบุมาเองได้ (edge function ของ POS / ตารางเวลา / แอดมิน)
  IF NEW.shop_status_source IS DISTINCT FROM OLD.shop_status_source
     AND NEW.shop_status_source IS NOT NULL THEN
    NEW.shop_status_changed_at := now();
    RETURN NEW;
  END IF;

  v_src := NULLIF(current_setting('app.shop_status_source', true), '');
  IF v_src IS NULL THEN
    IF auth.uid() IS NULL THEN
      v_src := 'system';
    ELSIF auth.uid() = NEW.id THEN
      v_src := 'merchant';
    ELSIF public.is_admin() THEN
      v_src := 'admin';
    ELSE
      v_src := 'system';
    END IF;
  END IF;

  NEW.shop_status_source := v_src;
  NEW.shop_status_changed_at := now();
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_track_shop_status_source ON public.profiles;
CREATE TRIGGER trg_track_shop_status_source
  BEFORE UPDATE OF shop_status ON public.profiles
  FOR EACH ROW
  EXECUTE FUNCTION public.track_shop_status_source();

-- 3) F4 + F5 ใน trigger ส่ง webhook ------------------------------------------
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
  v_request_id bigint;
  v_push_all boolean;
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

  -- F5: connection ของร้านนั้นก่อน
  SELECT * INTO v_conn
    FROM public.pos_connections
   WHERE merchant_id = NEW.merchant_id
     AND provider = 'storeos'
     AND status = 'active'
     AND storeos_webhook_url IS NOT NULL
   LIMIT 1;

  IF NOT FOUND THEN
    v_push_all := COALESCE(public._config_num('storeos_push_all_merchants', 1) <> 0, true);
    IF NOT v_push_all THEN
      RETURN NEW;
    END IF;
    SELECT * INTO v_conn
      FROM public.pos_connections
     WHERE merchant_id IS NULL
       AND provider = 'storeos'
       AND status = 'active'
       AND storeos_webhook_url IS NOT NULL
     LIMIT 1;
    IF NOT FOUND THEN
      RETURN NEW;
    END IF;
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
    'commission', public.connect_merchant_gp_amount(NEW.merchant_id, NEW.price::numeric),
    'paid', true,
    'ts', extract(epoch FROM now())::bigint
  );
  v_sig := encode(
    hmac(convert_to(v_body::text, 'UTF8'), convert_to(v_conn.webhook_secret, 'UTF8'), 'sha256'),
    'hex'
  );

  SELECT net.http_post(
    url := v_conn.storeos_webhook_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-JDC-Connection-Key', v_conn.jdc_connection_key,
      'X-Connect-Event-Id', v_event_id,
      'X-Connect-Timestamp', extract(epoch FROM now())::bigint::text,
      'X-Connect-Signature', 'sha256=' || v_sig
    ),
    body := v_body
  ) INTO v_request_id;

  -- F4: บันทึก event ที่ส่งออก (ไม่เก็บ signature/secret)
  INSERT INTO public.pos_outbound_events
    (event_id, topic, booking_id, merchant_id, connection_id, status, target_url, payload, http_request_id)
  VALUES
    (v_event_id, 'order.status', NEW.id, NEW.merchant_id, v_conn.id, NEW.status,
     v_conn.storeos_webhook_url, v_body, v_request_id);

  RETURN NEW;
END;
$function$;

INSERT INTO public.system_config (key, value)
SELECT 'storeos_push_all_merchants', '1'
WHERE NOT EXISTS (SELECT 1 FROM public.system_config WHERE key = 'storeos_push_all_merchants');

COMMIT;
