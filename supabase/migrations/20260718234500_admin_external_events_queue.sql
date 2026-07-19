-- Admin external notification queue (Telegram/LINE) — claim-pattern ต่อยอดจาก
-- notify_admins() (migration 20260718230000).
--
-- Flow: notify_admins() ลงแถว outbox 1 แถวต่อ event (นอกเหนือจาก in-app ต่อ
-- แอดมิน) → pg_cron ทุกนาทีเรียก edge function `notify-admin-events` ด้วย
-- x-cron-secret → function claim แบบ atomic (FOR UPDATE SKIP LOCKED ผ่าน RPC)
-- แล้วส่งเข้า Telegram/LINE ตาม system_config (admin_telegram_enabled /
-- admin_line_enabled) — token อยู่ใน Supabase secrets ฝั่ง function เท่านั้น
--
-- หมายเหตุ deploy: __ADMIN_EVENTS_CRON_SECRET__ เป็น placeholder — สคริปต์
-- deploy แทนค่าจริงตอน apply (ค่าเดียวกับ secret ADMIN_EVENTS_CRON_SECRET
-- ของ edge function) ห้าม commit ค่าจริงลง git

CREATE TABLE IF NOT EXISTS public.admin_event_external_queue (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  title text NOT NULL,
  body text NOT NULL,
  event_type text NOT NULL,
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  claimed_at timestamptz,
  sent_at timestamptz,
  attempts integer NOT NULL DEFAULT 0,
  last_error text
);

-- ไม่มี policy = client เข้าไม่ได้เลย (service role bypass RLS)
ALTER TABLE public.admin_event_external_queue ENABLE ROW LEVEL SECURITY;

CREATE INDEX IF NOT EXISTS idx_admin_event_queue_unsent
ON public.admin_event_external_queue (created_at)
WHERE sent_at IS NULL;

-- ─── notify_admins: เพิ่มการลงแถว outbox (แทนที่ตัวเดิมทั้งฟังก์ชัน) ─────────
CREATE OR REPLACE FUNCTION public.notify_admins(
  p_title text,
  p_body text,
  p_type text,
  p_data jsonb DEFAULT '{}'::jsonb
)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_count integer := 0;
BEGIN
  INSERT INTO public.notifications (user_id, title, body, type, data)
  SELECT p.id, p_title, p_body, p_type, COALESCE(p_data, '{}'::jsonb)
  FROM public.profiles p
  WHERE p.role = 'admin';
  GET DIAGNOSTICS v_count = ROW_COUNT;

  -- แถวเดียวต่อ event สำหรับช่องทางภายนอก (Telegram/LINE)
  INSERT INTO public.admin_event_external_queue (title, body, event_type, data)
  VALUES (p_title, p_body, p_type, COALESCE(p_data, '{}'::jsonb));

  RETURN v_count;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.notify_admins(text, text, text, jsonb) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.notify_admins(text, text, text, jsonb) FROM anon;
REVOKE EXECUTE ON FUNCTION public.notify_admins(text, text, text, jsonb) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.notify_admins(text, text, text, jsonb) TO service_role;

-- ─── claim / mark RPCs (service_role เท่านั้น) ──────────────────────────────
CREATE OR REPLACE FUNCTION public.claim_admin_external_events(p_limit integer DEFAULT 20)
RETURNS SETOF public.admin_event_external_queue
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN QUERY
  UPDATE public.admin_event_external_queue q
  SET claimed_at = now(),
      attempts = q.attempts + 1
  WHERE q.id IN (
    SELECT c.id
    FROM public.admin_event_external_queue c
    WHERE c.sent_at IS NULL
      AND c.attempts < 5
      AND (c.claimed_at IS NULL OR c.claimed_at < now() - interval '5 minutes')
    ORDER BY c.created_at
    LIMIT GREATEST(1, LEAST(COALESCE(p_limit, 20), 50))
    FOR UPDATE SKIP LOCKED
  )
  RETURNING q.*;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.claim_admin_external_events(integer) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.claim_admin_external_events(integer) FROM anon;
REVOKE EXECUTE ON FUNCTION public.claim_admin_external_events(integer) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.claim_admin_external_events(integer) TO service_role;

CREATE OR REPLACE FUNCTION public.mark_admin_external_event(
  p_id uuid,
  p_error text DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF p_error IS NULL THEN
    UPDATE public.admin_event_external_queue
    SET sent_at = now(), last_error = NULL
    WHERE id = p_id;
  ELSE
    UPDATE public.admin_event_external_queue
    SET last_error = LEFT(p_error, 500)
    WHERE id = p_id;
  END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.mark_admin_external_event(uuid, text) FROM PUBLIC;
REVOKE EXECUTE ON FUNCTION public.mark_admin_external_event(uuid, text) FROM anon;
REVOKE EXECUTE ON FUNCTION public.mark_admin_external_event(uuid, text) FROM authenticated;
GRANT EXECUTE ON FUNCTION public.mark_admin_external_event(uuid, text) TO service_role;

-- ─── cron: เรียก edge function ทุกนาที ──────────────────────────────────────
-- URL เป็นค่า public; secret ถูกแทนที่ตอน deploy (อยู่เฉพาะใน cron.job บน prod)
DO $$
DECLARE
  v_job_id int;
BEGIN
  FOR v_job_id IN SELECT jobid FROM cron.job WHERE jobname = 'admin-external-events-drain' LOOP
    PERFORM cron.unschedule(v_job_id);
  END LOOP;
  -- Authorization = anon key (ค่า public) กันกรณี function ถูก redeploy โดยลืม
  -- --no-verify-jwt แล้ว gateway บังคับ JWT — ประตูจริงคือ x-cron-secret เสมอ
  PERFORM cron.schedule(
    'admin-external-events-drain',
    '* * * * *',
    $cron$SELECT net.http_post(
      url := 'https://tfwhfkfgekkkgamhvttk.supabase.co/functions/v1/notify-admin-events',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer __SUPABASE_ANON_KEY__',
        'apikey', '__SUPABASE_ANON_KEY__',
        'x-cron-secret', '__ADMIN_EVENTS_CRON_SECRET__'
      ),
      body := '{}'::jsonb
    );$cron$
  );
EXCEPTION WHEN OTHERS THEN
  RAISE NOTICE 'cron schedule skipped: %', SQLERRM;
END
$$;
