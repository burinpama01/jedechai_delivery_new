// @ts-nocheck
// Beam Checkout client (https://docs.beamcheckout.com)
// - Auth: HTTP Basic base64(merchantId:apiKey)
// - Amount: satang (THB × 100)
// - Webhook: X-Beam-Signature = base64(HMAC-SHA256(base64decode(hmacKey), rawBody))
// Credentials live in public.payment_gateway_settings (service role only).

export const BEAM_BASE_URLS: Record<string, string> = {
  playground: "https://playground.api.beamcheckout.com",
  production: "https://api.beamcheckout.com",
};

const REQUEST_TIMEOUT_MS = 15_000;

export type BeamSettings = {
  environment: "playground" | "production";
  merchant_id: string | null;
  api_key: string | null;
  webhook_hmac_key: string | null;
  qr_expiry_minutes: number;
  last_test_at: string | null;
  last_test_ok: boolean | null;
  last_test_message: string | null;
  updated_at: string | null;
};

export async function loadBeamSettings(supabaseAdmin): Promise<BeamSettings | null> {
  const { data, error } = await supabaseAdmin
    .from("payment_gateway_settings")
    .select("*")
    .eq("provider", "beam")
    .maybeSingle();
  if (error) throw new Error(`load_beam_settings_failed: ${error.message}`);
  return data ?? null;
}

export function isBeamConfigured(s: BeamSettings | null): boolean {
  return !!(s && s.merchant_id && s.api_key);
}

export function maskSecret(value: string | null | undefined): string | null {
  if (!value) return null;
  const v = String(value);
  return v.length <= 4 ? "••••" : `••••${v.slice(-4)}`;
}

function authHeader(merchantId: string, apiKey: string): string {
  return "Basic " + btoa(`${merchantId}:${apiKey}`);
}

async function beamFetch(
  s: { environment: string; merchant_id: string; api_key: string },
  path: string,
  init: RequestInit = {},
): Promise<{ status: number; json: any; text: string }> {
  const base = BEAM_BASE_URLS[s.environment] ?? BEAM_BASE_URLS.playground;
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), REQUEST_TIMEOUT_MS);
  try {
    const res = await fetch(`${base}${path}`, {
      ...init,
      signal: controller.signal,
      headers: {
        Authorization: authHeader(s.merchant_id, s.api_key),
        "Content-Type": "application/json",
        Accept: "application/json",
        ...(init.headers ?? {}),
      },
    });
    const text = await res.text();
    let json = null;
    try {
      json = text ? JSON.parse(text) : null;
    } catch {
      json = null;
    }
    return { status: res.status, json, text };
  } finally {
    clearTimeout(timer);
  }
}

/** สร้าง Charge แบบ QR PromptPay — คืน chargeId + รูป QR (base64 PNG) */
export async function createQrPromptPayCharge(
  s: BeamSettings,
  params: { amountSatang: number; referenceId: string; expiresAt: Date; idempotencyKey: string },
) {
  const res = await beamFetch(s as any, "/api/v1/charges", {
    method: "POST",
    headers: { "x-beam-idempotency-key": params.idempotencyKey },
    body: JSON.stringify({
      amount: params.amountSatang,
      currency: "THB",
      referenceId: params.referenceId,
      paymentMethod: {
        paymentMethodType: "QR_PROMPT_PAY",
        qrPromptPay: { expiryTime: params.expiresAt.toISOString() },
      },
    }),
  });
  if (res.status < 200 || res.status >= 300 || !res.json?.chargeId) {
    throw new Error(`beam_create_charge_failed: HTTP ${res.status} ${res.text.slice(0, 300)}`);
  }
  return {
    chargeId: String(res.json.chargeId),
    qrImageBase64: res.json?.encodedImage?.imageBase64Encoded ?? null,
    qrRawData: res.json?.encodedImage?.rawData ?? null,
    expiresAt: res.json?.encodedImage?.expiry ?? params.expiresAt.toISOString(),
  };
}

/** ดึงสถานะ Charge: PENDING | SUCCEEDED | FAILED */
export async function getCharge(s: BeamSettings, chargeId: string) {
  const res = await beamFetch(s as any, `/api/v1/charges/${encodeURIComponent(chargeId)}`, {
    method: "GET",
  });
  if (res.status < 200 || res.status >= 300) {
    throw new Error(`beam_get_charge_failed: HTTP ${res.status} ${res.text.slice(0, 300)}`);
  }
  return {
    status: String(res.json?.status ?? "PENDING").toUpperCase(),
    amount: Number(res.json?.amount),
    referenceId: res.json?.referenceId ?? null,
    failureCode: res.json?.failureCode ?? null,
  };
}

