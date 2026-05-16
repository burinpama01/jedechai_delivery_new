// @ts-nocheck
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { notifyTargets } from "../_shared/admin-auth.ts";

type BookingRow = {
  id: string;
  customer_id: string;
  merchant_id: string | null;
  service_type: string;
  status: string;
  vehicle_type: string | null;
  scheduled_at: string;
};

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type, x-scheduler-secret",
};

const reminderWindowMinutes = Number(
  Deno.env.get("SCHEDULED_REMINDER_WINDOW_MINUTES") ?? "15",
);

const schedulerSecret = Deno.env.get("SCHEDULED_ORDER_CRON_SECRET") ?? "";

function unauthorized() {
  return new Response(
    JSON.stringify({ error: "Unauthorized" }),
    {
      status: 401,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    },
  );
}

function hasValidSchedulerAuth(req: Request, _serviceRoleKey?: string): boolean {
  // Phase 6: Only accept the dedicated scheduler secret.
  // Do NOT fall back to service_role key — that would allow any holder
  // of the service key to trigger scheduled-order processing.
  if (!schedulerSecret) {
    console.error("SCHEDULED_ORDER_CRON_SECRET is not configured");
    return false;
  }
  const incomingSecret = req.headers.get("x-scheduler-secret") ?? "";
  return incomingSecret === schedulerSecret;
}

