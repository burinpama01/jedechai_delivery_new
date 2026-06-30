// @ts-nocheck
// Supabase Edge Function: connect_set_shop_status
// StoreOS -> JDC shop open/close sync. Requires X-JDC-Connection-Key + HMAC headers.

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
    const { body } = auth;
    const merchantId = pickMerchantId(body);
    if (!merchantId) return withCors(errorResponse("Valid merchant_id is required"));
    const merchantCheck = await verifyConnectMerchant(supabaseAdmin, merchantId);
    if (!merchantCheck.ok) return withCors(errorResponse(merchantCheck.error, merchantCheck.status));

    if (typeof body.is_open !== "boolean") {
      return withCors(errorResponse("is_open boolean is required"));
    }

    const { data, error } = await supabaseAdmin
      .from("profiles")
      .update({
        shop_status: body.is_open,
        is_online: body.is_open,
      })
      .eq("id", merchantId)
      .select("id, shop_status, is_online")
      .maybeSingle();

    if (error) return withCors(errorResponse(error.message));
    if (!data) return withCors(errorResponse("Merchant profile not found", 404));

    return withCors(jsonResponse({
      success: true,
      merchant_id: merchantId,
      shop_status: data.shop_status,
      is_online: data.is_online,
    }));
  } catch (error) {
    console.error("connect_set_shop_status error:", error?.message || error);
    return withCors(errorResponse("Internal server error", 500));
  }
});
