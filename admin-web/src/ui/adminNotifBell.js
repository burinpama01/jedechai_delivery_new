// กระดิ่งแจ้งเตือนแอดมินบน topbar — อ่าน notifications ของ admin user เอง
// (triggers ฝั่ง DB จาก migration 20260718230000 เป็นคน insert เหตุการณ์:
//  ถอนเงิน/เติมเงิน/ร้องเรียน/ผู้สมัครใหม่/คำขอซักผ้า/งานค้าง)
// realtime ผ่าน supabase channel + fallback poll ทุก 60 วิ

let _channel = null;
let _pollTimer = null;
let _unread = 0;
let _items = [];
let _deps = null;

const PAGE_BY_TYPE = {
  "admin.withdrawal_new": "withdrawals",
  "admin.topup_new": "topups",
  "admin.ticket_new": "complaints",
  "admin.laundry_quote_new": "laundry",
  "admin.stale_laundry": "laundry",
  "admin.stale_order": "pending_orders",
  "admin.broadcast": "broadcast",
  "admin.daily_signup_summary": "users",
  ai_menu_import: "ai_menu_import",
};

function pageForNotification(item) {
  if (item?.type === "admin.applicant_pending") {
    return item?.data?.role === "driver" ? "drivers" : "merchants";
  }
  // event ใหม่ระบุหน้าเองได้ผ่าน data.admin_page (เช่นสรุปรายวันที่มีคนรออนุมัติ)
  const page = item?.data?.admin_page;
  if (typeof page === "string" && /^[a-z_]{2,40}$/.test(page)
    && globalThis.document?.querySelector?.(`.sidebar-link[data-page="${page}"]`)) {
    return page;
  }
  if (PAGE_BY_TYPE[item?.type]) return PAGE_BY_TYPE[item.type];
  if (String(item?.type || "").startsWith("laundry.")) return "laundry";
  return "dashboard";
}

