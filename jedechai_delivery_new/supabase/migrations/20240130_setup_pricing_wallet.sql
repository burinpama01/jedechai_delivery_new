-- Migration: ตั้งค่าระบบ Pricing และ Wallet
-- วันที่: 2024-01-30
-- คำอธิบาย: สร้างตารางสำหรับระบบราคาและกระเป๋าเงินคนขับ

-- ========================================
-- 1. ตาราง System Settings (การตั้งค่าระบบ)
-- ========================================
-- ใช้เก็บค่ากำหนดทั่วไปของระบบ เช่น ราคาพื้นฐาน, ค่านายหน้า, อัตราค่าคอมมิชชั่น
CREATE TABLE IF NOT EXISTS system_settings (
    id SERIAL PRIMARY KEY,
    base_fare INTEGER DEFAULT 20,                    -- ราคาพื้นฐาน (บาท)
    base_distance DECIMAL(5,2) DEFAULT 2.0,          -- ระยะทางพื้นฐาน (กิโลเมตร)
    price_per_km INTEGER DEFAULT 5,                 -- ราคาต่อกิโลเมตร (บาท)
    driver_min_wallet INTEGER DEFAULT 50,           -- เครดิตขั้นต่ำที่คนขับต้องมีเพื่อรับงาน
    commission_rate DECIMAL(5,2) DEFAULT 15.0,       -- อัตราค่าคอมมิชชั่น (%)
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- ========================================
-- 2. ข้อมูลเริ่มต้นสำหรับ System Settings
-- ========================================
-- แทรกข้อมูลเริ่มต้น ถ้ายังไม่มีข้อมูล
INSERT INTO system_settings (base_fare, base_distance, price_per_km, driver_min_wallet, commission_rate)
VALUES (20, 2.0, 5, 50, 15.0)
ON CONFLICT DO NOTHING;

-- ========================================
-- 3. ตาราง Wallets (กระเป๋าเงินคนขับ)
-- ========================================
-- ใช้เก็บยอดเงินคงเหลือของคนขับแต่ละคน
CREATE TABLE IF NOT EXISTS wallets (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
    balance NUMERIC(10,2) DEFAULT 0.00,            -- ยอดเงินคงเหลือ (รองรับทศนิยม)
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- บังคับให้ user_id ไม่ซ้ำกัน
    CONSTRAINT unique_user_wallet UNIQUE (user_id)
);

-- ========================================
-- 4. ตาราง Wallet Transactions (บันทึกการเคลื่อนไหวเงิน)
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
-- 5. Indexes สำหรับประสิทธิภาพ
-- ========================================
-- สร้าง index สำหรับการค้นหาที่รวดเร็ว
CREATE INDEX IF NOT EXISTS idx_wallets_user_id ON wallets(user_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_wallet_id ON wallet_transactions(wallet_id);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_created_at ON wallet_transactions(created_at);
CREATE INDEX IF NOT EXISTS idx_wallet_transactions_type ON wallet_transactions(type);

-- ========================================
-- 6. Trigger สร้าง Wallet อัตโนมัติ (ถ้าจำเป็น)
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
-- 7. Trigger อัปเดต updated_at สำหรับ Wallets
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
-- 8. RLS (Row Level Security) - เพิ่มความปลอดภัย
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
-- 9. Comments สำหรับคำอธิบายเพิ่มเติม
-- ========================================
COMMENT ON TABLE system_settings IS 'ตารางเก็บการตั้งค่าระบบทั่วไป';
COMMENT ON COLUMN system_settings.base_fare IS 'ราคาพื้นฐานเริ่มต้น (บาท)';
COMMENT ON COLUMN system_settings.base_distance IS 'ระยะทางที่ราคาพื้นฐานครอบคลุม (กิโลเมตร)';
COMMENT ON COLUMN system_settings.price_per_km IS 'ราคาต่อกิโลเมตรเพิ่มเติม (บาท)';
COMMENT ON COLUMN system_settings.driver_min_wallet IS 'ยอดเงินขั้นต่ำที่คนขับต้องมีเพื่อรับงาน (บาท)';
COMMENT ON COLUMN system_settings.commission_rate IS 'อัตราค่าคอมมิชชั่นที่หักจากคนขับ (%)';

COMMENT ON TABLE wallets IS 'ตารางเก็บยอดเงินคงเหลือของคนขับ';
COMMENT ON COLUMN wallets.balance IS 'ยอดเงินคงเหลือปัจจุบัน (รองรับทศนิยม)';

COMMENT ON TABLE wallet_transactions IS 'ตารางบันทึกการเคลื่อนไหวเงินทั้งหมด';
COMMENT ON COLUMN wallet_transactions.amount IS 'จำนวนเงิน (บวกสำหรับเติมเงิน, ลบสำหรับหักเงิน)';
COMMENT ON COLUMN wallet_transactions.type IS 'ประเภทการทำรายการ: topup, commission, job_income, penalty';
COMMENT ON COLUMN wallet_transactions.related_booking_id IS 'รหัสการจองที่เกี่ยวข้อง (ถ้ามี)';

-- ========================================
-- 10. เสร็จสมบูรณ์
-- ========================================
-- Migration นี้สร้างโครงสร้างพื้นฐานสำหรับระบบราคาและกระเป๋าเงิน
-- พร้อมใช้งานกับระบบจองรถและการจัดการเงินของคนขับ
