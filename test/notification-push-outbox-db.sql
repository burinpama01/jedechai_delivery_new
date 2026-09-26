\set ON_ERROR_STOP on
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon; END IF;
END $$;
CREATE TABLE public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid, title text, body text,
  type text, data jsonb, is_read boolean DEFAULT false, created_at timestamptz DEFAULT now());
-- ตรงกับ 20260506133000_notification_deliveries.sql ในส่วนที่ใช้
CREATE TABLE public.notification_deliveries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), notification_id uuid,
  user_id uuid NOT NULL, channel text NOT NULL, status text NOT NULL);

\ir ../supabase/migrations/20260926090400_notification_push_outbox.sql

INSERT INTO public.notifications(id,user_id,title,type,created_at) VALUES
 ('00000000-0000-0000-0000-000000000001', gen_random_uuid(), 'db only',     'referral_reward', now()-interval '1 minute'),
 ('00000000-0000-0000-0000-000000000002', gen_random_uuid(), 'already sent','booking_status_update', now()-interval '1 minute'),
 ('00000000-0000-0000-0000-000000000003', gen_random_uuid(), 'too new',     'order.cancelled', now()),
 ('00000000-0000-0000-0000-000000000004', gen_random_uuid(), 'too old',     'order.cancelled', now()-interval '1 hour'),
 ('00000000-0000-0000-0000-000000000005', gen_random_uuid(), 'offer',       'driver.job.offer', now()-interval '1 minute');
INSERT INTO public.notification_deliveries(notification_id,user_id,channel,status)
  VALUES ('00000000-0000-0000-0000-000000000002',gen_random_uuid(),'fcm','sent');

DO $$
DECLARE v_ids uuid[];
BEGIN
  SELECT array_agg(notification_id) INTO v_ids FROM public.claim_pending_notification_pushes(50);
  IF v_ids IS DISTINCT FROM ARRAY['00000000-0000-0000-0000-000000000001'::uuid] THEN
    RAISE EXCEPTION 'outbox claimed wrong rows: %', v_ids;
  END IF;
  IF EXISTS (SELECT 1 FROM public.claim_pending_notification_pushes(50)) THEN
    RAISE EXCEPTION 'outbox claimed a row twice';
  END IF;
  IF has_function_privilege('authenticated','public.claim_pending_notification_pushes(integer)','EXECUTE') THEN
    RAISE EXCEPTION 'authenticated can claim pushes';
  END IF;
END $$;
\echo 'notification push outbox fixture passed'
