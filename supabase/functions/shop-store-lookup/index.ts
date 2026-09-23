import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { corsHeaders, errorResponse, jsonResponse, verifyAdmin } from "../_shared/admin-auth.ts";

const GOOGLE = "https://maps.googleapis.com/maps/api";
const MAX_URL_LENGTH = 2048;
const ALLOWED_HOSTS = new Set(["maps.app.goo.gl", "goo.gl", "www.google.com", "google.com", "maps.google.com", "www.google.co.th", "google.co.th", "maps.google.co.th"]);
const requestWindows = new Map<string, { count: number; resetAt: number }>();

function rateLimited(adminId: string): boolean {
  const now = Date.now();
  const window = requestWindows.get(adminId);
  const next = !window || now >= window.resetAt ? { count: 0, resetAt: now + 60_000 } : window;
  next.count++;
  requestWindows.set(adminId, next);
  return next.count > 60;
}

function validPoint(lat: number, lng: number): boolean {
  return Number.isFinite(lat) && Number.isFinite(lng) && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180 && !(lat === 0 && lng === 0);
}

function checkedMapsUrl(value: string): URL {
  if (value.length > MAX_URL_LENGTH) throw new Error("ลิงก์ยาวเกินไป");
  const url = new URL(value);
  if (url.protocol !== "https:" || !ALLOWED_HOSTS.has(url.hostname.toLowerCase())) {
    throw new Error("รองรับเฉพาะลิงก์ Google Maps แบบ HTTPS");
  }
  return url;
}

async function expandMapsUrl(value: string): Promise<URL> {
  let url = checkedMapsUrl(value);
  for (let attempt = 0; attempt < 5; attempt++) {
    const response = await fetch(url, { redirect: "manual", signal: AbortSignal.timeout(6000) });
    const location = response.headers.get("location");
    if (!location || response.status < 300 || response.status >= 400) return url;
    url = checkedMapsUrl(new URL(location, url).toString());
  }
  throw new Error("ลิงก์เปลี่ยนทางหลายครั้งเกินไป");
}

function parseMapsUrl(url: URL): { placeId?: string; featureCid?: string; query?: string; lat?: number; lng?: number } {
  const placeId = url.searchParams.get("query_place_id") || url.searchParams.get("place_id") || undefined;
  const embeddedFeatures = [...url.toString().matchAll(/!1s0x[0-9a-f]+:(0x[0-9a-f]+)/gi)];
  const featureHex = url.searchParams.get("ftid")?.match(/^0x[0-9a-f]+:(0x[0-9a-f]+)$/i)?.[1] ||
    embeddedFeatures.at(-1)?.[1];
  const featureCid = featureHex ? BigInt(featureHex).toString() : undefined;
  const query = url.searchParams.get("query") || url.searchParams.get("q") ||
    (url.pathname.match(/\/place\/([^/]+)/)?.[1] ? decodeURIComponent(url.pathname.match(/\/place\/([^/]+)/)![1]).replaceAll("+", " ") : undefined);
  const location = url.toString().match(/!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)/) ||
    url.toString().match(/@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)/) ||
    (query || "").match(/^(-?\d+(?:\.\d+)?),\s*(-?\d+(?:\.\d+)?)$/);
  const lat = location ? Number(location[1]) : undefined;
  const lng = location ? Number(location[2]) : undefined;
  return { placeId, featureCid, query, lat, lng };
}

async function googleJson(path: string, params: Record<string, string>, key: string) {
  const url = new URL(`${GOOGLE}/${path}/json`);
  for (const [name, value] of Object.entries(params)) url.searchParams.set(name, value);
  url.searchParams.set("key", key);
  const response = await fetch(url, { signal: AbortSignal.timeout(8000) });
  const body = await response.json();
  if (!response.ok || !["OK", "ZERO_RESULTS"].includes(body.status)) {
    console.error("Google Maps lookup failed", path, response.status, body.status);
    throw new Error("ดึงข้อมูลจาก Google Maps ไม่สำเร็จ กรุณาตรวจการเปิด API และ Billing");
  }
  return body;
}

function resultFromPlace(place: Record<string, unknown>) {
  const point = (place.geometry as { location?: { lat: number; lng: number } } | undefined)?.location;
  if (!point || !validPoint(point.lat, point.lng)) return null;
  return {
    name: String(place.name || ""),
    address: String(place.formatted_address || place.vicinity || ""),
    lat: point.lat,
    lng: point.lng,
    source: "place",
    ...(openingHoursFromPlace(place.opening_hours) || {}),
  };
}

