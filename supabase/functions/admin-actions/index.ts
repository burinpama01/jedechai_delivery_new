// @ts-nocheck
import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import {
  verifyAdmin,
  corsHeaders,
  jsonResponse,
  errorResponse,
  notifyTargets,
} from "../_shared/admin-auth.ts";

// Phase 7: Simple in-memory rate limiter (per admin user)
const _rateLimitMap = new Map<string, { count: number; resetAt: number }>();
const RATE_LIMIT_MAX = 60; // max requests per window
const RATE_LIMIT_WINDOW_MS = 60_000; // 1 minute

function checkRateLimit(adminId: string): boolean {
  const now = Date.now();
  let entry = _rateLimitMap.get(adminId);
  if (!entry || now > entry.resetAt) {
    entry = { count: 0, resetAt: now + RATE_LIMIT_WINDOW_MS };
    _rateLimitMap.set(adminId, entry);
  }
  entry.count++;
  return entry.count <= RATE_LIMIT_MAX;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  // Verify admin authentication
  const authResult = await verifyAdmin(req);
  if (authResult instanceof Response) return authResult;

  const { adminId, supabaseAdmin } = authResult;

  // Phase 7: Rate limit check
  if (!checkRateLimit(adminId)) {
    return errorResponse("Rate limit exceeded. Please wait a moment.", 429);
  }

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return errorResponse("Invalid JSON body");
  }

  const action = body.action as string;
  if (!action) return errorResponse("Missing 'action' field");

  try {
    switch (action) {
      // ─── Driver / Merchant Approval ───
      case "approve_driver":
        return await handleApproveProfile(supabaseAdmin, body, "driver");
      case "reject_driver":
        return await handleRejectProfile(supabaseAdmin, body, "driver");
      case "approve_merchant":
        return await handleApproveProfile(supabaseAdmin, body, "merchant");
      case "reject_merchant":
        return await handleRejectProfile(supabaseAdmin, body, "merchant");

      // ─── User Management ───
      case "suspend_user":
        return await handleSuspendUser(supabaseAdmin, body);
      case "unsuspend_user":
        return await handleUnsuspendUser(supabaseAdmin, body);
      case "delete_user":
        return await handleDeleteUser(supabaseAdmin, body);
      case "set_online_status":
        return await handleSetOnlineStatus(supabaseAdmin, body);

      // ─── Profile Edit ───
      case "edit_driver":
        return await handleEditProfile(supabaseAdmin, body);
      case "edit_merchant":
        return await handleEditMerchant(supabaseAdmin, body);

      // ─── User Creation ───
      case "add_driver":
        return await handleAddUser(supabaseAdmin, body, "driver");
      case "add_merchant":
        return await handleAddUser(supabaseAdmin, body, "merchant");

      // ─── Withdrawal ───
      case "approve_withdrawal":
        return await handleApproveWithdrawal(supabaseAdmin, body);
      case "reject_withdrawal":
        return await handleRejectWithdrawal(supabaseAdmin, body);

      // ─── Topup ───
      case "approve_topup":
        return await handleApproveTopup(supabaseAdmin, body);
      case "reject_topup":
        return await handleRejectTopup(supabaseAdmin, body);

      // ─── Order Reassignment ───
      case "reassign_order":
        return await handleReassignOrder(supabaseAdmin, body);

      // ─── System Config ───
      case "upsert_system_config":
        return await handleUpsertSystemConfig(supabaseAdmin, body);
      case "upsert_system_config_kv":
        return await handleUpsertSystemConfigKV(supabaseAdmin, body);

      // ─── Account Deletion ───
      case "approve_account_deletion":
        return await handleApproveAccountDeletion(supabaseAdmin, body);
      case "reject_account_deletion":
        return await handleRejectAccountDeletion(supabaseAdmin, body);

      // ─── Coupons ───
      case "create_coupon":
        return await handleCreateCoupon(supabaseAdmin, body);
      case "toggle_coupon":
        return await handleToggleCoupon(supabaseAdmin, body);
      case "delete_coupon":
        return await handleDeleteCoupon(supabaseAdmin, body);
      case "update_coupon":
        return await handleUpdateCoupon(supabaseAdmin, body);

      // ─── Menu Management ───
      case "create_menu_item":
        return await handleCreateMenuItem(supabaseAdmin, body);
      case "update_menu_item":
        return await handleUpdateMenuItem(supabaseAdmin, body);
      case "delete_menu_item":
        return await handleDeleteMenuItem(supabaseAdmin, body);
      case "create_menu_option":
        return await handleCreateMenuOption(supabaseAdmin, body);
      case "update_menu_option":
        return await handleUpdateMenuOption(supabaseAdmin, body);
      case "delete_menu_option":
        return await handleDeleteMenuOption(supabaseAdmin, body);
      case "create_menu_option_group":
        return await handleCreateMenuOptionGroup(supabaseAdmin, body);
      case "delete_option_group":
        return await handleDeleteOptionGroup(supabaseAdmin, body);
      case "create_option_group_and_link":
        return await handleCreateOptionGroupAndLink(supabaseAdmin, body);
      case "toggle_link_group":
        return await handleToggleLinkGroup(supabaseAdmin, body);
      case "unlink_option_group":
        return await handleUnlinkOptionGroup(supabaseAdmin, body);

      // ─── Support Tickets ───
      case "update_ticket_status":
        return await handleUpdateTicketStatus(supabaseAdmin, body);
      case "resolve_ticket":
        return await handleResolveTicket(supabaseAdmin, body);

      // ─── Order Management ───
      case "assign_order":
        return await handleAssignOrder(supabaseAdmin, body);
      case "cancel_order":
        return await handleCancelOrder(supabaseAdmin, body);
      case "force_cancel_order":
        return await handleForceCancelOrder(supabaseAdmin, body);
      case "rebroadcast_order":
        return await handleRebroadcastOrder(supabaseAdmin, body);

      // ─── Wallet ───
      case "wallet_adjust":
        return await handleWalletAdjust(supabaseAdmin, body);
      case "manual_topup":
        return await handleManualTopup(supabaseAdmin, body);

      // ─── Withdrawal with Slip ───
      case "approve_withdrawal_with_slip":
        return await handleApproveWithdrawal(supabaseAdmin, body);

      // ─── Banners ───
      case "create_banner":
        return await handleCreateBanner(supabaseAdmin, body);
      case "toggle_banner":
        return await handleToggleBanner(supabaseAdmin, body);
      case "delete_banner":
        return await handleDeleteBanner(supabaseAdmin, body);

      // ─── Fetch User Emails ───
      case "fetch_user_emails":
        return await handleFetchUserEmails(supabaseAdmin);

      default:
        return errorResponse(`Unknown action: ${action}`);
    }
  } catch (e) {
    console.error(`admin-actions error [${action}]:`, e);
    return errorResponse(e.message || "Internal error", 500);
  }
});

