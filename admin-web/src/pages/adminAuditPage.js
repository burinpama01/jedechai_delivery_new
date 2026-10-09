// ทีมแอดมิน: บันทึกการทำงาน (superadmin เท่านั้น — RLS admin_audit_log อ่านได้เฉพาะ is_admin)
import { ACTION_CATALOG } from "../services/adminPermissions.js";
import { isSuperadmin } from "../services/adminAccess.js";

const OUTCOME_LABELS = {
  allowed: ["ทำรายการ", "text-emerald-700"],
  denied: ["ถูกปฏิเสธ", "text-red-600"],
  pending_approval: ["ส่งขออนุมัติ", "text-amber-700"],
  approved: ["อนุมัติ", "text-blue-700"],
  executed: ["อนุมัติและทำรายการ", "text-emerald-700"],
  rejected: ["ตีกลับ", "text-red-600"],
  failed: ["ทำรายการไม่สำเร็จ", "text-red-600"],
  cancelled: ["ยกเลิก", "text-gray-500"],
  error: ["ผิดพลาด", "text-red-600"],
};
const TIER_LABELS = { superadmin: "Superadmin", lead: "หัวหน้า", assistant: "ผู้ช่วย" };

function _deps(ctx) {
  return {
    supabase: ctx?.supabase || globalThis.supabase,
    escapeHtml: ctx?.escapeHtml || globalThis.escapeHtml || ((v) => String(v ?? "")),
    fmtDate: ctx?.fmtDate || globalThis.fmtDate || ((v) => (v ? new Date(v).toLocaleString("th-TH") : "-")),
  };
}

export async function renderAdminAuditPage(el, ctx) {
  const { supabase, escapeHtml, fmtDate } = _deps(ctx);
  if (!isSuperadmin()) {
    el.innerHTML = '<div class="bg-white rounded-3xl border border-gray-100 p-10 text-center text-gray-500">หน้านี้สำหรับ superadmin เท่านั้น</div>';
    return;
  }

  el.innerHTML = `<div id="auditRoot">
    <div class="bg-white rounded-3xl border border-gray-100 shadow-sm p-5 mb-6 flex flex-col md:flex-row md:items-center md:justify-between gap-3">
      <div><h2 class="text-xl font-bold text-gray-900">บันทึกการทำงาน</h2>
        <p class="text-sm text-gray-500">การทำรายการผ่านหลังบ้าน การส่ง/พิจารณาคำขอ และการเปลี่ยนสิทธิ์ทีม (500 รายการล่าสุด)</p></div>
      <div class="flex flex-wrap gap-2">
        <select id="auditOutcome" class="rounded-xl border border-gray-200 px-3 py-2 text-sm">
          <option value="">ทุกผล</option>
          ${Object.entries(OUTCOME_LABELS).map(([k, [l]]) => `<option value="${k}">${escapeHtml(l)}</option>`).join("")}
        </select>
        <select id="auditTier" class="rounded-xl border border-gray-200 px-3 py-2 text-sm">
          <option value="">ทุกระดับ</option><option value="superadmin">Superadmin</option><option value="lead">หัวหน้า</option><option value="assistant">ผู้ช่วย</option>
        </select>
        <input id="auditSearch" placeholder="ค้นหา ชื่อ/รายการ/เป้าหมาย" class="rounded-xl border border-gray-200 px-3 py-2 text-sm w-[200px]">
      </div>
    </div>
    <div id="auditContent" class="bg-white rounded-3xl border border-gray-100 shadow-sm p-5"><div class="text-center text-gray-400 py-12">กำลังโหลด...</div></div>
  </div>`;
  const root = el.querySelector("#auditRoot");

  const { data, error } = await supabase
    .from("admin_audit_log")
    .select("id, actor_id, actor_tier, action, target, summary, outcome, request_id, created_at")
    .order("created_at", { ascending: false })
    .limit(500);
  if (error) {
    root.querySelector("#auditContent").innerHTML = `<div class="text-red-600">โหลดไม่สำเร็จ: ${escapeHtml(error.message)}</div>`;
    return;
  }
  const rows = data || [];
  const actorIds = [...new Set(rows.map((r) => r.actor_id).filter(Boolean))];
  let names = {};
  if (actorIds.length) {
    const { data: people } = await supabase.from("profiles").select("id, full_name, phone_number").in("id", actorIds);
    names = Object.fromEntries((people || []).map((p) => [p.id, p.full_name || p.phone_number || p.id.slice(0, 8)]));
  }

  const draw = () => {
    const outcome = root.querySelector("#auditOutcome").value;
    const tier = root.querySelector("#auditTier").value;
    const q = root.querySelector("#auditSearch").value.trim().toLowerCase();
    const list = rows.filter((r) => {
      if (outcome && r.outcome !== outcome) return false;
      if (tier && r.actor_tier !== tier) return false;
      if (!q) return true;
      return [names[r.actor_id], r.summary, r.target, r.action, ACTION_CATALOG[r.action]?.label].join(" ").toLowerCase().includes(q);
    });
    root.querySelector("#auditContent").innerHTML = list.length ? `<div class="overflow-x-auto"><table class="w-full text-sm">
      <thead><tr class="text-left text-gray-500"><th class="py-2 pr-3">เวลา</th><th class="pr-3">ผู้ทำ</th><th class="pr-3">รายการ</th><th class="pr-3">ผล</th><th>เป้าหมาย</th></tr></thead>
      <tbody>${list.map((r) => {
        const [label, cls] = OUTCOME_LABELS[r.outcome] || [r.outcome, "text-gray-600"];
        return `<tr class="border-t border-gray-100 align-top">
          <td class="py-2 pr-3 whitespace-nowrap text-gray-500">${escapeHtml(fmtDate(r.created_at))}</td>
          <td class="py-2 pr-3">${escapeHtml(names[r.actor_id] || "-")}<div class="text-xs text-gray-400">${escapeHtml(TIER_LABELS[r.actor_tier] || r.actor_tier || "")}</div></td>
          <td class="py-2 pr-3">${escapeHtml(r.summary || ACTION_CATALOG[r.action]?.label || r.action)}</td>
          <td class="py-2 pr-3 font-semibold ${cls}">${escapeHtml(label)}</td>
          <td class="py-2 text-xs text-gray-500 break-all">${escapeHtml(r.target || "")}</td>
        </tr>`;
      }).join("")}</tbody></table></div>` : '<div class="text-center text-gray-400 py-10">ไม่มีรายการ</div>';
  };

  root.addEventListener("input", draw);
  root.addEventListener("change", draw);
  draw();
}
