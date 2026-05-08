// @ts-nocheck
// Supabase Edge Function: send-fcm-notification
// Server-side FCM sender. Firebase service account must live in Edge secrets:
//   FIREBASE_SERVICE_ACCOUNT_JSON
//   FIREBASE_PROJECT_ID

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { corsHeaders, errorResponse, jsonResponse } from "../_shared/admin-auth.ts";

let _cachedAccessToken: string | null = null;
let _tokenExpiresAt = 0;

function bearerToken(req: Request) {
  const authorization =
    req.headers.get("authorization") ?? req.headers.get("Authorization") ?? "";
  return authorization.toLowerCase().startsWith("bearer ")
    ? authorization.slice(7).trim()
    : "";
}

function base64Url(input: string | Uint8Array) {
  const bytes = typeof input === "string" ? new TextEncoder().encode(input) : input;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

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
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claim = base64Url(JSON.stringify({
    iss: sa.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    iat,
    exp,
  }));
  const signInput = `${header}.${claim}`;

  const pemContents = sa.private_key
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\n/g, "");
  const binaryKey = Uint8Array.from(atob(pemContents), (c) => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    binaryKey,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(signInput),
  );
  const jwt = `${signInput}.${base64Url(new Uint8Array(signature))}`;

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

function isUnregisteredTokenError(error: unknown) {
  const text = JSON.stringify(error ?? "");
  return text.includes("UNREGISTERED") || text.includes("registration-token-not-registered");
}

function androidChannelFor(data?: Record<string, string>) {
  const type = data?.type ?? data?.notification_type ?? data?.legacy_type;
  if (type === "merchant.order.created" || type === "merchant_new_order") {
    return "merchant_new_order_channel_v1";
  }
  if (type === "driver.job.available" || type === "driver_job_available" || type === "new_booking" || type === "new_ride_request") {
    return "driver_job_available_channel_v1";
  }
  return "jedechai_channel";
}

async function isAllowedDriverCandidateNotification(
  supabaseAdmin: ReturnType<typeof createClient>,
  targetUserId: string,
  notificationId?: string,
  data?: Record<string, string>,
) {
  if (!notificationId) return false;

  const { data: notification } = await supabaseAdmin
    .from("notifications")
    .select("id, user_id, type, data")
    .eq("id", notificationId)
    .eq("user_id", targetUserId)
    .eq("type", "driver.job.available")
    .maybeSingle();
  if (!notification) return false;

  const notificationBookingId = notification.data?.booking_id;
  const requestBookingId = data?.booking_id;
  if (!notificationBookingId) return false;
  if (requestBookingId && requestBookingId !== notificationBookingId) return false;

  const requestType = data?.type ?? data?.notification_type ?? data?.legacy_type;
  return requestType === "driver.job.available" ||
    requestType === "driver_job_available" ||
    requestType === "new_booking" ||
    requestType === "new_ride_request";
}

async function isAllowedTarget(
  supabaseAdmin: ReturnType<typeof createClient>,
  callerId: string,
  callerRole: string,
  targetUserId: string,
  notificationId?: string,
  data?: Record<string, string>,
) {
  if (callerRole === "admin" || callerId === targetUserId) return true;

  const { data: targetProfile } = await supabaseAdmin
    .from("profiles")
    .select("role")
    .eq("id", targetUserId)
    .maybeSingle();
  if (targetProfile?.role === "admin") return true;

  const bookingIdFromData = data?.booking_id;
  if (!notificationId && !bookingIdFromData) return false;

  let bookingId = bookingIdFromData;
  if (notificationId) {
    const { data: notification } = await supabaseAdmin
      .from("notifications")
      .select("id, user_id, data")
      .eq("id", notificationId)
      .eq("user_id", targetUserId)
      .maybeSingle();
    if (!notification) return false;

    bookingId = notification.data?.booking_id ?? bookingId;
  }
  if (!bookingId) return false;

  const { data: booking } = await supabaseAdmin
    .from("bookings")
    .select("customer_id, driver_id, merchant_id")
    .eq("id", bookingId)
    .maybeSingle();
  if (!booking) return false;

  const callerIsParticipant = booking.customer_id === callerId ||
    booking.driver_id === callerId ||
    booking.merchant_id === callerId;
  const targetIsParticipant = booking.customer_id === targetUserId ||
    booking.driver_id === targetUserId ||
    booking.merchant_id === targetUserId;

  if (
    callerIsParticipant &&
    await isAllowedDriverCandidateNotification(supabaseAdmin, targetUserId, notificationId, data)
  ) {
    return true;
  }

  return callerIsParticipant && targetIsParticipant;
}

