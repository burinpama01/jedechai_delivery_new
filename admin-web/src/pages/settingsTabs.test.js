import test from "node:test";
import assert from "node:assert/strict";
import { assignTabs, SETTINGS_TABS, tabForHeading } from "./settingsTabs.js";

// หัวข้อจริงในหน้า Settings ตามลำดับ DOM (null = การ์ด/แถวที่ไม่มี h3)
const PAGE = [
  "ตั้งค่าทั่วไป",
  "ตั้งค่าระยะตรวจจับแต่ละประเภท (กม.)",
  "โหมดเติมเงิน Wallet",
  "โปรโมชั่นชวนเพื่อน & การถอนเงิน",
  "อีเมลแจ้งเตือนแอดมิน",
  "StoreOS Connect",
  "บริการเรียกรถ",
  "บริการส่งอาหาร",
  "ค่าปรับเมื่อคนขับไกลจุดรับ",
  "ค่าปรับเมื่อคนขับไกลจุดรับ",
  null, // ปุ่มบันทึกอัตรา (ride/food)
  "บริการส่งพัสดุ",
  "อัตราอื่น ๆ",
  null, // ปุ่มบันทึกอัตรา
  "บริการฝากซื้อ/ฝากหิ้ว",
  "AI (OpenAI)",
  "ป้ายโปรโมชั่น",
  "Landing Page (เว็บสาธารณะ)",
  "แจ้งอัปเดตแอป",
  "จัดการ Banner โปรโมชั่น",
  "โลโก้ & Splash Screen",
];

test("ทุกหัวข้อจริงในหน้า Settings ถูกจัดเข้าแท็บ (ไม่มีตกหล่นไปค่า default โดยบังเอิญ)", () => {
  for (const h of PAGE.filter(Boolean)) {
    assert.ok(tabForHeading(h), `ไม่มีแท็บสำหรับ "${h}"`);
  }
});

test("assignTabs: แถวปุ่มบันทึกตามการ์ดก่อนหน้า, pinned แสดงทุกแท็บ", () => {
  const items = [...PAGE.map((heading) => ({ heading, pinned: false })), { heading: null, pinned: true }];
  const ids = assignTabs(items);
  assert.equal(ids[10], "rates"); // ปุ่มบันทึกหลังค่าปรับ
  assert.equal(ids[13], "rates"); // ปุ่มบันทึกหลังอัตราอื่น ๆ
  assert.equal(ids[14], "shop");
  assert.equal(ids[15], "ai");
  assert.equal(ids[5], "integrations");
  assert.equal(ids[18], "general"); // แจ้งอัปเดตแอป
  assert.equal(ids.at(-1), "*");
  // ทุกแท็บที่ประกาศไว้มีเนื้อหาอย่างน้อย 1 การ์ด
  for (const t of SETTINGS_TABS) assert.ok(ids.includes(t.id), `แท็บ ${t.id} ว่าง`);
});

test("หัวข้อใหม่ที่ไม่รู้จักไปอยู่แท็บทั่วไป ไม่หายจากหน้า", () => {
  assert.deepEqual(assignTabs([{ heading: "section ใหม่", pinned: false }, { heading: null, pinned: false }]), ["general", "general"]);
  assert.equal(tabForHeading(""), null);
});
