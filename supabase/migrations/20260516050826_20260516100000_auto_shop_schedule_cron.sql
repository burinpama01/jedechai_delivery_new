select cron.schedule(
  'auto-shop-schedule',
  '*/5 * * * *',
  $$
  select
    net.http_post(
      url := current_setting('app.supabase_url') || '/functions/v1/auto-shop-schedule',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-cron-secret', current_setting('app.auto_shop_schedule_secret')
      ),
      body := '{}'::jsonb
    )
  $$
);;
