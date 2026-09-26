// notify-admin-events — drain admin_event_external_queue → Telegram/LINE (+ อีเมลเฉพาะเรื่องสมาชิกใหม่)
//
// อีเมล: event ใน EMAIL_EVENT_TYPES → system_config.admin_notification_email (+ _cc)
//   ผ่าน Resend (env RESEND_API_KEY, RESEND_FROM) · ไม่มีคีย์/อีเมล = ข้ามช่องนี้
// ลิงก์: data.admin_page → ADMIN_WEB_URL (env, ค่าเริ่มต้น production) + ?page=<หน้า>
//
// เรียกโดย pg_cron ทุกนาที (migration 20260718234500) ด้วย header x-cron-secret
// เทียบกับ secret: supabase secrets set ADMIN_EVENTS_CRON_SECRET=...
// ช่องทางส่งใช้ config เดียวกับ send-admin-telegram / send-admin-line:
//   system_config.admin_telegram_enabled + admin_telegram_chat_id (+ env TELEGRAM_ADMIN_CHAT_ID fallback)
//   system_config.admin_line_enabled + admin_line_recipient_id (+ env LINE_ADMIN_TO fallback)
//   tokens: env TELEGRAM_BOT_TOKEN / LINE_CHANNEL_ACCESS_TOKEN
// claim-pattern: RPC claim_admin_external_events (FOR UPDATE SKIP LOCKED,
// retry สูงสุด 5 ครั้ง, re-claim ได้หลัง 5 นาที) → mark_admin_external_event
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  adminPageLink,
  EMAIL_EVENT_TYPES,
  formatChatText,
  formatEmail,
  parseEmailList,
} from "../_shared/admin-event-format.ts";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type, x-cron-secret",
};

function json(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

type QueueRow = {
  id: string;
  title: string;
  body: string;
  event_type: string;
  data: Record<string, unknown> | null;
};

async function sendTelegram(chatId: string, text: string) {
  const botToken = Deno.env.get("TELEGRAM_BOT_TOKEN")?.trim();
  if (!botToken) return { ok: false, error: "TELEGRAM_BOT_TOKEN not configured" };
  try {
    const res = await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ chat_id: chatId, text }),
    });
    const data = await res.json().catch(() => null);
    if (!res.ok || data?.ok === false) {
      return { ok: false, error: `telegram_${res.status}:${data?.description || ""}` };
    }
    return { ok: true };
  } catch (e) {
    return { ok: false, error: `telegram_fetch:${(e as Error)?.message || e}` };
  }
}

async function sendLine(to: string, text: string) {
  const accessToken = Deno.env.get("LINE_CHANNEL_ACCESS_TOKEN")?.trim();
  if (!accessToken) return { ok: false, error: "LINE_CHANNEL_ACCESS_TOKEN not configured" };
  try {
    const res = await fetch("https://api.line.me/v2/bot/message/push", {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({ to, messages: [{ type: "text", text }] }),
    });
    if (!res.ok) {
      const errText = await res.text().catch(() => "");
      return { ok: false, error: `line_${res.status}:${errText.slice(0, 120)}` };
    }
    return { ok: true };
  } catch (e) {
    return { ok: false, error: `line_fetch:${(e as Error)?.message || e}` };
  }
}

