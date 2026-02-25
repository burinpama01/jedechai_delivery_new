// @ts-nocheck
// Phase 3D: Edge Function for sending FCM notifications
// Moves Firebase Service Account credentials server-side
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import {
  verifyAdmin,
  corsHeaders,
  jsonResponse,
  errorResponse,
} from "../_shared/admin-auth.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Google OAuth2 token cache
let _cachedAccessToken: string | null = null;
let _tokenExpiresAt = 0;

async function getAccessToken(): Promise<string> {
  const now = Date.now();
  if (_cachedAccessToken && _tokenExpiresAt > now + 60_000) {
    return _cachedAccessToken;
  }

  const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT_JSON");
  if (!serviceAccountJson) {
    throw new Error("FIREBASE_SERVICE_ACCOUNT_JSON not configured");
  }

  const sa = JSON.parse(serviceAccountJson);
  const iat = Math.floor(now / 1000);
  const exp = iat + 3600;

  // Create JWT for Google OAuth2
  const header = btoa(JSON.stringify({ alg: "RS256", typ: "JWT" }))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

  const claim = btoa(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat,
    exp,
  })).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

  const signInput = `${header}.${claim}`;

  // Import private key and sign
  const pemContents = sa.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "");
  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8", binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false, ["sign"],
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signInput),
  );

  const sig = btoa(String.fromCharCode(...new Uint8Array(signature)))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");

  const jwt = `${signInput}.${sig}`;

  // Exchange JWT for access token
  const tokenRes = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${jwt}`,
  });

  const tokenData = await tokenRes.json();
  if (!tokenData.access_token) {
    throw new Error("Failed to get access token: " + JSON.stringify(tokenData));
  }

  _cachedAccessToken = tokenData.access_token;
  _tokenExpiresAt = now + (tokenData.expires_in || 3600) * 1000;
  return _cachedAccessToken!;
}

async function sendFcmMessage(
  projectId: string,
  token: string,
  title: string,
  body: string,
  data?: Record<string, string>,
) {
  const accessToken = await getAccessToken();

  const message: Record<string, unknown> = {
    message: {
      token,
      notification: { title, body },
      android: { priority: "high" },
      apns: { payload: { aps: { sound: "default" } } },
    },
  };

  if (data) {
    (message.message as Record<string, unknown>).data = data;
  }

  const res = await fetch(
    `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`,
    {
      method: "POST",
      headers: {
        Authorization: `Bearer ${accessToken}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify(message),
    },
  );

  const result = await res.json();
  if (!res.ok) {
    console.error("FCM send error:", result);
    return { success: false, error: result.error?.message || "FCM error" };
  }
  return { success: true, messageId: result.name };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  // This function can be called by authenticated users (for driver notifications)
  // or by service role (from other Edge Functions)
  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID") || "";

  if (!projectId) {
    return errorResponse("FIREBASE_PROJECT_ID not configured", 500);
  }

  // Verify caller is authenticated
  const authorization = req.headers.get("authorization") ?? "";
  const token = authorization.toLowerCase().startsWith("bearer ")
    ? authorization.slice(7).trim()
    : "";

  if (!token) {
    return errorResponse("Missing authorization", 401);
  }

  // Verify the JWT
  const supabaseAuth = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: { user }, error: userError } = await supabaseAuth.auth.getUser(token);
  if (userError || !user) {
    return errorResponse("Invalid token", 401);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON");
  }

  const { user_ids, title, message, data } = body as {
    user_ids?: string[];
    title?: string;
    message?: string;
    data?: Record<string, string>;
  };

  if (!user_ids?.length || !title || !message) {
    return errorResponse("Missing user_ids, title, or message");
  }

  // Fetch FCM tokens for the target users
  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
  const { data: profiles } = await supabaseAdmin
    .from("profiles")
    .select("id, fcm_token")
    .in("id", user_ids)
    .not("fcm_token", "is", null);

  const results: Array<{ userId: string; success: boolean; error?: string }> = [];

  for (const p of profiles || []) {
    if (!p.fcm_token) continue;
    try {
      const result = await sendFcmMessage(projectId, p.fcm_token, title, message, data);
      results.push({ userId: p.id, ...result });
    } catch (e) {
      results.push({ userId: p.id, success: false, error: e.message });
    }
  }

  return jsonResponse({ success: true, sent: results.length, results });
});
