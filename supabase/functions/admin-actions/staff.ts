// @ts-nocheck
// ทีมแอดมิน P1: คำขออนุมัติ (maker-checker), จัดการทีม/บทบาท, audit log
// ประตูสิทธิ์อยู่ใน index.ts (decideAccess) — ไฟล์นี้ทำงานหลังประตูตัดสินแล้ว
//   team action: เข้ามาได้เฉพาะ superadmin (decideAccess ปฏิเสธ staff เสมอ)
//   approval action: ตรวจสิทธิ์รายคำขอที่นี่ (canDecideApproval)

import { errorResponse, jsonResponse } from "../_shared/admin-auth.ts";
import {
  ACTION_CATALOG,
  ADMIN_PAGES,
  canDecideApproval,
  sanitizeActionOverrides,
  sanitizePageLevels,
  sanitizePageOverrides,
} from "../_shared/admin-permissions.ts";

export interface StaffContext {
  actorId: string;
  access: { tier: string; active: boolean; pages?: Record<string, string>; actions?: Record<string, string> };
  actorName: string;
  supabaseAdmin: any;
}

const MAX_APPROVAL_PAYLOAD_BYTES = 100_000;
const EMAIL_PATTERN = /^[^\s@<>,;]+@[^\s@<>,;]+\.[^\s@<>,;]+$/;
const UUID_PATTERN = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const TARGET_KEYS = [
  "id", "user_id", "driver_id", "merchant_id", "order_id", "booking_id", "request_id",
  "withdrawal_id", "topup_id", "coupon_id", "ticket_id", "review_id", "menu_item_id", "package_id",
];

