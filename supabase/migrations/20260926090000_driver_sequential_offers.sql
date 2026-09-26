-- คิวเสนองานคนขับทีละคน — ช่วงเปลี่ยนผ่าน (compat)
--
-- ไฟล์นี้ "เพิ่ม" คิว offer โดยไม่ปิดเส้นทางเดิม เพื่อให้แอปคนขับเวอร์ชันเก่า
-- (ก่อน 1.24.0) ยังเห็นงานรอรับและกดรับผ่าน accept_booking ได้เหมือนเดิม
--   * แอปใหม่: เห็นเฉพาะงานที่ถูกเสนอให้ตัวเอง + รับผ่าน accept_booking -> offer
--   * แอปเก่า: เห็นงานรอรับตาม policy เดิม + รับผ่าน accept_booking แบบเดิม
--   * ใครรับก่อนได้งาน; รับงานแล้ว offer ที่ค้างของงานนั้นถูกยกเลิกอัตโนมัติ
--
-- การปิดเส้นทางเดิม (drop policy, ปิด get_nearby_bookings, ห้ามรับงานนอก offer,
-- หยุด broadcast) แยกไปไว้ที่ 20260926090200_driver_offer_legacy_cutover.sql
-- apply ไฟล์นั้นเมื่อคนขับเกือบทั้งหมดอัปเดตแอปแล้วเท่านั้น
--
-- cron ที่ขับคิวอยู่ใน 20260926090100 (ต้อง deploy worker + Vault secret ก่อน)
BEGIN;

ALTER TABLE public.bookings ADD COLUMN IF NOT EXISTS driver_dispatch_next_at timestamptz DEFAULT now();
CREATE TABLE public.driver_job_offers (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  booking_id uuid NOT NULL REFERENCES public.bookings(id) ON DELETE CASCADE,
  driver_id uuid NOT NULL REFERENCES public.profiles(id),
  status text NOT NULL DEFAULT 'offered'
    CHECK (status IN ('offered', 'accepted', 'skipped', 'expired', 'cancelled')),
  offered_at timestamptz NOT NULL DEFAULT now(),
  expires_at timestamptz NOT NULL DEFAULT (now() + interval '60 seconds'),
  ended_at timestamptz,
  push_sent_at timestamptz,
  push_claimed_at timestamptz,
  push_attempts integer NOT NULL DEFAULT 0,
  notification_id uuid,
  CONSTRAINT driver_job_offers_time_check CHECK (expires_at > offered_at),
  CONSTRAINT driver_job_offers_unique_attempt UNIQUE (booking_id, driver_id)
);
CREATE UNIQUE INDEX driver_job_offers_one_active_booking
  ON public.driver_job_offers(booking_id) WHERE status = 'offered';
CREATE UNIQUE INDEX driver_job_offers_one_active_driver
  ON public.driver_job_offers(driver_id) WHERE status = 'offered';
CREATE INDEX driver_job_offers_expiry_idx
  ON public.driver_job_offers(expires_at) WHERE status = 'offered';
CREATE INDEX driver_job_offers_push_idx
  ON public.driver_job_offers(offered_at) WHERE status = 'offered' AND push_sent_at IS NULL;
ALTER PUBLICATION supabase_realtime ADD TABLE public.driver_job_offers;

ALTER TABLE public.driver_job_offers ENABLE ROW LEVEL SECURITY;
CREATE POLICY driver_job_offers_read_own ON public.driver_job_offers
  FOR SELECT TO authenticated USING (driver_id = auth.uid());
CREATE POLICY driver_job_offers_admin_read ON public.driver_job_offers
  FOR SELECT TO authenticated USING (
    EXISTS (SELECT 1 FROM public.profiles p WHERE p.id=auth.uid() AND p.role='admin')
  );
REVOKE ALL ON public.driver_job_offers FROM PUBLIC, anon, authenticated;
GRANT SELECT ON public.driver_job_offers TO authenticated;
GRANT ALL ON public.driver_job_offers TO service_role;

