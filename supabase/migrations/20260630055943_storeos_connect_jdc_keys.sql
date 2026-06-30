CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE EXTENSION IF NOT EXISTS pg_net;

ALTER TABLE IF EXISTS public.menu_items
  ADD COLUMN IF NOT EXISTS external_ref text;

ALTER TABLE IF EXISTS public.menu_items
  ADD COLUMN IF NOT EXISTS source text NOT NULL DEFAULT 'jdc';

CREATE UNIQUE INDEX IF NOT EXISTS uq_menu_items_merchant_extref
  ON public.menu_items (merchant_id, external_ref)
  WHERE external_ref IS NOT NULL;

ALTER TABLE IF EXISTS public.bookings
  ADD COLUMN IF NOT EXISTS status_origin text;

ALTER TABLE IF EXISTS public.bookings
  ADD COLUMN IF NOT EXISTS pos_order_id text;

DO $$
BEGIN
  ALTER TABLE public.bookings
    ADD CONSTRAINT bookings_status_origin_check
    CHECK (status_origin IS NULL OR status_origin IN ('jdc', 'storeos'));
EXCEPTION
  WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS public.pos_connections (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  merchant_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  provider text NOT NULL DEFAULT 'storeos',
  status text NOT NULL DEFAULT 'pending',
  storeos_shop_id text,
  storeos_webhook_url text,
  jdc_connection_key text NOT NULL,
  webhook_secret text NOT NULL,
  menu_managed_by_pos boolean NOT NULL DEFAULT true,
  last_menu_sync_at timestamptz,
  last_status_sync_at timestamptz,
  key_rotated_at timestamptz NOT NULL DEFAULT now(),
  secret_rotated_at timestamptz NOT NULL DEFAULT now(),
  created_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  updated_by uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT pos_connections_provider_check
    CHECK (provider IN ('storeos')),
  CONSTRAINT pos_connections_status_check
    CHECK (status IN ('pending', 'active', 'disabled', 'revoked')),
  CONSTRAINT pos_connections_webhook_url_check
    CHECK (storeos_webhook_url IS NULL OR storeos_webhook_url ~* '^https://')
);

CREATE UNIQUE INDEX IF NOT EXISTS uq_pos_connections_system_provider
  ON public.pos_connections (provider)
  WHERE merchant_id IS NULL AND status = 'active';

CREATE UNIQUE INDEX IF NOT EXISTS uq_pos_connections_merchant_provider
  ON public.pos_connections (merchant_id, provider)
  WHERE merchant_id IS NOT NULL;

CREATE UNIQUE INDEX IF NOT EXISTS uq_pos_connections_jdc_key
  ON public.pos_connections (jdc_connection_key);

CREATE INDEX IF NOT EXISTS idx_pos_connections_merchant_status
  ON public.pos_connections (merchant_id, status);

ALTER TABLE public.pos_connections ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.pos_connections FROM anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.pos_connections TO service_role;

COMMENT ON TABLE public.pos_connections IS
  'Private POS integration credentials. StoreOS uses one system connection and sends JDC merchant_id per shop payload.';
COMMENT ON COLUMN public.pos_connections.jdc_connection_key IS
  'Public identifier StoreOS sends in X-JDC-Connection-Key.';
COMMENT ON COLUMN public.pos_connections.webhook_secret IS
  'Shared webhook HMAC secret. Never expose through client-side reads.';

CREATE TABLE IF NOT EXISTS public.pos_webhook_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  connection_id uuid NOT NULL REFERENCES public.pos_connections(id) ON DELETE CASCADE,
  event_id text NOT NULL,
  received_at timestamptz NOT NULL DEFAULT now(),
  UNIQUE (connection_id, event_id)
);

CREATE INDEX IF NOT EXISTS idx_pos_webhook_events_received_at
  ON public.pos_webhook_events (received_at);

ALTER TABLE public.pos_webhook_events ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.pos_webhook_events FROM anon, authenticated;
GRANT SELECT, INSERT, DELETE ON public.pos_webhook_events TO service_role;

COMMENT ON TABLE public.pos_webhook_events IS
  'Replay guard for signed StoreOS Connect webhook events.';

