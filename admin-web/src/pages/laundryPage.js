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

function money(value) {
  return "฿" + new Intl.NumberFormat("th-TH").format(Math.round(Number(value || 0)));
}

function statusLabel(status) {
  const labels = {
    quote_requested: "รอร้านประเมิน",
    quoted: "ส่ง quote แล้ว",
    quote_expired: "quote หมดอายุ",
    quote_rejected: "ปฏิเสธ quote",
    outbound_pending: "รองานขาไป",
    outbound_assigned: "คนขับรับงานขาไป",
    outbound_picked_up: "รับผ้าแล้ว",
    at_merchant: "ถึงร้านแล้ว",
    washing: "กำลังซัก",
    ready_for_return: "พร้อมส่งกลับ",
    return_pending: "รองานขากลับ",
    return_assigned: "คนขับรับงานขากลับ",
    return_picked_up: "รับผ้ากลับแล้ว",
    completed: "เสร็จสิ้น",
    cancelled: "ยกเลิก",
  };
  return labels[status] || status || "-";
}

function statusClass(status) {
  if (status === "completed") return "bg-emerald-50 text-emerald-700 border-emerald-200";
  if (["cancelled", "quote_expired", "quote_rejected"].includes(status)) {
    return "bg-rose-50 text-rose-700 border-rose-200";
  }
  if (["quoted", "ready_for_return"].includes(status)) return "bg-blue-50 text-blue-700 border-blue-200";
  return "bg-amber-50 text-amber-700 border-amber-200";
}

function paymentLabel(method) {
  const labels = {
    wallet: "Wallet",
    cash: "Cash",
  };
  return labels[method] || method || "-";
}

function pickupPresenceLabel(value) {
  const labels = {
    remote_pickup: "Remote pickup",
    customer_at_pickup: "Customer at pickup",
  };
  return labels[value] || value || "-";
}

async function loadProfiles(supabase, ids) {
  const uniqueIds = [...new Set(ids.filter(Boolean))];
  if (!uniqueIds.length) return {};

  const { data, error } = await supabase
    .from("profiles")
    .select("id, full_name, phone_number, role")
    .in("id", uniqueIds);

  if (error) throw error;
  return Object.fromEntries((data || []).map((profile) => [profile.id, profile]));
}

async function loadLaundryDrivers(supabase) {
  const { data, error } = await supabase
    .from("profiles")
    .select("id, full_name, phone_number, approval_status, is_online")
    .eq("role", "driver")
    .eq("approval_status", "approved")
    .order("full_name", { ascending: true });

  if (error) throw error;
  return data || [];
}

async function attachSignedAttachmentUrls(supabase, orders) {
  const bucket = supabase.storage.from("laundry-quote-attachments");
  await Promise.all((orders || []).map(async (order) => {
    const paths = Array.isArray(order.attachment_urls)
      ? order.attachment_urls.filter(Boolean)
      : [];
    order.attachment_signed_urls = [];
    if (!paths.length) return;

    const { data, error } = await bucket.createSignedUrls(paths, 3600);
    if (error) {
      order.attachment_error = error.message || "signed_url_failed";
      return;
    }
    order.attachment_signed_urls = (data || [])
      .map((item) => item?.signedUrl)
      .filter(Boolean);
  }));
}

