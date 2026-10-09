// ทีมแอดมิน: สิทธิ์ของผู้ใช้ปัจจุบันใน admin-web (โหลดจาก RPC my_admin_access)
// ซ่อนเมนู/กันเปิดหน้าเป็นแค่ความสะดวก — สิทธิ์จริงตรวจที่ DB (RLS) และ admin-actions ทุก request
import { normalizeLevel } from "./adminPermissions.js";

// หน้าที่ superadmin เท่านั้น (staff เปิดไม่ได้แม้ตั้งระดับไว้)
export const SUPERADMIN_PAGES = new Set(["settings", "admin_team", "admin_audit"]);

let _access = null;

export function setAdminAccess(access) {
  _access = access && typeof access === "object" ? access : null;
}

export function getAdminAccess() {
  return _access;
}

export function isSuperadmin() {
  return _access?.tier === "superadmin" && _access?.active === true;
}

export function pageLevel(page) {
  if (!_access || _access.active !== true) return "none";
  if (_access.tier === "superadmin") return "approve";
  if (SUPERADMIN_PAGES.has(page)) return "none";
  if (page === "approvals") return "view"; // ทุกคนในทีมเห็นคำขอของตัวเอง
  return normalizeLevel(_access.pages?.[page]);
}

export function canViewPage(page) {
  return pageLevel(page) !== "none";
}

export function firstAllowedPage(candidates) {
  const order = Array.isArray(candidates) && candidates.length ? candidates : [];
  return order.find((page) => canViewPage(page)) || "approvals";
}

/**
 * โหลดสิทธิ์หลังล็อกอิน
 * - role admin + RPC ยังไม่มี (ก่อน apply migration) → ถือเป็น superadmin แบบเดิม
 * - role staff ต้องได้ access ที่ active
 */
export async function loadAdminAccess({ supabase, role }) {
  try {
    const { data, error } = await supabase.rpc("my_admin_access");
    if (error) throw error;
    if (data && data.active === true) {
      setAdminAccess(data);
      return { ok: true, access: data };
    }
    setAdminAccess(null);
    return { ok: false, message: role === "staff" ? "บัญชีทีมแอดมินนี้ถูกระงับหรือยังไม่ได้ตั้งสิทธิ์" : "บัญชีนี้ไม่มีสิทธิ์ Admin" };
  } catch (_) {
    if (role === "admin") {
      const legacy = { tier: "superadmin", active: true, pages: {}, actions: {} };
      setAdminAccess(legacy);
      return { ok: true, access: legacy };
    }
    setAdminAccess(null);
    return { ok: false, message: "โหลดสิทธิ์ทีมแอดมินไม่สำเร็จ" };
  }
}

/** ซ่อนเมนูที่ไม่มีสิทธิ์ + หัวข้อกลุ่มที่ไม่มีเมนูเหลือ */
export function applySidebarAccess(root = globalThis.document) {
  if (!root) return;
  const links = root.querySelectorAll(".sidebar-link[data-page]");
  links.forEach((link) => {
    link.classList.toggle("hidden", !canViewPage(link.dataset.page));
  });
  root.querySelectorAll(".sidebar-section-label").forEach((label) => {
    let node = label.nextElementSibling;
    let anyVisible = false;
    while (node && !node.classList.contains("sidebar-section-label")) {
      if (node.matches?.(".sidebar-link[data-page]") && !node.classList.contains("hidden")) anyVisible = true;
      node = node.nextElementSibling;
    }
    label.classList.toggle("hidden", !anyVisible);
  });
  const badge = root.getElementById?.("adminTierBadge");
  if (badge) {
    const tier = _access?.tier;
    badge.textContent = tier === "superadmin" ? "Superadmin" : tier === "lead" ? "หัวหน้า" : tier === "assistant" ? "ผู้ช่วย" : "";
    badge.classList.toggle("hidden", !tier);
  }
}

export function wireAdminAccessBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  Object.assign(globalThis.__adminWebBridge, {
    loadAdminAccess,
    applySidebarAccess,
    canViewPage,
    firstAllowedPage,
    isSuperadmin,
    getAdminAccess,
    pageLevel,
  });
}