CREATE OR REPLACE FUNCTION public.mark_food_ready_guarded(
  p_booking_id uuid,
  p_merchant_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
BEGIN
  IF auth.uid() IS NOT NULL AND auth.uid() <> p_merchant_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'merchant_auth_mismatch');
  END IF;

  SELECT *
    INTO v_booking
    FROM public.bookings
   WHERE id = p_booking_id
   FOR UPDATE;

  IF v_booking.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF v_booking.service_type <> 'food' THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_food_order');
  END IF;

  IF v_booking.merchant_id <> p_merchant_id THEN
    RETURN jsonb_build_object('success', false, 'error', 'merchant_mismatch');
  END IF;

  IF v_booking.status IN ('arrived_at_merchant', 'arrived') THEN
    UPDATE public.bookings
       SET status = 'ready_for_pickup',
           status_origin = 'jdc',
           merchant_food_ready_at = now(),
           updated_at = now()
     WHERE id = p_booking_id
     RETURNING * INTO v_booking;

    RETURN jsonb_build_object(
      'success', true,
      'status', 'ready_for_pickup',
      'pending_driver_arrival', false
    );
  END IF;

  IF v_booking.status IN ('preparing', 'matched', 'driver_accepted', 'accepted') THEN
    IF v_booking.driver_id IS NULL THEN
      UPDATE public.bookings
         SET status = 'ready_for_pickup',
             status_origin = 'jdc',
             merchant_food_ready_at = now(),
             updated_at = now()
       WHERE id = p_booking_id
       RETURNING * INTO v_booking;

      RETURN jsonb_build_object(
        'success', true,
        'status', 'ready_for_pickup',
        'pending_driver_arrival', false
      );
    END IF;

    UPDATE public.bookings
       SET status_origin = 'jdc',
           merchant_food_ready_at = now(),
           updated_at = now()
     WHERE id = p_booking_id
     RETURNING * INTO v_booking;

    RETURN jsonb_build_object(
      'success', true,
      'status', v_booking.status,
      'pending_driver_arrival', true
    );
  END IF;

  RETURN jsonb_build_object(
    'success', false,
    'error', 'invalid_status',
    'current_status', v_booking.status
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.mark_food_ready_guarded(uuid, uuid)
  TO authenticated, service_role;

CREATE OR REPLACE FUNCTION public.update_booking_status_driver_guarded(
  p_booking_id uuid,
  p_new_status text,
  p_expected_statuses text[]
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_booking public.bookings%ROWTYPE;
BEGIN
  IF auth.uid() IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'not_authenticated');
  END IF;

  SELECT * INTO v_booking
    FROM public.bookings
   WHERE id = p_booking_id
   FOR UPDATE;

  IF v_booking.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF v_booking.driver_id IS NULL OR v_booking.driver_id <> auth.uid() THEN
    RETURN jsonb_build_object('success', false, 'error', 'driver_mismatch');
  END IF;

  IF NOT (v_booking.status = ANY(p_expected_statuses)) THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'status_mismatch',
      'current_status', v_booking.status
    );
  END IF;

  UPDATE public.bookings
     SET status = p_new_status,
         status_origin = 'jdc',
         updated_at = now()
   WHERE id = p_booking_id;

  RETURN jsonb_build_object('success', true, 'status', p_new_status);
END;
$$;

GRANT EXECUTE ON FUNCTION public.update_booking_status_driver_guarded(uuid, text, text[])
  TO authenticated;

CREATE OR REPLACE FUNCTION public.complete_booking(
  p_booking_id uuid,
  p_driver_id uuid,
  p_commission_amount numeric DEFAULT 0,
  p_driver_earnings numeric DEFAULT 0,
  p_app_earnings numeric DEFAULT 0,
  p_description text DEFAULT ''
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_status text;
  v_wallet_result jsonb;
BEGIN
  SELECT status INTO v_status
  FROM public.bookings
  WHERE id = p_booking_id
  FOR UPDATE;

  IF v_status IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'booking_not_found');
  END IF;

  IF v_status NOT IN ('in_transit', 'arrived', 'picking_up_order', 'driver_accepted', 'ready_for_pickup', 'arrived_at_merchant') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_status', 'current_status', v_status);
  END IF;

  IF p_commission_amount > 0 THEN
    v_wallet_result := public.wallet_deduct(
      p_driver_id, p_commission_amount,
      COALESCE(p_description, 'หักค่าบริการระบบ ออเดอร์ ' || LEFT(p_booking_id::text, 8)),
      'commission', p_booking_id
    );

    IF NOT (v_wallet_result->>'success')::boolean THEN
      RETURN jsonb_build_object(
        'success', false,
        'error', 'settlement_failed',
        'wallet_error', v_wallet_result->>'error'
      );
    END IF;
  END IF;

  UPDATE public.bookings
  SET status = 'completed',
      status_origin = 'jdc',
      completed_at = now(),
      driver_earnings = p_driver_earnings,
      app_earnings = p_app_earnings,
      updated_at = now()
  WHERE id = p_booking_id;

  RETURN jsonb_build_object(
    'success', true,
    'booking_id', p_booking_id,
    'wallet', COALESCE(v_wallet_result, '{}'::jsonb)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.accept_booking(
  p_booking_id uuid,
  p_driver_id uuid,
  p_expected_status text DEFAULT 'pending'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_rows_affected integer;
BEGIN
  UPDATE public.bookings
  SET driver_id = p_driver_id,
      status = 'driver_accepted',
      status_origin = 'jdc',
      assigned_at = now(),
      updated_at = now()
  WHERE id = p_booking_id
    AND driver_id IS NULL
    AND status = p_expected_status;

  GET DIAGNOSTICS v_rows_affected = ROW_COUNT;

  IF v_rows_affected = 0 THEN
    RETURN jsonb_build_object(
      'success', false,
      'error', 'already_taken',
      'message', 'งานนี้ถูกรับไปแล้ว หรือสถานะเปลี่ยนไปแล้ว'
    );
  END IF;

  RETURN jsonb_build_object('success', true, 'booking_id', p_booking_id);
END;
$$;

GRANT EXECUTE ON FUNCTION public.complete_booking(uuid, uuid, numeric, numeric, numeric, text)
  TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.accept_booking(uuid, uuid, text)
  TO authenticated;

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

DROP TRIGGER IF EXISTS trg_notify_storeos_order ON public.bookings;
CREATE TRIGGER trg_notify_storeos_order
AFTER INSERT OR UPDATE OF status ON public.bookings
FOR EACH ROW
EXECUTE FUNCTION public.notify_storeos_order();
