// @ts-nocheck
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, errorResponse, jsonResponse } from "../_shared/admin-auth.ts";

const SLIP2GO_ENDPOINT =
  "https://connect.slip2go.com/api/verify-slip/qr-image/info";
const AMOUNT_TOLERANCE = 0.01;
const MIN_TOPUP_AMOUNT = 20;
const MAX_TOPUP_AMOUNT = 50000;
const MAX_SLIP_IMAGE_BYTES = 8 * 1024 * 1024;
const RATE_LIMIT_WINDOW_MINUTES = 10;
const RATE_LIMIT_MAX_REQUESTS = 5;
const MANUAL_REVIEW_BUCKET = "topup-slips";
const ALLOWED_IMAGE_TYPES = new Set(["image/jpeg", "image/png", "image/webp"]);
const MIN_TRUSTED_RECEIVER_DIGITS = 9;
const MASKED_ACCOUNT_PATTERN = /[xX*]/;
const ADMIN_NOTIFICATION_TIMEOUT_MS = 3000;

function authToken(req: Request): string | null {
  const header =
    req.headers.get("authorization") ?? req.headers.get("Authorization") ?? "";
  const match = header.match(/^Bearer\s+(.+)$/i);
  return match?.[1]?.trim() || null;
}

function pickString(...vals: unknown[]): string | null {
  for (const value of vals) {
    if (typeof value === "string" && value.trim() !== "") {
      return value.trim();
    }
  }
  return null;
}

function pickNumber(...vals: unknown[]): number | null {
  for (const value of vals) {
    if (typeof value === "number" && Number.isFinite(value)) return value;
    if (
      typeof value === "string" &&
      value.trim() !== "" &&
      Number.isFinite(Number(value))
    ) {
      return Number(value);
    }
  }
  return null;
}

function parseSlip2goResponse(json: unknown) {
  const root = (json ?? {}) as Record<string, unknown>;
  const data = (root.data ?? root) as Record<string, unknown>;
  const amountObj = (data.amount ?? {}) as Record<string, unknown>;
  const receiver = (data.receiver ?? {}) as Record<string, unknown>;
  const receiverAccount = (receiver.account ?? {}) as Record<string, unknown>;
  const receiverProxy = (receiverAccount.proxy ?? {}) as Record<string, unknown>;
  const receiverBankAccount =
    (receiverAccount.bank ?? {}) as Record<string, unknown>;

  const code = pickString(root.code, data.code);
  const message = pickString(root.message, data.message);
  const ok =
    code === "200000" ||
    code === "200" ||
    message?.toLowerCase() === "success" ||
    data.success === true ||
    root.success === true;

  return {
    ok,
    code,
    message,
    amount: pickNumber(
      data.amount,
      amountObj.amount,
      amountObj.value,
      data.amountValue,
      data.transAmount,
    ),
    receiverName: pickString(
      receiver.displayName,
      receiver.name,
      receiverAccount.name,
      data.receiverName,
    ),
    receiverAccount: pickString(
      receiverProxy.account,
      receiverAccount.value,
      receiverAccount.account,
      receiverBankAccount.account,
      data.receiverAccount,
    ),
    transRef: pickString(
      data.transRef,
      data.transactionRef,
      data.transactionReference,
      data.ref,
      data.reference,
    ),
    raw: json,
  };
}

function normalizeDigits(value: string | null): string {
  return (value ?? "").replace(/\D/g, "");
}

function isTrustedReceiverAccount(value: string | null): boolean {
  const digits = normalizeDigits(value);
  if (digits.length < MIN_TRUSTED_RECEIVER_DIGITS) return false;
  return !MASKED_ACCOUNT_PATTERN.test(value ?? "");
}

function receiverMatchesTemporaryMaskedOverride(
  actual: string | null,
  expected: string | null,
  allowMaskedReceiver: boolean,
): boolean {
  if (!allowMaskedReceiver) return false;
  const actualText = (actual ?? "").trim().toLowerCase();
  const expectedText = (expected ?? "").trim().toLowerCase();
  if (!actualText || !expectedText) return false;
  if (!MASKED_ACCOUNT_PATTERN.test(actualText)) return false;
  if (!MASKED_ACCOUNT_PATTERN.test(expectedText)) return false;
  return actualText === expectedText;
}

function receiverMatches(actual: string | null, expected: string | null): boolean {
  const actualDigits = normalizeDigits(actual);
  const expectedDigits = normalizeDigits(expected);
  if (!expectedDigits) return true;
  if (!actualDigits) return false;
  return actualDigits === expectedDigits;
}

