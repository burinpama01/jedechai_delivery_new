// @ts-nocheck
// Supabase Edge Function: notify-laundry-quote-request
// Sends allowlisted LINE/Telegram admin notifications for a customer-owned
// laundry quote request. The client may only submit laundry_order_id; all
// message details are derived server-side from Supabase.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  corsHeaders,
  errorResponse,
  jsonResponse,
} from "../_shared/admin-auth.ts";

const ADMIN_NOTIFICATION_TIMEOUT_MS = 3000;

function bearerToken(req: Request): string {
  const authorization = req.headers.get("authorization") ??
    req.headers.get("Authorization") ?? "";
  return authorization.toLowerCase().startsWith("bearer ")
    ? authorization.slice(7).trim()
    : "";
}

function truncateText(value: unknown, maxLength: number): string {
  const text = String(value ?? "").trim();
  if (text.length <= maxLength) return text;
  return `${text.slice(0, Math.max(0, maxLength - 3))}...`;
}

function summarizeAddress(value: unknown): string {
  return truncateText(value, 120);
}

function countLaundryItems(value: unknown): number {
  return Array.isArray(value) ? value.length : 0;
}

async function verifyUser(req: Request) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return { response: errorResponse("Server misconfigured", 500) };
  }

  const token = bearerToken(req);
  if (!token) {
    return { response: errorResponse("Missing authorization token", 401) };
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
  const {
    data: { user },
    error,
  } = await supabaseAdmin.auth.getUser(token);
  if (error || !user) {
    return { response: errorResponse("Invalid or expired token", 401) };
  }

  return { user, supabaseAdmin };
}

async function getAdminNotificationConfig(supabaseAdmin) {
  const envLineTo = Deno.env.get("LINE_ADMIN_TO")?.trim() || "";
  const envTelegramChatId = Deno.env.get("TELEGRAM_ADMIN_CHAT_ID")?.trim() ||
    "";

  try {
    const { data, error } = await supabaseAdmin
      .from("system_config")
      .select(
        "admin_line_enabled, admin_line_recipient_id, admin_telegram_enabled, admin_telegram_chat_id",
      )
      .eq("id", 1)
      .maybeSingle();
    if (error) throw error;

    return {
      lineEnabled: data?.admin_line_enabled === true,
      lineTo: String(data?.admin_line_recipient_id || envLineTo).trim(),
      telegramEnabled: data?.admin_telegram_enabled === true,
      telegramChatId: String(data?.admin_telegram_chat_id || envTelegramChatId)
        .trim(),
      hasConfigRow: !!data,
    };
  } catch (error) {
    console.warn(
      "laundry admin notification config lookup failed:",
      error?.message || error,
    );
    return {
      lineEnabled: !!envLineTo,
      lineTo: envLineTo,
      telegramEnabled: !!envTelegramChatId,
      telegramChatId: envTelegramChatId,
      hasConfigRow: false,
    };
  }
}

async function sendAdminLineNotification(to: string | null, text: string) {
  const accessToken = Deno.env.get("LINE_CHANNEL_ACCESS_TOKEN")?.trim();
  if (!to || !accessToken) {
    return { success: false, skipped: "line_not_configured" };
  }

  const res = await fetch("https://api.line.me/v2/bot/message/push", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${accessToken}`,
      "X-Line-Retry-Key": crypto.randomUUID(),
    },
    body: JSON.stringify({
      to,
      messages: [{ type: "text", text: truncateText(text, 4900) }],
    }),
    signal: AbortSignal.timeout(ADMIN_NOTIFICATION_TIMEOUT_MS),
  });
  if (!res.ok) {
    console.warn(
      "laundry LINE notification failed:",
      res.status,
      await res.text(),
    );
  }
  return { success: res.ok, status: res.status };
}

async function sendAdminTelegramNotification(
  chatId: string | null,
  text: string,
) {
  const botToken = Deno.env.get("TELEGRAM_BOT_TOKEN")?.trim();
  if (!chatId || !botToken) {
    return { success: false, skipped: "telegram_not_configured" };
  }

  const res = await fetch(
    `https://api.telegram.org/bot${botToken}/sendMessage`,
    {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        chat_id: chatId,
        text: truncateText(text, 4096),
      }),
      signal: AbortSignal.timeout(ADMIN_NOTIFICATION_TIMEOUT_MS),
    },
  );
  if (!res.ok) {
    console.warn(
      "laundry Telegram notification failed:",
      res.status,
      await res.text(),
    );
  }
  return { success: res.ok, status: res.status };
}

async function fetchLaundryOrderContext(supabaseAdmin, laundryOrderId: string) {
  const { data: order, error: orderError } = await supabaseAdmin
    .from("laundry_orders")
    .select(
      "id, customer_id, merchant_id, pickup_address, requested_items, attachment_urls, package_id, admin_external_notification_claimed_at, admin_external_notified_at",
    )
    .eq("id", laundryOrderId)
    .maybeSingle();
  if (orderError || !order) {
    return { error: orderError?.message || "laundry_order_not_found" };
  }

  const [{ data: merchant }, { data: laundryPackage }] = await Promise.all([
    supabaseAdmin
      .from("profiles")
      .select("full_name")
      .eq("id", order.merchant_id)
      .maybeSingle(),
    order.package_id
      ? supabaseAdmin
        .from("laundry_packages")
        .select("name")
        .eq("id", order.package_id)
        .maybeSingle()
      : Promise.resolve({ data: null }),
  ]);

  return { order, merchant, laundryPackage };
}

