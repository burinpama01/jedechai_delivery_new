import {
  buildOrderItemsPayload,
  getOrderItemsPriceChange,
  renderAdminNote,
  renderContactCard,
  renderOrderItemRows,
  validateOrderItemsPayload,
} from '../utils/orderItems.js';

let _ctx = null;

function _deps() {
  const ctx = _ctx || globalThis.__adminWebContext || globalThis.__adminWebBridge || {};
  const supabase = ctx.supabase || globalThis.supabase;
  const callAdminAction = ctx.callAdminAction || globalThis.callAdminAction || globalThis.__adminWebBridge?.callAdminAction;
  const showToast = ctx.showToast || globalThis.showToast || globalThis.__adminWebBridge?.showToast;
  const escapeHtml = ctx.escapeHtml || globalThis.escapeHtml;

  return {
    supabase,
    callAdminAction,
    showToast,
    escapeHtml,
  };
}

async function _refreshAdminOrderViews() {
  const currentPage = globalThis.currentPage;

  if (currentPage === 'orders' && typeof globalThis.loadOrders === 'function') {
    await globalThis.loadOrders();
  }
  if (currentPage === 'pending_orders' && typeof globalThis._refreshPendingOrders === 'function') {
    await globalThis._refreshPendingOrders();
  }
  if (currentPage === 'map' && typeof globalThis.refreshMapData === 'function') {
    await globalThis.refreshMapData();
  }

  const merchantOrderModal = document.getElementById('merchantOrderManagerModal');
  const merchantId = merchantOrderModal?.dataset?.merchantId;
  if (merchantId && typeof globalThis.refreshMerchantOrderManager === 'function') {
    await globalThis.refreshMerchantOrderManager(merchantId);
  }
}

export async function adminMerchantAcceptOrder(orderId, ctx) {
  _ctx = ctx || _ctx;
  return await showAdminAcceptModal(orderId);
}

export async function adminMarkFoodReady(orderId, ctx) {
  _ctx = ctx || _ctx;
  return await _adminActAsMerchantOrder(orderId, 'ready');
}

function _toNumber(value) {
  if (value === null || value === undefined || value === '') return null;
  const n = Number(value);
  return Number.isFinite(n) ? n : null;
}

function _shortOrderId(orderId) {
  return String(orderId || '').substring(0, 8);
}

