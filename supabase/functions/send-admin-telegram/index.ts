// @ts-nocheck
// Supabase Edge Function: send-admin-telegram
// Sends Telegram Bot push notifications to the admin chat.
//
// Required secret:
//   supabase secrets set TELEGRAM_BOT_TOKEN=...
//
// Optional secret fallback when system_config is not available:
//   supabase secrets set TELEGRAM_ADMIN_CHAT_ID=...

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, errorResponse, jsonResponse } from "../_shared/admin-auth.ts";

type TelegramConfig = {
  enabled: boolean;
  chatId: string | null;
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
  account_deletion_request: "🗑",
  admin_alert:              "⚠",
};

const UUID_FIELDS = new Set(["booking_id", "customer_id", "merchant_id", "driver_id", "user_id", "ticket_id"]);
const MONEY_FIELDS = new Set(["subtotal", "delivery_fee", "total", "price", "amount", "pickup_surcharge"]);

function escapeHtml(text: string): string {
  return text
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;");
}

function formatFieldValue(key: string, value: unknown): string {
  const raw = String(value ?? "").trim();
  if (!raw || raw === "null" || raw === "undefined") return "";

  if (MONEY_FIELDS.has(key)) {
    const num = parseFloat(raw);
    if (!isNaN(num)) return `฿${num.toLocaleString("th-TH")}`;
  }

  if (key === "distance_km") {
    const num = parseFloat(raw);
    if (!isNaN(num)) return `${num.toFixed(2)} กม.`;
  }

  if (key === "items") return `${raw} รายการ`;

  if (key === "payment_method") {
    const map: Record<string, string> = {
      cash:     "เงินสด",
      wallet:   "กระเป๋าเงิน",
      online:   "ออนไลน์",
      transfer: "โอนเงิน",
    };
    return map[raw.toLowerCase()] ?? raw;
  }

  if (key === "scheduled_at") {
    try {
      const d = new Date(raw);
      if (!isNaN(d.getTime())) {
        return d.toLocaleString("th-TH", { timeZone: "Asia/Bangkok" });
      }
    } catch { /* fall through */ }
  }

  if (UUID_FIELDS.has(key) && raw.length > 12) {
    return `…${raw.slice(-8)}`;
  }

  return truncateText(raw, 120);
}

function formatDataLines(data: unknown): string {
  if (!data || typeof data !== "object" || Array.isArray(data)) return "";

  const entries = Object.entries(data as Record<string, unknown>)
    .map(([key, value]) => {
      const formatted = formatFieldValue(key, value);
      if (!formatted) return null;
      const label = KEY_LABELS[key] ?? key;
      return `  <b>${escapeHtml(label)}:</b> ${escapeHtml(formatted)}`;
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

async function getTelegramConfig(supabaseAdmin: ReturnType<typeof createClient>): Promise<TelegramConfig> {
  const envChatId = Deno.env.get("TELEGRAM_ADMIN_CHAT_ID")?.trim() || null;

  try {
    const { data, error } = await supabaseAdmin
      .from("system_config")
      .select("admin_telegram_enabled, admin_telegram_chat_id")
      .eq("id", 1)
      .maybeSingle();
    if (error) throw error;

    const configuredChatId = String(data?.admin_telegram_chat_id || "").trim();
    return {
      enabled: data?.admin_telegram_enabled === true,
      chatId: configuredChatId || envChatId,
    };
  } catch (error) {
    console.warn("Telegram config lookup failed, using env fallback:", error?.message || error);
    return { enabled: true, chatId: envChatId };
  }
}

async function sendTelegramMessage(chatId: string, text: string) {
  const botToken = Deno.env.get("TELEGRAM_BOT_TOKEN")?.trim();
  if (!botToken) {
    return { success: false, status: 500, error: "TELEGRAM_BOT_TOKEN not configured" };
  }

  const res = await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      chat_id: chatId,
      text: truncateText(text, 4096),
      parse_mode: "HTML",
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
    console.error("Telegram send error:", res.status, raw);
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

    const config = await getTelegramConfig(auth.supabaseAdmin);
    const adminProvidedChatId = auth.role === "admin" ? String(body.chat_id || "").trim() : "";
    if (!config.enabled && !adminProvidedChatId) {
      return jsonResponse({ success: true, provider: "telegram", skipped: "disabled" });
    }
    const targetChatId = adminProvidedChatId || config.chatId;
    if (!targetChatId) {
      return errorResponse("Missing admin Telegram chat ID. Set admin_telegram_chat_id or TELEGRAM_ADMIN_CHAT_ID.", 400);
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
      `${emoji} <b>${escapeHtml(title)}</b>`,
      separator,
      escapeHtml(message),
      separator,
      details ? `<b>รายละเอียด:</b>\n${details}` : "",
      `⏰ เวลา: ${timeStr}`,
    ].filter(Boolean).join("\n");

    const result = await sendTelegramMessage(targetChatId, text);
    if (!result.success) {
      return jsonResponse({ success: false, provider: "telegram", result }, result.status || 500);
    }

    return jsonResponse({ success: true, provider: "telegram", result });
  } catch (error) {
    console.error("send-admin-telegram unhandled error:", error);
    return jsonResponse(
      {
        error: error?.message || "send-admin-telegram failed",
      },
      500,
    );
  }
});
