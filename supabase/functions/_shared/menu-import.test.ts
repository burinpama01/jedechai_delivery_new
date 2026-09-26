import { assert, assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import {
  applyConfidenceRules,
  buildDraftItems,
  detectImageMime,
  DraftItem,
  ISSUE,
  matchCategories,
  matchExistingMenu,
  mergeAcrossImages,
  normName,
  numbersInText,
  OptionTemplate,
  pickStoreType,
  sanitizeAiOutput,
  similarity,
  suggestTemplates,
} from "./menu-import.ts";

function aiItem(overrides: Record<string, unknown> = {}) {
  return {
    category: "กาแฟ",
    name: "ลาเต้",
    description: null,
    base_price: 55,
    price_text_raw: "55",
    variant_group: null,
    variants: [],
    addons: [],
    confidence: { name: 0.99, price: 0.98, category: 0.9 },
    ...overrides,
  };
}

function draft(overrides: Record<string, unknown> = {}): DraftItem {
  const out = sanitizeAiOutput({ items: [aiItem(overrides)] }, 0).items[0];
  return out;
}

Deno.test("normName ตัดช่องว่าง/เครื่องหมาย/คำว่าเมนู", () => {
  assertEquals(normName(" เมนู ชา  เขียว! "), "ชาเขียว");
  assertEquals(normName("Latte"), normName("latte "));
});

Deno.test("numbersInText อ่านตัวเลขทั้งหมด", () => {
  assertEquals(numbersInText("เย็น 55 / ปั่น 65"), [55, 65]);
  assertEquals(numbersInText("1,200.-"), [1200]);
  assertEquals(numbersInText(null), []);
});

Deno.test("sanitize ทิ้งรายการไม่มีชื่อ และ clamp confidence", () => {
  const out = sanitizeAiOutput({
    items: [aiItem({ name: "  " }), aiItem({ confidence: { name: 3, price: -1, category: "x" } })],
    unreadable_regions: ["มุมล่าง", 5],
    store_type_guess: { value: "cafe", confidence: 0.9 },
  }, 2);
  assertEquals(out.items.length, 1);
  assertEquals(out.items[0].source_index, 2);
  assertEquals(out.items[0].confidence, { name: 1, price: 0, category: 0 });
  assertEquals(out.unreadable_regions, ["มุมล่าง"]);
  assertEquals(out.store_type_guess?.value, "cafe");
});

Deno.test("sanitize ปฏิเสธ store type นอก enum", () => {
  const out = sanitizeAiOutput({ items: [], store_type_guess: { value: "bar", confidence: 1 } }, 0);
  assertEquals(out.store_type_guess, null);
});

Deno.test("confidence: ราคาชัดเจน → ไม่มี issue", () => {
  const out = applyConfidenceRules(draft());
  assertEquals(out.issues, []);
  assertEquals(out.price, 55);
});

Deno.test("confidence: ราคาไม่ตรง price_text_raw → ต้องตรวจ", () => {
  const out = applyConfidenceRules(draft({ base_price: 65, price_text_raw: "55" }));
  assert(out.issues.includes(ISSUE.priceTextMismatch));
  assert(out.issues.includes(ISSUE.lowPriceConf));
  assert(out.confidence.price <= 0.6);
});

Deno.test("confidence: ราคาผิดช่วง / ไม่มีราคา", () => {
  assert(applyConfidenceRules(draft({ base_price: 3, price_text_raw: "3" })).issues
    .includes(ISSUE.priceOutOfRange));
  assert(applyConfidenceRules(draft({ base_price: 2500, price_text_raw: "2500" })).issues
    .includes(ISSUE.priceOutOfRange));
  const missing = applyConfidenceRules(draft({ base_price: null, price_text_raw: null }));
  assert(missing.issues.includes(ISSUE.missingPrice));
  assertEquals(missing.price, null);
});

Deno.test("confidence: 0.80–0.94 = แนะนำตรวจ, ชื่อไม่ชัด = ต้องตรวจ", () => {
  const out = applyConfidenceRules(draft({ confidence: { name: 0.5, price: 0.9, category: 1 } }));
  assert(out.issues.includes(ISSUE.checkPrice));
  assert(out.issues.includes(ISSUE.lowNameConf));
});

Deno.test("variants: base price = ราคาต่ำสุด", () => {
  const out = applyConfidenceRules(draft({
    base_price: 55,
    price_text_raw: "เย็น 55 / ปั่น 65",
    variant_group: "แบบ",
    variants: [{ label: "ปั่น", price: 65 }, { label: "เย็น", price: 55 }],
  }));
  assertEquals(out.price, 55);
  assertEquals(out.issues, []);
});

Deno.test("variants: base ไม่ใช่ราคาต่ำสุด → ติด issue และแก้เป็นต่ำสุด", () => {
  const out = applyConfidenceRules(draft({
    base_price: 65,
    price_text_raw: "เย็น 55 / ปั่น 65",
    variants: [{ label: "เย็น", price: 55 }, { label: "ปั่น", price: 65 }],
  }));
  assertEquals(out.price, 55);
  assert(out.issues.includes(ISSUE.variantBaseMismatch));
});

Deno.test("merge: ชื่อซ้ำราคาเท่ากันจากหลายรูป → รวมเป็นรายการเดียว", () => {
  const a = applyConfidenceRules(draft());
  const b = applyConfidenceRules({ ...draft(), source_index: 1 });
  assertEquals(mergeAcrossImages([a, b]).length, 1);
});

Deno.test("merge: ชื่อซ้ำราคาต่างกัน → price_conflict ห้ามเลือกเอง", () => {
  const a = applyConfidenceRules(draft());
  const b = applyConfidenceRules(draft({ base_price: 60, price_text_raw: "60" }));
  const out = mergeAcrossImages([a, b]);
  assertEquals(out.length, 1);
  assert(out[0].issues.includes(ISSUE.priceConflict));
  assertEquals(out[0].conflict?.prices, [55, 60]);
});

Deno.test("matchExisting: exact / price_changed / similar / new", () => {
  const existing = [
    { id: "m1", name: "ลาเต้", price: 55 },
    { id: "m2", name: "มอคค่า", price: 60 },
    { id: "m3", name: "ชาเขียวนมสด", price: 50 },
  ];
  const items = [
    draft({ name: "ลาเต้", base_price: 55 }),
    draft({ name: "มอคค่า", base_price: 65, price_text_raw: "65" }),
    draft({ name: "ชาเขียวนมสดๆ", base_price: 50, price_text_raw: "50" }),
    draft({ name: "อเมริกาโน่", base_price: 45, price_text_raw: "45" }),
  ].map(applyConfidenceRules);
  const out = matchExistingMenu(items, existing);
  assertEquals(out.map((i) => i.match_type), ["exact_dup", "price_changed", "similar", "new"]);
  assertEquals(out.map((i) => i.action), ["skip", "skip", "create", "create"]);
  assertEquals(out[1].matched_price, 60);
  assert(out[2].issues.includes(ISSUE.similarExisting));
});

Deno.test("similarity: ชื่อต่างกันมาก < threshold", () => {
  assert(similarity("กะเพราหมู", "ผัดไทย") < 0.5);
  assertEquals(similarity("ชาไทย", "ชา ไทย"), 1);
});

Deno.test("matchCategories: ตรงชื่อ / synonym / หมวดใหม่", () => {
  const cats = [{ id: "c1", name: "กาแฟ" }, { id: "c2", name: "ของหวาน" }];
  const out = matchCategories([
    draft({ category: "กาแฟ " }),
    draft({ category: "Dessert" }),
    draft({ category: "ชาผลไม้" }),
    draft({ category: null }),
  ], cats);
  assertEquals(out[0].matched_category_id, "c1");
  assertEquals(out[1].matched_category_id, "c2");
  assertEquals(out[1].category, "ของหวาน");
  assertEquals(out[2].is_new_category, true);
  assertEquals(out[3].category, "อื่นๆ");
});

const templates: OptionTemplate[] = [
  {
    id: "t1", store_type: "cafe", name: "ระดับความหวาน", min_selection: 1, max_selection: 1,
    options: [{ label: "หวานน้อย", price: 0 }], match_keywords: ["กาแฟ", "ชา", "ลาเต้"],
    exclude_keywords: ["อเมริกาโน่"], sort_order: 10, version: 1,
  },
  {
    id: "t2", store_type: "noodle", name: "เส้น", min_selection: 1, max_selection: 1,
    options: [{ label: "เส้นเล็ก", price: 0 }], match_keywords: ["ก๋วยเตี๋ยว"],
    exclude_keywords: ["เกาเหลา"], sort_order: 10, version: 1,
  },
  {
    id: "t3", store_type: "other", name: "ระดับเผ็ด", min_selection: 1, max_selection: 1,
    options: [{ label: "เผ็ดน้อย", price: 0 }], match_keywords: [], exclude_keywords: [],
    sort_order: 10, version: 1,
  },
];

Deno.test("suggestTemplates: keyword + คำยกเว้น + ข้ามเมนูที่มีกลุ่มเดียวกันจากรูป", () => {
  const items = [
    { id: "a", name: "ลาเต้", category: "กาแฟ", variant_group: null, addon_groups: [] },
    { id: "b", name: "อเมริกาโน่", category: "กาแฟ", variant_group: null, addon_groups: [] },
    { id: "c", name: "ชาไทย", category: "ชา", variant_group: "ความหวาน", addon_groups: [] },
    { id: "d", name: "ครัวซองต์", category: "เบเกอรี่", variant_group: null, addon_groups: [] },
  ];
  const [s] = suggestTemplates(templates, items, "cafe");
  assertEquals(s.item_ids, ["a"]);
  assertEquals(s.skipped_item_ids, ["c"]);
});

Deno.test("suggestTemplates: เกาเหลาไม่ได้แม่แบบเส้น", () => {
  const items = [
    { id: "a", name: "ก๋วยเตี๋ยวหมู", category: null, variant_group: null, addon_groups: [] },
    { id: "b", name: "เกาเหลาก๋วยเตี๋ยวหมู", category: null, variant_group: null, addon_groups: [] },
  ];
  const [s] = suggestTemplates(templates, items, "noodle");
  assertEquals(s.item_ids, ["a"]);
});

Deno.test("suggestTemplates: other ไม่จับคู่อัตโนมัติ", () => {
  const items = [{ id: "a", name: "ข้าวมันไก่", category: null, variant_group: null, addon_groups: [] }];
  const [s] = suggestTemplates(templates, items, "other");
  assertEquals(s.item_ids, []);
});

Deno.test("buildDraftItems + pickStoreType ครบ pipeline", () => {
  const o1 = sanitizeAiOutput({
    items: [aiItem(), aiItem({ name: "เอสเพรสโซ่", base_price: 50, price_text_raw: "50" })],
    store_type_guess: { value: "cafe", confidence: 0.9 },
  }, 0);
  const o2 = sanitizeAiOutput({
    items: [aiItem()],
    store_type_guess: { value: "dessert", confidence: 0.4 },
  }, 1);
  const out = buildDraftItems([o1, o2], [{ id: "m", name: "เอสเพรสโซ่", price: 50 }], []);
  assertEquals(out.length, 2);
  assertEquals(out[1].match_type, "exact_dup");
  assertEquals(pickStoreType([o1, o2])?.value, "cafe");
});

Deno.test("detectImageMime ตรวจ magic bytes", () => {
  assertEquals(detectImageMime(new Uint8Array([0xff, 0xd8, 0xff, 0xe0])), "image/jpeg");
  assertEquals(
    detectImageMime(new Uint8Array([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a])),
    "image/png",
  );
  assertEquals(
    detectImageMime(new Uint8Array([0x52, 0x49, 0x46, 0x46, 0, 0, 0, 0, 0x57, 0x45, 0x42, 0x50])),
    "image/webp",
  );
  assertEquals(detectImageMime(new TextEncoder().encode("<svg>")), null);
});
