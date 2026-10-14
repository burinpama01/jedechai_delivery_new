-- ข้อเสนอแยกจากอัตราจริง ใช้ได้หลังแอดมินอนุมัติเท่านั้น
BEGIN;
CREATE TABLE public.merchant_gp_proposals (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  revision integer NOT NULL CHECK (revision > 0),
  status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','returned','approved','superseded')),
  gp_rate numeric NOT NULL CHECK (gp_rate >= 0 AND gp_rate <= 0.95),
  base_delivery_fee numeric NOT NULL CHECK (base_delivery_fee >= 0 AND base_delivery_fee::text NOT IN ('NaN','Infinity','-Infinity')),
  base_distance_km numeric NOT NULL CHECK (base_distance_km >= 0 AND base_distance_km::text NOT IN ('NaN','Infinity','-Infinity')),
  per_km_charge numeric NOT NULL CHECK (per_km_charge >= 0 AND per_km_charge::text NOT IN ('NaN','Infinity','-Infinity')),
  merchant_note text NOT NULL DEFAULT '' CHECK (length(merchant_note) <= 2000),
  rejection_reason text CHECK (length(rejection_reason) <= 2000),
  gp_system_rate numeric,
  gp_driver_rate numeric,
  created_at timestamptz NOT NULL DEFAULT now(),
  reviewed_at timestamptz,
  reviewed_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  UNIQUE (merchant_id, revision),
  CHECK (status <> 'returned' OR length(btrim(rejection_reason)) > 0),
  CHECK (status <> 'approved' OR (gp_system_rate IS NOT NULL AND gp_driver_rate IS NOT NULL
    AND gp_system_rate >= 0 AND gp_driver_rate >= 0 AND gp_system_rate + gp_driver_rate = gp_rate))
);
CREATE UNIQUE INDEX merchant_gp_proposals_one_pending ON public.merchant_gp_proposals(merchant_id) WHERE status = 'pending';
ALTER TABLE public.profiles ADD COLUMN gp_proposal_id uuid REFERENCES public.merchant_gp_proposals(id);
ALTER TABLE public.profiles ADD COLUMN gp_proposal_status text CHECK (gp_proposal_status IN ('pending','returned','approved'));
ALTER TABLE public.profiles ADD CONSTRAINT gp_proposal_metadata_pair CHECK ((gp_proposal_id IS NULL) = (gp_proposal_status IS NULL));
ALTER TABLE public.merchant_gp_proposals ENABLE ROW LEVEL SECURITY;
GRANT SELECT ON public.merchant_gp_proposals TO authenticated;
REVOKE INSERT, UPDATE, DELETE ON public.merchant_gp_proposals FROM anon, authenticated;
CREATE POLICY merchant_gp_proposals_read ON public.merchant_gp_proposals FOR SELECT TO authenticated
 USING (merchant_id = auth.uid() OR EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin'));

CREATE FUNCTION public.guard_profile_gp_proposal() RETURNS trigger
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_proposal public.merchant_gp_proposals%ROWTYPE;
BEGIN
  IF TG_OP = 'INSERT' THEN
    IF NEW.gp_proposal_id IS NOT NULL OR NEW.gp_proposal_status IS NOT NULL THEN
      RAISE EXCEPTION 'gp_proposal_metadata_rpc_only';
    END IF;
    RETURN NEW;
  END IF;
  IF (NEW.gp_proposal_id IS DISTINCT FROM OLD.gp_proposal_id
      OR NEW.gp_proposal_status IS DISTINCT FROM OLD.gp_proposal_status)
     AND COALESCE(current_setting('app.allow_gp_proposal_update',true),'') <> 'on' THEN
    RAISE EXCEPTION 'gp_proposal_metadata_rpc_only';
  END IF;
  -- กัน approve ผ่าน Flutter/direct update/service role/override_gp
  IF NEW.approval_status = 'approved' AND OLD.approval_status IS DISTINCT FROM 'approved'
     AND NEW.gp_proposal_id IS NOT NULL THEN
    SELECT * INTO v_proposal FROM public.merchant_gp_proposals WHERE id = NEW.gp_proposal_id;
    IF NOT FOUND OR v_proposal.merchant_id <> NEW.id OR v_proposal.status <> 'approved'
       OR NEW.gp_proposal_status <> 'approved' THEN
      RAISE EXCEPTION 'gp_proposal_pending';
    END IF;
    IF NEW.gp_rate IS DISTINCT FROM v_proposal.gp_rate
       OR NEW.custom_base_fare IS DISTINCT FROM v_proposal.base_delivery_fee
       OR NEW.custom_base_distance IS DISTINCT FROM v_proposal.base_distance_km
       OR NEW.custom_per_km IS DISTINCT FROM v_proposal.per_km_charge
       OR NEW.custom_delivery_fee IS NOT NULL
       OR NEW.merchant_gp_system_rate IS DISTINCT FROM v_proposal.gp_system_rate
       OR NEW.merchant_gp_driver_rate IS DISTINCT FROM v_proposal.gp_driver_rate THEN
      RAISE EXCEPTION 'gp_proposal_rates_changed';
    END IF;
  END IF;
  -- ไม่ให้ตั้งแพ็กเกจผ่าน admin editor เพื่อข้ามข้อเสนอที่ยังรอ
  IF NEW.gp_plan_id IS DISTINCT FROM OLD.gp_plan_id AND OLD.gp_proposal_id IS NOT NULL
     AND COALESCE(current_setting('app.allow_gp_proposal_update',true),'') <> 'on' THEN
    RAISE EXCEPTION 'gp_proposal_requires_review';
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER trg_guard_profile_gp_proposal BEFORE INSERT OR UPDATE ON public.profiles
 FOR EACH ROW EXECUTE FUNCTION public.guard_profile_gp_proposal();

CREATE FUNCTION public.merchant_submit_gp_proposal(p_gp_rate numeric, p_base_delivery_fee numeric,
 p_base_distance_km numeric, p_per_km_charge numeric, p_merchant_note text DEFAULT '') RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_uid uuid := auth.uid(); v_profile public.profiles%ROWTYPE;
 v_id uuid; v_revision integer;
BEGIN
  IF v_uid IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  SELECT * INTO v_profile FROM public.profiles WHERE id = v_uid FOR UPDATE;
  IF NOT FOUND OR v_profile.role <> 'merchant' THEN RAISE EXCEPTION 'not_merchant'; END IF;
  IF v_profile.merchant_service_types IS DISTINCT FROM ARRAY['food']::text[] THEN RAISE EXCEPTION 'food_merchant_required'; END IF;
  IF COALESCE(v_profile.approval_status,'pending') <> 'pending' THEN RAISE EXCEPTION 'new_merchant_only'; END IF;
  IF v_profile.gp_proposal_status IN ('pending','approved') THEN RAISE EXCEPTION 'gp_proposal_already_submitted'; END IF;
  IF p_gp_rate IS NULL OR p_gp_rate < 0 OR p_gp_rate > 0.95 OR p_gp_rate::text IN ('NaN','Infinity','-Infinity')
    OR p_base_delivery_fee IS NULL OR p_base_delivery_fee < 0 OR p_base_delivery_fee::text IN ('NaN','Infinity','-Infinity')
    OR p_base_distance_km IS NULL OR p_base_distance_km < 0 OR p_base_distance_km::text IN ('NaN','Infinity','-Infinity')
    OR p_per_km_charge IS NULL OR p_per_km_charge < 0 OR p_per_km_charge::text IN ('NaN','Infinity','-Infinity')
    OR length(COALESCE(p_merchant_note,'')) > 2000 THEN RAISE EXCEPTION 'invalid_gp_proposal'; END IF;
  -- ปรับ precision ให้ตรงกัน รองรับ JSON double เช่น 8.2/100
  p_gp_rate := round(p_gp_rate,6);
  SELECT COALESCE(max(revision),0)+1 INTO v_revision FROM public.merchant_gp_proposals WHERE merchant_id=v_uid;
  INSERT INTO public.merchant_gp_proposals(merchant_id,revision,gp_rate,base_delivery_fee,base_distance_km,per_km_charge,merchant_note)
   VALUES(v_uid,v_revision,p_gp_rate,p_base_delivery_fee,p_base_distance_km,p_per_km_charge,btrim(COALESCE(p_merchant_note,''))) RETURNING id INTO v_id;
  PERFORM set_config('app.allow_gp_proposal_update','on',true);
  PERFORM set_config('app.allow_gp_update','on',true);
  UPDATE public.profiles SET gp_proposal_id=v_id,gp_proposal_status='pending',gp_plan_id=NULL,updated_at=now() WHERE id=v_uid;
  PERFORM set_config('app.allow_gp_proposal_update','',true);
  PERFORM set_config('app.allow_gp_update','',true);
  RETURN jsonb_build_object('success',true,'proposal_id',v_id,'revision',v_revision);
END $$;

CREATE FUNCTION public.admin_review_gp_proposal(p_proposal_id uuid, p_decision text,
 p_reason text DEFAULT '', p_gp_system_rate numeric DEFAULT NULL, p_gp_driver_rate numeric DEFAULT NULL) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_admin uuid := auth.uid(); v_merchant uuid; v_profile public.profiles%ROWTYPE;
 v_proposal public.merchant_gp_proposals%ROWTYPE;
BEGIN
  IF v_admin IS NULL OR NOT EXISTS(SELECT 1 FROM public.profiles WHERE id=v_admin AND role='admin') THEN RAISE EXCEPTION 'admin_required'; END IF;
  SELECT merchant_id INTO v_merchant FROM public.merchant_gp_proposals WHERE id=p_proposal_id;
  IF NOT FOUND THEN RAISE EXCEPTION 'gp_proposal_not_found'; END IF;
  SELECT * INTO v_profile FROM public.profiles WHERE id=v_merchant FOR UPDATE;
  SELECT * INTO v_proposal FROM public.merchant_gp_proposals WHERE id=p_proposal_id FOR UPDATE;
  IF v_profile.gp_proposal_id IS DISTINCT FROM p_proposal_id OR v_proposal.status <> 'pending'
     OR v_profile.gp_proposal_status <> 'pending' THEN RAISE EXCEPTION 'gp_proposal_stale'; END IF;
  IF COALESCE(v_profile.approval_status,'pending') <> 'pending' OR v_profile.merchant_service_types IS DISTINCT FROM ARRAY['food']::text[] THEN RAISE EXCEPTION 'new_merchant_only'; END IF;
  IF p_decision IS NULL OR p_decision NOT IN ('approved','returned') THEN RAISE EXCEPTION 'invalid_gp_decision'; END IF;
  IF p_decision='returned' AND (length(btrim(COALESCE(p_reason,'')))=0 OR length(p_reason)>2000) THEN RAISE EXCEPTION 'gp_return_reason_required'; END IF;
  p_gp_system_rate := round(p_gp_system_rate,6);
  p_gp_driver_rate := round(p_gp_driver_rate,6);
  IF p_decision='approved' AND (p_gp_system_rate IS NULL OR p_gp_driver_rate IS NULL
     OR p_gp_system_rate < 0 OR p_gp_driver_rate < 0
     OR p_gp_system_rate::text IN ('NaN','Infinity','-Infinity') OR p_gp_driver_rate::text IN ('NaN','Infinity','-Infinity')
     OR p_gp_system_rate+p_gp_driver_rate <> v_proposal.gp_rate) THEN RAISE EXCEPTION 'gp_split_mismatch'; END IF;
  PERFORM set_config('app.allow_gp_proposal_update','on',true);
  PERFORM set_config('app.allow_gp_update','on',true);
  PERFORM set_config('app.gp_change_source','admin',true);
  UPDATE public.merchant_gp_proposals SET status=p_decision, reviewed_at=now(),reviewed_by=v_admin,
   rejection_reason=CASE WHEN p_decision='returned' THEN btrim(p_reason) ELSE NULL END,
   gp_system_rate=CASE WHEN p_decision='approved' THEN p_gp_system_rate ELSE NULL END,
   gp_driver_rate=CASE WHEN p_decision='approved' THEN p_gp_driver_rate ELSE NULL END WHERE id=p_proposal_id;
  IF p_decision='approved' THEN
    UPDATE public.profiles SET gp_proposal_status='approved',gp_plan_id=NULL,
     gp_rate=v_proposal.gp_rate,merchant_gp_system_rate=p_gp_system_rate,merchant_gp_driver_rate=p_gp_driver_rate,
     custom_base_fare=v_proposal.base_delivery_fee,custom_base_distance=v_proposal.base_distance_km,
     custom_per_km=v_proposal.per_km_charge,custom_delivery_fee=NULL,updated_at=now() WHERE id=v_merchant;
  ELSE
    UPDATE public.profiles SET gp_proposal_status='returned',updated_at=now() WHERE id=v_merchant;
  END IF;
  PERFORM set_config('app.allow_gp_proposal_update','',true);
  PERFORM set_config('app.allow_gp_update','',true);
  PERFORM set_config('app.gp_change_source','',true);
  RETURN jsonb_build_object('success',true,'status',p_decision);
END $$;

-- ครอบ RPC เดิมเพื่อเลือกแพ็กเกจหลังตีกลับได้ โดยไม่ทิ้งข้อเสนอค้าง
ALTER FUNCTION public.merchant_select_gp_plan(uuid) RENAME TO _merchant_select_gp_plan_before_proposals;
REVOKE ALL ON FUNCTION public._merchant_select_gp_plan_before_proposals(uuid) FROM PUBLIC, anon, authenticated;
CREATE FUNCTION public.merchant_select_gp_plan(p_plan_id uuid) RETURNS jsonb
LANGUAGE plpgsql SECURITY DEFINER SET search_path = public AS $$
DECLARE v_profile public.profiles%ROWTYPE; v_result jsonb;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'not_authenticated'; END IF;
  SELECT * INTO v_profile FROM public.profiles WHERE id=auth.uid() FOR UPDATE;
  IF NOT FOUND OR v_profile.role <> 'merchant' THEN RAISE EXCEPTION 'not_merchant'; END IF;
  IF v_profile.gp_proposal_status='pending' THEN RAISE EXCEPTION 'gp_proposal_already_submitted'; END IF;
  IF v_profile.gp_proposal_status='approved' AND v_profile.approval_status IS DISTINCT FROM 'approved' THEN RAISE EXCEPTION 'gp_proposal_already_submitted'; END IF;
  PERFORM set_config('app.allow_gp_proposal_update','on',true);
  v_result := public._merchant_select_gp_plan_before_proposals(p_plan_id);
  IF v_profile.gp_proposal_id IS NOT NULL AND v_profile.approval_status IS DISTINCT FROM 'approved' THEN
    UPDATE public.merchant_gp_proposals SET status='superseded' WHERE id=v_profile.gp_proposal_id;
    UPDATE public.profiles SET gp_proposal_id=NULL,gp_proposal_status=NULL WHERE id=auth.uid();
  END IF;
  PERFORM set_config('app.allow_gp_proposal_update','',true);
  RETURN v_result;
END $$;
REVOKE ALL ON FUNCTION public.merchant_submit_gp_proposal(numeric,numeric,numeric,numeric,text) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.admin_review_gp_proposal(uuid,text,text,numeric,numeric) FROM PUBLIC,anon;
REVOKE ALL ON FUNCTION public.merchant_select_gp_plan(uuid) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.merchant_submit_gp_proposal(numeric,numeric,numeric,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.admin_review_gp_proposal(uuid,text,text,numeric,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.merchant_select_gp_plan(uuid) TO authenticated;
COMMIT;
