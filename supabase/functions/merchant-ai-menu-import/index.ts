// Supabase Edge Function: merchant-ai-menu-import
// แผน: Plan/JDC_AI_Merchant_Quick_Setup_Plan_v7.html (Phase 2)
//
// actions (POST JSON, Authorization: Bearer <user JWT>):
//   { action: "process", job_id }                 → 202 แล้วประมวลผลเบื้องหลัง
//   { action: "suggest_templates", job_id, store_type } → ชุดตัวเลือกแนะนำ (ไม่เรียก AI)
//
// ตัวตนร้านมาจาก JWT เท่านั้น — ไม่เชื่อ merchant_id จาก client
// secret: OPENAI_API_KEY, OPENAI_VISION_MODEL (ตั้งด้วย supabase secrets set)

import { createClient, SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";
import { encode as encodeBase64 } from "https://deno.land/std@0.177.0/encoding/base64.ts";
import { corsHeaders, errorResponse, jsonResponse } from "../_shared/admin-auth.ts";
import { callOpenAIJson, loadOpenAIConfig, OpenAIConfig } from "../_shared/openai.ts";
import {
  AiOutput,
  buildDraftItems,
  buildSystemPrompt,
  buildUserPrompt,
  detectImageMime,
  MENU_EXTRACTION_SCHEMA,
  OptionTemplate,
  pickStoreType,
  sanitizeAiOutput,
  STORE_TYPES,
  suggestTemplates,
} from "../_shared/menu-import.ts";

const BUCKET = "merchant-imports";
const MAX_BYTES = 10 * 1024 * 1024;
const IMAGES_PER_REQUEST = 2;
const MAX_ATTEMPTS = 3;
const UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

declare const EdgeRuntime: { waitUntil(p: Promise<unknown>): void } | undefined;

function serviceClient(): SupabaseClient | null {
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  if (!url || !key) return null;
  return createClient(url, key, { auth: { persistSession: false } });
}

async function authUserId(req: Request, admin: SupabaseClient): Promise<string | null> {
  const header = req.headers.get("authorization") ?? "";
  const token = header.toLowerCase().startsWith("bearer ") ? header.slice(7).trim() : "";
  if (!token) return null;
  const { data, error } = await admin.auth.getUser(token);
  if (error || !data?.user) return null;
  return data.user.id;
}

async function logRun(admin: SupabaseClient, row: Record<string, unknown>) {
  const { error } = await admin.from("ai_runs").insert(row);
  if (error) console.warn("ai_runs insert failed:", error.message);
}

async function audit(admin: SupabaseClient, jobId: string, action: string, diff: unknown) {
  await admin.from("merchant_import_audit").insert({ import_job_id: jobId, action, diff });
}

// ─────────────────────────────────────────────────────────────
// ประมวลผล job (เบื้องหลัง)
// ─────────────────────────────────────────────────────────────
async function processJob(admin: SupabaseClient, job: any, aiConfig: OpenAIConfig) {
  const jobId: string = job.id;
  const merchantId: string = job.merchant_id;
  try {
    await admin.from("merchant_import_jobs").update({
      status: "processing",
      attempts: (job.attempts ?? 0) + 1,
      locked_at: new Date().toISOString(),
      error: null,
      updated_at: new Date().toISOString(),
    }).eq("id", jobId);

    const { data: sources, error: srcErr } = await admin
      .from("merchant_import_sources")
      .select("id, source_index, storage_path")
      .eq("import_job_id", jobId)
      .order("source_index");
    if (srcErr) throw new Error(srcErr.message);

    // โหลดรูป + ตรวจ magic bytes/ขนาด
    const images: { index: number; mime: string; base64: string }[] = [];
    for (const s of sources ?? []) {
      const { data: blob, error } = await admin.storage.from(BUCKET).download(s.storage_path);
      if (error || !blob) throw new Error(`download_failed:${s.source_index}`);
      const bytes = new Uint8Array(await blob.arrayBuffer());
      if (bytes.length > MAX_BYTES) throw new Error(`file_too_large:${s.source_index}`);
      const mime = detectImageMime(bytes);
      if (!mime) throw new Error(`invalid_image:${s.source_index}`);
      await admin.from("merchant_import_sources")
        .update({ mime, bytes: bytes.length }).eq("id", s.id);
      images.push({ index: s.source_index, mime, base64: encodeBase64(bytes.buffer as ArrayBuffer) });
    }
    if (images.length === 0) throw new Error("no_images");

    const [{ data: existingMenu }, { data: existingCats }] = await Promise.all([
      admin.from("menu_items").select("id, name, price").eq("merchant_id", merchantId),
      admin.from("menu_categories").select("id, name").eq("merchant_id", merchantId)
        .order("sort_order"),
    ]);

    const system = buildSystemPrompt();
    const userText = buildUserPrompt((existingCats ?? []).map((c: any) => c.name));

    // ส่งทีละ ≤2 รูป (ผูก source_index ได้ง่าย ลดโอกาส timeout) — ขนานทีละ 2 ชุด
    const batches: typeof images[] = [];
    for (let i = 0; i < images.length; i += IMAGES_PER_REQUEST) {
      batches.push(images.slice(i, i + IMAGES_PER_REQUEST));
    }
    const outputs: AiOutput[] = [];
    let failures = 0;
    for (let i = 0; i < batches.length; i += 2) {
      const chunk = batches.slice(i, i + 2);
      const results = await Promise.all(chunk.map((batch) =>
        callOpenAIJson(aiConfig, {
          system,
          userText,
          images: batch.map((b) => ({ mime: b.mime, base64: b.base64 })),
          schemaName: "menu_extraction",
          schema: MENU_EXTRACTION_SCHEMA as unknown as Record<string, unknown>,
        })
      ));
      for (let k = 0; k < results.length; k++) {
        const r = results[k];
        await logRun(admin, {
          feature: "menu_import",
          model: r.model,
          merchant_id: merchantId,
          import_job_id: jobId,
          input_tokens: r.inputTokens,
          output_tokens: r.outputTokens,
          estimated_cost_usd: r.estimatedCostUsd,
          latency_ms: r.latencyMs,
          status: r.ok ? "ok" : "error",
          error: r.error,
        });
        if (!r.ok) {
          failures++;
          continue;
        }
        outputs.push(sanitizeAiOutput(r.data, chunk[k][0].index));
      }
    }
    if (outputs.length === 0) {
      throw new Error(failures > 0 ? "ai_failed" : "no_output");
    }

    const drafts = buildDraftItems(
      outputs,
      (existingMenu ?? []).map((m: any) => ({ id: m.id, name: m.name, price: Number(m.price) })),
      existingCats ?? [],
    );
    const storeType = pickStoreType(outputs);

    // retry ได้ → ล้างผลรอบก่อนของ job นี้
    await admin.from("merchant_import_items").delete().eq("import_job_id", jobId);
    if (drafts.length > 0) {
      const rows = drafts.map((d, i) => ({
        import_job_id: jobId,
        source_index: d.source_index,
        sort_order: i,
        category: d.category,
        name: d.name,
        description: d.description,
        price: d.price,
        variant_group: d.variant_group,
        variants_json: d.variants,
        addons_json: d.addons,
        price_text_raw: d.price_text_raw,
        confidence_json: d.confidence,
        issues: d.issues,
        conflict_json: d.conflict,
        match_type: d.match_type,
        matched_menu_item_id: d.matched_menu_item_id,
        matched_price: d.matched_price,
        action: d.action,
        matched_category_id: d.matched_category_id,
        is_new_category: d.is_new_category,
      }));
      const { error: insErr } = await admin.from("merchant_import_items").insert(rows);
      if (insErr) throw new Error(`insert_items:${insErr.message}`);
    }

    const needReview = drafts.filter((d) => d.action === "create" && d.issues.length > 0).length;
    const now = new Date().toISOString();
    await admin.from("merchant_import_jobs").update({
      status: needReview > 0 || failures > 0 || drafts.length === 0 ? "review_required" : "ready",
      total_items: drafts.length,
      low_confidence_items: needReview,
      store_type_guess: storeType?.value ?? null,
      store_type_confidence: storeType?.confidence ?? null,
      store_type: storeType?.value ?? "other",
      unreadable_regions: [
        ...outputs.flatMap((o) => o.unreadable_regions),
        ...(failures > 0 ? [`อ่านไม่สำเร็จ ${failures} ชุดรูป`] : []),
      ].slice(0, 30),
      error: failures > 0 ? "partial_ai_failure" : null,
      processed_at: now,
      completed_at: now,
      locked_at: null,
      updated_at: now,
    }).eq("id", jobId);
    await audit(admin, jobId, "processed", {
      items: drafts.length, need_review: needReview, failures,
    });
  } catch (e) {
    const message = String((e as Error)?.message ?? e).slice(0, 300);
    console.error("merchant-ai-menu-import process error:", jobId, message);
    await admin.from("merchant_import_jobs").update({
      status: "failed",
      error: message,
      locked_at: null,
      updated_at: new Date().toISOString(),
    }).eq("id", jobId);
    await audit(admin, jobId, "process_failed", { error: message });
  }
}

// ─────────────────────────────────────────────────────────────
// handlers
// ─────────────────────────────────────────────────────────────
async function handleProcess(admin: SupabaseClient, uid: string, jobId: string) {
  const aiConfig = await loadOpenAIConfig(admin);
  if (!aiConfig) return errorResponse("ai_not_configured", 503);

  const { data: job, error } = await admin
    .from("merchant_import_jobs").select("*").eq("id", jobId).maybeSingle();
  if (error) return errorResponse(error.message, 500);
  if (!job || job.merchant_id !== uid) return errorResponse("ai_import_job_not_found", 404);

  const retry = job.status === "failed";
  if (!(job.status === "uploading" || retry)) {
    return errorResponse(`ai_import_job_status_${job.status}`, 409);
  }
  if (retry && (job.attempts ?? 0) >= MAX_ATTEMPTS) {
    return errorResponse("ai_import_max_attempts", 409);
  }

  // รายการไฟล์จริงใน storage (ไม่เชื่อ path จาก client)
  const prefix = `${uid}/${jobId}`;
  const { data: files, error: listErr } = await admin.storage.from(BUCKET)
    .list(prefix, { limit: 50, sortBy: { column: "name", order: "asc" } });
  if (listErr) return errorResponse(listErr.message, 500);
  // folder ที่ list() คืนมาไม่มี id → ข้าม
  const images = (files ?? []).filter((f: any) => f.id && f.name && !f.name.startsWith("."));
  if (images.length === 0) return errorResponse("ai_import_no_files", 400);
  if (images.length > Math.max(job.total_files, 1)) return errorResponse("ai_import_too_many_files", 400);

  // claim แบบมีเงื่อนไข — กันเรียกซ้อน
  const { data: claimed, error: claimErr } = await admin
    .from("merchant_import_jobs")
    .update({ status: "queued", total_files: images.length, updated_at: new Date().toISOString() })
    .eq("id", jobId)
    .eq("status", job.status)
    .select("*")
    .maybeSingle();
  if (claimErr) return errorResponse(claimErr.message, 500);
  if (!claimed) return errorResponse("ai_import_job_busy", 409);

  await admin.from("merchant_import_sources").delete().eq("import_job_id", jobId);
  const { error: srcErr } = await admin.from("merchant_import_sources").insert(
    images.map((f: any, i: number) => ({
      import_job_id: jobId,
      source_index: i,
      storage_path: `${prefix}/${f.name}`,
    })),
  );
  if (srcErr) {
    await admin.from("merchant_import_jobs").update({ status: "failed", error: srcErr.message })
      .eq("id", jobId);
    return errorResponse(srcErr.message, 500);
  }

  const task = processJob(admin, claimed, aiConfig);
  if (typeof EdgeRuntime !== "undefined" && EdgeRuntime?.waitUntil) {
    EdgeRuntime.waitUntil(task);
  } else {
    await task;
  }
  return jsonResponse({ job_id: jobId, status: "queued" }, 202);
}

async function handleSuggestTemplates(
  admin: SupabaseClient,
  uid: string,
  jobId: string,
  storeType: string,
) {
  if (!(STORE_TYPES as readonly string[]).includes(storeType)) {
    return errorResponse("ai_import_invalid_store_type", 400);
  }
  const { data: job } = await admin
    .from("merchant_import_jobs").select("id, merchant_id, status").eq("id", jobId).maybeSingle();
  if (!job || job.merchant_id !== uid) return errorResponse("ai_import_job_not_found", 404);
  if (job.status !== "review_required" && job.status !== "ready") {
    return errorResponse("ai_import_job_not_editable", 409);
  }

  const [{ data: templates, error: tErr }, { data: items, error: iErr }] = await Promise.all([
    admin.from("option_templates").select("*").eq("store_type", storeType).eq("is_active", true),
    admin.from("merchant_import_items")
      .select("id, name, category, variant_group, addons_json, action, status")
      .eq("import_job_id", jobId),
  ]);
  if (tErr || iErr) return errorResponse((tErr ?? iErr)!.message, 500);

  const candidates = (items ?? [])
    .filter((i: any) => i.action === "create" && i.status !== "rejected")
    .map((i: any) => ({
      id: i.id,
      name: i.name,
      category: i.category,
      variant_group: i.variant_group,
      addon_groups: (Array.isArray(i.addons_json) ? i.addons_json : [])
        .map((a: any) => a?.group).filter((g: unknown) => typeof g === "string"),
    }));
  const suggestions = suggestTemplates((templates ?? []) as OptionTemplate[], candidates, storeType);
  return jsonResponse({
    store_type: storeType,
    suggestions: suggestions.map((s) => ({
      template_id: s.template.id,
      template_version: s.template.version,
      name: s.template.name,
      min_selection: s.template.min_selection,
      max_selection: s.template.max_selection,
      options: s.template.options,
      item_ids: s.item_ids,
      skipped_item_ids: s.skipped_item_ids,
    })),
  });
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders });
  if (req.method !== "POST") return errorResponse("Method not allowed", 405);
  try {
    const admin = serviceClient();
    if (!admin) return errorResponse("Server misconfigured", 500);
    const uid = await authUserId(req, admin);
    if (!uid) return errorResponse("Invalid or expired token", 401);

    const body = await req.json().catch(() => ({}));
    const jobId = typeof body?.job_id === "string" ? body.job_id.trim() : "";
    if (!UUID_RE.test(jobId)) return errorResponse("job_id is required", 400);

    switch (body?.action) {
      case "process":
        return await handleProcess(admin, uid, jobId);
      case "suggest_templates":
        return await handleSuggestTemplates(admin, uid, jobId, String(body?.store_type ?? ""));
      default:
        return errorResponse("Unknown action", 400);
    }
  } catch (e) {
    console.error("merchant-ai-menu-import error:", (e as Error)?.message ?? e);
    return errorResponse("Internal server error", 500);
  }
});