function _escapeHtml(value) {
  const escapeHtml = _ctx?.escapeHtml || globalThis.escapeHtml;
  if (typeof escapeHtml === 'function') return escapeHtml(value);
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

function _coordText(lat, lng) {
  const la = _toNumber(lat);
  const ln = _toNumber(lng);
  if (la === null || ln === null) return '-';
  return `${la.toFixed(6)}, ${ln.toFixed(6)}`;
}

function _profileName(profile, fallback = '-') {
  return profile?.full_name || profile?.name || fallback;
}

function _profilePhone(profile) {
  return profile?.phone_number || profile?.phone || '';
}

function _parseJsonInput(value, fallback = []) {
  const text = String(value || '').trim();
  if (!text) return fallback;
  try {
    return JSON.parse(text);
  } catch (_) {
    return fallback;
  }
}

export function toggleAdminAcceptChecklist() {
  const checked = [...document.querySelectorAll('[data-admin-accept-check]')].every((el) => el.checked);
  const button = document.getElementById('adminAcceptSubmit');
  if (button) {
    button.disabled = !checked;
    button.classList.toggle('opacity-50', !checked);
    button.classList.toggle('cursor-not-allowed', !checked);
  }
}

export async function copyAdminText(value) {
  const text = String(value || '');
  try {
    await navigator.clipboard?.writeText(text);
    _deps().showToast?.('Copied', 'success');
  } catch (_) {
    window.prompt('Copy this value', text);
  }
}

export async function showEditPickupLocationModal(orderId, ctx) {
  _ctx = ctx || _ctx;
  const { supabase, escapeHtml } = _deps();

  const { data: order, error } = await supabase
    .from('bookings')
    .select('id, status, service_type, merchant_id, pickup_address, origin_lat, origin_lng, destination_address, dest_lat, dest_lng')
    .eq('id', orderId)
    .maybeSingle();

  if (error) return alert(error.message || JSON.stringify(error));
  if (!order) return alert('ไม่พบออเดอร์');

  let merchant = null;
  if (order.merchant_id) {
    const { data } = await supabase
      .from('profiles')
      .select('id, full_name, shop_address, latitude, longitude')
      .eq('id', order.merchant_id)
      .maybeSingle();
    merchant = data || null;
  }

  const modal = document.createElement('div');
  modal.id = 'editPickupLocationModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-xl fade-in overflow-hidden">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <div>
          <h3 class="font-bold text-gray-800 text-lg">แก้ไขพิกัด Pickup</h3>
          <p class="text-xs text-gray-500 mt-1">ออเดอร์ #${_shortOrderId(orderId)} · ${escapeHtml(order.service_type || '-')} · ${escapeHtml(order.status || '-')}</p>
        </div>
        <button onclick="document.getElementById('editPickupLocationModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-6 space-y-4">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3 text-xs">
          <div class="p-3 rounded-xl bg-gray-50">
            <p class="text-gray-400 mb-1">Pickup ปัจจุบัน</p>
            <p class="font-semibold text-gray-800">${escapeHtml(order.pickup_address || '-')}</p>
            <p class="text-gray-500 mt-1">${_coordText(order.origin_lat, order.origin_lng)}</p>
          </div>
          <div class="p-3 rounded-xl bg-gray-50">
            <p class="text-gray-400 mb-1">ปลายทางลูกค้า</p>
            <p class="font-semibold text-gray-800">${escapeHtml(order.destination_address || '-')}</p>
            <p class="text-gray-500 mt-1">${_coordText(order.dest_lat, order.dest_lng)}</p>
          </div>
        </div>

        ${merchant ? `
          <div class="p-3 rounded-xl bg-orange-50 border border-orange-100 text-xs">
            <div class="flex items-start justify-between gap-3">
              <div>
                <p class="font-semibold text-orange-700">พิกัดร้านค้าในโปรไฟล์</p>
                <p class="text-gray-700 mt-1">${escapeHtml(merchant.shop_address || merchant.full_name || '-')}</p>
                <p class="text-gray-500 mt-1">${_coordText(merchant.latitude, merchant.longitude)}</p>
              </div>
              <button onclick="useMerchantPickupLocation()" class="px-3 py-1.5 rounded-lg bg-orange-500 text-white text-xs font-semibold hover:bg-orange-600 whitespace-nowrap">ใช้พิกัดร้านค้า</button>
            </div>
          </div>` : ''}

        <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
          <label class="text-sm font-medium text-gray-700">Latitude
            <input id="editPickupLat" type="number" step="0.000001" value="${escapeHtml(order.origin_lat ?? '')}" class="mt-1 w-full border border-gray-200 rounded-xl px-3 py-2 text-sm" />
          </label>
          <label class="text-sm font-medium text-gray-700">Longitude
            <input id="editPickupLng" type="number" step="0.000001" value="${escapeHtml(order.origin_lng ?? '')}" class="mt-1 w-full border border-gray-200 rounded-xl px-3 py-2 text-sm" />
          </label>
        </div>
        <label class="text-sm font-medium text-gray-700">ชื่อ/ที่อยู่จุดรับ
          <input id="editPickupAddress" type="text" value="${escapeHtml(order.pickup_address || '')}" class="mt-1 w-full border border-gray-200 rounded-xl px-3 py-2 text-sm" />
        </label>
        <div class="flex flex-wrap items-center justify-between gap-2 pt-2">
          <a id="editPickupMapLink" href="https://www.google.com/maps/search/?api=1&query=${encodeURIComponent(`${order.origin_lat || ''},${order.origin_lng || ''}`)}" target="_blank" class="text-xs text-indigo-600 hover:underline">เปิดพิกัดปัจจุบันใน Google Maps</a>
          <div class="flex gap-2">
            <button onclick="document.getElementById('editPickupLocationModal')?.remove()" class="px-4 py-2 rounded-xl border border-gray-200 text-gray-600 text-sm font-semibold hover:bg-gray-50">ยกเลิก</button>
            <button onclick="submitPickupLocation('${orderId}')" class="px-4 py-2 rounded-xl bg-indigo-600 text-white text-sm font-semibold hover:bg-indigo-700">บันทึกพิกัด</button>
          </div>
        </div>
      </div>
    </div>`;

  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });

  globalThis._editPickupMerchantLocation = merchant ? {
    lat: _toNumber(merchant.latitude),
    lng: _toNumber(merchant.longitude),
    address: merchant.shop_address || merchant.full_name || '',
  } : null;
}

export function useMerchantPickupLocation() {
  const merchant = globalThis._editPickupMerchantLocation;
  if (!merchant || merchant.lat === null || merchant.lng === null) {
    alert('ร้านค้ายังไม่มีพิกัดที่ถูกต้องในโปรไฟล์');
    return;
  }
  const latEl = document.getElementById('editPickupLat');
  const lngEl = document.getElementById('editPickupLng');
  const addrEl = document.getElementById('editPickupAddress');
  if (latEl) latEl.value = merchant.lat;
  if (lngEl) lngEl.value = merchant.lng;
  if (addrEl && merchant.address) addrEl.value = merchant.address;
}

export async function showAdminAcceptModal(orderId, ctx) {
  _ctx = ctx || _ctx;
  const { supabase } = _deps();
  const escapeHtml = _escapeHtml;
  const fmt = _ctx?.fmt || globalThis.fmt || ((value) => value);

  const { data: order, error } = await supabase
    .from('bookings')
    .select('*')
    .eq('id', orderId)
    .maybeSingle();
  if (error) return alert(error.message || JSON.stringify(error));
  if (!order) return alert('ไม่พบออเดอร์');
  if (order.service_type !== 'food') return alert('รับแทนร้านใช้ได้เฉพาะออเดอร์อาหาร');

  const profileIds = [...new Set([order.customer_id, order.merchant_id].filter(Boolean))];
  const profileMap = {};
  if (profileIds.length) {
    const { data: profiles } = await supabase
      .from('profiles')
      .select('id, full_name, phone_number')
      .in('id', profileIds);
    (profiles || []).forEach((profile) => { profileMap[profile.id] = profile; });
  }

  const { data: items } = await supabase
    .from('booking_items')
    .select('*')
    .eq('booking_id', orderId);

  const customer = profileMap[order.customer_id];
  const merchant = profileMap[order.merchant_id];
  const merchantPhone = _profilePhone(merchant);
  const customerPhone = _profilePhone(customer);

  document.getElementById('adminAcceptModal')?.remove();
  const modal = document.createElement('div');
  modal.id = 'adminAcceptModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4';
  const merchantPhoneHtml = merchantPhone
    ? `<div class="mt-2 flex items-center gap-2"><a href="tel:${escapeHtml(merchantPhone)}" class="text-orange-700 font-semibold">${escapeHtml(merchantPhone)}</a><button onclick="copyAdminText('${escapeHtml(merchantPhone)}')" class="px-2 py-1 rounded-lg bg-white text-orange-600 border border-orange-100">Copy</button></div>`
    : '<p class="text-gray-400 mt-2">No merchant phone</p>';
  const customerPhoneHtml = customerPhone
    ? `<div class="mt-2 flex items-center gap-2"><a href="tel:${escapeHtml(customerPhone)}" class="text-blue-700 font-semibold">${escapeHtml(customerPhone)}</a><button onclick="copyAdminText('${escapeHtml(customerPhone)}')" class="px-2 py-1 rounded-lg bg-white text-blue-600 border border-blue-100">Copy</button></div>`
    : '<p class="text-gray-400 mt-2">No customer phone</p>';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-2xl fade-in max-h-[88vh] overflow-y-auto">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between sticky top-0 bg-white z-10">
        <div>
          <h3 class="font-bold text-gray-800 text-lg">รับออเดอร์แทนร้าน</h3>
          <p class="text-xs text-gray-400">ออเดอร์ #${escapeHtml(_shortOrderId(orderId))}</p>
        </div>
        <button onclick="document.getElementById('adminAcceptModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-5 space-y-4 text-sm">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3 text-xs">
          <div class="p-3 rounded-xl bg-orange-50 border border-orange-100">
            <p class="text-orange-500 mb-1 font-semibold">Merchant</p>
            <p class="font-bold text-orange-700">${escapeHtml(_profileName(merchant))}</p>
            ${merchantPhoneHtml}
          </div>
          <div class="p-3 rounded-xl bg-blue-50 border border-blue-100">
            <p class="text-blue-500 mb-1 font-semibold">Customer</p>
            <p class="font-bold text-blue-700">${escapeHtml(_profileName(customer))}</p>
            ${customerPhoneHtml}
          </div>
        </div>
        <div>
          <p class="text-xs font-semibold text-gray-500 mb-1.5">รายการอาหารสำหรับแจ้งร้าน</p>
          ${renderOrderItemRows(items || [], fmt, escapeHtml)}
        </div>
        ${renderAdminNote(order.admin_note, escapeHtml)}
        <div class="space-y-2 rounded-xl border border-gray-100 bg-gray-50 p-3 text-xs">
          <label class="flex items-center gap-2 text-gray-700">
            <input data-admin-accept-check type="checkbox" onchange="toggleAdminAcceptChecklist()" class="rounded border-gray-300" />
            Called merchant and confirmed the order.
          </label>
          <label class="flex items-center gap-2 text-gray-700">
            <input data-admin-accept-check type="checkbox" onchange="toggleAdminAcceptChecklist()" class="rounded border-gray-300" />
            Merchant reviewed every item and selected option.
          </label>
        </div>
        <label class="block text-xs font-semibold text-gray-600">Admin note
          <textarea id="adminAcceptNote" rows="3" class="mt-1 w-full border border-gray-200 rounded-xl px-3 py-2 text-sm" placeholder="เช่น โทรหาร้านแล้ว ร้านยืนยันรับออเดอร์">${escapeHtml(order.admin_note || '')}</textarea>
        </label>
        <div class="flex justify-end gap-2 pt-2">
          <button onclick="document.getElementById('adminAcceptModal')?.remove()" class="px-4 py-2 rounded-xl border border-gray-200 text-gray-600 text-sm font-semibold hover:bg-gray-50">ยกเลิก</button>
          <button id="adminAcceptSubmit" disabled onclick="submitAdminMerchantAcceptOrder('${orderId}')" class="px-4 py-2 rounded-xl bg-emerald-600 text-white text-sm font-semibold hover:bg-emerald-700 opacity-50 cursor-not-allowed">ยืนยันรับแทนร้าน</button>
        </div>
      </div>
    </div>`;

  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });
}

