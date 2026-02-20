-- ============================================================
-- Fix: driver_activity_logs INSERT blocked by RLS (42501)
-- ============================================================
-- Problem:
--   Updating driver online status can trigger INSERT into
--   public.driver_activity_logs, but INSERT fails with RLS.
--
-- Approach:
--   Add an idempotent INSERT policy that allows authenticated
--   users to insert activity logs. This unblocks online toggle
--   while keeping table protected by RLS for unauthenticated access.
-- ============================================================

DO $$
DECLARE
  has_table boolean;
BEGIN
  SELECT EXISTS (
    SELECT 1
    FROM information_schema.tables
    WHERE table_schema = 'public'
      AND table_name = 'driver_activity_logs'
  ) INTO has_table;

  IF NOT has_table THEN
    RAISE NOTICE 'driver_activity_logs table not found, skipping';
    RETURN;
  END IF;

  EXECUTE 'ALTER TABLE public.driver_activity_logs ENABLE ROW LEVEL SECURITY';

  IF NOT EXISTS (
    SELECT 1
    FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'driver_activity_logs'
      AND policyname = 'driver_activity_logs_insert_authenticated'
  ) THEN
    EXECUTE '
      CREATE POLICY "driver_activity_logs_insert_authenticated"
      ON public.driver_activity_logs
      FOR INSERT
      TO authenticated
      WITH CHECK (auth.uid() IS NOT NULL)
    ';
  END IF;
END $$;
