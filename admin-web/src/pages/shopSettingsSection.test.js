import test from "node:test";
import assert from "node:assert/strict";
import {
  collectShopSettings,
  renderShopSettingsSection,
  SHOP_CONFIG_KEYS,
} from "./shopSettingsSection.js";

// ค่าที่ถูกต้องทั้งหมด ใช้เป็นฐานแล้ว override ทีละตัวในแต่ละเทสต์
function baseForm(overrides = {}) {
  const form = {
    shopEnabled: true,
    shopAiReceiptEnabled: false,
    shopShowClosedStores: true,
    shopArrivalGeofenceEnabled: true,
    shopFarPickupEnabled: true,
    shopStoreRadiusKm: 10,
    shopStoreRadiusMaxKm: 25,
    shopArrivalRadiusM: 150,
    shopLocationFreshnessSec: 120,
    shopFeePercent: 10,
    shopFeeMin: 25,
    shopFeeMax: 200,
    shopDriverSharePercent: 80,
    shopMinBudget: 100,
    shopMaxBudget: 5000,
    shopNewDriverMaxBudget: 500,
    shopNewDriverJobs: 20,
    shopBudgetBufferPercent: 15,
    shopMaxItems: 30,
    shopDriverToStoreKm: 20,
    shopFarRateMoto: 5,
    shopFarRateCar: 8,
    shopFarMaxFee: "",
    shopMaxPickupKm: "",
    shopCancelFeePercent: 25,
    shopCancelFeeMax: 100,
    shopCancelFeeToDriver: 100,
    shopMatchTimeoutMin: 10,
    shopPhotoConfirmMin: 5,
    shopPhotoEscalateMin: 20,
    shopSubstitutionTimeoutMin: 5,
    shopReceiptToleranceBaht: 5,
    shopReceiptTolerancePercent: 2,
    shopReceiptReviewThreshold: 10,
    shopQuoteTtlSec: 120,
    shopTierMax0: 500, shopTierFee0: 30,
    shopTierMax1: 1500, shopTierFee1: 50,
    shopTierMax2: "", shopTierFee2: 80,
    shopMult_grocery: 1.0,
    shopMult_mall: 1.0,
    shopMult_market: 1.0,
    shopMult_convenience: 1.0,
    shopMult_pharmacy: 1.0,
    ...overrides,
  };
  return (id) => (id in form ? form[id] : null);
}

function rowsToMap(rows) {
  return Object.fromEntries(rows.map((r) => [r.key, r.value]));
}

test("ค่าถูกต้องทั้งหมด -> ได้ rows ครบทุก key", () => {
  const { rows, error } = collectShopSettings(baseForm());
  assert.equal(error, undefined);
  const map = rowsToMap(rows);
  for (const key of SHOP_CONFIG_KEYS) {
    assert.ok(key in map, `ขาด key ${key}`);
  }
});

test("boolean ถูกแปลงเป็น 'true'/'false' ไม่ใช่ on/undefined", () => {
  const map = rowsToMap(collectShopSettings(baseForm({ shopEnabled: false })).rows);
  assert.equal(map.shop_enabled, "false");
  assert.equal(map.shop_show_closed_stores, "true");
});

test("เว้นว่างเพดานค่าวิ่งไกล -> เก็บเป็น 'null' (ยังไม่กำหนด)", () => {
  const map = rowsToMap(collectShopSettings(baseForm()).rows);
  assert.equal(map.shop_far_pickup_max_fee, "null");
  assert.equal(map.shop_max_pickup_distance_km, "null");
});

test("ใส่เพดานค่าวิ่งไกลเป็นตัวเลข -> เก็บเป็นตัวเลข", () => {
  const map = rowsToMap(collectShopSettings(baseForm({ shopFarMaxFee: 100 })).rows);
  assert.equal(map.shop_far_pickup_max_fee, "100");
});

test("ขั้นบันไดถูกเก็บเป็น JSON ขั้นสุดท้าย max = null", () => {
  const map = rowsToMap(collectShopSettings(baseForm()).rows);
  const tiers = JSON.parse(map.shop_fee_tiers);
  assert.equal(tiers.length, 3);
  assert.equal(tiers[0].max, 500);
  assert.equal(tiers[2].max, null);
  assert.equal(tiers[2].fee, 80);
});

test("multiplier ครบทุกหมวด ค่าเริ่มต้น 1.0", () => {
  const map = rowsToMap(collectShopSettings(baseForm()).rows);
  const mult = JSON.parse(map.shop_fee_multiplier_by_category);
  assert.deepEqual(Object.keys(mult).sort(), [
    "convenience", "grocery", "mall", "market", "pharmacy",
  ]);
  assert.equal(mult.grocery, 1.0);
});

// ── validation ที่ถ้าหลุดไปจะทำให้ระบบคิดเงินเพี้ยนเงียบ ๆ ──