export async function submitAdminMerchantAcceptOrder(orderId, ctx) {
  _ctx = ctx || _ctx;
  const note = document.getElementById('adminAcceptNote')?.value || '';
  return await _adminActAsMerchantOrder(orderId, 'accept', note);
}

export async function submitPickupLocation(orderId, ctx) {
  _ctx = ctx || _ctx;
  const { supabase, showToast } = _deps();

  const lat = _toNumber(document.getElementById('editPickupLat')?.value);
  const lng = _toNumber(document.getElementById('editPickupLng')?.value);
  const address = (document.getElementById('editPickupAddress')?.value || '').trim();

  if (lat === null || lat < -90 || lat > 90) {
    alert('Latitude ไม่ถูกต้อง');
    return;
  }
  if (lng === null || lng < -180 || lng > 180) {
    alert('Longitude ไม่ถูกต้อง');
    return;
  }

  try {
    const updateData = {
      origin_lat: lat,
      origin_lng: lng,
      pickup_address: address || null,
      updated_at: new Date().toISOString(),
    };
    const { error } = await supabase
      .from('bookings')
      .update(updateData)
      .eq('id', orderId);
    if (error) throw error;

    document.getElementById('editPickupLocationModal')?.remove();
    showToast('อัปเดตพิกัด pickup สำเร็จ', 'success');
    await _refreshAdminOrderViews();
  } catch (e) {
    showToast('อัปเดตพิกัดไม่สำเร็จ: ' + (e.message || JSON.stringify(e)), 'error');
  }
}

