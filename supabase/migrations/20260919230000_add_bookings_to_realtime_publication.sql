-- ISSUE-20260919-001: แอปลูกค้าไม่ขึ้นออเดอร์ที่เพิ่งสั่งบนหน้าแรก
--
-- Root cause: หน้าแรกลูกค้า (และ waiting_for_driver / order_detail / ride_status /
-- tracking) ใช้ `.stream()` บนตาราง bookings เพื่อรับอัปเดตสด แต่ `bookings`
-- ไม่เคยถูกเพิ่มเข้า publication `supabase_realtime` ทำให้ postgres_changes
-- ไม่ส่ง event ให้เลย (initial fetch ผ่าน REST ยังได้ แต่ไม่มี live update)
-- ส่วน polling timer 10 วินาทีที่เคยชดเชยเรื่องนี้ถูกลบออกใน commit f488d8f
-- (2026-05-12) ด้วยสมมติฐานว่า realtime ทำงานอยู่แล้ว
--
-- Fix: เพิ่ม `public.bookings` เข้า publication แบบ idempotent
-- (รูปแบบเดียวกับ migration 20260718230000 ที่ใช้กับ notifications)
-- ผลทันที: แอปที่ติดตั้งแล้วทุกเวอร์ชันจะได้รับ INSERT/UPDATE/DELETE event
-- ของ bookings ผ่าน subscription ที่เปิดค้างอยู่ — ไม่ต้องอัปเดตแอป
--
-- หมายเหตุความเสี่ยง: ALTER PUBLICATION ADD TABLE จับ ACCESS EXCLUSIVE lock
-- บน bookings ชั่วขณะ (มิลลิวินาที ตารางเล็ก 149 แถว เขียนถี่ไม่มาก)
-- Realtime delivery ยังผ่านการกรอง filter ฝั่ง server ของแต่ละ subscription
-- (เช่น customer_id=eq.<uid>) และผ่าน RLS ตาม SELECT policy เดิม

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables
    WHERE pubname = 'supabase_realtime'
      AND schemaname = 'public'
      AND tablename = 'bookings'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.bookings;
  END IF;
END
$$;
