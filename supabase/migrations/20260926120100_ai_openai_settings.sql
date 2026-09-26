-- ตั้งค่า OpenAI จากหน้า Settings ของ admin-web (ต่อจาก 20260926120000_ai_menu_import_v1)
--
-- - API key เก็บใน Supabase Vault (vault.secrets name = 'ai_openai_api_key') ไม่ลง system_config
-- - แอดมิน "เขียนได้อย่างเดียว": เห็นแค่ว่าตั้งแล้ว + 4 ตัวท้าย ไม่มี RPC ไหนคืนคีย์เต็มให้ client
-- - Edge Function อ่านคีย์ผ่าน ai_get_openai_config() ซึ่ง grant ให้ service_role เท่านั้น
--   (ถ้าตั้ง secret OPENAI_API_KEY ของ function ไว้ จะใช้ค่านั้นก่อน)
-- - model + ราคา/ล้าน token อยู่ใน system_config (ไม่ใช่ความลับ)
--
-- Rollback: drop functions admin_set_openai_api_key, admin_get_ai_settings,
--   admin_ai_cost_summary, ai_get_openai_config; DELETE FROM vault.secrets WHERE name='ai_openai_api_key'

INSERT INTO public.system_config (key, value)
VALUES
  ('ai_openai_model', ''),
  ('ai_openai_price_input_per_mtok', ''),
  ('ai_openai_price_output_per_mtok', '')
ON CONFLICT (key) WHERE key IS NOT NULL DO NOTHING;

-- ตั้ง/เปลี่ยน/ลบ (ส่งค่าว่าง) API key — แอดมินเท่านั้น
CREATE OR REPLACE FUNCTION public.admin_set_openai_api_key(p_api_key text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_key text := btrim(coalesce(p_api_key, ''));
  v_id uuid;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;

  SELECT id INTO v_id FROM vault.secrets WHERE name = 'ai_openai_api_key';

  IF v_key = '' THEN
    IF v_id IS NOT NULL THEN
      DELETE FROM vault.secrets WHERE id = v_id;
    END IF;
  ELSE
    IF length(v_key) < 20 OR length(v_key) > 300 OR v_key !~ '^sk-[A-Za-z0-9_\-]+$' THEN
      RAISE EXCEPTION 'invalid_openai_key_format';
    END IF;
    IF v_id IS NULL THEN
      PERFORM vault.create_secret(v_key, 'ai_openai_api_key', 'OpenAI API key (ตั้งจาก admin-web Settings)');
    ELSE
      PERFORM vault.update_secret(v_id, v_key);
    END IF;
  END IF;

  -- บันทึกแค่ว่าเปลี่ยน + 4 ตัวท้าย ห้ามบันทึกคีย์
  INSERT INTO public.admin_audit_logs (admin_user_id, action_type, target_type, details)
  VALUES (auth.uid(), CASE WHEN v_key = '' THEN 'clear_openai_key' ELSE 'set_openai_key' END,
          'ai_settings',
          jsonb_build_object('key_hint', CASE WHEN v_key = '' THEN NULL ELSE right(v_key, 4) END));

  RETURN public.admin_get_ai_settings();
END;
$$;

-- สถานะการตั้งค่า (ไม่คืนคีย์เต็ม)
CREATE OR REPLACE FUNCTION public.admin_get_ai_settings()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_secret record;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  SELECT decrypted_secret, updated_at INTO v_secret
  FROM vault.decrypted_secrets WHERE name = 'ai_openai_api_key';
  RETURN jsonb_build_object(
    'key_set', v_secret.decrypted_secret IS NOT NULL AND v_secret.decrypted_secret <> '',
    'key_hint', CASE WHEN v_secret.decrypted_secret IS NULL THEN NULL
                     ELSE '…' || right(v_secret.decrypted_secret, 4) END,
    'key_updated_at', v_secret.updated_at,
    'model', public.ai_import_cfg('ai_openai_model', ''),
    'price_input_per_mtok', public.ai_import_cfg('ai_openai_price_input_per_mtok', ''),
    'price_output_per_mtok', public.ai_import_cfg('ai_openai_price_output_per_mtok', ''));
END;
$$;

-- ค่าใช้จ่าย AI (คิดจากราคาที่ตั้งไว้ ณ เวลาที่เรียก) — แอดมินเท่านั้น
CREATE OR REPLACE FUNCTION public.admin_ai_cost_summary()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_today timestamptz := (date_trunc('day', now() AT TIME ZONE 'Asia/Bangkok') AT TIME ZONE 'Asia/Bangkok');
  v_month timestamptz := (date_trunc('month', now() AT TIME ZONE 'Asia/Bangkok') AT TIME ZONE 'Asia/Bangkok');
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'forbidden';
  END IF;
  RETURN (
    SELECT jsonb_object_agg(bucket, stats) FROM (
      SELECT b.bucket, jsonb_build_object(
               'calls', count(r.id),
               'errors', count(r.id) FILTER (WHERE r.status <> 'ok'),
               'input_tokens', coalesce(sum(r.input_tokens), 0),
               'output_tokens', coalesce(sum(r.output_tokens), 0),
               'cost_usd', round(coalesce(sum(r.estimated_cost_usd), 0), 4),
               'unpriced_calls', count(r.id) FILTER (WHERE r.status = 'ok' AND r.estimated_cost_usd IS NULL),
               'jobs', count(DISTINCT r.import_job_id)) AS stats
      FROM (VALUES ('today', v_today), ('month', v_month),
                   ('last_30_days', now() - interval '30 days')) AS b(bucket, since)
      LEFT JOIN public.ai_runs r ON r.created_at >= b.since
      GROUP BY b.bucket
    ) s);
END;
$$;

-- สำหรับ Edge Function เท่านั้น (service_role)
CREATE OR REPLACE FUNCTION public.ai_get_openai_config()
RETURNS jsonb
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public
AS $$
  SELECT jsonb_build_object(
    'api_key', (SELECT decrypted_secret FROM vault.decrypted_secrets WHERE name = 'ai_openai_api_key'),
    'model', public.ai_import_cfg('ai_openai_model', ''),
    'price_input_per_mtok', public.ai_import_cfg('ai_openai_price_input_per_mtok', ''),
    'price_output_per_mtok', public.ai_import_cfg('ai_openai_price_output_per_mtok', ''));
$$;

REVOKE ALL ON FUNCTION public.admin_set_openai_api_key(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_set_openai_api_key(text) TO authenticated;
REVOKE ALL ON FUNCTION public.admin_get_ai_settings() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_ai_settings() TO authenticated;
REVOKE ALL ON FUNCTION public.admin_ai_cost_summary() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_ai_cost_summary() TO authenticated;
REVOKE ALL ON FUNCTION public.ai_get_openai_config() FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.ai_get_openai_config() TO service_role;
