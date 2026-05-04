// @ts-nocheck
// Supabase Edge Function: send-admin-line
// Sends LINE Messaging API push notifications to the admin recipient.
//
// Required secret:
//   supabase secrets set LINE_CHANNEL_ACCESS_TOKEN=...
//
// Optional secret fallback when system_config is not available:
//   supabase secrets set LINE_ADMIN_TO=Uxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, errorResponse, jsonResponse } from "../_shared/admin-auth.ts";

type LineConfig = {
  enabled: boolean;
  to: string | null;
};

function bearerToken(req: Request) {
  const authorization =
    req.headers.get("authorization") ??
    req.headers.get("Authorization") ??
    "";
  return authorization.toLowerCase().startsWith("bearer ")
    ? authorization.slice(7).trim()
    : "";
}

function truncateText(value: unknown, maxLength: number) {
  const text = String(value ?? "").trim();
  if (text.length <= maxLength) return text;
  return `${text.slice(0, Math.max(0, maxLength - 3))}...`;
}

// ─── Thai label mapping ───────────────────────────────────────────────────────
const KEY_LABELS: Record<string, string> = {
  booking_id:       "เลขออเดอร์",
  customer_id:      "รหัสลูกค้า",
  customer_name:    "ชื่อลูกค้า",
  merchant_id:      "รหัสร้าน",
  merchant_name:    "ชื่อร้านอาหาร",
  items:            "จำนวนเมนู",
  subtotal:         "ราคาอาหาร",
  delivery_fee:     "ค่าส่ง",
  total:            "ยอดรวม",
  payment_method:   "ชำระโดย",
  customer_address: "ที่อยู่ลูกค้า",
  scheduled_at:     "นัดหมาย",
  vehicle_type:     "ประเภทรถ",
  pickup:           "ต้นทาง",
  destination:      "ปลายทาง",
  distance_km:      "ระยะทาง",
  price:            "ราคา",
  pickup_surcharge: "ค่าธรรมเนียมรับ",
  sender_name:      "ชื่อผู้ส่ง",
  sender_phone:     "เบอร์ผู้ส่ง",
  recipient_name:   "ชื่อผู้รับ",
  recipient_phone:  "เบอร์ผู้รับ",
  parcel_size:      "ขนาดพัสดุ",
  driver_id:        "รหัสคนขับ",
  driver_name:      "ชื่อคนขับ",
  amount:           "จำนวนเงิน",
  bank_name:        "ธนาคาร",
  account_number:   "เลขบัญชี",
  account_name:     "ชื่อบัญชี",
  user_id:          "รหัสผู้ใช้",
  ticket_id:        "รหัสติ๊กเก็ต",
  subject:          "หัวข้อ",
  category:         "หมวดหมู่",
  priority:         "ความสำคัญ",
  service_type:     "ประเภทบริการ",
  status:           "สถานะ",
  email:            "อีเมล",
  name:             "ชื่อ",
  role:             "บทบาท",
  reason:           "เหตุผล",
};

// ─── Event-type emoji ─────────────────────────────────────────────────────────
const EVENT_EMOJI: Record<string, string> = {
  food_order_new:           "🍔",
  ride_order_new:           "🛵",
  parcel_order_new:         "📦",
  topup_request:            "💰",
  withdrawal_request:       "🏧",
  support_ticket_new:       "🎫",
  account_deletion_request: "🗑️",
  admin_alert:              "⚠️",
};

// Fields whose raw value is a UUID → show only last 8 chars
const UUID_FIELDS = new Set(["booking_id", "customer_id", "merchant_id", "driver_id", "user_id", "ticket_id"]);

// Fields to format as Thai Baht
const MONEY_FIELDS = new Set(["subtotal", "delivery_fee", "total", "price", "amount", "pickup_surcharge"]);

function formatFieldValue(key: string, value: unknown): string {
  const raw = String(value ?? "").trim();
  if (!raw || raw === "null" || raw === "undefined") return "";

  // Money → ฿1,234
  if (MONEY_FIELDS.has(key)) {
    const num = parseFloat(raw);
    if (!isNaN(num)) return `฿${num.toLocaleString("th-TH")}`;
  }

  // Distance → 12.50 กม.
  if (key === "distance_km") {
    const num = parseFloat(raw);
    if (!isNaN(num)) return `${num.toFixed(2)} กม.`;
  }

  // Items count → 3 รายการ
  if (key === "items") {
    return `${raw} รายการ`;
  }

  // Payment method → Thai label
  if (key === "payment_method") {
    const map: Record<string, string> = {
      cash:   "เงินสด",
      wallet: "กระเป๋าเงิน",
      online: "ออนไลน์",
      transfer: "โอนเงิน",
    };
    return map[raw.toLowerCase()] ?? raw;
  }

  // scheduled_at → human-readable Thai datetime
  if (key === "scheduled_at") {
    try {
      const d = new Date(raw);
      if (!isNaN(d.getTime())) {
        return d.toLocaleString("th-TH", { timeZone: "Asia/Bangkok" });
      }
    } catch { /* fall through */ }
  }

  // UUID fields → abbreviate
  if (UUID_FIELDS.has(key) && raw.length > 12) {
    return `…${raw.slice(-8)}`;
  }

  return truncateText(raw, 120);
}

