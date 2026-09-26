import { mountPageTabs } from "./pageTabs.js";

// หน้า AI นำเข้าเมนู (แผน Plan/JDC_AI_Merchant_Quick_Setup_Plan_v7.html)
//
// - เปิด/ปิด feature + allowlist ช่วงทดลอง + โควตา (system_config key/value)
// - ประวัติ import ทุกร้าน + ซ่อนเมนูทั้งชุดแทนร้าน (RPC merchant_hide_import_items)
// - เพิ่มโควตารายร้าน (merchant_ai_import_quota)
// - จัดการแม่แบบชุดตัวเลือกแนะนำ (option_templates) — การเขียนคุมด้วย RLS is_admin()

export const AI_IMPORT_CONFIG_KEYS = [
  "ai_menu_import_onboarding_enabled",
  "ai_menu_import_append_enabled",
  "ai_menu_import_allowlist",
  "ai_menu_import_quota_onboarding",
  "ai_menu_import_quota_append_month",
  "ai_menu_import_max_files",
];

export const STORE_TYPES = [
  ["cafe", "คาเฟ่ / เครื่องดื่ม"],
  ["made_to_order", "อาหารตามสั่ง"],
  ["noodle", "ก๋วยเตี๋ยว"],
  ["isan", "ส้มตำ / อีสาน"],
  ["dessert", "ของหวาน / เบเกอรี่"],
  ["other", "อื่น ๆ"],
];

const STATUS = {
  uploading: ["อัปโหลด", "bg-gray-100 text-gray-500 border-gray-200"],
  queued: ["รอคิว", "bg-sky-50 text-sky-600 border-sky-200"],
  processing: ["กำลังอ่าน", "bg-sky-50 text-sky-600 border-sky-200"],
  review_required: ["รอร้านตรวจ", "bg-amber-50 text-amber-700 border-amber-200"],
  ready: ["รอร้านตรวจ", "bg-amber-50 text-amber-700 border-amber-200"],
  publishing: ["กำลังบันทึก", "bg-sky-50 text-sky-600 border-sky-200"],
  published: ["บันทึกแล้ว", "bg-emerald-50 text-emerald-600 border-emerald-200"],
  failed: ["ไม่สำเร็จ", "bg-red-50 text-red-600 border-red-200"],
  cancelled: ["ยกเลิก", "bg-gray-100 text-gray-500 border-gray-200"],
};

let _ctx = null;

function _deps() {
  return {
    supabase: _ctx?.supabase || globalThis.supabase,
    escapeHtml: _ctx?.escapeHtml || globalThis.escapeHtml,
    fmtDate: _ctx?.fmtDate || globalThis.fmtDate,
    showToast: _ctx?.showToast || globalThis.showToast,
    refreshCurrentPage: _ctx?.refreshCurrentPage || globalThis.refreshCurrentPage,
    upsertConfig: _ctx?._upsertSystemConfigKeyValues || globalThis._upsertSystemConfigKeyValues,
  };
}

// ─────────────────────────────── helpers (pure — มี test)

/** "ไข่มุก=10\nบุก" → [{label:"ไข่มุก",price:10},{label:"บุก",price:0}] */
export function parseOptionsText(text) {
  const out = [];
  for (const raw of String(text || "").split(/\r?\n/)) {
    const line = raw.trim();
    if (!line) continue;
    const idx = line.lastIndexOf("=");
    const label = (idx >= 0 ? line.slice(0, idx) : line).trim();
    const priceText = idx >= 0 ? line.slice(idx + 1).trim() : "0";
    const price = Number(priceText || 0);
    if (!label) return { error: `บรรทัด "${line}" ไม่มีชื่อตัวเลือก` };
    if (!Number.isInteger(price) || price < 0 || price > 10000) {
      return { error: `ราคาของ "${label}" ต้องเป็นจำนวนเต็ม 0–10000` };
    }
    out.push({ label, price });
  }
  if (out.length === 0) return { error: "ต้องมีตัวเลือกอย่างน้อย 1 รายการ" };
  if (out.length > 30) return { error: "ตัวเลือกได้ไม่เกิน 30 รายการ" };
  return { options: out };
}

export function formatOptionsText(options) {
  return (Array.isArray(options) ? options : [])
    .map((o) => (Number(o?.price) > 0 ? `${o.label}=${Number(o.price)}` : String(o?.label ?? "")))
    .join("\n");
}