async function _adminActAsMerchantOrder(orderId, action, adminNote = '') {
  const { supabase, showToast } = _deps();

  const isAccept = action === 'accept';
  const confirmText = isAccept
    ? `ให้แอดมินรับออเดอร์ #${orderId.substring(0, 8)} แทนร้านค้า?`
    : `ให้อัปเดตออเดอร์ #${orderId.substring(0, 8)} เป็น "อาหารพร้อม" แทนร้านค้า?`;

  if (!isAccept && !confirm(confirmText)) return;

  try {
    const nowIso = new Date().toISOString();
    const { data: booking, error: bookingError } = await supabase
      .from('bookings')
      .select('id, status, service_type, merchant_id, customer_id, driver_id')
      .eq('id', orderId)
      .maybeSingle();

    if (bookingError) throw bookingError;
    if (!booking) throw new Error('ไม่พบออเดอร์ที่ต้องการ');
    if (booking.service_type !== 'food') {
      throw new Error('ฟีเจอร์นี้ใช้ได้เฉพาะออเดอร์อาหารเท่านั้น');
    }

    const acceptStatuses = globalThis.ADMIN_MERCHANT_ACCEPT_STATUSES;
    let updatedRows = [];

    if (isAccept) {
      let updateQuery = supabase
        .from('bookings')
        .update({
          status: 'preparing',
          admin_note: String(adminNote || '').trim() || null,
          updated_at: nowIso,
        })
        .eq('id', orderId);
      if (Array.isArray(acceptStatuses) && acceptStatuses.length) {
        updateQuery = updateQuery.in('status', acceptStatuses);
      }
      const { data, error: updateError } = await updateQuery.select('id, status');
      if (updateError) throw updateError;
      updatedRows = data || [];
    } else {
      const { data: rpcResult, error: rpcError } = await supabase.rpc('mark_food_ready_guarded', {
        p_booking_id: orderId,
        p_merchant_id: booking.merchant_id,
      });
      if (rpcError) throw rpcError;
      if (rpcResult?.success !== true) {
        throw new Error(rpcResult?.error || 'ไม่สามารถอัปเดตเป็นอาหารพร้อมได้ในสถานะปัจจุบัน');
      }
      updatedRows = [{ id: orderId, status: rpcResult.status, pending_driver_arrival: rpcResult.pending_driver_arrival }];
    }

    if (!updatedRows?.length) {
      throw new Error(
        isAccept
          ? 'ออเดอร์ไม่ได้อยู่ในสถานะรอร้านค้ารับแล้ว กรุณารีเฟรชข้อมูล'
          : 'ไม่สามารถอัปเดตเป็นอาหารพร้อมได้ในสถานะปัจจุบัน',
      );
    }

    const shortId = orderId.substring(0, 8);
    const pendingDriverArrival = !isAccept && updatedRows[0]?.pending_driver_arrival === true;
    const notifyRows = [];
    if (booking.merchant_id) {
      notifyRows.push({
        user_id: booking.merchant_id,
        title: isAccept ? '🛠️ แอดมินรับออเดอร์แทนร้าน' : '✅ แอดมินกดอาหารพร้อมแทนร้าน',
        body: isAccept
          ? `ออเดอร์ #${shortId} ถูกแอดมินรับแทนร้านค้าแล้ว`
          : pendingDriverArrival
            ? `ออเดอร์ #${shortId} ถูกบันทึกว่าอาหารพร้อมแล้ว และรอคนขับถึงร้าน`
            : `ออเดอร์ #${shortId} ถูกแอดมินอัปเดตเป็นอาหารพร้อมแล้ว`,
        type: isAccept ? 'admin_accept_order_for_merchant' : 'admin_mark_food_ready_for_merchant',
        data: {
          type: isAccept ? 'admin_accept_order_for_merchant' : 'admin_mark_food_ready_for_merchant',
          booking_id: orderId,
          merchant_id: booking.merchant_id,
        },
      });
    }
    if (booking.customer_id) {
      notifyRows.push({
        user_id: booking.customer_id,
        title: isAccept ? '🍳 ร้านค้าเริ่มเตรียมอาหารแล้ว' : '🍱 อาหารพร้อมจัดส่งแล้ว',
        body: isAccept
          ? `ออเดอร์ #${shortId} กำลังอยู่ระหว่างการเตรียมอาหาร`
          : pendingDriverArrival
            ? `ออเดอร์ #${shortId} เตรียมเสร็จแล้ว กำลังรอคนขับถึงร้าน`
            : `ออเดอร์ #${shortId} พร้อมให้คนขับไปรับแล้ว`,
        type: isAccept ? 'admin_customer_order_preparing' : 'admin_customer_food_ready',
        data: {
          type: isAccept ? 'admin_customer_order_preparing' : 'admin_customer_food_ready',
          booking_id: orderId,
        },
      });
    }
    if (booking.driver_id) {
      notifyRows.push({
        user_id: booking.driver_id,
        title: isAccept ? '🏪 ร้านค้ารับออเดอร์แล้ว' : '🍱 อาหารพร้อมรับแล้ว',
        body: isAccept
          ? `ออเดอร์ #${shortId} ร้านค้าเริ่มเตรียมอาหารแล้ว`
          : `ออเดอร์ #${shortId} ร้านค้าแจ้งว่าอาหารพร้อมรับแล้ว`,
        type: isAccept ? 'admin_driver_order_preparing' : 'admin_driver_food_ready',
        data: {
          type: isAccept ? 'admin_driver_order_preparing' : 'admin_driver_food_ready',
          booking_id: orderId,
        },
      });
    }

    if (typeof globalThis._notifyAdminActionTargets === 'function') {
      await globalThis._notifyAdminActionTargets(notifyRows);
    }

    document.getElementById('adminAcceptModal')?.remove();
    showToast(isAccept ? 'แอดมินรับออเดอร์แทนร้านสำเร็จ' : 'แอดมินอัปเดตเป็นอาหารพร้อมสำเร็จ', 'success');
    await _refreshAdminOrderViews();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + (e.message || JSON.stringify(e)), 'error');
  }
}

async function _applyAdminOrderReassign(orderId, newDriverId, updateFields = {}) {
  const { callAdminAction } = _deps();
  await callAdminAction({ action: 'reassign_order', order_id: orderId, new_driver_id: newDriverId, update_fields: updateFields });
}

