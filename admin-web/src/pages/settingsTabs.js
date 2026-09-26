// แบ่งหน้า Settings เป็นแท็บตามหมวด — เดิมทุก section ต่อกันในหน้าเดียวยาวเกินไป
//
// ทำงานหลัง render: จัดลูกชั้นแรกของ container เข้าแท็บตามหัวข้อ <h3> ของการ์ด
// การ์ดที่ไม่มีหัวข้อ (เช่นแถวปุ่มบันทึก) อยู่แท็บเดียวกับการ์ดก่อนหน้า
// ใช้การซ่อนด้วย class เท่านั้น — input ทุกตัวยังอยู่ใน DOM ปุ่มบันทึกเดิมทำงานเหมือนเดิม
// ส่วนแสดงผลแท็บใช้ helper กลาง pageTabs.js (หน้าอื่นใช้ data-tab แทนการเดาจากหัวข้อ)

import { ALL_TABS, mountPageTabs } from "./pageTabs.js";

export const SETTINGS_TABS = [
  { id: "general", label: "ทั่วไป", icon: "tune",
    headings: ["ตั้งค่าทั่วไป", "ตั้งค่าระยะตรวจจับ", "อีเมลแจ้งเตือนแอดมิน", "แจ้งอัปเดตแอป"] },
  { id: "rates", label: "อัตราค่าบริการ", icon: "payments",
    headings: ["บริการเรียกรถ", "บริการส่งอาหาร", "ค่าปรับเมื่อคนขับไกลจุดรับ", "บริการส่งพัสดุ", "อัตราอื่น ๆ"] },
  { id: "finance", label: "การเงิน & ชวนเพื่อน", icon: "account_balance_wallet",
    headings: ["โหมดเติมเงิน Wallet", "โปรโมชั่นชวนเพื่อน"] },
  { id: "shop", label: "ฝากซื้อ", icon: "shopping_bag", headings: ["บริการฝากซื้อ"] },
  { id: "ai", label: "AI", icon: "auto_awesome", headings: ["AI (OpenAI)"] },
  { id: "integrations", label: "เชื่อมต่อระบบ", icon: "hub", headings: ["StoreOS Connect"] },
  { id: "appearance", label: "หน้าตา & โปรโมชัน", icon: "palette",
    headings: ["ป้ายโปรโมชั่น", "Landing Page", "จัดการ Banner", "โลโก้ & Splash"] },
];

export const DEFAULT_TAB = "general";
const STORAGE_KEY = "adminSettingsTab";
const ALL = ALL_TABS;

export function tabForHeading(text) {
  const t = String(text || "").trim();
  if (!t) return null;
  const hit = SETTINGS_TABS.find((tab) => tab.headings.some((h) => t.startsWith(h)));
  return hit ? hit.id : null;
}

/**
 * items: [{ heading: string|null, pinned: boolean }] ตามลำดับใน DOM
 * คืน tab id ต่อ item — ไม่มีหัวข้อ = ตามการ์ดก่อนหน้า, pinned = แสดงทุกแท็บ,
 * หัวข้อที่ไม่รู้จัก = "ทั่วไป" (section ใหม่ในอนาคตจะไม่หายไปไหน)
 */
export function assignTabs(items) {
  let prev = DEFAULT_TAB;
  return items.map((item) => {
    if (item.pinned) return ALL;
    if (!item.heading) return prev;
    prev = tabForHeading(item.heading) || DEFAULT_TAB;
    return prev;
  });
}

// หัวข้อการ์ด (h3 ชั้นบน ๆ ของการ์ด) — กัน h3 ที่ซ้อนลึกในเนื้อหาแย่งเป็นหัวข้อ
function cardHeading(c) {
  return (c.matches?.("h3") ? c : c.querySelector(":scope > h3, :scope > * > h3, :scope > * > * > h3"))?.textContent || null;
}

/** เรียกหลัง el.innerHTML ของหน้า Settings — container = div.fade-in ชั้นนอก */
export function applySettingsTabs(container) {
  return mountPageTabs(container, {
    key: STORAGE_KEY,
    tabs: SETTINGS_TABS,
    defaultTab: DEFAULT_TAB,
    assign: (children) => assignTabs(children.map((c) => ({
      heading: cardHeading(c),
      pinned: c.hasAttribute("data-settings-pinned"),
    }))),
  });
}
