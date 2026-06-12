-- Minimal chat layer for Laundry quote negotiation.
-- The quote itself remains structured in laundry_orders; chat messages are
-- supporting conversation between customer, merchant, and admin.

CREATE TABLE IF NOT EXISTS public.laundry_quote_threads (
  laundry_order_id uuid PRIMARY KEY REFERENCES public.laundry_orders(id) ON DELETE CASCADE,
  customer_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  merchant_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status text NOT NULL DEFAULT 'open' CHECK (status IN ('open', 'closed')),
  last_message_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.laundry_quote_messages (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  thread_id uuid NOT NULL REFERENCES public.laundry_quote_threads(laundry_order_id) ON DELETE CASCADE,
  laundry_order_id uuid NOT NULL REFERENCES public.laundry_orders(id) ON DELETE CASCADE,
  sender_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  sender_role text NOT NULL CHECK (sender_role IN ('customer', 'merchant', 'admin')),
  message_type text NOT NULL DEFAULT 'text' CHECK (message_type IN ('text', 'system')),
  body text NOT NULL CHECK (char_length(btrim(body)) > 0),
  created_at timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_laundry_quote_messages_thread_created
  ON public.laundry_quote_messages (thread_id, created_at);

ALTER TABLE public.laundry_quote_threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.laundry_quote_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "laundry quote threads visible to participants and admins"
  ON public.laundry_quote_threads;
CREATE POLICY "laundry quote threads visible to participants and admins"
ON public.laundry_quote_threads
FOR SELECT
TO authenticated
USING (
  customer_id = auth.uid()
  OR merchant_id = auth.uid()
  OR EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = auth.uid()
      AND p.role = 'admin'
  )
);

DROP POLICY IF EXISTS "laundry quote messages visible to participants and admins"
  ON public.laundry_quote_messages;
CREATE POLICY "laundry quote messages visible to participants and admins"
ON public.laundry_quote_messages
FOR SELECT
TO authenticated
USING (
  EXISTS (
    SELECT 1
    FROM public.laundry_quote_threads t
    WHERE t.laundry_order_id = laundry_quote_messages.thread_id
      AND (
        t.customer_id = auth.uid()
        OR t.merchant_id = auth.uid()
        OR EXISTS (
          SELECT 1
          FROM public.profiles p
          WHERE p.id = auth.uid()
            AND p.role = 'admin'
        )
      )
  )
);

CREATE OR REPLACE FUNCTION public.send_laundry_quote_message(
  p_laundry_order_id uuid,
  p_body text,
  p_message_type text DEFAULT 'text'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v_actor_id uuid := auth.uid();
  v_order public.laundry_orders%ROWTYPE;
  v_sender_role text;
  v_message_id uuid;
  v_is_admin boolean;
BEGIN
  IF v_actor_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'unauthenticated');
  END IF;

  IF p_laundry_order_id IS NULL OR NULLIF(btrim(COALESCE(p_body, '')), '') IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'missing_required_fields');
  END IF;

  IF COALESCE(p_message_type, 'text') NOT IN ('text', 'system') THEN
    RETURN jsonb_build_object('success', false, 'error', 'invalid_message_type');
  END IF;

  SELECT *
  INTO v_order
  FROM public.laundry_orders
  WHERE id = p_laundry_order_id;

  IF v_order.id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'order_not_found');
  END IF;

  SELECT EXISTS (
    SELECT 1
    FROM public.profiles p
    WHERE p.id = v_actor_id
      AND p.role = 'admin'
  )
  INTO v_is_admin;

  IF v_actor_id = v_order.customer_id THEN
    v_sender_role := 'customer';
  ELSIF v_actor_id = v_order.merchant_id THEN
    v_sender_role := 'merchant';
  ELSIF v_is_admin THEN
    v_sender_role := 'admin';
  ELSE
    RETURN jsonb_build_object('success', false, 'error', 'forbidden');
  END IF;

  INSERT INTO public.laundry_quote_threads (
    laundry_order_id,
    customer_id,
    merchant_id,
    status,
    last_message_at
  )
  VALUES (
    v_order.id,
    v_order.customer_id,
    v_order.merchant_id,
    'open',
    now()
  )
  ON CONFLICT (laundry_order_id) DO UPDATE
  SET last_message_at = now(),
      updated_at = now();

  INSERT INTO public.laundry_quote_messages (
    thread_id,
    laundry_order_id,
    sender_id,
    sender_role,
    message_type,
    body
  )
  VALUES (
    v_order.id,
    v_order.id,
    v_actor_id,
    v_sender_role,
    COALESCE(p_message_type, 'text'),
    btrim(p_body)
  )
  RETURNING id INTO v_message_id;

  INSERT INTO public.notifications (user_id, title, body, type, data)
  SELECT target_user_id,
         'มีข้อความใหม่ในคำขอซักผ้า',
         LEFT(btrim(p_body), 120),
         'laundry.quote_message',
         jsonb_build_object(
           'laundry_order_id', v_order.id,
           'message_id', v_message_id,
           'sender_role', v_sender_role
         )
  FROM (
    VALUES (v_order.customer_id), (v_order.merchant_id)
  ) AS targets(target_user_id)
  WHERE target_user_id <> v_actor_id;

  RETURN jsonb_build_object(
    'success', true,
    'laundry_order_id', v_order.id,
    'message_id', v_message_id,
    'sender_role', v_sender_role
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.send_laundry_quote_message(uuid, text, text)
  TO authenticated, service_role;
