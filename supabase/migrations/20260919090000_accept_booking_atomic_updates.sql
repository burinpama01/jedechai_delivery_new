-- ISSUE-115: ค่าชดเชยระยะทาง/ค่าส่งที่ปรับแล้วถูกเขียนแยกจากการเคลมงาน
--
-- เดิม BookingService.acceptBooking() เรียก RPC accept_booking เพื่อเคลมงาน
-- แล้วค่อยยิง UPDATE bookings อีกครั้งเพื่อเขียน price / delivery_fee / notes /
-- merchant_food_ready_at ถ้า call ที่สองล้มเหลว คนขับจะได้งานแต่ไม่ได้ค่าชดเชย
-- และไม่มีทาง rollback เพราะงานถูกเคลมไปแล้ว
--
-- แก้โดยรับ p_updates jsonb เข้ามาแล้วเขียนทุกอย่างใน UPDATE เดียวกับตอนเคลม
--
-- หมายเหตุ: ต้อง DROP ตัวเดิมก่อน ไม่ใช่ปล่อยให้เป็น overload เพราะ PostgREST
-- จะเลือกไม่ถูกเมื่อ argument set ทับซ้อนกัน (p_updates มี DEFAULT)

DROP FUNCTION IF EXISTS public.accept_booking(uuid, uuid, text);

CREATE OR REPLACE FUNCTION public.accept_booking(
  p_booking_id uuid,
  p_driver_id uuid,
  p_expected_status text DEFAULT 'pending',
  p_updates jsonb DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_auth_uid uuid := auth.uid();
  v_rows_affected integer;
  v_price numeric;
  v_delivery_fee numeric;
  v_notes text;
  v_food_ready_at timestamptz;
BEGIN
  -- ISSUE-103 (แนวเดียวกัน): รับงานได้ในนามตัวเองเท่านั้น
  -- service_role (Edge Function) มี auth.uid() เป็น NULL จึงข้ามการ์ดนี้
  IF v_auth_uid IS NOT NULL AND v_auth_uid <> p_driver_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  -- แกะค่าที่จะอัปเดตออกมาก่อน เพื่อให้ UPDATE ด้านล่างอ่านง่ายและ type ชัดเจน
  IF p_updates IS NOT NULL THEN
    IF p_updates ? 'price' THEN
      v_price := (p_updates->>'price')::numeric;
    END IF;
    IF p_updates ? 'delivery_fee' THEN
      v_delivery_fee := (p_updates->>'delivery_fee')::numeric;
    END IF;
    IF p_updates ? 'notes' THEN
      v_notes := p_updates->>'notes';
    END IF;
    IF p_updates ? 'merchant_food_ready_at' THEN
      v_food_ready_at := (p_updates->>'merchant_food_ready_at')::timestamptz;
    END IF;
  END IF;

  UPDATE public.bookings
  SET driver_id = p_driver_id,
      status = 'driver_accepted',
      status_origin = 'jdc',
      assigned_at = now(),
      updated_at = now(),
      price = COALESCE(v_price, price),
      delivery_fee = COALESCE(v_delivery_fee, delivery_fee),
      notes = COALESCE(v_notes, notes),
      merchant_food_ready_at =
        COALESCE(v_food_ready_at, merchant_food_ready_at)
  WHERE id = p_booking_id
    AND driver_id IS NULL
    AND status = p_expected_status;

  GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

  IF v_rows_affected = 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'already_taken',
      'message', 'งานนี้ถูกรับไปแล้ว หรือสถานะเปลี่ยนไปแล้ว'
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'booking_id', p_booking_id);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.accept_booking(uuid, uuid, text, jsonb) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.accept_booking(uuid, uuid, text, jsonb) FROM anon;
GRANT EXECUTE ON FUNCTION public.accept_booking(uuid, uuid, text, jsonb)
  TO authenticated, service_role;