// ─── Handlers ───────────────────────────────────────────

async function handleApproveProfile(supabase, body, role: string) {
  const { id } = body;
  if (!id) return errorResponse("Missing 'id'");

  const { error } = await supabase
    .from("profiles")
    .update({
      approval_status: "approved",
      approved_at: new Date().toISOString(),
    })
    .eq("id", id);
  if (error) return errorResponse(error.message);

  const roleLabel = role === "driver" ? "คนขับ" : "ร้านค้า";
  await notifyTargets(supabase, [
    {
      user_id: id,
      title: `✅ บัญชี${roleLabel}ได้รับอนุมัติแล้ว`,
      body:
        role === "driver"
          ? "แอดมินอนุมัติบัญชีคนขับของคุณแล้ว สามารถเริ่มรับงานได้"
          : "แอดมินอนุมัติร้านค้าของคุณแล้ว สามารถเปิดร้านได้",
      type: `admin_approve_${role}`,
      data: { type: `admin_approve_${role}`, user_id: id },
    },
  ]);

  return jsonResponse({ success: true });
}

async function handleRejectProfile(supabase, body, role: string) {
  const { id, reason } = body;
  if (!id) return errorResponse("Missing 'id'");
  if (!reason) return errorResponse("Missing 'reason'");

  const { error } = await supabase
    .from("profiles")
    .update({
      approval_status: "rejected",
      rejection_reason: reason,
    })
    .eq("id", id);
  if (error) return errorResponse(error.message);

  const roleLabel = role === "driver" ? "คนขับ" : "ร้านค้า";
  await notifyTargets(supabase, [
    {
      user_id: id,
      title: `❌ บัญชี${roleLabel}ถูกปฏิเสธ`,
      body: `แอดมินปฏิเสธการอนุมัติบัญชี${roleLabel}: ${reason}`,
      type: `admin_reject_${role}`,
      data: { type: `admin_reject_${role}`, user_id: id, reason },
    },
  ]);

  return jsonResponse({ success: true });
}

async function handleSuspendUser(supabase, body) {
  const { id, reason } = body;
  if (!id) return errorResponse("Missing 'id'");
  if (!reason) return errorResponse("Missing 'reason'");

  const { error } = await supabase
    .from("profiles")
    .update({
      approval_status: "suspended",
      rejection_reason: reason,
      updated_at: new Date().toISOString(),
    })
    .eq("id", id);
  if (error) return errorResponse(error.message);

  await notifyTargets(supabase, [
    {
      user_id: id,
      title: "⛔ บัญชีถูกระงับโดยแอดมิน",
      body: `บัญชีของคุณถูกระงับชั่วคราว: ${reason}`,
      type: "admin_suspend_user",
      data: { type: "admin_suspend_user", user_id: id, reason },
    },
  ]);

  return jsonResponse({ success: true });
}

async function handleUnsuspendUser(supabase, body) {
  const { id } = body;
  if (!id) return errorResponse("Missing 'id'");

  const { error } = await supabase
    .from("profiles")
    .update({
      approval_status: "approved",
      rejection_reason: null,
      updated_at: new Date().toISOString(),
    })
    .eq("id", id);
  if (error) return errorResponse(error.message);

  await notifyTargets(supabase, [
    {
      user_id: id,
      title: "✅ บัญชีถูกปลดระงับแล้ว",
      body: "บัญชีของคุณถูกปลดระงับแล้ว สามารถใช้งานได้ตามปกติ",
      type: "admin_unsuspend_user",
      data: { type: "admin_unsuspend_user", user_id: id },
    },
  ]);

  return jsonResponse({ success: true });
}