async function sendEmail(to: string[], subject: string, html: string) {
  const apiKey = Deno.env.get("RESEND_API_KEY")?.trim();
  if (!apiKey) return { ok: false, error: "RESEND_API_KEY not configured" };
  try {
    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: { "Content-Type": "application/json", Authorization: `Bearer ${apiKey}` },
      body: JSON.stringify({
        from: Deno.env.get("RESEND_FROM") || "Jedechai Admin <noreply@jedechai.com>",
        to,
        subject,
        html,
      }),
    });
    if (!res.ok) {
      const errText = await res.text().catch(() => "");
      return { ok: false, error: `email_${res.status}:${errText.slice(0, 120)}` };
    }
    return { ok: true };
  } catch (e) {
    return { ok: false, error: `email_fetch:${(e as Error)?.message || e}` };
  }
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") return json(405, { error: "Method not allowed" });

  const expected = Deno.env.get("ADMIN_EVENTS_CRON_SECRET")?.trim() ?? "";
  const provided = req.headers.get("x-cron-secret")?.trim() ?? "";
  if (!expected || provided !== expected) {
    return json(401, { error: "unauthorized" });
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceRoleKey) {
    return json(500, { error: "missing service configuration" });
  }
  const supabase = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false },
  });

  const { data: events, error: claimError } = await supabase.rpc(
    "claim_admin_external_events",
    { p_limit: 20 },
  );
  if (claimError) return json(500, { error: claimError.message });

  const rows = (events || []) as QueueRow[];
  if (!rows.length) return json(200, { success: true, drained: 0 });

  // อ่าน config ช่องทางครั้งเดียวต่อ batch — แถว id=1 เท่านั้น (ตารางมีแถว key/value ปนอยู่
  // limit(1) เดิมได้แถวอื่นที่ช่องทางเป็น false ทั้งหมด → ปิดงานเงียบโดยไม่ส่ง)
  const { data: config, error: configError } = await supabase
    .from("system_config")
    .select("admin_telegram_enabled, admin_telegram_chat_id, admin_line_enabled, admin_line_recipient_id, admin_notification_email, admin_notification_email_cc")
    .eq("id", 1)
    .maybeSingle();
  if (configError) return json(500, { error: `config: ${configError.message}` });

  const telegramChatId = config?.admin_telegram_enabled === true
    ? (String(config?.admin_telegram_chat_id || "").trim() ||
      Deno.env.get("TELEGRAM_ADMIN_CHAT_ID")?.trim() || "")
    : "";
  const lineTo = config?.admin_line_enabled === true
    ? (String(config?.admin_line_recipient_id || "").trim() ||
      Deno.env.get("LINE_ADMIN_TO")?.trim() || "")
    : "";

  const emailTo = Deno.env.get("RESEND_API_KEY")?.trim()
    ? parseEmailList(config?.admin_notification_email, config?.admin_notification_email_cc)
    : [];
  const adminWebUrl = Deno.env.get("ADMIN_WEB_URL")?.trim() || undefined;

  let sent = 0;
  let failed = 0;
  let skippedNoChannel = 0;

  for (const event of rows) {
    const link = adminPageLink(event, adminWebUrl);
    const text = formatChatText(event, link);
    const useEmail = emailTo.length > 0 && EMAIL_EVENT_TYPES.has(event.event_type);
    const errors: string[] = [];
    let delivered = false;

    if (telegramChatId) {
      const r = await sendTelegram(telegramChatId, text);
      if (r.ok) delivered = true;
      else errors.push(r.error || "telegram_failed");
    }
    if (lineTo) {
      const r = await sendLine(lineTo, text);
      if (r.ok) delivered = true;
      else errors.push(r.error || "line_failed");
    }

    if (useEmail) {
      const mail = formatEmail(event, link);
      const r = await sendEmail(emailTo, mail.subject, mail.html);
      if (r.ok) delivered = true;
      else errors.push(r.error || "email_failed");
    }

    if (!telegramChatId && !lineTo && !useEmail) {
      // ไม่มีช่องทางเปิดอยู่ — ปิดงานเลย กันคิวค้าง/วนซ้ำไม่รู้จบ แต่บันทึกไว้ว่าไม่ได้ส่ง
      await supabase.rpc("mark_admin_external_event", {
        p_id: event.id,
        p_error: null,
      });
      await supabase.from("admin_event_external_queue")
        .update({ last_error: "no_channel: ไม่มีช่องทางที่เปิดใช้งาน (ไม่ได้ส่ง)" })
        .eq("id", event.id);
      skippedNoChannel += 1;
      continue;
    }

    if (delivered) {
      await supabase.rpc("mark_admin_external_event", { p_id: event.id, p_error: null });
      // ส่งถึงอย่างน้อย 1 ช่อง = ปิดงาน (ไม่ retry ซ้ำช่องที่ส่งแล้ว) แต่เก็บ error ช่องที่ล้มไว้ตรวจย้อนหลัง
      if (errors.length) {
        await supabase.from("admin_event_external_queue")
          .update({ last_error: `partial: ${errors.join(" | ")}`.slice(0, 500) })
          .eq("id", event.id);
      }
      sent += 1;
    } else {
      await supabase.rpc("mark_admin_external_event", {
        p_id: event.id,
        p_error: errors.join(" | ") || "send_failed",
      });
      failed += 1;
    }
  }

  return json(200, {
    success: true,
    drained: rows.length,
    sent,
    failed,
    skipped_no_channel: skippedNoChannel,
    channels: { telegram: !!telegramChatId, line: !!lineTo, email: emailTo.length > 0 },
  });
});
