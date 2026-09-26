import test from "node:test";
import assert from "node:assert/strict";
import {
  collectAiModelSettings,
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