function formatDataLines(data: unknown) {
  if (!data || typeof data !== "object" || Array.isArray(data)) return "";

  const entries = Object.entries(data as Record<string, unknown>)
    .map(([key, value]) => {
      const formatted = formatFieldValue(key, value);
      if (!formatted) return null;
      const label = KEY_LABELS[key] ?? key;
      return `  ${label}: ${formatted}`;
    })
    .filter(Boolean);

  if (!entries.length) return "";
  return entries.join("\n");
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
    error: userError,
  } = await supabaseAdmin.auth.getUser(token);
  if (userError || !user) {
    return { response: errorResponse("Invalid or expired token", 401) };
  }

  const { data: profile } = await supabaseAdmin
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .maybeSingle();

  return {
    user,
    role: profile?.role || null,
    supabaseAdmin,
  };
}

async function getLineConfig(supabaseAdmin: ReturnType<typeof createClient>): Promise<LineConfig> {
  const envTo = Deno.env.get("LINE_ADMIN_TO")?.trim() || null;

  try {
    const { data, error } = await supabaseAdmin
      .from("system_config")
      .select("admin_line_enabled, admin_line_recipient_id")
      .maybeSingle();
    if (error) throw error;

    const configuredTo = String(data?.admin_line_recipient_id || "").trim();
    return {
      enabled: data?.admin_line_enabled === true,
      to: configuredTo || envTo,
    };
  } catch (error) {
    console.warn("LINE config lookup failed, using env fallback:", error?.message || error);
    return { enabled: true, to: envTo };
  }
}

async function sendLinePush(to: string, text: string) {
  const accessToken = Deno.env.get("LINE_CHANNEL_ACCESS_TOKEN")?.trim();
  if (!accessToken) {
    return { success: false, status: 500, error: "LINE_CHANNEL_ACCESS_TOKEN not configured" };
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
  });

  const raw = await res.text();
  let data: unknown = null;
  try {
    data = raw ? JSON.parse(raw) : {};
  } catch {
    data = raw;
  }

  if (!res.ok) {
    console.error("LINE push error:", res.status, raw);
    return { success: false, status: res.status, error: data };
  }

  return { success: true, status: res.status, data };
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

    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return errorResponse("Invalid JSON body");
    }

    const isTest = body.test === true;
    if (isTest && auth.role !== "admin") {
      return errorResponse("Forbidden: admin role required", 403);
    }

    const config = await getLineConfig(auth.supabaseAdmin);
    const adminProvidedTo = auth.role === "admin" ? String(body.to || "").trim() : "";
    if (!config.enabled && !adminProvidedTo) {
      return jsonResponse({ success: true, provider: "line", skipped: "disabled" });
    }
    const targetTo = adminProvidedTo || config.to;
    if (!targetTo) {
      return errorResponse("Missing admin LINE recipient. Set admin_line_recipient_id or LINE_ADMIN_TO.", 400);
    }

    const title = truncateText(body.title || "JDC Admin Alert", 140);
    const message = truncateText(body.message || body.body || "", 2000);
    const eventType = truncateText(body.event_type || body.type || "admin_alert", 80);
    if (!message) {
      return errorResponse("Missing message");
    }

    const emoji = EVENT_EMOJI[eventType] ?? "🔔";
    const separator = "─".repeat(28);
    const details = formatDataLines(body.data);
    const timeStr = new Date().toLocaleString("th-TH", { timeZone: "Asia/Bangkok" });
    const text = [
      `${emoji} ${title}`,
      separator,
      message,
      separator,
      details ? `รายละเอียด:\n${details}` : "",
      `⏰ เวลา: ${timeStr}`,
    ].filter(Boolean).join("\n");

    const result = await sendLinePush(targetTo, text);
    if (!result.success) {
      return jsonResponse({ success: false, provider: "line", result }, result.status || 500);
    }

    return jsonResponse({ success: true, provider: "line", result });
  } catch (error) {
    console.error("send-admin-line unhandled error:", error);
    return jsonResponse(
      {
        error: error?.message || "send-admin-line failed",
      },
      500,
    );
  }
});
