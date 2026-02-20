// @ts-nocheck
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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

function hasValidSchedulerAuth(req: Request, serviceRoleKey?: string): boolean {
  const incomingSecret = req.headers.get("x-scheduler-secret") ?? "";
  if (schedulerSecret && incomingSecret === schedulerSecret) {
    return true;
  }

  const authorization = req.headers.get("authorization") ?? req.headers.get("Authorization") ?? "";
  const token = authorization.toLowerCase().startsWith("bearer ")
    ? authorization.slice(7).trim()
    : "";

  return Boolean(serviceRoleKey) && token === serviceRoleKey;
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

      const notifications: Array<Record<string, unknown>> = [
        {
          user_id: booking.customer_id,
          title: "⏰ ใกล้ถึงเวลานัดหมาย",
          body: `ออเดอร์ของคุณจะเริ่มเวลา ${timeText}`,
          type: "scheduled_order_reminder",
          data: baseData,
        },
      ];

      if (booking.merchant_id) {
        notifications.push({
          user_id: booking.merchant_id,
          title: "⏰ ออเดอร์นัดหมายใกล้ถึงเวลา",
          body: `ออเดอร์ #${booking.id.slice(0, 8)} จะเริ่มเวลา ${timeText}`,
          type: "scheduled_order_reminder",
          data: baseData,
        });
      }

      const { error: insertNotificationError } = await supabase
        .from("notifications")
        .insert(notifications);

      if (!insertNotificationError) {
        result.notificationsInserted += notifications.length;
      } else {
        console.error("notification insert error (reminder):", insertNotificationError);
      }
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

      const notifications: Array<Record<string, unknown>> = [
        {
          user_id: booking.customer_id,
          title: "🚀 ถึงเวลานัดหมายแล้ว",
          body: `ออเดอร์ของคุณเริ่มแล้ว (${timeText})`,
          type: "scheduled_order_released",
          data: baseData,
        },
      ];

      if (booking.merchant_id) {
        notifications.push({
          user_id: booking.merchant_id,
          title: "🚀 ถึงเวลาออเดอร์นัดหมาย",
          body: `เริ่มดำเนินการออเดอร์ #${booking.id.slice(0, 8)} ได้แล้ว`,
          type: "scheduled_order_released",
          data: baseData,
        });
      }

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
        } else {
          for (const driver of drivers ?? []) {
            notifications.push({
              user_id: driver.id,
              title: booking.service_type === "ride"
                ? "🚗 งานนัดหมายเริ่มแล้ว"
                : "📦 งานพัสดุนัดหมายเริ่มแล้ว",
              body: `มีงาน #${booking.id.slice(0, 8)} พร้อมรับแล้ว`,
              type: "scheduled_order_released",
              data: baseData,
            });
          }
        }
      }

      const { error: insertNotificationError } = await supabase
        .from("notifications")
        .insert(notifications);

      if (!insertNotificationError) {
        result.notificationsInserted += notifications.length;
      } else {
        console.error("notification insert error (release):", insertNotificationError);
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
