// ตั้งค่า AI (OpenAI) — section ในหน้า Settings
//
// - API key เขียนได้อย่างเดียว: ส่งเข้า RPC admin_set_openai_api_key → เก็บใน Supabase Vault
//   หน้าเว็บเห็นแค่ "ตั้งแล้ว …1234" ไม่มีทางอ่านคีย์เต็มกลับมา
// - รุ่น + ราคา/ล้าน token เก็บใน system_config (ใช้คำนวณค่าใช้จ่ายตอนเรียก AI)
// - ค่าใช้จ่ายสรุปจาก RPC admin_ai_cost_summary (ai_runs)

export const AI_SETTINGS_KEYS = [
  "ai_openai_model",
  "ai_openai_price_input_per_mtok",
  "ai_openai_price_output_per_mtok",
];

const KEY_RE = /^sk-[A-Za-z0-9_-]{17,297}$/;

// รุ่นที่เลือกได้ + ราคา (USD / 1M token, Standard tier) — อ้างอิง
// https://developers.openai.com/api/docs/pricing ณ 2026-09-26 (หน้า models ระบุว่ารุ่นล่าสุดรับรูปได้ทุกรุ่น)
// ราคาเปลี่ยนได้ — แอดมินแก้ช่องราคาเองได้เสมอ และเลือก "กำหนดเอง" สำหรับรุ่นที่ไม่อยู่ในรายการ
export const AI_MODEL_PRICES_AS_OF = "2026-09-26";
export const AI_MODEL_PRESETS = [
  { id: "gpt-6-luna", label: "GPT-6 Luna — ประหยัด งานปริมาณมาก (แนะนำเริ่มต้น)", input: 0.1, output: 0.5 },
  { id: "gpt-6-sol", label: "GPT-6 Sol — แม่นขึ้น", input: 2, output: 10 },
  { id: "gpt-6-astra", label: "GPT-6 Astra — แม่นที่สุด ราคาสูง", input: 10, output: 50 },
  { id: "gpt-5.6-luna", label: "GPT-5.6 Luna", input: 0.2, output: 1.2 },
  { id: "gpt-5.6-terra", label: "GPT-5.6 Terra", input: 2, output: 12 },
  { id: "gpt-5.4-mini", label: "GPT-5.4 mini", input: 0.75, output: 4.5 },
  { id: "gpt-5-mini", label: "GPT-5 mini", input: 0.25, output: 2 },
  { id: "gpt-4.1-mini", label: "GPT-4.1 mini", input: 0.4, output: 1.6 },
  { id: "gpt-4o-mini", label: "GPT-4o mini", input: 0.15, output: 0.6 },
];
export const CUSTOM_MODEL = "__custom__";

export function findModelPreset(id) {
  return AI_MODEL_PRESETS.find((m) => m.id === String(id || "").trim()) || null;
}

/** ค่าใช้จ่ายโดยประมาณต่อ 1 งาน (รูปเมนู N รูป) — ใช้แสดงเทียบรุ่นเท่านั้น
 *  สมมติ ~1,600 input token ต่อรูป (รูปละเอียดสูง) + ~1,500 output token ต่อรูป */
export function estimateJobCostUsd(preset, images = 3) {
  if (!preset) return null;
  const inTok = 1600 * images;
  const outTok = 1500 * images;
  return (inTok * preset.input + outTok * preset.output) / 1_000_000;
}

let _ctx = null;

function _deps() {
  return {
    supabase: _ctx?.supabase || globalThis.supabase,
    escapeHtml: _ctx?.escapeHtml || globalThis.escapeHtml,
    fmtDate: _ctx?.fmtDate || globalThis.fmtDate,
    showToast: _ctx?.showToast || globalThis.showToast,
    upsertConfig: _ctx?._upsertSystemConfigKeyValues || globalThis._upsertSystemConfigKeyValues,
  };
}

/** ตรวจคีย์ฝั่งหน้าเว็บก่อนส่ง (server ตรวจซ้ำ) */
export function validateOpenAIKey(value) {
  const key = String(value || "").trim();
  if (!key) return { error: "กรุณาวาง API key" };
  if (!KEY_RE.test(key)) return { error: "รูปแบบ API key ไม่ถูกต้อง (ต้องขึ้นต้นด้วย sk-)" };
  return { key };
}

