ALTER TABLE IF EXISTS public.pos_connections
  ALTER COLUMN merchant_id DROP NOT NULL;

DROP INDEX IF EXISTS public.uq_pos_connections_system_provider;

WITH ranked AS (
  SELECT
    id,
    row_number() OVER (
      PARTITION BY provider
      ORDER BY
        CASE WHEN status = 'active' THEN 0 ELSE 1 END,
        updated_at DESC NULLS LAST,
        created_at DESC NULLS LAST,
        id DESC
    ) AS rn
  FROM public.pos_connections
  WHERE provider = 'storeos'
    AND status IN ('active', 'pending')
)
UPDATE public.pos_connections pc
SET
  merchant_id = NULL,
  storeos_shop_id = NULL,
  updated_at = now()
FROM ranked
WHERE ranked.id = pc.id
  AND ranked.rn = 1
  AND pc.status IN ('active', 'pending');

WITH ranked AS (
  SELECT
    id,
    row_number() OVER (
      PARTITION BY provider
      ORDER BY
        CASE WHEN status = 'active' THEN 0 ELSE 1 END,
        updated_at DESC NULLS LAST,
        created_at DESC NULLS LAST,
        id DESC
    ) AS rn
  FROM public.pos_connections
  WHERE provider = 'storeos'
    AND status IN ('active', 'pending')
)
UPDATE public.pos_connections pc
SET
  status = 'active',
  updated_at = now()
FROM ranked
WHERE ranked.id = pc.id
  AND ranked.rn = 1
  AND pc.status = 'pending';

WITH ranked AS (
  SELECT
    id,
    row_number() OVER (
      PARTITION BY provider
      ORDER BY updated_at DESC NULLS LAST, created_at DESC NULLS LAST, id DESC
    ) AS rn
  FROM public.pos_connections
  WHERE provider = 'storeos'
    AND status IN ('active', 'pending')
)
UPDATE public.pos_connections pc
SET
  status = 'revoked',
  updated_at = now()
FROM ranked
WHERE ranked.id = pc.id
  AND ranked.rn > 1
  AND pc.status <> 'revoked';

DROP INDEX IF EXISTS public.uq_pos_connections_merchant_provider;

CREATE UNIQUE INDEX IF NOT EXISTS uq_pos_connections_system_provider
  ON public.pos_connections (provider)
  WHERE merchant_id IS NULL AND status = 'active';

CREATE UNIQUE INDEX IF NOT EXISTS uq_pos_connections_merchant_provider
  ON public.pos_connections (merchant_id, provider)
  WHERE merchant_id IS NOT NULL;

COMMENT ON TABLE public.pos_connections IS
  'Private POS integration credentials. StoreOS uses one system connection and sends JDC merchant_id per shop payload.';

CREATE OR REPLACE FUNCTION public.notify_storeos_order()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_conn public.pos_connections%ROWTYPE;
  v_body jsonb;
  v_sig text;
  v_topic text;
  v_timestamp text;
  v_event_id text;
BEGIN
  IF NEW.service_type <> 'food' THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE' AND NEW.status IS NOT DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'UPDATE'
     AND NEW.status_origin = 'storeos'
     AND NEW.status IS DISTINCT FROM OLD.status THEN
    RETURN NEW;
  END IF;

  SELECT *
    INTO v_conn
    FROM public.pos_connections
   WHERE merchant_id IS NULL
     AND provider = 'storeos'
     AND status = 'active'
     AND storeos_webhook_url IS NOT NULL
   LIMIT 1;

  IF NOT FOUND THEN
    RETURN NEW;
  END IF;

  v_topic := CASE WHEN TG_OP = 'INSERT' THEN 'order.created' ELSE 'order.status' END;
  v_timestamp := extract(epoch FROM now())::bigint::text;
  v_event_id := gen_random_uuid()::text;
  v_body := jsonb_build_object(
    'topic', v_topic,
    'event_id', v_event_id,
    'booking_id', NEW.id,
    'merchant_id', NEW.merchant_id,
    'status', NEW.status,
    'total', NEW.price,
    'paid', true,
    'ts', v_timestamp
  );
  v_sig := encode(
    hmac(convert_to(v_body::text, 'UTF8'), convert_to(v_conn.webhook_secret, 'UTF8'), 'sha256'),
    'hex'
  );

  PERFORM net.http_post(
    url := v_conn.storeos_webhook_url,
    headers := jsonb_build_object(
      'Content-Type', 'application/json',
      'X-JDC-Connection-Key', v_conn.jdc_connection_key,
      'X-Connect-Event-Id', v_event_id,
      'X-Connect-Timestamp', v_timestamp,
      'X-Connect-Signature', 'sha256=' || v_sig
    ),
    body := v_body
  );

  RETURN NEW;
END;
$$;