function buildNotificationText(args: {
  laundryOrderId: string;
  merchantName: string;
  laundryItemCount: number;
  attachmentCount: number;
  pickupAddressSummary: string;
  packageName?: string | null;
}) {
  return [
    "JDC: คำขอซักผ้าใหม่",
    `รหัส: #${args.laundryOrderId.slice(0, 8)}`,
    `ร้าน: ${args.merchantName}`,
    args.packageName ? `แพ็กเกจ: ${args.packageName}` : "",
    `รายการผ้า: ${args.laundryItemCount} รายการ`,
    `รูปแนบ: ${args.attachmentCount} รูป`,
    args.pickupAddressSummary ? `จุดรับผ้า: ${args.pickupAddressSummary}` : "",
  ].filter(Boolean).join("\n");
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  try {
    const auth = await verifyUser(req);
    if (auth.response) return auth.response;
    const { user, supabaseAdmin } = auth;

    const body = await req.json().catch(() => null);
    const laundryOrderId = String(body?.laundry_order_id || "").trim();
    if (!laundryOrderId) {
      return errorResponse("Missing laundry_order_id", 400);
    }

    const context = await fetchLaundryOrderContext(
      supabaseAdmin,
      laundryOrderId,
    );
    if (context.error) {
      return errorResponse(context.error, 404);
    }

    const { order, merchant, laundryPackage } = context;
    if (order.customer_id !== user.id) {
      return errorResponse("order_owner_required", 403);
    }
    if (order.admin_external_notified_at) {
      return jsonResponse({ success: true, skipped: "already_notified" });
    }

    const merchantName = truncateText(merchant?.full_name || "ร้านซักผ้า", 120);
    const laundryItemCount = countLaundryItems(order.requested_items);
    const attachmentCount = Array.isArray(order.attachment_urls)
      ? order.attachment_urls.length
      : 0;
    const pickupAddressSummary = summarizeAddress(order.pickup_address);
    const packageName = laundryPackage?.name
      ? truncateText(laundryPackage.name, 120)
      : null;
    const text = buildNotificationText({
      laundryOrderId,
      merchantName,
      laundryItemCount,
      attachmentCount,
      pickupAddressSummary,
      packageName,
    });

    const config = await getAdminNotificationConfig(supabaseAdmin);
    const sends: Array<() => Promise<unknown>> = [];
    if (config.lineEnabled || (!config.hasConfigRow && config.lineTo)) {
      sends.push(() => sendAdminLineNotification(config.lineTo, text));
    }
    if (
      config.telegramEnabled ||
      (!config.hasConfigRow && config.telegramChatId)
    ) {
      sends.push(() =>
        sendAdminTelegramNotification(config.telegramChatId, text)
      );
    }
    if (sends.length === 0) {
      return jsonResponse({ success: true, skipped: "no_channels_enabled" });
    }

    const { data: claim, error: claimError } = await supabaseAdmin
      .from("laundry_orders")
      .update({
        admin_external_notification_claimed_at: new Date().toISOString(),
        admin_external_notification_error: null,
      })
      .eq("id", laundryOrderId)
      .eq("customer_id", user.id)
      .is("admin_external_notified_at", null)
      .is("admin_external_notification_claimed_at", null)
      .select("id")
      .maybeSingle();
    if (claimError) {
      return errorResponse(
        claimError.message || "notification_claim_failed",
        500,
      );
    }
    if (!claim) {
      return jsonResponse({ success: true, skipped: "already_claimed" });
    }

    const results = await Promise.allSettled(sends.map((send) => send()));
    for (const result of results) {
      if (result.status === "rejected") {
        console.warn(
          "laundry admin notification channel failed:",
          result.reason,
        );
      }
    }
    const hasSuccessfulDelivery = results.some((result) => {
      if (result.status !== "fulfilled") return false;
      const value = result.value as Record<string, unknown> | undefined;
      return value?.success === true && !value.skipped;
    });
    if (!hasSuccessfulDelivery) {
      const errorSummary = results
        .map((result) =>
          result.status === "fulfilled"
            ? JSON.stringify(result.value)
            : String(result.reason)
        )
        .join("; ");
      await supabaseAdmin
        .from("laundry_orders")
        .update({
          admin_external_notification_claimed_at: null,
          admin_external_notification_error: truncateText(errorSummary, 500),
        })
        .eq("id", laundryOrderId)
        .eq("customer_id", user.id)
        .is("admin_external_notified_at", null);
      return jsonResponse(
        {
          success: false,
          error: "notification_delivery_failed",
        },
        502,
      );
    }

    await supabaseAdmin
      .from("laundry_orders")
      .update({
        admin_external_notified_at: new Date().toISOString(),
        admin_external_notification_error: null,
      })
      .eq("id", laundryOrderId)
      .eq("customer_id", user.id)
      .is("admin_external_notified_at", null);

    return jsonResponse({ success: true, channels: results.length });
  } catch (error) {
    console.error("notify-laundry-quote-request failed:", error);
    return errorResponse(
      error instanceof Error
        ? error.message
        : "notify-laundry-quote-request failed",
      500,
    );
  }
});
