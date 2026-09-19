// @ts-nocheck
// Supabase Edge Function: beam-topup
// เติมเงิน Wallet ผ่าน Beam Checkout (QR PromptPay) — ใช้เมื่อ system_config.topup_mode = 'beam'
//
// POST { action: "create", amount }      → สร้างคำขอ + Beam charge คืนรูป QR
// POST { action: "status", request_id }  → เช็คสถานะกับ Beam (สำรองกรณี webhook มาช้า) และเติมเงินถ้าจ่ายแล้ว
//
// ต้องแนบ JWT ของผู้ใช้ (verify_jwt = false ใน config — ตรวจเองในโค้ด)

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, errorResponse, jsonResponse } from "../_shared/admin-auth.ts";
import {
  createQrPromptPayCharge,
  isBeamConfigured,
  loadBeamSettings,
  syncBeamTopup,
} from "../_shared/beam.ts";

const MIN_TOPUP_AMOUNT = 20;
const MAX_TOPUP_AMOUNT = 50000;
const RATE_LIMIT_WINDOW_MINUTES = 10;
const RATE_LIMIT_MAX_REQUESTS = 5;
// action "status" ยิง Beam API ทุกครั้ง — จำกัดต่อผู้ใช้ (ต่อ instance ของ function)
const STATUS_LIMIT_PER_MINUTE = 30;
const _statusCalls = new Map<string, { count: number; resetAt: number }>();

function allowStatusCall(userId: string): boolean {
  const now = Date.now();
  let entry = _statusCalls.get(userId);
  if (!entry || now > entry.resetAt) {
    entry = { count: 0, resetAt: now + 60_000 };
    _statusCalls.set(userId, entry);
  }
  entry.count++;
  return entry.count <= STATUS_LIMIT_PER_MINUTE;
}

function authToken(req: Request): string | null {
  const header = req.headers.get("authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

async function currentTopupMode(supabaseAdmin): Promise<string> {
  const { data } = await supabaseAdmin
    .from("system_config")
    .select("topup_mode")
    .is("key", null)
    .order("id", { ascending: true })
    .limit(1)
    .maybeSingle();
  return data?.topup_mode ?? "admin_approve";
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) return errorResponse("Server misconfigured", 500);

    const token = authToken(req);
    if (!token) return errorResponse("Unauthorized", 401);

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey, {
      auth: { persistSession: false, autoRefreshToken: false },
    });
    const { data: userData, error: userError } = await supabaseAdmin.auth.getUser(token);
    if (userError || !userData?.user) return errorResponse("Unauthorized", 401);
    const userId = userData.user.id;

    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return errorResponse("Invalid JSON body");
    }
    const action = String(body.action ?? "");

    const settings = await loadBeamSettings(supabaseAdmin);
    if (!isBeamConfigured(settings)) {
      return jsonResponse({ ok: false, reason: "beam_not_configured" }, 503);
    }

    // ── status ──
    if (action === "status") {
      if (!allowStatusCall(userId)) {
        return jsonResponse({ ok: false, reason: "rate_limited" }, 429);
      }
      const requestId = String(body.request_id ?? "");
      if (!requestId) return errorResponse("Missing 'request_id'");
      const { data: request } = await supabaseAdmin
        .from("topup_requests")
        .select("id, user_id, status, amount, beam_charge_id, beam_expires_at, payment_provider")
        .eq("id", requestId)
        .maybeSingle();
      if (!request || request.user_id !== userId || request.payment_provider !== "beam") {
        return errorResponse("Not found", 404);
      }
      const result = await syncBeamTopup(supabaseAdmin, settings, request);
      return jsonResponse({ ok: true, request_id: request.id, amount: request.amount, ...result });
    }

    // ── create ──
    if (action !== "create") return errorResponse("Unknown action");

    if ((await currentTopupMode(supabaseAdmin)) !== "beam") {
      return jsonResponse({ ok: false, reason: "beam_disabled" }, 409);
    }

    const amount = Number(body.amount);
    if (
      !Number.isFinite(amount) ||
      amount < MIN_TOPUP_AMOUNT ||
      amount > MAX_TOPUP_AMOUNT ||
      Math.round(amount * 100) !== amount * 100
    ) {
      return jsonResponse(
        { ok: false, reason: "invalid_amount", min: MIN_TOPUP_AMOUNT, max: MAX_TOPUP_AMOUNT },
        400,
      );
    }

    const since = new Date(Date.now() - RATE_LIMIT_WINDOW_MINUTES * 60_000).toISOString();
    const { count } = await supabaseAdmin
      .from("topup_requests")
      .select("id", { count: "exact", head: true })
      .eq("user_id", userId)
      .eq("payment_provider", "beam")
      .gte("created_at", since);
    if ((count ?? 0) >= RATE_LIMIT_MAX_REQUESTS) {
      return jsonResponse({ ok: false, reason: "rate_limited" }, 429);
    }

    const expiresAt = new Date(Date.now() + (settings.qr_expiry_minutes ?? 15) * 60_000);
    const { data: request, error: insertError } = await supabaseAdmin
      .from("topup_requests")
      .insert({
        user_id: userId,
        amount,
        status: "awaiting_payment",
        payment_provider: "beam",
        beam_environment: settings.environment,
        beam_expires_at: expiresAt.toISOString(),
      })
      .select("id")
      .single();
    if (insertError || !request) {
      return errorResponse(`create_request_failed: ${insertError?.message ?? "unknown"}`, 500);
    }

    let charge;
    try {
      charge = await createQrPromptPayCharge(settings, {
        amountSatang: Math.round(amount * 100),
        referenceId: `topup_${request.id}`,
        expiresAt,
        idempotencyKey: request.id,
      });
    } catch (e) {
      await supabaseAdmin
        .from("topup_requests")
        .update({
          status: "failed",
          admin_note: String(e?.message ?? e).slice(0, 500),
          updated_at: new Date().toISOString(),
        })
        .eq("id", request.id);
      console.error("beam-topup create charge error:", e);
      return jsonResponse({ ok: false, reason: "beam_charge_failed" }, 502);
    }

    await supabaseAdmin
      .from("topup_requests")
      .update({
        beam_charge_id: charge.chargeId,
        beam_expires_at: charge.expiresAt,
        updated_at: new Date().toISOString(),
      })
      .eq("id", request.id);

    return jsonResponse({
      ok: true,
      request_id: request.id,
      amount,
      charge_id: charge.chargeId,
      qr_image_base64: charge.qrImageBase64,
      qr_raw_data: charge.qrRawData,
      expires_at: charge.expiresAt,
      environment: settings.environment,
    });
  } catch (e) {
    console.error("beam-topup error:", e);
    return errorResponse("beam-topup failed", 500);
  }
});
