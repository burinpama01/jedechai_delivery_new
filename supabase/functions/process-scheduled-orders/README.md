# process-scheduled-orders

Edge Function สำหรับ automation งานนัดหมาย (Scheduled Order)

## ความสามารถ

ฟังก์ชันนี้ทำงานแบบ idempotent และแบ่ง 2 ช่วง:

1. **Reminder Window** (ค่าเริ่มต้น 15 นาทีล่วงหน้า)
   - หา booking ที่ `scheduled_at` อยู่ในช่วง `now .. now+15m`
   - ยังไม่เคยส่ง reminder (`scheduled_reminder_sent_at IS NULL`)
   - insert notification ลงตาราง `notifications`
   - mark `scheduled_reminder_sent_at`

2. **Release Window** (ถึงเวลานัดแล้ว)
   - หา booking ที่ `scheduled_at <= now`
   - ยังไม่เคย release (`scheduled_release_processed_at IS NULL`)
   - insert notification ลง `notifications`
   - สำหรับ ride/parcel จะแจ้งคนขับออนไลน์
   - mark `scheduled_release_processed_at`

> หมายเหตุ: เวอร์ชันนี้เน้น in-app notifications ผ่านตาราง `notifications` เป็นหลัก

---

## Secrets ที่ต้องตั้ง

```bash
supabase secrets set SCHEDULED_ORDER_CRON_SECRET=replace_with_strong_secret
supabase secrets set SCHEDULED_REMINDER_WINDOW_MINUTES=15
```

`SUPABASE_URL` และ `SUPABASE_SERVICE_ROLE_KEY` จะถูกใช้จาก environment ของ Supabase Edge Functions

---

## Deploy

```bash
supabase functions deploy process-scheduled-orders
```

---

## เรียกใช้งาน (Manual test)

```bash
curl -X POST "https://<PROJECT-REF>.supabase.co/functions/v1/process-scheduled-orders" \
  -H "Content-Type: application/json" \
  -H "x-scheduler-secret: <SCHEDULED_ORDER_CRON_SECRET>"
```

PowerShell (Windows):

```powershell
Invoke-RestMethod -Method Post `
  -Uri "https://<PROJECT-REF>.supabase.co/functions/v1/process-scheduled-orders" `
  -Headers @{ "x-scheduler-secret" = "<SCHEDULED_ORDER_CRON_SECRET>"; "Content-Type" = "application/json" }
```

หรือเรียกด้วย service-role bearer token:

```bash
curl -X POST "https://<PROJECT-REF>.supabase.co/functions/v1/process-scheduled-orders" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <SUPABASE_SERVICE_ROLE_KEY>"
```

PowerShell (Windows):

```powershell
Invoke-RestMethod -Method Post `
  -Uri "https://<PROJECT-REF>.supabase.co/functions/v1/process-scheduled-orders" `
  -Headers @{ "Authorization" = "Bearer <SUPABASE_SERVICE_ROLE_KEY>"; "Content-Type" = "application/json" }
```

Expected response:

```json
{
  "success": true,
  "now": "...",
  "result": {
    "remindersScanned": 0,
    "remindersMarked": 0,
    "releasesScanned": 0,
    "releasesMarked": 0,
    "notificationsInserted": 0
  }
}
```

---

## ตั้ง scheduler (ตัวอย่าง)

### แบบที่ 1: ใช้ migration ตั้ง `pg_cron` (แนะนำ)

เพิ่ม migration นี้แล้วรันตามปกติ:

- `supabase/migrations/20260304_schedule_process_scheduled_orders_cron.sql`

migration จะพยายามอ่าน:

- `app.settings.supabase_url`
- `app.settings.service_role_key`

จากนั้นจะ schedule job `process-scheduled-orders-every-minute` ให้ยิงทุก 1 นาทีแบบ idempotent

### แบบที่ 2: External scheduler

สามารถตั้ง scheduler ภายนอก (GitHub Actions / Cloud Scheduler / cron server) ให้ยิงทุก 1 นาที

- Method: `POST`
- URL: `https://<PROJECT-REF>.supabase.co/functions/v1/process-scheduled-orders`
- Header: `x-scheduler-secret: <SCHEDULED_ORDER_CRON_SECRET>`

---

## ตรวจสอบหลัง deploy (Verification)

ก่อนรัน smoke test ให้แน่ใจว่า migration dependency ถูก apply แล้ว:

- `20260305_create_notifications_table.sql`

สามารถใช้สคริปต์สำเร็จรูปได้ที่:

- `supabase/functions/process-scheduled-orders/SMOKE_TEST.sql`

Flow แนะนำหลังแก้ปัญหาเวลา:

1. รัน Block A ตรวจ timezone
2. ยิง function 1 รอบ
3. รัน Block B-E เพื่อตรวจ reminder/release + marker
4. ยิง function ซ้ำ 1-2 รอบ แล้วรัน Block F ตรวจ idempotency
5. รัน Block G ตรวจ cron health

### 1) ตรวจว่า cron job ถูกสร้างแล้ว

```sql
select jobid, jobname, schedule, command
from cron.job
where jobname = 'process-scheduled-orders-every-minute';
```

Expected: ได้ 1 แถว และ `schedule = '* * * * *'`

### 2) ดูประวัติการรันล่าสุด

```sql
select jobid, status, return_message, start_time, end_time
from cron.job_run_details
where jobid in (
  select jobid from cron.job where jobname = 'process-scheduled-orders-every-minute'
)
order by start_time desc
limit 20;
```

Expected: status เป็น `succeeded` เป็นหลัก

### 3) ทดสอบ function โดยตรง

```bash
curl -X POST "https://<PROJECT-REF>.supabase.co/functions/v1/process-scheduled-orders" \
  -H "Content-Type: application/json" \
  -H "x-scheduler-secret: <SCHEDULED_ORDER_CRON_SECRET>"
```

Expected: ได้ `{"success": true, ...}`

---

## Troubleshooting

### อาการ: migration แจ้ง `Skipping cron schedule: app.settings.supabase_url or app.settings.service_role_key not available`

ความหมาย: environment ของ Postgres ยังไม่มีค่า custom settings ทั้งสองตัว

ทางเลือกแก้ไข:

1. ตั้งค่า `app.settings.supabase_url` และ `app.settings.service_role_key` ใน environment ของ DB แล้วรัน migration นี้ใหม่
2. ใช้ **External scheduler** ชั่วคราว (GitHub Actions / Cloud Scheduler) ตามหัวข้อด้านบน

### อาการ: job มีแต่ status fail

ให้ตรวจ:

1. URL function ถูกต้อง (`/functions/v1/process-scheduled-orders`)
2. Token/Secret ตรงกับฝั่ง function
3. Function deploy แล้ว (`supabase functions deploy process-scheduled-orders`)

---

## Rollback เฉพาะ scheduler job

```sql
do $$
declare
  v_job_id integer;
begin
  for v_job_id in
    select jobid from cron.job where jobname = 'process-scheduled-orders-every-minute'
  loop
    perform cron.unschedule(v_job_id);
  end loop;
end
$$;
```

