// ทีมแอดมิน: คำขออนุมัติ (maker-checker)
// ข้อมูลอ่านตรงจาก admin_approval_requests (RLS: superadmin เห็นทั้งหมด, ผู้ขอเห็นของตัวเอง,
// หัวหน้าเห็นคำขอในหน้าที่ตัวเองมีระดับอนุมัติ) · พิจารณา/ยกเลิกผ่าน admin-actions
import { ACTION_CATALOG, ADMIN_PAGES, canDecideApproval } from "../services/adminPermissions.js";
import { getAdminAccess } from "../services/adminAccess.js";

const STATUS_LABELS = {
  pending: ["รอพิจารณา", "bg-amber-50 text-amber-700"],
  approved: ["อนุมัติแล้ว", "bg-blue-50 text-blue-700"],
  executed: ["อนุมัติและทำรายการแล้ว", "bg-emerald-50 text-emerald-700"],
  failed: ["อนุมัติแต่ทำรายการไม่สำเร็จ", "bg-red-50 text-red-700"],
  rejected: ["ตีกลับ", "bg-red-50 text-red-700"],
  cancelled: ["ยกเลิก", "bg-gray-100 text-gray-600"],
  expired: ["หมดอายุ", "bg-gray-100 text-gray-600"],
};

function _deps(ctx) {
  return {
    supabase: ctx?.supabase || globalThis.supabase,
    escapeHtml: ctx?.escapeHtml || globalThis.escapeHtml || ((v) => String(v ?? "")),
    fmtDate: ctx?.fmtDate || globalThis.fmtDate || ((v) => (v ? new Date(v).toLocaleString("th-TH") : "-")),
    showToast: ctx?.showToast || globalThis.showToast || (() => {}),
    callAdminAction: ctx?.callAdminAction || globalThis.callAdminAction || null,
    currentUserId: ctx?.currentUser?.id || null,
  };
}

function isPendingLive(row) {
  return row.status === "pending" && new Date(row.expires_at).getTime() > Date.now();
}

function statusBadge(row, escapeHtml) {
  const key = row.status === "pending" && !isPendingLive(row) ? "expired" : row.status;
  const [label, cls] = STATUS_LABELS[key] || [key, "bg-gray-100 text-gray-600"];
  return `<span class="inline-flex px-2 py-0.5 rounded-full text-xs font-semibold ${cls}">${escapeHtml(label)}</span>`;
}

function payloadDetails(payload, escapeHtml) {
  const shown = { ...(payload || {}) };
  delete shown.action;
  const json = JSON.stringify(shown, null, 2);
  return `<details class="mt-2"><summary class="text-xs text-gray-500 cursor-pointer">รายละเอียดคำขอ</summary>
    <pre class="mt-1 text-xs bg-gray-50 rounded-xl p-3 overflow-auto max-h-64">${escapeHtml(json)}</pre></details>`;
}