CREATE OR REPLACE FUNCTION public.dispatch_next_driver_job_offer(p_booking_id uuid)
RETURNS uuid LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
  v_driver uuid;
  v_offer uuid;
  v_notification uuid;
  v_min_wallet numeric;
  v_radius_km double precision;
  v_attempt integer;
BEGIN
  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND OR v_booking.driver_id IS NOT NULL OR
     NOT ((v_booking.service_type IN ('ride','parcel','laundry') AND v_booking.status = 'pending')
       OR (v_booking.service_type = 'food' AND v_booking.status IN ('preparing','ready_for_pickup')))
     OR v_booking.origin_lat IS NULL OR v_booking.origin_lng IS NULL
     OR (v_booking.scheduled_at IS NOT NULL AND v_booking.scheduled_at > now()) THEN
    RETURN NULL;
  END IF;

  -- An expired offer cannot continue to reserve this booking or driver.
  UPDATE public.driver_job_offers SET status = 'expired', ended_at = now()
   WHERE booking_id = p_booking_id AND status = 'offered' AND expires_at <= now();
  SELECT id INTO v_offer FROM public.driver_job_offers
   WHERE booking_id = p_booking_id AND status = 'offered';
  IF v_offer IS NOT NULL THEN RETURN v_offer; END IF;

  SELECT COALESCE(max(driver_min_wallet), 0) INTO v_min_wallet FROM public.system_config;
  SELECT COALESCE(max((detection_radius_config->>'driver_to_order_km')::double precision),20)
    INTO v_radius_km FROM public.system_config;
  -- Concurrent statements can start from an older snapshot. Retry after a
  -- uniqueness conflict so the booking itself is never rolled back by a burst.
  FOR v_attempt IN 1..10 LOOP
    v_driver := NULL;
    v_offer := NULL;
    SELECT dl.driver_id INTO v_driver
    FROM public.driver_locations dl
    JOIN public.profiles p ON p.id = dl.driver_id
    JOIN public.wallets w ON w.user_id = dl.driver_id
   WHERE p.role = 'driver' AND p.approval_status = 'approved'
     AND dl.is_online = true AND dl.is_available = true
     AND dl.last_heartbeat_at > now() - interval '2 minutes'
     AND dl.location_lat IS NOT NULL AND dl.location_lng IS NOT NULL
     AND (6371.0 * acos(LEAST(1.0, GREATEST(-1.0,
       cos(radians(v_booking.origin_lat)) * cos(radians(dl.location_lat)) *
       cos(radians(dl.location_lng) - radians(v_booking.origin_lng)) +
       sin(radians(v_booking.origin_lat)) * sin(radians(dl.location_lat)))))) <= v_radius_km
     AND w.balance >= v_min_wallet
     AND (p.accepted_service_types IS NULL
       OR cardinality(p.accepted_service_types) = 0
       OR v_booking.service_type = ANY(p.accepted_service_types))
     AND (v_booking.service_type <> 'ride' OR v_booking.vehicle_type IS NULL
       OR v_booking.vehicle_type = p.vehicle_type)
     AND NOT EXISTS (
       SELECT 1 FROM public.driver_job_offers x
        WHERE x.booking_id = p_booking_id AND x.driver_id = dl.driver_id)
     AND NOT EXISTS (
       SELECT 1 FROM public.driver_job_offers x
        WHERE x.driver_id = dl.driver_id AND x.status = 'offered')
     AND NOT EXISTS (
       SELECT 1 FROM public.bookings active
        WHERE active.driver_id = dl.driver_id
          AND active.status IN ('driver_accepted','accepted','matched','preparing',
            'arrived','arrived_at_merchant','ready_for_pickup','picking_up_order','in_transit'))
   ORDER BY (6371.0 * acos(LEAST(1.0, GREATEST(-1.0,
     cos(radians(v_booking.origin_lat)) * cos(radians(dl.location_lat)) *
     cos(radians(dl.location_lng) - radians(v_booking.origin_lng)) +
     sin(radians(v_booking.origin_lat)) * sin(radians(dl.location_lat)))))), dl.driver_id
   FOR UPDATE OF dl SKIP LOCKED
    LIMIT 1;
    IF v_driver IS NULL THEN EXIT; END IF;
    INSERT INTO public.driver_job_offers(booking_id, driver_id)
      VALUES (p_booking_id, v_driver)
      ON CONFLICT DO NOTHING RETURNING id INTO v_offer;
    EXIT WHEN v_offer IS NOT NULL;
  END LOOP;

  IF v_offer IS NULL THEN
    UPDATE public.bookings SET driver_dispatch_next_at = now() + interval '30 seconds'
      WHERE id = p_booking_id;
    RETURN NULL;
  END IF;
  UPDATE public.bookings SET driver_dispatch_next_at = NULL WHERE id = p_booking_id;
  INSERT INTO public.notifications(user_id,title,body,type,data)
  VALUES (v_driver,'มีงานใหม่รอรับ','โปรดรับหรือข้ามงานภายใน 60 วินาที',
    'driver.job.offer',jsonb_build_object('booking_id',p_booking_id,'offer_id',v_offer))
  RETURNING id INTO STRICT v_notification;
  -- notification_id is optional: the push worker can still deliver when this
  -- notification insert is unavailable, but the transaction above must succeed.
  UPDATE public.driver_job_offers SET notification_id = v_notification WHERE id = v_offer;
  RETURN v_offer;
