\set ON_ERROR_STOP on
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='service_role') THEN CREATE ROLE service_role; END IF;
  IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon; END IF;
END $$;

CREATE SCHEMA auth;
CREATE PUBLICATION supabase_realtime;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
  SELECT NULLIF(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
CREATE FUNCTION auth.role() RETURNS text LANGUAGE sql STABLE AS $$
  SELECT current_setting('request.jwt.claim.role', true)
$$;

CREATE TABLE public.profiles (
  id uuid PRIMARY KEY, role text NOT NULL, approval_status text,
  accepted_service_types text[], vehicle_type text
);
CREATE TABLE public.driver_locations (
  driver_id uuid PRIMARY KEY, is_online boolean, is_available boolean,
  location_lat double precision, location_lng double precision,
  last_heartbeat_at timestamptz
);
CREATE TABLE public.wallets (user_id uuid PRIMARY KEY, balance numeric);
CREATE TABLE public.system_config (driver_min_wallet numeric, detection_radius_config jsonb);
CREATE TABLE public.bookings (
  id uuid PRIMARY KEY, customer_id uuid, driver_id uuid, service_type text,
  status text, origin_lat double precision, origin_lng double precision,
  vehicle_type text, scheduled_at timestamptz, assigned_at timestamptz,
  updated_at timestamptz, status_origin text, created_at timestamptz DEFAULT now()
);
CREATE TABLE public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(), user_id uuid,
  title text, body text, type text, data jsonb, created_at timestamptz DEFAULT now()
);
CREATE FUNCTION public.notify_driver_visible_job(uuid,text,text,double precision)
RETURNS TABLE(driver_id uuid, notification_id uuid) LANGUAGE sql AS $$
  SELECT '00000000-0000-0000-0000-000000000001'::uuid,
    '00000000-0000-0000-0000-000000000090'::uuid
$$;
INSERT INTO public.system_config VALUES (0, '{"driver_to_order_km":20}');

\ir ../supabase/migrations/20260926090000_driver_sequential_offers.sql
-- ทดสอบสถานะหลัง cutover (ปิดเส้นทางเดิมแล้ว)
\ir ../supabase/migrations/20260926090200_driver_offer_legacy_cutover.sql

INSERT INTO public.profiles VALUES
  ('00000000-0000-0000-0000-000000000001','driver','approved',ARRAY['parcel'],NULL),
  ('00000000-0000-0000-0000-000000000002','driver','approved',ARRAY['parcel'],NULL);
INSERT INTO public.driver_locations VALUES
  ('00000000-0000-0000-0000-000000000001',true,true,13.0000,100.0000,now()),
  ('00000000-0000-0000-0000-000000000002',true,true,13.0100,100.0000,now());
INSERT INTO public.wallets VALUES
  ('00000000-0000-0000-0000-000000000001',100),
  ('00000000-0000-0000-0000-000000000002',100);
INSERT INTO public.bookings(id,customer_id,service_type,status,origin_lat,origin_lng)
VALUES ('00000000-0000-0000-0000-000000000010','00000000-0000-0000-0000-000000000099','parcel','pending',13.0001,100.0000);

DO $$
DECLARE v_offer public.driver_job_offers%ROWTYPE;
BEGIN
  SELECT * INTO STRICT v_offer FROM public.driver_job_offers WHERE booking_id='00000000-0000-0000-0000-000000000010';
  IF v_offer.driver_id <> '00000000-0000-0000-0000-000000000001' OR v_offer.status <> 'offered' THEN
    RAISE EXCEPTION 'nearest driver was not offered first';
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.notify_driver_visible_job(
      '00000000-0000-0000-0000-000000000010')) THEN
    RAISE EXCEPTION 'legacy notification still broadcast an unassigned booking';
  END IF;
END $$;

SET request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
SELECT public.skip_driver_job_offer(id) FROM public.driver_job_offers
WHERE booking_id='00000000-0000-0000-0000-000000000010' AND status='offered';
DO $$
DECLARE v_driver uuid;
BEGIN
  SELECT driver_id INTO STRICT v_driver FROM public.driver_job_offers
  WHERE booking_id='00000000-0000-0000-0000-000000000010' AND status='offered';
  IF v_driver <> '00000000-0000-0000-0000-000000000002' THEN
    RAISE EXCEPTION 'skip did not immediately offer the next driver';
  END IF;
END $$;

SET request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
DO $$
DECLARE v_offer uuid; v_result jsonb;
BEGIN
  SELECT id INTO v_offer FROM public.driver_job_offers WHERE status='offered';
  v_result := public.accept_driver_job_offer(v_offer);
  IF v_result->>'success' <> 'false' THEN
    RAISE EXCEPTION 'wrong driver accepted an offer';
  END IF;
END $$;
SET request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
DO $$
DECLARE v_offer uuid; v_result jsonb; v_driver uuid;
BEGIN
  SELECT id INTO v_offer FROM public.driver_job_offers WHERE status='offered';
  v_result := public.accept_driver_job_offer(v_offer);
  SELECT driver_id INTO v_driver FROM public.bookings WHERE id='00000000-0000-0000-0000-000000000010';
  IF v_result->>'success' <> 'true' OR v_driver <> auth.uid() THEN
    RAISE EXCEPTION 'offered driver could not claim booking';
  END IF;
  v_result := public.accept_driver_job_offer(v_offer);
  IF v_result->>'success' <> 'false' THEN
    RAISE EXCEPTION 'accepted offer was reused';
  END IF;