async function handleDeleteUser(supabase, body) {
  const { id } = body;
  if (!id) return errorResponse("Missing 'id'");

  // Check not admin
  const { data: profile, error: profileErr } = await supabase
    .from("profiles")
    .select("id, role")
    .eq("id", id)
    .maybeSingle();
  if (profileErr) return errorResponse(profileErr.message);
  if (profile?.role === "admin") {
    return errorResponse("ไม่อนุญาตให้ลบบัญชีแอดมิน", 403);
  }

  // Delete profile
  const { error: delErr } = await supabase
    .from("profiles")
    .delete()
    .eq("id", id);
  if (delErr) return errorResponse(delErr.message);

  // Delete auth user
  const { error: authErr } = await supabase.auth.admin.deleteUser(id);
  if (
    authErr &&
    !String(authErr.message || "").toLowerCase().includes("not found")
  ) {
    return errorResponse(authErr.message);
  }

  return jsonResponse({ success: true });
}

async function handleSetOnlineStatus(supabase, body) {
  const { id, is_online, role } = body;
  if (!id) return errorResponse("Missing 'id'");

  const nowIso = new Date().toISOString();
  const { error } = await supabase
    .from("profiles")
    .update({ is_online: !!is_online, updated_at: nowIso })
    .eq("id", id);
  if (error) return errorResponse(error.message);

  if (role === "driver") {
    const driverPatch: Record<string, unknown> = {
      is_online: !!is_online,
      updated_at: nowIso,
    };
    if (!is_online) driverPatch.is_available = false;

    const { error: locErr } = await supabase
      .from("driver_locations")
      .update(driverPatch)
      .eq("driver_id", id);
    if (locErr) return errorResponse(locErr.message);
  }

  return jsonResponse({ success: true });
}

async function handleEditProfile(supabase, body) {
  const { id, update_data } = body;
  if (!id || !update_data) return errorResponse("Missing 'id' or 'update_data'");

  const { error } = await supabase
    .from("profiles")
    .update(update_data)
    .eq("id", id);
  if (error) return errorResponse(error.message);

  return jsonResponse({ success: true });
}

async function handleEditMerchant(supabase, body) {
  const { id, update_data, system_config_updates } = body;
  if (!id || !update_data) return errorResponse("Missing 'id' or 'update_data'");

  const { error } = await supabase
    .from("profiles")
    .update(update_data)
    .eq("id", id);
  if (error) return errorResponse(error.message);

  // Handle system_config key-value updates for merchant-specific settings
  if (system_config_updates && typeof system_config_updates === "object") {
    for (const [key, value] of Object.entries(system_config_updates)) {
      await supabase
        .from("system_config")
        .upsert(
          { key, value: String(value), updated_at: new Date().toISOString() },
          { onConflict: "key" },
        );
    }
  }

  return jsonResponse({ success: true });
}

async function handleAddUser(supabase, body, role: string) {
  const { email, password, profile_data } = body;
  if (!email || !password) return errorResponse("Missing 'email' or 'password'");

  const { data, error } = await supabase.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { role },
  });
  if (error) return errorResponse(error.message);

  if (data.user) {
    const profilePayload = {
      id: data.user.id,
      role,
      approval_status: "approved",
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
      ...(profile_data || {}),
    };
    await supabase.from("profiles").upsert(profilePayload);

    if (role === "driver") {
      await supabase
        .from("wallets")
        .insert({ user_id: data.user.id, balance: 0 });
    }
  }

  return jsonResponse({ success: true, user_id: data.user?.id });
}

async function handleApproveWithdrawal(supabase, body) {
  const { id, transfer_slip_url } = body;
  if (!id) return errorResponse("Missing 'id'");

  // Fetch request details
  const { data: req, error: reqErr } = await supabase
    .from("withdrawal_requests")
    .select("id, user_id, amount, status")
    .eq("id", id)
    .single();
  if (reqErr) return errorResponse(reqErr.message);
  if (req.status !== "pending") {
    return jsonResponse({ success: false, already_processed: true });
  }

  // Update request status with expected-state guard
  const updatePayload: Record<string, unknown> = {
    status: "completed",
    processed_at: new Date().toISOString(),
  };
  if (transfer_slip_url) updatePayload.transfer_slip_url = transfer_slip_url;

  const { data: updated, error: updateErr } = await supabase
    .from("withdrawal_requests")
    .update(updatePayload)
    .eq("id", id)
    .eq("status", "pending")
    .select("id")
    .maybeSingle();
  if (updateErr) return errorResponse(updateErr.message);
  if (!updated) {
    return jsonResponse({ success: false, already_processed: true });
  }

  await notifyTargets(supabase, [
    {
      user_id: req.user_id,
      title: "✅ อนุมัติถอนเงินแล้ว",
      body: `คำขอถอนเงิน ฿${Math.round(req.amount || 0).toLocaleString()} ได้รับการอนุมัติแล้ว`,
      type: "admin_approve_withdrawal",
      data: {
        type: "admin_approve_withdrawal",
        request_id: id,
        amount: String(req.amount || 0),
      },
    },
  ]);

  return jsonResponse({ success: true });
}