function esc(value) {
  const escapeHtml = _deps?.escapeHtml || globalThis.escapeHtml;
  if (typeof escapeHtml === "function") return escapeHtml(value);
  return String(value ?? "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  }[c]));
}

function timeLabel(iso) {
  if (!iso) return "";
  const mins = Math.floor((Date.now() - new Date(iso).getTime()) / 60000);
  if (mins < 1) return "เมื่อครู่";
  if (mins < 60) return `${mins} นาทีที่แล้ว`;
  if (mins < 1440) return `${Math.floor(mins / 60)} ชม.ที่แล้ว`;
  return new Date(iso).toLocaleDateString("th-TH", { day: "numeric", month: "short" });
}

function renderBadge() {
  const badge = document.getElementById("adminNotifBadge");
  if (!badge) return;
  if (_unread > 0) {
    badge.textContent = _unread > 99 ? "99+" : String(_unread);
    badge.classList.remove("hidden");
  } else {
    badge.classList.add("hidden");
  }
}

function renderList() {
  const list = document.getElementById("adminNotifList");
  if (!list) return;
  if (!_items.length) {
    list.innerHTML = '<div class="py-10 text-center text-gray-400 text-sm">ยังไม่มีการแจ้งเตือน</div>';
    return;
  }
  list.innerHTML = _items.map((item) => `
    <button type="button"
      class="adminNotifItem w-full text-left px-4 py-3 hover:bg-indigo-50/60 transition-colors ${item.is_read ? "opacity-60" : "bg-indigo-50/30"}"
      data-notif-id="${esc(item.id)}">
      <div class="flex items-start gap-2">
        ${item.is_read ? "" : '<span class="mt-1.5 w-2 h-2 rounded-full bg-indigo-500 shrink-0"></span>'}
        <div class="min-w-0">
          <p class="text-[13px] font-semibold text-gray-800 truncate">${esc(item.title)}</p>
          <p class="text-xs text-gray-500 line-clamp-2">${esc(item.body || "")}</p>
          <p class="text-[10px] text-gray-400 mt-0.5">${esc(timeLabel(item.created_at))}</p>
        </div>
      </div>
    </button>
  `).join("");

  for (const btn of list.querySelectorAll(".adminNotifItem")) {
    btn.addEventListener("click", () => openNotification(btn.dataset.notifId));
  }
}

async function loadNotifications() {
  const { supabase, userId } = _deps;
  const { data, error } = await supabase
    .from("notifications")
    .select("id, title, body, type, data, is_read, created_at")
    .eq("user_id", userId)
    .order("created_at", { ascending: false })
    .limit(20);
  if (error) return;
  _items = data || [];
  const { count } = await supabase
    .from("notifications")
    .select("id", { count: "exact", head: true })
    .eq("user_id", userId)
    .eq("is_read", false);
  _unread = count || 0;
  renderBadge();
  renderList();
}

async function openNotification(notifId) {
  const { supabase } = _deps;
  const item = _items.find((n) => n.id === notifId);
  if (!item) return;
  if (!item.is_read) {
    item.is_read = true;
    _unread = Math.max(0, _unread - 1);
    renderBadge();
    renderList();
    await supabase.from("notifications").update({ is_read: true }).eq("id", notifId);
  }
  togglePanel(false);
  const nav = globalThis.navigateTo;
  if (typeof nav === "function") nav(pageForNotification(item));
}

async function markAllRead() {
  const { supabase, userId } = _deps;
  _items.forEach((n) => { n.is_read = true; });
  _unread = 0;
  renderBadge();
  renderList();
  await supabase
    .from("notifications")
    .update({ is_read: true })
    .eq("user_id", userId)
    .eq("is_read", false);
}

function togglePanel(force) {
  const panel = document.getElementById("adminNotifPanel");
  if (!panel) return;
  const show = typeof force === "boolean" ? force : panel.classList.contains("hidden");
  panel.classList.toggle("hidden", !show);
  if (show) loadNotifications();
}

function wireRealtime() {
  const { supabase, userId, showToast } = _deps;
  try {
    if (_channel) supabase.removeChannel(_channel);
    _channel = supabase
      .channel("admin-notif-bell")
      .on("postgres_changes", {
        event: "INSERT",
        schema: "public",
        table: "notifications",
        filter: `user_id=eq.${userId}`,
      }, (payload) => {
        const row = payload?.new;
        if (!row) return;
        _items = [row, ..._items].slice(0, 20);
        _unread += 1;
        renderBadge();
        renderList();
        if (typeof showToast === "function") {
          showToast(`🔔 ${row.title}`, "success");
        }
      })
      .subscribe();
  } catch (_) {
    // realtime ไม่พร้อมก็ยังมี poll fallback
  }
}

export function initAdminNotifBell(ctx) {
  const supabase = ctx?.supabase || globalThis.supabase;
  const userId = ctx?.currentUser?.id || ctx?.userId || globalThis.currentUser?.id;
  if (!supabase || !userId) return false;
  _deps = {
    supabase,
    userId,
    escapeHtml: ctx?.escapeHtml || globalThis.escapeHtml,
    showToast: ctx?.showToast || globalThis.showToast,
  };

  const root = document.getElementById("adminNotifBellRoot");
  if (!root) return false;
  root.innerHTML = `
    <div class="relative">
      <button id="adminNotifBellBtn" title="การแจ้งเตือน"
        class="relative flex items-center justify-center w-10 h-10 bg-white rounded-xl border border-gray-200/80 shadow-sm hover:shadow text-gray-500 hover:text-admin-500 transition-colors">
        <span class="material-icons-round text-[20px]">notifications</span>
        <span id="adminNotifBadge" class="hidden absolute -top-1.5 -right-1.5 min-w-[18px] h-[18px] px-1 rounded-full bg-rose-500 text-white text-[10px] font-bold flex items-center justify-center">0</span>
      </button>
      <div id="adminNotifPanel" class="hidden absolute right-0 mt-2 w-[340px] max-w-[90vw] bg-white rounded-2xl border border-gray-100 shadow-xl z-40 overflow-hidden">
        <div class="px-4 py-3 border-b border-gray-100 flex items-center justify-between">
          <p class="text-sm font-bold text-gray-800">การแจ้งเตือน</p>
          <button id="adminNotifMarkAll" class="text-xs text-indigo-500 hover:text-indigo-700 font-semibold">อ่านทั้งหมดแล้ว</button>
        </div>
        <div id="adminNotifList" class="max-h-[380px] overflow-y-auto divide-y divide-gray-50"></div>
      </div>
    </div>
  `;

  document.getElementById("adminNotifBellBtn")?.addEventListener("click", (e) => {
    e.stopPropagation();
    togglePanel();
  });
  document.getElementById("adminNotifMarkAll")?.addEventListener("click", markAllRead);
  document.addEventListener("click", (e) => {
    const panel = document.getElementById("adminNotifPanel");
    if (panel && !panel.classList.contains("hidden") && !root.contains(e.target)) {
      togglePanel(false);
    }
  });

  loadNotifications();
  wireRealtime();
  if (_pollTimer) clearInterval(_pollTimer);
  _pollTimer = setInterval(loadNotifications, 60000);
  return true;
}

globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
globalThis.__adminWebBridge.initAdminNotifBell = initAdminNotifBell;
