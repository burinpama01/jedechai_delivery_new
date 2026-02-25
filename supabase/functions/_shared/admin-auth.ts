// Shared admin authentication helper for Edge Functions
// Verifies that the caller is an authenticated admin user

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
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
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY");

  if (!supabaseUrl || !serviceRoleKey || !anonKey) {
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
  const supabaseAuth = createClient(supabaseUrl, anonKey, {
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
 * Insert notification rows for admin actions.
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
  const { error } = await supabase.from("notifications").insert(validRows);
  if (error) {
    console.warn("Admin notification insert failed:", error.message);
  }
}
