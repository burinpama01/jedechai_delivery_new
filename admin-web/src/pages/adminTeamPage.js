// ทีมแอดมิน: จัดการสมาชิก บทบาทสำเร็จรูป และ superadmin (superadmin เท่านั้น)
// อ่านตรงผ่าน RLS (is_admin) · เขียนผ่าน admin-actions (team_* / template_* / superadmin_*)
import { ACTION_CATALOG, ADMIN_PAGES } from "../services/adminPermissions.js";
import { isSuperadmin } from "../services/adminAccess.js";

const LEVELS = [
  ["none", "ไม่เห็น"],
  ["view", "ดู"],
  ["edit", "แก้ไข"],
  ["approve", "อนุมัติ"],
];
const EFFECTS = [
  ["", "ตามระดับหน้า"],
  ["allow", "อนุญาต"],
  ["require_approval", "ต้องขออนุมัติ"],
  ["deny", "ห้าม"],
];
const TIER_LABELS = { lead: "หัวหน้า", assistant: "ผู้ช่วย" };
const KIND_LABELS = { read: "ดู", write: "แก้ไข", sensitive: "สำคัญ", super: "superadmin" };

// หน้าที่ตั้งระดับให้ staff ได้ (ตั้งค่าระบบ/ทีม เป็นของ superadmin)
const STAFF_PAGES = Object.keys(ADMIN_PAGES).filter((p) => p !== "settings");

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

async function loadTeam(supabase) {
  const [staffRes, pagesRes, actionsRes, templatesRes, profilesRes] = await Promise.all([
    supabase.from("admin_staff").select("*").order("created_at"),
    supabase.from("admin_staff_page_overrides").select("*"),
    supabase.from("admin_staff_action_overrides").select("*"),
    supabase.from("admin_role_templates").select("*").order("is_system", { ascending: false }).order("name"),
    supabase.from("profiles").select("id, full_name, phone_number, role, approval_status").in("role", ["admin", "staff"]),
  ]);
  for (const res of [staffRes, pagesRes, actionsRes, templatesRes, profilesRes]) {
    if (res.error) throw res.error;
  }
  const profiles = Object.fromEntries((profilesRes.data || []).map((p) => [p.id, p]));
  const pageOverrides = {};
  for (const row of pagesRes.data || []) (pageOverrides[row.user_id] ||= {})[row.page] = row.level;
  const actionOverrides = {};
  for (const row of actionsRes.data || []) (actionOverrides[row.user_id] ||= {})[row.action] = row.effect;
  return {
    staff: staffRes.data || [],
    templates: templatesRes.data || [],
    profiles,
    superadmins: (profilesRes.data || []).filter((p) => p.role === "admin"),
    pageOverrides,
    actionOverrides,
  };
}

function options(list, selected, escapeHtml) {
  return list.map(([v, l]) => `<option value="${escapeHtml(v)}" ${v === selected ? "selected" : ""}>${escapeHtml(l)}</option>`).join("");
}

