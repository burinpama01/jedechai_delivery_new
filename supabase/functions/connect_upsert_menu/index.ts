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

// #12: option_groups from StoreOS (variants + modifiers).
// Strategy: replace the full storeos-sourced option set per menu item.
function parseOptionGroups(value: unknown): Array<{
  name: string;
  min_selection: number;
  max_selection: number;
  options: Array<{ name: string; price: number; is_available: boolean }>;
}> | null {
  if (value === undefined) return null; // field absent → leave existing options untouched
  if (!Array.isArray(value)) return [];
  const groups = [];
  for (const raw of value) {
    const name = pickString(raw?.name);
    if (!name) continue;
    const min = pickNumber(raw?.min_selection) ?? 0;
    const max = pickNumber(raw?.max_selection) ?? 1;
    const options = [];
    for (const opt of Array.isArray(raw?.options) ? raw.options : []) {
      const optName = pickString(opt?.name);
      if (!optName) continue;
      // JDC menu_options.price is integer baht — round StoreOS decimals
      const price = Math.max(0, Math.round(pickNumber(opt?.price) ?? 0));
      options.push({
        name: optName,
        price,
        is_available: pickBool(opt?.is_available, true),
      });
    }
    if (options.length === 0) continue;
    groups.push({
      name,
      min_selection: Math.max(0, Math.round(min)),
      max_selection: Math.max(1, Math.round(max)),
      options,
    });
  }
  return groups;
}

// Replace storeos-sourced option groups for one menu item (delete cascade removes
// menu_options + menu_item_option_links), then recreate from the payload.
async function replaceStoreosOptionGroups(
  supabaseAdmin: any,
  menuItemId: string,
  merchantId: string,
  groups: NonNullable<ReturnType<typeof parseOptionGroups>>,
): Promise<string | null> {
  const { data: links, error: linkError } = await supabaseAdmin
    .from("menu_item_option_links")
    .select("option_group_id, menu_option_groups!inner(id, source)")
    .eq("menu_item_id", menuItemId)
    .eq("menu_option_groups.source", "storeos");
  if (linkError) return linkError.message;

  const staleGroupIds = (links ?? []).map((row: any) => row.option_group_id);
  if (staleGroupIds.length > 0) {
    const { error: deleteError } = await supabaseAdmin
      .from("menu_option_groups")
      .delete()
      .in("id", staleGroupIds);
    if (deleteError) return deleteError.message;
  }

  for (let i = 0; i < groups.length; i++) {
    const group = groups[i];
    // merchant_id is NOT NULL in prod; source='storeos' still marks these as
    // sync-owned (edits in JDC get replaced on the next sync).
    const { data: created, error: groupError } = await supabaseAdmin
      .from("menu_option_groups")
      .insert({
        merchant_id: merchantId,
        name: group.name,
        min_selection: group.min_selection,
        max_selection: group.max_selection,
        source: "storeos",
      })
      .select("id")
      .single();
    if (groupError || !created) return groupError?.message ?? "create option group failed";

    const { error: optionsError } = await supabaseAdmin
      .from("menu_options")
      .insert(group.options.map((opt) => ({
        group_id: created.id,
        name: opt.name,
        price: opt.price,
        is_available: opt.is_available,
      })));
    if (optionsError) return optionsError.message;

    const { error: linkInsertError } = await supabaseAdmin
      .from("menu_item_option_links")
      .insert({
        menu_item_id: menuItemId,
        option_group_id: created.id,
        sort_order: i,
      });
    if (linkInsertError) return linkInsertError.message;
  }

  return null;
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
    // #12: external_ref → parsed option_groups (null = field absent, leave as-is)
    const optionGroupsByRef = new Map<string, ReturnType<typeof parseOptionGroups>>();
    for (const item of items) {
      const externalRef = pickString(item?.external_ref);
      const name = pickString(item?.name);
      const price = pickNumber(item?.price);
      if (!externalRef || !name || price === null || price < 0) {
        return withCors(errorResponse("Each item needs external_ref, name, and price"));
      }
      optionGroupsByRef.set(externalRef, parseOptionGroups(item?.option_groups));
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

    // #12: sync option groups (variants/modifiers) per menu item
    let optionGroupsSynced = 0;
    const optionErrors: string[] = [];
    for (const row of data ?? []) {
      const groups = optionGroupsByRef.get(row.external_ref);
      if (groups === null || groups === undefined) continue; // payload didn't carry the field
      const syncError = await replaceStoreosOptionGroups(supabaseAdmin, row.id, merchantId, groups);
      if (syncError) {
        optionErrors.push(`${row.external_ref}: ${syncError}`);
      } else {
        optionGroupsSynced += groups.length;
      }
    }

    await supabaseAdmin
      .from("pos_connections")
      .update({ last_menu_sync_at: now, updated_at: now })
      .eq("id", connection.id);

    return withCors(jsonResponse({
      success: true,
      upserted: data?.length ?? rows.length,
      disabled,
      option_groups_synced: optionGroupsSynced,
      ...(optionErrors.length > 0 ? { option_group_errors: optionErrors.slice(0, 5) } : {}),
    }));
  } catch (error) {
    console.error("connect_upsert_menu error:", error?.message || error);
    return withCors(errorResponse("Internal server error", 500));
  }
});