export async function renderApprovalsPage(el, ctx) {
  const { supabase, escapeHtml, fmtDate, showToast, callAdminAction, currentUserId } = _deps(ctx);
  const access = getAdminAccess();

  el.innerHTML = `<div id="approvalsRoot">
    <div class="bg-white rounded-3xl border border-gray-100 shadow-sm p-5 mb-6">
      <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-3">
        <div>
          <h2 class="text-xl font-bold text-gray-900">คำขออนุมัติ</h2>
          <p class="text-sm text-gray-500">งานสำคัญที่ผู้ช่วยส่งมาให้ผู้มีสิทธิ์ยืนยัน · คำขอหมดอายุใน 48 ชั่วโมง</p>
        </div>
        <div class="flex flex-wrap gap-2" role="tablist">
          <button data-tab="decide" class="apv-tab px-3 py-2 rounded-xl text-sm font-semibold">รอฉันพิจารณา</button>
          <button data-tab="mine" class="apv-tab px-3 py-2 rounded-xl text-sm font-semibold">คำขอของฉัน</button>
          <button data-tab="all" class="apv-tab px-3 py-2 rounded-xl text-sm font-semibold">ทั้งหมดที่เห็น</button>
          <button data-act="refresh" class="px-3 py-2 bg-gray-100 hover:bg-gray-200 rounded-xl text-sm font-semibold">รีเฟรช</button>
        </div>
      </div>
    </div>
    <div id="approvalsContent" class="space-y-3"><div class="text-center text-gray-400 py-12">กำลังโหลด...</div></div>
  </div>`;
  // ผูก event กับ root ของหน้านี้ (el ใช้ร่วมกันทุกหน้า — ผูกที่ el จะสะสมข้ามหน้า)
  const root = el.querySelector("#approvalsRoot");

  let rows = [];
  let tab = "decide";

  const canDecide = (row) => canDecideApproval(access, row.pages || [], currentUserId, row.requester_id);

  const draw = () => {
    root.querySelectorAll(".apv-tab").forEach((b) => {
      const active = b.dataset.tab === tab;
      b.classList.toggle("bg-gray-900", active);
      b.classList.toggle("text-white", active);
      b.classList.toggle("bg-gray-100", !active);
    });
    let list = rows;
    if (tab === "decide") list = rows.filter((r) => isPendingLive(r) && canDecide(r));
    if (tab === "mine") list = rows.filter((r) => r.requester_id === currentUserId);
    const content = root.querySelector("#approvalsContent");
    if (!list.length) {
      content.innerHTML = `<div class="bg-white rounded-3xl border border-gray-100 p-10 text-center text-gray-400">ไม่มีรายการ</div>`;
      return;
    }
    content.innerHTML = list.map((r) => {
      const label = ACTION_CATALOG[r.action]?.label || r.action;
      const pages = (r.pages || []).map((p) => ADMIN_PAGES[p] || p).join(", ");
      const live = isPendingLive(r);
      const decideBtns = live && canDecide(r) ? `
        <button data-act="approve" data-id="${escapeHtml(r.id)}" class="px-3 py-2 bg-emerald-600 hover:bg-emerald-700 text-white rounded-xl text-sm font-semibold">อนุมัติ</button>
        <button data-act="reject" data-id="${escapeHtml(r.id)}" class="px-3 py-2 bg-red-50 hover:bg-red-100 text-red-700 rounded-xl text-sm font-semibold">ตีกลับ</button>` : "";
      const cancelBtn = live && r.requester_id === currentUserId
        ? `<button data-act="cancel" data-id="${escapeHtml(r.id)}" class="px-3 py-2 bg-gray-100 hover:bg-gray-200 rounded-xl text-sm font-semibold">ยกเลิกคำขอ</button>` : "";
      const decided = r.decided_at ? `<div class="text-xs text-gray-500 mt-1">พิจารณาโดย ${escapeHtml(r.decided_by_name || "-")} · ${escapeHtml(fmtDate(r.decided_at))}${r.decision_note ? ` · เหตุผล: ${escapeHtml(r.decision_note)}` : ""}</div>` : "";
      const failed = r.status === "failed" && r.result ? `<div class="text-xs text-red-600 mt-1">ผล: ${escapeHtml(r.result.error || r.result.message || JSON.stringify(r.result).slice(0, 200))}</div>` : "";
      return `<div class="bg-white rounded-3xl border border-gray-100 shadow-sm p-5">
        <div class="flex flex-col md:flex-row md:items-start md:justify-between gap-3">
          <div class="min-w-0">
            <div class="flex flex-wrap items-center gap-2"><span class="font-bold text-gray-900">${escapeHtml(label)}</span>${statusBadge(r, escapeHtml)}</div>
            <div class="text-sm text-gray-600 mt-1">${escapeHtml(r.summary || "")}</div>
            <div class="text-xs text-gray-500 mt-1">ขอโดย ${escapeHtml(r.requester_name || "-")} · ${escapeHtml(fmtDate(r.created_at))} · หน้า: ${escapeHtml(pages || "-")}</div>
            ${decided}${failed}
            ${payloadDetails(r.payload, escapeHtml)}
          </div>
          <div class="flex flex-wrap gap-2 shrink-0">${decideBtns}${cancelBtn}</div>
        </div>
      </div>`;
    }).join("");
  };

  const load = async () => {
    const { data, error } = await supabase
      .from("admin_approval_requests")
      .select("id, requester_id, requester_name, action, pages, payload, summary, status, decided_by_name, decision_note, decided_at, result, created_at, expires_at")
      .order("created_at", { ascending: false })
      .limit(200);
    if (error) {
      root.querySelector("#approvalsContent").innerHTML = `<div class="bg-white rounded-3xl border border-red-100 p-6 text-red-600">โหลดคำขอไม่สำเร็จ: ${escapeHtml(error.message)}</div>`;
      return;
    }
    rows = data || [];
    if (tab === "decide" && !rows.some((r) => isPendingLive(r) && canDecide(r))) {
      tab = rows.some((r) => r.requester_id === currentUserId) ? "mine" : "all";
    }
    draw();
  };

  const run = async (body, okMessage) => {
    try {
      const res = await callAdminAction(body);
      if (res?.success === false) throw new Error(res?.result?.error || res?.status || "ทำรายการไม่สำเร็จ");
      showToast(okMessage, "success");
    } catch (e) {
      showToast(`ไม่สำเร็จ: ${e?.message || e}`, "error");
    }
    await load();
  };

  root.addEventListener("click", async (event) => {
    const tabBtn = event.target.closest(".apv-tab");
    if (tabBtn) {
      tab = tabBtn.dataset.tab;
      draw();
      return;
    }
    const btn = event.target.closest("[data-act]");
    if (!btn) return;
    const id = btn.dataset.id;
    if (btn.dataset.act === "refresh") return load();
    if (typeof callAdminAction !== "function") return showToast("ไม่พบ admin action", "error");
    btn.disabled = true;
    try {
      if (btn.dataset.act === "approve") {
        if (!globalThis.confirm("อนุมัติและทำรายการนี้ทันที?")) return;
        const note = globalThis.prompt("หมายเหตุ (ไม่บังคับ)", "") ?? "";
        await run({ action: "approval_decide", request_id: id, decision: "approve", note }, "อนุมัติแล้ว");
      } else if (btn.dataset.act === "reject") {
        const note = (globalThis.prompt("เหตุผลที่ตีกลับ (บังคับ)", "") || "").trim();
        if (!note) return showToast("กรุณาระบุเหตุผล", "error");
        await run({ action: "approval_decide", request_id: id, decision: "reject", note }, "ตีกลับแล้ว");
      } else if (btn.dataset.act === "cancel") {
        if (!globalThis.confirm("ยกเลิกคำขอนี้?")) return;
        await run({ action: "approval_cancel", request_id: id }, "ยกเลิกคำขอแล้ว");
      }
    } finally {
      btn.disabled = false;
    }
  });

  await load();
}