async function handleRejectWithdrawal(supabase, body) {
  const { id, reason } = body;
  if (!id) return errorResponse("Missing 'id'");
  if (!reason) return errorResponse("Missing 'reason'");

  // Fetch request
  const { data: req, error: reqErr } = await supabase
    .from("withdrawal_requests")
    .select("id, user_id, amount, status")
    .eq("id", id)
    .single();
  if (reqErr) return errorResponse(reqErr.message);
  if (req.status !== "pending") {
    return jsonResponse({ success: false, already_processed: true });
  }

  // Refund to wallet (read-then-write for now; Phase 2 will make this atomic via RPC)
  const { data: wallet } = await supabase
    .from("wallets")
    .select("id, balance")
    .eq("user_id", req.user_id)
    .single();
  if (wallet) {
    await supabase
      .from("wallets")
      .update({ balance: (wallet.balance || 0) + req.amount })
      .eq("id", wallet.id);
    await supabase.from("wallet_transactions").insert({
      wallet_id: wallet.id,
      amount: req.amount,
      type: "refund",
      description: `คืนเงินจากคำขอถอนที่ถูกปฏิเสธ: ${reason}`,
    });
  }

  // Update request with expected-state guard
  const { data: updated, error: updateErr } = await supabase
    .from("withdrawal_requests")
    .update({
      status: "rejected",
      admin_note: reason,
      processed_at: new Date().toISOString(),
    })
    .eq("id", id)
    .eq("status", "pending")
    .select("id")
    .maybeSingle();
  if (updateErr) return errorResponse(updateErr.message);
  if (!updated) {
    return jsonResponse({ success: false, already_processed: true });
  }

  await notifyTargets(supabase, [
    {
      user_id: req.user_id,
      title: "❌ ปฏิเสธคำขอถอนเงิน",
      body: `คำขอถอนเงิน ฿${Math.round(req.amount || 0).toLocaleString()} ถูกปฏิเสธ: ${reason}`,
      type: "admin_reject_withdrawal",
      data: {
        type: "admin_reject_withdrawal",
        request_id: id,
        amount: String(req.amount || 0),
        reason,
      },
    },
  ]);

  return jsonResponse({ success: true });
}

async function handleApproveTopup(supabase, body) {
  const { id, user_id, amount } = body;
  if (!id) return errorResponse("Missing 'id'");

  // Fetch request to verify
  const { data: req, error: reqErr } = await supabase
    .from("topup_requests")
    .select("id, user_id, amount, status")
    .eq("id", id)
    .single();
  if (reqErr) return errorResponse(reqErr.message);
  if (req.status !== "pending") {
    return jsonResponse({ success: false, already_processed: true });
  }

  const topupUserId = req.user_id || user_id;
  const topupAmount = req.amount || amount;

  // Get or create wallet
  let { data: wallet } = await supabase
    .from("wallets")
    .select("id, balance")
    .eq("user_id", topupUserId)
    .maybeSingle();
  if (!wallet) {
    const { data: newW } = await supabase
      .from("wallets")
      .insert({ user_id: topupUserId, balance: 0 })
      .select()
      .single();
    wallet = newW;
  }

  if (wallet) {
    await supabase
      .from("wallets")
      .update({ balance: (wallet.balance || 0) + topupAmount })
      .eq("id", wallet.id);
    await supabase.from("wallet_transactions").insert({
      wallet_id: wallet.id,
      amount: topupAmount,
      type: "topup",
      description: `เติมเงินผ่าน Admin (฿${topupAmount})`,
    });
  }

  // Update request with expected-state guard
  const { data: updated, error: updateErr } = await supabase
    .from("topup_requests")
    .update({
      status: "completed",
      processed_at: new Date().toISOString(),
    })
    .eq("id", id)
    .eq("status", "pending")
    .select("id")
    .maybeSingle();
  if (updateErr) return errorResponse(updateErr.message);
  if (!updated) {
    return jsonResponse({ success: false, already_processed: true });
  }

  await notifyTargets(supabase, [
    {
      user_id: topupUserId,
      title: "✅ เติมเงินสำเร็จ",
      body: `คำขอเติมเงิน ฿${Math.round(topupAmount || 0).toLocaleString()} ได้รับการอนุมัติแล้ว`,
      type: "admin_approve_topup",
      data: {
        type: "admin_approve_topup",
        request_id: id,
        amount: String(topupAmount || 0),
      },
    },
  ]);

  return jsonResponse({ success: true });
}

async function handleRejectTopup(supabase, body) {
  const { id, reason } = body;
  if (!id) return errorResponse("Missing 'id'");

  const { data: updated, error } = await supabase
    .from("topup_requests")
    .update({
      status: "rejected",
      admin_note: reason || "",
      processed_at: new Date().toISOString(),
    })
    .eq("id", id)
    .eq("status", "pending")
    .select("id")
    .maybeSingle();
  if (error) return errorResponse(error.message);
  if (!updated) {
    return jsonResponse({ success: false, already_processed: true });
  }

  return jsonResponse({ success: true });
}

