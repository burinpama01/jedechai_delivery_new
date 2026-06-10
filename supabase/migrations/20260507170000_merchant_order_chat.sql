ALTER TABLE public.chat_rooms
  ADD COLUMN IF NOT EXISTS merchant_id UUID REFERENCES auth.users(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_chat_rooms_merchant
  ON public.chat_rooms(merchant_id)
  WHERE merchant_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_chat_rooms_booking_room_type
  ON public.chat_rooms(booking_id, room_type);
DROP POLICY IF EXISTS "chat_rooms_select" ON public.chat_rooms;
CREATE POLICY "chat_rooms_select" ON public.chat_rooms
  FOR SELECT USING (
    auth.uid() = customer_id
    OR auth.uid() = driver_id
    OR auth.uid() = merchant_id
    OR public.is_admin()
  );
DROP POLICY IF EXISTS "chat_rooms_insert" ON public.chat_rooms;
CREATE POLICY "chat_rooms_insert" ON public.chat_rooms
  FOR INSERT WITH CHECK (
    public.is_admin()
    OR (
      room_type = 'merchant_order'
      AND auth.uid() = merchant_id
      AND EXISTS (
        SELECT 1
        FROM public.bookings b
        WHERE b.id = booking_id
          AND b.customer_id = chat_rooms.customer_id
          AND b.merchant_id = chat_rooms.merchant_id
      )
    )
    OR (
      room_type <> 'merchant_order'
      AND (
        auth.uid() = customer_id
        OR auth.uid() = driver_id
      )
    )
  );
DROP POLICY IF EXISTS "chat_rooms_update" ON public.chat_rooms;
CREATE POLICY "chat_rooms_update" ON public.chat_rooms
  FOR UPDATE USING (
    auth.uid() = customer_id
    OR auth.uid() = driver_id
    OR auth.uid() = merchant_id
    OR public.is_admin()
  );
DROP POLICY IF EXISTS "chat_msg_select" ON public.chat_messages;
CREATE POLICY "chat_msg_select" ON public.chat_messages
  FOR SELECT USING (
    EXISTS (
      SELECT 1 FROM public.chat_rooms cr
      WHERE cr.id = chat_messages.chat_room_id
        AND (
          cr.customer_id = auth.uid()
          OR cr.driver_id = auth.uid()
          OR cr.merchant_id = auth.uid()
          OR public.is_admin()
        )
    )
  );
DROP POLICY IF EXISTS "chat_msg_insert" ON public.chat_messages;
CREATE POLICY "chat_msg_insert" ON public.chat_messages
  FOR INSERT WITH CHECK (
    auth.uid() = sender_id
    AND EXISTS (
      SELECT 1 FROM public.chat_rooms cr
      WHERE cr.id = chat_messages.chat_room_id
        AND (
          cr.customer_id = auth.uid()
          OR cr.driver_id = auth.uid()
          OR cr.merchant_id = auth.uid()
          OR public.is_admin()
        )
    )
  );
DROP POLICY IF EXISTS "chat_msg_update" ON public.chat_messages;
CREATE POLICY "chat_msg_update" ON public.chat_messages
  FOR UPDATE USING (
    EXISTS (
      SELECT 1 FROM public.chat_rooms cr
      WHERE cr.id = chat_messages.chat_room_id
        AND (
          cr.customer_id = auth.uid()
          OR cr.driver_id = auth.uid()
          OR cr.merchant_id = auth.uid()
          OR public.is_admin()
        )
    )
  );