END $$;

-- The accepted driver is busy; the next booking goes only to driver 1.
INSERT INTO public.bookings(id,customer_id,service_type,status,origin_lat,origin_lng)
VALUES ('00000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000099','parcel','pending',13.0100,100.0000);
DO $$
DECLARE v_driver uuid;
BEGIN
  SELECT driver_id INTO STRICT v_driver FROM public.driver_job_offers
   WHERE booking_id='00000000-0000-0000-0000-000000000011' AND status='offered';
  IF v_driver <> '00000000-0000-0000-0000-000000000001' THEN
    RAISE EXCEPTION 'busy driver received a second booking';
  END IF;
END $$;

SET request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
DO $$
DECLARE v_result jsonb;
BEGIN
  v_result := public.accept_booking('00000000-0000-0000-0000-000000000011',
    '00000000-0000-0000-0000-000000000001', 'pending');
  IF v_result->>'error' <> 'driver_mismatch' THEN
    RAISE EXCEPTION 'legacy RPC accepted another driver ID';
  END IF;
END $$;

UPDATE public.driver_job_offers
  SET offered_at=now()-interval '2 minutes', expires_at=now()-interval '1 minute'
  WHERE booking_id='00000000-0000-0000-0000-000000000011' AND status='offered';
SELECT public.process_driver_offer_queue(100);
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.driver_job_offers
      WHERE booking_id='00000000-0000-0000-0000-000000000011' AND status='offered') THEN
    RAISE EXCEPTION 'expired offer remained active';
  END IF;
END $$;

SET request.jwt.claim.role = 'service_role';
DO $$
DECLARE v_result jsonb; v_driver uuid;
BEGIN
  v_result := public.admin_assign_driver_job(
    '00000000-0000-0000-0000-000000000011',
    '00000000-0000-0000-0000-000000000001');
  SELECT driver_id INTO v_driver FROM public.bookings
    WHERE id='00000000-0000-0000-0000-000000000011';
  IF v_result->>'success' <> 'true' OR v_driver <> '00000000-0000-0000-0000-000000000001' THEN
    RAISE EXCEPTION 'admin conditional assignment failed';
  END IF;
END $$;

-- A ride with a required vehicle type must skip a closer driver with no type.
INSERT INTO public.profiles VALUES
  ('00000000-0000-0000-0000-000000000003','driver','approved',ARRAY['ride'],NULL),
  ('00000000-0000-0000-0000-000000000004','driver','approved',ARRAY['ride'],'motorcycle');
INSERT INTO public.driver_locations VALUES
  ('00000000-0000-0000-0000-000000000003',true,true,13.0000,100.0000,now()),
  ('00000000-0000-0000-0000-000000000004',true,true,13.0100,100.0000,now());
INSERT INTO public.wallets VALUES
  ('00000000-0000-0000-0000-000000000003',100),
  ('00000000-0000-0000-0000-000000000004',100);
INSERT INTO public.bookings(id,customer_id,service_type,status,origin_lat,origin_lng,vehicle_type)
VALUES ('00000000-0000-0000-0000-000000000012','00000000-0000-0000-0000-000000000099',
  'ride','pending',13.0001,100.0000,'motorcycle');
DO $$ BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.driver_job_offers
      WHERE booking_id='00000000-0000-0000-0000-000000000012'
        AND driver_id='00000000-0000-0000-0000-000000000004' AND status='offered') THEN
    RAISE EXCEPTION 'ride offered to driver without matching vehicle type';
  END IF;
END $$;

-- หลัง cutover: accept_booking ไม่มี offer ต้องถูกปฏิเสธ และเขียน driver_id ตรงไม่ได้
INSERT INTO public.bookings(id,customer_id,service_type,status,origin_lat,origin_lng)
VALUES ('00000000-0000-0000-0000-000000000020','00000000-0000-0000-0000-000000000099','parcel','pending',60.0,10.0);
SET request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
DO $$
DECLARE v_result jsonb;
BEGIN
  v_result := public.accept_booking('00000000-0000-0000-0000-000000000020',
    '00000000-0000-0000-0000-000000000002', 'pending');
  IF v_result->>'error' <> 'not_offered' THEN
    RAISE EXCEPTION 'cutover: accept_booking without offer returned %', v_result;
  END IF;
END $$;
GRANT SELECT, UPDATE ON public.bookings TO authenticated;
SET ROLE authenticated;
DO $$
BEGIN
  BEGIN
    UPDATE public.bookings SET driver_id = '00000000-0000-0000-0000-000000000002'
     WHERE id = '00000000-0000-0000-0000-000000000020';
    RAISE EXCEPTION 'cutover: direct driver claim was allowed';
  EXCEPTION WHEN raise_exception THEN
    IF SQLERRM <> 'use_accept_driver_job_offer' THEN RAISE; END IF;
  END;
END $$;
RESET ROLE;
\echo 'driver offer cutover fixture passed'
