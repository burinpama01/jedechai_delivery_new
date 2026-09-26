// แท็บของหน้า admin-web (ใช้ร่วมทุกหน้า — แผน Plan/Admin_Web_Page_Tabs_Plan_v1.html)
//
// ใช้หลัง render: การ์ดชั้นแรกของ container ติด data-tab="<id>" ในโค้ดหน้า
//   - ไม่ติด = อยู่แท็บเดียวกับการ์ดก่อนหน้า (แถวปุ่ม/ช่องว่างตามการ์ดของมัน)
//   - data-tab="*" = แสดงทุกแท็บ (เช่นแถบเลือกช่วงวันที่)
// ซ่อนด้วย class "hidden" เท่านั้น — input/ปุ่ม/ฟังก์ชันเดิมยังอยู่ใน DOM ทำงานเหมือนเดิม
// element ที่ append เข้า container ภายหลังโดยไม่มี data-page-tab จะแสดงทุกแท็บ

export const ALL_TABS = "*";

/**
 * items: [{ tab: string|null }] ตามลำดับใน DOM → tab id ต่อ item
 * ไม่ระบุ = ตามก่อนหน้า (ตัวแรกไม่ระบุ = defaultTab) · id ที่ไม่รู้จัก = defaultTab
 */
export function resolveTabs(items, knownIds, defaultTab) {
  let prev = defaultTab;
  return items.map((item) => {
    const t = item.tab;
    if (t === ALL_TABS) return ALL_TABS;
    if (!t) return prev;
    prev = knownIds.includes(t) ? t : defaultTab;
    return prev;
  });
}

function readSaved(key, ids) {
  try {
    const v = globalThis.localStorage?.getItem(key);
    return ids.includes(v) ? v : null;
  } catch {
    return null;
  }
}

function save(key, id) {
  try {
    globalThis.localStorage?.setItem(key, id);
  } catch { /* private mode — ไม่จำแท็บก็ได้ */ }
}

/** จอเล็กแถบปัดได้ — เลื่อนแถบ (ไม่ใช่หน้า) ให้แท็บที่เลือกอยู่ในจอ */
export function revealActiveTab(nav) {
  const btn = nav?.querySelector('[aria-selected="true"]');
  if (!btn || nav.scrollWidth <= nav.clientWidth) return;
  const delta = btn.getBoundingClientRect().left - nav.getBoundingClientRect().left - 8;
  nav.scrollLeft = Math.max(0, nav.scrollLeft + delta);
}

export function selectPageTab(container, id) {
  const state = container?.__pageTabs;
  if (!state) return null;
  const tabId = state.ids.includes(id) ? id : state.defaultTab;
  for (const child of container.children) {
    const own = child.dataset?.pageTab;
    if (!own) continue;
    child.classList.toggle("hidden", own !== ALL_TABS && own !== tabId);
  }
  for (const btn of state.nav.querySelectorAll("[data-tab-btn]")) {
    const active = btn.dataset.tabBtn === tabId;
    btn.classList.toggle("bg-indigo-600", active);
    btn.classList.toggle("text-white", active);
    btn.classList.toggle("shadow-md", active);
    btn.classList.toggle("text-gray-600", !active);
    btn.classList.toggle("hover:bg-gray-100", !active);
    btn.setAttribute("aria-selected", active ? "true" : "false");
  }
  revealActiveTab(state.nav);
  save(state.key, tabId);
  state.onChange?.(tabId);
  return tabId;
}

function badgeHtml(n) {
  const v = Number(n);
  if (!Number.isFinite(v) || v <= 0) return "";
  return `<span class="ml-1 min-w-[20px] px-1.5 py-0.5 rounded-full text-[11px] leading-none bg-red-500 text-white">${v > 99 ? "99+" : v}</span>`;
}

/**
 * ติดแท็บให้ container
 * @param {HTMLElement} container ตัวครอบการ์ดชั้นแรก
 * @param {{key:string, tabs:{id:string,label:string,icon?:string,badge?:number}[],
 *          defaultTab?:string, navClass?:string, assign?:(children:Element[])=>string[], onChange?:(id:string)=>void}} opts
 *   navClass: class เพิ่มให้แถบแท็บ (เช่น "mb-5" เมื่อ container ไม่มี space-y)
 *   assign: กำหนด tab ต่อ child เอง (ค่าเริ่มต้นอ่านจาก data-tab)
 */
export function mountPageTabs(container, opts) {
  if (!container || !opts?.tabs?.length) return null;
  const ids = opts.tabs.map((t) => t.id);
  const defaultTab = opts.defaultTab && ids.includes(opts.defaultTab) ? opts.defaultTab : ids[0];
  const children = [...container.children].filter((c) => !c.hasAttribute("data-page-tabs-nav"));
  const assigned = typeof opts.assign === "function"
    ? opts.assign(children)
    : resolveTabs(children.map((c) => ({ tab: c.getAttribute("data-tab") })), ids, defaultTab);
  children.forEach((c, i) => { c.dataset.pageTab = assigned[i]; });

  // แท็บที่ไม่มีเนื้อหาเลยไม่ต้องแสดงปุ่ม
  const used = new Set(assigned);
  const tabs = opts.tabs.filter((t) => used.has(t.id));
  container.querySelector(":scope > [data-page-tabs-nav]")?.remove();
  const nav = container.ownerDocument.createElement("div");
  nav.setAttribute("data-page-tabs-nav", "");
  nav.setAttribute("role", "tablist");
  // จอเล็ก: แถวเดียวปัดซ้าย-ขวา (sticky ไม่กินจอ) · จอกว้าง: ตัดบรรทัด
  nav.className = "glass-card p-2 flex gap-1 overflow-x-auto md:flex-wrap sticky top-0 z-10 [scrollbar-width:none] [&::-webkit-scrollbar]:hidden"
    + (opts.navClass ? ` ${opts.navClass}` : "");
  nav.innerHTML = tabs.map((t) => `
    <button type="button" role="tab" data-tab-btn="${t.id}"
      class="flex shrink-0 items-center gap-1.5 px-3.5 py-2 rounded-xl text-sm font-semibold whitespace-nowrap transition-all text-gray-600 hover:bg-gray-100">
      ${t.icon ? `<span class="material-icons-round text-[18px]">${t.icon}</span>` : ""}${t.label}${badgeHtml(t.badge)}
    </button>`).join("");
  nav.addEventListener("click", (e) => {
    const btn = e.target.closest?.("[data-tab-btn]");
    if (btn) selectPageTab(container, btn.dataset.tabBtn);
  });
  container.prepend(nav);

  const visibleIds = tabs.map((t) => t.id);
  container.__pageTabs = { key: opts.key, ids: visibleIds, defaultTab: visibleIds.includes(defaultTab) ? defaultTab : visibleIds[0], nav, onChange: opts.onChange };
  const saved = readSaved(opts.key, visibleIds);
  const selected = selectPageTab(container, saved || container.__pageTabs.defaultTab);
  // Tailwind CDN สร้าง class แบบ async + ฟอนต์ไอคอนยังโหลดไม่เสร็จ → ขนาดแถบยังไม่นิ่งตอนนี้
  setTimeout(() => revealActiveTab(nav), 300);
  globalThis.document?.fonts?.ready?.then(() => revealActiveTab(nav)).catch(() => {});
  return selected;
}