async function sendFcmMessage(
  projectId: string,
  token: string,
  title: string,
  body: string,
  data?: Record<string, string>,
) {
  const accessToken = await getAccessToken();
  const channelId = androidChannelFor(data);
  const message = {
    message: {
      token,
      notification: { title, body },
      data: data ?? {},
      android: {
        priority: "high",
        notification: {
          channel_id: channelId,
          sound: channelId === "merchant_new_order_channel_v1" ? "alert_new_order" : "default",
        },
      },
      apns: {
        headers: {
          "apns-push-type": "alert",
          "apns-priority": "10",
        },
        payload: {
          aps: {
            alert: { title, body },
            sound: channelId === "merchant_new_order_channel_v1" ? "AlertNewOrder.caf" : "default",
          },
        },
      },
    },
  };

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
    return { success: false, error: result.error ?? result };
  }
  return { success: true, messageId: result.name as string };
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
  const anonKey = Deno.env.get("SUPABASE_ANON_KEY")!;
  const projectId = Deno.env.get("FIREBASE_PROJECT_ID") || "";
  if (!projectId) return errorResponse("FIREBASE_PROJECT_ID not configured", 500);

  const token = bearerToken(req);
  if (!token) return errorResponse("Missing authorization", 401);

  const supabaseAuth = createClient(supabaseUrl, anonKey, {
    global: { headers: { Authorization: `Bearer ${token}` } },
  });
  const { data: { user }, error: userError } = await supabaseAuth.auth.getUser(token);
  if (userError || !user) return errorResponse("Invalid token", 401);

  const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);
  const { data: callerProfile } = await supabaseAdmin
    .from("profiles")
    .select("role")
    .eq("id", user.id)
    .maybeSingle();
  const callerRole = callerProfile?.role ?? "";

  let requestBody: Record<string, unknown>;
  try {
    requestBody = await req.json();
  } catch {
    return errorResponse("Invalid JSON");
  }

  const {
    user_ids,
    title,
    message,
    data,
    notification_id,
    persist_in_app,
  } = requestBody as {
    user_ids?: string[];
    title?: string;
    message?: string;
    data?: Record<string, string>;
    notification_id?: string;
    persist_in_app?: boolean;
  };

  if (!user_ids?.length || !title || !message) {
    return errorResponse("Missing user_ids, title, or message");
  }

  const uniqueUserIds = [...new Set(user_ids.map((id) => String(id)).filter(Boolean))];
  const allowedChecks = await Promise.all(
    uniqueUserIds.map((targetUserId) =>
      isAllowedTarget(supabaseAdmin, user.id, callerRole, targetUserId, notification_id, data)
    ),
  );
  if (allowedChecks.some((allowed) => !allowed)) {
    return errorResponse("Not allowed to send FCM to one or more target users", 403);
  }

  const { data: profiles, error: profileError } = await supabaseAdmin
    .from("profiles")
    .select("id, fcm_token")
    .in("id", uniqueUserIds);
  if (profileError) return errorResponse(profileError.message, 500);

  const results: Array<{ userId: string; success: boolean; error?: string; messageId?: string }> = [];

  for (const p of profiles || []) {
    let deliveryNotificationId = notification_id || null;
    if (!deliveryNotificationId && persist_in_app !== false) {
      const { data: insertedNotification, error: notificationError } = await supabaseAdmin
        .from("notifications")
        .insert({
          user_id: p.id,
          title,
          body: message,
          type: data?.type ?? null,
          data: data ?? null,
        })
        .select("id")
        .maybeSingle();
      if (notificationError) {
        return errorResponse(notificationError.message, 500);
      }
      deliveryNotificationId = insertedNotification?.id ?? null;
    }

    if (!p.fcm_token) {
      const { error: deliveryError } = await supabaseAdmin.from("notification_deliveries").insert({
        notification_id: deliveryNotificationId,
        user_id: p.id,
        channel: "fcm",
        status: "skipped",
        error: "missing_fcm_token",
      });
      if (deliveryError) {
        return errorResponse(deliveryError.message, 500);
      }
      results.push({ userId: p.id, success: false, error: "missing_fcm_token" });
      continue;
    }

    const result = await sendFcmMessage(projectId, p.fcm_token, title, message, data);
    if (!result.success && isUnregisteredTokenError(result.error)) {
      await supabaseAdmin.from("profiles").update({ fcm_token: null }).eq("id", p.id);
    }

    const { error: deliveryError } = await supabaseAdmin.from("notification_deliveries").insert({
      notification_id: deliveryNotificationId,
      user_id: p.id,
      channel: "fcm",
      status: result.success ? "sent" : "failed",
      provider_message_id: result.messageId ?? null,
      error: result.success ? null : JSON.stringify(result.error ?? "FCM error"),
    });
    if (deliveryError) {
      return errorResponse(deliveryError.message, 500);
    }

    results.push({
      userId: p.id,
      success: result.success,
      messageId: result.messageId,
      error: result.success ? undefined : JSON.stringify(result.error ?? "FCM error"),
    });
  }

  return jsonResponse({
    success: results.every((r) => r.success),
    sent: results.filter((r) => r.success).length,
    results,
  });
});
