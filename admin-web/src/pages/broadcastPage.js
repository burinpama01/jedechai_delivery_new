function _deps(ctx) {
  return {
    supabase: ctx?.supabase || globalThis.supabase,
    escapeHtml:
      ctx?.escapeHtml ||
      globalThis.escapeHtml ||
      ((value) => String(value ?? "")),
    fmtDate:
      ctx?.fmtDate ||
      globalThis.fmtDate ||
      globalThis.__adminWebBridge?.fmtDate ||
      ((value) => (value ? new Date(value).toLocaleString("th-TH") : "-")),
    showToast:
      ctx?.showToast ||
      globalThis.showToast ||
      globalThis.__adminWebBridge?.showToast ||
      (() => {}),
    callAdminAction:
      ctx?.callAdminAction ||
      globalThis.callAdminAction ||
      null,
  };
}

const TARGET_LABELS = {
  all: "ผู้ใช้ทุกคน (ลูกค้า + คนขับ + ร้านค้า)",
  customer: "เฉพาะลูกค้า",
  driver: "เฉพาะคนขับ",
  merchant: "เฉพาะร้านค้า",
};

async function loadTargetCounts(supabase) {
  const roles = ["customer", "driver", "merchant"];
  const counts = {};
  await Promise.all(roles.map(async (role) => {
    const { count } = await supabase
      .from("profiles")
      .select("id", { count: "exact", head: true })
      .eq("role", role);
    counts[role] = count || 0;
  }));
  counts.all = roles.reduce((sum, role) => sum + (counts[role] || 0), 0);
  return counts;
}

async function loadRecentBroadcasts(supabase) {
  const { data, error } = await supabase
    .from("notifications")
    .select("title, body, created_at, data")
    .eq("type", "admin.broadcast")
    .order("created_at", { ascending: false })
    .limit(60);
  if (error) return [];
  // แถวถูก insert ต่อผู้รับ — ยุบให้เหลือหนึ่งรายการต่อการส่ง (title+เวลาใกล้กัน)
  const seen = new Set();
  const unique = [];
  for (const row of data || []) {
    const sentAt = row.data?.sent_at || String(row.created_at || "").slice(0, 16);
    const key = `${row.title}|${sentAt}`;
    if (seen.has(key)) continue;
    seen.add(key);
    unique.push(row);
    if (unique.length >= 10) break;
  }
  return unique;
}

