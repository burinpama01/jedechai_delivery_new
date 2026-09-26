// แบ่งหน้า Settings เป็นแท็บตามหมวด — เดิมทุก section ต่อกันในหน้าเดียวยาวเกินไป
//
// ทำงานหลัง render: จัดลูกชั้นแรกของ container เข้าแท็บตามหัวข้อ <h3> ของการ์ด
// การ์ดที่ไม่มีหัวข้อ (เช่นแถวปุ่มบันทึก) อยู่แท็บเดียวกับการ์ดก่อนหน้า
// ใช้การซ่อนด้วย class เท่านั้น — input ทุกตัวยังอยู่ใน DOM ปุ่มบันทึกเดิมทำงานเหมือนเดิม

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
const ALL = "*";

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

function readSaved() {
  try {
    const v = globalThis.localStorage?.getItem(STORAGE_KEY);
    return SETTINGS_TABS.some((t) => t.id === v) ? v : null;
  } catch {
    return null;
  }
}

function save(id) {
  try {
    globalThis.localStorage?.setItem(STORAGE_KEY, id);
  } catch { /* private mode — ไม่จำแท็บก็ได้ */ }
}

export function selectSettingsTab(container, id) {
  const tabId = SETTINGS_TABS.some((t) => t.id === id) ? id : DEFAULT_TAB;
  for (const child of container.children) {
    const own = child.dataset?.settingsTab;
    // ไม่มี data-settings-tab = ไม่อยู่ในระบบแท็บ (เช่นแถบ nav เอง) → แสดงเสมอ
    // element ที่ append เข้า container ภายหลังต้องตั้ง attribute นี้เอง
    if (!own) continue;
    child.classList.toggle("hidden", own !== ALL && own !== tabId);
  }
  const nav = container.querySelector("[data-settings-tabs]");
  for (const btn of nav?.querySelectorAll("[data-tab]") || []) {
    const active = btn.dataset.tab === tabId;
    btn.classList.toggle("bg-indigo-600", active);
    btn.classList.toggle("text-white", active);
    btn.classList.toggle("shadow-md", active);
    btn.classList.toggle("text-gray-600", !active);
    btn.classList.toggle("hover:bg-gray-100", !active);
    btn.setAttribute("aria-selected", active ? "true" : "false");
    // จอเล็กแถบปัดได้ — เลื่อนแถบ (ไม่ใช่หน้า) ให้แท็บที่เลือกอยู่ในจอ
  }
  revealActiveTab(nav);
  save(tabId);
  return tabId;
}

/** จอเล็กแถบปัดได้ — เลื่อนแถบ (ไม่ใช่หน้า) ให้แท็บที่เลือกอยู่ในจอ */
export function revealActiveTab(nav) {
  const btn = nav?.querySelector('[aria-selected="true"]');
  if (!btn || nav.scrollWidth <= nav.clientWidth) return;
  const delta = btn.getBoundingClientRect().left - nav.getBoundingClientRect().left - 8;
  nav.scrollLeft = Math.max(0, nav.scrollLeft + delta);
}

/** เรียกหลัง el.innerHTML ของหน้า Settings — container = div.fade-in ชั้นนอก */
export function applySettingsTabs(container) {
  if (!container) return null;
  const children = [...container.children];
  const ids = assignTabs(children.map((c) => ({
    // หัวข้อการ์ด (h3 ชั้นบน ๆ ของการ์ด) — กัน h3 ที่ซ้อนลึกในเนื้อหาแย่งเป็นหัวข้อ
    heading: (c.matches?.("h3") ? c : c.querySelector(":scope > h3, :scope > * > h3, :scope > * > * > h3"))?.textContent || null,
    pinned: c.hasAttribute("data-settings-pinned"),
  })));
  children.forEach((c, i) => { c.dataset.settingsTab = ids[i]; });

  const used = new Set(ids);
  const tabs = SETTINGS_TABS.filter((t) => used.has(t.id));
  const nav = container.ownerDocument.createElement("div");
  nav.setAttribute("data-settings-tabs", "");
  nav.setAttribute("role", "tablist");
  // จอเล็ก: แถวเดียวปัดซ้าย-ขวา (sticky ไม่กินจอ) · จอกว้าง: ตัดบรรทัด
  nav.className = "glass-card p-2 flex gap-1 overflow-x-auto md:flex-wrap sticky top-0 z-10 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden";
  nav.innerHTML = tabs.map((t) => `
    <button type="button" role="tab" data-tab="${t.id}"
      class="flex shrink-0 items-center gap-1.5 px-3.5 py-2 rounded-xl text-sm font-semibold whitespace-nowrap transition-all text-gray-600 hover:bg-gray-100">
      <span class="material-icons-round text-[18px]">${t.icon}</span>${t.label}
    </button>`).join("");
  nav.addEventListener("click", (e) => {
    const btn = e.target.closest?.("[data-tab]");
    if (btn) selectSettingsTab(container, btn.dataset.tab);
  });
  container.prepend(nav);

  const initial = readSaved();
  const selected = selectSettingsTab(container, tabs.some((t) => t.id === initial) ? initial : DEFAULT_TAB);
  // Tailwind CDN สร้าง class แบบ async + ฟอนต์ไอคอนยังโหลดไม่เสร็จ → ขนาดแถบยังไม่นิ่งตอนนี้
  setTimeout(() => revealActiveTab(nav), 300);
  globalThis.document?.fonts?.ready?.then(() => revealActiveTab(nav)).catch(() => {});
  return selected;
}