export async function showReassignModal(orderId, currentDriverName, ctx) {
  _ctx = ctx || _ctx;
  const { supabase, escapeHtml } = _deps();

  const { data: booking } = await supabase
    .from('bookings')
    .select('driver_id')
    .eq('id', orderId)
    .maybeSingle();
  const currentDriverId = booking?.driver_id || null;

  let driverQuery = supabase
    .from('profiles')
    .select('id, full_name, phone_number, license_plate, is_online')
    .eq('role', 'driver')
    .eq('approval_status', 'approved')
    .order('full_name');

  if (currentDriverId) {
    driverQuery = driverQuery.neq('id', currentDriverId);
  }

  const { data: drivers } = await driverQuery;
  if (!drivers || !drivers.length) return alert('ไม่พบคนขับที่อนุมัติแล้ว');

  const driverIds = drivers.map(d => d.id).filter(Boolean);
  const { data: driverLocs } = driverIds.length
    ? await supabase
      .from('driver_locations')
      .select('driver_id, is_online')
      .in('driver_id', driverIds)
    : { data: [] };
  const locMap = {};
  (driverLocs || []).forEach(d => { locMap[d.driver_id] = d; });
  const truthyFlag = globalThis._truthyFlag;
  const onlineDrivers = drivers.filter(d => {
    const loc = locMap[d.id];
    const profileOnline = typeof truthyFlag === 'function' ? truthyFlag(d.is_online) : !!d.is_online;
    const locOnline = loc ? (typeof truthyFlag === 'function' ? truthyFlag(loc.is_online) : !!loc.is_online) : false;
    return profileOnline || locOnline;
  });
  if (!onlineDrivers.length) return alert('ไม่มีคนขับออนไลน์คนอื่น');

  const modal = document.createElement('div');
  modal.id = 'reassignModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 fade-in">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <div>
          <h3 class="font-bold text-gray-800 text-lg">ย้ายออเดอร์ให้คนขับอื่น</h3>
          <p class="text-xs text-gray-500 mt-1">ออเดอร์ #${orderId.substring(0,8)} — คนขับปัจจุบัน: ${currentDriverName || 'ยังไม่มี'}</p>
        </div>
        <button onclick="document.getElementById('reassignModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-6 max-h-[60vh] overflow-y-auto">
        <input type="text" id="reassignSearch" placeholder="ค้นหาคนขับ..." class="w-full border rounded-lg px-3 py-2 text-sm mb-3" oninput="filterReassignDrivers()" />
        <div id="reassignDriverList">
          ${onlineDrivers.map(d => `
            <div class="reassign-driver-item flex items-center justify-between p-3 rounded-lg hover:bg-blue-50 cursor-pointer border border-gray-100 mb-2 transition-colors" data-name="${(d.full_name||'').toLowerCase()}" onclick="reassignOrder('${orderId}','${d.id}','${(d.full_name||'').replace(/'/g,'')}')">
              <div class="flex items-center gap-3">
                <div class="w-9 h-9 bg-blue-100 rounded-full flex items-center justify-center"><span class="material-icons-round text-blue-600 text-sm">person</span></div>
                <div>
                  <p class="font-medium text-sm">${escapeHtml(d.full_name) || '-'}</p>
                  <p class="text-xs text-gray-500">${escapeHtml(d.phone_number) || ''} ${d.license_plate ? '• '+escapeHtml(d.license_plate) : ''}</p>
                </div>
              </div>
              <span class="material-icons-round text-gray-300 text-lg">chevron_right</span>
            </div>
          `).join('')}
        </div>
      </div>
    </div>`;

  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });
}

export function filterReassignDrivers() {
  const q = (document.getElementById('reassignSearch')?.value || '').toLowerCase();
  document.querySelectorAll('.reassign-driver-item').forEach(el => {
    el.style.display = el.dataset.name.includes(q) ? '' : 'none';
  });
}

export async function reassignOrder(orderId, newDriverId, driverName, ctx) {
  _ctx = ctx || _ctx;
  const { showToast } = _deps();

  if (!confirm(`ย้ายออเดอร์ #${orderId.substring(0,8)} ให้ "${driverName}" ?`)) return;
  try {
    await _applyAdminOrderReassign(orderId, newDriverId, { status: 'driver_accepted' });
    document.getElementById('reassignModal')?.remove();
    showToast('ย้ายออเดอร์สำเร็จ!', 'success');
    if (typeof globalThis.loadOrders === 'function') {
      await globalThis.loadOrders();
    }
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + (e.message || JSON.stringify(e)), 'error');
  }
}

export async function forceCancelOrder(orderId, customerId, price, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml } = _deps();

  const reason = prompt('เหตุผลที่ยกเลิก (ฉุกเฉิน):');
  if (!reason) return;
  const doRefund = confirm('คืนเงินเข้า Wallet ลูกค้าด้วยหรือไม่?');
  try {
    await callAdminAction({ action: 'force_cancel_order', order_id: orderId, customer_id: customerId, price, reason, do_refund: doRefund });
    showToast('ยกเลิกออเดอร์สำเร็จ!' + (doRefund ? ' (คืนเงินแล้ว)' : ''), 'success');
    if (typeof globalThis.loadOrders === 'function') {
      await globalThis.loadOrders();
    }
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function rebroadcastOrder(orderId, serviceType, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml } = _deps();

  if (!confirm(`โยนออเดอร์ #${orderId.substring(0,8)} ใหม่?\n\nระบบจะลบคนขับเดิมออก แล้วโยนออเดอร์ให้คนขับทุกคนเห็นอีกครั้ง`)) return;
  try {
    await callAdminAction({ action: 'rebroadcast_order', order_id: orderId, service_type: serviceType });
    showToast('โยนออเดอร์ใหม่สำเร็จ! คนขับทุกคนจะเห็นออเดอร์นี้', 'success');
    if (typeof globalThis.loadOrders === 'function') {
      await globalThis.loadOrders();
    }
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message || JSON.stringify(e)), 'error');
  }
}

function _normalizeDraftItem(item, menuItems = []) {
  const menuItemId = item.menu_item_id || item.id || '';
  const menuItem = menuItems.find((m) => m.id === menuItemId);
  return {
    draft_id: item.draft_id || (globalThis.crypto?.randomUUID ? globalThis.crypto.randomUUID() : `${Date.now()}-${Math.random()}`),
    menu_item_id: menuItemId,
    name: item.name || item.menu_name || menuItem?.name || '',
    quantity: Math.max(1, Number.parseInt(item.quantity || 1, 10) || 1),
    price: Number(item.price || item.unit_price || menuItem?.price || 0) || 0,
    selected_options: item.selected_options || [],
    note: item.note || '',
  };
}