async function handleReassignOrder(supabase, body) {
  const { order_id, new_driver_id, update_fields } = body;
  if (!order_id || !new_driver_id)
    return errorResponse("Missing 'order_id' or 'new_driver_id'");

  const { data: booking, error: bookingErr } = await supabase
    .from("bookings")
    .select("id, customer_id, merchant_id, driver_id, service_type, status")
    .eq("id", order_id)
    .single();
  if (bookingErr) return errorResponse(bookingErr.message);

  const previousDriverId = booking.driver_id;
  if (previousDriverId === new_driver_id) {
    return errorResponse("คนขับที่เลือกเป็นคนเดิมของออเดอร์นี้");
  }

  const reassignAt = new Date().toISOString();
  const payload = {
    driver_id: new_driver_id,
    assigned_at: reassignAt,
    ...(update_fields || {}),
  };

  const { error: updateErr } = await supabase
    .from("bookings")
    .update(payload)
    .eq("id", order_id);
  if (updateErr) return errorResponse(updateErr.message);

  const shortId = (order_id || "").substring(0, 8);
  const baseData = {
    type: "admin_reassign",
    booking_id: order_id,
    new_driver_id,
    old_driver_id: previousDriverId || "",
    service_type: booking.service_type || "",
    status_after: payload.status || booking.status || "",
    reassigned_at: reassignAt,
  };

  const notifyRows = [
    {
      user_id: new_driver_id,
      title: "📌 แอดมินมอบหมายงานใหม่",
      body: `คุณได้รับงาน #${shortId} จากแอดมินแล้ว`,
      type: "admin_reassign_new_driver",
      data: { ...baseData, role: "new_driver" },
    },
  ];

  if (previousDriverId && previousDriverId !== new_driver_id) {
    notifyRows.push({
      user_id: previousDriverId,
      title: "🔄 แอดมินย้ายงาน",
      body: `งาน #${shortId} ถูกย้ายไปให้คนขับท่านอื่น`,
      type: "admin_reassign_old_driver",
      data: { ...baseData, role: "old_driver" },
    });
  }

  if (booking.customer_id) {
    notifyRows.push({
      user_id: booking.customer_id,
      title: "🚗 เปลี่ยนคนขับโดยแอดมิน",
      body: `ออเดอร์ #${shortId} มีการมอบหมายคนขับใหม่แล้ว`,
      type: "admin_reassign_customer",
      data: { ...baseData, role: "customer" },
    });
  }

  if (booking.merchant_id && booking.service_type === "food") {
    notifyRows.push({
      user_id: booking.merchant_id,
      title: "🍔 เปลี่ยนคนขับออเดอร์",
      body: `ออเดอร์ #${shortId} มีการเปลี่ยนคนขับโดยแอดมิน`,
      type: "admin_reassign_merchant",
      data: { ...baseData, role: "merchant" },
    });
  }

  await notifyTargets(supabase, notifyRows);

  return jsonResponse({ success: true });
}

async function handleUpsertSystemConfig(supabase, body) {
  const config = body.config_data || body.config;
  if (!config || typeof config !== "object")
    return errorResponse("Missing 'config_data' object");

  const payload = { ...config, updated_at: new Date().toISOString() };

  // Try id-based upsert first, then fallback to column-model update
  try {
    const { data: existing } = await supabase
      .from("system_config")
      .select("id")
      .maybeSingle();
    const configId = existing?.id ?? 1;
    const { error } = await supabase
      .from("system_config")
      .upsert({ id: configId, ...payload }, { onConflict: "id" });
    if (!error) return jsonResponse({ success: true });
  } catch { /* fall through */ }

  // Fallback: update all rows
  const { data: rows, error: updateErr } = await supabase
    .from("system_config")
    .update(payload)
    .select("*");
  if (updateErr) return errorResponse(updateErr.message);
  if ((rows || []).length > 0) return jsonResponse({ success: true });

  const { error: insertErr } = await supabase
    .from("system_config")
    .insert(payload);
  if (insertErr) return errorResponse(insertErr.message);

  return jsonResponse({ success: true });
}

async function handleUpsertSystemConfigKV(supabase, body) {
  const { rows } = body;
  if (!rows || !Array.isArray(rows) || !rows.length)
    return errorResponse("Missing 'rows' array");

  const nowIso = new Date().toISOString();
  for (const row of rows) {
    if (!row.key) continue;
    const { error } = await supabase
      .from("system_config")
      .upsert(
        { key: row.key, value: String(row.value ?? ""), updated_at: nowIso },
        { onConflict: "key" },
      );
    if (error) return errorResponse(`Failed to upsert '${row.key}': ${error.message}`);
  }
  return jsonResponse({ success: true });
}

// ─── Account Deletion ─────────────────────────────────

async function handleApproveAccountDeletion(supabase, body) {
  const { id } = body;
  if (!id) return errorResponse("Missing 'id'");
  const nowIso = new Date().toISOString();
  const { error } = await supabase
    .from("deletion_requests")
    .update({ status: "approved", processed_at: nowIso, updated_at: nowIso })
    .eq("id", id);
  if (error) return errorResponse(error.message);
  return jsonResponse({ success: true });
}

