-- เพิ่มคอลัมน์ max_delivery_radius ใน system_config
-- ใช้สำหรับกำหนดรัศมีจัดส่งสูงสุด (กิโลเมตร)
-- ถ้าลูกค้าสั่งอาหารเกินระยะนี้ จะแจ้งเตือนและคิดค่าส่งตามระยะทาง

ALTER TABLE public.system_config 
ADD COLUMN IF NOT EXISTS max_delivery_radius NUMERIC(5,1) DEFAULT 20.0;

-- อัปเดตค่าเริ่มต้นสำหรับ row ที่มีอยู่แล้ว
UPDATE public.system_config 
SET max_delivery_radius = 20.0 
WHERE max_delivery_radius IS NULL;
