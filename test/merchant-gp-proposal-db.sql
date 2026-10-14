\set ON_ERROR_STOP on
-- ฐานข้อมูล fixture แยก ไม่มีข้อมูลจริง ห้ามรันบน production
DO $$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='authenticated') THEN CREATE ROLE authenticated NOLOGIN; END IF; END $$;
DO $$ BEGIN IF NOT EXISTS(SELECT 1 FROM pg_roles WHERE rolname='anon') THEN CREATE ROLE anon NOLOGIN; END IF; END $$;
CREATE SCHEMA auth;
CREATE FUNCTION auth.uid() RETURNS uuid LANGUAGE sql STABLE AS $$
 SELECT nullif(current_setting('request.jwt.claim.sub', true),'')::uuid $$;
CREATE TABLE public.profiles(id uuid PRIMARY KEY, role text, approval_status text DEFAULT 'pending',
 merchant_service_types text[], gp_rate numeric DEFAULT 0.2, merchant_gp_system_rate numeric,
 merchant_gp_driver_rate numeric, custom_base_fare numeric, custom_base_distance numeric,
 custom_per_km numeric, custom_delivery_fee numeric, updated_at timestamptz);
CREATE TABLE public.bookings(id uuid PRIMARY KEY,merchant_id uuid,status text);
CREATE FUNCTION public.is_admin() RETURNS boolean LANGUAGE sql STABLE SECURITY DEFINER AS $$
 SELECT EXISTS(SELECT 1 FROM profiles WHERE id=auth.uid() AND role='admin') $$;
GRANT USAGE ON SCHEMA public,auth TO authenticated,anon;
GRANT SELECT,UPDATE ON profiles TO authenticated;
GRANT SELECT ON bookings TO authenticated;
ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY self_read ON profiles FOR SELECT TO authenticated USING(id=auth.uid() OR public.is_admin());
CREATE POLICY self_update ON profiles FOR UPDATE TO authenticated USING(id=auth.uid() OR public.is_admin());
INSERT INTO profiles(id,role,merchant_service_types) VALUES
 ('00000000-0000-0000-0000-000000000001','merchant',ARRAY['food']),
 ('00000000-0000-0000-0000-000000000002','merchant',ARRAY['food']),
 ('00000000-0000-0000-0000-000000000003','admin',NULL),
 ('00000000-0000-0000-0000-000000000004','merchant',ARRAY['laundry']);
\i /work/supabase/migrations/20260716090000_gp_plans_merchant_stage1.sql
\i /work/supabase/migrations/20260919235000_gp_plan_self_change_cooldown.sql
\i /work/supabase/migrations/20260930120000_merchant_gp_proposals.sql
GRANT SELECT ON gp_plans TO authenticated;
CREATE FUNCTION test_assert(ok boolean,message text) RETURNS void LANGUAGE plpgsql AS $$
 BEGIN IF ok IS DISTINCT FROM true THEN RAISE EXCEPTION 'ASSERT: %',message; END IF; END $$;
CREATE FUNCTION test_error(statement text,expected text) RETURNS void LANGUAGE plpgsql AS $$
 BEGIN BEGIN EXECUTE statement; EXCEPTION WHEN OTHERS THEN
 IF position(expected IN SQLERRM)>0 THEN RETURN; ELSE RAISE; END IF;
 END; RAISE EXCEPTION 'Expected error: %',expected; END $$;
