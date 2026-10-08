// Supabase Edge Function: send-admin-email
// ส่งอีเมลจากหลังบ้าน (ปุ่ม "ทดสอบอีเมล" ใน admin-web Settings)
//
// ISSUE-20261008-001: เดิมผู้ใช้ที่ล็อกอินคนไหนก็ได้ส่ง `to`/`html` เอง = open relay
// ตอนนี้เรียกได้เฉพาะแอดมิน (verifyAdmin) — แจ้งเตือนแอดมินจากเหตุการณ์ในระบบ
// ให้ไปทางคิว notify-admin-events (server อ่านปลายทางจาก system_config_private เอง)
//
// วิธี deploy:
//   supabase functions deploy send-admin-email

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { corsHeaders, errorResponse, jsonResponse, verifyAdmin } from "../_shared/admin-auth.ts";

// In-memory rate limiter per admin (ต่อ instance — พอสำหรับปุ่มทดสอบของแอดมิน)
const rateLimitMap = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT_MAX = 5; // max 5 emails per minute per admin
const RATE_LIMIT_WINDOW_MS = 60_000; // 1 minute
const EMAIL_PATTERN = /^[^\s@<>,;]+@[^\s@<>,;]+\.[^\s@<>,;]+$/;

function isRateLimited(userId: string): boolean {
  const now = Date.now();
  let entry = rateLimitMap.get(userId);
  if (!entry || now > entry.resetAt) {
    entry = { count: 0, resetAt: now + RATE_LIMIT_WINDOW_MS };
    rateLimitMap.set(userId, entry);
  }
  entry.count++;
  return entry.count > RATE_LIMIT_MAX;
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // 1. แอดมินเท่านั้น
    const auth = await verifyAdmin(req);
    if (auth instanceof Response) return auth;

    // 2. Check Rate Limiting
    if (isRateLimited(auth.adminId)) {
      return errorResponse("Too many email requests. Please wait a minute.", 429);
    }

    const { to, subject, html } = await req.json();
    const recipient = typeof to === "string" ? to.trim() : "";

    if (!recipient || !subject) {
      return errorResponse("Missing required fields: to, subject", 400);
    }
    if (!EMAIL_PATTERN.test(recipient)) {
      return errorResponse("Invalid recipient email", 400);
    }

    // ส่งอีเมลผ่าน Resend API
    const resendApiKey = Deno.env.get("RESEND_API_KEY");
    if (resendApiKey) {
      const res = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${resendApiKey}`,
        },
        body: JSON.stringify({
          from: Deno.env.get("RESEND_FROM") || "Jedechai Admin <noreply@jedechai.com>",
          to: [recipient],
          subject,
          html: html || subject,
        }),
      });

      const data = await res.json();
      // ไม่ log ทั้งก้อน — response ของ Resend มีอีเมลผู้รับ
      console.log("Resend response:", res.status, data?.id ?? data?.name ?? "");

      return jsonResponse({ success: true, provider: "resend", data });
    }

    console.log(`📧 Email not sent (no RESEND_API_KEY): admin=${auth.adminId}`);
    return jsonResponse({
      success: true,
      provider: "queue",
      message: "Email queued (no email provider configured). Set RESEND_API_KEY to enable.",
    });
  } catch (error) {
    console.error("Error:", error);
    return errorResponse((error as Error)?.message || "internal_error", 500);
  }
});
