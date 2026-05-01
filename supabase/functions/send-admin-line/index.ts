// @ts-nocheck
// Supabase Edge Function: send-admin-line
// Sends LINE Messaging API push notifications to the admin recipient.
//
// Required secret:
//   supabase secrets set LINE_CHANNEL_ACCESS_TOKEN=...
//
// Optional secret fallback when system_config is not available:
//   supabase secrets set LINE_ADMIN_TO=Uxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, errorResponse, jsonResponse } from "../_shared/admin-auth.ts";

type LineConfig = {
  enabled: boolean;
  to: string | null;
};

function bearerToken(req: Request) {
  const authorization =
    req.headers.get("authorization") ??
    req.headers.get("Authorization") ??
    "";
  return authorization.toLowerCase().startsWith("bearer ")
    ? authorization.slice(7).trim()
    : "";
}

function truncateText(value: unknown, maxLength: number) {
  const text = String(value ?? "").trim();
  if (text.length <= maxLength) return text;
  return `${text.slice(0, Math.max(0, maxLength - 3))}...`;
}

function formatDataLines(data: unknown) {
  if (!data || typeof data !== "object" || Array.isArray(data)) return "";
  const entries = Object.entries(data as Record<string, unknown>)
    .filter(([, value]) => value !== undefined && value !== null && value !== "")
    .slice(0, 8);
  if (!entries.length) return "";
  return entries
    .map(([key, value]) => `- ${key}: ${truncateText(value, 120)}`)
    .join("\n");
}

async function verifyUser(req: Request) {
  const supabaseUrl = Deno.env.get("SUPABASE_URL");
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!supabaseUrl || !serviceRoleKey) {
    return { response: errorResponse("Server misconfigured", 500) };
  }

  const token = bearerToken(req);
  if (!token) {
    return { response: errorResponse("Missing authorization token", 401) };
  }

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
  const {
    data: { user },
    error: userError,
  } = await supabaseAdmin.auth.getUser(token);
  if (userError || !user) {
    return { response: errorResponse("Invalid or expired token", 401) };
  }

  const { data: profile } = await supabaseAdmin
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .maybeSingle();

  return {
    user,
    role: profile?.role || null,
    supabaseAdmin,
  };
}

async function getLineConfig(supabaseAdmin: ReturnType<typeof createClient>): Promise<LineConfig> {
  const envTo = Deno.env.get("LINE_ADMIN_TO")?.trim() || null;

  try {
    const { data, error } = await supabaseAdmin
      .from("system_config")
      .select("admin_line_enabled, admin_line_recipient_id")
      .maybeSingle();
    if (error) throw error;

    const configuredTo = String(data?.admin_line_recipient_id || "").trim();
    return {
      enabled: data?.admin_line_enabled === true,
      to: configuredTo || envTo,
    };
  } catch (error) {
    console.warn("LINE config lookup failed, using env fallback:", error?.message || error);
    return { enabled: true, to: envTo };
  }
}

async function sendLinePush(to: string, text: string) {
  const accessToken = Deno.env.get("LINE_CHANNEL_ACCESS_TOKEN")?.trim();
  if (!accessToken) {
    return { success: false, status: 500, error: "LINE_CHANNEL_ACCESS_TOKEN not configured" };
  }

  const res = await fetch("https://api.line.me/v2/bot/message/push", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${accessToken}`,
      "X-Line-Retry-Key": crypto.randomUUID(),
    },
    body: JSON.stringify({
      to,
      messages: [{ type: "text", text: truncateText(text, 4900) }],
    }),
  });

  const raw = await res.text();
  let data: unknown = null;
  try {
    data = raw ? JSON.parse(raw) : {};
  } catch {
    data = raw;
  }

  if (!res.ok) {
    console.error("LINE push error:", res.status, raw);
    return { success: false, status: res.status, error: data };
  }

  return { success: true, status: res.status, data };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  try {
    const auth = await verifyUser(req);
    if (auth.response) return auth.response;

    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return errorResponse("Invalid JSON body");
    }

    const isTest = body.test === true;
    if (isTest && auth.role !== "admin") {
      return errorResponse("Forbidden: admin role required", 403);
    }

    const config = await getLineConfig(auth.supabaseAdmin);
    const adminProvidedTo = auth.role === "admin" ? String(body.to || "").trim() : "";
    if (!config.enabled && !adminProvidedTo) {
      return jsonResponse({ success: true, provider: "line", skipped: "disabled" });
    }
    const targetTo = adminProvidedTo || config.to;
    if (!targetTo) {
      return errorResponse("Missing admin LINE recipient. Set admin_line_recipient_id or LINE_ADMIN_TO.", 400);
    }

    const title = truncateText(body.title || "JDC Admin Alert", 140);
    const message = truncateText(body.message || body.body || "", 2000);
    const eventType = truncateText(body.event_type || body.type || "admin_alert", 80);
    if (!message) {
      return errorResponse("Missing message");
    }

    const details = formatDataLines(body.data);
    const text = [
      title,
      "",
      message,
      "",
      `Type: ${eventType}`,
      details ? `Details:\n${details}` : "",
      `Time: ${new Date().toLocaleString("th-TH", { timeZone: "Asia/Bangkok" })}`,
    ].filter(Boolean).join("\n");

    const result = await sendLinePush(targetTo, text);
    if (!result.success) {
      return jsonResponse({ success: false, provider: "line", result }, result.status || 500);
    }

    return jsonResponse({ success: true, provider: "line", result });
  } catch (error) {
    console.error("send-admin-line unhandled error:", error);
    return jsonResponse(
      {
        error: error?.message || "send-admin-line failed",
      },
      500,
    );
  }
});
