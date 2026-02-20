-- Migration: ตั้งค่าระบบ Service-Based Pricing และ Driver Wallet (เวอร์ชั่น 2)
-- วันที่: 2024-01-30
-- คำอธิบาย: สร้างตารางสำหรับระบบราคาแบบแยกตามบริการและกระเป๋าเงินคนขับ

-- ========================================
-- 1. ตาราง Service Rates (อัตราค่าบริการแต่ละประเภท)
-- ========================================
-- ใช้เก็บโครงสร้างราคาแยกตามประเภทบริการ (ride, food, parcel)
CREATE TABLE IF NOT EXISTS service_rates (
    service_type TEXT PRIMARY KEY,                 -- ประเภทบริการ: 'ride', 'food', 'parcel'
    base_price INTEGER NOT NULL,                   -- ราคาพื้นฐาน (บาท)
    base_distance DECIMAL(5,2) NOT NULL,           -- ระยะทางพื้นฐาน (กิโลเมตร)
    price_per_km INTEGER NOT NULL,                 -- ราคาต่อกิโลเมตรเพิ่มเติม (บาท)
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ========================================
-- 2. ข้อมูลเริ่มต้นสำหรับ Service Rates
-- ========================================
-- แทรกข้อมูลอัตราค่าบริการเริ่มต้น สำหรับทุกประเภท
INSERT INTO service_rates (service_type, base_price, base_distance, price_per_km)
VALUES 
    ('ride', 20, 2.0, 5),      -- บริการรับส่งผู้โดยสาร
    ('food', 20, 2.0, 5),      -- บริการส่งอาหาร
    ('parcel', 20, 2.0, 5)     -- บริการส่งพัสดุ
ON CONFLICT (service_type) DO NOTHING;

-- ========================================
-- 3. ตาราง System Config (การตั้งค่าระบบ)
-- ========================================
-- ใช้เก็บค่ากำหนดทั่วไปของระบบ
CREATE TABLE IF NOT EXISTS system_config (
    id SERIAL PRIMARY KEY,
    driver_min_wallet INTEGER DEFAULT 50,          -- เครดิตขั้นต่ำที่คนขับต้องมีเพื่อรับงาน (บาท)
    commission_rate DECIMAL(5,2) DEFAULT 15.0,      -- อัตราค่าคอมมิชชั่นจากคนขับ (%)
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ========================================
-- 4. ข้อมูลเริ่มต้นสำหรับ System Config
-- ========================================
-- แทรกข้อมูลเริ่มต้น ถ้ายังไม่มีข้อมูล
INSERT INTO system_config (driver_min_wallet, commission_rate)
VALUES (50, 15.0)
ON CONFLICT DO NOTHING;

-- ========================================
-- 5. ตาราง Wallets (กระเป๋าเงินคนขับ)
-- ========================================
-- ใช้เก็บยอดเงินคงเหลือของคนขับแต่ละคน
CREATE TABLE IF NOT EXISTS wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    balance NUMERIC(10,2) DEFAULT 0.00,            -- ยอดเงินคงเหลือ (รองรับทศนิยมสำหรับค่าคอมมิชชั่น)
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- บังคับให้ user_id ไม่ซ้ำกัน
    CONSTRAINT unique_user_wallet UNIQUE (user_id)
);

-- ========================================
-- 6. ตาราง Wallet Transactions (บันทึกการเคลื่อนไหวเงิน)
-- ========================================
-- บันทึกทุกการเคลื่อนไหวของเงินในกระเป๋าคนขับ
CREATE TABLE IF NOT EXISTS wallet_transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    wallet_id UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
    amount NUMERIC(10,2) NOT NULL,                  -- จำนวนเงิน (บวก=เติมเงิน, ลบ=หักเงิน)
    type TEXT NOT NULL,                              -- ประเภทการทำรายการ: 'topup', 'commission', 'job_income', 'penalty'
    description TEXT,                                -- รายละเอียดการทำรายการ
    related_booking_id TEXT,                         -- อ้างอิงไปยัง booking_id (ถ้ามี)
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ========================================
-- 7. Indexes สำหรับประสิทธิภาพ
-- ========================================
-- สร้าง index สำหรับการค้นหาที่รวดเร็ว
CREATE INDEX IF NOT EXISTS idx_service_rates_type ON service_rates(service_type);
CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_wallet_id ON wallet_transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_created_at ON wallet_transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_type ON wallet_transactions(type);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_booking_id ON wallet_transactions(related_booking_id) WHERE related_booking_id IS NOT NULL;

-- ========================================
-- 8. Trigger สร้าง Wallet อัตโนมัติเมื่อมี User ใหม่
-- ========================================
-- สร้าง function สำหรับสร้าง wallet เมื่อมีผู้ใช้ใหม่
CREATE OR REPLACE FUNCTION create_wallet_for_new_user()
RETURNS TRIGGER AS $$
BEGIN
    -- สร้าง wallet สำหรับผู้ใช้ใหม่ที่เป็นคนขับ
    IF NEW.role = 'driver' THEN
        INSERT INTO wallets (user_id, balance)
        VALUES (NEW.id, 0.00)
        ON CONFLICT (user_id) DO NOTHING;
        
        -- Log การสร้าง wallet (ถ้าต้องการ)
        RAISE NOTICE 'Created wallet for driver: %', NEW.id;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- สร้าง trigger ที่ทำงานหลังจาก insert ในตาราง profiles
DROP TRIGGER IF EXISTS trigger_create_wallet_for_new_user ON profiles;
CREATE TRIGGER trigger_create_wallet_for_new_user
    AFTER INSERT ON profiles
    FOR EACH ROW
    EXECUTE FUNCTION create_wallet_for_new_user();

-- ========================================
-- 9. Trigger อัปเดต updated_at สำหรับ Wallets
-- ========================================
-- สร้าง function สำหรับอัปเดต timestamp
CREATE OR REPLACE FUNCTION update_wallet_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- สร้าง trigger สำหรับอัปเดต updated_at
DROP TRIGGER IF EXISTS trigger_update_wallet_updated_at ON wallets;
CREATE TRIGGER trigger_update_wallet_updated_at
    BEFORE UPDATE ON wallets
    FOR EACH ROW
    EXECUTE FUNCTION update_wallet_updated_at();

-- ========================================
-- 10. Trigger อัปเดต updated_at สำหรับ Service Rates
-- ========================================
-- สร้าง function สำหรับอัปเดต timestamp ของ service_rates
CREATE OR REPLACE FUNCTION update_service_rates_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- สร้าง trigger สำหรับอัปเดต updated_at
DROP TRIGGER IF EXISTS trigger_update_service_rates_updated_at ON service_rates;
CREATE TRIGGER trigger_update_service_rates_updated_at
    BEFORE UPDATE ON service_rates
    FOR EACH ROW
    EXECUTE FUNCTION update_service_rates_updated_at();

-- ========================================
-- 11. Trigger อัปเดต updated_at สำหรับ System Config
-- ========================================
-- สร้าง function สำหรับอัปเดต timestamp ของ system_config
CREATE OR REPLACE FUNCTION update_system_config_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- สร้าง trigger สำหรับอัปเดต updated_at
DROP TRIGGER IF EXISTS trigger_update_system_config_updated_at ON system_config;
CREATE TRIGGER trigger_update_system_config_updated_at
    BEFORE UPDATE ON system_config
    FOR EACH ROW
    EXECUTE FUNCTION update_system_config_updated_at();

-- ========================================
-- 12. RLS (Row Level Security) - เพิ่มความปลอดภัย
-- ========================================
-- เปิดใช้งาน RLS สำหรับตาราง wallets
ALTER TABLE wallets ENABLE ROW LEVEL SECURITY;

-- สร้าง policy ให้ผู้ใช้เห็นเฉพาะ wallet ของตัวเอง
CREATE POLICY "Users can view own wallet" ON wallets
    FOR SELECT USING (auth.uid() = user_id);

-- สร้าง policy ให้ผู้ใช้เห็น transactions ของตัวเอง
ALTER TABLE wallet_transactions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "Users can view own wallet transactions" ON wallet_transactions
    FOR SELECT USING (
        wallet_id IN (
            SELECT id FROM wallets WHERE user_id = auth.uid()
        )
    );

-- ========================================
-- 13. Views สำหรับการคำนวณราคา (Utility Views)
-- ========================================
-- สร้าง view สำหรับดูข้อมูลราคาบริการทั้งหมด
CREATE OR REPLACE VIEW service_pricing_view AS
SELECT 
    sr.service_type,
    sr.base_price,
    sr.base_distance,
    sr.price_per_km,
    sc.driver_min_wallet,
    sc.commission_rate,
    sr.updated_at as pricing_updated,
    sc.updated_at as config_updated
FROM service_rates sr
CROSS JOIN system_config sc;

-- ========================================
-- 14. Functions สำหรับการคำนวณราคา
-- ========================================
-- สร้าง function สำหรับคำนวณราคาตามระยะทางและประเภทบริการ
CREATE OR REPLACE FUNCTION calculate_trip_price(
    p_service_type TEXT,
    p_distance_km DECIMAL
)
RETURNS DECIMAL(10,2) AS $$
DECLARE
    v_base_price INTEGER;
    v_base_distance DECIMAL;
    v_price_per_km INTEGER;
    v_extra_distance DECIMAL;
    v_extra_price INTEGER;
    v_total_price DECIMAL(10,2);
BEGIN
    -- ดึงข้อมูลราคาจาก service_rates
    SELECT base_price, base_distance, price_per_km 
    INTO v_base_price, v_base_distance, v_price_per_km
    FROM service_rates 
    WHERE service_type = p_service_type;
    
    -- ถ้าไม่พบข้อมูล ให้ใช้ค่าเริ่มต้น
    IF v_base_price IS NULL THEN
        v_base_price := 20;
        v_base_distance := 2.0;
        v_price_per_km := 5;
    END IF;
    
    -- คำนวณระยะทางที่เกิน
    IF p_distance_km > v_base_distance THEN
        v_extra_distance := p_distance_km - v_base_distance;
        v_extra_price := CEIL(v_extra_distance * v_price_per_km);
    ELSE
        v_extra_price := 0;
    END IF;
    
    -- คำนวณราคารวม
    v_total_price := v_base_price + v_extra_price;
    
    RETURN v_total_price;
END;
$$ LANGUAGE plpgsql;

-- ========================================
-- 15. Comments สำหรับคำอธิบายเพิ่มเติม
-- ========================================
COMMENT ON TABLE service_rates IS 'ตารางเก็บอัตราค่าบริการแยกตามประเภท';
COMMENT ON COLUMN service_rates.service_type IS 'ประเภทบริการ: ride, food, parcel';
COMMENT ON COLUMN service_rates.base_price IS 'ราคาพื้นฐานเริ่มต้น (บาท)';
COMMENT ON COLUMN service_rates.base_distance IS 'ระยะทางที่ราคาพื้นฐานครอบคลุม (กิโลเมตร)';
COMMENT ON COLUMN service_rates.price_per_km IS 'ราคาต่อกิโลเมตรเพิ่มเติม (บาท)';

COMMENT ON TABLE system_config IS 'ตารางเก็บการตั้งค่าระบบทั่วไป';
COMMENT ON COLUMN system_config.driver_min_wallet IS 'ยอดเงินขั้นต่ำที่คนขับต้องมีเพื่อรับงาน (บาท)';
COMMENT ON COLUMN system_config.commission_rate IS 'อัตราค่าคอมมิชชั่นที่หักจากคนขับ (%)';

COMMENT ON TABLE wallets IS 'ตารางเก็บยอดเงินคงเหลือของคนขับ';
COMMENT ON COLUMN wallets.balance IS 'ยอดเงินคงเหลือปัจจุบัน (รองรับทศนิยมสำหรับค่าคอมมิชชั่น)';

COMMENT ON TABLE wallet_transactions IS 'ตารางบันทึกการเคลื่อนไหวเงินทั้งหมด';
COMMENT ON COLUMN wallet_transactions.amount IS 'จำนวนเงิน (บวกสำหรับเติมเงิน, ลบสำหรับหักเงิน)';
COMMENT ON COLUMN wallet_transactions.type IS 'ประเภทการทำรายการ: topup, commission, job_income, penalty';
COMMENT ON COLUMN wallet_transactions.related_booking_id IS 'รหัสการจองที่เกี่ยวข้อง (ถ้ามี)';

COMMENT ON FUNCTION calculate_trip_price IS 'ฟังก์ชันสำหรับคำนวณราคาทริปตามระยะทางและประเภทบริการ';

-- ========================================
-- 16. เสร็จสมบูรณ์
-- ========================================
-- Migration เวอร์ชั่น 2 นี้สร้างโครงสร้างพื้นฐานสำหรับระบบราคาแบบแยกตามบริการและกระเป๋าเงินคนขับ
-- พร้อมใช้งานกับระบบจองรถ ส่งอาหาร และพัสดุ
-- รองรับการคำนวณราคาอัตโนมัติและจัดการเงินคนขับอย่างสมบูรณ์
