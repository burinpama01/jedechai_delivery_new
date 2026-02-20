-- ============================================================
-- Scheduled Order Automation Smoke Test
-- Target: process-scheduled-orders Edge Function + cron markers
-- ============================================================
-- Usage:
-- 1) Run each block in Supabase SQL Editor
-- 2) Execute Edge Function manually between steps
-- 3) Re-run verification queries

-- ------------------------------------------------------------
-- A) Timezone sanity check (after you fixed time mismatch)
-- ------------------------------------------------------------
select
  now() as db_now_utc,
  now() at time zone 'Asia/Bangkok' as db_now_bangkok,
  current_setting('TimeZone', true) as db_timezone;

-- ------------------------------------------------------------
-- B) Find candidate bookings for reminder window
-- ------------------------------------------------------------
select
  id,
  service_type,
  status,
  scheduled_at,
  scheduled_at at time zone 'Asia/Bangkok' as scheduled_at_bangkok,
  scheduled_reminder_sent_at,
  scheduled_release_processed_at
from public.bookings
where scheduled_at is not null
  and status in ('pending', 'pending_merchant', 'preparing')
  and scheduled_at >= now()
  and scheduled_at <= now() + interval '15 minutes'
order by scheduled_at asc
limit 50;

-- ------------------------------------------------------------
-- C) Find candidate bookings for release window
-- ------------------------------------------------------------
select
  id,
  service_type,
  status,
  scheduled_at,
  scheduled_at at time zone 'Asia/Bangkok' as scheduled_at_bangkok,
  scheduled_reminder_sent_at,
  scheduled_release_processed_at
from public.bookings
where scheduled_at is not null
  and status in ('pending', 'pending_merchant', 'preparing')
  and scheduled_at <= now()
order by scheduled_at asc
limit 50;

-- ------------------------------------------------------------
-- D) Verify notifications inserted by scheduler
-- ------------------------------------------------------------
select
  n.id,
  n.user_id,
  n.type,
  n.title,
  n.created_at,
  n.created_at at time zone 'Asia/Bangkok' as created_at_bangkok,
  n.data
from public.notifications n
where n.type in ('scheduled_order_reminder', 'scheduled_order_released')
order by n.created_at desc
limit 100;

-- ------------------------------------------------------------
-- E) Verify booking marker columns were updated
-- ------------------------------------------------------------
select
  b.id,
  b.service_type,
  b.status,
  b.scheduled_at,
  b.scheduled_reminder_sent_at,
  b.scheduled_release_processed_at,
  b.updated_at
from public.bookings b
where b.scheduled_at is not null
  and (b.scheduled_reminder_sent_at is not null or b.scheduled_release_processed_at is not null)
order by b.updated_at desc
limit 100;

-- ------------------------------------------------------------
-- F) Idempotency quick check (no duplicate burst)
-- ------------------------------------------------------------
-- Run function 2-3 times, then check same booking + type count.
select
  (n.data ->> 'booking_id') as booking_id,
  n.type,
  count(*) as total_rows,
  min(n.created_at) as first_at,
  max(n.created_at) as last_at
from public.notifications n
where n.type in ('scheduled_order_reminder', 'scheduled_order_released')
  and n.created_at >= now() - interval '1 day'
group by (n.data ->> 'booking_id'), n.type
having count(*) > 1
order by total_rows desc, last_at desc
limit 100;

-- If query above returns rows, inspect the listed booking IDs.
-- Some duplicates may be expected only if business intentionally re-notifies,
-- but current scheduler design should generally create one row/type/booking.

-- ------------------------------------------------------------
-- G) Cron health check (if pg_cron migration is enabled)
-- ------------------------------------------------------------
select jobid, jobname, schedule, active
from cron.job
where jobname = 'process-scheduled-orders-every-minute';

select
  jobid,
  status,
  return_message,
  start_time,
  end_time
from cron.job_run_details
where jobid in (
  select jobid from cron.job where jobname = 'process-scheduled-orders-every-minute'
)
order by start_time desc
limit 50;