function openingHoursFromPlace(raw: unknown): { openingHours: Record<string, { open: string; close: string }[]>; is24h: boolean } | null {
  const periods = (raw as { periods?: Array<{ open?: { day?: number; time?: string }; close?: { day?: number; time?: string } }> } | undefined)?.periods;
  if (!Array.isArray(periods) || periods.length === 0) return null;
  if (periods.length === 1 && periods[0].open?.day === 0 && periods[0].open?.time === "0000" && !periods[0].close) {
    return { openingHours: {}, is24h: true };
  }
  const days = ["sun", "mon", "tue", "wed", "thu", "fri", "sat"];
  const hours: Record<string, { open: string; close: string }[]> = Object.fromEntries(days.map((day) => [day, []]));
  const format = (value?: string) => /^([01]\d|2[0-3])[0-5]\d$/.test(value || "") ? `${value!.slice(0, 2)}:${value!.slice(2)}` : null;
  for (const period of periods) {
    const day = period.open?.day;
    const closeDay = period.close?.day;
    const open = format(period.open?.time);
    const close = format(period.close?.time);
    if (!Number.isInteger(day) || day! < 0 || day! > 6 || !Number.isInteger(closeDay) || !open || !close || hours[days[day!]].length >= 2) return null;
    const sameDay = closeDay === day && close > open;
    const overnight = closeDay === (day! + 1) % 7 && close < open;
    if (!sameDay && !overnight) return null;
    hours[days[day!]].push({ open, close });
  }
  return { openingHours: hours, is24h: false };
}

async function placeDetails(placeId: string, key: string) {
  const data = await googleJson("place/details", {
    place_id: placeId,
    fields: "name,formatted_address,geometry,opening_hours,url",
    language: "th",
  }, key);
  return data.result || null;
}

function cidFromPlaceUrl(value: unknown): string | null {
  if (typeof value !== "string") return null;
  try {
    return new URL(value).searchParams.get("cid");
  } catch {
    return null;
  }
}

function distanceMeters(lat1: number, lng1: number, lat2: number, lng2: number): number {
  return Math.hypot((lat2 - lat1) * 111_000, (lng2 - lng1) * 111_000 * Math.cos(lat1 * Math.PI / 180));
}

async function addressFromPoint(lat: number, lng: number, key: string) {
  const geocoded = await googleJson("geocode", { latlng: `${lat},${lng}`, language: "th" }, key);
  return { name: "", address: String(geocoded.results?.[0]?.formatted_address || ""), lat, lng, source: "address" };
}

async function findFromLink(rawUrl: string, key: string) {
  const url = await expandMapsUrl(rawUrl);
  const parsed = parseMapsUrl(url);
  if (parsed.placeId) {
    const details = await placeDetails(parsed.placeId, key);
    const result = details && resultFromPlace(details);
    if (result) return result;
  }
  if (parsed.query && !/^https?:/i.test(parsed.query) && !/^\s*-?\d+(?:\.\d+)?,\s*-?\d+(?:\.\d+)?\s*$/.test(parsed.query)) {
    const params: Record<string, string> = { query: parsed.query.slice(0, 250), language: "th" };
    if (validPoint(parsed.lat!, parsed.lng!)) params.location = `${parsed.lat},${parsed.lng}`;
    const data = await googleJson("place/textsearch", params, key);
    const candidates = Array.isArray(data.results) ? data.results.slice(0, parsed.featureCid ? 5 : 1) : [];
    for (const candidate of candidates) {
      if (!candidate.place_id) continue;
      const details = await placeDetails(candidate.place_id, key);
      if (!details) continue;
      if (parsed.featureCid && cidFromPlaceUrl(details.url) !== parsed.featureCid) continue;
      const result = resultFromPlace(details);
      if (!result) continue;
      if (!parsed.featureCid && validPoint(parsed.lat!, parsed.lng!) && distanceMeters(parsed.lat!, parsed.lng!, result.lat, result.lng) > 100) {
        return addressFromPoint(parsed.lat!, parsed.lng!, key);
      }
      return parsed.featureCid ? result : { ...result, source: "unverified_search" };
    }
  }
  if (parsed.featureCid) throw new Error("ไม่พบข้อมูลร้านที่ตรงกับหมุดในลิงก์ กรุณาตรวจลิงก์อีกครั้ง");
  if (validPoint(parsed.lat!, parsed.lng!)) return addressFromPoint(parsed.lat!, parsed.lng!, key);
  throw new Error("ลิงก์นี้ไม่มีข้อมูลสถานที่หรือพิกัดที่อ่านได้");
}

