-- ═══════════════════════════════════════════════════════════════
-- ฝากซื้อ — กันร้านซ้ำจากการกดบันทึกย้ำ
--
-- พบบน production (2026-09-23): แถว "7-11 สาขา ตลาดปัว2" 2 แถว
-- ที่มี created_at ตรงกันถึงระดับมิลลิวินาที = คลิกเดียวแต่ INSERT 2 ครั้ง
--
-- กัน 2 ชั้น: ชั้นนี้คือชั้น DB (กันได้แม้เรียกจาก client อื่นหรือ API ตรง)
-- อีกชั้นอยู่ที่ปุ่มในหน้า Admin ที่ disable ระหว่างกำลังบันทึก
--
-- ใช้ชื่อ+พิกัดเป็นตัวชี้ซ้ำ ไม่ใช่พิกัดอย่างเดียว เพราะหลายร้านอยู่ในอาคารเดียวกันได้
-- ═══════════════════════════════════════════════════════════════

BEGIN;

-- ล้างแถวซ้ำที่ค้างอยู่ก่อน ไม่งั้นสร้าง index ไม่ผ่าน
-- เก็บแถวที่เก่าที่สุดไว้ และไม่แตะแถวที่มีออเดอร์อ้างถึง
WITH ranked AS (
  SELECT id,
         row_number() OVER (
           PARTITION BY btrim(lower(name)), lat, lng
           ORDER BY created_at, id
         ) AS rn
    FROM public.shop_stores
)
DELETE FROM public.shop_stores s
 USING ranked r
 WHERE s.id = r.id
   AND r.rn > 1
   AND NOT EXISTS (SELECT 1 FROM public.shop_orders o WHERE o.store_id = s.id);

CREATE UNIQUE INDEX IF NOT EXISTS shop_stores_name_coord_unique
  ON public.shop_stores (btrim(lower(name)), lat, lng);

COMMIT;
