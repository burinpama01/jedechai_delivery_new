-- StoreOS Connect รอบ #13
-- 1) JDC-1: mark_food_ready_guarded รับ p_origin เพื่อให้ Edge Fn connect_update_order_status
--    ใช้ logic เดียวกับปุ่ม "อาหารพร้อม" ในแอปได้ (StoreOS ส่ง ready_for_pickup ขณะ
--    arrived_at_merchant / driver_accepted แล้วไม่เจอ 409 อีก) โดยติดธง status_origin='storeos'
--    กัน echo กลับ StoreOS
-- 2) JDC-2: order.created / order.status ส่ง commission (GP ที่หักจากยอดอาหาร) ให้ StoreOS
--    ใช้สูตรเดียวกับแอป (MerchantFoodConfigService.resolve + DriverAmountCalculator.foodOrderSettlement)

-- ── 1) mark_food_ready_guarded + p_origin ───────────────────────────────────
-- ต้อง DROP ก่อนเพราะเพิ่ม parameter ใหม่ (ถ้าปล่อยไว้จะกลายเป็น overload
-- 2 ตัว แล้ว PostgREST เลือก candidate ไม่ได้)
DROP FUNCTION IF EXISTS public.mark_food_ready_guarded(uuid, uuid);

CREATE OR REPLACE FUNCTION public.mark_food_ready_guarded(
  p_booking_id uuid,
  p_merchant_id uuid,
  p_origin text DEFAULT 'jdc'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_origin text := CASE WHEN p_origin = 'storeos' THEN 'storeos' ELSE 'jdc' END;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_merchant_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'merchant_auth_mismatch');
  END IF;

  SELECT *
    INTO v_booking
    FROM public.bookings
   WHERE id = p_booking_id
   FOR UPDATE;

  IF v_booking.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF v_booking.service_type <> 'food' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_food_order');
  END IF;

  IF v_booking.merchant_id <> p_merchant_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'merchant_mismatch');
  END IF;

  IF v_booking.status IN ('arrived_at_merchant', 'arrived') THEN
    UPDATE public.bookings
       SET status = 'ready_for_pickup',
           status_origin = v_origin,
           merchant_food_ready_at = now(),
           updated_at = now()
     WHERE id = p_booking_id
     RETURNING * INTO v_booking;

    RETURN jsonb_build_object(
      'success', true,
      'status', 'ready_for_pickup',
      'pending_driver_arrival', false
    );
  END IF;

  IF v_booking.status IN ('preparing', 'matched', 'driver_accepted', 'accepted') THEN
    IF v_booking.driver_id IS NULL THEN
      UPDATE public.bookings
         SET status = 'ready_for_pickup',
             status_origin = v_origin,
             merchant_food_ready_at = now(),
             updated_at = now()
       WHERE id = p_booking_id
       RETURNING * INTO v_booking;

      RETURN jsonb_build_object(
        'success', true,
        'status', 'ready_for_pickup',
        'pending_driver_arrival', false
      );
    END IF;

    -- มีคนขับแล้วแต่ยังไม่ถึงร้าน: บันทึกเวลาอาหารพร้อมไว้ก่อน สถานะจะเปลี่ยนเป็น
    -- ready_for_pickup ตอนคนขับถึงร้าน (driver_arrived_at_merchant_guarded)
    -- branch นี้สถานะไม่เปลี่ยน จึงไม่มี echo ให้ต้องกัน — คง 'jdc' เสมอ เพื่อไม่ให้
    -- 'storeos' ค้างแล้วไปกด webhook ของ status change ถัดไป (เช่น ยกเลิกออเดอร์
    -- หรือ driver arrival flip ที่ไม่ได้ set status_origin เอง) ให้เงียบหาย
    UPDATE public.bookings
       SET status_origin = 'jdc',
           merchant_food_ready_at = now(),
           updated_at = now()
     WHERE id = p_booking_id
     RETURNING * INTO v_booking;

    RETURN jsonb_build_object(
      'success', true,
      'status', v_booking.status,
      'pending_driver_arrival', true
    );
  END IF;

  RETURN jsonb_build_object(
    'success', false,
    'error', 'invalid_status',
    'current_status', v_booking.status
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_food_ready_guarded(uuid, uuid, text)
  TO authenticated, service_role;

-- ── 2) GP (commission) ของออเดอร์อาหาร ──────────────────────────────────────
-- สูตรต้องตรงกับแอป: MerchantFoodConfigService.resolve (preset plan_1/2/3 จาก gp_rate,
-- override ราย merchant, default จาก system_config) + DriverAmountCalculator
-- (_ceilMoney = ปัดขึ้นเป็นบาทเต็มแยกก้อน system/driver แล้วค่อยรวม)
CREATE OR REPLACE FUNCTION public.connect_merchant_gp_amount(
  p_merchant_id uuid,
  p_food_price numeric
)
RETURNS numeric
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
AS $$
DECLARE
  v_gp_rate numeric;
  v_profile_sys numeric;
  v_profile_drv numeric;
  v_default_sys numeric;
  v_default_drv numeric;
  v_preset_sys numeric;
  v_preset_drv numeric;
  v_sys numeric;
  v_drv numeric;
  v_max_total numeric;
  v_overflow numeric;
  v_price numeric := GREATEST(COALESCE(p_food_price, 0), 0);
