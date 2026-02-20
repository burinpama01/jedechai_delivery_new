-- เพิ่มคอลัมน์อีเมลแจ้งเตือนใน system_config
ALTER TABLE system_config ADD COLUMN IF NOT EXISTS admin_notification_email TEXT;
ALTER TABLE system_config ADD COLUMN IF NOT EXISTS admin_notification_email_cc TEXT;
