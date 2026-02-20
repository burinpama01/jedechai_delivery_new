-- Add shop open/close hours to profiles table for merchants
-- เพิ่มคอลัมน์เวลาเปิด-ปิดร้านสำหรับร้านค้า

ALTER TABLE profiles
ADD COLUMN IF NOT EXISTS shop_open_time TEXT DEFAULT '08:00',
ADD COLUMN IF NOT EXISTS shop_close_time TEXT DEFAULT '22:00';

-- Comment
COMMENT ON COLUMN profiles.shop_open_time IS 'เวลาเปิดร้าน (HH:mm format)';
COMMENT ON COLUMN profiles.shop_close_time IS 'เวลาปิดร้าน (HH:mm format)';