async function loadLaundryOrders(supabase) {
  const { data, error } = await supabase
    .from("laundry_orders")
    .select(`
      id,
      customer_id,
      merchant_id,
      status,
      laundry_amount,
      delivery_fee_outbound,
      delivery_fee_return,
      platform_gp_amount,
      merchant_net_amount,
      payment_method,
      pickup_presence,
      attachment_urls,
      quote_expires_at,
      accepted_at,
      return_mode,
      return_payment_method,
      created_at,
      outbound_booking:outbound_booking_id(id,status,driver_id,laundry_leg,pickup_evidence_url,payment_method,price,delivery_fee),
      return_booking:return_booking_id(id,status,driver_id,laundry_leg,pickup_evidence_url,payment_method,price,delivery_fee)
    `)
    .order("created_at", { ascending: false })
    .limit(100);

  if (error) throw error;
  await attachSignedAttachmentUrls(supabase, data || []);

  const profileIds = [];
  for (const order of data || []) {
    profileIds.push(order.customer_id, order.merchant_id);
    if (order.outbound_booking?.driver_id) profileIds.push(order.outbound_booking.driver_id);
    if (order.return_booking?.driver_id) profileIds.push(order.return_booking.driver_id);
  }

  const orderIds = (data || []).map((order) => order.id).filter(Boolean);
  const messagesByOrder = {};
  if (orderIds.length) {
    const { data: messages, error: msgError } = await supabase
      .from("laundry_quote_messages")
      .select("laundry_order_id,sender_role,body,created_at")
      .in("laundry_order_id", orderIds)
      .order("created_at", { ascending: false });
    if (msgError) throw msgError;
    for (const message of messages || []) {
      const key = message.laundry_order_id;
      if (!messagesByOrder[key]) {
        messagesByOrder[key] = { count: 0, latest: message };
      }
      messagesByOrder[key].count += 1;
    }
  }

  const [profiles, drivers] = await Promise.all([
    loadProfiles(supabase, profileIds),
    loadLaundryDrivers(supabase),
  ]);
  return { orders: data || [], profiles, drivers, messagesByOrder };
}

function profileName(profiles, id) {
  const profile = profiles[id];
  if (!profile) return id ? `#${String(id).slice(0, 8)}` : "-";
  return profile.full_name || profile.phone_number || `#${String(id).slice(0, 8)}`;
}

function driverOptions(drivers, escapeHtml) {
  if (!drivers.length) {
    return '<option value="">ยังไม่มีคนขับที่อนุมัติแล้ว</option>';
  }
  return [
    '<option value="">เลือกคนขับ</option>',
    ...drivers.map((driver) => {
      const online = driver.is_online ? " · ออนไลน์" : "";
      const label = driver.full_name || driver.phone_number || `#${String(driver.id).slice(0, 8)}`;
      return `<option value="${escapeHtml(driver.id)}">${escapeHtml(label + online)}</option>`;
    }),
  ].join("");
}

function canAssignBooking(booking) {
  return (
    booking &&
    !booking.driver_id &&
    ["pending", "ready_for_pickup", "preparing"].includes(booking.status)
  );
}

function bookingCell(booking, profiles, drivers, escapeHtml, legLabel) {
  if (!booking) return '<span class="text-gray-400">ยังไม่สร้าง</span>';
  const driver = booking.driver_id ? profileName(profiles, booking.driver_id) : "ยังไม่มีคนขับ";
  const evidence = booking.pickup_evidence_url ? "มีรูปหลักฐาน" : "ยังไม่มีรูป";
  const assignControl = canAssignBooking(booking)
    ? `
      <div class="mt-2 flex flex-col gap-2 min-w-[190px]">
        <select
          class="laundryAssignDriverSelect border border-gray-200 rounded-lg px-2 py-1.5 text-xs bg-white"
          data-booking-id="${escapeHtml(booking.id)}"
          aria-label="เลือกคนขับ${escapeHtml(legLabel)}"
        >
          ${driverOptions(drivers, escapeHtml)}
        </select>
        <button
          type="button"
          class="laundryAssignDriverBtn px-2.5 py-1.5 rounded-lg bg-indigo-600 hover:bg-indigo-700 text-white text-xs font-semibold disabled:opacity-50 disabled:cursor-not-allowed"
          data-booking-id="${escapeHtml(booking.id)}"
          data-leg-label="${escapeHtml(legLabel)}"
          ${drivers.length ? "" : "disabled"}
        >
          Assign คนขับ
        </button>
      </div>
    `
    : "";
  return `
    <div class="space-y-1">
      <div class="font-semibold text-gray-800">#${escapeHtml(String(booking.id).slice(0, 8))}</div>
      <div class="text-xs text-gray-500">${escapeHtml(statusLabel(booking.status))} · ${escapeHtml(driver)}</div>
      <div class="text-xs text-gray-400">${escapeHtml(booking.payment_method || "-")} · ${escapeHtml(evidence)}</div>
      ${assignControl}
    </div>
  `;
}

