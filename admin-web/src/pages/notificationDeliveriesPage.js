let _ctx = null;

function _deps() {
  const ctx = _ctx || globalThis.__adminWebContext || globalThis.__adminWebBridge || {};
  return {
    supabase: ctx.supabase || globalThis.supabase,
    fmtDate: ctx.fmtDate || globalThis.fmtDate || globalThis.__adminWebBridge?.fmtDate,
    escapeHtml: ctx.escapeHtml || globalThis.escapeHtml || ((value) => String(value ?? "")),
  };
}

function _statusBadge(status) {
  const cls = {
    sent: "bg-emerald-50 text-emerald-700 border-emerald-200",
    failed: "bg-red-50 text-red-700 border-red-200",
    skipped: "bg-amber-50 text-amber-700 border-amber-200",
  }[status] || "bg-gray-50 text-gray-700 border-gray-200";
  return `<span class="px-2 py-1 rounded-lg border text-xs font-semibold ${cls}">${status || "-"}</span>`;
}

export async function renderNotificationDeliveriesPage(el, ctx) {
  _ctx = ctx || null;
  globalThis.__adminWebContext = {
    ...(globalThis.__adminWebContext || {}),
    ...(ctx || {}),
  };

  const today = new Date();
  const weekAgo = new Date(today);
  weekAgo.setDate(weekAgo.getDate() - 7);

  el.innerHTML = `
    <div class="fade-in space-y-5">
      <div class="glass-card p-4 flex flex-wrap gap-3 items-center">
        <span class="material-icons-round text-indigo-400 text-lg">notifications_active</span>
        <input type="date" id="notifDeliveryFrom" value="${weekAgo.toISOString().split("T")[0]}" class="border border-gray-200 rounded-xl px-3.5 py-2 text-sm bg-gray-50/50 transition-all" />
        <span class="text-gray-300 text-sm font-medium">ถึง</span>
        <input type="date" id="notifDeliveryTo" value="${today.toISOString().split("T")[0]}" class="border border-gray-200 rounded-xl px-3.5 py-2 text-sm bg-gray-50/50 transition-all" />
        <select id="notifDeliveryStatus" class="text-sm border border-gray-200 rounded-xl px-3.5 py-2 bg-gray-50/50 transition-all">
          <option value="">ทุกสถานะ</option>
          <option value="sent">sent</option>
          <option value="failed">failed</option>
          <option value="skipped">skipped</option>
        </select>
        <button onclick="loadNotificationDeliveries()" class="text-white px-5 py-2 rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">โหลดข้อมูล</button>
      </div>
      <div id="notificationDeliveriesContainer"><div class="flex justify-center py-10"><div class="loader"></div></div></div>
    </div>`;

  await loadNotificationDeliveries();
}

export async function loadNotificationDeliveries() {
  const { supabase, fmtDate, escapeHtml } = _deps();
  const container = document.getElementById("notificationDeliveriesContainer");
  if (!container) return;

  const from = document.getElementById("notifDeliveryFrom")?.value;
  const to = document.getElementById("notifDeliveryTo")?.value;
  const status = document.getElementById("notifDeliveryStatus")?.value;
  const startDate = from ? new Date(`${from}T00:00:00`).toISOString() : new Date(Date.now() - 7 * 86400000).toISOString();
  const endDate = to ? new Date(`${to}T23:59:59`).toISOString() : new Date().toISOString();

  container.innerHTML = '<div class="flex justify-center py-10"><div class="loader"></div></div>';

  let query = supabase
    .from("notification_deliveries")
    .select("id, notification_id, user_id, channel, status, provider_message_id, error, created_at")
    .gte("created_at", startDate)
    .lte("created_at", endDate)
    .order("created_at", { ascending: false })
    .limit(300);

  if (status) query = query.eq("status", status);

  const { data, error } = await query;
  if (error) {
    container.innerHTML = `<div class="glass-card p-6 text-red-600">โหลด delivery log ไม่สำเร็จ: ${escapeHtml(error.message)}</div>`;
    return;
  }

  const rows = data || [];
  const counts = rows.reduce((acc, row) => {
    const key = row.status || "unknown";
    acc[key] = (acc[key] || 0) + 1;
    return acc;
  }, {});

  container.innerHTML = `
    <div class="grid grid-cols-1 md:grid-cols-4 gap-4">
      ${["sent", "failed", "skipped", "unknown"].map((key) => `
        <div class="glass-card p-4">
          <p class="text-xs text-gray-400 uppercase tracking-wide">${key}</p>
          <p class="text-2xl font-extrabold text-gray-800 mt-1">${counts[key] || 0}</p>
        </div>`).join("")}
    </div>
    <div class="glass-card overflow-hidden">
      <div class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead class="bg-gray-50 text-gray-500">
            <tr>
              <th class="px-4 py-3 text-left font-semibold">เวลา</th>
              <th class="px-4 py-3 text-left font-semibold">ผู้รับ</th>
              <th class="px-4 py-3 text-left font-semibold">Channel</th>
              <th class="px-4 py-3 text-left font-semibold">สถานะ</th>
              <th class="px-4 py-3 text-left font-semibold">Notification</th>
              <th class="px-4 py-3 text-left font-semibold">Error / Provider ID</th>
            </tr>
          </thead>
          <tbody>
            ${rows.length ? rows.map((row) => `
              <tr class="table-row border-t border-gray-100">
                <td class="px-4 py-3 whitespace-nowrap">${fmtDate ? fmtDate(row.created_at) : escapeHtml(row.created_at)}</td>
                <td class="px-4 py-3 font-mono text-xs">${escapeHtml(row.user_id || "-")}</td>
                <td class="px-4 py-3">${escapeHtml(row.channel || "-")}</td>
                <td class="px-4 py-3">${_statusBadge(row.status)}</td>
                <td class="px-4 py-3 font-mono text-xs">${escapeHtml(row.notification_id || "-")}</td>
                <td class="px-4 py-3 text-xs">${escapeHtml(row.error || row.provider_message_id || "-")}</td>
              </tr>`).join("") : `
              <tr><td colspan="6" class="px-4 py-10 text-center text-gray-400">ไม่พบ delivery log ในช่วงนี้</td></tr>`}
          </tbody>
        </table>
      </div>
    </div>`;
}

export function wireNotificationDeliveriesBridge() {
  globalThis.loadNotificationDeliveries = loadNotificationDeliveries;
}
