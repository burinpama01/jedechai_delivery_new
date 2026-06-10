-- App update alert policy for optional and force update guardrails.
-- Default is disabled so deploys never block users until admin opts in.

ALTER TABLE IF EXISTS public.system_config
  ADD COLUMN IF NOT EXISTS app_update_policy jsonb;

ALTER TABLE IF EXISTS public.system_config
  ALTER COLUMN app_update_policy SET DEFAULT '{
    "enabled": false,
    "mode": "optional",
    "latest_version": null,
    "latest_build": null,
    "min_supported_version": null,
    "min_supported_build": null,
    "title_th": "มีเวอร์ชันใหม่",
    "message_th": "กรุณาอัปเดตแอปเพื่อใช้งานฟีเจอร์ล่าสุด",
    "android_url": "",
    "ios_url": "",
    "target_roles": [],
    "starts_at": null,
    "ends_at": null
  }'::jsonb;

UPDATE public.system_config
SET app_update_policy = '{
  "enabled": false,
  "mode": "optional",
  "latest_version": null,
  "latest_build": null,
  "min_supported_version": null,
  "min_supported_build": null,
  "title_th": "มีเวอร์ชันใหม่",
  "message_th": "กรุณาอัปเดตแอปเพื่อใช้งานฟีเจอร์ล่าสุด",
  "android_url": "",
  "ios_url": "",
  "target_roles": [],
  "starts_at": null,
  "ends_at": null
}'::jsonb
WHERE app_update_policy IS NULL;

ALTER TABLE IF EXISTS public.system_config
  ALTER COLUMN app_update_policy SET NOT NULL;

COMMENT ON COLUMN public.system_config.app_update_policy IS
  'JSON policy for mobile app optional/force update alerts. Disabled by default.';