function chatCell(chat, escapeHtml, fmtDate) {
  if (!chat?.count) return '<span class="text-gray-400">ยังไม่มี chat</span>';
  const latest = chat.latest || {};
  return `
    <div class="space-y-1">
      <div class="font-semibold text-gray-800">${chat.count} ข้อความ</div>
      <div class="text-xs text-gray-500">${escapeHtml(latest.sender_role || "-")} · ${escapeHtml(fmtDate(latest.created_at))}</div>
      <div class="text-xs text-gray-400 max-w-[220px] truncate">${escapeHtml(latest.body || "")}</div>
    </div>
  `;
}

function attachmentCell(order, escapeHtml) {
  const urls = Array.isArray(order.attachment_signed_urls)
    ? order.attachment_signed_urls
    : [];
  if (urls.length) {
    return `
      <div class="space-y-1">
        <div class="font-semibold text-gray-800">รูปแนบ ${urls.length} รูป</div>
        <div class="flex flex-wrap gap-2">
          ${urls.map((url, index) => `
            <a
              class="px-2 py-1 rounded-lg bg-blue-50 text-blue-700 text-xs font-semibold hover:bg-blue-100"
              href="${escapeHtml(url)}"
              target="_blank"
              rel="noopener noreferrer"
            >รูป ${index + 1}</a>
          `).join("")}
        </div>
      </div>
    `;
  }
  if (order.attachment_error) {
    return `<span class="text-xs text-amber-600">เปิดรูปแนบไม่ได้: ${escapeHtml(order.attachment_error)}</span>`;
  }
  return '<span class="text-gray-400">ไม่มีรูปแนบ</span>';
}

async function loadLaundryPackageMerchants(supabase) {
  const { data, error } = await supabase
    .from("profiles")
    .select("id, full_name, phone_number, shop_address, merchant_service_types")
    .eq("role", "merchant")
    .contains("merchant_service_types", ["laundry"])
    .order("full_name", { ascending: true });

  if (error) throw error;
  return data || [];
}

async function loadLaundryPackages(supabase, merchantIds, ctx) {
  const ids = [...new Set((merchantIds || []).filter(Boolean))];
  if (!ids.length) return [];

  const { callAdminAction } = _deps(ctx);
  if (typeof callAdminAction === "function") {
    const result = await callAdminAction({
      action: "list_laundry_packages",
      merchant_ids: ids,
    });
    return Array.isArray(result?.packages) ? result.packages : [];
  }

  const { data, error } = await supabase
    .from("laundry_packages")
    .select("id, merchant_id, name, description, base_price, unit, is_active, sort_order, updated_at")
    .in("merchant_id", ids)
    .order("sort_order", { ascending: true })
    .order("name", { ascending: true });

  if (error) throw error;
  return data || [];
}