function base64ToBytes(value: string): Uint8Array {
  const clean = value.replace(/^data:[^;]+;base64,/, "");
  const binary = atob(clean);
  const bytes = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i++) {
    bytes[i] = binary.charCodeAt(i);
  }
  return bytes;
}

function normalizeContentType(value: string): string {
  const type = value.split(";")[0]?.trim().toLowerCase() || "image/jpeg";
  if (type === "image/jpg") return "image/jpeg";
  return type;
}

function slipExtension(contentType: string): string {
  if (contentType === "image/png") return "png";
  if (contentType === "image/webp") return "webp";
  return "jpg";
}

function shouldCreateManualReview(status: number | undefined): boolean {
  return status === 503 || status === 429 || (status ?? 0) >= 500;
}

async function verifySlipWithSlip2go(
  bytes: Uint8Array,
  contentType: string,
) {
  const apiKey = Deno.env.get("SLIP2GO_API_KEY");
  if (!apiKey) {
    return {
      ok: false,
      error: "ยังไม่ได้ตั้งค่า SLIP2GO_API_KEY",
      status: 503,
    };
  }

  const form = new FormData();
  const ext = slipExtension(contentType);
  form.set(
    "file",
    new Blob([bytes], { type: contentType || "image/jpeg" }),
    `topup-slip.${ext}`,
  );

  const res = await fetch(SLIP2GO_ENDPOINT, {
    method: "POST",
    headers: { Authorization: `Bearer ${apiKey}` },
    body: form,
  });
  const json = await res.json().catch(() => null);
  if (!res.ok) {
    return {
      ok: false,
      error: (json as Record<string, unknown> | null)?.message ??
        `Slip2Go HTTP ${res.status}`,
      status: res.status,
      raw: json,
    };
  }
  const parsed = parseSlip2goResponse(json);
  if (!parsed.ok) {
    return {
      ok: false,
      error: parsed.message ?? "Slip2Go verification failed",
      status: 422,
      raw: json,
      parsed,
    };
  }
  return { ok: true, parsed, raw: json };
}

async function logTopupRequest(supabaseAdmin, values: Record<string, unknown>) {
  const { data, error } = await supabaseAdmin
    .from("topup_requests")
    .insert(values)
    .select("id, status")
    .single();
  return { data, error };
}

async function uploadSlipEvidence(
  supabaseAdmin,
  userId: string,
  bytes: Uint8Array,
  contentType: string,
) {
  const path =
    `topup-slips/${userId}/${Date.now()}-${crypto.randomUUID()}.${slipExtension(contentType)}`;
  const { error } = await supabaseAdmin.storage
    .from(MANUAL_REVIEW_BUCKET)
    .upload(path, new Blob([bytes], { type: contentType }), {
      contentType,
      upsert: false,
    });
  if (error) {
    return { path: null, error: error.message };
  }
  return { path, error: null };
}

async function createManualReviewRequest(
  supabaseAdmin,
  args: {
    userId: string;
    amount: number;
    reason: string;
    message: string;
    bytes: Uint8Array;
    contentType: string;
    parsed?: Record<string, unknown> | null;
  },
) {
  const evidence = await uploadSlipEvidence(
    supabaseAdmin,
    args.userId,
    args.bytes,
    args.contentType,
  );
  if (evidence.error || !evidence.path) {
    return {
      data: null,
      error: {
        message:
          evidence.error ?? "topup slip evidence upload returned no path",
      },
      evidence,
    };
  }
  const parsed = args.parsed ?? {};
  const now = new Date().toISOString();
  const { data, error } = await logTopupRequest(supabaseAdmin, {
    user_id: args.userId,
    amount: args.amount,
    status: "pending",
    admin_note: args.message,
    verification_provider: "slip2go",
    verification_reason: args.reason,
    slip2go_code: parsed.code,
    slip2go_message: parsed.message,
    slip2go_trans_ref: parsed.transRef,
    verified_amount: parsed.amount,
    verified_receiver_name: parsed.receiverName,
    verified_receiver_account: parsed.receiverAccount,
    slip_image_path: evidence.path,
    verified_at: parsed.amount ? now : null,
  });

  return { data, error, evidence };
}

