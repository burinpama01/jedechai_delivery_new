import test from "node:test";
import assert from "node:assert/strict";
import {
  buildTemplateRow,
  collectAiImportConfig,
  formatOptionsText,
  parseKeywords,
  parseOptionsText,
  summarizeRuns,
} from "./aiMenuImportPage.js";

test("parseOptionsText อ่านชื่อ=ราคา และบรรทัดไม่มีราคาเป็น 0", () => {
  assert.deepEqual(parseOptionsText("ไข่ดาว=10\n ไข่เจียว = 15 \n\nไม่ใส่ไข่"), {
    options: [
      { label: "ไข่ดาว", price: 10 },
      { label: "ไข่เจียว", price: 15 },
      { label: "ไม่ใส่ไข่", price: 0 },
    ],
  });
});

test("parseOptionsText ปฏิเสธราคาติดลบ/ทศนิยม/ว่าง", () => {
  assert.match(parseOptionsText("ก=-5").error, /จำนวนเต็ม/);
  assert.match(parseOptionsText("ก=2.5").error, /จำนวนเต็ม/);
  assert.match(parseOptionsText("  \n").error, /อย่างน้อย 1/);
  assert.match(parseOptionsText("=10").error, /ไม่มีชื่อ/);
});

test("formatOptionsText กลับด้านกับ parse", () => {
  const opts = [{ label: "หวานน้อย", price: 0 }, { label: "ไข่มุก", price: 10 }];
  assert.deepEqual(parseOptionsText(formatOptionsText(opts)).options, opts);
});

test("parseKeywords ตัดซ้ำและช่องว่าง", () => {
  assert.deepEqual(parseKeywords("กาแฟ, ชา,,กาแฟ\nนม"), ["กาแฟ", "ชา", "นม"]);
});

test("buildTemplateRow ตรวจ min/max กับจำนวนตัวเลือก", () => {
  const base = {
    store_type: "cafe", name: "ความหวาน", min_selection: "1", max_selection: "1",
    options_text: "หวานน้อย\nหวานปกติ", match_keywords: "กาแฟ", exclude_keywords: "", sort_order: "10",
    is_active: true,
  };
  const ok = buildTemplateRow(base);
  assert.equal(ok.row.options.length, 2);
  assert.deepEqual(ok.row.match_keywords, ["กาแฟ"]);
  assert.match(buildTemplateRow({ ...base, max_selection: "3" }).error, /ไม่เกินจำนวนตัวเลือก/);
  assert.match(buildTemplateRow({ ...base, min_selection: "2" }).error, /ขั้นต่ำ/);
  assert.match(buildTemplateRow({ ...base, store_type: "bar" }).error, /ประเภทร้าน/);
  assert.match(buildTemplateRow({ ...base, name: " " }).error, /ชื่อ/);
});

test("collectAiImportConfig แปลงค่าและตรวจ allowlist", () => {
  const form = {
    aiimp_onboarding: true, aiimp_append: false,
    aiimp_allowlist: "11111111-1111-4111-8111-111111111111, 22222222-2222-4222-8222-222222222222",
    aiimp_quota_onb: "3", aiimp_quota_app: "5", aiimp_max_files: "8",
  };
  const res = collectAiImportConfig((id) => form[id]);
  const kv = Object.fromEntries(res.rows.map((r) => [r.key, r.value]));
  assert.equal(kv.ai_menu_import_onboarding_enabled, "true");
  assert.equal(kv.ai_menu_import_append_enabled, "false");
  assert.equal(kv.ai_menu_import_allowlist.split(",").length, 2);
  assert.match(collectAiImportConfig((id) => ({ ...form, aiimp_allowlist: "abc" })[id]).error, /allowlist/);
  assert.match(collectAiImportConfig((id) => ({ ...form, aiimp_max_files: "9" })[id]).error, /1–8/);
});

test("summarizeRuns รวม token/ค่าใช้จ่าย และนับ error", () => {
  const s = summarizeRuns([
    { input_tokens: 1000, output_tokens: 200, estimated_cost_usd: 0.01, status: "ok" },
    { input_tokens: 500, output_tokens: null, estimated_cost_usd: null, status: "error" },
  ]);
  assert.deepEqual(s, { calls: 2, tokensIn: 1500, tokensOut: 200, cost: 0.01, errors: 1 });
  assert.equal(summarizeRuns([{ status: "ok" }]).cost, null);
});
