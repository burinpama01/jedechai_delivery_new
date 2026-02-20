-- Migration: ระบบส่งพัสดุ (Parcel Service)
-- วันที่: 2024-02-01
-- คำอธิบาย: สร้างตารางเก็บรายละเอียดพัสดุ และรูปภาพการส่ง

-- ========================================
-- 1. ตาราง Parcel Details (รายละเอียดพัสดุ)
-- ========================================
CREATE TABLE IF NOT EXISTS parcel_details (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    booking_id UUID NOT NULL REFERENCES bookings(id) ON DELETE CASCADE,
    
    -- ข้อมูลผู้ส่ง
    sender_name TEXT NOT NULL,
    sender_phone TEXT NOT NULL,
    sender_address TEXT,
    
    -- ข้อมูลผู้รับ
    recipient_name TEXT NOT NULL,
    recipient_phone TEXT NOT NULL,
    recipient_address TEXT,
    
    -- รายละเอียดพัสดุ
    description TEXT,
    parcel_size TEXT NOT NULL DEFAULT 'small' CHECK (parcel_size IN ('small', 'medium', 'large', 'xlarge')),
    estimated_weight_kg DECIMAL(5,2),
    
    -- รูปภาพ
    parcel_photo_url TEXT,           -- รูปพัสดุที่ลูกค้าถ่าย
    pickup_photo_url TEXT,           -- รูปตอนคนขับรับของ
    delivery_photo_url TEXT,         -- รูปตอนส่งของถึง
    signature_photo_url TEXT,        -- รูปลายเซ็นผู้รับ
    
    -- สถานะพัสดุ
    parcel_status TEXT NOT NULL DEFAULT 'created' CHECK (parcel_status IN (
        'created',           -- สร้างแล้ว รอคนขับรับ
        'picked_up',         -- คนขับรับของแล้ว
        'in_transit',        -- กำลังส่ง
        'delivered',         -- ส่งถึงแล้ว
        'returned',          -- ส่งคืน
        'cancelled'          -- ยกเลิก
    )),
    
    picked_up_at TIMESTAMP WITH TIME ZONE,
    delivered_at TIMESTAMP WITH TIME ZONE,
    
    -- Timestamps
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW() NOT NULL,
    
    -- Constraints
    CONSTRAINT unique_booking_parcel UNIQUE (booking_id)
);

-- ========================================
-- 2. Indexes
-- ========================================
CREATE INDEX IF NOT EXISTS idx_parcel_details_booking_id ON parcel_details(booking_id);
CREATE INDEX IF NOT EXISTS idx_parcel_details_status ON parcel_details(parcel_status);
CREATE INDEX IF NOT EXISTS idx_parcel_details_created_at ON parcel_details(created_at DESC);

-- ========================================
-- 3. Trigger อัปเดต updated_at
-- ========================================
CREATE OR REPLACE FUNCTION update_parcel_details_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_update_parcel_details_updated_at ON parcel_details;
CREATE TRIGGER trigger_update_parcel_details_updated_at
    BEFORE UPDATE ON parcel_details
    FOR EACH ROW
    EXECUTE FUNCTION update_parcel_details_updated_at();

-- ========================================
-- 4. RLS (Row Level Security)
-- ========================================
ALTER TABLE parcel_details ENABLE ROW LEVEL SECURITY;

-- ลูกค้าดูพัสดุของตัวเอง (ผ่าน booking)
CREATE POLICY "Customers can view own parcel details" ON parcel_details
    FOR SELECT USING (
        booking_id IN (
            SELECT id FROM bookings WHERE customer_id = auth.uid()
        )
    );

-- ลูกค้าสร้างพัสดุของตัวเอง
CREATE POLICY "Customers can insert own parcel details" ON parcel_details
    FOR INSERT WITH CHECK (
        booking_id IN (
            SELECT id FROM bookings WHERE customer_id = auth.uid()
        )
    );

-- คนขับดูพัสดุที่ตัวเองรับ
CREATE POLICY "Drivers can view assigned parcel details" ON parcel_details
    FOR SELECT USING (
        booking_id IN (
            SELECT id FROM bookings WHERE driver_id = auth.uid()
        )
    );

-- คนขับอัปเดตพัสดุที่ตัวเองรับ (อัปโหลดรูป, เปลี่ยนสถานะ)
CREATE POLICY "Drivers can update assigned parcel details" ON parcel_details
    FOR UPDATE USING (
        booking_id IN (
            SELECT id FROM bookings WHERE driver_id = auth.uid()
        )
    );

-- ========================================
-- 5. Grant permissions
-- ========================================
GRANT ALL ON parcel_details TO authenticated;
GRANT SELECT ON parcel_details TO anon;

-- ========================================
-- 6. Comments
-- ========================================
COMMENT ON TABLE parcel_details IS 'ตารางเก็บรายละเอียดพัสดุ เชื่อมกับ bookings';
COMMENT ON COLUMN parcel_details.parcel_size IS 'ขนาดพัสดุ: small, medium, large, xlarge';
COMMENT ON COLUMN parcel_details.parcel_status IS 'สถานะพัสดุ: created, picked_up, in_transit, delivered, returned, cancelled';
COMMENT ON COLUMN parcel_details.parcel_photo_url IS 'รูปพัสดุที่ลูกค้าถ่ายตอนจอง';
COMMENT ON COLUMN parcel_details.pickup_photo_url IS 'รูปที่คนขับถ่ายตอนรับของ';
COMMENT ON COLUMN parcel_details.delivery_photo_url IS 'รูปที่คนขับถ่ายตอนส่งของถึง';
COMMENT ON COLUMN parcel_details.signature_photo_url IS 'รูปลายเซ็นผู้รับ';