async function createRejectedSlipRequest(
  supabaseAdmin,
  args: {
    userId: string;
    amount: number;
    reason: string;
    message: string;
    bytes: Uint8Array;
    contentType: string;
    parsed?: Record<string, unknown> | null;
  },
) {
  const evidence = await uploadSlipEvidence(
    supabaseAdmin,
    args.userId,
    args.bytes,
    args.contentType,
  );
  if (evidence.error || !evidence.path) {
    return {
      data: null,
      error: {
        message:
          evidence.error ?? "topup rejected slip evidence upload returned no path",
      },
      evidence,
    };
  }

  const parsed = args.parsed ?? {};
  const now = new Date().toISOString();
  const { data, error } = await logTopupRequest(supabaseAdmin, {
    user_id: args.userId,
    amount: args.amount,
    status: "rejected",
    admin_note: args.message,
    processed_at: now,
    verification_provider: "slip2go",
    verification_reason: args.reason,
    slip2go_code: parsed.code,
    slip2go_message: parsed.message,
    slip2go_trans_ref: parsed.transRef,
    verified_amount: parsed.amount,
    verified_receiver_name: parsed.receiverName,
    verified_receiver_account: parsed.receiverAccount,
    slip_image_path: evidence.path,
    verified_at: now,
  });

  return { data, error, evidence };
}

async function countRecentSlipAttempts(supabaseAdmin, userId: string) {
  const since = new Date(
    Date.now() - RATE_LIMIT_WINDOW_MINUTES * 60 * 1000,
  ).toISOString();
  const { count, error } = await supabaseAdmin
    .from("topup_verification_attempts")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("provider", "slip2go")
    .gte("created_at", since);
  if (error) {
    console.warn("topup slip rate-limit query failed:", error.message);
    return 0;
  }
  return count ?? 0;
}

async function createVerificationAttempt(
  supabaseAdmin,
  userId: string,
  amount: number,
) {
  const { data, error } = await supabaseAdmin
    .from("topup_verification_attempts")
    .insert({
      user_id: userId,
      amount,
      provider: "slip2go",
      status: "started",
    })
    .select("id")
    .single();
  return { id: data?.id ?? null, error };
}

async function updateVerificationAttempt(
  supabaseAdmin,
  attemptId: string | null,
  values: {
    status: string;
    reason?: string | null;
    transRef?: string | null;
  },
) {
  if (!attemptId) return;
  const { error } = await supabaseAdmin
    .from("topup_verification_attempts")
    .update({
      status: values.status,
      reason: values.reason ?? null,
      slip2go_trans_ref: values.transRef ?? null,
    })
    .eq("id", attemptId);
  if (error) {
    console.warn("topup verification attempt update failed:", error.message);
  }
}

function truncateNotificationText(value: unknown, maxLength = 1900): string {
  const text = String(value ?? "").trim();
  if (text.length <= maxLength) return text;
  return `${text.slice(0, Math.max(0, maxLength - 3))}...`;
}

async function sendAdminLineNotification(to: string | null, text: string) {
  const accessToken = Deno.env.get("LINE_CHANNEL_ACCESS_TOKEN")?.trim();
  if (!to || !accessToken) return { success: true, skipped: "line_not_configured" };
  const res = await fetch("https://api.line.me/v2/bot/message/push", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${accessToken}`,
      "X-Line-Retry-Key": crypto.randomUUID(),
    },
    body: JSON.stringify({
      to,
      messages: [{ type: "text", text: truncateNotificationText(text, 4900) }],
    }),
    signal: AbortSignal.timeout(ADMIN_NOTIFICATION_TIMEOUT_MS),
  });
  if (!res.ok) {
    console.warn("topup LINE notification failed:", res.status, await res.text());
  }
  return { success: res.ok, status: res.status };
}

async function sendAdminTelegramNotification(chatId: string | null, text: string) {
  const botToken = Deno.env.get("TELEGRAM_BOT_TOKEN")?.trim();
  if (!chatId || !botToken) {
    return { success: true, skipped: "telegram_not_configured" };
  }
  const res = await fetch(`https://api.telegram.org/bot${botToken}/sendMessage`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      chat_id: chatId,
      text: truncateNotificationText(text, 4096),
    }),
    signal: AbortSignal.timeout(ADMIN_NOTIFICATION_TIMEOUT_MS),
  });
  if (!res.ok) {
    console.warn("topup Telegram notification failed:", res.status, await res.text());
  }
  return { success: res.ok, status: res.status };
}