export function parseKeywords(text) {
  return [...new Set(String(text || "").split(/[,\n]/).map((s) => s.trim()).filter(Boolean))];
}

/** ตรวจฟอร์มแม่แบบ → { row } หรือ { error } */
export function buildTemplateRow(form) {
  const name = String(form.name || "").trim();
  if (!name) return { error: "กรุณาใส่ชื่อชุดตัวเลือก" };
  if (!STORE_TYPES.some(([k]) => k === form.store_type)) return { error: "ประเภทร้านไม่ถูกต้อง" };
  const parsed = parseOptionsText(form.options_text);
  if (parsed.error) return { error: parsed.error };
  const min = Number(form.min_selection);
  const max = Number(form.max_selection);
  if (!Number.isInteger(min) || !Number.isInteger(max) || min < 0 || max < 1 || min > max) {
    return { error: "จำนวนเลือกขั้นต่ำ/สูงสุดไม่ถูกต้อง" };
  }
  if (max > parsed.options.length) return { error: "เลือกสูงสุดต้องไม่เกินจำนวนตัวเลือก" };
  return {
    row: {
      store_type: form.store_type,
      name,
      min_selection: min,
      max_selection: max,
      options: parsed.options,
      match_keywords: parseKeywords(form.match_keywords),
      exclude_keywords: parseKeywords(form.exclude_keywords),
      sort_order: Number.isFinite(Number(form.sort_order)) ? Math.round(Number(form.sort_order)) : 0,
      is_active: form.is_active !== false,
    },
  };
}

/** ตรวจค่าตั้งค่า → { rows } หรือ { error } */
export function collectAiImportConfig(get) {
  const bool = (id) => (get(id) === true ? "true" : "false");
  const int = (id, label, min, max) => {
    const n = Number(get(id));
    if (!Number.isInteger(n) || n < min || n > max) throw new Error(`${label} ต้องเป็นจำนวนเต็ม ${min}–${max}`);
    return String(n);
  };
  try {
    const allow = parseKeywords(get("aiimp_allowlist"));
    const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
    const bad = allow.find((id) => !uuid.test(id));
    if (bad) throw new Error(`รหัสร้านใน allowlist ไม่ถูกต้อง: ${bad}`);
    return {
      rows: [
        { key: "ai_menu_import_onboarding_enabled", value: bool("aiimp_onboarding") },
        { key: "ai_menu_import_append_enabled", value: bool("aiimp_append") },
        { key: "ai_menu_import_allowlist", value: allow.join(",") },
        { key: "ai_menu_import_quota_onboarding", value: int("aiimp_quota_onb", "โควตาร้านใหม่", 0, 50) },
        { key: "ai_menu_import_quota_append_month", value: int("aiimp_quota_app", "โควตาร้านเดิม/เดือน", 0, 100) },
        { key: "ai_menu_import_max_files", value: int("aiimp_max_files", "จำนวนรูปสูงสุด", 1, 8) },
      ],
    };
  } catch (e) {
    return { error: e.message };
  }
}

export function summarizeRuns(runs) {
  const list = Array.isArray(runs) ? runs : [];
  let tokensIn = 0;
  let tokensOut = 0;
  let cost = 0;
  let costKnown = false;
  let errors = 0;
  for (const r of list) {
    tokensIn += Number(r.input_tokens) || 0;
    tokensOut += Number(r.output_tokens) || 0;
    if (r.estimated_cost_usd != null) {
      cost += Number(r.estimated_cost_usd) || 0;
      costKnown = true;
    }
    if (r.status !== "ok") errors++;
  }
  return { calls: list.length, tokensIn, tokensOut, cost: costKnown ? cost : null, errors };
}

// ─────────────────────────────── render

