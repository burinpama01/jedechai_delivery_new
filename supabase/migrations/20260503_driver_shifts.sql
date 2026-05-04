-- Sprint 4.2: Driver Shifts
-- Tracks each driver's working session with earnings and job counts.

CREATE TABLE IF NOT EXISTS driver_shifts (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id       uuid NOT NULL REFERENCES profiles(id) ON DELETE CASCADE,
  shift_start_at  timestamptz NOT NULL,
  shift_end_at    timestamptz,
  total_earnings  decimal(10,2) DEFAULT 0,
  total_jobs      integer DEFAULT 0,
  created_at      timestamptz DEFAULT now()
);

-- ────────────────────────────────────────────────────────────────────────────
-- RLS
-- ────────────────────────────────────────────────────────────────────────────
ALTER TABLE driver_shifts ENABLE ROW LEVEL SECURITY;

-- Drivers can manage only their own shifts
CREATE POLICY driver_shifts_insert ON driver_shifts
  FOR INSERT
  WITH CHECK (
    driver_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'driver'
    )
  );

CREATE POLICY driver_shifts_select ON driver_shifts
  FOR SELECT
  USING (
    driver_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'driver'
    )
  );

CREATE POLICY driver_shifts_update ON driver_shifts
  FOR UPDATE
  USING (
    driver_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'driver'
    )
  )
  WITH CHECK (
    driver_id = auth.uid()
    AND EXISTS (
      SELECT 1 FROM profiles WHERE id = auth.uid() AND role = 'driver'
    )
  );

-- ────────────────────────────────────────────────────────────────────────────
-- Index
-- ────────────────────────────────────────────────────────────────────────────
CREATE INDEX IF NOT EXISTS idx_driver_shifts_driver_start
  ON driver_shifts (driver_id, shift_start_at DESC);
