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

function withCors(res: Response) {
  const headers = new Headers(res.headers);
  for (const [k, v] of Object.entries(corsHeaders)) {
    if (!headers.has(k)) headers.set(k, v);
  }
  return new Response(res.body, {
    status: res.status,
    statusText: res.statusText,
    headers,
  });
}

serve(async (req) => {
  try {
    if (req.method === "OPTIONS") {
      return withCors(new Response(null, { status: 204, headers: corsHeaders }));
    }

    if (req.method !== "POST") {
      return withCors(errorResponse("Method not allowed", 405));
    }

    // Verify admin authentication
    const authResult = await verifyAdmin(req);
    if (authResult instanceof Response) return withCors(authResult);

    const { adminId, supabaseAdmin } = authResult;

    // Phase 7: Rate limit check
    if (!checkRateLimit(adminId)) {
      return withCors(errorResponse("Rate limit exceeded. Please wait a moment.", 429));
    }

    let body: Record<string, unknown>;
    try {
      body = await req.json();
    } catch {
      return withCors(errorResponse("Invalid JSON body"));
    }

    const action = body.action as string;
    if (!action) return withCors(errorResponse("Missing 'action' field"));

    let result: Response;
    switch (action) {
      // ─── Driver / Merchant Approval ───
      case "approve_driver":
        result = await handleApproveProfile(supabaseAdmin, body, "driver");
        break;
      case "reject_driver":
        result = await handleRejectProfile(supabaseAdmin, body, "driver");
        break;
      case "approve_merchant":
        result = await handleApproveProfile(supabaseAdmin, body, "merchant");
        break;
      case "reject_merchant":
        result = await handleRejectProfile(supabaseAdmin, body, "merchant");
        break;

      // ─── User Management ───
      case "suspend_user":
        result = await handleSuspendUser(supabaseAdmin, body);
        break;
      case "unsuspend_user":
        result = await handleUnsuspendUser(supabaseAdmin, body);
        break;
      case "delete_user":
        result = await handleDeleteUser(supabaseAdmin, body);
        break;
      case "set_online_status":
        result = await handleSetOnlineStatus(supabaseAdmin, body);
        break;

      // ─── Profile Edit ───
      case "edit_driver":
        result = await handleEditProfile(supabaseAdmin, body);
        break;
      case "edit_merchant":
        result = await handleEditMerchant(supabaseAdmin, body);
        break;
      case "edit_user":
        result = await handleEditUser(supabaseAdmin, body);
        break;

      // ─── User Creation ───
      case "add_driver":
        result = await handleAddUser(supabaseAdmin, body, "driver");
        break;
      case "add_merchant":
        result = await handleAddUser(supabaseAdmin, body, "merchant");
        break;

      // ─── Withdrawal ───
      case "approve_withdrawal":
        result = await handleApproveWithdrawal(supabaseAdmin, body);
        break;
      case "reject_withdrawal":
        result = await handleRejectWithdrawal(supabaseAdmin, body);
        break;

      // ─── Topup ───
      case "approve_topup":
        result = await handleApproveTopup(supabaseAdmin, body);
        break;
      case "reject_topup":
        result = await handleRejectTopup(supabaseAdmin, body);
        break;
      case "get_topup_slip_url":
        result = await handleGetTopupSlipUrl(supabaseAdmin, body);
        break;

      // ─── Order Reassignment ───
      case "reassign_order":
        result = await handleReassignOrder(supabaseAdmin, body);
        break;

      case "toggle_shop_status":
        result = await handleToggleShopStatus(supabaseAdmin, body);
        break;

      // ─── System Config ───
      case "upsert_system_config":
        result = await handleUpsertSystemConfig(supabaseAdmin, body);
        break;
      case "upsert_system_config_kv":
        result = await handleUpsertSystemConfigKV(supabaseAdmin, body);
        break;

      // ─── Account Deletion ───
      case "approve_account_deletion":
        result = await handleApproveAccountDeletion(supabaseAdmin, body);
        break;
      case "reject_account_deletion":
        result = await handleRejectAccountDeletion(supabaseAdmin, body, adminId);
        break;
      case "approve_deletion":
        result = await handleApproveAccountDeletion(supabaseAdmin, body);
        break;
      case "reject_deletion":
        result = await handleRejectAccountDeletion(supabaseAdmin, body, adminId);
        break;

      // ─── Coupons ───
      case "create_coupon":
        result = await handleCreateCoupon(supabaseAdmin, body);
        break;
      case "toggle_coupon":
        result = await handleToggleCoupon(supabaseAdmin, body);
        break;
      case "delete_coupon":
        result = await handleDeleteCoupon(supabaseAdmin, body);
        break;
      case "update_coupon":
        result = await handleUpdateCoupon(supabaseAdmin, body);
        break;

      // ─── Menu Management ───
      case "create_menu_item":
        result = await handleCreateMenuItem(supabaseAdmin, body);
        break;
      case "update_menu_item":
        result = await handleUpdateMenuItem(supabaseAdmin, body);
        break;
      case "delete_menu_item":
        result = await handleDeleteMenuItem(supabaseAdmin, body);
        break;
      case "create_menu_option":
        result = await handleCreateMenuOption(supabaseAdmin, body);
        break;
      case "update_menu_option":
        result = await handleUpdateMenuOption(supabaseAdmin, body);
        break;
      case "delete_menu_option":
        result = await handleDeleteMenuOption(supabaseAdmin, body);
        break;
      case "create_menu_option_group":
        result = await handleCreateMenuOptionGroup(supabaseAdmin, body);
        break;
      case "delete_option_group":
        result = await handleDeleteOptionGroup(supabaseAdmin, body);
        break;
      case "create_option_group_and_link":
        result = await handleCreateOptionGroupAndLink(supabaseAdmin, body);
        break;
      case "toggle_link_group":
        result = await handleToggleLinkGroup(supabaseAdmin, body);
        break;
      case "unlink_option_group":
        result = await handleUnlinkOptionGroup(supabaseAdmin, body);
        break;

      // ─── Support Tickets ───
      case "update_ticket_status":
        result = await handleUpdateTicketStatus(supabaseAdmin, body);
        break;
      case "resolve_ticket":
        result = await handleResolveTicket(supabaseAdmin, body);
        break;

      // ─── Order Management ───
      case "accept_order_as_merchant":
        result = await handleAcceptOrderAsMerchant(supabaseAdmin, body, adminId);
        break;
      case "assign_order":
        result = await handleAssignOrder(supabaseAdmin, body);
        break;
      case "cancel_order":
        result = await handleCancelOrder(supabaseAdmin, body);
        break;
      case "force_cancel_order":
        result = await handleForceCancelOrder(supabaseAdmin, body);
        break;
      case "rebroadcast_order":
        result = await handleRebroadcastOrder(supabaseAdmin, body);
        break;
      case "edit_order_items":
        result = await handleEditOrderItems(supabaseAdmin, body);
        break;

      // ─── Wallet ───
      case "wallet_adjust":
        result = await handleWalletAdjust(supabaseAdmin, body);
        break;
      case "manual_topup":
        result = await handleManualTopup(supabaseAdmin, body);
        break;

      // ─── Withdrawal with Slip ───
      case "approve_withdrawal_with_slip":
        result = await handleApproveWithdrawal(supabaseAdmin, body);
        break;

      // ─── Banners ───
      case "create_banner":
        result = await handleCreateBanner(supabaseAdmin, body);
        break;
      case "toggle_banner":
        result = await handleToggleBanner(supabaseAdmin, body);
        break;
      case "delete_banner":
        result = await handleDeleteBanner(supabaseAdmin, body);
        break;

      // ─── Fetch User Emails ───
      case "fetch_user_emails":
        result = await handleFetchUserEmails(supabaseAdmin);
        break;

      default:
        result = errorResponse(`Unknown action: ${action}`);
        break;
    }
    return withCors(result);
  } catch (e) {
    console.error(`admin-actions error [${action}]:`, e);
    return withCors(errorResponse(e?.message || "Internal error", 500));
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

  if (update_data.driver_delivery_system_rate !== undefined) {
    const rawRate = update_data.driver_delivery_system_rate;
    if (rawRate === null || rawRate === "") {
      update_data.driver_delivery_system_rate = null;
    } else {
      const rate = Number(rawRate);
      if (!Number.isFinite(rate) || rate < 0 || rate > 1) {
        return errorResponse("driver_delivery_system_rate must be between 0 and 1");
      }
      update_data.driver_delivery_system_rate = rate;
    }
  }

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

  // Sync is_online with shop_status if shop_status is provided
  if (update_data.shop_status !== undefined) {
    update_data.is_online = update_data.shop_status;
  }

  const { error } = await supabase
    .from("profiles")
    .update(update_data)
    .eq("id", id);
  if (error) return errorResponse(error.message);

  // Handle system_config key-value updates for merchant-specific settings
  if (system_config_updates && typeof system_config_updates === "object") {
    for (const [key, value] of Object.entries(system_config_updates)) {
      const { error } = await upsertSystemConfigKeyValue(supabase, key, value);
      if (error) return errorResponse(`Failed to save '${key}': ${error.message}`);
    }
  }

  return jsonResponse({ success: true });
}

async function handleEditUser(supabase, body) {
  const { original_role } = body;
  if (original_role === "merchant") {
    return await handleEditMerchant(supabase, body);
  }
  return await handleEditProfile(supabase, body);
}

async function handleToggleShopStatus(supabase, body) {
  const { id, make_open } = body;
  if (!id) return errorResponse("Missing 'id'");

  const nowIso = new Date().toISOString();
  const { error } = await supabase
    .from("profiles")
    .update({ shop_status: !!make_open, is_online: !!make_open, updated_at: nowIso })
    .eq("id", id);
  if (error) return errorResponse(error.message);

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

  const { data: result, error: rpcErr } = await supabase.rpc(
    "complete_topup_request",
    {
      p_request_id: id,
      p_description: null,
      p_admin_note: "Admin approved topup",
    },
  );
  if (rpcErr) return errorResponse(rpcErr.message);
  if (result?.success !== true) {
    if (result?.error === "already_processed") {
      return jsonResponse({
        success: false,
        already_processed: true,
        current_status: result.current_status,
      });
    }
    return errorResponse(result?.error ?? "approve_topup_failed");
  }

  const topupUserId = result.user_id || user_id;
  const topupAmount = Number(result.amount || amount || 0);

  if (!topupUserId) {
    return errorResponse("approve_topup returned no user_id");
  }
  if (!Number.isFinite(topupAmount) || topupAmount <= 0) {
    return errorResponse("approve_topup returned invalid amount");
  }

  if (result?.already_processed) {
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

  return jsonResponse({ success: true, wallet: result.wallet });
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

async function handleGetTopupSlipUrl(supabase, body) {
  const { path } = body;
  if (!path || typeof path !== "string") {
    return errorResponse("Missing 'path'");
  }
  if (!path.startsWith("topup-slips/")) {
    return errorResponse("Invalid topup slip path", 400);
  }

  const { data, error } = await supabase.storage
    .from("topup-slips")
    .createSignedUrl(path, 300);
  if (error) return errorResponse(error.message, 500);

  return jsonResponse({
    success: true,
    signed_url: data?.signedUrl ?? null,
    expires_in: 300,
  });
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

  const { error } = await supabase
    .from("system_config")
    .upsert({ id: 1, ...config }, { onConflict: "id" });

  if (error) return errorResponse(error.message);
  return jsonResponse({ success: true });
}

async function handleUpsertSystemConfigKV(supabase, body) {
  const { rows } = body;
  if (!rows || !Array.isArray(rows) || !rows.length)
    return errorResponse("Missing 'rows' array");

  for (const row of rows) {
    if (!row.key) continue;
    const { error } = await upsertSystemConfigKeyValue(supabase, row.key, row.value);
    if (error) return errorResponse(`Failed to save '${row.key}': ${error.message}`);
  }
  return jsonResponse({ success: true });
}

async function upsertSystemConfigKeyValue(supabase, key: string, value: unknown) {
  const nowIso = new Date().toISOString();
  const payload = { value: String(value ?? ""), updated_at: nowIso };

  const { data: updated, error: updateError } = await supabase
    .from("system_config")
    .update(payload)
    .eq("key", key)
    .select("key");
  if (updateError) return { error: updateError };
  if ((updated || []).length > 0) return { error: null };

  const { error: insertError } = await supabase
    .from("system_config")
    .insert({ key, ...payload });
  return { error: insertError };
}

// ─── Account Deletion ─────────────────────────────────

async function handleApproveAccountDeletion(supabase, body) {
  const { id } = body;
  if (!id) return errorResponse("Missing 'id'");

  // Fetch the request to get user_id
  const nowIso = new Date().toISOString();

  // Update request status guarded by expected state, and fetch target user in one round trip.
  const { data: updatedRows, error: reqErr } = await supabase
    .from("account_deletion_requests")
    .update({ status: "approved", reviewed_at: nowIso })
    .eq("id", id)
    .eq("status", "pending")
    .select("user_id");
  if (reqErr) return errorResponse(reqErr.message);
  if (!updatedRows?.length) return errorResponse("Request is not pending or not found");

  const targetUserId = updatedRows[0].user_id as string;

  // Mark profile as approved for deletion
  await supabase
    .from("profiles")
    .update({ deletion_status: "approved" })
    .eq("id", targetUserId);

  // Delete the auth user (this invalidates all active sessions)
  const { error: authErr } = await supabase.auth.admin.deleteUser(targetUserId);
  if (
    authErr &&
    !String(authErr.message || "").toLowerCase().includes("not found")
  ) {
    return errorResponse(`Auth user deletion failed: ${authErr.message}`);
  }

  return jsonResponse({ success: true });
}

async function handleRejectAccountDeletion(supabase, body, adminId) {
  const { id, reason } = body;
  if (!id) return errorResponse("Missing 'id'");

  const { data, error } = await supabase.rpc("reject_account_deletion_guarded", {
    p_request_id: String(id),
    p_admin_id: adminId,
    p_reason: reason || "",
  });
  if (error) return errorResponse(error.message);

  return jsonResponse(data || { success: true });
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

async function notifyCancelParticipants(supabase, orderId: string, isForce: boolean) {
  try {
    const { data: booking } = await supabase
      .from("bookings")
      .select("customer_id, driver_id, merchant_id, service_type")
      .eq("id", orderId)
      .maybeSingle();
    if (!booking) return;

    const title = isForce ? "ออเดอร์ถูกยกเลิกโดย Admin" : "ออเดอร์ถูกยกเลิก";
    const body = "ออเดอร์ #" + orderId.substring(0, 8) + " ถูกยกเลิกแล้ว";
    const targets = [booking.customer_id, booking.driver_id];
    if (booking.service_type === "food") targets.push(booking.merchant_id);

    const rows = targets
      .filter(Boolean)
      .map((uid) => ({ user_id: uid, title, body, type: "order.cancelled", data: { order_id: orderId } }));
    await notifyTargets(supabase, rows);
  } catch (e) {
    console.warn("Failed to notify cancel participants:", e);
  }
}

async function handleCancelOrder(supabase, body) {
  const { order_id, reason } = body;
  if (!order_id) return errorResponse("Missing 'order_id'");
  const { error } = await supabase
    .from("bookings")
    .update({ status: "cancelled", cancellation_reason: reason || "", updated_at: new Date().toISOString() })
    .eq("id", order_id);
  if (error) return errorResponse(error.message);
  await notifyCancelParticipants(supabase, order_id, false);
  return jsonResponse({ success: true });
}

async function handleForceCancelOrder(supabase, body) {
  const { order_id, reason, do_refund } = body;
  if (!order_id) return errorResponse("Missing 'order_id'");

  const { data: result, error } = await supabase.rpc("admin_force_cancel_booking_with_wallet_refund", {
    p_booking_id: order_id,
    p_reason: reason || "",
    p_do_refund: Boolean(do_refund),
  });
  if (error) return errorResponse(error.message);

  const payload = Array.isArray(result) ? result[0] : result;
  if (payload?.success !== true) {
    return errorResponse(payload?.message || payload?.error || "force_cancel_order_failed");
  }

  await notifyCancelParticipants(supabase, order_id, true);
  return jsonResponse(payload);
}

async function handleAcceptOrderAsMerchant(supabase, body, adminId: string) {
  const { order_id, admin_note } = body;
  if (!order_id) return errorResponse("Missing 'order_id'");

  const { data: booking, error: bookingErr } = await supabase
    .from("bookings")
    .select("id, status, service_type, merchant_id, customer_id, driver_id")
    .eq("id", order_id)
    .maybeSingle();
  if (bookingErr) return errorResponse(bookingErr.message);
  if (!booking) return errorResponse("Booking not found", 404);
  if (booking.service_type !== "food") return errorResponse("Only food orders can be accepted on behalf of merchant");

  const allowedStatuses = ["pending_merchant", "pending"];
  if (!allowedStatuses.includes(booking.status)) {
    return errorResponse(`Cannot accept order with status '${booking.status}'. Expected: ${allowedStatuses.join(", ")}`);
  }

  const { data: updatedRows, error: updateErr } = await supabase
    .from("bookings")
    .update({
      status: "preparing",
      admin_note: String(admin_note || "").trim() || null,
      updated_at: new Date().toISOString(),
    })
    .eq("id", order_id)
    .in("status", allowedStatuses)
    .select("id, status");
  if (updateErr) return errorResponse(updateErr.message);
  if (!updatedRows || updatedRows.length === 0) {
    return errorResponse("Order status changed before accept. Please refresh.");
  }

  const notifications = [];
  if (booking.merchant_id) {
    notifications.push({
      user_id: booking.merchant_id,
      title: "🛠️ แอดมินรับออเดอร์แทนร้าน",
      body: `ออเดอร์ #${String(order_id).substring(0, 8)} ถูกแอดมินรับแทน`,
      type: "admin_accept_as_merchant",
      data: { type: "admin_accept_as_merchant", booking_id: order_id },
    });
  }
  if (booking.customer_id) {
    notifications.push({
      user_id: booking.customer_id,
      title: "✅ ออเดอร์กำลังถูกเตรียม",
      body: `ออเดอร์ #${String(order_id).substring(0, 8)} ได้รับการยืนยันแล้ว`,
      type: "order_accepted_by_admin",
      data: { type: "order_accepted_by_admin", booking_id: order_id },
    });
  }
  if (notifications.length) {
    const { error: notifyErr } = await supabase.from("notifications").insert(notifications);
    if (notifyErr) console.error("accept_order_as_merchant notification error:", notifyErr);
  }

  return jsonResponse({ success: true, status: "preparing", booking_id: order_id });
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

async function handleEditOrderItems(supabase, body) {
  const { booking_id, new_items, admin_note } = body;
  if (!booking_id) return errorResponse("Missing 'booking_id'");
  if (!Array.isArray(new_items) || new_items.length === 0) {
    return errorResponse("new_items must contain at least one item");
  }

  const { data: booking, error: bookingErr } = await supabase
    .from("bookings")
    .select("id, status, service_type, merchant_id, customer_id, payment_method, price")
    .eq("id", booking_id)
    .maybeSingle();
  if (bookingErr) return errorResponse(bookingErr.message);
  if (!booking) return errorResponse("Booking not found", 404);
  if (booking.service_type !== "food") return errorResponse("Only food orders can edit items");
  if (!["pending_merchant", "accepted", "preparing"].includes(booking.status)) {
    return errorResponse("Order status cannot edit items");
  }

  const normalizedItems = new_items.map((item) => ({
    booking_id,
    menu_item_id: item.menu_item_id || null,
    name: String(item.name || item.menu_name || "").trim(),
    quantity: Math.max(1, Number.parseInt(item.quantity || 1, 10) || 1),
    price: Number(item.price || 0) || 0,
    selected_options: item.selected_options || [],
    options: item.options || [],
    note: String(item.note || "").trim() || null,
  }));

  if (normalizedItems.some((item) => !item.menu_item_id)) return errorResponse("menu_item_id is required");
  if (normalizedItems.some((item) => !item.name)) return errorResponse("item name is required");
  if (normalizedItems.some((item) => item.price < 0)) return errorResponse("item price is invalid");

  const menuIds = [...new Set(normalizedItems.map((item) => item.menu_item_id))];
  const { data: menuRows, error: menuErr } = await supabase
    .from("menu_items")
    .select("id, merchant_id")
    .in("id", menuIds);
  if (menuErr) return errorResponse(menuErr.message);
  if ((menuRows || []).length !== menuIds.length) return errorResponse("Some menu items were not found");
  if ((menuRows || []).some((item) => item.merchant_id !== booking.merchant_id)) {
    return errorResponse("Menu item merchant mismatch");
  }

  const originalPrice = Number(booking.price || 0) || 0;
  const newFoodTotal = normalizedItems.reduce((sum, item) => sum + (item.price * item.quantity), 0);
  const priceDiff = Math.round(newFoodTotal - originalPrice);

  if (String(booking.payment_method || "").toLowerCase() === "wallet" && priceDiff > 0) {
    const { data: wallet, error: walletErr } = await supabase
      .from("wallets")
      .select("id, balance")
      .eq("user_id", booking.customer_id)
      .maybeSingle();
    if (walletErr) return errorResponse(walletErr.message);
    if (!wallet || Number(wallet.balance || 0) < priceDiff) return errorResponse("Insufficient wallet balance");
  }

  const { error: deleteErr } = await supabase
    .from("booking_items")
    .delete()
    .eq("booking_id", booking_id);
  if (deleteErr) return errorResponse(deleteErr.message);

  const { error: insertErr } = await supabase.from("booking_items").insert(normalizedItems);
  if (insertErr) return errorResponse(insertErr.message);

  const { error: updateErr } = await supabase
    .from("bookings")
    .update({
      price: newFoodTotal,
      admin_note: String(admin_note || "").trim() || null,
      updated_at: new Date().toISOString(),
    })
    .eq("id", booking_id);
  if (updateErr) return errorResponse(updateErr.message);

  const paymentMethod = String(booking.payment_method || "").toLowerCase();
  if (paymentMethod === "wallet" && priceDiff < 0) {
    const { error: refundErr } = await supabase.rpc("wallet_topup", {
      p_user_id: booking.customer_id,
      p_amount: Math.abs(priceDiff),
      p_note: "order_item_edit_refund",
      p_ref_id: booking_id,
    });
    if (refundErr) return errorResponse(refundErr.message);
  }
  if (paymentMethod === "wallet" && priceDiff > 0) {
    const { error: chargeErr } = await supabase.rpc("wallet_deduct", {
      p_user_id: booking.customer_id,
      p_amount: priceDiff,
      p_note: "order_item_edit_charge",
      p_ref_id: booking_id,
    });
    if (chargeErr) return errorResponse(chargeErr.message);
  }

  const notifications = [];
  if (booking.customer_id) {
    notifications.push({
      user_id: booking.customer_id,
      title: "Order items updated",
      body: `Order #${String(booking_id).substring(0, 8)} items were updated by admin.`,
      type: "order_item_edit_customer",
      data: { type: "order_item_edit_customer", booking_id, price_diff: priceDiff },
    });
  }
  if (booking.merchant_id) {
    notifications.push({
      user_id: booking.merchant_id,
      title: "Order items updated",
      body: `Order #${String(booking_id).substring(0, 8)} item list was updated.`,
      type: "order_item_edit_merchant",
      data: { type: "order_item_edit_merchant", booking_id, price_diff: priceDiff },
    });
  }
  if (notifications.length) {
    const { error: notifyErr } = await supabase.from("notifications").insert(notifications);
    if (notifyErr) console.error("edit_order_items notification error:", notifyErr);
  }

  return jsonResponse({ success: true, price_diff: priceDiff, new_food_total: newFoodTotal });
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
  if (!wallet) return errorResponse("ไม่สามารถสร้าง wallet ได้ (wallet insert returned null)");

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
    type: "topup",
    description: (description || "Admin เติมเงินด้วยมือ") + " (Admin Manual)",
  });
  if (txErr) return errorResponse(txErr.message);

  let topupRequestLogged = false;
  let topupRequestLogError: string | null = null;
  try {
    const nowIso = new Date().toISOString();
    const { error: topupLogErr } = await supabase.from("topup_requests").insert({
      user_id,
      amount,
      status: "completed",
      admin_note: (description || "Admin เติมเงินด้วยมือ") + " (Admin Manual)",
      processed_at: nowIso,
      updated_at: nowIso,
    });

    if (topupLogErr) {
      topupRequestLogError = topupLogErr.message;
    } else {
      topupRequestLogged = true;
    }
  } catch (e) {
    topupRequestLogError = String((e as Error)?.message || e);
  }

  return jsonResponse({
    success: true,
    before,
    after,
    topup_request_logged: topupRequestLogged,
    topup_request_log_error: topupRequestLogError,
  });
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