async function handleRejectAccountDeletion(supabase, body) {
  const { id, reason } = body;
  if (!id) return errorResponse("Missing 'id'");
  const nowIso = new Date().toISOString();
  const { error } = await supabase
    .from("deletion_requests")
    .update({ status: "rejected", admin_note: reason || "", processed_at: nowIso, updated_at: nowIso })
    .eq("id", id);
  if (error) return errorResponse(error.message);
  return jsonResponse({ success: true });
}

// ─── Coupons ──────────────────────────────────────────

async function handleCreateCoupon(supabase, body) {
  const { coupon_data } = body;
  if (!coupon_data) return errorResponse("Missing 'coupon_data'");
  const { data, error } = await supabase.from("coupons").insert(coupon_data).select().single();
  if (error) return errorResponse(error.message);
  return jsonResponse({ success: true, coupon: data });
}

async function handleToggleCoupon(supabase, body) {
  const { id, is_active } = body;
  if (!id) return errorResponse("Missing 'id'");
  const { error } = await supabase.from("coupons").update({ is_active }).eq("id", id);
  if (error) return errorResponse(error.message);
  return jsonResponse({ success: true });
}

async function handleDeleteCoupon(supabase, body) {
  const { id } = body;
  if (!id) return errorResponse("Missing 'id'");
  const { error } = await supabase.from("coupons").delete().eq("id", id);
  if (error) return errorResponse(error.message);
  return jsonResponse({ success: true });
}

async function handleUpdateCoupon(supabase, body) {
  const { id, update_data } = body;
  if (!id || !update_data) return errorResponse("Missing 'id' or 'update_data'");
  const { error } = await supabase.from("coupons").update(update_data).eq("id", id);
  if (error) return errorResponse(error.message);
  return jsonResponse({ success: true });
}

// ─── Menu Management ──────────────────────────────────

async function handleCreateMenuItem(supabase, body) {
  const { merchant_id, item_data, option_group_ids } = body;
  if (!merchant_id || !item_data) return errorResponse("Missing 'merchant_id' or 'item_data'");

  const { data: newItem, error } = await supabase
    .from("menu_items")
    .insert({ merchant_id, ...item_data })
    .select()
    .single();
  if (error) return errorResponse(error.message);

  if (newItem && Array.isArray(option_group_ids) && option_group_ids.length > 0) {
    for (let i = 0; i < option_group_ids.length; i++) {
      await supabase.from("menu_item_option_links").insert({
        menu_item_id: newItem.id,
        option_group_id: option_group_ids[i],
        sort_order: i,
      });
    }
  }

  return jsonResponse({ success: true, item: newItem });
}

async function handleUpdateMenuItem(supabase, body) {
  const { id, update_data } = body;
  if (!id || !update_data) return errorResponse("Missing 'id' or 'update_data'");
  const { error } = await supabase.from("menu_items").update(update_data).eq("id", id);
  if (error) return errorResponse(error.message);
  return jsonResponse({ success: true });
}

async function handleDeleteMenuItem(supabase, body) {
  const { id } = body;
  if (!id) return errorResponse("Missing 'id'");
  const { error } = await supabase.from("menu_items").delete().eq("id", id);
  if (error) return errorResponse(error.message);
  return jsonResponse({ success: true });
}

async function handleCreateMenuOption(supabase, body) {
  const { group_id, name, price, is_available } = body;
  if (!group_id || !name) return errorResponse("Missing 'group_id' or 'name'");
  const { data, error } = await supabase
    .from("menu_options")
    .insert({ group_id, name, price: price || 0, is_available: is_available !== false })
    .select()
    .single();
  if (error) return errorResponse(error.message);
  return jsonResponse({ success: true, option: data });
}

async function handleUpdateMenuOption(supabase, body) {
  const { id, update_data } = body;
  if (!id || !update_data) return errorResponse("Missing 'id' or 'update_data'");
  const { error } = await supabase.from("menu_options").update(update_data).eq("id", id);
  if (error) return errorResponse(error.message);
  return jsonResponse({ success: true });
}

async function handleDeleteMenuOption(supabase, body) {
  const { id } = body;
  if (!id) return errorResponse("Missing 'id'");
  const { error } = await supabase.from("menu_options").delete().eq("id", id);
  if (error) return errorResponse(error.message);
  return jsonResponse({ success: true });
}

async function handleCreateMenuOptionGroup(supabase, body) {
  const { merchant_id, name, min_selection, max_selection } = body;
  if (!merchant_id || !name) return errorResponse("Missing 'merchant_id' or 'name'");
  const { data, error } = await supabase
    .from("menu_option_groups")
    .insert({ merchant_id, name, min_selection: min_selection || 0, max_selection: max_selection || 1 })
    .select()
    .single();
  if (error) return errorResponse(error.message);
  return jsonResponse({ success: true, group: data });
}