function _renderEditOrderItemsDraft() {
  const state = globalThis._editOrderItemsState;
  if (!state) return;
  const { fmt, escapeHtml } = state;
  const draftEl = document.getElementById('editOrderItemsDraft');
  const diffEl = document.getElementById('editOrderItemsPriceDiff');
  if (!draftEl || !diffEl) return;

  const menuOptions = state.menuItems.map((menuItem) => (
    `<option value="${escapeHtml(menuItem.id)}">${escapeHtml(menuItem.name || '-')} · ฿${fmt(Math.round(menuItem.price || 0))}</option>`
  )).join('');

  draftEl.innerHTML = state.draftItems.map((item, index) => `
    <div class="p-3 rounded-xl border border-gray-100 bg-gray-50 space-y-2" data-index="${index}">
      <div class="flex items-center gap-2">
        <select onchange="editOrderItemsSwap(${index}, this.value)" class="flex-1 border border-gray-200 rounded-lg px-2 py-1.5 text-xs bg-white">
          ${menuOptions}
        </select>
        <button onclick="editOrderItemsRemove(${index})" class="px-2 py-1.5 rounded-lg bg-red-100 text-red-600 text-xs font-semibold">Remove</button>
      </div>
      <div class="grid grid-cols-2 gap-2">
        <label class="text-[11px] text-gray-500">Qty
          <input type="number" min="1" value="${escapeHtml(item.quantity)}" oninput="editOrderItemsUpdate(${index}, 'quantity', this.value)" class="mt-1 w-full border border-gray-200 rounded-lg px-2 py-1.5 text-xs bg-white" />
        </label>
        <label class="text-[11px] text-gray-500">Price
          <input type="number" min="0" step="1" value="${escapeHtml(item.price)}" oninput="editOrderItemsUpdate(${index}, 'price', this.value)" class="mt-1 w-full border border-gray-200 rounded-lg px-2 py-1.5 text-xs bg-white" />
        </label>
      </div>
      <label class="block text-[11px] text-gray-500">Options JSON
        <textarea rows="2" oninput="editOrderItemsUpdate(${index}, 'selected_options_text', this.value)" class="mt-1 w-full border border-gray-200 rounded-lg px-2 py-1.5 text-xs bg-white">${escapeHtml(JSON.stringify(item.selected_options || []))}</textarea>
      </label>
      <label class="block text-[11px] text-gray-500">Item note
        <input type="text" value="${escapeHtml(item.note || '')}" oninput="editOrderItemsUpdate(${index}, 'note', this.value)" class="mt-1 w-full border border-gray-200 rounded-lg px-2 py-1.5 text-xs bg-white" />
      </label>
    </div>
  `).join('') || '<div class="text-xs text-red-500">ต้องมีอย่างน้อย 1 รายการ</div>';

  state.draftItems.forEach((item, index) => {
    const select = draftEl.querySelector(`[data-index="${index}"] select`);
    if (select) select.value = item.menu_item_id;
  });

  const change = getOrderItemsPriceChange({
    originalTotal: state.originalTotal,
    items: state.draftItems,
    paymentMethod: state.paymentMethod,
  });
  diffEl.className = `p-3 rounded-xl border text-xs font-semibold ${change.toneClass}`;
  diffEl.textContent = `${change.message} · New food total ฿${fmt(change.newTotal)}`;
}

export function editOrderItemsSwap(index, menuItemId) {
  const state = globalThis._editOrderItemsState;
  if (!state?.draftItems[index]) return;
  const menuItem = state.menuItems.find((item) => item.id === menuItemId);
  if (!menuItem) return;
  state.draftItems[index] = _normalizeDraftItem({
    ...state.draftItems[index],
    menu_item_id: menuItem.id,
    name: menuItem.name,
    price: menuItem.price,
    selected_options: [],
  }, state.menuItems);
  _renderEditOrderItemsDraft();
}

export function editOrderItemsAdd() {
  const state = globalThis._editOrderItemsState;
  const menuItem = state?.menuItems?.[0];
  if (!state || !menuItem) return;
  state.draftItems.push(_normalizeDraftItem({
    menu_item_id: menuItem.id,
    name: menuItem.name,
    price: menuItem.price,
    quantity: 1,
    selected_options: [],
  }, state.menuItems));
  _renderEditOrderItemsDraft();
}

export function editOrderItemsRemove(index) {
  const state = globalThis._editOrderItemsState;
  if (!state) return;
  state.draftItems.splice(index, 1);
  _renderEditOrderItemsDraft();
}

export function editOrderItemsUpdate(index, field, value) {
  const state = globalThis._editOrderItemsState;
  const item = state?.draftItems[index];
  if (!item) return;
  if (field === 'quantity') item.quantity = Math.max(1, Number.parseInt(value || 1, 10) || 1);
  else if (field === 'price') item.price = Number(value || 0) || 0;
  else if (field === 'selected_options_text') item.selected_options = _parseJsonInput(value, []);
  else item[field] = value;
  _renderEditOrderItemsDraft();
}

