// Shared StoreOS Connect auth helpers.

export const CONNECT_CONNECTION_KEY_HEADER = "X-JDC-Connection-Key";
export const CONNECT_SIGNATURE_HEADER = "X-Connect-Signature";
export const CONNECT_TIMESTAMP_HEADER = "X-Connect-Timestamp";
export const CONNECT_EVENT_ID_HEADER = "X-Connect-Event-Id";
export const MAX_WEBHOOK_CLOCK_SKEW_MS = 5 * 60 * 1000;

const textEncoder = new TextEncoder();

function bytesToHex(bytes: Uint8Array): string {
  return Array.from(bytes)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

function randomHex(byteLength: number): string {
  const bytes = new Uint8Array(byteLength);
  crypto.getRandomValues(bytes);
  return bytesToHex(bytes);
}

export function generateConnectionKey(): string {
  return `jdc_${randomHex(18)}`;
}

export function generateWebhookSecret(): string {
  return `whsec_${randomHex(32)}`;
}

export function previewSecret(secret: string): string {
  const value = String(secret || "").trim();
  if (value.length <= 8) return "********";
  return `${value.slice(0, 6)}...${value.slice(-4)}`;
}

function normalizeSignature(signature: string): string {
  return signature.trim().replace(/^sha256=/i, "").toLowerCase();
}

export function constantTimeEqual(left: string, right: string): boolean {
  const a = normalizeSignature(left);
  const b = normalizeSignature(right);
  let diff = a.length ^ b.length;
  const length = Math.max(a.length, b.length);

  for (let i = 0; i < length; i++) {
    diff |= (a.charCodeAt(i) || 0) ^ (b.charCodeAt(i) || 0);
  }

  return diff === 0;
}

export async function hmacSha256Hex(
  rawBody: string,
  webhookSecret: string,
): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    textEncoder.encode(webhookSecret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "HMAC",
    key,
    textEncoder.encode(rawBody),
  );
  return bytesToHex(new Uint8Array(signature));
}

export function readConnectHeaders(req: Request) {
  return {
    connectionKey: req.headers.get(CONNECT_CONNECTION_KEY_HEADER) ??
      req.headers.get(CONNECT_CONNECTION_KEY_HEADER.toLowerCase()) ?? "",
    signature: req.headers.get(CONNECT_SIGNATURE_HEADER) ??
      req.headers.get(CONNECT_SIGNATURE_HEADER.toLowerCase()) ?? "",
    timestamp: req.headers.get(CONNECT_TIMESTAMP_HEADER) ??
      req.headers.get(CONNECT_TIMESTAMP_HEADER.toLowerCase()) ?? "",
    eventId: req.headers.get(CONNECT_EVENT_ID_HEADER) ??
      req.headers.get(CONNECT_EVENT_ID_HEADER.toLowerCase()) ?? "",
  };
}

export function isFreshTimestamp(
  timestampHeader: string,
  nowMs = Date.now(),
): boolean {
  const parsed = Number(timestampHeader);
  if (!Number.isFinite(parsed) || parsed <= 0) return false;
  const timestampMs = parsed < 10_000_000_000 ? parsed * 1000 : parsed;
  return Math.abs(nowMs - timestampMs) <= MAX_WEBHOOK_CLOCK_SKEW_MS;
}

export async function verifyConnectSignature(
  rawBody: string,
  webhookSecret: string,
  signatureHeader: string,
  timestampHeader: string,
): Promise<{ ok: true } | { ok: false; error: string }> {
  if (!signatureHeader) return { ok: false, error: "Missing signature" };
  if (!isFreshTimestamp(timestampHeader)) {
    return { ok: false, error: "Stale webhook timestamp" };
  }

  const expected = await hmacSha256Hex(rawBody, webhookSecret);
  if (!constantTimeEqual(signatureHeader, expected)) {
    return { ok: false, error: "Invalid signature" };
  }

  return { ok: true };
}

export async function authenticateConnectRequest(
  req: Request,
  supabaseAdmin: any,
): Promise<
  | { ok: true; rawBody: string; body: Record<string, unknown>; connection: any }
  | { ok: false; status: number; error: string }
> {
  const rawBody = await req.text();
  const headers = readConnectHeaders(req);

  if (!headers.connectionKey) {
    return { ok: false, status: 401, error: "Missing connection key" };
  }
  if (!headers.eventId || headers.eventId.length > 128) {
    return { ok: false, status: 400, error: "Missing or invalid event id" };
  }

  const { data: connection, error: connectionError } = await supabaseAdmin
    .from("pos_connections")
    .select("id, merchant_id, provider, status, webhook_secret")
    .eq("jdc_connection_key", headers.connectionKey)
    .eq("status", "active")
    .maybeSingle();

  if (connectionError) {
    return { ok: false, status: 500, error: connectionError.message };
  }
  if (!connection?.webhook_secret) {
    return { ok: false, status: 401, error: "Unknown or inactive connection" };
  }

  const verified = await verifyConnectSignature(
    rawBody,
    connection.webhook_secret,
    headers.signature,
    headers.timestamp,
  );
  if (!verified.ok) {
    return { ok: false, status: 401, error: verified.error };
  }

  const { error: eventError } = await supabaseAdmin
    .from("pos_webhook_events")
    .insert({
      connection_id: connection.id,
      event_id: headers.eventId,
    });
  if (eventError?.code === "23505") {
    return { ok: false, status: 409, error: "Duplicate webhook event" };
  }
  if (eventError) {
    return { ok: false, status: 500, error: eventError.message };
  }

  try {
    return {
      ok: true,
      rawBody,
      body: JSON.parse(rawBody || "{}"),
      connection,
    };
  } catch {
    return { ok: false, status: 400, error: "Invalid JSON body" };
  }
}
