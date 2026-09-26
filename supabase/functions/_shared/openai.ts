// OpenAI Responses API helper สำหรับ Edge Functions
// - คีย์: Supabase secret OPENAI_API_KEY ก่อน ถ้าไม่มีอ่านจาก Vault ผ่าน RPC
//   ai_get_openai_config() (แอดมินตั้งจากหน้า Settings) — ห้ามอยู่ใน Flutter
// - บังคับ output ด้วย Structured Outputs (json_schema strict)
// - store: false, timeout ต่อ request, retry 1 ครั้งเมื่อ 429/5xx/timeout
// - คืน usage + latency ให้ผู้เรียกบันทึก ai_runs

const OPENAI_URL = "https://api.openai.com/v1/responses";

export interface OpenAIImageInput {
  mime: string;
  base64: string;
}

export interface OpenAIJsonResult {
  ok: boolean;
  data: unknown;
  model: string;
  inputTokens: number | null;
  outputTokens: number | null;
  latencyMs: number;
  error: string | null;
  estimatedCostUsd: number | null;
}

export interface OpenAIConfig {
  apiKey: string;
  model: string;
  priceInputPerMTok: number | null;
  priceOutputPerMTok: number | null;
}

function priceOrNull(value: unknown): number | null {
  const n = Number(value ?? "");
  return Number.isFinite(n) && n > 0 ? n : null;
}

/** env ก่อน (secret ของ function) แล้วค่อย Vault/system_config ที่แอดมินตั้ง */
export async function loadOpenAIConfig(
  admin: { rpc: (fn: string) => PromiseLike<{ data: unknown; error: unknown }> },
): Promise<OpenAIConfig | null> {
  let db: Record<string, unknown> = {};
  try {
    const { data } = await admin.rpc("ai_get_openai_config");
    if (data && typeof data === "object") db = data as Record<string, unknown>;
  } catch (e) {
    console.warn("ai_get_openai_config failed:", (e as Error)?.message ?? e);
  }
  const apiKey = Deno.env.get("OPENAI_API_KEY") || String(db.api_key ?? "");
  const model = Deno.env.get("OPENAI_VISION_MODEL") || String(db.model ?? "");
  if (!apiKey || !model) return null;
  // ค่าที่ไม่ใช่รูปแบบคีย์ OpenAI (เช่นเขียน Vault ผิด) → ถือว่ายังไม่ตั้ง แทนการยิง 401 ทุกงาน
  if (!/^sk-[A-Za-z0-9_-]{17,}$/.test(apiKey)) {
    console.warn("OpenAI API key format invalid — treated as not configured");
    return null;
  }
  return {
    apiKey,
    model,
    priceInputPerMTok: priceOrNull(Deno.env.get("OPENAI_PRICE_INPUT_PER_MTOK") || db.price_input_per_mtok),
    priceOutputPerMTok: priceOrNull(Deno.env.get("OPENAI_PRICE_OUTPUT_PER_MTOK") || db.price_output_per_mtok),
  };
}

function estimateCost(
  cfg: OpenAIConfig,
  inputTokens: number | null,
  outputTokens: number | null,
): number | null {
  // ไม่ hard-code ราคาเพราะเปลี่ยนตามรุ่น — ไม่ได้ตั้งราคา = ไม่คำนวณ
  if (cfg.priceInputPerMTok === null || cfg.priceOutputPerMTok === null) return null;
  return ((inputTokens ?? 0) * cfg.priceInputPerMTok + (outputTokens ?? 0) * cfg.priceOutputPerMTok) /
    1_000_000;
}

function extractOutputText(body: any): string | null {
  if (typeof body?.output_text === "string") return body.output_text;
  for (const out of Array.isArray(body?.output) ? body.output : []) {
    for (const part of Array.isArray(out?.content) ? out.content : []) {
      if (part?.type === "output_text" && typeof part.text === "string") return part.text;
      if (part?.type === "refusal") return null;
    }
  }
  return null;
}

async function callOnce(
  apiKey: string,
  payload: Record<string, unknown>,
  timeoutMs: number,
): Promise<{ status: number; body: any; error: string | null }> {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(OPENAI_URL, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        Authorization: `Bearer ${apiKey}`,
      },
      body: JSON.stringify(payload),
      signal: controller.signal,
    });
    const body = await res.json().catch(() => null);
    const error = res.ok ? null : String(body?.error?.message ?? `HTTP ${res.status}`).slice(0, 300);
    return { status: res.status, body, error };
  } catch (e) {
    const aborted = (e as Error)?.name === "AbortError";
    return { status: aborted ? 408 : 0, body: null, error: aborted ? "timeout" : String(e).slice(0, 300) };
  } finally {
    clearTimeout(timer);
  }
}

export async function callOpenAIJson(cfg: OpenAIConfig | null, opts: {
  system: string;
  userText: string;
  images: OpenAIImageInput[];
  schemaName: string;
  schema: Record<string, unknown>;
  timeoutMs?: number;
}): Promise<OpenAIJsonResult> {
  const started = Date.now();
  if (!cfg) {
    return {
      ok: false, data: null, model: "", inputTokens: null, outputTokens: null,
      latencyMs: 0, error: "ai_not_configured", estimatedCostUsd: null,
    };
  }

  const payload = {
    model: cfg.model,
    store: false,
    input: [
      { role: "system", content: [{ type: "input_text", text: opts.system }] },
      {
        role: "user",
        content: [
          { type: "input_text", text: opts.userText },
          ...opts.images.map((img) => ({
            type: "input_image",
            image_url: `data:${img.mime};base64,${img.base64}`,
            detail: "high",
          })),
        ],
      },
    ],
    text: {
      format: {
        type: "json_schema",
        name: opts.schemaName,
        schema: opts.schema,
        strict: true,
      },
    },
  };

  const timeoutMs = opts.timeoutMs ?? 90_000;
  let attempt = await callOnce(cfg.apiKey, payload, timeoutMs);
  const retryable = attempt.status === 408 || attempt.status === 429 || attempt.status === 0 ||
    attempt.status >= 500;
  if (attempt.error && retryable) {
    await new Promise((r) => setTimeout(r, 1500));
    attempt = await callOnce(cfg.apiKey, payload, timeoutMs);
  }

  const usage = attempt.body?.usage ?? {};
  const inputTokens = typeof usage.input_tokens === "number" ? usage.input_tokens : null;
  const outputTokens = typeof usage.output_tokens === "number" ? usage.output_tokens : null;
  const base = {
    model: cfg.model,
    inputTokens,
    outputTokens,
    latencyMs: Date.now() - started,
    estimatedCostUsd: estimateCost(cfg, inputTokens, outputTokens),
  };

  if (attempt.error) return { ...base, ok: false, data: null, error: attempt.error };
  if (attempt.body?.status && attempt.body.status !== "completed") {
    return { ...base, ok: false, data: null, error: `status_${attempt.body.status}` };
  }
  const text = extractOutputText(attempt.body);
  if (!text) return { ...base, ok: false, data: null, error: "empty_or_refused" };
  try {
    return { ...base, ok: true, data: JSON.parse(text), error: null };
  } catch {
    return { ...base, ok: false, data: null, error: "invalid_json" };
  }
}