export async function showEditOrderItemsModal(orderId, ctx) {
  _ctx = ctx || _ctx;
  const { supabase } = _deps();
  const escapeHtml = _escapeHtml;
  const fmt = _ctx?.fmt || globalThis.fmt || ((value) => value);

  const { data: order, error } = await supabase
    .from('bookings')
    .select('id, status, service_type, merchant_id, customer_id, payment_method, price, admin_note')
    .eq('id', orderId)
    .maybeSingle();
  if (error) return alert(error.message || JSON.stringify(error));
  if (!order) return alert('ไม่พบออเดอร์');
  if (order.service_type !== 'food') return alert('แก้รายการได้เฉพาะออเดอร์อาหาร');

  const [{ data: items }, { data: menuItems }] = await Promise.all([
    supabase.from('booking_items').select('*').eq('booking_id', orderId),
    supabase.from('menu_items')
      .select('id, merchant_id, name, price, is_available, options, category')
      .eq('merchant_id', order.merchant_id)
      .eq('is_available', true)
      .order('name'),
  ]);
  if (!menuItems?.length) return alert('ไม่พบเมนูที่เปิดขายของร้านนี้');

  globalThis._editOrderItemsState = {
    orderId,
    originalTotal: Number(order.price || 0),
    paymentMethod: order.payment_method || '',
    menuItems,
    draftItems: (items || []).map((item) => _normalizeDraftItem(item, menuItems)),
    fmt,
    escapeHtml,
  };

  document.getElementById('editOrderItemsModal')?.remove();
  const modal = document.createElement('div');
  modal.id = 'editOrderItemsModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50 p-4';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-3xl fade-in max-h-[90vh] overflow-y-auto">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between sticky top-0 bg-white z-10">
        <div>
          <h3 class="font-bold text-gray-800 text-lg">แก้ไขรายการอาหาร</h3>
          <p class="text-xs text-gray-400">ออเดอร์ #${escapeHtml(_shortOrderId(orderId))} · original food ฿${fmt(Math.round(order.price || 0))}</p>
        </div>
        <button onclick="document.getElementById('editOrderItemsModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-5 space-y-4">
        <div id="editOrderItemsDraft" class="space-y-3"></div>
        <button onclick="editOrderItemsAdd()" class="px-3 py-2 rounded-xl bg-indigo-50 text-indigo-700 text-xs font-semibold">+ เพิ่มรายการจากเมนูร้าน</button>
        <div id="editOrderItemsPriceDiff"></div>
        ${renderAdminNote(order.admin_note, escapeHtml)}
        <label class="block text-xs font-semibold text-gray-600">บันทึกเหตุผล
          <textarea id="editOrderItemsAdminNote" rows="3" class="mt-1 w-full border border-gray-200 rounded-xl px-3 py-2 text-sm" placeholder="เช่น ร้านแจ้งว่าสินค้าหมด เปลี่ยนรายการตามที่ลูกค้ายืนยัน">${escapeHtml(order.admin_note || '')}</textarea>
        </label>
        <div class="flex justify-end gap-2 pt-2">
          <button onclick="document.getElementById('editOrderItemsModal')?.remove()" class="px-4 py-2 rounded-xl border border-gray-200 text-gray-600 text-sm font-semibold hover:bg-gray-50">ยกเลิก</button>
          <button onclick="submitEditOrderItems()" class="px-4 py-2 rounded-xl bg-indigo-600 text-white text-sm font-semibold hover:bg-indigo-700">ยืนยันการแก้ไข</button>
        </div>
      </div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });
  _renderEditOrderItemsDraft();
}

export async function submitEditOrderItems(ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast } = _deps();
  const state = globalThis._editOrderItemsState;
  if (!state) return;
  const newItems = buildOrderItemsPayload(state.draftItems);
  const validation = validateOrderItemsPayload(newItems);
  if (!validation.ok) {
    const message = validation.error === 'order_items_required'
      ? 'ต้องมีอย่างน้อย 1 รายการ ถ้าต้องการลบทั้งหมดให้ยกเลิกออเดอร์แทน'
      : `ข้อมูลรายการไม่ถูกต้อง: ${validation.error}`;
    return alert(message);
  }

  try {
    const adminNote = document.getElementById('editOrderItemsAdminNote')?.value || '';
    await callAdminAction({
      action: 'edit_order_items',
      booking_id: state.orderId,
      new_items: newItems,
      admin_note: adminNote,
    });
    document.getElementById('editOrderItemsModal')?.remove();
    showToast('แก้ไขรายการอาหารสำเร็จ', 'success');
    await _refreshAdminOrderViews();
  } catch (e) {
    showToast('แก้ไขรายการไม่สำเร็จ: ' + (e.message || JSON.stringify(e)), 'error');
  }
}