export async function renderAiMenuImportPage(el, ctx) {
  _ctx = ctx || null;
  const { supabase, escapeHtml, fmtDate } = _deps();
  const since = new Date(Date.now() - 30 * 24 * 3600 * 1000).toISOString();

  const [cfgRes, jobsRes, tplRes, runsRes] = await Promise.all([
    supabase.from("system_config").select("key, value").in("key", AI_IMPORT_CONFIG_KEYS),
    supabase
      .from("merchant_import_jobs")
      .select("id, merchant_id, mode, status, total_files, total_items, low_confidence_items, visibility, error, created_at, published_at, hidden_at, merchant:profiles!merchant_import_jobs_merchant_id_fkey(full_name)")
      .neq("status", "uploading")
      .order("created_at", { ascending: false })
      .limit(60),
    supabase.from("option_templates").select("*").order("store_type").order("sort_order"),
    supabase.from("ai_runs").select("input_tokens, output_tokens, estimated_cost_usd, status").gte("created_at", since).limit(5000),
  ]);

  const firstError = [cfgRes, jobsRes, tplRes, runsRes].find((r) => r.error)?.error;
  if (firstError) {
    el.innerHTML = `<div class="glass-card p-6 text-red-500">โหลดข้อมูลไม่สำเร็จ: ${escapeHtml(firstError.message)}
      <div class="text-xs text-gray-400 mt-2">ถ้าเพิ่ง deploy ให้ตรวจว่า migration 20260926120000_ai_menu_import_v1 ถูก apply แล้ว</div></div>`;
    return;
  }

  const kv = Object.fromEntries((cfgRes.data || []).map((r) => [r.key, r.value]));
  const jobs = jobsRes.data || [];
  const templates = tplRes.data || [];
  const stats = summarizeRuns(runsRes.data);
  globalThis._aiImportTemplates = templates;
  globalThis._aiImportJobs = jobs;

  const on = (k) => String(kv[k] || "").toLowerCase() === "true";
  const inputCls = "w-full border border-gray-200 rounded-xl px-3 py-2 text-sm";

  const jobRows = jobs.map((j) => {
    const [label, cls] = STATUS[j.status] || [j.status, "bg-gray-100 text-gray-500 border-gray-200"];
    const vis = j.status === "published"
      ? (j.hidden_at ? "ซ่อนทั้งชุดแล้ว" : j.visibility === "live" ? "เปิดขายทันที" : "ซ่อนไว้ก่อน")
      : "";
    return `
      <tr class="border-b border-gray-100 hover:bg-gray-50">
        <td class="px-3 py-3 text-sm text-gray-600 whitespace-nowrap">${escapeHtml(fmtDate ? fmtDate(j.created_at) : j.created_at)}</td>
        <td class="px-3 py-3">
          <div class="font-semibold text-gray-800">${escapeHtml(j.merchant?.full_name || "-")}</div>
          <div class="text-[11px] text-gray-400">${escapeHtml(j.merchant_id)}</div>
        </td>
        <td class="px-3 py-3 text-sm text-gray-600">${j.mode === "append" ? "ร้านเดิมเพิ่มเมนู" : "ร้านใหม่"}</td>
        <td class="px-3 py-3"><span class="inline-flex px-2.5 py-0.5 rounded-lg text-xs font-semibold border ${cls}">${label}</span>
          ${j.error ? `<div class="text-[11px] text-red-400 mt-1">${escapeHtml(j.error)}</div>` : ""}</td>
        <td class="px-3 py-3 text-sm text-gray-600">${j.total_files} รูป · ${j.total_items} รายการ${j.low_confidence_items ? ` · ต้องตรวจ ${j.low_confidence_items}` : ""}</td>
        <td class="px-3 py-3 text-xs text-gray-500">${vis}</td>
        <td class="px-3 py-3 text-right whitespace-nowrap">
          <button onclick="viewAiImportItems('${j.id}')" class="px-3 py-1.5 rounded-lg text-xs font-semibold bg-blue-50 text-blue-600 border border-blue-200 hover:bg-blue-100">รายการ</button>
          ${j.status === "published" && !j.hidden_at
            ? `<button onclick="hideAiImportItems('${j.id}')" class="px-3 py-1.5 rounded-lg text-xs font-semibold bg-red-50 text-red-600 border border-red-200 hover:bg-red-100 ml-1">ซ่อนทั้งชุด</button>`
            : ""}
          <button onclick="editAiImportQuota('${j.merchant_id}')" class="px-3 py-1.5 rounded-lg text-xs font-semibold bg-gray-50 text-gray-600 border border-gray-200 hover:bg-gray-100 ml-1">โควตา</button>
        </td>
      </tr>`;
  }).join("");

  const tplRows = templates.map((t) => `
      <tr class="border-b border-gray-100 hover:bg-gray-50 ${t.is_active ? "" : "opacity-50"}">
        <td class="px-3 py-3 text-sm text-gray-600">${escapeHtml((STORE_TYPES.find(([k]) => k === t.store_type) || [0, t.store_type])[1])}</td>
        <td class="px-3 py-3 font-semibold text-gray-800">${escapeHtml(t.name)}
          <div class="text-[11px] text-gray-400">${t.min_selection >= 1 ? `ต้องเลือก ${t.min_selection}` : `ไม่บังคับ · สูงสุด ${t.max_selection}`} · v${t.version}</div></td>
        <td class="px-3 py-3 text-sm text-gray-600">${escapeHtml((t.options || []).map((o) => (o.price > 0 ? `${o.label} +${o.price}` : o.label)).join(" · "))}</td>
        <td class="px-3 py-3 text-xs text-gray-500">${escapeHtml((t.match_keywords || []).join(", ") || "— ร้านเลือกเมนูเอง")}
          ${(t.exclude_keywords || []).length ? `<div class="text-red-400">ยกเว้น: ${escapeHtml(t.exclude_keywords.join(", "))}</div>` : ""}</td>
        <td class="px-3 py-3 text-right"><button onclick="editAiTemplate('${t.id}')" class="px-3 py-1.5 rounded-lg text-xs font-semibold bg-blue-50 text-blue-600 border border-blue-200 hover:bg-blue-100">แก้ไข</button></td>
      </tr>`).join("");

  el.innerHTML = `
    <div class="fade-in space-y-5">
      <div data-tab="overview" class="grid grid-cols-1 md:grid-cols-4 gap-4">
        <div class="glass-card p-4"><div class="text-xs text-gray-400 mb-1">เรียก AI (30 วัน)</div><div class="text-2xl font-bold text-gray-800">${stats.calls}</div>
          <div class="text-[11px] text-red-400">${stats.errors ? `ผิดพลาด ${stats.errors}` : ""}</div></div>
        <div class="glass-card p-4"><div class="text-xs text-gray-400 mb-1">Token เข้า / ออก</div><div class="text-lg font-bold text-gray-800">${stats.tokensIn.toLocaleString()} / ${stats.tokensOut.toLocaleString()}</div></div>
        <div class="glass-card p-4"><div class="text-xs text-gray-400 mb-1">ค่าใช้จ่ายประมาณ (USD)</div><div class="text-2xl font-bold text-gray-800">${stats.cost == null ? "–" : stats.cost.toFixed(2)}</div>
          <div class="text-[11px] text-gray-400">${stats.cost == null ? "ตั้ง secret OPENAI_PRICE_* เพื่อคำนวณ" : ""}</div></div>
        <div class="glass-card p-4"><div class="text-xs text-gray-400 mb-1">งานนำเข้า (ล่าสุด 60)</div><div class="text-2xl font-bold text-gray-800">${jobs.length}</div></div>
      </div>

      <div class="glass-card p-5">
        <h3 class="font-bold text-gray-800 mb-1">ตั้งค่า</h3>
        <p class="text-xs text-gray-400 mb-4">ปิดไว้ตอน deploy — เปิดเมื่อตั้ง OPENAI_API_KEY / OPENAI_VISION_MODEL แล้ว · ร้านซักรีดยังใช้ไม่ได้ (V1)</p>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <label class="flex items-center gap-2 text-sm"><input type="checkbox" id="aiimp_onboarding" ${on("ai_menu_import_onboarding_enabled") ? "checked" : ""}> เปิดให้ร้านใหม่ (ยังไม่อนุมัติ)</label>
          <label class="flex items-center gap-2 text-sm"><input type="checkbox" id="aiimp_append" ${on("ai_menu_import_append_enabled") ? "checked" : ""}> เปิดให้ร้านเดิมเพิ่มเมนู</label>
          <div></div>
          <div><label class="block text-xs font-semibold text-gray-500 mb-1">โควตาร้านใหม่ (ครั้ง)</label><input id="aiimp_quota_onb" type="number" min="0" value="${escapeHtml(kv.ai_menu_import_quota_onboarding ?? "3")}" class="${inputCls}"></div>
          <div><label class="block text-xs font-semibold text-gray-500 mb-1">โควตาร้านเดิม (ครั้ง/เดือน)</label><input id="aiimp_quota_app" type="number" min="0" value="${escapeHtml(kv.ai_menu_import_quota_append_month ?? "5")}" class="${inputCls}"></div>
          <div><label class="block text-xs font-semibold text-gray-500 mb-1">รูปสูงสุดต่อครั้ง</label><input id="aiimp_max_files" type="number" min="1" max="8" value="${escapeHtml(kv.ai_menu_import_max_files ?? "8")}" class="${inputCls}"></div>
          <div class="md:col-span-3"><label class="block text-xs font-semibold text-gray-500 mb-1">Allowlist ร้านทดลอง (merchant id คั่นด้วย comma — ว่าง = ทุกร้าน)</label>
            <textarea id="aiimp_allowlist" rows="2" class="${inputCls}">${escapeHtml(kv.ai_menu_import_allowlist || "")}</textarea></div>
        </div>
        <div class="mt-4 text-right"><button onclick="saveAiImportConfig()" class="px-4 py-2 rounded-xl text-sm font-semibold text-white bg-indigo-600 hover:bg-indigo-700">บันทึกการตั้งค่า</button></div>
      </div>

      <div data-tab="history" class="glass-card overflow-x-auto">
        <div class="p-4 font-bold text-gray-800">ประวัติการนำเข้า</div>
        <table class="w-full text-left">
          <thead><tr class="text-xs text-gray-400 uppercase border-b border-gray-100">
            <th class="px-3 py-3 font-semibold">เวลา</th><th class="px-3 py-3 font-semibold">ร้าน</th><th class="px-3 py-3 font-semibold">โหมด</th>
            <th class="px-3 py-3 font-semibold">สถานะ</th><th class="px-3 py-3 font-semibold">ผล</th><th class="px-3 py-3 font-semibold">หลังบันทึก</th><th class="px-3 py-3"></th>
          </tr></thead>
          <tbody>${jobRows || `<tr><td colspan="7" class="px-3 py-10 text-center text-gray-400">ยังไม่มีการนำเข้า</td></tr>`}</tbody>
        </table>
      </div>

      <div data-tab="templates" class="glass-card overflow-x-auto">
        <div class="p-4 flex items-center justify-between">
          <div><div class="font-bold text-gray-800">แม่แบบชุดตัวเลือกแนะนำ</div>
            <div class="text-xs text-gray-400">ร้านเห็นเป็นข้อเสนอ ต้องติ๊กใช้เอง · ราคาในแม่แบบเป็นค่าตั้งต้นที่ร้านแก้ได้</div></div>
          <button onclick="editAiTemplate(null)" class="px-4 py-2 rounded-xl text-sm font-semibold text-white bg-indigo-600 hover:bg-indigo-700"><span class="material-icons-round text-sm align-middle">add</span> เพิ่มแม่แบบ</button>
        </div>
        <table class="w-full text-left">
          <thead><tr class="text-xs text-gray-400 uppercase border-b border-gray-100">
            <th class="px-3 py-3 font-semibold">ประเภทร้าน</th><th class="px-3 py-3 font-semibold">ชุด</th><th class="px-3 py-3 font-semibold">ตัวเลือก</th><th class="px-3 py-3 font-semibold">จับคู่เมนู (คำในชื่อ/หมวด)</th><th class="px-3 py-3"></th>
          </tr></thead>
          <tbody>${tplRows || `<tr><td colspan="5" class="px-3 py-10 text-center text-gray-400">ยังไม่มีแม่แบบ</td></tr>`}</tbody>
        </table>
      </div>

      <div data-tab="*" id="aiImportDialog"></div>
    </div>`;

  mountPageTabs(el.querySelector(".fade-in"), {
    key: "adminAiImportTab",
    tabs: [
      { id: "overview", label: "ภาพรวม & ตั้งค่า", icon: "tune" },
      { id: "history", label: "ประวัติการนำเข้า", icon: "history",
        badge: jobs.filter((j) => j.status === "review_required" || j.status === "ready").length },
      { id: "templates", label: "แม่แบบตัวเลือก", icon: "checklist" },
    ],
  });

  globalThis.saveAiImportConfig = saveAiImportConfig;
  globalThis.hideAiImportItems = hideAiImportItems;
  globalThis.viewAiImportItems = viewAiImportItems;
  globalThis.editAiImportQuota = editAiImportQuota;
  globalThis.saveAiImportQuota = saveAiImportQuota;
  globalThis.editAiTemplate = editAiTemplate;
  globalThis.saveAiTemplate = saveAiTemplate;
  globalThis.closeAiImportDialog = closeAiImportDialog;
}

