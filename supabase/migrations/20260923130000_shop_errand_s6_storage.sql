-- ═══════════════════════════════════════════════════════════════
-- ฝากซื้อ/ฝากหิ้ว — S6: ที่เก็บรูปหลักฐาน (ใบเสร็จ / รูปสินค้า)
--
-- bucket เป็น private เพราะรูปใบเสร็จบอกได้ว่าลูกค้าซื้ออะไร ที่ไหน เมื่อไหร่
-- และบางใบมีที่อยู่/เบอร์โทรอยู่ด้วย -> ต้องเข้าถึงผ่าน signed URL เท่านั้น
-- (แบบเดียวกับ topup-slips และ laundry-quote-attachments ที่มีอยู่แล้ว)
--
-- โครงสร้าง path: <booking_id>/<filename>
-- ใช้ folder แรกเป็น booking_id เพื่อให้ policy ตรวจสิทธิ์จาก bookings ได้
-- ═══════════════════════════════════════════════════════════════

BEGIN;

INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES (
  'shop-receipts', 'shop-receipts', false, 8388608,
  ARRAY['image/jpeg', 'image/png', 'image/webp']
)
ON CONFLICT (id) DO UPDATE
  SET public = false,
      file_size_limit = 8388608,
      allowed_mime_types = ARRAY['image/jpeg', 'image/png', 'image/webp'];

-- helper: uuid ของ booking จาก path (folder แรก) — คืน NULL ถ้า path ไม่ใช่รูปแบบที่คาด
CREATE OR REPLACE FUNCTION public.shop_receipt_booking_id(p_name text)
RETURNS uuid
LANGUAGE plpgsql
IMMUTABLE
AS $$
DECLARE
  v_first text;
BEGIN
  v_first := split_part(COALESCE(p_name, ''), '/', 1);
  IF v_first = '' THEN RETURN NULL; END IF;
  RETURN v_first::uuid;
EXCEPTION WHEN others THEN
  RETURN NULL;
END;
$$;

-- อัปโหลดได้เฉพาะคนขับที่ถูก assign งานนั้น และงานยังไม่จบ
DROP POLICY IF EXISTS "shop receipts driver upload" ON storage.objects;
CREATE POLICY "shop receipts driver upload" ON storage.objects
  FOR INSERT TO authenticated
  WITH CHECK (
    bucket_id = 'shop-receipts'
    AND EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = public.shop_receipt_booking_id(name)
        AND b.service_type = 'shop'
        AND b.driver_id = auth.uid()
        -- เฉพาะตอนกำลังซื้อของเท่านั้น ให้ตรงกับ DELETE policy
        -- หลัง mark purchased แล้วไม่ควรมีรูปเพิ่มเข้ามาเป็นไฟล์กำพร้า
        AND b.status = 'shopping'
    )
  );

-- อ่านได้เฉพาะคู่กรณีของงานนั้น (ลูกค้า / คนขับ) หรือแอดมิน
DROP POLICY IF EXISTS "shop receipts party read" ON storage.objects;
CREATE POLICY "shop receipts party read" ON storage.objects
  FOR SELECT TO authenticated
  USING (
    bucket_id = 'shop-receipts'
    AND (
      public.is_admin()
      OR EXISTS (
        SELECT 1 FROM public.bookings b
        WHERE b.id = public.shop_receipt_booking_id(name)
          AND (b.customer_id = auth.uid() OR b.driver_id = auth.uid())
      )
    )
  );

-- คนขับลบรูปที่เพิ่งอัปโหลดผิดได้ ตราบใดที่ยังไม่ยืนยันซื้อ
DROP POLICY IF EXISTS "shop receipts driver delete" ON storage.objects;
CREATE POLICY "shop receipts driver delete" ON storage.objects
  FOR DELETE TO authenticated
  USING (
    bucket_id = 'shop-receipts'
    AND EXISTS (
      SELECT 1 FROM public.bookings b
      WHERE b.id = public.shop_receipt_booking_id(name)
        AND b.driver_id = auth.uid()
        AND b.status = 'shopping'
    )
  );

COMMIT;
