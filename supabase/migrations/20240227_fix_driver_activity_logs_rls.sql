-- ============================================
-- Fix RLS for driver_activity_logs
-- ============================================
-- ปัญหา: มี trigger/logic ที่ INSERT ลง driver_activity_logs ตอนคนขับเปลี่ยนสถานะ
-- แต่ RLS ของตาราง driver_activity_logs ไม่อนุญาต ทำให้ update สถานะล้มเหลว (42501)
-- ============================================

DO $$
DECLARE
  has_table boolean;
  has_driver_id boolean;
  has_user_id boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM pg_class c
    JOIN pg_namespace n ON n.oid = c.relnamespace
    WHERE n.nspname = 'public'
      AND c.relname = 'driver_activity_logs'
      AND c.relkind = 'r'
  ) INTO has_table;

  IF NOT has_table THEN
    -- Table not found; nothing to do
    RETURN;
  END IF;

  -- Enable RLS
  EXECUTE 'ALTER TABLE public.driver_activity_logs ENABLE ROW LEVEL SECURITY';

  -- Detect common owner column names
  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'driver_activity_logs' AND column_name = 'driver_id'
  ) INTO has_driver_id;

  SELECT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_schema = 'public' AND table_name = 'driver_activity_logs' AND column_name = 'user_id'
  ) INTO has_user_id;

  -- INSERT policy: allow user to insert their own log rows
  IF has_driver_id THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'driver_activity_logs'
        AND policyname = 'driver_activity_logs_insert_own'
    ) THEN
      EXECUTE 'CREATE POLICY "driver_activity_logs_insert_own" ON public.driver_activity_logs FOR INSERT WITH CHECK (auth.uid() = driver_id)';
    END IF;
  ELSIF has_user_id THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'driver_activity_logs'
        AND policyname = 'driver_activity_logs_insert_own'
    ) THEN
      EXECUTE 'CREATE POLICY "driver_activity_logs_insert_own" ON public.driver_activity_logs FOR INSERT WITH CHECK (auth.uid() = user_id)';
    END IF;
  ELSE
    -- Fallback: allow authenticated users to insert (better than breaking online toggle)
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'driver_activity_logs'
        AND policyname = 'driver_activity_logs_insert_auth'
    ) THEN
      EXECUTE 'CREATE POLICY "driver_activity_logs_insert_auth" ON public.driver_activity_logs FOR INSERT WITH CHECK (auth.role() = ''authenticated'')';
    END IF;
  END IF;

  -- SELECT policy: allow admin to read everything
  IF NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'driver_activity_logs'
      AND policyname = 'driver_activity_logs_admin_read'
  ) THEN
    EXECUTE 'CREATE POLICY "driver_activity_logs_admin_read" ON public.driver_activity_logs FOR SELECT USING (EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = ''admin''))';
  END IF;

  -- SELECT policy: user can read own logs (optional)
  IF has_driver_id THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'driver_activity_logs'
        AND policyname = 'driver_activity_logs_select_own'
    ) THEN
      EXECUTE 'CREATE POLICY "driver_activity_logs_select_own" ON public.driver_activity_logs FOR SELECT USING (auth.uid() = driver_id)';
    END IF;
  ELSIF has_user_id THEN
    IF NOT EXISTS (
      SELECT 1 FROM pg_policies
      WHERE schemaname = 'public'
        AND tablename = 'driver_activity_logs'
        AND policyname = 'driver_activity_logs_select_own'
    ) THEN
      EXECUTE 'CREATE POLICY "driver_activity_logs_select_own" ON public.driver_activity_logs FOR SELECT USING (auth.uid() = user_id)';
    END IF;
  END IF;
END $$;
