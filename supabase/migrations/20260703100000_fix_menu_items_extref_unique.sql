-- fix: connect_upsert_menu upsert ล้ม 400 "no unique or exclusion constraint matching
-- the ON CONFLICT specification" — index เดิมเป็น partial (WHERE external_ref IS NOT NULL)
-- ซึ่ง supabase-js upsert(onConflict) ใช้เป็น arbiter ไม่ได้ (ระบุ WHERE ไม่ได้)
-- เปลี่ยนเป็น full unique index: แถวที่ external_ref เป็น NULL (เมนูที่ร้านสร้างเองใน JDC)
-- ไม่โดนบังคับ unique อยู่แล้วเพราะ Postgres ถือว่า NULL แต่ละแถวต่างกัน (NULLS DISTINCT)

DROP INDEX IF EXISTS public.uq_menu_items_merchant_extref;

CREATE UNIQUE INDEX IF NOT EXISTS uq_menu_items_merchant_extref
  ON public.menu_items (merchant_id, external_ref);