function renderLaundryPackageManager(merchants, packages, selectedMerchantId, escapeHtml) {
  const selectedPackages = (packages || [])
    .filter((packageRow) => packageRow.merchant_id === selectedMerchantId)
    .sort((a, b) => Number(a.sort_order || 0) - Number(b.sort_order || 0));

  const merchantOptions = (merchants || [])
    .map((merchant) => `
      <option value="${escapeHtml(merchant.id)}" ${merchant.id === selectedMerchantId ? "selected" : ""}>
        ${escapeHtml(merchant.full_name || merchant.shop_address || merchant.id)}
      </option>
    `)
    .join("");

  return `
    <section class="rounded-2xl border border-gray-100 bg-gray-50 p-4 mb-5">
      <div class="flex flex-col lg:flex-row lg:items-center lg:justify-between gap-3 mb-4">
        <div>
          <h3 class="text-base font-bold text-gray-900">แพ็กเกจซักผ้า</h3>
          <p class="text-xs text-gray-500">สร้าง ลบ และแก้ไขแพ็กเกจที่ลูกค้าจะเห็นหลังเลือกร้าน</p>
        </div>
        <div class="flex flex-col sm:flex-row gap-2">
          <select
            id="laundryPackageMerchantSelect"
            class="min-w-[220px] rounded-xl border border-gray-200 bg-white px-3 py-2 text-sm"
            ${merchantOptions ? "" : "disabled"}
          >
            ${merchantOptions || '<option value="">ยังไม่มีร้าน laundry</option>'}
          </select>
          <button
            id="laundryAddPackageBtn"
            class="px-4 py-2 rounded-xl bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold disabled:opacity-50"
            ${selectedMerchantId ? "" : "disabled"}
          >
            + เพิ่มแพ็กเกจ
          </button>
        </div>
      </div>
      <div class="overflow-x-auto rounded-2xl border border-gray-100 bg-white">
        <table class="min-w-full text-sm">
          <thead>
            <tr class="text-left text-xs uppercase tracking-wide text-gray-400 border-b border-gray-100">
              <th class="py-3 px-3">ชื่อแพ็กเกจ</th>
              <th class="py-3 px-3">ราคาเริ่มต้น</th>
              <th class="py-3 px-3">หน่วย</th>
              <th class="py-3 px-3">สถานะ</th>
              <th class="py-3 px-3 text-right">จัดการ</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            ${selectedPackages.map((packageRow) => `
              <tr>
                <td class="py-3 px-3">
                  <div class="font-semibold text-gray-900">${escapeHtml(packageRow.name)}</div>
                  <div class="text-xs text-gray-500">${escapeHtml(packageRow.description || "-")}</div>
                </td>
                <td class="py-3 px-3 font-semibold text-gray-900">${money(packageRow.base_price)}</td>
                <td class="py-3 px-3 text-gray-500">${escapeHtml(packageRow.unit || "-")}</td>
                <td class="py-3 px-3">
                  <span class="inline-flex px-2.5 py-1 rounded-full border text-xs font-semibold ${packageRow.is_active ? "bg-emerald-50 text-emerald-700 border-emerald-200" : "bg-gray-50 text-gray-500 border-gray-200"}">
                    ${packageRow.is_active ? "เปิดใช้งาน" : "ปิดใช้งาน"}
                  </span>
                </td>
                <td class="py-3 px-3">
                  <div class="flex justify-end gap-2">
                    <button class="laundryEditPackageBtn px-3 py-1.5 rounded-lg bg-indigo-50 text-indigo-700 text-xs font-semibold hover:bg-indigo-100" data-package-id="${escapeHtml(packageRow.id)}">แก้ไข</button>
                    <button class="laundryDeletePackageBtn px-3 py-1.5 rounded-lg bg-rose-50 text-rose-700 text-xs font-semibold hover:bg-rose-100" data-package-id="${escapeHtml(packageRow.id)}">ลบ</button>
                  </div>
                </td>
              </tr>
            `).join("") || `
              <tr>
                <td colspan="5" class="py-8 text-center text-gray-400">ยังไม่มีแพ็กเกจของร้านนี้</td>
              </tr>
            `}
          </tbody>
        </table>
      </div>
    </section>
  `;
}

function closeLaundryPackageDialog() {
  document.querySelector("#laundryPackageDialog")?.remove();
}

