-- ============================================
-- Add merchant schedule & order acceptance columns
-- ============================================
-- เพิ่มคอลัมน์สำหรับวันเปิดร้าน, โหมดรับออเดอร์, เปิด-ปิดร้านอัตโนมัติ

-- 1) shop_open_days: array of weekday keys e.g. ['mon','tue','wed','thu','fri']
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS shop_open_days TEXT[] DEFAULT '{}';

-- 2) order_accept_mode: 'manual' (default) or 'auto'
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS order_accept_mode TEXT DEFAULT 'manual';

-- 3) shop_auto_schedule_enabled: auto open/close shop based on time + days
ALTER TABLE public.profiles
ADD COLUMN IF NOT EXISTS shop_auto_schedule_enabled BOOLEAN DEFAULT true;

-- Comments
COMMENT ON COLUMN profiles.shop_open_days IS 'วันที่เปิดร้าน เช่น [mon, tue, wed, thu, fri] — ถ้าว่าง = ทุกวัน';
COMMENT ON COLUMN profiles.order_accept_mode IS 'โหมดรับออเดอร์: manual = รับเอง, auto = รับอัตโนมัติ';
COMMENT ON COLUMN profiles.shop_auto_schedule_enabled IS 'เปิด-ปิดร้านอัตโนมัติตามวันและเวลาที่กำหนด';

-- Constraint: order_accept_mode must be 'manual' or 'auto'
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'chk_order_accept_mode'
  ) THEN
    ALTER TABLE public.profiles
    ADD CONSTRAINT chk_order_accept_mode
    CHECK (order_accept_mode IN ('manual', 'auto'));
  END IF;
END $$;