BEGIN
  SELECT p.gp_rate, p.merchant_gp_system_rate, p.merchant_gp_driver_rate
    INTO v_gp_rate, v_profile_sys, v_profile_drv
    FROM public.profiles p
   WHERE p.id = p_merchant_id;

  SELECT COALESCE(sc.merchant_gp_system_rate_default, sc.merchant_gp_rate, 0.10),
         COALESCE(sc.merchant_gp_driver_rate_default, 0)
    INTO v_default_sys, v_default_drv
    FROM public.system_config sc
   WHERE sc.id = 1;

  v_default_sys := COALESCE(v_default_sys, 0.10);
  v_default_drv := COALESCE(v_default_drv, 0);

  -- preset plan_1/2/3 ตาม gp_rate (เทียบแบบ tolerance เดียวกับแอป)
  IF v_gp_rate IS NOT NULL THEN
    IF abs(v_gp_rate - 0.10) < 0.0001 THEN
      v_preset_sys := 0.10; v_preset_drv := 0.00;
    ELSIF abs(v_gp_rate - 0.20) < 0.0001 THEN
      v_preset_sys := 0.10; v_preset_drv := 0.10;
    ELSIF abs(v_gp_rate - 0.25) < 0.0001 THEN
      v_preset_sys := 0.13; v_preset_drv := 0.12;
    END IF;
  END IF;

  v_sys := LEAST(GREATEST(COALESCE(v_profile_sys, v_preset_sys, v_gp_rate, v_default_sys), 0), 1);
  v_drv := LEAST(GREATEST(COALESCE(v_profile_drv, v_preset_drv, v_default_drv), 0), 1);

  -- split รวมห้ามเกิน gp_rate ของร้าน (ตัดฝั่ง driver ก่อน เหมือนแอป)
  IF v_gp_rate IS NOT NULL THEN
    v_max_total := LEAST(GREATEST(v_gp_rate, 0), 1);
    IF v_sys + v_drv > v_max_total THEN
      v_overflow := (v_sys + v_drv) - v_max_total;
      IF v_drv >= v_overflow THEN
        v_drv := v_drv - v_overflow;
      ELSE
        v_drv := 0;
        v_sys := v_max_total;
      END IF;
    END IF;
  END IF;

  RETURN (CASE WHEN v_price * v_sys <= 0 THEN 0 ELSE ceil(v_price * v_sys) END)
       + (CASE WHEN v_price * v_drv <= 0 THEN 0 ELSE ceil(v_price * v_drv) END);
END;
$$;

-- ── 3) order.created: เพิ่ม commission ──────────────────────────────────────
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
      -- price = ยอดอาหาร (ไม่รวมค่าส่ง), commission = GP ที่หักจากยอดอาหาร
      -- StoreOS แสดงยอดจ่ายร้าน = merchant_total - commission
      'merchant_total', v_booking.price,
      -- price เป็น double precision — ต้อง cast เป็น numeric ให้ตรง signature ของ fn
      'commission', public.connect_merchant_gp_amount(v_booking.merchant_id, v_booking.price::numeric),
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

-- ── 4) order.status: เพิ่ม commission ───────────────────────────────────────
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
$$;