// ─────────────────────────────── actions

function _val(id) {
  const el = document.getElementById(id);
  if (!el) return null;
  return el.type === "checkbox" ? el.checked : el.value;
}

export async function saveAiImportConfig() {
  const { showToast, upsertConfig } = _deps();
  const result = collectAiImportConfig(_val);
  if (result.error) return showToast?.(result.error, "error");
  if (typeof upsertConfig !== "function") return showToast?.("บันทึกไม่ได้: ไม่พบตัวช่วยบันทึกค่าระบบ", "error");
  try {
    await upsertConfig(result.rows);
    showToast?.("บันทึกการตั้งค่า AI นำเข้าเมนูแล้ว", "success");
  } catch (e) {
    showToast?.("บันทึกไม่สำเร็จ: " + (e?.message || e), "error");
  }
}

export async function hideAiImportItems(jobId) {
  const { supabase, showToast, refreshCurrentPage } = _deps();
  if (!globalThis.confirm("ซ่อนเมนูทั้งหมดที่เพิ่มจากงานนี้? (ไม่ลบ ออเดอร์เดิมไม่กระทบ ร้านเปิดขายคืนเองได้)")) return;
  const { data, error } = await supabase.rpc("merchant_hide_import_items", { p_job_id: jobId });
  if (error) return showToast?.("ซ่อนไม่สำเร็จ: " + error.message, "error");
  showToast?.(`ซ่อน ${data ?? 0} เมนูแล้ว`, "success");
  refreshCurrentPage?.();
}

