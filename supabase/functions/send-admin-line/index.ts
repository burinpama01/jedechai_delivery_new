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
  if (!supabaseUrl || !serviceRoleKey) 