export async function renderBroadcastPage(el, ctx) {
  const { supabase, escapeHtml, fmtDate, showToast, callAdminAction } = _deps(ctx);
  if (!supabase) {
    el.innerHTML = '<div class="p-6 text-red-600">Supabase client unavailable</div>';
    return;
  }

  el.innerHTML = `
    <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
      <div class="bg-white rounded-3xl border border-gray-100 shadow-sm p-6">
        <h2 class="text-xl font-bold text-gray-900">ส่งประกาศถึงผู้ใช้</h2>
        <p class="text-sm text-gray-500 mb-5">ข้อความจะแสดงในหน้าแจ้งเตือนของแอป และส่ง push (FCM) ถึงเครื่องที่เปิดรับ</p>
        <form id="broadcastForm" class="space-y-4">
          <label class="block">
            <span class="text-xs font-semibold text-gray-600">กลุ่มเป้าหมาย</span>
            <select name="target" id="broadcastTarget" class="mt-1 w-full rounded-xl border border-gray-200 px-3 py-2.5 text-sm bg-white">
              <option value="all">${TARGET_LABELS.all}</option>
              <option value="customer">${TARGET_LABELS.customer}</option>
              <option value="driver">${TARGET_LABELS.driver}</option>
              <option value="merchant">${TARGET_LABELS.merchant}</option>
            </select>
            <p id="broadcastTargetCount" class="text-xs text-gray-400 mt-1">กำลังนับจำนวนผู้รับ...</p>
          </label>
          <label class="block">
            <span class="text-xs font-semibold text-gray-600">หัวข้อ (สูงสุด 120 ตัวอักษร)</span>
            <input name="title" maxlength="120" required
              class="mt-1 w-full rounded-xl border border-gray-200 px-3 py-2.5 text-sm"
              placeholder="เช่น ประกาศปิดปรับปรุงระบบคืนนี้ 00:00-01:00">
          </label>
          <label class="block">
            <span class="text-xs font-semibold text-gray-600">ข้อความ (สูงสุด 500 ตัวอักษร)</span>
            <textarea name="body" maxlength="500" rows="4" required
              class="mt-1 w-full rounded-xl border border-gray-200 px-3 py-2.5 text-sm"
              placeholder="รายละเอียดประกาศ..."></textarea>
          </label>
          <label class="inline-flex items-center gap-2 text-sm text-gray-700">
            <input name="send_push" type="checkbox" checked class="rounded border-gray-300">
            ส่ง push notification (FCM) ด้วย
          </label>
          <div class="pt-2">
            <button type="submit" id="broadcastSubmitBtn"
              class="w-full px-4 py-3 rounded-xl bg-indigo-600 text-white text-sm font-bold hover:bg-indigo-700 disabled:opacity-50">
              ส่งประกาศ
            </button>
          </div>
        </form>
        <div id="broadcastResult" class="mt-4 hidden"></div>
      </div>
      <div class="bg-white rounded-3xl border border-gray-100 shadow-sm p-6">
        <h3 class="text-base font-bold text-gray-900 mb-1">ประกาศล่าสุด</h3>
        <p class="text-xs text-gray-500 mb-4">10 รายการล่าสุดที่ส่งจากระบบ</p>
        <div id="broadcastHistory" class="space-y-3">
          <div class="text-center text-gray-400 py-8">กำลังโหลด...</div>
        </div>
      </div>
    </div>
  `;

  let targetCounts = null;

  const updateTargetCount = () => {
    const label = el.querySelector("#broadcastTargetCount");
    const target = el.querySelector("#broadcastTarget")?.value || "all";
    if (!label) return;
    if (!targetCounts) {
      label.textContent = "กำลังนับจำนวนผู้รับ...";
      return;
    }
    label.textContent = `ผู้รับโดยประมาณ: ${new Intl.NumberFormat("th-TH").format(targetCounts[target] || 0)} คน (เพดาน 5,000 ต่อครั้ง)`;
  };

  const loadHistory = async () => {
    const historyEl = el.querySelector("#broadcastHistory");
    if (!historyEl) return;
    const rows = await loadRecentBroadcasts(supabase);
    if (!rows.length) {
      historyEl.innerHTML = '<div class="text-center text-gray-400 py-8">ยังไม่เคยส่งประกาศ</div>';
      return;
    }
    historyEl.innerHTML = rows.map((row) => `
      <div class="rounded-2xl border border-gray-100 bg-gray-50 p-3">
        <div class="flex items-center justify-between gap-2">
          <p class="font-semibold text-gray-800 text-sm truncate">${escapeHtml(row.title)}</p>
          <span class="text-[10px] text-gray-400 whitespace-nowrap">${escapeHtml(fmtDate(row.created_at))}</span>
        </div>
        <p class="text-xs text-gray-500 mt-1 line-clamp-2">${escapeHtml(row.body || "")}</p>
        <p class="text-[10px] text-indigo-500 mt-1">กลุ่ม: ${escapeHtml(TARGET_LABELS[row.data?.target] || row.data?.target || "-")}</p>
      </div>
    `).join("");
  };

  el.querySelector("#broadcastTarget")?.addEventListener("change", updateTargetCount);

  el.querySelector("#broadcastForm")?.addEventListener("submit", async (event) => {
    event.preventDefault();
    if (typeof callAdminAction !== "function") {
      showToast("ไม่พบ admin action สำหรับส่งประกาศ", "error");
      return;
    }
    const form = event.currentTarget;
    const formData = new FormData(form);
    const target = String(formData.get("target") || "all");
    const title = String(formData.get("title") || "").trim();
    const body = String(formData.get("body") || "").trim();
    if (!title || !body) return;

    const approxCount = targetCounts ? (targetCounts[target] || 0) : "?";
    if (typeof globalThis.confirm === "function" &&
      !globalThis.confirm(`ยืนยันส่งประกาศถึง ${TARGET_LABELS[target]} (~${approxCount} คน)?\n\n"${title}"`)) {
      return;
    }

    const submitBtn = el.querySelector("#broadcastSubmitBtn");
    const resultEl = el.querySelector("#broadcastResult");
    if (submitBtn) { submitBtn.disabled = true; submitBtn.textContent = "กำลังส่ง..."; }
    try {
      const result = await callAdminAction({
        action: "admin_broadcast_notification",
        target,
        title,
        body,
        send_push: formData.get("send_push") === "on",
      });
      showToast(`ส่งประกาศแล้วถึง ${result?.recipients ?? "?"} คน`, "success");
      if (resultEl) {
        resultEl.classList.remove("hidden");
        resultEl.innerHTML = `
          <div class="rounded-2xl bg-emerald-50 border border-emerald-200 text-emerald-800 text-sm p-3">
            ส่งสำเร็จ: ผู้รับ ${result?.recipients ?? "-"} คน · in-app ${result?.inserted ?? "-"} รายการ
            ${result?.capped ? "<br>⚠️ ผู้รับถึงเพดาน 5,000 — กลุ่มใหญ่กว่านี้ถูกตัด" : ""}
          </div>`;
      }
      form.reset();
      updateTargetCount();
      await loadHistory();
    } catch (err) {
      showToast(`ส่งประกาศไม่สำเร็จ: ${err.message || err}`, "error");
      if (resultEl) {
        resultEl.classList.remove("hidden");
        resultEl.innerHTML = `<div class="rounded-2xl bg-rose-50 border border-rose-200 text-rose-700 text-sm p-3">ส่งไม่สำเร็จ: ${escapeHtml(err.message || err)}</div>`;
      }
    } finally {
      if (submitBtn) { submitBtn.disabled = false; submitBtn.textContent = "ส่งประกาศ"; }
    }
  });

  loadTargetCounts(supabase)
    .then((counts) => { targetCounts = counts; updateTargetCount(); })
    .catch(() => { targetCounts = null; });
  await loadHistory();
}

globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
globalThis.__adminWebBridge.renderBroadcastPage = renderBroadcastPage;