export async function viewAiImportItems(jobId) {
  const { supabase, escapeHtml } = _deps();
  const host = document.getElementById("aiImportDialog");
  if (!host) return;
  const { data, error } = await supabase
    .from("merchant_import_items")
    .select("name, category, price, status, action, match_type, matched_price, issues, variants_json, addons_json")
    .eq("import_job_id", jobId)
    .order("sort_order");
  const rows = (data || []).map((i) => `
    <tr class="border-b border-gray-100 ${i.action === "skip" || i.status === "rejected" ? "opacity-50" : ""}">
      <td class="py-2 pr-3 text-sm font-semibold text-gray-800">${escapeHtml(i.name)}</td>
      <td class="py-2 pr-3 text-xs text-gray-500">${escapeHtml(i.category || "-")}</td>
      <td class="py-2 pr-3 text-sm">${i.price == null ? "–" : `฿${Math.round(i.price)}`}${(i.variants_json || []).length >= 2 ? `<div class="text-[11px] text-gray-400">${escapeHtml(i.variants_json.map((v) => `${v.label} ${v.price ?? "-"}`).join(" / "))}</div>` : ""}</td>
      <td class="py-2 pr-3 text-xs text-gray-500">${escapeHtml(i.status)}${i.action === "skip" ? ` · ข้าม (${escapeHtml(i.match_type)}${i.matched_price != null ? ` เดิม ฿${Math.round(i.matched_price)}` : ""})` : ""}</td>
      <td class="py-2 text-[11px] text-red-400">${escapeHtml((i.issues || []).join(", "))}</td>
    </tr>`).join("");
  host.innerHTML = `
    <div class="fixed inset-0 bg-black/40 flex items-start justify-center z-50 overflow-y-auto py-8" onclick="if(event.target===this)closeAiImportDialog()">
      <div class="bg-white rounded-2xl p-6 w-full max-w-4xl mx-4 shadow-2xl">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-bold text-gray-800">รายการจากงานนำเข้า</h3>
          <button onclick="closeAiImportDialog()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
        </div>
        ${error ? `<p class="text-red-500">${escapeHtml(error.message)}</p>` : `
        <table class="w-full text-left"><thead><tr class="text-xs text-gray-400 border-b border-gray-100">
          <th class="py-2 pr-3">ชื่อ</th><th class="py-2 pr-3">หมวด</th><th class="py-2 pr-3">ราคา</th><th class="py-2 pr-3">สถานะ</th><th class="py-2">ประเด็น</th>
        </tr></thead><tbody>${rows || `<tr><td colspan="5" class="py-6 text-center text-gray-400">ไม่มีรายการ</td></tr>`}</tbody></table>`}
      </div>
    </div>`;
}