END;
$$;
REVOKE ALL ON FUNCTION public.dispatch_next_driver_job_offer(uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.dispatch_next_driver_job_offer(uuid) TO service_role;

CREATE OR REPLACE FUNCTION public.accept_driver_job_offer(p_offer_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_booking_id uuid;
  v_booking public.bookings%ROWTYPE;
  v_offer public.driver_job_offers%ROWTYPE;
  v_min_wallet numeric;
BEGIN
  SELECT booking_id INTO v_booking_id FROM public.driver_job_offers WHERE id = p_offer_id;
  IF v_booking_id IS NULL THEN RETURN jsonb_build_object('success',false,'error','not_found'); END IF;
  SELECT * INTO v_booking FROM public.bookings WHERE id = v_booking_id FOR UPDATE;
  SELECT * INTO v_offer FROM public.driver_job_offers WHERE id = p_offer_id FOR UPDATE;
  IF v_offer.driver_id IS DISTINCT FROM auth.uid() OR
     v_offer.status <> 'offered' OR v_offer.expires_at <= now() OR
     v_booking.driver_id IS NOT NULL OR
     NOT ((v_booking.service_type IN ('ride','parcel','laundry') AND v_booking.status = 'pending')
       OR (v_booking.service_type = 'food' AND v_booking.status IN ('preparing','ready_for_pickup'))) THEN
    RETURN jsonb_build_object('success',false,'error','offer_unavailable');
  END IF;
  IF EXISTS (SELECT 1 FROM public.bookings active WHERE active.driver_id = auth.uid()
       AND active.id <> v_booking_id AND active.status IN ('driver_accepted','accepted',
         'matched','preparing','arrived','arrived_at_merchant','ready_for_pickup',
         'picking_up_order','in_transit')) THEN
    RETURN jsonb_build_object('success',false,'error','driver_busy');
  END IF;
  IF NOT EXISTS (SELECT 1 FROM public.driver_locations dl
      WHERE dl.driver_id=auth.uid() AND dl.is_online=true AND dl.is_available=true
        AND dl.last_heartbeat_at > now()-interval '2 minutes') THEN
    RETURN jsonb_build_object('success',false,'error','driver_offline');
  END IF;
  SELECT COALESCE(max(driver_min_wallet),0) INTO v_min_wallet FROM public.system_config;
  IF NOT EXISTS (SELECT 1 FROM public.wallets WHERE user_id = auth.uid() AND balance >= v_min_wallet) THEN
    RETURN jsonb_build_object('success',false,'error','wallet_insufficient');
  END IF;
  UPDATE public.bookings SET driver_id = auth.uid(),
    status = CASE WHEN v_booking.service_type = 'food' THEN 'driver_accepted' ELSE 'accepted' END,
    status_origin = 'jdc', assigned_at = now(), updated_at = now()
   WHERE id = v_booking_id AND driver_id IS NULL;
  UPDATE public.driver_job_offers SET status = 'accepted', ended_at = now() WHERE id = p_offer_id;
  RETURN jsonb_build_object('success',true,'booking_id',v_booking_id);
END;
$$;
REVOKE ALL ON FUNCTION public.accept_driver_job_offer(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_driver_job_offer(uuid) TO authenticated;

CREATE OR REPLACE FUNCTION public.skip_driver_job_offer(p_offer_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE
  v_booking_id uuid;
  v_offer public.driver_job_offers%ROWTYPE;
  v_next uuid;
BEGIN
  SELECT booking_id INTO v_booking_id FROM public.driver_job_offers WHERE id = p_offer_id;
  IF v_booking_id IS NULL THEN RETURN jsonb_build_object('success',false,'error','not_found'); END IF;
  PERFORM 1 FROM public.bookings WHERE id = v_booking_id FOR UPDATE;
  SELECT * INTO v_offer FROM public.driver_job_offers WHERE id = p_offer_id FOR UPDATE;
  IF v_offer.driver_id IS DISTINCT FROM auth.uid() OR v_offer.status <> 'offered'
     OR v_offer.expires_at <= now() THEN
    RETURN jsonb_build_object('success',false,'error','offer_unavailable');
  END IF;
  UPDATE public.driver_job_offers SET status = 'skipped', ended_at = now() WHERE id = p_offer_id;
  v_next := public.dispatch_next_driver_job_offer(v_booking_id);
  RETURN jsonb_build_object('success',true,'next_offer_id',v_next);
END;
$$;
REVOKE ALL ON FUNCTION public.skip_driver_job_offer(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.skip_driver_job_offer(uuid) TO authenticated;

-- ชื่อ RPC เดิม ใช้ได้ทั้งแอปเก่าและแอปใหม่
--   * มี offer ที่ยังไม่หมดเวลาของคนขับคนนี้ -> รับผ่าน offer (ตรวจ busy/wallet/online)
--   * ไม่มี offer -> พฤติกรรมเดิมทุกอย่าง (status driver_accepted) เพื่อให้แอปเก่าใช้ได้
-- ทั้งสองทางห้ามรับงานแทนคนขับคนอื่น (เดิมไม่ได้ตรวจ p_driver_id กับ auth.uid())
CREATE OR REPLACE FUNCTION public.accept_booking(
  p_booking_id uuid, p_driver_id uuid, p_expected_status text DEFAULT 'pending')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_offer uuid; v_status text; v_rows integer;
BEGIN
  IF p_driver_id IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success',false,'error','driver_mismatch');
  END IF;

  SELECT id INTO v_offer FROM public.driver_job_offers
   WHERE booking_id = p_booking_id AND driver_id = auth.uid()
     AND status = 'offered' AND expires_at > now();
  IF v_offer IS NOT NULL THEN
    SELECT status INTO v_status FROM public.bookings WHERE id = p_booking_id;
    IF v_status IS DISTINCT FROM p_expected_status THEN
      RETURN jsonb_build_object('success',false,'error','status_changed');
    END IF;
    RETURN public.accept_driver_job_offer(v_offer);
  END IF;

  -- legacy path: เหมือน 20260630055943 ทุกอย่าง
  -- ตั้งใจใช้ 'driver_accepted' ทุกประเภทงานแบบเดิม (ทาง offer ใช้ 'accepted' กับ ride/parcel)
  -- ทั้งแอปเก่าและแอปใหม่รองรับทั้งสองสถานะอยู่แล้ว
  UPDATE public.bookings
     SET driver_id = p_driver_id, status = 'driver_accepted', status_origin = 'jdc',
         assigned_at = now(), updated_at = now()
   WHERE id = p_booking_id AND driver_id IS NULL AND status = p_expected_status;
  GET DIAGNOSTICS v_rows = ROW_COUNT;
  IF v_rows = 0 THEN
    RETURN jsonb_build_object('success',false,'error','already_taken',
      'message','งานนี้ถูกรับไปแล้ว หรือสถานะเปลี่ยนไปแล้ว');
  END IF;
  RETURN jsonb_build_object('success',true,'booking_id',p_booking_id);
END;
$$;
REVOKE ALL ON FUNCTION public.accept_booking(uuid,uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_booking(uuid,uuid,text) TO authenticated;

CREATE OR REPLACE FUNCTION public.process_driver_offer_queue(p_limit integer DEFAULT 100)
RETURNS integer LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_id uuid; v_processed integer := 0;
BEGIN
  FOR v_id IN
    SELECT id FROM public.bookings b
     WHERE b.driver_id IS NULL AND b.origin_lat IS NOT NULL AND b.origin_lng IS NOT NULL
       AND (b.driver_dispatch_next_at IS NULL OR b.driver_dispatch_next_at <= now())
       AND NOT EXISTS (SELECT 1 FROM public.driver_job_offers active_offer
          WHERE active_offer.booking_id = b.id AND active_offer.status = 'offered'
            AND active_offer.expires_at > now())
       AND ((b.service_type IN ('ride','parcel','laundry') AND b.status = 'pending')
         OR (b.service_type = 'food' AND b.status IN ('preparing','ready_for_pickup')))
       AND (b.scheduled_at IS NULL OR b.scheduled_at <= now())
     ORDER BY b.driver_dispatch_next_at NULLS FIRST, b.created_at NULLS LAST, b.id
     LIMIT LEAST(GREATEST(p_limit,1),500)
  LOOP
    PERFORM public.dispatch_next_driver_job_offer(v_id);
    v_processed := v_processed + 1;
  END LOOP;
  RETURN v_processed;
END;
$$;
REVOKE ALL ON FUNCTION public.process_driver_offer_queue(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.process_driver_offer_queue(integer) TO service_role;

CREATE OR REPLACE FUNCTION public.claim_driver_offer_pushes(p_limit integer DEFAULT 100)
RETURNS TABLE(offer_id uuid, booking_id uuid, driver_id uuid, notification_id uuid,
  expires_at timestamptz)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  RETURN QUERY
  WITH claimed AS (
    SELECT o.id FROM public.driver_job_offers o
     WHERE o.status = 'offered' AND o.expires_at > now()
       AND o.push_sent_at IS NULL AND o.push_attempts < 3
       AND (o.push_claimed_at IS NULL OR o.push_claimed_at < now() - interval '30 seconds')
     ORDER BY o.offered_at LIMIT LEAST(GREATEST(p_limit,1),100)
     FOR UPDATE SKIP LOCKED
  ), updated AS (
    UPDATE public.driver_job_offers o
       SET push_claimed_at = now(), push_attempts = push_attempts + 1
      FROM claimed c WHERE o.id = c.id
    RETURNING o.id, o.booking_id, o.driver_id, o.notification_id, o.expires_at
  )
  SELECT u.id, u.booking_id, u.driver_id, u.notification_id, u.expires_at FROM updated u;
END;
$$;
REVOKE ALL ON FUNCTION public.claim_driver_offer_pushes(integer) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.claim_driver_offer_pushes(integer) TO service_role;

CREATE OR REPLACE FUNCTION public.admin_assign_driver_job(
  p_booking_id uuid, p_driver_id uuid)
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_booking public.bookings%ROWTYPE;
BEGIN
  IF auth.role() <> 'service_role' THEN
    RETURN jsonb_build_object('success',false,'error','not_authorized');
  END IF;
  SELECT * INTO v_booking FROM public.bookings WHERE id = p_booking_id FOR UPDATE;
  IF NOT FOUND OR v_booking.driver_id IS NOT NULL OR
      NOT ((v_booking.service_type IN ('ride','parcel','laundry') AND v_booking.status = 'pending')
        OR (v_booking.service_type = 'food' AND v_booking.status IN ('preparing','ready_for_pickup'))) THEN
    RETURN jsonb_build_object('success',false,'error','booking_unavailable');
  END IF;
  PERFORM 1 FROM public.driver_locations dl JOIN public.profiles p ON p.id=dl.driver_id
   WHERE dl.driver_id=p_driver_id AND p.role='driver' AND p.approval_status='approved'
     AND dl.is_online=true AND dl.is_available=true
     AND dl.last_heartbeat_at > now() - interval '2 minutes'
   FOR UPDATE OF dl;
  IF NOT FOUND OR EXISTS (SELECT 1 FROM public.bookings active
      WHERE active.driver_id=p_driver_id AND active.status IN ('driver_accepted','accepted',
        'matched','preparing','arrived','arrived_at_merchant','ready_for_pickup',
        'picking_up_order','in_transit')) THEN
    RETURN jsonb_build_object('success',false,'error','driver_unavailable');
  END IF;
  IF EXISTS (SELECT 1 FROM public.driver_job_offers active_offer
      WHERE active_offer.driver_id=p_driver_id AND active_offer.status='offered'
        AND active_offer.booking_id <> p_booking_id) THEN
    RETURN jsonb_build_object('success',false,'error','driver_has_other_offer');
  END IF;
  UPDATE public.driver_job_offers SET status='cancelled',ended_at=now()
   WHERE booking_id=p_booking_id AND status='offered';
  UPDATE public.bookings SET driver_id=p_driver_id,
    status='driver_accepted',
    assigned_at=now(),updated_at=now(),status_origin='jdc'
   WHERE id=p_booking_id AND driver_id IS NULL;
  RETURN jsonb_build_object('success',true);
END;
$$;
REVOKE ALL ON FUNCTION public.admin_assign_driver_job(uuid,uuid) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.admin_assign_driver_job(uuid,uuid) TO service_role;

-- เริ่มเสนองานเมื่อมีงานใหม่/สถานะพร้อมให้คนขับ
-- และยกเลิก offer ที่ค้างเมื่องานถูกรับไปแล้ว (เช่นคนขับแอปเก่ากดรับจากรายการ)
-- หรือสถานะไม่อยู่ในช่วงหาคนขับแล้ว (เช่นลูกค้ายกเลิก)
CREATE OR REPLACE FUNCTION public.start_driver_job_offer_on_booking()
RETURNS trigger LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
BEGIN
  IF TG_OP = 'UPDATE' AND (
       NEW.driver_id IS NOT NULL OR
       NOT ((NEW.service_type IN ('ride','parcel','laundry') AND NEW.status = 'pending')
         OR (NEW.service_type = 'food' AND NEW.status IN ('preparing','ready_for_pickup')))) THEN
    UPDATE public.driver_job_offers
       SET status = 'cancelled', ended_at = now()
     WHERE booking_id = NEW.id AND status = 'offered'
       AND driver_id IS DISTINCT FROM NEW.driver_id;
  END IF;
  IF NEW.driver_id IS NULL THEN
    PERFORM public.dispatch_next_driver_job_offer(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;
CREATE TRIGGER start_driver_job_offer
AFTER INSERT OR UPDATE OF status, driver_id ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.start_driver_job_offer_on_booking();

-- เพิ่มสิทธิ์ให้คนขับอ่านงานที่ถูกเสนอให้ตัวเอง (policy เดิมยังอยู่ครบ)
DROP POLICY IF EXISTS "bookings_select_offered_driver" ON public.bookings;
CREATE POLICY "bookings_select_offered_driver" ON public.bookings
  FOR SELECT USING (EXISTS (
    SELECT 1 FROM public.driver_job_offers o
    WHERE o.booking_id = bookings.id AND o.driver_id = auth.uid()
      AND o.status = 'offered' AND o.expires_at > now()
  ));

COMMIT;