export async function showOrderDetail(orderId, ctx) {
  _ctx = ctx || _ctx;
  const { supabase } = _deps();
  const escapeHtml = _escapeHtml;
  const fmt = _ctx?.fmt || globalThis.fmt || ((value) => value);
  const fmtDate = _ctx?.fmtDate || globalThis.fmtDate || ((value) => value || '-');
  const statusBadge = _ctx?.statusBadge || globalThis.statusBadge || ((value) => value || '-');
  const serviceIcon = _ctx?.serviceIcon || globalThis.serviceIcon || (() => '');

  const { data: order, error } = await supabase
    .from('bookings')
    .select('*')
    .eq('id', orderId)
    .maybeSingle();

  if (error) return alert(error.message || JSON.stringify(error));
  if (!order) return alert('Order not found');

  const profileIds = [...new Set([order.customer_id, order.driver_id, order.merchant_id].filter(Boolean))];
  const profileMap = {};
  if (profileIds.length) {
    const { data: profiles } = await supabase
      .from('profiles')
      .select('id, full_name, phone_number')
      .in('id', profileIds);
    (profiles || []).forEach((profile) => {
      profileMap[profile.id] = {
        name: profile.full_name || profile.id.substring(0, 8),
        phone: profile.phone_number || '',
      };
    });
  }

  let itemsHtml = '';
  if (order.service_type === 'food') {
    const { data: items, error: itemsError } = await supabase
      .from('booking_items')
      .select('*')
      .eq('booking_id', orderId);
    if (itemsError) {
      itemsHtml = `<div class="text-xs text-red-500">Could not load items: ${escapeHtml(itemsError.message || JSON.stringify(itemsError))}</div>`;
    } else if (items && items.length) {
      itemsHtml = `
        <div class="border-t border-gray-100 pt-3">
          <p class="text-xs font-semibold text-gray-500 mb-1.5">Food items</p>
          ${renderOrderItemRows(items, fmt, escapeHtml)}
        </div>`;
    }
  }

  const customer = profileMap[order.customer_id];
  const driver = profileMap[order.driver_id];
  const merchant = profileMap[order.merchant_id];
  const dName = driver?.name || globalThis._orderDriverMap?.[order.driver_id] || (order.driver_id ? order.driver_id.substring(0, 8) : '-');
  const totalAmount = Number(order.price || 0) + Number(order.delivery_fee || 0);
  const canReassign = ['pending','preparing','driver_accepted','accepted','matched','pending_merchant','arrived_at_merchant','ready_for_pickup'].includes(order.status);
  const canRebroadcast = ['pending','pending_merchant','driver_accepted','accepted','matched','preparing','arrived_at_merchant','ready_for_pickup'].includes(order.status);
  const canAdminAccept = typeof globalThis._canAdminMerchantAccept === 'function' ? globalThis._canAdminMerchantAccept(order) : false;
  const canAdminReady = typeof globalThis._canAdminMarkFoodReady === 'function' ? globalThis._canAdminMarkFoodReady(order) : false;
  const canEditPickup = order.status !== 'completed' && order.status !== 'cancelled';
  const canEditItems = order.service_type === 'food' && ['pending_merchant', 'accepted', 'preparing'].includes(order.status);
  const canCancel = order.status !== 'completed' && order.status !== 'cancelled';

  document.getElementById('orderDetailModal')?.remove();
  const modal = document.createElement('div');
  modal.id = 'orderDetailModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-2xl mx-4 fade-in max-h-[88vh] overflow-y-auto">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between sticky top-0 bg-white z-10">
        <div>
          <h3 class="font-bold text-gray-800">Order #${escapeHtml(_shortOrderId(orderId))}</h3>
          <p class="text-xs text-gray-400">${escapeHtml(fmtDate(order.created_at))}</p>
        </div>
        <button onclick="document.getElementById('orderDetailModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-5 space-y-4">
        <div class="flex items-center gap-3 flex-wrap">
          ${serviceIcon(order.service_type)}
          ${statusBadge(order.status)}
          <span class="text-lg font-bold text-gray-800">฿${fmt(Math.round(totalAmount))}</span>
          ${order.service_type === 'food' ? `<span class="text-xs text-blue-500 bg-blue-50 px-2 py-0.5 rounded-full">Food ฿${fmt(Math.round(order.price || 0))} + Delivery ฿${fmt(Math.round(order.delivery_fee || 0))}</span>` : ''}
        </div>
        <div class="grid grid-cols-1 md:grid-cols-3 gap-3 text-xs">
          ${renderContactCard('person', 'Customer', customer, '', escapeHtml)}
          ${renderContactCard('two_wheeler', 'Driver', driver || { name: dName }, driver ? 'text-blue-600' : 'text-red-500', escapeHtml)}
          ${merchant ? renderContactCard('store', 'Merchant', merchant, 'text-orange-600', escapeHtml) : '<div class="p-3 rounded-xl bg-gray-50 text-gray-400">No merchant</div>'}
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-3 text-xs">
          <div class="p-3 rounded-xl bg-gray-50">
            <p class="text-gray-400 mb-1">Pickup</p>
            <p class="font-medium text-gray-700">${escapeHtml(order.pickup_address || '-')}</p>
            <p class="text-[11px] text-gray-400 mt-1">${escapeHtml(_coordText(order.origin_lat, order.origin_lng))}</p>
          </div>
          <div class="p-3 rounded-xl bg-gray-50">
            <p class="text-gray-400 mb-1">Destination</p>
            <p class="font-medium text-gray-700">${escapeHtml(order.destination_address || '-')}</p>
            <p class="text-[11px] text-gray-400 mt-1">${escapeHtml(_coordText(order.dest_lat, order.dest_lng))}</p>
          </div>
        </div>
        ${itemsHtml}
        ${renderAdminNote(order.admin_note, escapeHtml)}
        <div class="flex gap-2 pt-2 flex-wrap">
          ${canEditPickup ? `<button onclick="showEditPickupLocationModal('${orderId}')" class="min-h-[44px] px-4 py-2 bg-blue-100 text-blue-600 rounded-lg text-xs font-semibold">Edit pickup</button>` : ''}
          ${canEditItems ? `<button onclick="showEditOrderItemsModal('${orderId}')" class="min-h-[44px] px-4 py-2 bg-indigo-100 text-indigo-700 rounded-lg text-xs font-semibold">Edit items</button>` : ''}
          ${canRebroadcast ? `<button onclick="rebroadcastOrder('${orderId}','${order.service_type}')" class="min-h-[44px] px-4 py-2 bg-purple-100 text-purple-700 rounded-lg text-xs font-semibold">Rebroadcast</button>` : ''}
          ${canReassign ? `<button onclick="showReassignModal('${orderId}','${escapeHtml(String(dName).replace(/'/g, ''))}')" class="min-h-[44px] px-4 py-2 bg-orange-100 text-orange-700 rounded-lg text-xs font-semibold">Reassign</button>` : ''}
          ${canAdminAccept ? `<button onclick="adminMerchantAcceptOrder('${orderId}')" class="min-h-[44px] px-4 py-2 bg-emerald-500 text-white rounded-lg text-xs font-semibold">Accept as merchant</button>` : ''}
          ${canAdminReady ? `<button onclick="adminMarkFoodReady('${orderId}')" class="min-h-[44px] px-4 py-2 bg-teal-500 text-white rounded-lg text-xs font-semibold">Mark food ready</button>` : ''}
          ${canCancel ? `<button onclick="forceCancelOrder('${orderId}','${order.customer_id || ''}',${Math.round(order.price || 0)})" class="min-h-[44px] px-4 py-2 bg-red-100 text-red-600 rounded-lg text-xs font-semibold">Cancel</button>` : ''}
        </div>
      </div>
    </div>`;

  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });
}

export function wireOrdersActionsBridge() {
  const bridge = {
    adminMerchantAcceptOrder,
    adminMarkFoodReady,
    copyAdminText,
    toggleAdminAcceptChecklist,
    showAdminAcceptModal,
    submitAdminMerchantAcceptOrder,
    showEditOrderItemsModal,
    editOrderItemsSwap,
    editOrderItemsAdd,
    editOrderItemsRemove,
    editOrderItemsUpdate,
    submitEditOrderItems,
    showEditPickupLocationModal,
    useMerchantPickupLocation,
    submitPickupLocation,
    showReassignModal,
    filterReassignDrivers,
    reassignOrder,
    forceCancelOrder,
    rebroadcastOrder,
    showOrderDetail,
  };
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  Object.assign(globalThis.__adminWebBridge, bridge);
  Object.assign(globalThis, bridge);
}
