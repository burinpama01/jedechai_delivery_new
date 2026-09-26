import test from "node:test";
import assert from "node:assert/strict";
import {
  AI_MODEL_PRESETS,
  collectAiModelSettings,
  CUSTOM_MODEL,
  estimateJobCostUsd,
  findModelPreset,
  formatUsd,
  renderAiSettingsBody,
  validateOpenAIKey,
} from "./aiSettingsSection.js";

const esc = (s) => String(s ?? "").replace(/[&<>"']/g, (m) => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[m]));

test("validateOpenAIKey รับเฉพาะรูปแบบ sk-", () => {
  assert.equal(validateOpenAIKey("  sk-proj-abcdefghijklmnopqrstuvwx ").key, "sk-proj-abcdefghijklmnopqrstuvwx");
  assert.match(validateOpenAIKey("").error, /วาง/);
  assert.match(validateOpenAIKey("abc-123").error, /sk-/);
  assert.match(validateOpenAIKey("sk-short").error, /sk-/);
  assert.match(validateOpenAIKey("sk-abc def ghijklmnopqrstu").error, /sk-/);
});

test("collectAiModelSettings ตรวจรุ่นและราคา", () => {
  const form = { ai_model: "gpt-x-mini", ai_price_in: "0.4", ai_price_out: "1.6" };
  const ok = collectAiModelSettings((id) => form[id]);
  assert.deepEqual(ok.rows.map((r) => r.value), ["gpt-x-mini", "0.4", "1.6"]);
  assert.deepEqual(collectAiModelSettings((id) => ({ ...form, ai_price_in: "" })[id]).rows[1].value, "");
  assert.match(collectAiModelSettings((id) => ({ ...form, ai_model: "" })[id]).error, /รุ่น/);
  assert.match(collectAiModelSettings((id) => ({ ...form, ai_model: "gpt x" })[id]).error, /อักขระ/);
  assert.match(collectAiModelSettings((id) => ({ ...form, ai_price_out: "-1" })[id]).error, /output/);
});

test("formatUsd ทศนิยมตามขนาด", () => {
  assert.equal(formatUsd(0.01234), "$0.0123");
  assert.equal(formatUsd(12.345), "$12.35");
  assert.equal(formatUsd(null), "$0.0000");
});

test("render ไม่แสดงคีย์เต็ม แสดงแค่ hint และค่าใช้จ่าย", () => {
  const html = renderAiSettingsBody(
    { key_set: true, key_hint: "…wxyz", model: "m<1>", price_input_per_mtok: "0.4", price_output_per_mtok: "1.6" },
    { today: { calls: 2, jobs: 1, cost_usd: 0.012, input_tokens: 1000, output_tokens: 200, unpriced_calls: 1 },
      month: { calls: 5, cost_usd: 1.5 }, last_30_days: {} },
    esc, null);
  assert.ok(html.includes("ตั้งแล้ว …wxyz"));
  assert.ok(html.includes("m&lt;1&gt;"));
  assert.ok(html.includes("$0.0120"));
  assert.ok(html.includes("$1.50"));
  assert.ok(html.includes("1 ครั้งไม่ได้คิดเงิน"));
  assert.ok(!/value="sk-/.test(html));
  const empty = renderAiSettingsBody({ key_set: false }, null, esc, null);
  assert.ok(empty.includes("ยังไม่ได้ตั้ง"));
  assert.ok(!empty.includes("ลบคีย์"));
});

test("รายการรุ่น: id ไม่ซ้ำ ผ่าน validation ของหน้า และราคาเป็นบวก", () => {
  const ids = AI_MODEL_PRESETS.map((m) => m.id);
  assert.equal(new Set(ids).size, ids.length);
  for (const m of AI_MODEL_PRESETS) {
    const res = collectAiModelSettings((id) => ({ ai_model: m.id, ai_price_in: String(m.input), ai_price_out: String(m.output) })[id]);
    assert.ok(res.rows, `${m.id} ไม่ผ่าน validation`);
    assert.ok(m.input > 0 && m.output > 0);
  }
  assert.equal(findModelPreset(" gpt-6-luna ").id, "gpt-6-luna");
  assert.equal(findModelPreset("my-model"), null);
});

test("estimateJobCostUsd คิดจาก token ต่อรูป", () => {
  const cost = estimateJobCostUsd({ input: 1, output: 1 }, 1);
  assert.equal(cost, (1600 + 1500) / 1_000_000);
  assert.equal(estimateJobCostUsd(null), null);
});

test("dropdown: ยังไม่ตั้ง = รุ่นแนะนำ, รุ่นในรายการ = เลือกไว้, รุ่นนอกรายการ = กำหนดเอง", () => {
  const sel = (html) => (html.match(/<option value="([^"]+)" selected>/) || [])[1];
  assert.equal(sel(renderAiSettingsBody({ key_set: false }, null, esc, null)), AI_MODEL_PRESETS[0].id);
  assert.equal(sel(renderAiSettingsBody({ model: "gpt-4.1-mini" }, null, esc, null)), "gpt-4.1-mini");
  const custom = renderAiSettingsBody({ model: "my-own-model" }, null, esc, null);
  assert.equal(sel(custom), CUSTOM_MODEL);
  const modelInput = (html) => html.match(/<input id="ai_model"[^>]*>/)[0];
  assert.ok(!/ readonly /.test(modelInput(custom)), "กำหนดเองต้องพิมพ์ได้");
  assert.ok(/ readonly /.test(modelInput(renderAiSettingsBody({ model: "gpt-4.1-mini" }, null, esc, null))), "รุ่นในรายการต้อง readonly");
});
