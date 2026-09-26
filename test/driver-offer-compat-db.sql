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

-- ช่วงเปลี่ยนผ่าน: apply เฉพาะ compat migration (ยังไม่ cutover)
\ir ../supabase/migrations/20260926090000_driver_sequential_offers.sql

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

-- คิวยังเสนองานให้คนขับใกล้สุด
DO $$
DECLARE v_driver uuid;
BEGIN
  SELECT driver_id INTO STRICT v_driver FROM public.driver_job_offers
   WHERE booking_id='00000000-0000-0000-0000-000000000010' AND status='offered';
  IF v_driver <> '00000000-0000-0000-0000-000000000001' THEN
    RAISE EXCEPTION 'compat: nearest driver was not offered first';
  END IF;
END $$;

-- broadcast เดิมยังทำงาน (แอปลูกค้าเก่ายังเรียกเพื่อแจ้งคนขับแอปเก่า)
DO $$
BEGIN
  IF NOT EXISTS (SELECT 1 FROM public.notify_driver_visible_job(
      '00000000-0000-0000-0000-000000000010', NULL, NULL, 5.0)) THEN
    RAISE EXCEPTION 'compat: legacy broadcast was disabled';
  END IF;
END $$;

-- ห้ามรับงานแทนคนอื่น แม้ในโหมด compat
SET request.jwt.claim.sub = '00000000-0000-0000-0000-000000000002';
DO $$
DECLARE v_result jsonb;
BEGIN
  v_result := public.accept_booking('00000000-0000-0000-0000-000000000010',
    '00000000-0000-0000-0000-000000000001', 'pending');
  IF v_result->>'error' <> 'driver_mismatch' THEN
    RAISE EXCEPTION 'compat: accepted another driver ID';
  END IF;
END $$;

-- คนขับแอปเก่า (ไม่มี offer) กดรับจากรายการได้แบบเดิม และ offer ของคนอื่นถูกยกเลิก
DO $$
DECLARE v_result jsonb; v_booking public.bookings%ROWTYPE; v_offer_status text;
BEGIN
  v_result := public.accept_booking('00000000-0000-0000-0000-000000000010',
    '00000000-0000-0000-0000-000000000002', 'pending');
  SELECT * INTO v_booking FROM public.bookings WHERE id='00000000-0000-0000-0000-000000000010';
  SELECT status INTO v_offer_status FROM public.driver_job_offers
   WHERE booking_id='00000000-0000-0000-0000-000000000010'
     AND driver_id='00000000-0000-0000-0000-000000000001';
  IF v_result->>'success' <> 'true' OR v_booking.driver_id <> auth.uid()
     OR v_booking.status <> 'driver_accepted' THEN
    RAISE EXCEPTION 'compat: legacy accept failed: %', v_result;
  END IF;
  IF v_offer_status <> 'cancelled' THEN
    RAISE EXCEPTION 'compat: stale offer not cancelled (%)', v_offer_status;
  END IF;
  v_result := public.accept_booking('00000000-0000-0000-0000-000000000010',
    '00000000-0000-0000-0000-000000000002', 'pending');
  IF v_result->>'error' <> 'already_taken' THEN
    RAISE EXCEPTION 'compat: legacy accept reused a taken booking';
  END IF;
END $$;

-- งานใหม่: คนขับ 2 ติดงานอยู่ -> เสนอให้คนขับ 1 ซึ่งรับผ่าน offer (แอปใหม่)
INSERT INTO public.bookings(id,customer_id,service_type,status,origin_lat,origin_lng)
VALUES ('00000000-0000-0000-0000-000000000011','00000000-0000-0000-0000-000000000099','parcel','pending',13.0100,100.0000);
SET request.jwt.claim.sub = '00000000-0000-0000-0000-000000000001';
DO $$
DECLARE v_result jsonb; v_booking public.bookings%ROWTYPE; v_offer_status text;
BEGIN
  v_result := public.accept_booking('00000000-0000-0000-0000-000000000011',
    '00000000-0000-0000-0000-000000000001', 'pending');
  SELECT * INTO v_booking FROM public.bookings WHERE id='00000000-0000-0000-0000-000000000011';
  SELECT status INTO v_offer_status FROM public.driver_job_offers
   WHERE booking_id='00000000-0000-0000-0000-000000000011'
     AND driver_id='00000000-0000-0000-0000-000000000001';
  IF v_result->>'success' <> 'true' OR v_booking.status <> 'accepted'
     OR v_offer_status <> 'accepted' THEN
    RAISE EXCEPTION 'compat: offer path failed: % / % / %', v_result, v_booking.status, v_offer_status;
  END IF;
END $$;

-- ลูกค้ายกเลิกงานที่กำลังเสนออยู่ -> offer ถูกยกเลิก
UPDATE public.driver_locations SET is_available = true;
INSERT INTO public.profiles VALUES
  ('00000000-0000-0000-0000-000000000003','driver','approved',ARRAY['parcel'],NULL);
INSERT INTO public.driver_locations VALUES
  ('00000000-0000-0000-0000-000000000003',true,true,13.0000,100.0000,now());
INSERT INTO public.wallets VALUES ('00000000-0000-0000-0000-000000000003',100);
INSERT INTO public.bookings(id,customer_id,service_type,status,origin_lat,origin_lng)
VALUES ('00000000-0000-0000-0000-000000000012','00000000-0000-0000-0000-000000000099','parcel','pending',13.0000,100.0000);
UPDATE public.bookings SET status='cancelled' WHERE id='00000000-0000-0000-0000-000000000012';
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM public.driver_job_offers
      WHERE booking_id='00000000-0000-0000-0000-000000000012' AND status='offered') THEN
    RAISE EXCEPTION 'compat: offer survived a cancelled booking';
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.driver_job_offers
      WHERE booking_id='00000000-0000-0000-0000-000000000012' AND status='cancelled') THEN
    RAISE EXCEPTION 'compat: cancelled booking was never offered (fixture invalid)';
  END IF;
END $$;

\echo 'driver offer compat fixture passed'
