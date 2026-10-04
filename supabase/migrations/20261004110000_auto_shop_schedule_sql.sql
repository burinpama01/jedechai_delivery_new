-- ตารางเปิด/ปิดร้านอัตโนมัติ: ย้ายจาก edge function มาเป็น SQL ล้วน (ISSUE-20261004-002)
--
-- ของเดิม (20260516100000) ให้ cron ยิง net.http_post ด้วย current_setting('app.supabase_url')
-- และ 'app.auto_shop_schedule_secret' ซึ่งไม่เคยตั้งใน DB -> ล้มทุก 5 นาทีตั้งแต่สร้าง
-- (edge secret AUTO_SHOP_SCHEDULE_SECRET ก็ไม่เคยตั้ง) shop_status ใน DB จึงไม่เคยตามตารางเวลา
-- ขณะที่แอปลูกค้า (lib/common/utils/shop_schedule.dart) คำนวณเปิด/ปิดจากตารางเองอยู่แล้ว
--
-- ทำไมเป็น SQL: ไม่ต้องใช้ HTTP/secret, ลด Disk IO (ไม่มี pg_net request/response) และแก้บั๊ก
-- edge function เดิมที่ไม่กรอง role — shop_auto_schedule_enabled มีค่าเริ่มต้น true ทุกบัญชี
-- ถ้าซ่อมแค่ config จะไปตั้ง is_online ของคนขับเป็น false นอกเวลา 08:00–22:00
--
-- logic เดียวกับ isShopOpenNow (Dart/edge):
--   * เวลาเปิด/ปิดว่างหรือรูปแบบผิด -> คงสถานะเดิม
--   * ช่วงข้ามเที่ยงคืน (open > close) รองรับ
--   * shop_open_days ว่าง = ทุกวัน, ไม่ว่าง = เฉพาะวันที่ระบุ (mon..sun, เวลาไทย)
-- อัปเดตเฉพาะร้านที่สถานะต้องเปลี่ยน, is_online ตาม shop_status (trigger sync ก็ทำซ้ำให้),
-- shop_status_source = 'schedule' (ผ่าน set_config ให้ trigger track_shop_status_source ใส่)

BEGIN;

CREATE OR REPLACE FUNCTION public.run_auto_shop_schedule()
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_now timestamp := now() AT TIME ZONE 'Asia/Bangkok';
  v_min integer := extract(hour FROM v_now)::integer * 60 + extract(minute FROM v_now)::integer;
  v_day text := (ARRAY['mon','tue','wed','thu','fri','sat','sun'])[extract(isodow FROM v_now)::integer];
  v_changed integer;
BEGIN
  -- ให้ trigger track_shop_status_source ใส่ 'schedule' ทุกครั้ง (ถ้าตั้งใน SET ตรง ๆ
  -- รอบที่ OLD เป็น 'schedule' อยู่แล้วจะถูกมองว่าไม่ได้ระบุ แล้วกลายเป็น 'system')
  PERFORM set_config('app.shop_status_source', 'schedule', true);
  WITH parsed AS (
    SELECT p.id, COALESCE(p.shop_status, false) AS cur, p.shop_open_days AS days,
           CASE WHEN btrim(p.shop_open_time) ~ '^\d{1,2}:\d{2}'
                 AND btrim(p.shop_close_time) ~ '^\d{1,2}:\d{2}'
                THEN split_part(btrim(p.shop_open_time), ':', 1)::integer * 60
                   + split_part(btrim(p.shop_open_time), ':', 2)::integer END AS o,
           CASE WHEN btrim(p.shop_open_time) ~ '^\d{1,2}:\d{2}'
                 AND btrim(p.shop_close_time) ~ '^\d{1,2}:\d{2}'
                THEN split_part(btrim(p.shop_close_time), ':', 1)::integer * 60
                   + split_part(btrim(p.shop_close_time), ':', 2)::integer END AS c
      FROM public.profiles p
     WHERE p.role = 'merchant'
       AND p.shop_auto_schedule_enabled IS TRUE
  ), decided AS (
    SELECT id, cur,
           CASE
             WHEN o IS NULL OR c IS NULL THEN cur
             -- เหมือน Dart: นับเฉพาะชื่อวันที่ถูกต้อง ถ้าไม่มีเลย = ทุกวัน
             WHEN EXISTS (SELECT 1 FROM unnest(days) d
                           WHERE lower(btrim(d)) = ANY (ARRAY['mon','tue','wed','thu','fri','sat','sun']))
                  AND NOT EXISTS (SELECT 1 FROM unnest(days) d WHERE lower(btrim(d)) = v_day)
               THEN false
             WHEN o <= c THEN v_min >= o AND v_min < c
             ELSE v_min >= o OR v_min < c
           END AS should_open
      FROM parsed
  )
  UPDATE public.profiles p
     SET shop_status = d.should_open,
         is_online = d.should_open
    FROM decided d
   WHERE p.id = d.id
     AND d.should_open IS DISTINCT FROM d.cur;
  GET DIAGNOSTICS v_changed = ROW_COUNT;
  RETURN v_changed;
END;
$$;

REVOKE ALL ON FUNCTION public.run_auto_shop_schedule() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.run_auto_shop_schedule() TO service_role;

-- ชื่อเดิม -> pg_cron แทนที่ command เดิม (เลิกยิง edge function)
SELECT cron.schedule('auto-shop-schedule', '*/5 * * * *',
  'SELECT public.run_auto_shop_schedule();');

COMMIT;