/** ตรวจรุ่น/ราคา → rows สำหรับ system_config */
export function collectAiModelSettings(get) {
  const model = String(get("ai_model") || "").trim();
  if (!model) return { error: "กรุณาใส่ชื่อรุ่น (model) ที่รองรับการอ่านรูป" };
  if (!/^[A-Za-z0-9._:-]{2,80}$/.test(model)) return { error: "ชื่อรุ่นมีอักขระไม่ถูกต้อง" };
  const price = (id, label) => {
    const raw = String(get(id) ?? "").trim();
    if (raw === "") return "";
    const n = Number(raw);
    if (!Number.isFinite(n) || n < 0 || n > 1000) throw new Error(`${label} ต้องเป็นตัวเลข 0–1000`);
    return String(n);
  };
  try {
    return {
      rows: [
        { key: "ai_openai_model", value: model },
        { key: "ai_openai_price_input_per_mtok", value: price("ai_price_in", "ราคา input") },
        { key: "ai_openai_price_output_per_mtok", value: price("ai_price_out", "ราคา output") },
      ],
    };
  } catch (e) {
    return { error: e.message };
  }
}

export function formatUsd(value) {
  const n = Number(value) || 0;
  return n < 1 ? `$${n.toFixed(4)}` : `$${n.toFixed(2)}`;
}

export function renderCostCard(label, s) {
  const stats = s || {};
  const unpriced = Number(stats.unpriced_calls) || 0;
  return `
    <div class="rounded-xl border border-gray-100 p-4">
      <div class="text-xs text-gray-400 mb-1">${label}</div>
      <div class="text-xl font-bold text-gray-800">${formatUsd(stats.cost_usd)}</div>
      <div class="text-[11px] text-gray-500 mt-1">${Number(stats.calls) || 0} ครั้ง · ${Number(stats.jobs) || 0} งาน · token ${(Number(stats.input_tokens) || 0).toLocaleString()} / ${(Number(stats.output_tokens) || 0).toLocaleString()}</div>
      ${Number(stats.errors) ? `<div class="text-[11px] text-red-500">ผิดพลาด ${Number(stats.errors)} ครั้ง</div>` : ""}
      ${unpriced ? `<div class="text-[11px] text-amber-600">${unpriced} ครั้งไม่ได้คิดเงิน (ตอนนั้นยังไม่ตั้งราคา)</div>` : ""}
    </div>`;
}

