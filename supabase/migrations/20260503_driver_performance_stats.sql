-- Sprint 4.1: Driver Performance Stats
-- Adds aggregated performance columns to profiles and a trigger to keep them current.

ALTER TABLE profiles ADD COLUMN IF NOT EXISTS total_completed_jobs integer DEFAULT 0;
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS acceptance_rate decimal(5,2);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS completion_rate decimal(5,2);
ALTER TABLE profiles ADD COLUMN IF NOT EXISTS average_rating decimal(3,2);

-- ────────────────────────────────────────────────────────────────────────────
-- Function: recompute stats for one driver from bookings + reviews
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_driver_performance_stats(p_driver_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_total_assigned   integer;
  v_total_accepted   integer;
  v_total_completed  integer;
  v_avg_rating       decimal(3,2);
BEGIN
  -- Jobs assigned to this driver (pending + any terminal state)
  SELECT COUNT(*)
    INTO v_total_assigned
    FROM bookings
   WHERE driver_id = p_driver_id;

  -- Jobs the driver accepted (moved out of pending)
  SELECT COUNT(*)
    INTO v_total_accepted
    FROM bookings
   WHERE driver_id = p_driver_id
     AND status NOT IN ('pending', 'pending_merchant', 'cancelled');

  -- Jobs completed
  SELECT COUNT(*)
    INTO v_total_completed
    FROM bookings
   WHERE driver_id = p_driver_id
     AND status = 'completed';

  -- Average rating from reviews table (if it exists)
  SELECT ROUND(AVG(rating)::numeric, 2)
    INTO v_avg_rating
    FROM reviews
   WHERE driver_id = p_driver_id;

  UPDATE profiles
     SET total_completed_jobs = v_total_completed,
         acceptance_rate = CASE
                             WHEN v_total_assigned > 0
                             THEN ROUND((v_total_accepted::decimal / v_total_assigned) * 100, 2)
                             ELSE NULL
                           END,
         completion_rate = CASE
                             WHEN v_total_accepted > 0
                             THEN ROUND((v_total_completed::decimal / v_total_accepted) * 100, 2)
                             ELSE NULL
                           END,
         average_rating  = v_avg_rating
   WHERE id = p_driver_id;
END;
$$;

-- ────────────────────────────────────────────────────────────────────────────
-- Trigger: fire after a booking reaches 'completed'
-- ────────────────────────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION _trigger_update_driver_performance_stats()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  IF NEW.status = 'completed' AND NEW.driver_id IS NOT NULL THEN
    PERFORM update_driver_performance_stats(NEW.driver_id);
  END IF;
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_driver_performance_stats ON bookings;

CREATE TRIGGER trg_driver_performance_stats
  AFTER UPDATE OF status ON bookings
  FOR EACH ROW
  EXECUTE FUNCTION _trigger_update_driver_performance_stats();
