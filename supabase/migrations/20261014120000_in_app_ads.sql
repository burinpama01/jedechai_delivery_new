-- In-app ads (โฆษณาในแอพ) — ขยายตาราง banners ให้รองรับ ลูกค้า/คนขับ/ร้านค้า
-- รูปแบบ สไลด์/ป๊อปอัป/การ์ด, กดแล้วทำอะไร, ช่วงเวลาแสดง
-- + ปิดช่องโหว่: policy "Service role full access" เปิดให้ public เขียนได้ทุกแถว
-- แผน: Plan/In_App_Ads_Plan_v1.html

BEGIN;

-- 1) คอลัมน์ใหม่
ALTER TABLE public.banners ADD COLUMN IF NOT EXISTS action_type text;
ALTER TABLE public.banners ADD COLUMN IF NOT EXISTS action_value text;
ALTER TABLE public.banners ADD COLUMN IF NOT EXISTS starts_at timestamptz;
ALTER TABLE public.banners ADD COLUMN IF NOT EXISTS ends_at timestamptz;
ALTER TABLE public.banners ADD COLUMN IF NOT EXISTS popup_frequency text NOT NULL DEFAULT 'daily';

-- แถวเดิม: มีคูปอง = coupon, ไม่มี = none
UPDATE public.banners
SET action_type = CASE WHEN coupon_code IS NOT NULL AND coupon_code <> '' THEN 'coupon' ELSE 'none' END
WHERE action_type IS NULL;

ALTER TABLE public.banners ALTER COLUMN action_type SET DEFAULT 'none';
ALTER TABLE public.banners ALTER COLUMN action_type SET NOT NULL;

-- 2) CHECK constraints
ALTER TABLE public.banners DROP CONSTRAINT IF EXISTS banners_action_type_check;
ALTER TABLE public.banners ADD CONSTRAINT banners_action_type_check
  CHECK (action_type IN ('none', 'coupon', 'url', 'screen'));

ALTER TABLE public.banners DROP CONSTRAINT IF EXISTS banners_popup_frequency_check;
ALTER TABLE public.banners ADD CONSTRAINT banners_popup_frequency_check
  CHECK (popup_frequency IN ('once', 'daily', 'every_open'));

ALTER TABLE public.banners DROP CONSTRAINT IF EXISTS banners_schedule_check;
ALTER TABLE public.banners ADD CONSTRAINT banners_schedule_check
  CHECK (starts_at IS NULL OR ends_at IS NULL OR ends_at > starts_at);

ALTER TABLE public.banners DROP CONSTRAINT IF EXISTS banners_url_https_check;
ALTER TABLE public.banners ADD CONSTRAINT banners_url_https_check
  CHECK (action_type <> 'url' OR action_value ~* '^https://');

-- 3) RLS — ปิดช่องเขียนสาธารณะ, ตัดช่วงเวลาที่ server
DROP POLICY IF EXISTS "Service role full access" ON public.banners;
DROP POLICY IF EXISTS "Read active banners" ON public.banners;
DROP POLICY IF EXISTS "Anyone can read active banners" ON public.banners;

CREATE POLICY "Anyone can read live banners" ON public.banners
  FOR SELECT USING (
    is_active = true
    AND (starts_at IS NULL OR starts_at <= now())
    AND (ends_at IS NULL OR ends_at > now())
  );

-- "Admin full access" (role = 'admin') คงไว้ให้ admin-web อ่านแถวที่ปิด/หมดเวลา

-- เขียนผ่าน edge fn admin-actions (service_role) เท่านั้น
REVOKE INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER ON public.banners FROM anon, authenticated;
GRANT SELECT ON public.banners TO anon, authenticated;

CREATE INDEX IF NOT EXISTS idx_banners_page_active_sort
  ON public.banners(page, sort_order) WHERE is_active = true;

COMMIT;
