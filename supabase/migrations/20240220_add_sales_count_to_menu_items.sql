-- เพิ่มคอลัมน์ sales_count ใน menu_items สำหรับนับจำนวนการขาย
ALTER TABLE menu_items ADD COLUMN IF NOT EXISTS sales_count integer DEFAULT 0;

-- สร้าง index สำหรับ query สินค้าขายดี
CREATE INDEX IF NOT EXISTS idx_menu_items_sales_count ON menu_items (sales_count DESC);

-- อัพเดต sales_count จากข้อมูล booking_items ที่มีอยู่แล้ว (completed bookings)
UPDATE menu_items mi
SET sales_count = COALESCE(sub.total_sold, 0)
FROM (
  SELECT bi.menu_item_id, SUM(bi.quantity) AS total_sold
  FROM booking_items bi
  JOIN bookings b ON b.id = bi.booking_id
  WHERE b.status = 'completed'
  GROUP BY bi.menu_item_id
) sub
WHERE mi.id = sub.menu_item_id;
