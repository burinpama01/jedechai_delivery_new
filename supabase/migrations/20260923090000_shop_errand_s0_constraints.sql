-- ═══════════════════════════════════════════════════════════════
-- ฝากซื้อ/ฝากหิ้ว — S0: ขยาย constraint ของ bookings ให้รองรับ service_type และสถานะใหม่
--
-- ต้องรันก่อน S1-S3 เสมอ
--
-- พบจาก pre-flight บน production (2026-09-23) ว่า:
--   bookings_service_type_check  อนุญาตแค่ ride / food / parcel / laundry
--   bookings_status_check        ไม่มีสถานะของฝากซื้อเลย
-- ถ้าไม่ขยายก่อน create_shop_booking จะ INSERT ไม่ผ่าน และเปลี่ยนสถานะไม่ได้
--
-- เป็นการ "เพิ่มค่าที่อนุญาต" ล้วน ๆ ไม่ตัดค่าเดิมออก -> ข้อมูลเดิมยังผ่าน constraint ทุกแถว
-- ═══════════════════════════════════════════════════════════════

BEGIN;

-- 1) service_type: เพิ่ม 'shop' -----------------------------------------
ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_service_type_check;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_service_type_check
  CHECK (service_type IN ('ride', 'food', 'parcel', 'laundry', 'shop'));

-- 2) status: เพิ่มสถานะของฝากซื้อ ---------------------------------------
--    shopping        คนขับถึงร้านแล้ว กำลังเลือกของ (เส้นที่เริ่มมีค่าปรับยกเลิก)
--    receipt_review  ส่งหลักฐานแล้ว รอลูกค้ายืนยัน (เฉพาะร้านที่ไม่ออกใบเสร็จ)
--    purchased       ซื้อครบ ยอดยืนยันแล้ว
--    delivering      กำลังนำส่ง
ALTER TABLE public.bookings DROP CONSTRAINT IF EXISTS bookings_status_check;
ALTER TABLE public.bookings ADD CONSTRAINT bookings_status_check
  CHECK (status IN (
    -- ค่าเดิมทั้งหมด (คัดลอกจาก production ห้ามตกหล่นแม้แต่ตัวเดียว)
    'pending', 'pending_merchant', 'preparing', 'matched', 'ready_for_pickup',
    'accepted', 'driver_accepted', 'arrived', 'arrived_at_merchant',
    'picking_up_order', 'in_transit', 'completed', 'cancelled',
    'searching', 'confirmed', 'driver_assigned', 'in_progress',
    -- ของฝากซื้อ
    'shopping', 'receipt_review', 'purchased', 'delivering'
  ));

-- 3) ตรวจว่าไม่มีแถวเดิมตกหล่นจาก constraint ใหม่ (fail closed ถ้ามี)
DO $$
DECLARE
  v_bad_service int;
  v_bad_status  int;
BEGIN
  SELECT count(*) INTO v_bad_service FROM public.bookings
   WHERE service_type NOT IN ('ride','food','parcel','laundry','shop');
  SELECT count(*) INTO v_bad_status FROM public.bookings
   WHERE status NOT IN (
     'pending','pending_merchant','preparing','matched','ready_for_pickup',
     'accepted','driver_accepted','arrived','arrived_at_merchant',
     'picking_up_order','in_transit','completed','cancelled',
     'searching','confirmed','driver_assigned','in_progress',
     'shopping','receipt_review','purchased','delivering');

  IF v_bad_service > 0 OR v_bad_status > 0 THEN
    RAISE EXCEPTION 'มีแถวเดิมที่ไม่ผ่าน constraint ใหม่: service_type=% status=%',
      v_bad_service, v_bad_status;
  END IF;
END $$;

COMMIT;