async function handleDeleteOptionGroup(supabase, body) {
  const { id } = body;
  if (!id) return errorResponse("Missing 'id'");
  // Delete options, links, then the group itself
  await supabase.from("menu_options").delete().eq("group_id", id);
  await supabase.from("menu_item_option_links").delete().eq("option_group_id", id);
  const { error } = await supabase.from("menu_option_groups").delete().eq("id", id);
  if (error) return errorResponse(error.message);
  return jsonResponse({ success: true });
}

async function handleCreateOptionGroupAndLink(supabase, body) {
  const { merchant_id, menu_item_id, name, min_selection, max_selection } = body;
  if (!merchant_id || !menu_item_id || !name)
    return errorResponse("Missing required fields");
  const { data: grp, error } = await supabase
    .from("menu_option_groups")
    .insert({ merchant_id, name, min_selection: min_selection || 0, max_selection: max_selection || 1 })
    .select()
    .single();
  if (error) return errorResponse(error.message);
  if (grp) {
    await supabase.from("menu_item_option_links").insert({
      menu_item_id,
      option_group_id: grp.id,
      sort_order: 0,
    });
  }
  return jsonResponse({ success: true, group: grp });
}

async function handleToggleLinkGroup(supabase, body) {
  const { menu_item_id, option_group_id, link } = body;
  if (!menu_item_id || !option_group_id) return errorResponse("Missing required fields");
  if (link) {
    await supabase.from("menu_item_option_links").insert({
      menu_item_id,
      option_group_id,
      sort_order: 0,
    });
  } else {
    await supabase
      .from("menu_item_option_links")
      .delete()
      .eq("menu_item_id", menu_item_id)
      .eq("option_group_id", option_group_id);
  }
  return jsonResponse({ success: true });
}

async function handleUnlinkOptionGroup(supabase, body) {
  const { menu_item_id, option_group_id } = body;
  if (!menu_item_id || !option_group_id) return errorResponse("Missing required fields");
  const { error } = await supabase
    .from("menu_item_option_links")
    .delete()
    .eq("menu_item_id", menu_item_id)
    .eq("option_group_id", option_group_id);
  if (error) return errorResponse(error.message);
  return jsonResponse({ success: true });
}

// ─── Support Tickets ──────────────────────────────────

async function handleUpdateTicketStatus(supabase, body) {
  const { id, status } = body;
  if (!id || !status) return errorResponse("Missing 'id' or 'status'");
  const { error } = await supabase
    .from("support_tickets")
    .update({ status, updated_at: new Date().toISOString() })
    .eq("id", id);
  if (error) return errorResponse(error.message);
  return jsonResponse({ success: true });
}

async function handleResolveTicket(supabase, body) {
  const { id, resolution } = body;
  if (!id || !resolution) return errorResponse("Missing 'id' or 'resolution'");
  const nowIso = new Date().toISOString();
  const { error } = await supabase
    .from("support_tickets")
    .update({ status: "resolved", resolution, resolved_at: nowIso, updated_at: nowIso })
    .eq("id", id);
  if (error) return errorResponse(error.message);
  return jsonResponse({ success: true });
}

// ─── Order Management ─────────────────────────────────

async function handleAssignOrder(supabase, body) {
  const { order_id, driver_id } = body;
  if (!order_id || !driver_id) return errorResponse("Missing 'order_id' or 'driver_id'");
  const nowIso = new Date().toISOString();
  const { error } = await supabase
    .from("bookings")
    .update({ driver_id, status: "driver_accepted", assigned_at: nowIso, updated_at: nowIso })
    .eq("id", order_id);
  if (error) return errorResponse(error.message);
  return jsonResponse({ success: true });
}

async function handleCancelOrder(supabase, body) {
  const { order_id, reason } = body;
  if (!order_id) return errorResponse("Missing 'order_id'");
  const { error } = await supabase
    .from("bookings")
    .update({ status: "cancelled", cancellation_reason: reason || "", updated_at: new Date().toISOString() })
    .eq("id", order_id);
  if (error) return errorResponse(error.message);
  return jsonResponse({ success: true });
}

async function handleForceCancelOrder(supabase, body) {
  const { order_id, customer_id, price, reason, do_refund } = body;
  if (!order_id) return errorResponse("Missing 'order_id'");

  const { error: cancelErr } = await supabase
    .from("bookings")
    .update({
      status: "cancelled",
      cancellation_reason: "admin_force_cancel: " + (reason || ""),
      updated_at: new Date().toISOString(),
    })
    .eq("id", order_id);
  if (cancelErr) return errorResponse(cancelErr.message);

  if (do_refund && customer_id && price > 0) {
    try {
      let { data: wallet } = await supabase
        .from("wallets")
        .select("id, balance")
        .eq("user_id", customer_id)
        .maybeSingle();
      if (!wallet) {
        const { data: newW } = await supabase
          .from("wallets")
          .insert({ user_id: customer_id, balance: 0 })
          .select()
          .single();
        wallet = newW;
      }
      if (wallet) {
        await supabase
          .from("wallets")
          .update({ balance: (wallet.balance || 0) + price })
          .eq("id", wallet.id);
        await supabase.from("wallet_transactions").insert({
          wallet_id: wallet.id,
          amount: price,
          type: "refund",
          description: `คืนเงินจากยกเลิกออเดอร์ #${(order_id || "").substring(0, 8)} (Admin)`,
        });
      }
    } catch (e) {
      console.error("Refund error:", e);
    }
  }

  return jsonResponse({ success: true });
}

