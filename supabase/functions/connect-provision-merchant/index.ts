// @ts-nocheck
// Supabase Edge Function: connect-provision-merchant
// Admin-only provisioning for StoreOS Connect credentials.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import {
  corsHeaders,
  errorResponse,
  jsonResponse,
  verifyAdmin,
} from "../_shared/admin-auth.ts";
import {
  generateConnectionKey,
  generateWebhookSecret,
  previewSecret,
} from "../_shared/connect-auth.ts";

function withCors(res: Response) {
  const headers = new Headers(res.headers);
  for (const [key, value] of Object.entries(corsHeaders)) {
    if (!headers.has(key)) headers.set(key, value);
  }
  return new Response(res.body, {
    status: res.status,
    statusText: res.statusText,
    headers,
  });
}

function pickString(value: unknown): string | null {
  return typeof value === "string" && value.trim() !== "" ? value.trim() : null;
}

function pickBool(value: unknown, fallback: boolean): boolean {
  return typeof value === "boolean" ? value : fallback;
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

function validateHttpsUrl(value: string | null): string | null {
  if (!value) return null;
  try {
    const url = new URL(value);
    if (url.protocol !== "https:") return null;
    return url.toString();
  } catch {
    return null;
  }
}

function shouldReturnSecret(existing: unknown, rotateSecret: boolean): boolean {
  return !existing || rotateSecret;
}

serve(async (req) => {
  try {
    if (req.method === "OPTIONS") {
      return withCors(new Response(null, { status: 204, headers: corsHeaders }));
    }

    if (req.method !== "POST") {
      return withCors(errorResponse("Method not allowed", 405));
    }

    const authResult = await verifyAdmin(req);
    if (authResult instanceof Response) return withCors(authResult);
    const { adminId, supabaseAdmin } = authResult;

    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return withCors(errorResponse("Invalid JSON body"));
    }

    const merchantId = pickString(body.merchant_id);
    if (!merchantId || !isUuid(merchantId)) {
      return withCors(errorResponse("Valid merchant_id is required"));
    }

    const storeosWebhookUrl = validateHttpsUrl(pickString(body.storeos_webhook_url));
    if (body.storeos_webhook_url && !storeosWebhookUrl) {
      return withCors(errorResponse("storeos_webhook_url must be HTTPS"));
    }

    const { data: merchant, error: merchantError } = await supabaseAdmin
      .from("profiles")
      .select("id, role")
      .eq("id", merchantId)
      .maybeSingle();
    if (merchantError) return withCors(errorResponse(merchantError.message));
    if (!merchant || merchant.role !== "merchant") {
      return withCors(errorResponse("Merchant profile not found", 404));
    }

    const { data: existing, error: existingError } = await supabaseAdmin
      .from("pos_connections")
      .select(
        "id, status, storeos_shop_id, storeos_webhook_url, jdc_connection_key, webhook_secret, menu_managed_by_pos, key_rotated_at, secret_rotated_at",
      )
      .eq("merchant_id", merchantId)
      .eq("provider", "storeos")
      .maybeSingle();
    if (existingError) return withCors(errorResponse(existingError.message));

    const rotateSecret = pickBool(body.rotate_secret, false);
    const rotateKey = pickBool(body.rotate_key, false);
    const now = new Date().toISOString();
    const jdcConnectionKey = existing && !rotateKey
      ? existing.jdc_connection_key
      : generateConnectionKey();
    const webhookSecret = existing && !rotateSecret
      ? existing.webhook_secret
      : generateWebhookSecret();
    const nextStatus = pickString(body.status) ?? existing?.status ?? "pending";

    if (!["pending", "active", "disabled", "revoked"].includes(nextStatus)) {
      return withCors(errorResponse("Invalid connection status"));
    }

    const payload = {
      merchant_id: merchantId,
      provider: "storeos",
      status: nextStatus,
      storeos_shop_id: pickString(body.storeos_shop_id) ?? existing?.storeos_shop_id ?? null,
      storeos_webhook_url: storeosWebhookUrl ?? existing?.storeos_webhook_url ?? null,
      jdc_connection_key: jdcConnectionKey,
      webhook_secret: webhookSecret,
      menu_managed_by_pos: pickBool(
        body.menu_managed_by_pos,
        existing?.menu_managed_by_pos ?? true,
      ),
      key_rotated_at: rotateKey || !existing ? now : existing.key_rotated_at,
      secret_rotated_at: rotateSecret || !existing ? now : existing.secret_rotated_at,
      created_by: existing?.id ? undefined : adminId,
      updated_by: adminId,
      updated_at: now,
    };

    const { data: saved, error: saveError } = await supabaseAdmin
      .from("pos_connections")
      .upsert(payload, { onConflict: "merchant_id,provider" })
      .select(
        "id, merchant_id, provider, status, storeos_shop_id, storeos_webhook_url, jdc_connection_key, menu_managed_by_pos, key_rotated_at, secret_rotated_at, updated_at",
      )
      .single();
    if (saveError) return withCors(errorResponse(saveError.message));

    const includeSecret = shouldReturnSecret(existing, rotateSecret);
    return withCors(jsonResponse({
      success: true,
      connection: {
        ...saved,
        secret_preview: previewSecret(webhookSecret),
      },
      webhook_secret: includeSecret ? webhookSecret : undefined,
      secret_returned: includeSecret,
    }));
  } catch (error) {
    console.error("connect-provision-merchant error:", error?.message || error);
    return withCors(errorResponse("Internal server error", 500));
  }
});
