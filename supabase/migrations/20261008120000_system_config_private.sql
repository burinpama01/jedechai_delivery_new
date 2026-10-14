-- ISSUE-20261004-003: system_config อ่านได้โดย anon/authenticated ทั้งตาราง
-- (policy "Anyone can read system_config" / config_select_all = true) ทำให้ค่าติดต่อแอดมินและบัญชีรับเงินรั่ว
--
-- ทำไมไม่ใช้ column-level REVOKE: แอปมือถือที่ติดตั้งอยู่แล้ว select('*') จาก system_config
-- (system_config_service.dart) — ถ้าตัดสิทธิ์คอลัมน์ select('*') จะ permission denied ทั้งแถว
--
-- วิธีนี้: ย้ายค่าลับไป public.system_config_private (แถวเดียว id=1, อ่าน/เขียนได้เฉพาะแอดมิน + service_role)
-- แล้วล้างค่าในคอลัมน์เดิม (คอลัมน์ยังอยู่ select('*') ไม่พัง)
-- trigger บน system_config ย้ายค่าที่ถูกเขียนเข้าคอลัมน์ลับไปตาราง private เสมอ
-- (admin-actions upsert_system_config ยังเขียนเข้า system_config ได้ตามเดิม)
-- ค่าว่าง '' = ล้างค่า (PostgREST upsert แยก "ไม่ได้ส่ง" กับ "ส่ง null" ไม่ได้)

BEGIN;

CREATE TABLE IF NOT EXISTS public.system_config_private (
  id integer PRIMARY KEY DEFAULT 1 CHECK (id = 1),
  admin_notification_email text,
  admin_notification_email_cc text,
  admin_line_recipient_id text,
  admin_telegram_chat_id text,
  slip2go_receiver_account text,
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.system_config_private IS
  'ค่าลับของ system_config (แอดมิน/service_role เท่านั้น) — เขียนผ่าน system_config ได้ trigger ย้ายมาให้; ห้ามเปิด SELECT ให้ anon';

ALTER TABLE public.system_config_private ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.system_config_private FROM PUBLIC, anon, authenticated;
-- เขียนผ่าน trigger (SECURITY DEFINER) บน system_config เท่านั้น — authenticated ได้แค่ SELECT (RLS: แอดมิน)
GRANT SELECT ON public.system_config_private TO authenticated;
GRANT ALL ON public.system_config_private TO service_role;

DROP POLICY IF EXISTS system_config_private_admin ON public.system_config_private;
CREATE POLICY system_config_private_admin ON public.system_config_private
  FOR ALL TO authenticated
  USING (public.is_admin())
  WITH CHECK (public.is_admin());

-- ย้ายค่าปัจจุบัน
INSERT INTO public.system_config_private (
  id, admin_notification_email, admin_notification_email_cc,
  admin_line_recipient_id, admin_telegram_chat_id, slip2go_receiver_account
)
SELECT 1,
  NULLIF(btrim(admin_notification_email), ''),
  NULLIF(btrim(admin_notification_email_cc), ''),
  NULLIF(btrim(admin_line_recipient_id), ''),
  NULLIF(btrim(admin_telegram_chat_id), ''),
  NULLIF(btrim(slip2go_receiver_account), '')
FROM public.system_config
WHERE id = 1
ON CONFLICT (id) DO NOTHING;

-- กันกรณีไม่มีแถว id=1 ใน system_config — ให้มีแถว private เสมอ
INSERT INTO public.system_config_private (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

-- trigger: ค่าลับที่เขียนเข้า system_config → ย้ายไป private แล้วล้างทิ้ง
CREATE OR REPLACE FUNCTION public.system_config_route_private_columns()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF NEW.admin_notification_email IS NOT NULL
     OR NEW.admin_notification_email_cc IS NOT NULL
     OR NEW.admin_line_recipient_id IS NOT NULL
     OR NEW.admin_telegram_chat_id IS NOT NULL
     OR NEW.slip2go_receiver_account IS NOT NULL THEN

    -- เก็บได้เฉพาะแถวหลัก id=1 (แถว key/value ไม่ควรมีค่าเหล่านี้ — ทิ้งเฉย ๆ)
    IF NEW.id = 1 THEN
      INSERT INTO public.system_config_private (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

      UPDATE public.system_config_private p SET
        admin_notification_email = CASE WHEN NEW.admin_notification_email IS NULL
          THEN p.admin_notification_email ELSE NULLIF(btrim(NEW.admin_notification_email), '') END,
        admin_notification_email_cc = CASE WHEN NEW.admin_notification_email_cc IS NULL
          THEN p.admin_notification_email_cc ELSE NULLIF(btrim(NEW.admin_notification_email_cc), '') END,
        admin_line_recipient_id = CASE WHEN NEW.admin_line_recipient_id IS NULL
          THEN p.admin_line_recipient_id ELSE NULLIF(btrim(NEW.admin_line_recipient_id), '') END,
        admin_telegram_chat_id = CASE WHEN NEW.admin_telegram_chat_id IS NULL
          THEN p.admin_telegram_chat_id ELSE NULLIF(btrim(NEW.admin_telegram_chat_id), '') END,
        slip2go_receiver_account = CASE WHEN NEW.slip2go_receiver_account IS NULL
          THEN p.slip2go_receiver_account ELSE NULLIF(btrim(NEW.slip2go_receiver_account), '') END,
        updated_at = now()
      WHERE p.id = 1;
    END IF;

    NEW.admin_notification_email := NULL;
    NEW.admin_notification_email_cc := NULL;
    NEW.admin_line_recipient_id := NULL;
    NEW.admin_telegram_chat_id := NULL;
    NEW.slip2go_receiver_account := NULL;
  END IF;

  -- resend_api_key ไม่ได้ใช้แล้ว (ใช้ edge secret RESEND_API_KEY) — ห้ามเก็บในตารางที่อ่านได้สาธารณะ
  NEW.resend_api_key := NULL;
  RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.system_config_route_private_columns() FROM PUBLIC, anon, authenticated;

DROP TRIGGER IF EXISTS system_config_route_private_columns ON public.system_config;
CREATE TRIGGER system_config_route_private_columns
  BEFORE INSERT OR UPDATE ON public.system_config
  FOR EACH ROW EXECUTE FUNCTION public.system_config_route_private_columns();

-- ล้างค่าลับในตารางสาธารณะ (trigger ข้างบนจะไม่แตะค่า private เพราะ NEW เป็น null หมด)
UPDATE public.system_config SET
  admin_notification_email = NULL,
  admin_notification_email_cc = NULL,
  admin_line_recipient_id = NULL,
  admin_telegram_chat_id = NULL,
  slip2go_receiver_account = NULL,
  resend_api_key = NULL
WHERE admin_notification_email IS NOT NULL
   OR admin_notification_email_cc IS NOT NULL
   OR admin_line_recipient_id IS NOT NULL
   OR admin_telegram_chat_id IS NOT NULL
   OR slip2go_receiver_account IS NOT NULL
   OR resend_api_key IS NOT NULL;

COMMIT;