async function notifyTopupVerificationEvent(
  supabaseAdmin,
  args: {
    eventType: string;
    title: string;
    message: string;
    amount: number;
    userId: string;
    requestId?: string | null;
    reason?: string | null;
    transRef?: string | null;
    receiverAccount?: string | null;
  },
) {
  try {
    const { data: config, error } = await supabaseAdmin
      .from("system_config")
      .select(
        "admin_line_enabled, admin_line_recipient_id, admin_telegram_enabled, admin_telegram_chat_id",
      )
      .eq("id", 1)
      .maybeSingle();
    if (error) {
      console.warn("topup notification config lookup failed:", error.message);
    }

    const lineTo = String(
      config?.admin_line_recipient_id || Deno.env.get("LINE_ADMIN_TO") || "",
    ).trim();
    const telegramChatId = String(
      config?.admin_telegram_chat_id ||
        Deno.env.get("TELEGRAM_ADMIN_CHAT_ID") ||
        "",
    ).trim();
    const details = [
      args.message,
      `amount: ${args.amount}`,
      `user_id: ${args.userId}`,
      args.requestId ? `request_id: ${args.requestId}` : "",
      args.reason ? `reason: ${args.reason}` : "",
      args.transRef ? `trans_ref: ${args.transRef}` : "",
      args.receiverAccount ? `receiver: ${args.receiverAccount}` : "",
    ].filter(Boolean).join("\n");
    const text = `${args.title}\n${details}`;

    const sends: Promise<unknown>[] = [];
    if (config?.admin_line_enabled === true || (!config && lineTo)) {
      sends.push(sendAdminLineNotification(lineTo, text));
    }
    if (config?.admin_telegram_enabled === true || (!config && telegramChatId)) {
      sends.push(sendAdminTelegramNotification(telegramChatId, text));
    }
    const results = await Promise.allSettled(sends);
    for (const result of results) {
      if (result.status === "rejected") {
        console.warn("topup notification channel failed:", result.reason);
      }
    }
  } catch (error) {
    console.warn("topup notification failed:", error?.message || error);
  }
}

async function manualReviewErrorResponse(
  supabaseAdmin,
  attemptId: string | null,
  reason: string,
  error,
  transRef?: string | null,
) {
  if (error?.code === "23505") {
    await updateVerificationAttempt(supabaseAdmin, attemptId, {
      status: "rejected",
      reason: "duplicateSlip",
      transRef,
    });
    return jsonResponse(
      {
        ok: false,
        status: "rejected",
        reason: "duplicateSlip",
        message: "สลิปซ้ำ เคยใช้เติมเงินแล้ว",
      },
      409,
    );
  }

  await updateVerificationAttempt(supabaseAdmin, attemptId, {
    status: "failed",
    reason,
    transRef,
  });
  return errorResponse(
    error?.message ?? "สร้างคำขอให้แอดมินตรวจสอบไม่สำเร็จ",
    500,
  );
}

