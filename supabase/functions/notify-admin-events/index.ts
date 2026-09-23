// notify-admin-events — drain admin_event_external_queue → Telegram/LINE
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

  // อ่าน config ช่องทางครั้งเดียวต่อ batch
  const { data: config } = await supabase
    .from("system_config")
    .select("admin_telegram_enabled, admin_telegram_chat_id, admin_line_enabled, admin_line_recipient_id")
    .limit(1)
    .maybeSingle();

  const telegramChatId = config?.admin_telegram_enabled === true
    ? (String(config?.admin_telegram_chat_id || "").trim() ||
      Deno.env.get("TELEGRAM_ADMIN_CHAT_ID")?.trim() || "")
    : "";
  const lineTo = config?.admin_line_enabled === true
    ? (String(config?.admin_line_recipient_id || "").trim() ||
      Deno.env.get("LINE_ADMIN_TO")?.trim() || "")
    : "";

  let sent = 0;
  let failed = 0;
  let skippedNoChannel = 0;

  for (const event of rows) {
    const text = `🔔 ${event.title}\n${event.body}`;
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

    if (!telegramChatId && !lineTo) {
      // ไม่มีช่องทางเปิดอยู่ — ปิดงานเลย กันคิวค้าง/วนซ้ำไม่รู้จบ
      await supabase.rpc("mark_admin_external_event", {
        p_id: event.id,
        p_error: null,
      });
      skippedNoChannel += 1;
      continue;
    }

    if (delivered) {
      await supabase.rpc("mark_admin_external_event", { p_id: event.id, p_error: null });
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
    channels: { telegram: !!telegramChatId, line: !!lineTo },
  });
});
