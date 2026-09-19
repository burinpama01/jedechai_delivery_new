-- ISSUE-20260919-002: ยกเลิกออเดอร์ไม่ได้ — PostgrestException 42883
-- function hmac(bytea, bytea, unknown) does not exist
--
-- Root cause: RPC `cancel_wallet_booking_with_refund` (และ RPC hardened อื่นๆ)
-- ตั้ง `SET search_path TO 'public'` — เมื่อ UPDATE สถานะ bookings แล้ว trigger
-- trg_notify_storeos_order เรียก public.notify_storeos_order() ซึ่งเป็น
-- SECURITY DEFINER ที่ *ไม่* pin search_path เอง จึง resolve ตาม search_path
-- ของ session ณ ตอนนั้น (= public เท่านั้น) และ hmac() ของ pgcrypto อยู่ใน
-- schema `extensions` → หาไม่เจอ → 42883 → ธุรกรรมยกเลิก rollback ทั้งหมด
-- (ออเดอร์ที่ sync กับ StoreOS เท่านั้นที่ชนเพราะมี connection row active)
--
-- Fix: pin search_path ของ trigger functions ทั้งสองตัวให้รวม `extensions`
-- เพื่อให้ hmac() resolvable ไม่ว่าจะถูกเรียกจาก search_path ใด
-- ALTER FUNCTION ... SET เป็น idempotent (รันซ้ำได้ ไม่แตะ body)

ALTER FUNCTION public.notify_storeos_order() SET search_path = public, extensions;

ALTER FUNCTION public.notify_storeos_order_created() SET search_path = public, extensions;
