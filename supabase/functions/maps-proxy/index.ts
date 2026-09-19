// @ts-nocheck
// Supabase Edge Function: maps-proxy
//
// ISSUE-120: เดิมแอปเรียก Google Maps Web Service API (Directions / Geocoding /
// Places) ตรงจากเครื่องผู้ใช้ด้วย GOOGLE_MAPS_API_KEY ที่อยู่ใน .env ซึ่งถูก
// bundle เป็น Flutter asset — key แบบนั้นผูก application restriction ไม่ได้
// (Web Service ไม่รองรับ) ใครแตก APK ก็เอา key ไปยิงบิลเข้าโปรเจคได้ไม่จำกัด
//
// ฟังก์ชันนี้เป็น proxy ฝั่ง server:
// - ใช้ GOOGLE_MAPS_SERVER_KEY ที่เก็บเป็น Edge Function secret (ตั้ง IP
//   restriction ได้) ไม่มีวันหลุดไปกับแอป
// - รับเฉพาะ operation ที่ allowlist ไว้ และ normalize parameter ทุกตัวเอง
//   ไม่ให้ client ส่ง path/query อะไรก็ได้ทะลุไปหา Google
// - บังคับให้ผู้เรียกเป็นผู้ใช้ที่ล็อกอินแล้ว (ตรวจ JWT กับ Supabase)

import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  corsHeaders,
  errorResponse,
  jsonResponse,
} from "../_shared/admin-auth.ts";

const GOOGLE_API_BASE = "https://maps.googleapis.com/maps/api";
const UPSTREAM_TIMEOUT_MS = 10000;

function bearerToken(req: Request): string {
  const authorization = req.headers.get("authorization") ??
    req.headers.get("Authorization") ?? "";
  return authorization.toLowerCase().startsWith("bearer ")
    ? authorization.slice(7).trim()
    : "";
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
  const { data: { user }, error } = await supabaseAdmin.auth.getUser(token);
  if (error || !user) {
    return { response: errorResponse("Invalid or expired token", 401) };
  }

  return { user };
}

/** แปลงเป็นพิกัดที่ใช้ได้จริง หรือ null ถ้าไม่ผ่าน */
function toLatLng(lat: unknown, lng: unknown): string | null {
  const latNum = Number(lat);
  const lngNum = Number(lng);
  if (!Number.isFinite(latNum) || !Number.isFinite(lngNum)) return null;
  if (latNum < -90 || latNum > 90) return null;
  if (lngNum < -180 || lngNum > 180) return null;
  return `${latNum},${lngNum}`;
}

function toQuery(value: unknown, maxLength = 200): string | null {
  const text = String(value ?? "").trim();
  if (!text) return null;
  return text.slice(0, maxLength);
}

/** ประกอบ URL ของ Google จาก operation ที่ allowlist ไว้เท่านั้น */
function buildUpstreamUrl(
  operation: string,
  payload: Record<string, unknown>,
  apiKey: string,
): { url: string } | { error: string } {
  switch (operation) {
    case "directions": {
      const origin = toLatLng(payload.origin_lat, payload.origin_lng);
      const destination = toLatLng(
        payload.destination_lat,
        payload.destination_lng,
      );
      if (!origin || !destination) return { error: "invalid_coordinates" };

      const params = new URLSearchParams({
        origin,
        destination,
        mode: "driving",
        language: "th",
        key: apiKey,
      });
      return { url: `${GOOGLE_API_BASE}/directions/json?${params}` };
    }

    case "geocode": {
      const address = toQuery(payload.address);
      if (!address) return { error: "invalid_address" };

      const params = new URLSearchParams({
        address,
        language: "th",
        region: "th",
        key: apiKey,
      });
      return { url: `${GOOGLE_API_BASE}/geocode/json?${params}` };
    }

    case "reverse_geocode": {
      const latlng = toLatLng(payload.lat, payload.lng);
      if (!latlng) return { error: "invalid_coordinates" };

      const params = new URLSearchParams({
        latlng,
        language: "th",
        key: apiKey,
      });
      return { url: `${GOOGLE_API_BASE}/geocode/json?${params}` };
    }

    case "place_text_search": {
      const query = toQuery(payload.query);
      if (!query) return { error: "invalid_query" };

      const params = new URLSearchParams({
        query,
        language: "th",
        region: "th",
        key: apiKey,
      });
      return { url: `${GOOGLE_API_BASE}/place/textsearch/json?${params}` };
    }

    default:
      return { error: "unsupported_operation" };
  }
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
    if ("response" in auth) return auth.response;

    const apiKey = Deno.env.get("GOOGLE_MAPS_SERVER_KEY")?.trim();
    if (!apiKey) {
      console.error("maps-proxy: GOOGLE_MAPS_SERVER_KEY is not configured");
      return errorResponse("Server misconfigured", 500);
    }

    const body = await req.json().catch(() => ({}));
    const operation = String(body?.operation ?? "").trim();

    const built = buildUpstreamUrl(operation, body ?? {}, apiKey);
    if ("error" in built) {
      return jsonResponse({ success: false, error: built.error }, 400);
    }

    const controller = new AbortController();
    const timeout = setTimeout(() => controller.abort(), UPSTREAM_TIMEOUT_MS);

    let upstream: Response;
    try {
      upstream = await fetch(built.url, { signal: controller.signal });
    } finally {
      clearTimeout(timeout);
    }

    if (!upstream.ok) {
      console.error(`maps-proxy: upstream HTTP ${upstream.status}`);
      return jsonResponse(
        { success: false, error: "upstream_error" },
        502,
      );
    }

    const data = await upstream.json();

    // ส่งต่อ payload ของ Google ตามเดิม เพื่อให้ฝั่งแอปแกะเหมือนที่เคยทำ
    // (ไม่มี API key อยู่ใน response ของ Google อยู่แล้ว)
    return jsonResponse({ success: true, operation, data });
  } catch (error) {
    if (error instanceof DOMException && error.name === "AbortError") {
      return jsonResponse({ success: false, error: "upstream_timeout" }, 504);
    }
    console.error("maps-proxy failed:", error);
    return errorResponse(
      error instanceof Error ? error.message : "maps-proxy failed",
      500,
    );
  }
});