function adminWebBase(): string {
  return (Deno.env.get("ADMIN_WEB_URL")?.trim() || "https://jdc-delivery.vercel.app/admin")
    .replace(/[?#].*$/, "").replace(/\/admin\/?$/, "").replace(/\/+$/, "");
}

function pickTarget(body: Record<string, unknown>): string | null {
  for (const key of TARGET_KEYS) {
    const value = body?.[key];
    if (typeof value === "string" && value.length <= 80) return `${key}:${value}`;
    if (typeof value === "number") return `${key}:${value}`;
  }
  return null;
}

function labelOf(action: string): string {
  return ACTION_CATALOG[action]?.label || action;
}

// ─── กันยกระดับสิทธิ์ผ่านการแก้โปรไฟล์ ─────────────────
// handler edit_*/add_* ส่ง update_data/profile_data เข้า profiles ด้วย service_role
// (trigger guard_profile_privileged_columns ไม่บังคับ service_role) → ต้องกรองที่นี่
//   privileged = superadmin ทำรายการเอง · false = staff หรือการรันคำขอที่อนุมัติแล้ว (payload มาจากผู้ขอ)

const ALWAYS_STRIPPED = ["id", "admin_permissions", "admin_level", "approved_at", "approved_by", "created_at"];
const NON_PRIVILEGED_STRIPPED = ["rejection_reason"];
const BUSINESS_ROLES = ["customer", "driver", "merchant"];

export async function guardProfileMutation(
  supabaseAdmin,
  action: string,
  body: Record<string, unknown>,
  privileged: boolean,
): Promise<Response | null> {
  if (action === "add_driver" || action === "add_merchant") {
    if (body.profile_data && typeof body.profile_data === "object") {
      const data = { ...(body.profile_data as Record<string, unknown>) };
      for (const key of [...ALWAYS_STRIPPED, "role", "approval_status"]) delete data[key];
      body.profile_data = data;
    }
    return null;
  }
  if (action !== "edit_user" && action !== "edit_driver" && action !== "edit_merchant") return null;

  if (!privileged && body.system_config_updates !== undefined) {
    return errorResponse("Forbidden: การแก้ค่าระบบผ่านหน้าร้านค้าเป็นของ superadmin", 403);
  }
  if (!body.update_data || typeof body.update_data !== "object" || Array.isArray(body.update_data)) return null;
  const data = { ...(body.update_data as Record<string, unknown>) };
  for (const key of ALWAYS_STRIPPED) delete data[key];
  if (!privileged) for (const key of NON_PRIVILEGED_STRIPPED) delete data[key];

  const needsTarget = data.role !== undefined || data.approval_status !== undefined;
  if (needsTarget) {
    const targetId = typeof body.id === "string" ? body.id : "";
    const { data: target } = await supabaseAdmin.from("profiles").select("role, approval_status").eq("id", targetId).maybeSingle();
    if (!target) return errorResponse("ไม่พบบัญชี", 404);

    if (data.role !== undefined && data.role !== target.role) {
      if (!privileged) return errorResponse("Forbidden: เปลี่ยนประเภทบัญชีได้เฉพาะ superadmin", 403);
      if (target.role === "admin" || target.role === "staff" || !BUSINESS_ROLES.includes(String(data.role))) {
        return errorResponse("บัญชีทีมแอดมินจัดการที่หน้า \"ทีมแอดมิน\" เท่านั้น", 403);
      }
    }
    if (data.role === target.role) delete data.role;

    if (data.approval_status !== undefined && data.approval_status !== target.approval_status && !privileged) {
      return errorResponse("Forbidden: เปลี่ยนสถานะอนุมัติ/ระงับ ใช้ปุ่มอนุมัติหรือระงับแทน", 403);
    }
  }
  body.update_data = data;
  return null;
}

// ─── Audit ─────────────────────────────────────────────

export async function writeAudit(
  ctx: StaffContext,
  action: string,
  entry: { pages: string[] } | undefined,
  body: Record<string, unknown>,
  outcome: string,
  extra: { summary?: string; requestId?: string | null; target?: string | null } = {},
) {
  try {
    await ctx.supabaseAdmin.from("admin_audit_log").insert({
      actor_id: ctx.actorId,
      actor_tier: ctx.access?.tier || null,
      action,
      pages: entry?.pages || [],
      target: extra.target ?? pickTarget(body),
      summary: (extra.summary ?? labelOf(action)).slice(0, 1000),
      outcome,
      request_id: extra.requestId ?? null,
    });
  } catch (e) {
    console.warn("admin audit insert failed:", e?.message || e);
  }
}

// ─── แจ้งเตือน ─────────────────────────────────────────

async function notifyUsers(supabaseAdmin, userIds: string[], title: string, body: string, data: Record<string, unknown>) {
  const rows = [...new Set(userIds)].filter(Boolean).map((user_id) => ({
    user_id,
    title,
    body,
    type: "admin_approval",
    data,
    is_read: false,
  }));
  if (!rows.length) return;
  const { error } = await supabaseAdmin.from("notifications").insert(rows);
  if (error) console.warn("approval notifications insert failed:", error.message);
}

async function enqueueExternal(supabaseAdmin, title: string, body: string, data: Record<string, unknown>) {
  const { error } = await supabaseAdmin.from("admin_event_external_queue").insert({
    title,
    body,
    event_type: "admin.approval_requested",
    data,
  });
  if (error) console.warn("approval external queue insert failed:", error.message);
}

// ─── คำขออนุมัติ ──────────────────────────────────────

export async function createApprovalRequest(
  ctx: StaffContext,
  action: string,
  entry: { pages: string[]; label: string } | undefined,
  body: Record<string, unknown>,
): Promise<Response> {
  const payload = { ...body, action };
  const size = new TextEncoder().encode(JSON.stringify(payload)).length;
  if (size > MAX_APPROVAL_PAYLOAD_BYTES) {
    await writeAudit(ctx, action, entry, body, "denied", { summary: "payload ใหญ่เกินสำหรับคำขออนุมัติ" });
    return errorResponse("ข้อมูลใหญ่เกินไปสำหรับคำขออนุมัติ", 413);
  }

  const target = pickTarget(body);
  const summary = `${labelOf(action)}${target ? ` (${target})` : ""}`;
  const { data: request, error } = await ctx.supabaseAdmin
    .from("admin_approval_requests")
    .insert({
      requester_id: ctx.actorId,
      requester_name: ctx.actorName || "",
      action,
      pages: entry?.pages || [],
      payload,
      summary,
    })
    .select("id")
    .single();
  if (error) return errorResponse(`สร้างคำขออนุมัติไม่สำเร็จ: ${error.message}`, 500);

  const { data: approvers } = await ctx.supabaseAdmin.rpc("admin_approvers_for_pages", { p_pages: entry?.pages || [] });
  const approverIds = (approvers || []).map((row) => row.user_id).filter((id) => id && id !== ctx.actorId);
  const title = "คำขออนุมัติใหม่";
  const text = `${ctx.actorName || "ทีมแอดมิน"} ขอ${labelOf(action)}`;
  const data = { admin_page: "approvals", request_id: request.id };
  await notifyUsers(ctx.supabaseAdmin, approverIds, title, text, data);
  await enqueueExternal(ctx.supabaseAdmin, title, text, data);
  await writeAudit(ctx, action, entry, body, "pending_approval", { requestId: request.id, target });

  return jsonResponse({
    success: true,
    pending_approval: true,
    request_id: request.id,
    message: "ส่งคำขออนุมัติแล้ว — รอผู้มีสิทธิ์อนุมัติ",
  });
}

async function readResponseJson(res: Response) {
  try {
    return await res.clone().json();
  } catch (_) {
    return null;
  }
}

export async function runApprovalAction(
  ctx: StaffContext,
  action: string,
  body: Record<string, unknown>,
  runAction: (supabaseAdmin, body: Record<string, unknown>, adminId: string) => Promise<Response>,
): Promise<Response> {
  const requestId = String(body?.request_id || "");
  if (!UUID_PATTERN.test(requestId)) return errorResponse("request_id ไม่ถูกต้อง");

  const { data: request, error } = await ctx.supabaseAdmin
    .from("admin_approval_requests")
    .select("*")
    .eq("id", requestId)
    .maybeSingle();
  if (error) return errorResponse(error.message, 500);
  if (!request) return errorResponse("ไม่พบคำขอ", 404);

  const entry = ACTION_CATALOG[request.action];

  if (action === "approval_cancel") {
    if (request.requester_id !== ctx.actorId && ctx.access?.tier !== "superadmin") {
      return errorResponse("Forbidden: ยกเลิกได้เฉพาะคำขอของตัวเอง", 403);
    }
    const { data: updated } = await ctx.supabaseAdmin
      .from("admin_approval_requests")
      .update({ status: "cancelled", decided_by: ctx.actorId, decided_by_name: ctx.actorName || "", decided_at: new Date().toISOString() })
      .eq("id", requestId)
      .eq("status", "pending")
      .select("id");
    if (!updated?.length) return errorResponse("คำขอนี้ถูกพิจารณาไปแล้ว", 409);
    await writeAudit(ctx, request.action, entry, request.payload || {}, "cancelled", { requestId });
    return jsonResponse({ success: true, status: "cancelled" });
  }

  // approval_decide
  const decision = String(body?.decision || "");
  const note = String(body?.note || "").trim().slice(0, 1000);
  if (decision !== "approve" && decision !== "reject") return errorResponse("decision ต้องเป็น approve หรือ reject");
  if (decision === "reject" && !note) return errorResponse("กรุณาระบุเหตุผลที่ตีกลับ");
  if (!canDecideApproval(ctx.access, request.pages || [], ctx.actorId, request.requester_id)) {
    await writeAudit(ctx, request.action, entry, request.payload || {}, "denied", { requestId, summary: "พยายามพิจารณาคำขอโดยไม่มีสิทธิ์" });
    return errorResponse("Forbidden: ไม่มีสิทธิ์พิจารณาคำขอนี้", 403);
  }
  if (request.status !== "pending") return errorResponse("คำขอนี้ถูกพิจารณาไปแล้ว", 409);
  if (new Date(request.expires_at).getTime() <= Date.now()) {
    await ctx.supabaseAdmin.from("admin_approval_requests").update({ status: "expired" }).eq("id", requestId).eq("status", "pending");
    return errorResponse("คำขอหมดอายุแล้ว", 409);
  }

  const nowIso = new Date().toISOString();
  const nextStatus = decision === "approve" ? "approved" : "rejected";
  // claim แบบมีเงื่อนไข — กันอนุมัติซ้ำ/รันซ้ำเมื่อกดพร้อมกัน
  const { data: claimed, error: claimError } = await ctx.supabaseAdmin
    .from("admin_approval_requests")
    .update({
      status: nextStatus,
      decided_by: ctx.actorId,
      decided_by_name: ctx.actorName || "",
      decision_note: note || null,
      decided_at: nowIso,
    })
    .eq("id", requestId)
    .eq("status", "pending")
    .gt("expires_at", nowIso)
    .select("id");
  if (claimError) return errorResponse(claimError.message, 500);
  if (!claimed?.length) return errorResponse("คำขอนี้ถูกพิจารณาไปแล้ว", 409);

  const requesterData = { admin_page: "approvals", request_id: requestId };
  if (decision === "reject") {
    await notifyUsers(ctx.supabaseAdmin, [request.requester_id], "คำขอถูกตีกลับ", `${labelOf(request.action)}: ${note}`, requesterData);
    await writeAudit(ctx, request.action, entry, request.payload || {}, "rejected", { requestId });
    return jsonResponse({ success: true, status: "rejected" });
  }

  // รัน action เดิมในนามผู้อนุมัติ — ห้ามคำสั่งทีม/คำขอซ้อน
  if (!entry || entry.kind === "team" || entry.kind === "approval") {
    await ctx.supabaseAdmin.from("admin_approval_requests").update({ status: "failed", result: { error: "action_not_allowed" } }).eq("id", requestId);
    return errorResponse("action นี้อนุมัติผ่านคำขอไม่ได้", 400);
  }
  const payload = { ...(request.payload || {}), action: request.action };
  let res: Response;
  try {
    // payload มาจากผู้ขอ — กรองแบบไม่มีสิทธิ์พิเศษเสมอ แม้ผู้อนุมัติเป็น superadmin
    res = (await guardProfileMutation(ctx.supabaseAdmin, request.action, payload, false))
      ?? await runAction(ctx.supabaseAdmin, payload, ctx.actorId);
  } catch (e) {
    res = errorResponse(e?.message || "Internal error", 500);
  }
  const result = await readResponseJson(res);
  const executed = res.ok && result?.success !== false;
  const status = executed ? "executed" : "failed";
  await ctx.supabaseAdmin
    .from("admin_approval_requests")
    .update({ status, result: result ?? { http_status: res.status } })
    .eq("id", requestId);
  await notifyUsers(
    ctx.supabaseAdmin,
    [request.requester_id],
    executed ? "คำขอได้รับอนุมัติแล้ว" : "อนุมัติแล้วแต่ทำรายการไม่สำเร็จ",
    labelOf(request.action),
    requesterData,
  );
  await writeAudit(ctx, request.action, entry, payload, status, { requestId });
  return jsonResponse({ success: executed, status, result });
}

// ─── จัดการทีม (superadmin) ────────────────────────────

async function loadTemplate(supabaseAdmin, templateId: unknown) {
  if (templateId === null || templateId === undefined || templateId === "") return { id: null };
  if (typeof templateId !== "string" || !UUID_PATTERN.test(templateId)) return { error: "template_id ไม่ถูกต้อง" };
  const { data } = await supabaseAdmin.from("admin_role_templates").select("id").eq("id", templateId).maybeSingle();
  if (!data) return { error: "ไม่พบบทบาท" };
  return { id: data.id };
}

function parseTier(value: unknown): "lead" | "assistant" | null {
  return value === "lead" || value === "assistant" ? value : null;
}

async function recoveryLink(supabaseAdmin, email: string) {
  const { data, error } = await supabaseAdmin.auth.admin.generateLink({
    type: "recovery",
    email,
    options: { redirectTo: `${adminWebBase()}/reset-password` },
  });
  if (error) return { error: error.message };
  return { link: data?.properties?.action_link || null };
}

async function replaceOverrides(supabaseAdmin, userId: string, body: Record<string, unknown>) {
  if (body.page_overrides !== undefined) {
    const pages = sanitizePageOverrides(body.page_overrides);
    await supabaseAdmin.from("admin_staff_page_overrides").delete().eq("user_id", userId);
    const rows = Object.entries(pages).map(([page, level]) => ({ user_id: userId, page, level }));
    if (rows.length) {
      const { error } = await supabaseAdmin.from("admin_staff_page_overrides").insert(rows);
      if (error) return error.message;
    }
  }
  if (body.action_overrides !== undefined) {
    const actions = sanitizeActionOverrides(body.action_overrides);
    await supabaseAdmin.from("admin_staff_action_overrides").delete().eq("user_id", userId);
    const rows = Object.entries(actions).map(([action, effect]) => ({ user_id: userId, action, effect }));
    if (rows.length) {
      const { error } = await supabaseAdmin.from("admin_staff_action_overrides").insert(rows);
      if (error) return error.message;
    }
  }
  return null;
}

async function cancelPendingRequestsOf(supabaseAdmin, userId: string) {
  await supabaseAdmin
    .from("admin_approval_requests")
    .update({ status: "cancelled", decision_note: "ผู้ขอถูกนำออกจากทีม", decided_at: new Date().toISOString() })
    .eq("requester_id", userId)
    .eq("status", "pending");
}

async function addStaffRow(ctx: StaffContext, userId: string, body: Record<string, unknown>) {
  const tier = parseTier(body.tier);
  if (!tier) return "tier ต้องเป็น lead หรือ assistant";
  const template = await loadTemplate(ctx.supabaseAdmin, body.template_id);
  if (template.error) return template.error;
  const { error } = await ctx.supabaseAdmin.from("admin_staff").insert({
    user_id: userId,
    tier,
    template_id: template.id,
    active: true,
    note: String(body.note || "").slice(0, 500),
    created_by: ctx.actorId,
  });
  if (error) return error.message;
  return await replaceOverrides(ctx.supabaseAdmin, userId, body);
}

export async function runTeamAction(ctx: StaffContext, action: string, body: Record<string, unknown>): Promise<Response> {
  // decideAccess ปฏิเสธ staff สำหรับ team action อยู่แล้ว — ตรวจซ้ำกันพลาด
  if (ctx.access?.tier !== "superadmin") return errorResponse("Forbidden: superadmin เท่านั้น", 403);
  const sb = ctx.supabaseAdmin;
  const audit = (summary: string, target: string | null) =>
    writeAudit(ctx, action, { pages: [] }, body, "allowed", { summary, target });

  switch (action) {
    case "team_add_existing": {
      const email = String(body.email || "").trim();
      if (!EMAIL_PATTERN.test(email)) return errorResponse("อีเมลไม่ถูกต้อง");
      const { data: rows, error } = await sb.rpc("admin_find_user_by_email", { p_email: email });
      if (error) return errorResponse(error.message, 500);
      const user = rows?.[0];
      if (!user) return errorResponse("ไม่พบบัญชีที่ใช้อีเมลนี้", 404);
      if (user.role === "admin") return errorResponse("บัญชีนี้เป็น superadmin อยู่แล้ว");
      if (user.role === "driver" || user.role === "merchant") {
        return errorResponse("บัญชีคนขับ/ร้านค้าแปลงเป็นทีมแอดมินไม่ได้ — ใช้อีเมลอื่นหรือสร้างบัญชีใหม่");
      }
      if (user.role === "staff") {
        const { data: existing } = await sb.from("admin_staff").select("user_id").eq("user_id", user.id).maybeSingle();
        if (existing) return errorResponse("บัญชีนี้อยู่ในทีมแล้ว");
      }
      const { error: roleError } = await sb.from("profiles")
        .update({ role: "staff", approval_status: "approved", updated_at: new Date().toISOString() })
        .eq("id", user.id);
      if (roleError) return errorResponse(roleError.message, 500);
      const staffError = await addStaffRow(ctx, user.id, body);
      if (staffError) {
        await sb.from("profiles").update({ role: "customer" }).eq("id", user.id);
        return errorResponse(staffError);
      }
      await audit(`เพิ่ม ${user.full_name || email} เข้าทีม (${body.tier})`, `user_id:${user.id}`);
      return jsonResponse({ success: true, user_id: user.id });
    }

    case "team_create_account": {
      const email = String(body.email || "").trim().toLowerCase();
      const fullName = String(body.full_name || "").trim().slice(0, 120);
      if (!EMAIL_PATTERN.test(email)) return errorResponse("อีเมลไม่ถูกต้อง");
      if (!fullName) return errorResponse("กรุณากรอกชื่อ");
      if (!parseTier(body.tier)) return errorResponse("tier ต้องเป็น lead หรือ assistant");
      const template = await loadTemplate(sb, body.template_id);
      if (template.error) return errorResponse(template.error);

      const password = crypto.randomUUID() + crypto.randomUUID();
      const { data: created, error: createError } = await sb.auth.admin.createUser({
        email,
        password,
        email_confirm: true,
        user_metadata: { full_name: fullName },
      });
      if (createError || !created?.user) {
        const msg = String(createError?.message || "");
        if (/already|registered|exists/i.test(msg)) {
          return errorResponse("อีเมลนี้มีบัญชีอยู่แล้ว — ใช้ \"เพิ่มบัญชีเดิม\" แทน");
        }
        return errorResponse(`สร้างบัญชีไม่สำเร็จ: ${msg}`, 500);
      }
      const userId = created.user.id;
      const { error: roleError } = await sb.from("profiles")
        .update({ role: "staff", full_name: fullName, approval_status: "approved", updated_at: new Date().toISOString() })
        .eq("id", userId);
      if (roleError) return errorResponse(roleError.message, 500);
      const staffError = await addStaffRow(ctx, userId, body);
      if (staffError) return errorResponse(staffError);
      const link = await recoveryLink(sb, email);
      await audit(`สร้างบัญชีทีม ${fullName} (${body.tier})`, `user_id:${userId}`);
      return jsonResponse({ success: true, user_id: userId, reset_link: link.link || null, link_error: link.error || null });
    }

    case "team_reset_link": {
      const userId = String(body.user_id || "");
      if (!UUID_PATTERN.test(userId)) return errorResponse("user_id ไม่ถูกต้อง");
      const { data: staff } = await sb.from("admin_staff").select("user_id").eq("user_id", userId).maybeSingle();
      if (!staff) return errorResponse("ไม่ใช่สมาชิกทีม", 404);
      const { data: userData, error } = await sb.auth.admin.getUserById(userId);
      if (error || !userData?.user?.email) return errorResponse("ไม่พบอีเมลของบัญชี", 404);
      const link = await recoveryLink(sb, userData.user.email);
      if (link.error) return errorResponse(link.error, 500);
      await audit("สร้างลิงก์ตั้งรหัสผ่าน", `user_id:${userId}`);
      return jsonResponse({ success: true, reset_link: link.link });
    }

    case "team_update": {
      const userId = String(body.user_id || "");
      if (!UUID_PATTERN.test(userId)) return errorResponse("user_id ไม่ถูกต้อง");
      const { data: staff } = await sb.from("admin_staff").select("*").eq("user_id", userId).maybeSingle();
      if (!staff) return errorResponse("ไม่ใช่สมาชิกทีม", 404);
      const patch: Record<string, unknown> = {};
      if (body.tier !== undefined) {
        const tier = parseTier(body.tier);
        if (!tier) return errorResponse("tier ต้องเป็น lead หรือ assistant");
        patch.tier = tier;
      }
      if (body.template_id !== undefined) {
        const template = await loadTemplate(sb, body.template_id);
        if (template.error) return errorResponse(template.error);
        patch.template_id = template.id;
      }
      if (body.active !== undefined) patch.active = body.active === true;
      if (body.note !== undefined) patch.note = String(body.note || "").slice(0, 500);
      if (Object.keys(patch).length) {
        const { error } = await sb.from("admin_staff").update(patch).eq("user_id", userId);
        if (error) return errorResponse(error.message);
      }
      const overrideError = await replaceOverrides(sb, userId, body);
      if (overrideError) return errorResponse(overrideError);
      if (patch.active === false) await cancelPendingRequestsOf(sb, userId);
      await audit(`แก้ไขสมาชิกทีม: ${Object.keys(patch).concat(
        body.page_overrides !== undefined ? ["สิทธิ์รายหน้า"] : [],
        body.action_overrides !== undefined ? ["สิทธิ์ราย action"] : [],
      ).join(", ") || "ไม่มีการเปลี่ยนแปลง"}`, `user_id:${userId}`);
      return jsonResponse({ success: true });
    }

    case "team_remove": {
      const userId = String(body.user_id || "");
      if (!UUID_PATTERN.test(userId)) return errorResponse("user_id ไม่ถูกต้อง");
      const { data: staff } = await sb.from("admin_staff").select("user_id").eq("user_id", userId).maybeSingle();
      if (!staff) return errorResponse("ไม่ใช่สมาชิกทีม", 404);
      await cancelPendingRequestsOf(sb, userId);
      const { error: delError } = await sb.from("admin_staff").delete().eq("user_id", userId);
      if (delError) return errorResponse(delError.message, 500);
      const { error } = await sb.from("profiles").update({ role: "customer", updated_at: new Date().toISOString() }).eq("id", userId);
      if (error) return errorResponse(error.message, 500);
      await audit("นำออกจากทีม (กลับเป็นบัญชีลูกค้า)", `user_id:${userId}`);
      return jsonResponse({ success: true });
    }

    case "superadmin_grant": {
      const userId = String(body.user_id || "");
      if (!UUID_PATTERN.test(userId)) return errorResponse("user_id ไม่ถูกต้อง");
      const { data: profile } = await sb.from("profiles").select("role, full_name").eq("id", userId).maybeSingle();
      if (!profile) return errorResponse("ไม่พบบัญชี", 404);
      if (profile.role === "admin") return errorResponse("เป็น superadmin อยู่แล้ว");
      if (profile.role !== "staff" && profile.role !== "customer") {
        return errorResponse("แต่งตั้งได้เฉพาะสมาชิกทีมหรือบัญชีลูกค้า");
      }
      await cancelPendingRequestsOf(sb, userId);
      await sb.from("admin_staff").delete().eq("user_id", userId);
      const { error } = await sb.from("profiles")
        .update({ role: "admin", approval_status: "approved", updated_at: new Date().toISOString() })
        .eq("id", userId);
      if (error) return errorResponse(error.message, 500);
      await audit(`แต่งตั้ง ${profile.full_name || ""} เป็น superadmin`, `user_id:${userId}`);
      return jsonResponse({ success: true });
    }

    case "superadmin_revoke": {
      const userId = String(body.user_id || "");
      if (!UUID_PATTERN.test(userId)) return errorResponse("user_id ไม่ถูกต้อง");
      const { data: profile } = await sb.from("profiles").select("role, full_name").eq("id", userId).maybeSingle();
      if (!profile || profile.role !== "admin") return errorResponse("บัญชีนี้ไม่ใช่ superadmin", 404);
      const { error } = await sb.from("profiles").update({ role: "customer", updated_at: new Date().toISOString() }).eq("id", userId);
      if (error) {
        if (/last_superadmin/.test(error.message)) return errorResponse("ต้องเหลือ superadmin อย่างน้อย 1 คน");
        return errorResponse(error.message, 500);
      }
      await audit(`ถอด ${profile.full_name || ""} จาก superadmin`, `user_id:${userId}`);
      return jsonResponse({ success: true });
    }

    case "template_upsert": {
      const name = String(body.name || "").trim();
      if (!name || name.length > 80) return errorResponse("ชื่อบทบาทต้องมี 1–80 ตัวอักษร");
      const row = {
        name,
        description: String(body.description || "").slice(0, 500),
        page_levels: sanitizePageLevels(body.page_levels),
        updated_at: new Date().toISOString(),
        updated_by: ctx.actorId,
      };
      let result;
      if (body.id) {
        if (typeof body.id !== "string" || !UUID_PATTERN.test(body.id)) return errorResponse("id ไม่ถูกต้อง");
        result = await sb.from("admin_role_templates").update(row).eq("id", body.id).select("id").maybeSingle();
      } else {
        result = await sb.from("admin_role_templates").insert(row).select("id").single();
      }
      if (result.error) {
        if (/duplicate|unique/i.test(result.error.message)) return errorResponse("มีบทบาทชื่อนี้แล้ว");
        return errorResponse(result.error.message);
      }
      if (!result.data) return errorResponse("ไม่พบบทบาท", 404);
      await audit(`บันทึกบทบาท "${name}"`, `template:${result.data.id}`);
      return jsonResponse({ success: true, id: result.data.id });
    }

    case "template_delete": {
      const id = String(body.id || "");
      if (!UUID_PATTERN.test(id)) return errorResponse("id ไม่ถูกต้อง");
      const { data: template } = await sb.from("admin_role_templates").select("name, is_system").eq("id", id).maybeSingle();
      if (!template) return errorResponse("ไม่พบบทบาท", 404);
      if (template.is_system) return errorResponse("บทบาทตั้งต้นของระบบลบไม่ได้ (แก้ไขได้)");
      const { error } = await sb.from("admin_role_templates").delete().eq("id", id);
      if (error) return errorResponse(error.message);
      await audit(`ลบบทบาท "${template.name}"`, `template:${id}`);
      return jsonResponse({ success: true });
    }
  }

  return errorResponse(`Unknown team action: ${action}`);
}

export const STAFF_PAGES = ADMIN_PAGES;
