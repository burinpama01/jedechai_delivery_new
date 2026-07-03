// @ts-nocheck
// Supabase Edge Function: connect_update_order_status
// StoreOS -> JDC food order status sync. Requires X-JDC-Connection-Key + HMAC headers.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, errorResponse, jsonResponse } from "../_shared/admin-auth.ts";
import {
  authenticateConnectRequest,
  pickMerchantId,
  verifyConnectMerchant,
} from "../_shared/connect-auth.ts";

const STOREOS_ALLOWED_STATUSES = new Set([
  "preparing",
  "ready_for_pickup",
]);

// เฉพาะ status ที่อัปเดตตรงบนตาราง bookings — ส่วน ready_for_pickup ไป
// mark_food_ready_guarded (logic เดียวกับปุ่ม "อาหารพร้อม" ในแอป) แทน
const ALLOWED_TRANSITIONS: Record<string, string[]> = {
  pending_merchant: ["preparing"],
  accepted: ["preparing"],
};

function withCors(res: Response) {
  const headers = new Headers(res.headers);
  for (const [key, value] of Object.entries(corsHeaders)) {
    if (!headers.has(key)) headers.set(key, value);
  }
  return new Response(res.body, {
    status: res.status,
    statusText: res.statusText,
    headers,
  });
}

function adminClient() {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) return null;
  return createClient(supabaseUrl, serviceRoleKey);
}

function pickString(value: unknown): string | null {
  return typeof value === "string" && value.trim() !== "" ? value.trim() : null;
}

function canTransition(current: string, next: string): boolean {
  if (current === next) return true;
  return (ALLOWED_TRANSITIONS[current] ?? []).includes(next);
}

serve(async (req) => {
  try {
    if (req.method === "OPTIONS") {
      return withCors(new Response(null, { status: 204, headers: corsHeaders }));
    }
    if (req.method !== "POST") {
      return withCors(errorResponse("Method not allowed", 405));
    }

    const supabaseAdmin = adminClient();
    if (!supabaseAdmin) return withCors(errorResponse("Server misconfigured", 500));

    const auth = await authenticateConnectRequest(req, supabaseAdmin);
    if (!auth.ok) return withCors(errorResponse(auth.error, auth.status));
    const { body, connection } = auth;

    const merchantId = pickMerchantId(body);
    const bookingId = pickString(body.booking_id);
    const nextStatus = pickString(body.status);
    const expectedCurrent = pickString(body.expected_current_status);
    if (!merchantId || !bookingId || !nextStatus) {
      return withCors(errorResponse("merchant_id, booking_id and status are required"));
    }
    const merchantCheck = await verifyConnectMerchant(supabaseAdmin, merchantId);
    if (!merchantCheck.ok) return withCors(errorResponse(merchantCheck.error, merchantCheck.status));

    if (!STOREOS_ALLOWED_STATUSES.has(nextStatus)) {
      return withCors(errorResponse("Status is not allowed for StoreOS", 400));
    }

    const { data: booking, error: bookingError } = await supabaseAdmin
      .from("bookings")
      .select("id, status, service_type, merchant_id, driver_id")
      .eq("id", bookingId)
      .eq("merchant_id", merchantId)
      .eq("service_type", "food")
      .maybeSingle();

    if (bookingError) return withCors(errorResponse(bookingError.message));
    if (!booking) return withCors(errorResponse("Food booking not found", 404));

    if (expectedCurrent && booking.status !== expectedCurrent) {
      return withCors(jsonResponse({
        conflict: true,
        current: booking.status,
      }, 409));
    }
    if (booking.status === nextStatus) {
      return withCors(jsonResponse({
        success: true,
        status: nextStatus,
        no_op: true,
      }));
    }

    const posOrderId = pickString(body.pos_order_id);

    if (nextStatus === "ready_for_pickup") {
      // ใช้ logic เดียวกับปุ่ม "อาหารพร้อม" ในแอป: mark_food_ready_guarded รองรับ
      // arrived_at_merchant / driver_accepted / preparing ฯลฯ และ set
      // merchant_food_ready_at + status_origin ให้เอง (p_origin=storeos กัน echo)
      const { data: ready, error: readyError } = await supabaseAdmin.rpc(
        "mark_food_ready_guarded",
        {
          p_booking_id: bookingId,
          p_merchant_id: merchantId,
          p_origin: "storeos",
        },
      );
      if (readyError) return withCors(errorResponse(readyError.message));
      if (!ready || ready.success !== true) {
        return withCors(jsonResponse({
          conflict: true,
          current: ready?.current_status ?? booking.status,
          error: ready?.error ?? "invalid_status",
        }, 409));
      }

      if (posOrderId) {
        await supabaseAdmin
          .from("bookings")
          .update({ pos_order_id: posOrderId })
          .eq("id", bookingId)
          .eq("merchant_id", merchantId);
      }

      let driver_candidate_notifications = 0;
      if (ready.status === "ready_for_pickup") {
        // แจ้งคนขับเหมือน flow ในแอป (ครอบคลุมทั้งคนขับที่รับงานแล้วและคนขับใกล้ร้าน)
        const { data: driverNotifications, error: notifyError } =
          await supabaseAdmin
            .rpc("notify_driver_visible_job", { p_booking_id: bookingId });
        if (notifyError) {
          console.error(
            "connect_update_order_status driver notification error:",
            notifyError.message,
          );
        } else {
          driver_candidate_notifications = Array.isArray(driverNotifications)
            ? driverNotifications.length
            : 0;
        }
      }

      await supabaseAdmin
        .from("pos_connections")
        .update({ last_status_sync_at: new Date().toISOString() })
        .eq("id", connection.id);

      return withCors(jsonResponse({
        success: true,
        booking_id: bookingId,
        status: ready.status,
        status_origin: "storeos",
        pending_driver_arrival: ready.pending_driver_arrival === true,
        driver_candidate_notifications,
      }));
    }

    if (!canTransition(booking.status, nextStatus)) {
      return withCors(jsonResponse({
        conflict: true,
        current: booking.status,
      }, 409));
    }

    const updatePayload: Record<string, unknown> = {
      status: nextStatus,
      status_origin: "storeos",
      updated_at: new Date().toISOString(),
    };
    if (posOrderId) updatePayload.pos_order_id = posOrderId;

    const { data: updated, error: updateError } = await supabaseAdmin
      .from("bookings")
      .update(updatePayload)
      .eq("id", bookingId)
      .eq("merchant_id", merchantId)
      .eq("service_type", "food")
      .eq("status", booking.status)
      .select("id, status, status_origin, pos_order_id")
      .maybeSingle();

    if (updateError) return withCors(errorResponse(updateError.message));
    if (!updated) {
      return withCors(jsonResponse({
        conflict: true,
        current: booking.status,
      }, 409));
    }

    await supabaseAdmin
      .from("pos_connections")
      .update({ last_status_sync_at: new Date().toISOString() })
      .eq("id", connection.id);

    return withCors(jsonResponse({
      success: true,
      booking_id: updated.id,
      status: updated.status,
      status_origin: updated.status_origin,
      driver_candidate_notifications: 0,
    }));
  } catch (error) {
    console.error("connect_update_order_status error:", error?.message || error);
    return withCors(errorResponse("Internal server error", 500));
  }
});