export function openLaundryPackageDialog(packageRow, merchantId, ctx) {
  const { escapeHtml, showToast } = _deps(ctx);
  if (!merchantId) {
    showToast("กรุณาเลือกร้านก่อนเพิ่มแพ็กเกจ", "error");
    return;
  }

  closeLaundryPackageDialog();
  const dialog = document.createElement("div");
  dialog.id = "laundryPackageDialog";
  dialog.className = "fixed inset-0 z-50 flex items-center justify-center bg-black/40 px-4";
  dialog.innerHTML = `
    <div class="w-full max-w-lg rounded-3xl bg-white shadow-xl border border-gray-100">
      <form id="laundryPackageForm" class="p-5 space-y-4">
        <div class="flex items-center justify-between gap-3">
          <div>
            <h3 class="text-lg font-bold text-gray-900">${packageRow?.id ? "แก้ไขแพ็กเกจซักผ้า" : "เพิ่มแพ็กเกจซักผ้า"}</h3>
            <p class="text-xs text-gray-500">ข้อมูลนี้จะแสดงหลังลูกค้าเลือกร้านซักผ้า</p>
          </div>
          <button type="button" id="laundryPackageCloseBtn" class="w-9 h-9 rounded-full bg-gray-100 hover:bg-gray-200 text-gray-600">×</button>
        </div>
        <label class="block">
          <span class="text-xs font-semibold text-gray-600">ชื่อแพ็กเกจ</span>
          <input name="name" required class="mt-1 w-full rounded-xl border border-gray-200 px-3 py-2 text-sm" value="${escapeHtml(packageRow?.name || "")}">
        </label>
        <label class="block">
          <span class="text-xs font-semibold text-gray-600">รายละเอียด</span>
          <textarea name="description" rows="3" class="mt-1 w-full rounded-xl border border-gray-200 px-3 py-2 text-sm">${escapeHtml(packageRow?.description || "")}</textarea>
        </label>
        <div class="grid grid-cols-1 sm:grid-cols-3 gap-3">
          <label class="block">
            <span class="text-xs font-semibold text-gray-600">ราคาเริ่มต้น</span>
            <input name="base_price" type="number" min="0" step="0.01" required class="mt-1 w-full rounded-xl border border-gray-200 px-3 py-2 text-sm" value="${Number(packageRow?.base_price || 0)}">
          </label>
          <label class="block">
            <span class="text-xs font-semibold text-gray-600">หน่วย</span>
            <input name="unit" required class="mt-1 w-full rounded-xl border border-gray-200 px-3 py-2 text-sm" value="${escapeHtml(packageRow?.unit || "piece")}">
          </label>
          <label class="block">
            <span class="text-xs font-semibold text-gray-600">ลำดับ</span>
            <input name="sort_order" type="number" step="1" class="mt-1 w-full rounded-xl border border-gray-200 px-3 py-2 text-sm" value="${Number(packageRow?.sort_order || 0)}">
          </label>
        </div>
        <label class="inline-flex items-center gap-2 text-sm text-gray-700">
          <input name="is_active" type="checkbox" class="rounded border-gray-300" ${packageRow?.is_active === false ? "" : "checked"}>
          เปิดให้ลูกค้าเห็น
        </label>
        <div class="flex justify-end gap-2 pt-2">
          <button type="button" id="laundryPackageCancelBtn" class="px-4 py-2 rounded-xl bg-gray-100 text-gray-700 text-sm font-semibold hover:bg-gray-200">ยกเลิก</button>
          <button type="submit" class="px-4 py-2 rounded-xl bg-blue-600 text-white text-sm font-semibold hover:bg-blue-700">บันทึก</button>
        </div>
      </form>
    </div>
  `;

  document.body.appendChild(dialog);
  dialog.querySelector("#laundryPackageCloseBtn")?.addEventListener("click", closeLaundryPackageDialog);
  dialog.querySelector("#laundryPackageCancelBtn")?.addEventListener("click", closeLaundryPackageDialog);
  dialog.addEventListener("click", (event) => {
    if (event.target === dialog) closeLaundryPackageDialog();
  });
  dialog.querySelector("#laundryPackageForm")?.addEventListener("submit", async (event) => {
    event.preventDefault();
    const form = event.currentTarget;
    const formData = new FormData(form);
    await saveLaundryPackage({
      package_id: packageRow?.id || null,
      merchant_id: merchantId,
      name: String(formData.get("name") || "").trim(),
      description: String(formData.get("description") || "").trim(),
      base_price: Number(formData.get("base_price") || 0),
      unit: String(formData.get("unit") || "").trim(),
      sort_order: Number(formData.get("sort_order") || 0),
      is_active: formData.get("is_active") === "on",
    }, ctx);
  });
}

