-- ส่ง push ให้แจ้งเตือนที่ฐานข้อมูลสร้างเอง
--
-- ปัญหา: มีกว่า 50 จุดใน SQL (trigger/RPC) ที่ INSERT INTO notifications ตรง ๆ
-- เช่น รางวัลแนะนำเพื่อน, ยกเลิกออเดอร์, อนุมัติร้าน, ร้านถูกแอดมินเปลี่ยนสถานะ
-- แถวพวกนี้เห็นแค่ในกล่องแจ้งเตือนในแอป แต่ไม่เคยถูกส่งเป็น push เพราะ push
-- ส่งเฉพาะตอนที่ client/edge function เรียก send-fcm-notification เอง
--
-- วิธีแก้: outbox — worker process-driver-offers (cron ทุก 10 วินาที) ดึงแถวที่
--   * สร้างมาแล้วอย่างน้อย 15 วินาที (ให้เวลาทางเดิมที่ส่ง push เองทำงานเสร็จก่อน)
--   * ไม่เกิน 15 นาที (ไม่ส่งแจ้งเตือนเก่าย้อนหลังตอนเปิดระบบครั้งแรก)
--   * ยังไม่มีแถวใน notification_deliveries (= ยังไม่มีใครพยายามส่ง)
--   * ไม่ใช่ driver.job.offer (worker ส่งเองอยู่แล้ว และหมดอายุใน 60 วินาที)
-- แล้วส่งผ่าน send-fcm-notification พร้อม notification_id (ไม่สร้างแถวซ้ำ)
--
-- ข้อจำกัดที่ยอมรับ:
--   * claim ก่อนส่ง: ถ้า worker ล้มกลางทางหลัง claim แถวนั้นจะไม่ถูกส่งซ้ำ
--     (ยังเห็นในกล่องแจ้งเตือนในแอป) — เลือกไม่ retry เพื่อกันส่งซ้ำ
--   * ถ้า client insert แถวเองแล้วรอ >15 วินาทีก่อนเรียก send-fcm พร้อม notification_id
--     อาจได้ 2 push; ทางเดิมทุกจุดเรียก send-fcm ทันทีหลัง insert จึงไม่พบกรณีนี้
BEGIN;

ALTER TABLE public.notifications
  ADD COLUMN IF NOT EXISTS push_claimed_at timestamptz;

CREATE INDEX IF NOT EXISTS notifications_push_outbox_idx
  ON public.notifications (created_at)
  WHERE push_claimed_at IS NULL;

CREATE OR REPLACE FUNCTION public.claim_pending_notification_pushes(p_limit integer DEFAULT 50)
RETURNS TABLE(notification_id uuid, user_id uuid, title text, body text, type text, data jsonb)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN QUERY
  WITH claimed AS (
    SELECT n.id FROM public.notifications n
     WHERE n.push_claimed_at IS NULL
       AND n.created_at <= now() - interval '15 seconds'
       AND n.created_at >  now() - interval '15 minutes'
       AND COALESCE(n.type, '') <> 'driver.job.offer'
       AND NOT EXISTS (SELECT 1 FROM public.notification_deliveries d
                        WHERE d.notification_id = n.id)
     ORDER BY n.created_at
     LIMIT LEAST(GREATEST(p_limit, 1), 100)
     FOR UPDATE SKIP LOCKED
  ), updated AS (
    UPDATE public.notifications n SET push_claimed_at = now()
      FROM claimed c WHERE n.id = c.id
    RETURNING n.id, n.user_id, n.title, n.body, n.type, n.data
  )
  SELECT u.id, u.user_id, u.title, u.body, u.type, u.data FROM updated u;
END;
$$;
REVOKE ALL ON FUNCTION public.claim_pending_notification_pushes(integer)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_pending_notification_pushes(integer) TO service_role;

COMMIT;