export async function editAiImportQuota(merchantId) {
  const { supabase, escapeHtml } = _deps();
  const host = document.getElementById("aiImportDialog");
  if (!host) return;
  const { data } = await supabase
    .from("merchant_ai_import_quota")
    .select("extra_onboarding, extra_append_monthly")
    .eq("merchant_id", merchantId)
    .maybeSingle();
  host.innerHTML = `
    <div class="fixed inset-0 bg-black/40 flex items-start justify-center z-50 overflow-y-auto py-8" onclick="if(event.target===this)closeAiImportDialog()">
      <div class="bg-white rounded-2xl p-6 w-full max-w-md mx-4 shadow-2xl">
        <h3 class="text-lg font-bold text-gray-800 mb-1">เพิ่มโควตารายร้าน</h3>
        <p class="text-[11px] text-gray-400 mb-4">${escapeHtml(merchantId)} — บวกเพิ่มจากค่ากลาง</p>
        <input type="hidden" id="aiq_merchant" value="${escapeHtml(merchantId)}">
        <label class="block text-xs font-semibold text-gray-500 mb-1">เพิ่มโควตาร้านใหม่ (ครั้ง)</label>
        <input id="aiq_onb" type="number" min="0" value="${data?.extra_onboarding ?? 0}" class="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm mb-3">
        <label class="block text-xs font-semibold text-gray-500 mb-1">เพิ่มโควตาร้านเดิม (ครั้ง/เดือน)</label>
        <input id="aiq_app" type="number" min="0" value="${data?.extra_append_monthly ?? 0}" class="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm mb-4">
        <div class="flex justify-end gap-2">
          <button onclick="closeAiImportDialog()" class="px-4 py-2 rounded-xl text-sm bg-gray-100">ยกเลิก</button>
          <button onclick="saveAiImportQuota()" class="px-4 py-2 rounded-xl text-sm font-semibold text-white bg-indigo-600">บันทึก</button>
        </div>
      </div>
    </div>`;
}