export async function renderLaundryPage(el, ctx) {
  const { supabase, escapeHtml, fmtDate, showToast } = _deps(ctx);
  if (!supabase) {
    el.innerHTML = '<div class="p-6 text-red-600">Supabase client unavailable</div>';
    return;
  }

  el.innerHTML = `
    <div class="bg-white rounded-3xl border border-gray-100 shadow-sm p-5 mb-6">
      <div class="flex flex-col md:flex-row md:items-center md:justify-between gap-3">
        <div>
          <h2 class="text-xl font-bold text-gray-900">Laundry</h2>
          <p class="text-sm text-gray-500">ตรวจสอบคำขอซักผ้า, quote, งานขาไป/ขากลับ และยอด GP</p>
        </div>
        <button id="laundryRefreshBtn" class="px-4 py-2 bg-gray-100 hover:bg-gray-200 text-gray-700 rounded-xl text-sm font-semibold">รีเฟรช</button>
      </div>
    </div>
    <div id="laundryContent" class="bg-white rounded-3xl border border-gray-100 shadow-sm p-5">
      <div class="text-center text-gray-400 py-12">กำลังโหลด...</div>
    </div>
  `;

  const render = async () => {
    const content = el.querySelector("#laundryContent");
    try {
      const { orders, profiles, drivers, messagesByOrder } = await loadLaundryOrders(supabase);
      const laundryPackageMerchants = await loadLaundryPackageMerchants(supabase);
      const laundryPackageMerchantIds = laundryPackageMerchants.map((merchant) => merchant.id).filter(Boolean);
      const laundryPackages = await loadLaundryPackages(supabase, laundryPackageMerchantIds, ctx);
      const currentPackageMerchantId = content.dataset.packageMerchantId;
      const selectedPackageMerchantId = laundryPackageMerchantIds.includes(currentPackageMerchantId)
        ? currentPackageMerchantId
        : (laundryPackageMerchantIds[0] || "");
      content.dataset.packageMerchantId = selectedPackageMerchantId;
      const totalLaundry = orders.reduce((sum, order) => sum + Number(order.laundry_amount || 0), 0);
      const totalGp = orders.reduce((sum, order) => sum + Number(order.platform_gp_amount || 0), 0);
      const totalNet = orders.reduce((sum, order) => sum + Number(order.merchant_net_amount || 0), 0);
      const pendingCount = orders.filter((order) => !["completed", "cancelled", "quote_expired", "quote_rejected"].includes(order.status)).length;

      content.innerHTML = `
        <div class="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-5">
          <div class="rounded-2xl bg-gray-50 p-4">
            <p class="text-xs text-gray-500">คำขอทั้งหมด</p>
            <p class="text-2xl font-bold text-gray-900">${orders.length}</p>
          </div>
          <div class="rounded-2xl bg-amber-50 p-4">
            <p class="text-xs text-amber-700">กำลังดำเนินการ</p>
            <p class="text-2xl font-bold text-amber-700">${pendingCount}</p>
          </div>
          <div class="rounded-2xl bg-cyan-50 p-4">
            <p class="text-xs text-cyan-700">ยอดซักรวม</p>
            <p class="text-2xl font-bold text-cyan-700">${money(totalLaundry)}</p>
          </div>
          <div class="rounded-2xl bg-emerald-50 p-4">
            <p class="text-xs text-emerald-700">GP / ร้านสุทธิ</p>
            <p class="text-lg font-bold text-emerald-700">${money(totalGp)} / ${money(totalNet)}</p>
          </div>
        </div>
        ${renderLaundryPackageManager(laundryPackageMerchants, laundryPackages, selectedPackageMerchantId, escapeHtml)}
        <div class="overflow-x-auto">
          <table class="min-w-full text-sm">
            <thead>
              <tr class="text-left text-xs uppercase tracking-wide text-gray-400 border-b border-gray-100">
                <th class="py-3 px-3">ลูกค้า / ร้าน</th>
                <th class="py-3 px-3">สถานะ</th>
                <th class="py-3 px-3">ยอดเงิน</th>
                <th class="py-3 px-3">รูปแนบ</th>
                <th class="py-3 px-3">Chat</th>
                <th class="py-3 px-3">งานขาไป</th>
                <th class="py-3 px-3">งานขากลับ</th>
                <th class="py-3 px-3">วันที่</th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-100">
              ${orders.map((order) => `
                <tr class="align-top">
                  <td class="py-3 px-3">
                    <div class="font-semibold text-gray-900">${escapeHtml(profileName(profiles, order.customer_id))}</div>
                    <div class="text-xs text-gray-500">${escapeHtml(profileName(profiles, order.merchant_id))}</div>
                    <div class="text-xs text-gray-400">#${escapeHtml(String(order.id).slice(0, 8))}</div>
                  </td>
                  <td class="py-3 px-3">
                    <span class="inline-flex px-2.5 py-1 rounded-full border text-xs font-semibold ${statusClass(order.status)}">${escapeHtml(statusLabel(order.status))}</span>
                    <div class="text-xs text-gray-400 mt-1">quote หมดอายุ: ${escapeHtml(fmtDate(order.quote_expires_at))}</div>
                  </td>
                  <td class="py-3 px-3">
                    <div class="font-semibold text-gray-900">ซัก ${money(order.laundry_amount)}</div>
                    <div class="text-xs text-gray-500">ส่งไป ${money(order.delivery_fee_outbound)} · ส่งกลับ ${money(order.delivery_fee_return)}</div>
                    <div class="text-xs text-gray-500">GP ${money(order.platform_gp_amount)} · ร้านสุทธิ ${money(order.merchant_net_amount)}</div>
                    <div class="text-xs text-gray-500">\u0e27\u0e34\u0e18\u0e35\u0e0a\u0e33\u0e23\u0e30: ${escapeHtml(paymentLabel(order.payment_method))}</div>
                    <div class="text-xs text-gray-500">\u0e08\u0e38\u0e14\u0e23\u0e31\u0e1a\u0e1c\u0e49\u0e32: ${escapeHtml(pickupPresenceLabel(order.pickup_presence))}</div>
                  </td>
                  <td class="py-3 px-3">${attachmentCell(order, escapeHtml)}</td>
                  <td class="py-3 px-3">${chatCell(messagesByOrder[order.id], escapeHtml, fmtDate)}</td>
                  <td class="py-3 px-3">${bookingCell(order.outbound_booking, profiles, drivers, escapeHtml, "ขาไป")}</td>
                  <td class="py-3 px-3">${bookingCell(order.return_booking, profiles, drivers, escapeHtml, "ขากลับ")}</td>
                  <td class="py-3 px-3 text-gray-500">${escapeHtml(fmtDate(order.created_at))}</td>
                </tr>
              `).join("") || `
                <tr>
                  <td colspan="8" class="py-10 text-center text-gray-400">ยังไม่มีคำขอซักผ้า</td>
                </tr>
              `}
            </tbody>
          </table>
        </div>
      `;

      content.querySelector("#laundryPackageMerchantSelect")?.addEventListener("change", async (event) => {
        content.dataset.packageMerchantId = event.currentTarget.value;
        await render();
      });
      content.querySelector("#laundryAddPackageBtn")?.addEventListener("click", () => {
        openLaundryPackageDialog(null, selectedPackageMerchantId, { ...ctx, render });
      });
      for (const button of content.querySelectorAll(".laundryEditPackageBtn")) {
        button.addEventListener("click", () => {
          const packageRow = laundryPackages.find((item) => item.id === button.dataset.packageId);
          openLaundryPackageDialog(packageRow, packageRow?.merchant_id || selectedPackageMerchantId, { ...ctx, render });
        });
      }
      for (const button of content.querySelectorAll(".laundryDeletePackageBtn")) {
        button.addEventListener("click", async () => {
          await deleteLaundryPackage(button.dataset.packageId, { ...ctx, render });
        });
      }
      for (const button of content.querySelectorAll(".laundryAssignDriverBtn")) {
        button.addEventListener("click", async () => {
          const bookingId = button.dataset.bookingId;
          const select = button.parentElement?.querySelector(".laundryAssignDriverSelect");
          const driverId = select?.value;
          await assignLaundryBookingDriver(bookingId, driverId, { ...ctx, render });
        });
      }
    } catch (err) {
      content.innerHTML = `<div class="p-4 rounded-2xl bg-red-50 text-red-700">โหลดข้อมูล Laundry ไม่สำเร็จ: ${escapeHtml(err.message || err)}</div>`;
      showToast(`โหลดข้อมูล Laundry ไม่สำเร็จ: ${err.message || err}`, "error");
    }
  };

  el.querySelector("#laundryRefreshBtn")?.addEventListener("click", render);
  await render();
}