async function findFromPoint(lat: number, lng: number, key: string) {
  const nearby = await googleJson("place/nearbysearch", {
    location: `${lat},${lng}`, radius: "30", language: "th",
  }, key);
  const candidates = (nearby.results || []).map((item: Record<string, unknown>) => {
    const point = (item.geometry as { location?: { lat: number; lng: number } } | undefined)?.location;
    return { item, meters: point ? distanceMeters(lat, lng, point.lat, point.lng) : Infinity };
  }).filter(({ item, meters }: { item: Record<string, unknown>; meters: number }) =>
    meters <= 35 && Array.isArray(item.types) && item.types.includes("establishment") && !!item.place_id
  ).sort((a: { meters: number }, b: { meters: number }) => a.meters - b.meters);
  if (candidates.length) {
    const closest = candidates[0];
    const details = await placeDetails(String(closest.item.place_id), key);
    const result = details && resultFromPlace(details);
    if (result) {
      const ambiguous = closest.meters > 12 || (candidates[1] && candidates[1].meters - closest.meters < 10);
      const fallbackAddress = ambiguous ? (await addressFromPoint(lat, lng, key)).address : undefined;
      return { ...result, source: ambiguous ? "nearby_candidate" : "nearby_place", distanceMeters: Math.round(closest.meters), fallbackAddress };
    }
  }
  return addressFromPoint(lat, lng, key);
}

serve(async (req) => {
  if (req.method === "OPTIONS") return new Response("ok", { headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);
  const auth = await verifyAdmin(req);
  if (auth instanceof Response) return auth;
  if (rateLimited(auth.adminId)) return errorResponse("เรียกข้อมูลบ่อยเกินไป กรุณารอสักครู่", 429);
  if (Number(req.headers.get("content-length") || 0) > 4096) return errorResponse("ข้อมูลคำขอใหญ่เกินไป", 413);
  const key = Deno.env.get("GOOGLE_MAPS_API_KEY");
  if (!key) return errorResponse("Google Maps API ยังไม่ได้ตั้งค่าฝั่ง server", 503);
  try {
    const body = await req.json();
    if (body.mode === "map" && validPoint(body.lat, body.lng)) {
      const zoom = Number(body.zoom);
      if (!Number.isInteger(zoom) || zoom < 3 || zoom > 19) return errorResponse("ระดับแผนที่ไม่ถูกต้อง", 400);
      const url = new URL(`${GOOGLE}/staticmap`);
      url.searchParams.set("center", `${body.lat},${body.lng}`);
      url.searchParams.set("zoom", String(zoom));
      url.searchParams.set("size", "640x320");
      url.searchParams.set("scale", "1");
      url.searchParams.set("maptype", "roadmap");
      url.searchParams.set("language", "th");
      if (body.marker === true) url.searchParams.set("markers", `color:red|${body.lat},${body.lng}`);
      url.searchParams.set("key", key);
      const mapResponse = await fetch(url, { signal: AbortSignal.timeout(8000) });
      if (!mapResponse.ok || !mapResponse.headers.get("content-type")?.startsWith("image/")) {
        return errorResponse("โหลดแผนที่ Google ไม่สำเร็จ", 502);
      }
      const bytes = new Uint8Array(await mapResponse.arrayBuffer());
      if (bytes.length > 400_000) return errorResponse("รูปแผนที่ใหญ่เกินไป", 502);
      let binary = "";
      for (const byte of bytes) binary += String.fromCharCode(byte);
      return jsonResponse({ image: `data:image/png;base64,${btoa(binary)}` });
    }
    if (body.mode === "url" && typeof body.url === "string") {
      return jsonResponse({ result: await findFromLink(body.url, key) });
    }
    if (body.mode === "point" && validPoint(body.lat, body.lng)) {
      return jsonResponse({ result: await findFromPoint(body.lat, body.lng, key) });
    }
    return errorResponse("ข้อมูลตำแหน่งไม่ถูกต้อง", 400);
  } catch (error) {
    return errorResponse(error instanceof Error ? error.message : "ไม่สามารถดึงข้อมูลร้านได้", 400);
  }
});