async function handleRebroadcastOrder(supabase, body) {
  const { order_id, service_type } = body;
  if (!order_id) return errorResponse("Missing 'order_id'");
  const resetStatus = service_type === "food" ? "pending_merchant" : "pending";
  const { error } = await supabase
    .from("bookings")
    .update({ driver_id: null, status: resetStatus, assigned_at: null, updated_at: new Date().toISOString() })
    .eq("id", order_id);
  if (error) return errorResponse(error.message);
  return jsonResponse({ success: true });
}

// ─── Wallet ───────────────────────────────────────────

async function handleWalletAdjust(supabase, body) {
  const { user_id, amount, reason } = body;
  if (!user_id || !amount) return errorResponse("Missing 'user_id' or 'amount'");

  let { data: wallet, error: walletErr } = await supabase
    .from("wallets")
    .select("id, balance")
    .eq("user_id", user_id)
    .maybeSingle();
  if (walletErr) return errorResponse(walletErr.message);

  if (!wallet) {
    const { data: newW, error: createErr } = await supabase
      .from("wallets")
      .insert({ user_id, balance: 0 })
      .select("id, balance")
      .single();
    if (createErr) return errorResponse(createErr.message);
    wallet = newW;
  }

  const before = wallet.balance || 0;
  const after = before + amount;

  const { error: updateErr } = await supabase
    .from("wallets")
    .update({ balance: after, updated_at: new Date().toISOString() })
    .eq("id", wallet.id);
  if (updateErr) return errorResponse(updateErr.message);

  const { error: txErr } = await supabase.from("wallet_transactions").insert({
    wallet_id: wallet.id,
    amount,
    type: "admin_adjustment",
    description: `${reason || "Admin adjustment"} (Admin ปรับยอดจาก ฿${Math.round(before)} เป็น ฿${Math.round(after)})`,
  });
  if (txErr) return errorResponse(txErr.message);

  return jsonResponse({ success: true, before, after });
}

async function handleManualTopup(supabase, body) {
  const { user_id, amount, description } = body;
  if (!user_id || !amount) return errorResponse("Missing 'user_id' or 'amount'");

  let { data: wallet } = await supabase
    .from("wallets")
    .select("id, balance")
    .eq("user_id", user_id)
    .maybeSingle();
  if (!wallet) {
    const { data: newW } = await supabase
      .from("wallets")
      .insert({ user_id, balance: 0 })
      .select()
      .single();
    wallet = newW;
  }
  if (!wallet) return errorResponse("ไม่สามารถสร้าง wallet ได้");

  await supabase
    .from("wallets")
    .update({ balance: (wallet.balance || 0) + amount })
    .eq("id", wallet.id);
  await supabase.from("wallet_transactions").insert({
    wallet_id: wallet.id,
    amount,
    type: "topup",
    description: (description || "Admin เติมเงินด้วยมือ") + " (Admin Manual)",
  });

  return jsonResponse({ success: true });
}

// ─── Banners ──────────────────────────────────────────

async function handleCreateBanner(supabase, body) {
  const { banner_data } = body;
  if (!banner_data) return errorResponse("Missing 'banner_data'");

  const { error } = await supabase.from("banners").insert(banner_data);
  if (error) {
    // If column doesn't exist, retry with minimal fields
    if (error.message?.includes("column") || error.code === "42703") {
      const { error: retryErr } = await supabase.from("banners").insert({
        title: banner_data.title || "Banner",
        image_url: banner_data.image_url,
        is_active: true,
        sort_order: 0,
      });
      if (retryErr) return errorResponse(retryErr.message);
    } else {
      return errorResponse(error.message);
    }
  }
  return jsonResponse({ success: true });
}

async function handleToggleBanner(supabase, body) {
  const { id, is_active } = body;
  if (!id) return errorResponse("Missing 'id'");
  const { error } = await supabase.from("banners").update({ is_active }).eq("id", id);
  if (error) return errorResponse(error.message);
  return jsonResponse({ success: true });
}

async function handleDeleteBanner(supabase, body) {
  const { id } = body;
  if (!id) return errorResponse("Missing 'id'");
  const { error } = await supabase.from("banners").delete().eq("id", id);
  if (error) return errorResponse(error.message);
  return jsonResponse({ success: true });
}

// ─── Fetch User Emails ────────────────────────────────

async function handleFetchUserEmails(supabase) {
  const emailMap: Record<string, string> = {};
  let page = 1;
  const perPage = 1000;

  while (true) {
    const {
      data: { users },
      error,
    } = await supabase.auth.admin.listUsers({ page, perPage });
    if (error) return errorResponse(error.message);
    if (!users || users.length === 0) break;

    for (const u of users) {
      if (u.id && u.email) emailMap[u.id] = u.email;
    }
    if (users.length < perPage) break;
    page++;
  }

  return jsonResponse({ success: true, email_map: emailMap });
}