/**
 * ทดสอบการเชื่อมต่อ: Beam ไม่มี endpoint read-only สำหรับเช็คคีย์
 * จึงเรียก GET charge ด้วย id ที่ไม่มีอยู่จริง
 *   401/403 → คีย์ไม่ถูกต้อง, 404/400/2xx → เชื่อมต่อและยืนยันตัวตนผ่าน
 */
export async function testBeamConnection(s: {
  environment: string;
  merchant_id: string;
  api_key: string;
}): Promise<{ ok: boolean; message: string; httpStatus: number | null }> {
  try {
    const res = await beamFetch(s, "/api/v1/charges/ch_jdc_connection_test", { method: "GET" });
    if (res.status === 401 || res.status === 403) {
      return { ok: false, httpStatus: res.status, message: `คีย์ไม่ถูกต้อง (HTTP ${res.status})` };
    }
    if (res.status >= 500) {
      return { ok: false, httpStatus: res.status, message: `Beam ขัดข้อง (HTTP ${res.status})` };
    }
    return {
      ok: true,
      httpStatus: res.status,
      message: `เชื่อมต่อ Beam (${s.environment}) สำเร็จ — ยืนยันตัวตนผ่าน (HTTP ${res.status})`,
    };
  } catch (e) {
    const msg = e?.name === "AbortError" ? "หมดเวลาเชื่อมต่อ" : (e?.message ?? String(e));
    return { ok: false, httpStatus: null, message: `เชื่อมต่อไม่ได้: ${msg}` };
  }
}

function base64ToBytes(b64: string): Uint8Array {
  const bin = atob(b64.trim());
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

function bytesToBase64(bytes: Uint8Array): string {
  let bin = "";
  for (const b of bytes) bin += String.fromCharCode(b);
  return btoa(bin);
}

export function isValidBase64Key(value: string): boolean {
  try {
    return base64ToBytes(value).length >= 16;
  } catch {
    return false;
  }
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let diff = 0;
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i);
  return diff === 0;
}

export async function computeBeamSignature(hmacKeyB64: string, rawBody: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    base64ToBytes(hmacKeyB64),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const sig = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(rawBody));
  return bytesToBase64(new Uint8Array(sig));
}

export async function verifyBeamSignature(
  hmacKeyB64: string,
  rawBody: string,
  signatureHeader: string | null,
): Promise<boolean> {
  if (!signatureHeader || !hmacKeyB64) return false;
  try {
    const expected = await computeBeamSignature(hmacKeyB64, rawBody);
    return timingSafeEqual(expected, signatureHeader.trim());
  } catch {
    return false;
  }
}

/** เช็คสถานะกับ Beam แล้วเติมเงิน/ปิดคำขอ — ใช้ร่วมกับ webhook ได้อย่างปลอดภัย (idempotent) */
export async function syncBeamTopup(supabaseAdmin, settings: BeamSettings, request) {
  if (request.status === "completed") return { status: "completed" };
  if (!request.beam_charge_id) return { status: request.status };

  const charge = await getCharge(settings, request.beam_charge_id);

  if (charge.status === "SUCCEEDED") {
    const { data, error } = await supabaseAdmin.rpc("complete_beam_topup", {
      p_charge_id: request.beam_charge_id,
      p_paid_satang: Number.isFinite(charge.amount) ? Math.round(charge.amount) : null,
    });
    if (error) throw new Error(`complete_beam_topup_failed: ${error.message}`);
    if (data?.success !== true) {
      return { status: "manual_review", reason: data?.error ?? "unknown" };
    }
    return { status: "completed", wallet: data?.wallet ?? null };
  }

  if (charge.status === "FAILED") {
    await supabaseAdmin
      .from("topup_requests")
      .update({
        status: "failed",
        admin_note: `Beam charge failed: ${charge.failureCode ?? "-"}`,
        updated_at: new Date().toISOString(),
      })
      .eq("id", request.id)
      .eq("status", "awaiting_payment");
    return { status: "failed", reason: charge.failureCode ?? null };
  }

  // PENDING — ถ้าเลยเวลาหมดอายุ QR แล้ว ให้ปิดเป็น expired (ยังเติมได้ถ้า Beam ยืนยันภายหลัง)
  if (
    request.status === "awaiting_payment" &&
    request.beam_expires_at &&
    new Date(request.beam_expires_at).getTime() < Date.now()
  ) {
    await supabaseAdmin
      .from("topup_requests")
      .update({ status: "expired", updated_at: new Date().toISOString() })
      .eq("id", request.id)
      .eq("status", "awaiting_payment");
    return { status: "expired" };
  }
  return { status: request.status === "expired" ? "expired" : "awaiting_payment" };
}

