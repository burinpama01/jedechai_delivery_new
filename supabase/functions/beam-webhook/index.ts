// @ts-nocheck
// Supabase Edge Function: beam-webhook
// รับ webhook จาก Beam Checkout (ตั้ง URL นี้ใน Beam Lighthouse → Developers → Webhook Settings)
//
// ความปลอดภัย:
// 1) ตรวจ X-Beam-Signature (HMAC-SHA256 ด้วย Webhook HMAC Key) กับ raw body — ไม่ผ่าน = 401
// 2) ไม่เชื่อสถานะ/ยอดใน payload — ดึง charge จาก Beam อีกครั้ง (syncBeamTopup) แล้วค่อยเติมเงิน
// 3) เติมเงินผ่าน RPC complete_beam_topup (idempotent + ตรวจยอด satang)

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { loadBeamSettings, syncBeamTopup, verifyBeamSignature } from "../_shared/beam.ts";

const HANDLED_EVENTS = new Set(["charge.succeeded", "charge.failed"]);
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

function reply(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

serve(async (req) => {
  if (req.method !== "POST") return reply({ error: "Method not allowed" }, 405);

  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) return reply({ error: "Server misconfigured" }, 500);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  const rawBody = await req.text();

  let settings;
  try {
    settings = await loadBeamSettings(supabaseAdmin);
  } catch (e) {
    console.error("beam-webhook settings error:", e);
    return reply({ error: "settings_unavailable" }, 500); // Beam จะ retry
  }
  if (!settings?.webhook_hmac_key || !settings?.merchant_id || !settings?.api_key) {
    console.error("beam-webhook: Beam not configured (missing HMAC key or API credentials)");
    return reply({ error: "not_configured" }, 503);
  }

  const signature = req.headers.get("x-beam-signature");
  if (!(await verifyBeamSignature(settings.webhook_hmac_key, rawBody, signature))) {
    return reply({ error: "invalid_signature" }, 401);
  }

  const eventType = (req.headers.get("x-beam-event") ?? "").toLowerCase();
  if (!HANDLED_EVENTS.has(eventType)) {
    return reply({ ok: true, ignored: eventType || "unknown" });
  }

  let payload;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return reply({ error: "invalid_json" }, 400);
  }
  if (payload?.merchantId && payload.merchantId !== settings.merchant_id) {
    return reply({ ok: true, ignored: "other_merchant" });
  }

  const chargeId = typeof payload?.chargeId === "string" ? payload.chargeId : null;
  if (!chargeId) return reply({ ok: true, ignored: "no_charge_id" });

  const columns = "id, user_id, status, amount, beam_charge_id, beam_expires_at, payment_provider";
  let { data: request } = await supabaseAdmin
    .from("topup_requests")
    .select(columns)
    .eq("beam_charge_id", chargeId)
    .maybeSingle();

  // สำรอง: บันทึก chargeId ไม่ทันตอนสร้าง → หาจาก referenceId = topup_<request uuid>
  if (!request) {
    const ref = typeof payload?.referenceId === "string" ? payload.referenceId : "";
    const requestId = ref.startsWith("topup_") ? ref.slice("topup_".length) : "";
    if (UUID_RE.test(requestId)) {
      await supabaseAdmin
        .from("topup_requests")
        .update({ beam_charge_id: chargeId, updated_at: new Date().toISOString() })
        .eq("id", requestId)
        .eq("payment_provider", "beam")
        .is("beam_charge_id", null);
      ({ data: request } = await supabaseAdmin
        .from("topup_requests")
        .select(columns)
        .eq("beam_charge_id", chargeId)
        .maybeSingle());
    }
  }

  if (!request || request.payment_provider !== "beam") {
    console.warn("beam-webhook: no topup request for charge", chargeId);
    return reply({ ok: true, ignored: "unknown_charge" });
  }

  try {
    const result = await syncBeamTopup(supabaseAdmin, settings, request);
    return reply({ ok: true, request_id: request.id, ...result });
  } catch (e) {
    console.error("beam-webhook sync error:", e);
    return reply({ error: "sync_failed" }, 500); // ให้ Beam retry
  }
});