serve(async (req) => {
  try {
    if (req.method === "OPTIONS") {
      return new Response("ok", { headers: corsHeaders });
    }
    if (req.method !== "POST") {
      return errorResponse("Method not allowed", 405);
    }

    const token = authToken(req);
    if (!token) return errorResponse("Unauthorized", 401);

    const supabaseUrl = Deno.env.get("SUPABASE_URL");
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
    if (!supabaseUrl || !serviceRoleKey) {
      return errorResponse("Missing Supabase service configuration", 500);
    }

    const supabaseAuth = createClient(supabaseUrl, serviceRoleKey, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });
    const { data: userData, error: userError } =
      await supabaseAuth.auth.getUser(token);
    if (userError || !userData?.user?.id) {
      return errorResponse("Unauthorized", 401);
    }

    const body = await req.json().catch(() => null);
    const amount = Number(body?.amount);
    const slipImageBase64 = body?.slipImageBase64;
    const contentType = normalizeContentType(
      String(body?.slipImageContentType || "image/jpeg"),
    );
    if (
      !Number.isFinite(amount) ||
      amount < MIN_TOPUP_AMOUNT ||
      amount > MAX_TOPUP_AMOUNT
    ) {
      return errorResponse("Invalid amount", 400);
    }
    if (typeof slipImageBase64 !== "string" || slipImageBase64.trim() === "") {
      return errorResponse("Missing slip image", 400);
    }
    if (!ALLOWED_IMAGE_TYPES.has(contentType)) {
      return errorResponse("Unsupported slip image type", 415);
    }

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
    let bytes: Uint8Array;
    try {
      bytes = base64ToBytes(slipImageBase64);
    } catch (_) {
      return errorResponse("Invalid slip image", 400);
    }
    if (bytes.length > MAX_SLIP_IMAGE_BYTES) {
      return errorResponse("Slip image is too large", 413);
    }

    const recentAttempts = await countRecentSlipAttempts(
      supabaseAdmin,
      userData.user.id,
    );
    if (recentAttempts >= RATE_LIMIT_MAX_REQUESTS) {
      return errorResponse("Too many topup slip attempts", 429);
    }
    const attempt = await createVerificationAttempt(
      supabaseAdmin,
      userData.user.id,
      amount,
    );
    if (attempt.error || !attempt.id) {
      return errorResponse(
        attempt.error?.message ?? "topup verification attempt log failed",
        500,
      );
    }
    const attemptId = attempt.id;

    const slip = await verifySlipWithSlip2go(bytes, contentType);
    if (!slip.ok) {
      if (shouldCreateManualReview(slip.status)) {
        const manualReview = await createManualReviewRequest(supabaseAdmin, {
          userId: userData.user.id,
          amount,
          reason: "manualReview",
          message:
            `Slip2Go unavailable (${slip.error}); pending admin manual review`,
          bytes,
          contentType,
          parsed: slip.parsed ?? null,
        });
        if (manualReview.error) {
          return await manualReviewErrorResponse(
            supabaseAdmin,
            attemptId,
            "manualReviewEvidenceUploadFailed",
            manualReview.error,
            slip.parsed?.transRef,
          );
        }
        await updateVerificationAttempt(supabaseAdmin, attemptId, {
          status: "pending_manual_review",
          reason: "manualReview",
          transRef: slip.parsed?.transRef,
        });
        await notifyTopupVerificationEvent(supabaseAdmin, {
          eventType: "topup_manual_review",
          title: "Topup manual review",
          message: "Automatic slip verification is unavailable",
          amount,
          userId: userData.user.id,
          requestId: manualReview.data?.id,
          reason: "manualReview",
          transRef: slip.parsed?.transRef,
          receiverAccount: slip.parsed?.receiverAccount,
        });
        return jsonResponse(
          {
            ok: false,
            status: "pending",
            reason: "manualReview",
            message:
              "ระบบตรวจสลิปอัตโนมัติยังไม่พร้อม ส่งคำขอให้แอดมินตรวจสอบแล้ว",
            request_id: manualReview.data?.id,
            slip_image_path: manualReview.evidence.path,
          },
          202,
        );
      }
      await updateVerificationAttempt(supabaseAdmin, attemptId, {
        status: "rejected",
        reason: "slip2go_failed",
        transRef: slip.parsed?.transRef,
      });
      return jsonResponse(
        {
          ok: false,
          status: "rejected",
          reason: "slip2go_failed",
          message: "สลิปนี้ไม่ผ่านการตรวจสอบอัตโนมัติ",
        },
        slip.status ?? 422,
      );
    }

    const parsed = slip.parsed;
    if (parsed.transRef) {
      const { data: duplicateSlip, error: duplicateLookupError } =
        await supabaseAdmin
        .from("topup_requests")
        .select("id, status")
        .eq("slip2go_trans_ref", parsed.transRef)
        .maybeSingle();
      if (duplicateLookupError) {
        await updateVerificationAttempt(supabaseAdmin, attemptId, {
          status: "failed",
          reason: "duplicateLookupFailed",
          transRef: parsed.transRef,
        });
        return errorResponse(
          "ตรวจสอบสลิปซ้ำไม่สำเร็จ กรุณาลองใหม่",
          500,
        );
      }
      if (duplicateSlip) {
        await updateVerificationAttempt(supabaseAdmin, attemptId, {
          status: "rejected",
          reason: "duplicateSlip",
          transRef: parsed.transRef,
        });
        return jsonResponse(
          {
            ok: false,
            status: "rejected",
            reason: "duplicateSlip",
            message: "สลิปซ้ำ เคยใช้เติมเงินแล้ว",
            request_id: duplicateSlip.id,
          },
          409,
        );
      }
    }

    const verifiedAmount = Number(parsed.amount ?? 0);
    const amountMismatch =
      !Number.isFinite(verifiedAmount) ||
      Math.abs(verifiedAmount - amount) > AMOUNT_TOLERANCE;
    if (amountMismatch) {
      const rejectedRequest = await createRejectedSlipRequest(supabaseAdmin, {
        userId: userData.user.id,
        amount,
        reason: "amountMismatch",
        message:
          `Slip2Go amount mismatch: expected ${amount}, got ${parsed.amount}`,
        bytes,
        contentType,
        parsed,
      });
      if (rejectedRequest.error) {
        return await manualReviewErrorResponse(
          supabaseAdmin,
          attemptId,
          "amountMismatchEvidenceUploadFailed",
          rejectedRequest.error,
          parsed.transRef,
        );
      }
      await updateVerificationAttempt(supabaseAdmin, attemptId, {
        status: "rejected",
        reason: "amountMismatch",
        transRef: parsed.transRef,
      });
      return jsonResponse(
        {
          ok: false,
          status: "rejected",
          reason: "amountMismatch",
          message: "ยอดเงินในสลิปไม่ตรงกับยอดเติมเงิน",
          request_id: rejectedRequest.data?.id,
          slip_image_path: rejectedRequest.evidence.path,
          verified_amount: parsed.amount,
        },
        422,
      );
    }

    const { data: config } = await supabaseAdmin
      .from("system_config")
      .select("slip2go_receiver_account, slip2go_allow_masked_receiver_account")
      .eq("id", 1)
      .maybeSingle();
    const expectedReceiver = config?.slip2go_receiver_account ?? null;
    const allowMaskedReceiver =
      config?.slip2go_allow_masked_receiver_account === true;
    const maskedReceiverAllowed = receiverMatchesTemporaryMaskedOverride(parsed.receiverAccount, expectedReceiver, allowMaskedReceiver);
    if (!normalizeDigits(expectedReceiver)) {
      const manualReview = await createManualReviewRequest(supabaseAdmin, {
        userId: userData.user.id,
        amount,
        reason: "receiverConfigMissing",
        message:
          "Slip2Go receiver account config is missing; pending admin manual review",
        bytes,
        contentType,
        parsed,
      });
      if (manualReview.error) {
        return await manualReviewErrorResponse(
          supabaseAdmin,
          attemptId,
          "receiverConfigMissingEvidenceUploadFailed",
          manualReview.error,
          parsed.transRef,
        );
      }
      await updateVerificationAttempt(supabaseAdmin, attemptId, {
        status: "pending_manual_review",
        reason: "receiverConfigMissing",
        transRef: parsed.transRef,
      });
      await notifyTopupVerificationEvent(supabaseAdmin, {
        eventType: "topup_manual_review",
        title: "Topup manual review",
        message: "Receiver config missing",
        amount,
        userId: userData.user.id,
        requestId: manualReview.data?.id,
        reason: "receiverConfigMissing",
        transRef: parsed.transRef,
        receiverAccount: parsed.receiverAccount,
      });
      return jsonResponse(
        {
          ok: false,
          status: "pending",
          reason: "receiverConfigMissing",
          message:
            "ยังไม่ได้ตั้งค่าบัญชีปลายทางสำหรับตรวจสลิป ส่งคำขอให้แอดมินตรวจสอบแล้ว",
          request_id: manualReview.data?.id,
          slip_image_path: manualReview.evidence.path,
        },
        202,
      );
    }
    if (!isTrustedReceiverAccount(expectedReceiver) && !maskedReceiverAllowed) {
      const manualReview = await createManualReviewRequest(supabaseAdmin, {
        userId: userData.user.id,
        amount,
        reason: "receiverConfigUntrusted",
        message:
          "Slip receiver account config is masked or too short; pending admin manual review",
        bytes,
        contentType,
        parsed,
      });
      if (manualReview.error) {
        return await manualReviewErrorResponse(
          supabaseAdmin,
          attemptId,
          "receiverConfigUntrustedEvidenceUploadFailed",
          manualReview.error,
          parsed.transRef,
        );
      }
      await updateVerificationAttempt(supabaseAdmin, attemptId, {
        status: "pending_manual_review",
        reason: "receiverConfigUntrusted",
        transRef: parsed.transRef,
      });
      await notifyTopupVerificationEvent(supabaseAdmin, {
        eventType: "topup_manual_review",
        title: "Topup manual review",
        message: "Receiver config is masked or too short",
        amount,
        userId: userData.user.id,
        requestId: manualReview.data?.id,
        reason: "receiverConfigUntrusted",
        transRef: parsed.transRef,
        receiverAccount: parsed.receiverAccount,
      });
      return jsonResponse(
        {
          ok: false,
          status: "pending",
          reason: "receiverConfigUntrusted",
          message:
            "บัญชีปลายทางที่ตั้งไว้ยังไม่ชัดเจนพอสำหรับตรวจอัตโนมัติ ส่งคำขอให้แอดมินตรวจสอบแล้ว",
          request_id: manualReview.data?.id,
          slip_image_path: manualReview.evidence.path,
        },
        202,
      );
    }
    if (!normalizeDigits(parsed.receiverAccount)) {
      const manualReview = await createManualReviewRequest(supabaseAdmin, {
        userId: userData.user.id,
        amount,
        reason: "receiverAccountMissing",
        message:
          "Slip receiver account is missing; pending admin manual review",
        bytes,
        contentType,
        parsed,
      });
      if (manualReview.error) {
        return await manualReviewErrorResponse(
          supabaseAdmin,
          attemptId,
          "receiverAccountMissingEvidenceUploadFailed",
          manualReview.error,
          parsed.transRef,
        );
      }
      await updateVerificationAttempt(supabaseAdmin, attemptId, {
        status: "pending_manual_review",
        reason: "receiverAccountMissing",
        transRef: parsed.transRef,
      });
      await notifyTopupVerificationEvent(supabaseAdmin, {
        eventType: "topup_manual_review",
        title: "Topup manual review",
        message: "Receiver account missing from slip",
        amount,
        userId: userData.user.id,
        requestId: manualReview.data?.id,
        reason: "receiverAccountMissing",
        transRef: parsed.transRef,
        receiverAccount: parsed.receiverAccount,
      });
      return jsonResponse(
        {
          ok: false,
          status: "pending",
          reason: "receiverAccountMissing",
          message:
            "ตรวจยอดเงินแล้ว แต่ข้อมูลบัญชีปลายทางในสลิปไม่ครบ ส่งคำขอให้แอดมินตรวจสอบแล้ว",
          request_id: manualReview.data?.id,
          slip_image_path: manualReview.evidence.path,
        },
        202,
      );
    }
    if (!isTrustedReceiverAccount(parsed.receiverAccount) && !maskedReceiverAllowed) {
      const manualReview = await createManualReviewRequest(supabaseAdmin, {
        userId: userData.user.id,
        amount,
        reason: "receiverAccountUntrusted",
        message:
          "Slip receiver account is masked or too short; pending admin manual review",
        bytes,
        contentType,
        parsed,
      });
      if (manualReview.error) {
        return await manualReviewErrorResponse(
          supabaseAdmin,
          attemptId,
          "receiverAccountUntrustedEvidenceUploadFailed",
          manualReview.error,
          parsed.transRef,
        );
      }
      await updateVerificationAttempt(supabaseAdmin, attemptId, {
        status: "pending_manual_review",
        reason: "receiverAccountUntrusted",
        transRef: parsed.transRef,
      });
      await notifyTopupVerificationEvent(supabaseAdmin, {
        eventType: "topup_manual_review",
        title: "Topup manual review",
        message: "Receiver account is masked or too short",
        amount,
        userId: userData.user.id,
        requestId: manualReview.data?.id,
        reason: "receiverAccountUntrusted",
        transRef: parsed.transRef,
        receiverAccount: parsed.receiverAccount,
      });
      return jsonResponse(
        {
          ok: false,
          status: "pending",
          reason: "receiverAccountUntrusted",
          message:
            "ตรวจยอดเงินแล้ว แต่บัญชีปลายทางในสลิปยังไม่ชัดเจนพอสำหรับตรวจอัตโนมัติ ส่งคำขอให้แอดมินตรวจสอบแล้ว",
          request_id: manualReview.data?.id,
          slip_image_path: manualReview.evidence.path,
        },
        202,
      );
    }
    if (
      !receiverMatches(parsed.receiverAccount, expectedReceiver) &&
      !maskedReceiverAllowed
    ) {
      const rejectedRequest = await createRejectedSlipRequest(supabaseAdmin, {
        userId: userData.user.id,
        amount,
        reason: "receiverMismatch",
        message: "Slip2Go receiver account mismatch",
        bytes,
        contentType,
        parsed,
      });
      if (rejectedRequest.error) {
        return await manualReviewErrorResponse(
          supabaseAdmin,
          attemptId,
          "receiverMismatchEvidenceUploadFailed",
          rejectedRequest.error,
          parsed.transRef,
        );
      }
      await updateVerificationAttempt(supabaseAdmin, attemptId, {
        status: "rejected",
        reason: "receiverMismatch",
        transRef: parsed.transRef,
      });
      return jsonResponse(
        {
          ok: false,
          status: "rejected",
          reason: "receiverMismatch",
          message: "บัญชีผู้รับในสลิปไม่ตรงกับบัญชีระบบ",
          request_id: rejectedRequest.data?.id,
          slip_image_path: rejectedRequest.evidence.path,
        },
        422,
      );
    }

    if (!parsed.transRef) {
      const manualReview = await createManualReviewRequest(supabaseAdmin, {
        userId: userData.user.id,
        amount,
        reason: "missingTransRef",
        message:
          "Slip2Go verified but transRef is missing; pending admin manual review",
        bytes,
        contentType,
        parsed,
      });
      if (manualReview.error) {
        return await manualReviewErrorResponse(
          supabaseAdmin,
          attemptId,
          "missingTransRefEvidenceUploadFailed",
          manualReview.error,
        );
      }
      await updateVerificationAttempt(supabaseAdmin, attemptId, {
        status: "pending_manual_review",
        reason: "missingTransRef",
      });
      await notifyTopupVerificationEvent(supabaseAdmin, {
        eventType: "topup_manual_review",
        title: "Topup manual review",
        message: "Verified slip is missing transRef",
        amount,
        userId: userData.user.id,
        requestId: manualReview.data?.id,
        reason: "missingTransRef",
        receiverAccount: parsed.receiverAccount,
      });
      return jsonResponse(
        {
          ok: false,
          status: "pending",
          reason: "missingTransRef",
          message:
            "ตรวจสลิปได้แต่ไม่มีเลขอ้างอิงธุรกรรม ส่งคำขอให้แอดมินตรวจสอบแล้ว",
          request_id: manualReview.data?.id,
          slip_image_path: manualReview.evidence.path,
        },
        202,
      );
    }

    const now = new Date().toISOString();
    const autoEvidence = await uploadSlipEvidence(
      supabaseAdmin,
      userData.user.id,
      bytes,
      contentType,
    );
    if (autoEvidence.error || !autoEvidence.path) {
      return await manualReviewErrorResponse(
        supabaseAdmin,
        attemptId,
        "autoCompletedEvidenceUploadFailed",
        {
          message:
            autoEvidence.error ?? "topup auto slip evidence upload returned no path",
        },
        parsed.transRef,
      );
    }
    const { data: request, error: insertError } = await logTopupRequest(
      supabaseAdmin,
      {
        user_id: userData.user.id,
        amount,
        status: "pending",
        admin_note: "Slip2Go verified; wallet credit pending",
        verification_provider: "slip2go",
        slip2go_code: parsed.code,
        slip2go_message: parsed.message,
        slip2go_trans_ref: parsed.transRef,
        verified_amount: parsed.amount,
        verified_receiver_name: parsed.receiverName,
        verified_receiver_account: parsed.receiverAccount,
        slip_image_path: autoEvidence.path,
        verified_at: now,
      },
    );
    if (insertError) {
      await updateVerificationAttempt(supabaseAdmin, attemptId, {
        status: "failed",
        reason: insertError.code === "23505" ? "duplicateSlip" : "logFailed",
        transRef: parsed.transRef,
      });
      return jsonResponse(
        {
          ok: false,
          status: "rejected",
          reason: insertError.code === "23505" ? "duplicateSlip" : "logFailed",
          message: insertError.message,
        },
        insertError.code === "23505" ? 409 : 500,
      );
    }

    const { data: completion, error: completionError } = await supabaseAdmin.rpc(
      "complete_topup_request",
      {
        p_description: `เติมเงินผ่าน Slip2Go (${parsed.transRef ?? "no-ref"})`,
        p_admin_note: "Slip2Go auto verified and credited",
        p_request_id: request.id,
      },
    );
    if (completionError || completion?.success !== true) {
      await updateVerificationAttempt(supabaseAdmin, attemptId, {
        status: "pending_manual_review",
        reason: "walletTopupFailed",
        transRef: parsed.transRef,
      });
      await supabaseAdmin
        .from("topup_requests")
        .update({
          admin_note:
            `Slip2Go verified but complete_topup_request failed: ${completionError?.message ?? completion?.error ?? "unknown"}`,
          updated_at: new Date().toISOString(),
        })
        .eq("id", request.id);
      await notifyTopupVerificationEvent(supabaseAdmin, {
        eventType: "topup_manual_review",
        title: "Topup manual review",
        message: "Wallet credit failed after slip verification",
        amount,
        userId: userData.user.id,
        requestId: request.id,
        reason: "walletTopupFailed",
        transRef: parsed.transRef,
        receiverAccount: parsed.receiverAccount,
      });
      return jsonResponse(
        {
          ok: false,
          status: "pending",
          reason: "walletTopupFailed",
          message: "ตรวจสลิปผ่านแล้ว แต่เติม wallet ไม่สำเร็จ รอแอดมินตรวจสอบ",
          request_id: request.id,
        },
        500,
      );
    }

    await updateVerificationAttempt(supabaseAdmin, attemptId, {
      status: "completed",
      reason: "autoCompleted",
      transRef: parsed.transRef,
    });

    await notifyTopupVerificationEvent(supabaseAdmin, {
      eventType: "topup_auto_credit",
      title: "Topup auto-credit completed",
      message: "Slip verified and wallet credited automatically",
      amount,
      userId: userData.user.id,
      requestId: request.id,
      reason: maskedReceiverAllowed ? "autoCompletedMaskedReceiver" : "autoCompleted",
      transRef: parsed.transRef,
      receiverAccount: parsed.receiverAccount,
    });

    return jsonResponse({
      ok: true,
      status: "completed",
      request_id: request.id,
      verified_amount: parsed.amount,
      slip2go_trans_ref: parsed.transRef,
      wallet: completion.wallet,
    });
  } catch (e) {
    console.error("verify-topup-slip error:", e);
    return errorResponse(
      e instanceof Error ? e.message : "verify-topup-slip failed",
      500,
    );
  }
});