export function renderAiSettingsBody(settings, costs, escapeHtml, fmtDate) {
  const s = settings || {};
  const inputCls = "w-full border border-gray-200 rounded-xl px-3 py-2 text-sm";
  // ยังไม่ตั้งรุ่น → เสนอรุ่นแรก (แนะนำ) · ตั้งรุ่นนอกรายการไว้ → กำหนดเอง
  const selectedPreset = !s.model ? AI_MODEL_PRESETS[0].id : (findModelPreset(s.model) ? s.model : CUSTOM_MODEL);
  const keyStatus = s.key_set
    ? `<span class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-lg text-xs font-semibold bg-emerald-50 text-emerald-600 border border-emerald-200">ตั้งแล้ว ${escapeHtml(s.key_hint || "")}</span>
       <span class="text-[11px] text-gray-400 ml-2">${s.key_updated_at ? `อัปเดต ${escapeHtml(fmtDate ? fmtDate(s.key_updated_at) : s.key_updated_at)}` : ""}</span>`
    : `<span class="inline-flex px-2.5 py-0.5 rounded-lg text-xs font-semibold bg-amber-50 text-amber-700 border border-amber-200">ยังไม่ได้ตั้ง — ฟีเจอร์ AI จะใช้งานไม่ได้</span>`;
  return `
    <div class="space-y-5">
      <div>
        <label class="block text-xs font-semibold text-gray-500 mb-1">OpenAI API key</label>
        <div class="mb-2">${keyStatus}</div>
        <div class="flex gap-2">
          <input id="ai_api_key" type="password" autocomplete="off" spellcheck="false" placeholder="${s.key_set ? "วางคีย์ใหม่เพื่อเปลี่ยน" : "sk-..."}" class="${inputCls} font-mono">
          <button onclick="saveOpenAIKey()" class="px-4 py-2 rounded-xl text-sm font-semibold text-white bg-indigo-600 hover:bg-indigo-700 whitespace-nowrap">บันทึกคีย์</button>
          ${s.key_set ? `<button onclick="clearOpenAIKey()" class="px-4 py-2 rounded-xl text-sm font-semibold bg-red-50 text-red-600 border border-red-200 whitespace-nowrap">ลบคีย์</button>` : ""}
        </div>
        <p class="text-[11px] text-gray-400 mt-1">เก็บใน Supabase Vault — หลังบันทึกจะไม่แสดงคีย์เต็มอีก · ถ้าตั้ง secret OPENAI_API_KEY ของ Edge Function ไว้ จะใช้ค่านั้นก่อน</p>
      </div>
      <div>
        <label class="block text-xs font-semibold text-gray-500 mb-1">เลือกรุ่น (ราคา USD ต่อ 1M token · input / output)</label>
        <select id="ai_model_preset" onchange="applyAiModelPreset()" class="${inputCls}">
          ${AI_MODEL_PRESETS.map((m) => `<option value="${m.id}" ${m.id === selectedPreset ? "selected" : ""}>${escapeHtml(m.label)} · $${m.input} / $${m.output} · ~${formatUsd(estimateJobCostUsd(m))}/งาน 3 รูป</option>`).join("")}
          <option value="${CUSTOM_MODEL}" ${selectedPreset === CUSTOM_MODEL ? "selected" : ""}>กำหนดเอง (พิมพ์ชื่อรุ่นและราคาเอง)</option>
        </select>
        <p class="text-[11px] text-gray-400 mt-1">ราคาอ้างอิงหน้า pricing ของ OpenAI ณ ${AI_MODEL_PRICES_AS_OF} — ตรวจกับหน้า pricing ก่อนใช้งานจริง · ค่าต่องานเป็นการประมาณคร่าว ๆ</p>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div><label class="block text-xs font-semibold text-gray-500 mb-1">รุ่น (model)</label>
          <input id="ai_model" value="${escapeHtml(s.model || "")}" ${selectedPreset === CUSTOM_MODEL ? "" : "readonly"} placeholder="ชื่อรุ่นที่อ่านรูปได้" class="${inputCls} ${selectedPreset === CUSTOM_MODEL ? "" : "bg-gray-50 text-gray-500"}"></div>
        <div><label class="block text-xs font-semibold text-gray-500 mb-1">ราคา input (USD / 1M token)</label>
          <input id="ai_price_in" type="number" step="0.001" min="0" value="${escapeHtml(s.price_input_per_mtok || "")}" class="${inputCls}"></div>
        <div><label class="block text-xs font-semibold text-gray-500 mb-1">ราคา output (USD / 1M token)</label>
          <input id="ai_price_out" type="number" step="0.001" min="0" value="${escapeHtml(s.price_output_per_mtok || "")}" class="${inputCls}"></div>
      </div>
      <p class="text-[11px] text-gray-400 -mt-3">ดูราคาจากหน้า pricing ของ OpenAI ตามรุ่นที่เลือก — ใช้คำนวณค่าใช้จ่ายของการเรียกครั้งถัดไป (ครั้งก่อนหน้าไม่ถูกคิดย้อนหลัง)</p>
      <div class="flex justify-end">
        <button onclick="saveAiModelSettings()" class="px-4 py-2 rounded-xl text-sm font-semibold text-white bg-indigo-600 hover:bg-indigo-700">บันทึกรุ่นและราคา</button>
      </div>
      <div>
        <div class="text-sm font-bold text-gray-700 mb-2">ค่าใช้จ่าย AI (ประมาณการ)</div>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
          ${renderCostCard("วันนี้", costs?.today)}
          ${renderCostCard("เดือนนี้", costs?.month)}
          ${renderCostCard("30 วันล่าสุด", costs?.last_30_days)}
        </div>
      </div>
    </div>`;
}

export function renderAiSettingsSection() {
  return `
    <div class="glass-card p-6" id="aiSettingsCard">
      <div class="flex items-center gap-3 mb-5">
        <div class="w-10 h-10 bg-indigo-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-indigo-500">auto_awesome</span></div>
        <div>
          <h3 class="font-bold text-gray-800">AI (OpenAI)</h3>
          <p class="text-xs text-gray-400">ใช้กับ "AI นำเข้าเมนู" — เปิด/ปิดฟีเจอร์และโควตาอยู่ที่หน้า AI นำเข้าเมนู</p>
        </div>
      </div>
      <div id="aiSettingsBody" class="text-sm text-gray-400">กำลังโหลด…</div>
    </div>`;
}

