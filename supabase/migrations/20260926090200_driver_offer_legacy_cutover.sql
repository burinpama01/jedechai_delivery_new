-- คิวเสนองานคนขับ — ปิดเส้นทางเดิม (cutover)
--
-- ⚠️ ห้าม apply จนกว่าคนขับเกือบทั้งหมดจะอัปเดตแอปเป็น 1.24.0 ขึ้นไป
-- หลัง apply แอปคนขับเวอร์ชันเก่าจะไม่เห็นงานรอรับและกดรับงานไม่ได้
--
-- ต้อง apply 20260926090000 (compat) และ 20260926090100 (cron) ก่อน
-- สิ่งที่ไฟล์นี้ทำ:
--   * accept_booking รับได้เฉพาะงานที่ถูกเสนอให้ตัวเอง
--   * notify_driver_visible_job ไม่ broadcast งานที่ยังไม่มีคนขับ (กันแข่งกับคิว)
--   * drop policy ที่ให้คนขับเห็น/แก้งานที่ยังไม่มีเจ้าของ, ปิด get_nearby_bookings
--   * trigger กันคนขับเขียน driver_id ตรงเข้า bookings
BEGIN;

CREATE OR REPLACE FUNCTION public.accept_booking(
  p_booking_id uuid, p_driver_id uuid, p_expected_status text DEFAULT 'pending')
RETURNS jsonb LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_offer uuid; v_status text;
BEGIN
  IF p_driver_id IS DISTINCT FROM auth.uid() THEN
    RETURN jsonb_build_object('success',false,'error','driver_mismatch');
  END IF;
  SELECT status INTO v_status FROM public.bookings WHERE id = p_booking_id;
  IF v_status IS DISTINCT FROM p_expected_status THEN
    RETURN jsonb_build_object('success',false,'error','status_changed');
  END IF;
  SELECT id INTO v_offer FROM public.driver_job_offers
   WHERE booking_id = p_booking_id AND driver_id = auth.uid()
     AND status = 'offered' AND expires_at > now();
  IF v_offer IS NULL THEN RETURN jsonb_build_object('success',false,'error','not_offered'); END IF;
  RETURN public.accept_driver_job_offer(v_offer);
END;
$$;
REVOKE ALL ON FUNCTION public.accept_booking(uuid,uuid,text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_booking(uuid,uuid,text) TO authenticated;

-- แจ้งเตือนคนขับที่ได้งานแล้วยังทำงานเหมือนเดิม แต่ไม่ broadcast งานที่ยังไม่มีคนขับ
ALTER FUNCTION public.notify_driver_visible_job(uuid,text,text,double precision)
  RENAME TO notify_driver_visible_job_broadcast_legacy;
REVOKE ALL ON FUNCTION public.notify_driver_visible_job_broadcast_legacy(uuid,text,text,double precision)
  FROM PUBLIC, anon, authenticated, service_role;
CREATE OR REPLACE FUNCTION public.notify_driver_visible_job(
  p_booking_id uuid, p_title text DEFAULT NULL, p_body text DEFAULT NULL,
  p_radius_km double precision DEFAULT 5.0)
RETURNS TABLE(driver_id uuid, notification_id uuid)
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_assigned_driver uuid;
BEGIN
  SELECT b.driver_id INTO v_assigned_driver FROM public.bookings b WHERE b.id=p_booking_id;
  IF v_assigned_driver IS NULL THEN RETURN; END IF;
  RETURN QUERY SELECT * FROM public.notify_driver_visible_job_broadcast_legacy(
    p_booking_id,p_title,p_body,p_radius_km);
END;
$$;
REVOKE ALL ON FUNCTION public.notify_driver_visible_job(uuid,text,text,double precision)
  FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.notify_driver_visible_job(uuid,text,text,double precision)
  TO authenticated, service_role;

-- แอปเก่าต้องค้น/รับงานที่ยังไม่มีเจ้าของผ่าน policy เดิมหรือ nearby RPC ไม่ได้อีก
DROP POLICY IF EXISTS "Drivers can view pending bookings" ON public.bookings;
DROP POLICY IF EXISTS "bookings_select_driver" ON public.bookings;
DROP POLICY IF EXISTS "bookings_update_driver" ON public.bookings;
CREATE POLICY "bookings_update_driver" ON public.bookings
  FOR UPDATE USING (driver_id = auth.uid())
  WITH CHECK (driver_id = auth.uid());
DO $$ BEGIN
  IF to_regprocedure('public.get_nearby_bookings(double precision,double precision,double precision,text[])') IS NOT NULL THEN
    REVOKE ALL ON FUNCTION public.get_nearby_bookings(
      double precision, double precision, double precision, text[])
      FROM PUBLIC, anon, authenticated;
  END IF;
END $$;

CREATE OR REPLACE FUNCTION public.guard_direct_driver_claim()
RETURNS trigger LANGUAGE plpgsql SECURITY INVOKER SET search_path = public AS $$
BEGIN
  IF current_user = 'authenticated' AND OLD.driver_id IS NULL
     AND NEW.driver_id IS NOT NULL THEN
    RAISE EXCEPTION 'use_accept_driver_job_offer';
  END IF;
  RETURN NEW;
END;
$$;
DROP TRIGGER IF EXISTS zz_guard_direct_driver_claim ON public.bookings;
CREATE TRIGGER zz_guard_direct_driver_claim
BEFORE UPDATE OF driver_id ON public.bookings
FOR EACH ROW EXECUTE FUNCTION public.guard_direct_driver_claim();

COMMIT;