function formatThaiDateTime(iso: string): string {
  const dt = new Date(iso);
  const formatter = new Intl.DateTimeFormat("en-GB", {
    timeZone: "Asia/Bangkok",
    year: "numeric",
    month: "2-digit",
    day: "2-digit",
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  });

  const parts = formatter.formatToParts(dt);
  const day = parts.find((p) => p.type === "day")?.value ?? "00";
  const month = parts.find((p) => p.type === "month")?.value ?? "00";
  const year = parts.find((p) => p.type === "year")?.value ?? "0000";
  const hour = parts.find((p) => p.type === "hour")?.value ?? "00";
  const minute = parts.find((p) => p.type === "minute")?.value ?? "00";
  return `${day}/${month}/${year} ${hour}:${minute}`;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return new Response(JSON.stringify({ error: "Method not allowed" }), {
      status: 405,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    return new Response(
      JSON.stringify({ error: "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY" }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }

  if (!hasValidSchedulerAuth(req, serviceRoleKey)) {
    return unauthorized();
  }

  const supabase = createClient(supabaseUrl, serviceRoleKey);

  const now = new Date();
  const nowIso = now.toISOString();
  const reminderUpperIso = new Date(
    now.getTime() + reminderWindowMinutes * 60 * 1000,
  ).toISOString();

  const result = {
    remindersScanned: 0,
    remindersMarked: 0,
    releasesScanned: 0,
    releasesMarked: 0,
    notificationsInserted: 0,
  };

  try {
    const { data: reminderBookings, error: reminderError } = await supabase
      .from("bookings")
      .select("id, customer_id, merchant_id, service_type, status, vehicle_type, scheduled_at")
      .not("scheduled_at", "is", null)
      .in("status", ["pending", "pending_merchant", "preparing"])
      .is("scheduled_reminder_sent_at", null)
      .gte("scheduled_at", nowIso)
      .lte("scheduled_at", reminderUpperIso)
      .order("scheduled_at", { ascending: true })
      .limit(300);

    if (reminderError) throw reminderError;

    const reminders = (reminderBookings ?? []) as BookingRow[];
    result.remindersScanned = reminders.length;

    for (const booking of reminders) {
      const timeText = formatThaiDateTime(booking.scheduled_at);
      const baseData = {
        booking_id: booking.id,
        service_type: booking.service_type,
        scheduled_at: booking.scheduled_at,
        type: "scheduled_order_reminder",
      };

      const rows: Array<{ user_id: string; title: string; body: string; type: string; data: Record<string, unknown> }> = [
        {
          user_id: booking.customer_id,
          title: "⏰ ใกล้ถึงเวลานัดหมาย",
          body: `ออเดอร์ของคุณจะเริ่มเวลา ${timeText}`,
          type: "scheduled_order_reminder",
          data: baseData,
        },
      ];

      if (booking.merchant_id) {
        rows.push({
          user_id: booking.merchant_id,
          title: "⏰ ออเดอร์นัดหมายใกล้ถึงเวลา",
          body: `ออเดอร์ #${booking.id.slice(0, 8)} จะเริ่มเวลา ${timeText}`,
          type: "scheduled_order_reminder",
          data: baseData,
        });
      }

      await notifyTargets(supabase, rows);
      result.notificationsInserted += rows.length;
    }

    if (reminders.length > 0) {
      const reminderIds = reminders.map((b) => b.id);
      const { error: markReminderError } = await supabase
        .from("bookings")
        .update({
          scheduled_reminder_sent_at: nowIso,
          updated_at: nowIso,
        })
        .in("id", reminderIds);

      if (markReminderError) throw markReminderError;
      result.remindersMarked = reminderIds.length;
    }

    const { data: releaseBookings, error: releaseError } = await supabase
      .from("bookings")
      .select("id, customer_id, merchant_id, service_type, status, vehicle_type, scheduled_at")
      .not("scheduled_at", "is", null)
      .in("status", ["pending", "pending_merchant", "preparing"])
      .is("scheduled_release_processed_at", null)
      .lte("scheduled_at", nowIso)
      .order("scheduled_at", { ascending: true })
      .limit(300);

    if (releaseError) throw releaseError;

    const releases = (releaseBookings ?? []) as BookingRow[];
    result.releasesScanned = releases.length;

    for (const booking of releases) {
      const timeText = formatThaiDateTime(booking.scheduled_at);
      const baseData = {
        booking_id: booking.id,
        service_type: booking.service_type,
        scheduled_at: booking.scheduled_at,
        type: "scheduled_order_released",
      };

      const participantRows: Array<{ user_id: string; title: string; body: string; type: string; data: Record<string, unknown> }> = [
        {
          user_id: booking.customer_id,
          title: "🚀 ถึงเวลานัดหมายแล้ว",
          body: `ออเดอร์ของคุณเริ่มแล้ว (${timeText})`,
          type: "scheduled_order_released",
          data: baseData,
        },
      ];

      if (booking.merchant_id) {
        participantRows.push({
          user_id: booking.merchant_id,
          title: "🚀 ถึงเวลาออเดอร์นัดหมาย",
          body: `เริ่มดำเนินการออเดอร์ #${booking.id.slice(0, 8)} ได้แล้ว`,
          type: "scheduled_order_released",
          data: baseData,
        });
      }

      await notifyTargets(supabase, participantRows);
      result.notificationsInserted += participantRows.length;

      if (booking.service_type === "ride" || booking.service_type === "parcel") {
        let driverQuery = supabase
          .from("profiles")
          .select("id")
          .eq("role", "driver")
          .eq("is_online", true)
          .limit(120);

        if (booking.service_type === "ride" && booking.vehicle_type) {
          driverQuery = driverQuery.eq("vehicle_type", booking.vehicle_type);
        }

        const { data: drivers, error: driversError } = await driverQuery;
        if (driversError) {
          console.error("driver query error:", driversError);
        } else if ((drivers ?? []).length > 0) {
          const driverTitle = booking.service_type === "ride"
            ? "🚗 งานนัดหมายเริ่มแล้ว"
            : "📦 งานพัสดุนัดหมายเริ่มแล้ว";
          const driverBody = `มีงาน #${booking.id.slice(0, 8)} พร้อมรับแล้ว`;

          const driverRows = (drivers ?? []).map((d) => ({
            user_id: d.id,
            title: driverTitle,
            body: driverBody,
            type: "scheduled_order_released",
            data: baseData,
          }));

          const { error: driverInsertErr } = await supabase
            .from("notifications")
            .insert(driverRows);
          if (driverInsertErr) {
            console.error("driver notification insert error:", driverInsertErr);
          } else {
            result.notificationsInserted += driverRows.length;
          }

          const driverIds = (drivers ?? []).map((d) => d.id);
          try {
            await fetch(`${supabaseUrl}/functions/v1/send-fcm-notification`, {
              method: "POST",
              headers: {
                "Content-Type": "application/json",
                Authorization: `Bearer ${serviceRoleKey}`,
              },
              body: JSON.stringify({
                user_ids: driverIds,
                title: driverTitle,
                message: driverBody,
                data: baseData as Record<string, string>,
                persist_in_app: false,
              }),
            });
          } catch (e) {
            console.warn("Driver FCM batch failed:", e);
          }
        }
      }
    }

    if (releases.length > 0) {
      const releaseIds = releases.map((b) => b.id);
      const { error: markReleaseError } = await supabase
        .from("bookings")
        .update({
          scheduled_release_processed_at: nowIso,
          updated_at: nowIso,
        })
        .in("id", releaseIds);

      if (markReleaseError) throw markReleaseError;
      result.releasesMarked = releaseIds.length;
    }

    return new Response(
      JSON.stringify({ success: true, now: nowIso, result }),
      {
        status: 200,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  } catch (error) {
    console.error("process-scheduled-orders error:", error);
    return new Response(
      JSON.stringify({ success: false, error: String(error) }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      },
    );
  }
});