export async function saveAiImportQuota() {
  const { supabase, showToast } = _deps();
  const merchantId = String(_val("aiq_merchant") || "");
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(merchantId)) {
    return showToast?.("รหัสร้านไม่ถูกต้อง", "error");
  }
  const eo = Number(_val("aiq_onb"));
  const ea = Number(_val("aiq_app"));
  if (![eo, ea].every((n) => Number.isInteger(n) && n >= 0 && n <= 100)) {
    return showToast?.("โควตาต้องเป็นจำนวนเต็ม 0–100", "error");
  }
  const { data: auth } = await supabase.auth.getUser();
  const { error } = await supabase.from("merchant_ai_import_quota").upsert({
    merchant_id: merchantId,
    extra_onboarding: eo,
    extra_append_monthly: ea,
    updated_by: auth?.user?.id ?? null,
    updated_at: new Date().toISOString(),
  });
  if (error) return showToast?.("บันทึกไม่สำเร็จ: " + error.message, "error");
  showToast?.("บันทึกโควตาแล้ว", "success");
  closeAiImportDialog();
}

export function editAiTemplate(id) {
  const { escapeHtml } = _deps();
  const t = id ? (globalThis._aiImportTemplates || []).find((x) => x.id === id) : null;
  const host = document.getElementById("aiImportDialog");
  if (!host) return;
  const inputCls = "w-full border border-gray-200 rounded-xl px-3 py-2 text-sm";
  host.innerHTML = `
    <div class="fixed inset-0 bg-black/40 flex items-start justify-center z-50 overflow-y-auto py-8" onclick="if(event.target===this)closeAiImportDialog()">
      <div class="bg-white rounded-2xl p-6 w-full max-w-2xl mx-4 shadow-2xl">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-bold text-gray-800">${t ? "แก้ไขแม่แบบ" : "เพิ่มแม่แบบ"}</h3>
          <button onclick="closeAiImportDialog()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
        </div>
        <input type="hidden" id="tpl_id" value="${t?.id || ""}">
        <input type="hidden" id="tpl_version" value="${t?.version || 0}">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div><label class="block text-xs font-semibold text-gray-500 mb-1">ประเภทร้าน</label>
            <select id="tpl_store_type" class="${inputCls}">${STORE_TYPES.map(([k, l]) => `<option value="${k}" ${t?.store_type === k ? "selected" : ""}>${l}</option>`).join("")}</select></div>
          <div><label class="block text-xs font-semibold text-gray-500 mb-1">ชื่อชุดตัวเลือก</label>
            <input id="tpl_name" value="${escapeHtml(t?.name || "")}" class="${inputCls}"></div>
          <div><label class="block text-xs font-semibold text-gray-500 mb-1">ต้องเลือกขั้นต่ำ</label>
            <input id="tpl_min" type="number" min="0" value="${t?.min_selection ?? 0}" class="${inputCls}"></div>
          <div><label class="block text-xs font-semibold text-gray-500 mb-1">เลือกได้สูงสุด</label>
            <input id="tpl_max" type="number" min="1" value="${t?.max_selection ?? 1}" class="${inputCls}"></div>
          <div class="md:col-span-2"><label class="block text-xs font-semibold text-gray-500 mb-1">ตัวเลือก (บรรทัดละ 1 · ใส่ราคาด้วย "=" เช่น ไข่ดาว=10)</label>
            <textarea id="tpl_options" rows="5" class="${inputCls}">${escapeHtml(formatOptionsText(t?.options))}</textarea></div>
          <div class="md:col-span-2"><label class="block text-xs font-semibold text-gray-500 mb-1">คำจับคู่เมนู (คั่นด้วย comma · ว่าง = ร้านเลือกเมนูเอง)</label>
            <input id="tpl_match" value="${escapeHtml((t?.match_keywords || []).join(", "))}" class="${inputCls}"></div>
          <div class="md:col-span-2"><label class="block text-xs font-semibold text-gray-500 mb-1">คำยกเว้น (เมนูที่มีคำนี้ในชื่อจะไม่ถูกเสนอ)</label>
            <input id="tpl_exclude" value="${escapeHtml((t?.exclude_keywords || []).join(", "))}" class="${inputCls}"></div>
          <div><label class="block text-xs font-semibold text-gray-500 mb-1">ลำดับ</label>
            <input id="tpl_sort" type="number" value="${t?.sort_order ?? 0}" class="${inputCls}"></div>
          <label class="flex items-center gap-2 text-sm mt-6"><input type="checkbox" id="tpl_active" ${t ? (t.is_active ? "checked" : "") : "checked"}> เปิดใช้งาน</label>
        </div>
        <div class="flex justify-end gap-2 mt-5">
          <button onclick="closeAiImportDialog()" class="px-4 py-2 rounded-xl text-sm bg-gray-100">ยกเลิก</button>
          <button onclick="saveAiTemplate()" class="px-4 py-2 rounded-xl text-sm font-semibold text-white bg-indigo-600">บันทึก</button>
        </div>
      </div>
    </div>`;
}

