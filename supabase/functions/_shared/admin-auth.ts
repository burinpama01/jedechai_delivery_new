// Shared admin authentication helper for Edge Functions
// Verifies that the caller is an authenticated admin user

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Max-Age": "86400",
};

export function jsonResponse(body: Record<string, unknown>, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

export function errorResponse(message: string, status = 400) {
  return jsonResponse({ error: message }, status);
}

/**
 * Verifies the request comes from an authenticated admin user.
 * Returns { adminId, supabaseAdmin } on success, or a Response on failure.
 */
export async function verifyAdmin(
  req: Request,
): Promise<
  | { adminId: string; supabaseAdmin: SupabaseClient; supabaseAuth: SupabaseClient }
  | Response
> {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");

  if (!supabaseUrl || !serviceRoleKey) {
    return errorResponse("Server misconfigured", 500);
  }

  // Extract the user's JWT from the Authorization header
  const authorization =
    req.headers.get("authorization") ??
    req.headers.get("Authorization") ??
    "";
  const token = authorization.toLowerCase().startsWith("bearer ")
    ? authorization.slice(7).trim()
    : "";

  if (!token) {
    return errorResponse("Missing authorization token", 401);
  }

  // Create an auth client to verify the user's JWT
  // Use service role key to avoid failures when SUPABASE_ANON_KEY is missing/mismatched.
  const supabaseAuth = createClient(supabaseUrl, serviceRoleKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });

  const {
    data: { user },
    error: userError,
  } = await supabaseAuth.auth.getUser(token);

  if (userError || !user) {
    return errorResponse("Invalid or expired token", 401);
  }

  // Create a service-role client for privileged operations
  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

  // Verify the user has admin role
  const { data: profile, error: profileError } = await supabaseAdmin
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .single();

  if (profileError || profile?.role !== "admin") {
    return errorResponse("Forbidden: admin role required", 403);
  }

  return { adminId: user.id, supabaseAdmin, supabaseAuth };
}

/**
 * Insert notification rows for admin actions and trigger FCM push.
 * DB insert failure only warns — FCM is still attempted independently.
 */
export async function notifyTargets(
  supabase: SupabaseClient,
  rows: Array<{
    user_id: string;
    title: string;
    body: string;
    type: string;
    data?: Record<string, unknown>;
  }>,
) {
  const validRows = rows.filter((r) => r.user_id && r.title && r.body);
  if (!validRows.length) return;

  // Insert into DB (in-app notifications)
  const { error: dbError } = await supabase.from("notifications").insert(validRows);
  if (dbError) {
    console.warn("Admin notification insert failed:", dbError.message);
  }

  // Send FCM push for each notification — use service role key as bearer
  const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  if (!supabaseUrl || !serviceRoleKey) return;

  for (const row of validRows) {
    try {
      await fetch(`${supabaseUrl}/functions/v1/send-fcm-notification`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `Bearer ${serviceRoleKey}`,
        },
        body: JSON.stringify({
          user_ids: [row.user_id],
          title: row.title,
          message: row.body,
          data: row.data as Record<string, string> | undefined,
          persist_in_app: false,
        }),
      });
    } catch (e) {
      console.warn(`FCM push failed for user ${row.user_id}:`, e);
    }
  }
}