test("วงเงินขั้นต่ำมากกว่าสูงสุด -> error", () => {
  const { error } = collectShopSettings(baseForm({ shopMinBudget: 6000 }));
  assert.match(error, /วงเงินขั้นต่ำ/);
});

test("ค่าบริการขั้นต่ำมากกว่าเพดาน -> error", () => {
  const { error } = collectShopSettings(baseForm({ shopFeeMin: 500 }));
  assert.match(error, /ค่าบริการขั้นต่ำ/);
});

test("รัศมีค้นหาเกินเพดานรัศมี -> error", () => {
  const { error } = collectShopSettings(baseForm({ shopStoreRadiusKm: 99 }));
  assert.match(error, /รัศมี/);
});

test("ส่วนแบ่งคนขับเกิน 100% -> error", () => {
  const { error } = collectShopSettings(baseForm({ shopDriverSharePercent: 120 }));
  assert.match(error, /100/);
});

test("ค่าปรับเข้าคนขับเกิน 100% -> error", () => {
  const { error } = collectShopSettings(baseForm({ shopCancelFeeToDriver: 150 }));
  assert.match(error, /100/);
});

test("เวลาเข้าคิวแอดมินน้อยกว่าเวลารอลูกค้ายืนยัน -> error", () => {
  const { error } = collectShopSettings(baseForm({ shopPhotoEscalateMin: 2 }));
  assert.match(error, /คิวแอดมิน/);
});

test("เพดานคนขับใหม่เกินวงเงินสูงสุด -> error", () => {
  const { error } = collectShopSettings(baseForm({ shopNewDriverMaxBudget: 9999 }));
  assert.match(error, /คนขับใหม่/);
});

test("ค่าติดลบ -> error", () => {
  const { error } = collectShopSettings(baseForm({ shopFeePercent: -5 }));
  assert.match(error, /ติดลบ/);
});

test("ค่าที่ไม่ใช่ตัวเลข -> error ไม่ใช่ NaN หลุดเข้า DB", () => {
  const { error, rows } = collectShopSettings(baseForm({ shopFeeMin: "abc" }));
  assert.ok(error, "ควรมี error");
  assert.equal(rows, undefined);
});

test("ช่องว่างในค่าที่จำเป็น -> error", () => {
  const { error } = collectShopSettings(baseForm({ shopMaxItems: "" }));
  assert.match(error, /shop_max_items/);
});

test("ขั้นบันไดสุดท้ายไม่ได้เว้นว่าง -> error", () => {
  const { error } = collectShopSettings(baseForm({ shopTierMax2: 3000 }));
  assert.match(error, /ขั้นสุดท้าย/);
});

test("ขั้นบันไดไม่เรียงจากน้อยไปมาก -> error", () => {
  const { error } = collectShopSettings(baseForm({ shopTierMax1: 100 }));
  assert.match(error, /เรียงจากน้อยไปมาก/);
});

test("multiplier ติดลบ -> error", () => {
  const { error } = collectShopSettings(baseForm({ shopMult_mall: -1 }));
  assert.match(error, /ตัวคูณ/);
});

// ── render ──

test("render ออกมาแล้วมีปุ่มบันทึกและ input ครบ", () => {
  const html = renderShopSettingsSection({}, 3);
  assert.ok(html.includes("saveShopSettings()"));
  assert.ok(html.includes("shopFeePercent"));
  assert.ok(html.includes("shopCancelFeeMax"));
  assert.ok(!/undefined|NaN/.test(html), "ต้องไม่มี undefined/NaN หลุด");
});

test("ยังไม่มีร้าน + ยังไม่เปิดบริการ -> ขึ้นคำเตือน", () => {
  const html = renderShopSettingsSection({}, 0);
  assert.ok(html.includes("ยังไม่มีร้านในระบบ"));
});

test("มีร้านแล้ว -> ไม่ขึ้นคำเตือน", () => {
  const html = renderShopSettingsSection({ shop_enabled: "true" }, 5);
  assert.ok(!html.includes("ยังไม่มีร้านในระบบ"));
});

test("shop_fee_tiers ที่เสียหายใน DB -> ใช้ค่าเริ่มต้น ไม่พัง", () => {
  const html = renderShopSettingsSection({ shop_fee_tiers: "{ไม่ใช่ json" }, 1);
  assert.ok(html.includes("shopTierFee0"));
  assert.ok(!/undefined|NaN/.test(html));
});

test("ค่าจาก DB ถูกเติมลง input", () => {
  const html = renderShopSettingsSection(
    { shop_fee_percent: "12.5", shop_cancel_fee_max: "77" },
    1,
  );
  assert.ok(html.includes('id="shopFeePercent" value="12.5"'));
  assert.ok(html.includes('id="shopCancelFeeMax" value="77"'));
});
