-- Security Advisor: "Security Definer View" (CRITICAL) บน
--   public.service_pricing_view, public.menu_items_with_options
--
-- view ที่ไม่ได้ตั้ง security_invoker จะรันด้วยสิทธิ์เจ้าของ (postgres) -> ข้าม RLS ของตารางต้นทาง
-- ตรวจ 2026-10-04: ไม่มีโค้ดในแอป/admin-web เรียกใช้ทั้งสอง view (มีแค่ migration 20240130_*),
-- และ anon/authenticated อ่านตารางต้นทางได้ครบอยู่แล้ว (service_rates, system_config,
-- menu_items, menu_option_groups, menu_options) -> เปลี่ยนเป็น security_invoker ไม่กระทบผลลัพธ์ในวันนี้
-- แต่กันไม่ให้ view กลายเป็นช่องข้าม RLS เมื่อเข้ม policy ของตารางต้นทางภายหลัง
--
-- ถอนสิทธิ์เขียน: view ทั้งสองเป็น join (อัปเดตอัตโนมัติไม่ได้อยู่แล้ว) สิทธิ์ INSERT/UPDATE/DELETE/
-- TRUNCATE/TRIGGER/REFERENCES ที่ติดมาจาก default privileges ไม่มีประโยชน์
--
-- ⚠️ ถ้า migration ในอนาคต CREATE OR REPLACE VIEW สองตัวนี้ ต้องใส่ WITH (security_invoker = true)
--    ใน CREATE เอง ไม่งั้น reloptions จะถูกล้างกลับเป็น security definer
--
-- ย้อนกลับ:ALTER VIEW ... RESET (security_invoker); GRANT ALL ... TO anon, authenticated;

BEGIN;

ALTER VIEW public.service_pricing_view SET (security_invoker = true);
ALTER VIEW public.menu_items_with_options SET (security_invoker = true);

REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER, REFERENCES
  ON public.service_pricing_view FROM anon, authenticated;
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, TRIGGER, REFERENCES
  ON public.menu_items_with_options FROM anon, authenticated;

COMMIT;