export async function renderAdminTeamPage(el, ctx) {
  const { supabase, escapeHtml, showToast, callAdminAction, currentUserId } = _deps(ctx);
  if (!isSuperadmin()) {
    el.innerHTML = '<div class="bg-white rounded-3xl border border-gray-100 p-10 text-center text-gray-500">หน้านี้สำหรับ superadmin เท่านั้น</div>';
    return;
  }

  el.innerHTML = `<div id="teamRoot">
    <div class="bg-white rounded-3xl border border-gray-100 shadow-sm p-5 mb-6">
      <h2 class="text-xl font-bold text-gray-900">ทีมแอดมิน</h2>
      <p class="text-sm text-gray-500">เพิ่มผู้ช่วย/หัวหน้า กำหนดบทบาทและสิทธิ์รายหน้า/ราย action · ทุกการเปลี่ยนแปลงถูกบันทึกในบันทึกการทำงาน</p>
    </div>
    <div class="grid grid-cols-1 xl:grid-cols-3 gap-6">
      <div class="xl:col-span-2 space-y-6">
        <section class="bg-white rounded-3xl border border-gray-100 shadow-sm p-5">
          <h3 class="font-bold text-gray-900 mb-3">เพิ่มสมาชิก</h3>
          <form id="teamAddForm" class="grid grid-cols-1 md:grid-cols-2 gap-3">
            <label class="text-sm">วิธีเพิ่ม
              <select name="mode" class="mt-1 w-full rounded-xl border border-gray-200 px-3 py-2">
                <option value="existing">แปลงบัญชีที่สมัครแล้ว (อีเมล)</option>
                <option value="create">สร้างบัญชีใหม่ + ลิงก์ตั้งรหัสผ่าน</option>
              </select></label>
            <label class="text-sm">อีเมล<input name="email" type="email" required class="mt-1 w-full rounded-xl border border-gray-200 px-3 py-2"></label>
            <label class="text-sm team-create-only hidden">ชื่อ<input name="full_name" class="mt-1 w-full rounded-xl border border-gray-200 px-3 py-2"></label>
            <label class="text-sm">ระดับ
              <select name="tier" class="mt-1 w-full rounded-xl border border-gray-200 px-3 py-2">
                <option value="assistant">ผู้ช่วย</option><option value="lead">หัวหน้า (อนุมัติคำขอในหน้าที่มีระดับอนุมัติ)</option>
              </select></label>
            <label class="text-sm">บทบาท<select name="template_id" id="teamAddTemplate" class="mt-1 w-full rounded-xl border border-gray-200 px-3 py-2"></select></label>
            <div class="md:col-span-2 flex justify-end"><button class="px-4 py-2 bg-gray-900 text-white rounded-xl text-sm font-semibold">เพิ่มเข้าทีม</button></div>
          </form>
          <div id="teamLinkBox" class="hidden mt-3 rounded-2xl bg-amber-50 border border-amber-200 p-3 text-sm"></div>
        </section>
        <section class="bg-white rounded-3xl border border-gray-100 shadow-sm p-5">
          <h3 class="font-bold text-gray-900 mb-3">สมาชิกทีม</h3>
          <div id="teamMembers" class="text-gray-400">กำลังโหลด...</div>
        </section>
      </div>
      <div class="space-y-6">
        <section class="bg-white rounded-3xl border border-gray-100 shadow-sm p-5">
          <h3 class="font-bold text-gray-900 mb-3">Superadmin</h3>
          <div id="teamSupers" class="text-gray-400">กำลังโหลด...</div>
        </section>
        <section class="bg-white rounded-3xl border border-gray-100 shadow-sm p-5">
          <div class="flex items-center justify-between mb-3"><h3 class="font-bold text-gray-900">บทบาทสำเร็จรูป</h3>
            <button data-act="template-new" class="px-3 py-1.5 bg-gray-100 hover:bg-gray-200 rounded-xl text-xs font-semibold">+ บทบาทใหม่</button></div>
          <div id="teamTemplates" class="text-gray-400">กำลังโหลด...</div>
        </section>
      </div>
    </div>
    <div id="teamModal" class="hidden fixed inset-0 z-50 bg-black/40 flex items-start justify-center overflow-y-auto p-4"></div>
  </div>`;
  const root = el.querySelector("#teamRoot");
  let data = null;

  const templateName = (id) => data.templates.find((t) => t.id === id)?.name || "ไม่มีบทบาท";
  const personName = (id) => {
    const p = data.profiles[id];
    return p?.full_name || p?.phone_number || `#${String(id).slice(0, 8)}`;
  };

  const draw = () => {
    root.querySelector("#teamAddTemplate").innerHTML =
      `<option value="">— ไม่มี (ตั้งรายหน้าเอง) —</option>` +
      data.templates.map((t) => `<option value="${escapeHtml(t.id)}">${escapeHtml(t.name)}</option>`).join("");

    root.querySelector("#teamMembers").innerHTML = data.staff.length ? `<div class="overflow-x-auto"><table class="w-full text-sm">
      <thead><tr class="text-left text-gray-500"><th class="py-2 pr-3">ชื่อ</th><th class="pr-3">ระดับ</th><th class="pr-3">บทบาท</th><th class="pr-3">สถานะ</th><th></th></tr></thead>
      <tbody>${data.staff.map((s) => `<tr class="border-t border-gray-100">
        <td class="py-2 pr-3 font-medium text-gray-900">${escapeHtml(personName(s.user_id))}</td>
        <td class="pr-3">${escapeHtml(TIER_LABELS[s.tier] || s.tier)}</td>
        <td class="pr-3">${escapeHtml(templateName(s.template_id))}${Object.keys(data.pageOverrides[s.user_id] || {}).length || Object.keys(data.actionOverrides[s.user_id] || {}).length ? ' <span class="text-xs text-amber-600">+ปรับเฉพาะคน</span>' : ""}</td>
        <td class="pr-3">${s.active ? '<span class="text-emerald-600">ใช้งาน</span>' : '<span class="text-red-600">ระงับ</span>'}</td>
        <td class="py-2 text-right whitespace-nowrap">
          <button data-act="member-edit" data-id="${escapeHtml(s.user_id)}" class="px-2 py-1 bg-gray-100 hover:bg-gray-200 rounded-lg text-xs font-semibold">แก้ไขสิทธิ์</button>
          <button data-act="member-link" data-id="${escapeHtml(s.user_id)}" class="px-2 py-1 bg-gray-100 hover:bg-gray-200 rounded-lg text-xs font-semibold">ลิงก์ตั้งรหัส</button>
          <button data-act="member-promote" data-id="${escapeHtml(s.user_id)}" class="px-2 py-1 bg-gray-100 hover:bg-gray-200 rounded-lg text-xs font-semibold">ตั้งเป็น superadmin</button>
          <button data-act="member-remove" data-id="${escapeHtml(s.user_id)}" class="px-2 py-1 bg-red-50 hover:bg-red-100 text-red-700 rounded-lg text-xs font-semibold">นำออก</button>
        </td></tr>`).join("")}</tbody></table></div>` : '<div class="text-gray-400 text-sm">ยังไม่มีสมาชิก</div>';

    root.querySelector("#teamSupers").innerHTML = data.superadmins.map((p) => `<div class="flex items-center justify-between py-1.5">
      <span class="text-sm text-gray-900">${escapeHtml(p.full_name || p.phone_number || p.id.slice(0, 8))}${p.id === currentUserId ? ' <span class="text-xs text-gray-400">(คุณ)</span>' : ""}</span>
      ${data.superadmins.length > 1 ? `<button data-act="super-revoke" data-id="${escapeHtml(p.id)}" class="px-2 py-1 bg-red-50 hover:bg-red-100 text-red-700 rounded-lg text-xs font-semibold">ถอด</button>` : '<span class="text-xs text-gray-400">ต้องมีอย่างน้อย 1 คน</span>'}
    </div>`).join("");

    root.querySelector("#teamTemplates").innerHTML = data.templates.map((t) => {
      const count = Object.keys(t.page_levels || {}).length;
      return `<div class="flex items-center justify-between py-1.5 border-b border-gray-50">
        <div><div class="text-sm font-medium text-gray-900">${escapeHtml(t.name)}${t.is_system ? ' <span class="text-xs text-gray-400">ตั้งต้น</span>' : ""}</div>
        <div class="text-xs text-gray-500">${escapeHtml(t.description || "")} · ${count} หน้า</div></div>
        <div class="whitespace-nowrap"><button data-act="template-edit" data-id="${escapeHtml(t.id)}" class="px-2 py-1 bg-gray-100 hover:bg-gray-200 rounded-lg text-xs font-semibold">แก้ไข</button>
        ${t.is_system ? "" : `<button data-act="template-delete" data-id="${escapeHtml(t.id)}" class="px-2 py-1 bg-red-50 text-red-700 rounded-lg text-xs font-semibold">ลบ</button>`}</div>
      </div>`;
    }).join("") || '<div class="text-gray-400 text-sm">ไม่มีบทบาท</div>';
  };

  const load = async () => {
    try {
      data = await loadTeam(supabase);
      draw();
    } catch (e) {
      root.querySelector("#teamMembers").innerHTML = `<div class="text-red-600 text-sm">โหลดข้อมูลทีมไม่สำเร็จ: ${escapeHtml(e?.message || e)}</div>`;
    }
  };

  const call = async (body, okMessage) => {
    const res = await callAdminAction(body);
    if (res?.success === false) throw new Error(res?.error || res?.message || "ทำรายการไม่สำเร็จ");
    if (okMessage) showToast(okMessage, "success");
    return res;
  };

  const showLink = (link, who) => {
    const box = root.querySelector("#teamLinkBox");
    if (!link) {
      box.classList.add("hidden");
      return;
    }
    box.innerHTML = `<div class="font-semibold mb-1">ลิงก์ตั้งรหัสผ่านของ ${escapeHtml(who)} (ส่งให้เจ้าของบัญชีเอง · ใช้ได้ครั้งเดียว)</div>
      <div class="flex gap-2"><input readonly class="flex-1 rounded-lg border border-amber-200 px-2 py-1 text-xs" value="${escapeHtml(link)}">
      <button type="button" data-act="copy-link" class="px-2 py-1 bg-amber-600 text-white rounded-lg text-xs font-semibold">คัดลอก</button></div>`;
    box.classList.remove("hidden");
  };

  const modal = root.querySelector("#teamModal");
  const closeModal = () => {
    modal.classList.add("hidden");
    modal.innerHTML = "";
  };

  const levelMatrix = (current, inheritFrom) => STAFF_PAGES.map((page) => {
    const base = inheritFrom ? (inheritFrom[page] || "none") : null;
    const choices = inheritFrom
      ? [["", `ตามบทบาท (${LEVELS.find(([v]) => v === base)?.[1] || "ไม่เห็น"})`], ...LEVELS]
      : LEVELS;
    return `<label class="flex items-center justify-between gap-2 py-1 text-sm border-b border-gray-50">
      <span>${escapeHtml(ADMIN_PAGES[page])}</span>
      <select data-page="${escapeHtml(page)}" class="lvl rounded-lg border border-gray-200 px-2 py-1 text-xs">${options(choices, current[page] ?? "", escapeHtml)}</select>
    </label>`;
  }).join("");

  const openMember = (userId) => {
    const s = data.staff.find((x) => x.user_id === userId);
    if (!s) return;
    const tpl = data.templates.find((t) => t.id === s.template_id);
    const pages = data.pageOverrides[userId] || {};
    const actions = data.actionOverrides[userId] || {};
    const actionRows = Object.entries(ACTION_CATALOG)
      .filter(([, e]) => e.kind !== "team" && e.kind !== "approval")
      .sort(([, a], [, b]) => (a.kind === "super" || a.kind === "sensitive" ? 0 : 1) - (b.kind === "super" || b.kind === "sensitive" ? 0 : 1))
      .map(([action, e]) => `<label class="act-row flex items-center justify-between gap-2 py-1 text-sm border-b border-gray-50 ${e.kind === "sensitive" || e.kind === "super" || actions[action] ? "" : "hidden extra-act"}">
        <span>${escapeHtml(e.label)} <span class="text-xs text-gray-400">${escapeHtml(KIND_LABELS[e.kind] || e.kind)} · ${escapeHtml(e.pages.map((p) => ADMIN_PAGES[p] || p).join(", "))}</span></span>
        <select data-action="${escapeHtml(action)}" class="eff rounded-lg border border-gray-200 px-2 py-1 text-xs">${options(EFFECTS, actions[action] || "", escapeHtml)}</select>
      </label>`).join("");
    modal.innerHTML = `<div class="bg-white rounded-3xl shadow-xl w-full max-w-3xl p-5 my-8">
      <div class="flex items-center justify-between mb-4"><h3 class="font-bold text-lg">${escapeHtml(personName(userId))}</h3>
        <button data-act="modal-close" class="text-gray-400 hover:text-gray-700 text-2xl leading-none">×</button></div>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-3 mb-4">
        <label class="text-sm">ระดับ<select id="mTier" class="mt-1 w-full rounded-xl border border-gray-200 px-3 py-2">${options([["assistant", "ผู้ช่วย"], ["lead", "หัวหน้า"]], s.tier, escapeHtml)}</select></label>
        <label class="text-sm">บทบาท<select id="mTemplate" class="mt-1 w-full rounded-xl border border-gray-200 px-3 py-2">${options([["", "— ไม่มี —"], ...data.templates.map((t) => [t.id, t.name])], s.template_id || "", escapeHtml)}</select></label>
        <label class="text-sm flex items-end gap-2 pb-2"><input id="mActive" type="checkbox" ${s.active ? "checked" : ""}> ใช้งานได้</label>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
        <div><div class="font-semibold text-sm mb-1">สิทธิ์รายหน้า (ทับบทบาท)</div><div class="max-h-[420px] overflow-y-auto pr-1">${levelMatrix(pages, tpl?.page_levels || {})}</div></div>
        <div><div class="flex items-center justify-between mb-1"><span class="font-semibold text-sm">สิทธิ์ราย action</span>
          <button data-act="show-all-actions" class="text-xs text-blue-600">แสดงทั้งหมด</button></div>
          <div class="max-h-[420px] overflow-y-auto pr-1">${actionRows}</div></div>
      </div>
      <div class="flex justify-end gap-2 mt-4"><button data-act="modal-close" class="px-4 py-2 bg-gray-100 rounded-xl text-sm font-semibold">ยกเลิก</button>
        <button data-act="member-save" data-id="${escapeHtml(userId)}" class="px-4 py-2 bg-gray-900 text-white rounded-xl text-sm font-semibold">บันทึก</button></div>
    </div>`;
    modal.classList.remove("hidden");
  };

  const openTemplate = (id) => {
    const t = id ? data.templates.find((x) => x.id === id) : { name: "", description: "", page_levels: {} };
    if (!t) return;
    modal.innerHTML = `<div class="bg-white rounded-3xl shadow-xl w-full max-w-xl p-5 my-8">
      <div class="flex items-center justify-between mb-4"><h3 class="font-bold text-lg">${id ? "แก้ไขบทบาท" : "บทบาทใหม่"}</h3>
        <button data-act="modal-close" class="text-gray-400 hover:text-gray-700 text-2xl leading-none">×</button></div>
      <label class="text-sm block mb-2">ชื่อ<input id="tName" value="${escapeHtml(t.name)}" class="mt-1 w-full rounded-xl border border-gray-200 px-3 py-2"></label>
      <label class="text-sm block mb-3">คำอธิบาย<input id="tDesc" value="${escapeHtml(t.description || "")}" class="mt-1 w-full rounded-xl border border-gray-200 px-3 py-2"></label>
      <div class="font-semibold text-sm mb-1">ระดับรายหน้า</div>
      <div class="max-h-[420px] overflow-y-auto pr-1">${levelMatrix(t.page_levels || {}, null)}</div>
      <div class="flex justify-end gap-2 mt-4"><button data-act="modal-close" class="px-4 py-2 bg-gray-100 rounded-xl text-sm font-semibold">ยกเลิก</button>
        <button data-act="template-save" data-id="${escapeHtml(id || "")}" class="px-4 py-2 bg-gray-900 text-white rounded-xl text-sm font-semibold">บันทึก</button></div>
    </div>`;
    modal.classList.remove("hidden");
  };

  root.querySelector("#teamAddForm").addEventListener("change", (event) => {
    if (event.target.name === "mode") {
      root.querySelectorAll(".team-create-only").forEach((n) => n.classList.toggle("hidden", event.target.value !== "create"));
    }
  });

  root.querySelector("#teamAddForm").addEventListener("submit", async (event) => {
    event.preventDefault();
    const form = new FormData(event.target);
    const mode = form.get("mode");
    const body = {
      action: mode === "create" ? "team_create_account" : "team_add_existing",
      email: String(form.get("email") || "").trim(),
      full_name: String(form.get("full_name") || "").trim(),
      tier: form.get("tier"),
      template_id: form.get("template_id") || null,
    };
    const submit = event.target.querySelector("button");
    submit.disabled = true;
    try {
      const res = await call(body, "เพิ่มเข้าทีมแล้ว");
      if (mode === "create") {
        if (res?.reset_link) showLink(res.reset_link, body.full_name || body.email);
        else showToast(`สร้างบัญชีแล้ว แต่สร้างลิงก์ไม่สำเร็จ: ${res?.link_error || "-"} — กด "ลิงก์ตั้งรหัส" อีกครั้ง`, "error");
      }
      event.target.reset();
      root.querySelectorAll(".team-create-only").forEach((n) => n.classList.add("hidden"));
      await load();
    } catch (e) {
      showToast(`เพิ่มไม่สำเร็จ: ${e?.message || e}`, "error");
    } finally {
      submit.disabled = false;
    }
  });

  root.addEventListener("click", async (event) => {
    const btn = event.target.closest("[data-act]");
    if (!btn) return;
    const id = btn.dataset.id;
    const act = btn.dataset.act;
    if (act === "modal-close") return closeModal();
    if (act === "show-all-actions") {
      modal.querySelectorAll(".extra-act").forEach((n) => n.classList.toggle("hidden"));
      return;
    }
    if (act === "copy-link") {
      const input = root.querySelector("#teamLinkBox input");
      try { await navigator.clipboard.writeText(input.value); showToast("คัดลอกแล้ว", "success"); } catch (_) { input.select(); }
      return;
    }
    if (act === "member-edit") return openMember(id);
    if (act === "template-edit") return openTemplate(id);
    if (act === "template-new") return openTemplate(null);
    if (typeof callAdminAction !== "function") return showToast("ไม่พบ admin action", "error");

    btn.disabled = true;
    try {
      if (act === "member-save") {
        const page_overrides = {};
        modal.querySelectorAll("select.lvl").forEach((sel) => { if (sel.value) page_overrides[sel.dataset.page] = sel.value; });
        const action_overrides = {};
        modal.querySelectorAll("select.eff").forEach((sel) => { if (sel.value) action_overrides[sel.dataset.action] = sel.value; });
        await call({
          action: "team_update",
          user_id: id,
          tier: modal.querySelector("#mTier").value,
          template_id: modal.querySelector("#mTemplate").value || null,
          active: modal.querySelector("#mActive").checked,
          page_overrides,
          action_overrides,
        }, "บันทึกสิทธิ์แล้ว");
        closeModal();
        await load();
      } else if (act === "template-save") {
        const page_levels = {};
        modal.querySelectorAll("select.lvl").forEach((sel) => { if (sel.value && sel.value !== "none") page_levels[sel.dataset.page] = sel.value; });
        await call({
          action: "template_upsert",
          id: id || undefined,
          name: modal.querySelector("#tName").value.trim(),
          description: modal.querySelector("#tDesc").value.trim(),
          page_levels,
        }, "บันทึกบทบาทแล้ว");
        closeModal();
        await load();
      } else if (act === "template-delete") {
        if (!globalThis.confirm("ลบบทบาทนี้? สมาชิกที่ใช้บทบาทนี้จะเหลือแค่สิทธิ์ที่ปรับเฉพาะคน")) return;
        await call({ action: "template_delete", id }, "ลบบทบาทแล้ว");
        await load();
      } else if (act === "member-link") {
        const res = await call({ action: "team_reset_link", user_id: id });
        showLink(res?.reset_link, personName(id));
      } else if (act === "member-remove") {
        if (!globalThis.confirm(`นำ ${personName(id)} ออกจากทีม? บัญชีจะกลับเป็นบัญชีลูกค้าและคำขอที่รออยู่จะถูกยกเลิก`)) return;
        await call({ action: "team_remove", user_id: id }, "นำออกจากทีมแล้ว");
        await load();
      } else if (act === "member-promote") {
        if (!globalThis.confirm(`ตั้ง ${personName(id)} เป็น superadmin? จะได้สิทธิ์ทุกอย่างรวมถึงจัดการทีม`)) return;
        await call({ action: "superadmin_grant", user_id: id }, "ตั้งเป็น superadmin แล้ว");
        await load();
      } else if (act === "super-revoke") {
        if (!globalThis.confirm(`ถอดสิทธิ์ superadmin ของ ${personName(id)}? บัญชีจะกลับเป็นบัญชีลูกค้า`)) return;
        await call({ action: "superadmin_revoke", user_id: id }, "ถอด superadmin แล้ว");
        if (id === currentUserId) {
          globalThis.location.reload();
          return;
        }
        await load();
      }
    } catch (e) {
      showToast(`ไม่สำเร็จ: ${e?.message || e}`, "error");
    } finally {
      btn.disabled = false;
    }
  });

  await load();
}