export async function saveLaundryPackage(packageData, ctx) {
  const { callAdminAction, showToast, escapeHtml } = _deps(ctx);
  if (typeof callAdminAction !== "function") {
    showToast("ไม่พบ admin action สำหรับบันทึกแพ็กเกจซักผ้า", "error");
    return;
  }

  try {
    await callAdminAction({ action: "manage_laundry_package", ...packageData });
    showToast("บันทึกแพ็กเกจซักผ้าแล้ว", "success");
    closeLaundryPackageDialog();
    if (typeof ctx?.render === "function") await ctx.render();
  } catch (err) {
    showToast(`บันทึกแพ็กเกจซักผ้าไม่สำเร็จ: ${escapeHtml(err.message || err)}`, "error");
  }
}

export async function deleteLaundryPackage(packageId, ctx) {
  const { callAdminAction, showToast, escapeHtml } = _deps(ctx);
  if (!packageId) {
    showToast("ไม่พบแพ็กเกจที่ต้องการลบ", "error");
    return;
  }
  if (typeof callAdminAction !== "function") {
    showToast("ไม่พบ admin action สำหรับลบแพ็กเกจซักผ้า", "error");
    return;
  }
  if (typeof globalThis.confirm === "function" && !globalThis.confirm("ลบแพ็กเกจนี้หรือไม่?")) return;

  try {
    await callAdminAction({ action: "delete_laundry_package", package_id: packageId });
    showToast("ลบแพ็กเกจซักผ้าแล้ว", "success");
    if (typeof ctx?.render === "function") await ctx.render();
  } catch (err) {
    showToast(`ลบแพ็กเกจซักผ้าไม่สำเร็จ: ${escapeHtml(err.message || err)}`, "error");
  }
}