export async function loadAiSettingsSection(ctx) {
  if (ctx) _ctx = ctx;
  const { supabase, escapeHtml, fmtDate } = _deps();
  const body = document.getElementById("aiSettingsBody");
  if (!body) return;
  const [settingsRes, costRes] = await Promise.all([
    supabase.rpc("admin_get_ai_settings"),
    supabase.rpc("admin_ai_cost_summary"),
  ]);
  if (settingsRes.error) {
    body.innerHTML = `<p class="text-red-500">โหลดไม่สำเร็จ: ${escapeHtml(settingsRes.error.message)}</p>
      <p class="text-[11px] text-gray-400">ตรวจว่า migration 20260926120100_ai_openai_settings ถูก apply แล้ว</p>`;
    return;
  }
  body.innerHTML = renderAiSettingsBody(settingsRes.data, costRes.data, escapeHtml, fmtDate);
  globalThis.saveOpenAIKey = saveOpenAIKey;
  globalThis.clearOpenAIKey = clearOpenAIKey;
  globalThis.saveAiModelSettings = saveAiModelSettings;
  globalThis.applyAiModelPreset = applyAiModelPreset;
  // ยังไม่เคยตั้งรุ่น → เติมค่าของรุ่นแนะนำไว้ให้ (ยังไม่บันทึกจนกดปุ่ม)
  if (!settingsRes.data?.model) applyAiModelPreset();
}

/** เลือกรุ่นจาก dropdown → เติมชื่อรุ่นและราคาให้ · กำหนดเอง → ปลดล็อกช่องให้พิมพ์ */
export function applyAiModelPreset() {
  const select = document.getElementById("ai_model_preset");
  const model = document.getElementById("ai_model");
  const priceIn = document.getElementById("ai_price_in");
  const priceOut = document.getElementById("ai_price_out");
  if (!select || !model) return;
  const preset = findModelPreset(select.value);
  const custom = !preset;
  model.readOnly = !custom;
  model.classList.toggle("bg-gray-50", !custom);
  model.classList.toggle("text-gray-500", !custom);
  if (preset) {
    model.value = preset.id;
    if (priceIn) priceIn.value = String(preset.input);
    if (priceOut) priceOut.value = String(preset.output);
  } else {
    // สลับมากำหนดเอง → ล้างราคาของรุ่นก่อนหน้า กันบันทึกราคาผิดรุ่นโดยไม่ตั้งใจ
    if (priceIn) priceIn.value = "";
    if (priceOut) priceOut.value = "";
    model.focus?.();
  }
}

export async function saveOpenAIKey() {
  const { supabase, showToast } = _deps();
  const input = document.getElementById("ai_api_key");
  const checked = validateOpenAIKey(input?.value);
  if (checked.error) return showToast?.(checked.error, "error");
  const { error } = await supabase.rpc("admin_set_openai_api_key", { p_api_key: checked.key });
  if (input) input.value = "";
  if (error) return showToast?.("บันทึกคีย์ไม่สำเร็จ: " + error.message, "error");
  showToast?.("บันทึก API key แล้ว", "success");
  loadAiSettingsSection();
}

export async function clearOpenAIKey() {
  const { supabase, showToast } = _deps();
  if (!globalThis.confirm("ลบ OpenAI API key? ฟีเจอร์ AI จะหยุดทำงานจนกว่าจะตั้งคีย์ใหม่")) return;
  const { error } = await supabase.rpc("admin_set_openai_api_key", { p_api_key: "" });
  if (error) return showToast?.("ลบคีย์ไม่สำเร็จ: " + error.message, "error");
  showToast?.("ลบ API key แล้ว", "success");
  loadAiSettingsSection();
}

export async function saveAiModelSettings() {
  const { showToast, upsertConfig } = _deps();
  const result = collectAiModelSettings((id) => document.getElementById(id)?.value);
  if (result.error) return showToast?.(result.error, "error");
  if (typeof upsertConfig !== "function") return showToast?.("บันทึกไม่ได้: ไม่พบตัวช่วยบันทึกค่าระบบ", "error");
  try {
    await upsertConfig(result.rows);
    showToast?.("บันทึกรุ่นและราคาแล้ว", "success");
    loadAiSettingsSection();
  } catch (e) {
    showToast?.("บันทึกไม่สำเร็จ: " + (e?.message || e), "error");
  }
}