export async function saveAiTemplate() {
  const { supabase, showToast, refreshCurrentPage } = _deps();
  const result = buildTemplateRow({
    store_type: _val("tpl_store_type"),
    name: _val("tpl_name"),
    min_selection: _val("tpl_min"),
    max_selection: _val("tpl_max"),
    options_text: _val("tpl_options"),
    match_keywords: _val("tpl_match"),
    exclude_keywords: _val("tpl_exclude"),
    sort_order: _val("tpl_sort"),
    is_active: _val("tpl_active") === true,
  });
  if (result.error) return showToast?.(result.error, "error");
  const id = _val("tpl_id");
  const version = Number(_val("tpl_version")) || 0;
  const row = { ...result.row, version: version + 1, updated_at: new Date().toISOString() };
  const { error } = id
    ? await supabase.from("option_templates").update(row).eq("id", id)
    : await supabase.from("option_templates").insert({ ...row, version: 1 });
  if (error) return showToast?.("บันทึกไม่สำเร็จ: " + error.message, "error");
  showToast?.("บันทึกแม่แบบแล้ว", "success");
  closeAiImportDialog();
  refreshCurrentPage?.();
}

export function closeAiImportDialog() {
  const host = document.getElementById("aiImportDialog");
  if (host) host.innerHTML = "";
}