SET ROLE authenticated;
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
SELECT test_error($q$ SELECT merchant_submit_gp_proposal('NaN',10,5,3,'') $q$,'invalid_gp_proposal');
SELECT test_error($q$ SELECT merchant_submit_gp_proposal(0.1,-1,5,3,'') $q$,'invalid_gp_proposal');
SELECT merchant_submit_gp_proposal(0.1,10,5,3,'เสนอค่าส่ง');
SELECT test_assert((SELECT gp_rate=0.2 AND gp_proposal_status='pending' FROM profiles WHERE id=auth.uid()),'pending rates unchanged');
SELECT test_assert((SELECT count(*)=1 FROM merchant_gp_proposals),'owner reads own');
SELECT test_error($q$ SELECT merchant_submit_gp_proposal(0.1,10,5,3,'') $q$,'gp_proposal_already_submitted');
SELECT test_error($q$ SELECT merchant_select_gp_plan('a1000000-0000-4000-8000-000000000001') $q$,'gp_proposal_already_submitted');
SELECT test_error($q$ UPDATE profiles SET approval_status='approved' WHERE id=auth.uid() $q$,'gp_proposal_pending');
SELECT test_error($q$ UPDATE profiles SET gp_proposal_status='approved' WHERE id=auth.uid() $q$,'gp_proposal_metadata_rpc_only');
SELECT test_error($q$ SELECT admin_review_gp_proposal((SELECT id FROM merchant_gp_proposals LIMIT 1),'approved','',0.1,0) $q$,'admin_required');
SELECT test_error($q$ UPDATE merchant_gp_proposals SET status='approved' $q$,'permission denied');
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',false);
SELECT test_assert((SELECT count(*)=0 FROM merchant_gp_proposals),'other owner cannot read');
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000004',false);
SELECT test_error($q$ SELECT merchant_submit_gp_proposal(0.1,10,5,3,'') $q$,'food_merchant_required');
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',false);
SELECT test_error($q$ SELECT admin_review_gp_proposal((SELECT id FROM merchant_gp_proposals LIMIT 1),'returned','') $q$,'gp_return_reason_required');
SELECT test_error($q$ SELECT admin_review_gp_proposal((SELECT id FROM merchant_gp_proposals LIMIT 1),'approved','',0.05,0.04) $q$,'gp_split_mismatch');
SELECT admin_review_gp_proposal((SELECT id FROM merchant_gp_proposals LIMIT 1),'returned','ปรับค่าส่ง');
SELECT test_error($q$ UPDATE profiles SET approval_status='approved' WHERE id='00000000-0000-0000-0000-000000000001' $q$,'gp_proposal_pending');
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
SELECT merchant_submit_gp_proposal(0.12,12,5,4,'เสนอใหม่');
SELECT test_assert((SELECT count(*)=2 FROM merchant_gp_proposals),'revision retained');
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',false);
SELECT test_error($q$ SELECT admin_review_gp_proposal((SELECT id FROM merchant_gp_proposals WHERE revision=1),'approved','',0.1,0) $q$,'gp_proposal_stale');
SELECT admin_review_gp_proposal((SELECT id FROM merchant_gp_proposals WHERE revision=2),'approved','',0.07,0.05);
SELECT test_assert((SELECT gp_rate=0.12 AND merchant_gp_system_rate=0.07 AND merchant_gp_driver_rate=0.05
 AND custom_base_fare=12 AND custom_base_distance=5 AND custom_per_km=4 AND approval_status='pending'
 AND gp_proposal_status='approved' FROM profiles WHERE id='00000000-0000-0000-0000-000000000001'),'approval writes rates but not store approval');
SELECT test_error($q$ SELECT admin_review_gp_proposal((SELECT id FROM merchant_gp_proposals WHERE revision=2),'approved','',0.07,0.05) $q$,'gp_proposal_stale');
UPDATE profiles SET custom_delivery_fee=99 WHERE id='00000000-0000-0000-0000-000000000001';
SELECT test_error($q$ UPDATE profiles SET approval_status='approved' WHERE id='00000000-0000-0000-0000-000000000001' $q$,'gp_proposal_rates_changed');
UPDATE profiles SET custom_delivery_fee=NULL WHERE id='00000000-0000-0000-0000-000000000001';
UPDATE profiles SET approval_status='approved' WHERE id='00000000-0000-0000-0000-000000000001';
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000001',false);
SELECT test_error($q$ SELECT merchant_submit_gp_proposal(0.1,10,5,3,'') $q$,'new_merchant_only');
SELECT test_error($q$ SELECT merchant_select_gp_plan('a1000000-0000-4000-8000-000000000001') $q$,'custom_deal_contact_admin');
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',false);
SELECT merchant_submit_gp_proposal(0.1,10,5,3,'');
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',false);
SELECT admin_review_gp_proposal((SELECT id FROM merchant_gp_proposals WHERE merchant_id='00000000-0000-0000-0000-000000000002'),'returned','เลือกแพ็กเกจแทนได้');
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000002',false);
SELECT merchant_select_gp_plan('a1000000-0000-4000-8000-000000000001');
SELECT test_assert((SELECT gp_proposal_id IS NULL AND gp_proposal_status IS NULL AND gp_plan_id IS NOT NULL FROM profiles WHERE id=auth.uid()),'returned to preset clears metadata');
SELECT test_assert((SELECT status='superseded' FROM merchant_gp_proposals WHERE merchant_id=auth.uid()),'preset preserves superseded history');
SELECT merchant_submit_gp_proposal(0.15,10,5,3,'decimal test');
SELECT set_config('request.jwt.claim.sub','00000000-0000-0000-0000-000000000003',false);
SELECT admin_review_gp_proposal((SELECT id FROM merchant_gp_proposals WHERE merchant_id='00000000-0000-0000-0000-000000000002' AND revision=2),'approved','',0.08199999999999999,0.068);
SELECT test_assert((SELECT merchant_gp_system_rate=0.082 AND merchant_gp_driver_rate=0.068 FROM profiles WHERE id='00000000-0000-0000-0000-000000000002'),'normalized decimal split');
RESET ROLE;
DELETE FROM profiles WHERE id='00000000-0000-0000-0000-000000000002';
SELECT test_assert((SELECT count(*)=0 FROM merchant_gp_proposals WHERE merchant_id='00000000-0000-0000-0000-000000000002'),'existing delete lifecycle is not blocked');
SELECT 'GP proposal fixture passed' AS result;