export async function assignLaundryBookingDriver(bookingId, driverId, ctx) {
  const { callAdminAction, showToast, escapeHtml } = _deps(ctx);
  if (!bookingId || !driverId) {
    showToast("กรุณาเลือกคนขับก่อน assign", "error");
    return;
  }
  if (typeof callAdminAction !== "function") {
    showToast("ไม่พบ admin action สำหรับ assign คนขับ", "error");
    return;
  }

  try {
    await callAdminAction({ action: "assign_order", order_id: bookingId, driver_id: driverId });
    showToast("Assign คนขับให้งานซักผ้าแล้ว", "success");
    if (typeof ctx?.render === "function") {
      await ctx.render();
    } else if (typeof ctx?.refreshCurrentPage === "function") {
      ctx.refreshCurrentPage();
    }
  } catch (err) {
    showToast(`Assign คนขับไม่สำเร็จ: ${escapeHtml(err.message || err)}`, "error");
  }
}

globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
globalThis.__adminWebBridge.renderLaundryPage = renderLaundryPage;
globalThis.__adminWebBridge.openLaundryPackageDialog = openLaundryPackageDialog;
globalThis.__adminWebBridge.saveLaundryPackage = saveLaundryPackage;
globalThis.__adminWebBridge.deleteLaundryPackage = deleteLaundryPackage;
globalThis.__adminWebBridge.assignLaundryBookingDriver = assignLaundryBookingDriver;
