-- ============================================
-- Add merchant minimum order amount column
-- ============================================
-- เพิ่มคอลัมน์ยอดสั่งซื้อขั้นต่ำต่อร้าน (min_order_amount)
-- 0 = ไม่มีขั้นต่ำ (ค่าเริ่มต้น)

ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS min_order_amount NUMERIC NOT NULL DEFAULT 0;

COMMENT ON COLUMN profiles.min_order_amount IS 'ยอดสั่งซื้อขั้นต่ำของร้าน (บาท) — 0 = ไม่มีขั้นต่ำ';

-- Constraint: ต้องไม่ติดลบ
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_min_order_amount_nonneg'
  ) THEN
    ALTER TABLE public.profiles
    ADD CONSTRAINT chk_min_order_amount_nonneg
    CHECK (min_order_amount >= 0);
  END IF;
END $$;
