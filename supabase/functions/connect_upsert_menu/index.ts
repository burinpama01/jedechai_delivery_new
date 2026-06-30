// @ts-nocheck
// Supabase Edge Function: connect_upsert_menu
// StoreOS -> JDC menu sync. Requires X-JDC-Connection-Key + HMAC headers.

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, errorResponse, jsonResponse } from "../_shared/admin-auth.ts";
import {
  authenticateConnectRequest,
  pickMerchantId,
  verifyConnectMerchant,
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

function adminClient() {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) return null;
  return createClient(supabaseUrl, serviceRoleKey);
}

function pickString(value: unknown): string | null {
  return typeof value === "string" && value.trim() !== "" ? value.trim() : null;
}

function pickNumber(value: unknown): number | null {
  if (typeof value === "number" && Number.isFinite(value)) return value;
  if (typeof value === "string" && value.trim() !== "" && Number.isFinite(Number(value))) {
    return Number(value);
  }
  return null;
}

function pickBool(value: unknown, fallback: boolean): boolean {
  return typeof value === "boolean" ? value : fallback;
}

serve(async (req) => {
  try {
    if (req.method === "OPTIONS") {
      return withCors(new Response(null, { status: 204, headers: corsHeaders }));
    }
    if (req.method !== "POST") {
      return withCors(errorResponse("Method not allowed", 405));
    }

    const supabaseAdmin = adminClient();
    if (!supabaseAdmin) return withCors(errorResponse("Server misconfigured", 500));

    const auth = await authenticateConnectRequest(req, supabaseAdmin);
    if (!auth.ok) return withCors(errorResponse(auth.error, auth.status));
    const { body, connection } = auth;
    const merchantId = pickMerchantId(body);
    if (!merchantId) return withCors(errorResponse("Valid merchant_id is required"));
    const merchantCheck = await verifyConnectMerchant(supabaseAdmin, merchantId);
    if (!merchantCheck.ok) return withCors(errorResponse(merchantCheck.error, merchantCheck.status));
    if (connection.menu_managed_by_pos === false) {
      return withCors(errorResponse("StoreOS menu sync is disabled", 403));
    }

    const items = Array.isArray(body.items) ? body.items : [];
    if (items.length === 0) return withCors(errorResponse("items is required"));

    const now = new Date().toISOString();
    const rows = [];
    for (const item of items) {
      const externalRef = pickString(item?.external_ref);
      const name = pickString(item?.name);
      const price = pickNumber(item?.price);
      if (!externalRef || !name || price === null || price < 0) {
        return withCors(errorResponse("Each item needs external_ref, name, and price"));
      }
      rows.push({
        merchant_id: merchantId,
        external_ref: externalRef,
        source: "storeos",
        name,
        description: pickString(item?.description),
        price,
        image_url: pickString(item?.image_url),
        is_available: pickBool(item?.is_available, true),
        category: pickString(item?.category),
        prep_time_minutes: pickNumber(item?.preparation_time) ?? pickNumber(item?.prep_time_minutes) ?? 15,
        updated_at: now,
      });
    }

    let disabled = 0;
    if (body.full_sync === true) {
      const refs = new Set(rows.map((row) => row.external_ref));
      const { data: existing, error: existingError } = await supabaseAdmin
        .from("menu_items")
        .select("id, external_ref")
        .eq("merchant_id", merchantId)
        .eq("source", "storeos");
      if (existingError) return withCors(errorResponse(existingError.message));

      const staleIds = (existing ?? [])
        .filter((row) => !refs.has(row.external_ref))
        .map((row) => row.id);
      if (staleIds.length > 0) {
        const { error: disableError } = await supabaseAdmin
          .from("menu_items")
          .update({ is_available: false, updated_at: now })
          .in("id", staleIds);
        if (disableError) return withCors(errorResponse(disableError.message));
        disabled = staleIds.length;
      }
    }

    const { data, error } = await supabaseAdmin
      .from("menu_items")
      .upsert(rows, { onConflict: "merchant_id,external_ref" })
      .select("id, external_ref");
    if (error) return withCors(errorResponse(error.message));

    await supabaseAdmin
      .from("pos_connections")
      .update({ last_menu_sync_at: now, updated_at: now })
      .eq("id", connection.id);

    return withCors(jsonResponse({
      success: true,
      upserted: data?.length ?? rows.length,
      disabled,
    }));
  } catch (error) {
    console.error("connect_upsert_menu error:", error?.message || error);
    return withCors(errorResponse("Internal server error", 500));
  }
});
