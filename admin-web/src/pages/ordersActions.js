let _ctx = null;

function _deps() {
  const supabase = _ctx?.supabase || globalThis.supabase;
  const callAdminAction = _ctx?.callAdminAction || globalThis.callAdminAction;
  const showToast = _ctx?.showToast || globalThis.showToast;
  const escapeHtml = _ctx?.escapeHtml || globalThis.escapeHtml;

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
  return await _adminActAsMerchantOrder(orderId, 'accept');
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

function _coordText(lat, lng) {
  const la = _toNumber(lat);
  const ln = _toNumber(lng);
  if (la === null || ln === null) return '-';
  return `${la.toFixed(6)}, ${ln.toFixed(6)}`;
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

async function _adminActAsMerchantOrder(orderId, action) {
  const { supabase, showToast } = _deps();

  const isAccept = action === 'accept';
  const confirmText = isAccept
    ? `ให้แอดมินรับออเดอร์ #${orderId.substring(0, 8)} แทนร้านค้า?`
    : `ให้อัปเดตออเดอร์ #${orderId.substring(0, 8)} เป็น "อาหารพร้อม" แทนร้านค้า?`;

  if (!confirm(confirmText)) return;

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

    let updateQuery = supabase
      .from('bookings')
      .update({
        status: isAccept ? 'preparing' : 'ready_for_pickup',
        updated_at: nowIso,
      })
      .eq('id', orderId);

    const acceptStatuses = globalThis.ADMIN_MERCHANT_ACCEPT_STATUSES;
    const readyStatuses = globalThis.ADMIN_MERCHANT_READY_STATUSES;

    if (isAccept) {
      if (Array.isArray(acceptStatuses) && acceptStatuses.length) {
        updateQuery = updateQuery.in('status', acceptStatuses);
      }
    } else {
      if (Array.isArray(readyStatuses) && readyStatuses.length) {
        updateQuery = updateQuery.in('status', readyStatuses);
      }
    }

    const { data: updatedRows, error: updateError } = await updateQuery.select('id, status');
    if (updateError) throw updateError;
    if (!updatedRows?.length) {
      throw new Error(
        isAccept
          ? 'ออเดอร์ไม่ได้อยู่ในสถานะรอร้านค้ารับแล้ว กรุณารีเฟรชข้อมูล'
          : 'ไม่สามารถอัปเดตเป็นอาหารพร้อมได้ในสถานะปัจจุบัน',
      );
    }

    const shortId = orderId.substring(0, 8);
    const notifyRows = [];
    if (booking.merchant_id) {
      notifyRows.push({
        user_id: booking.merchant_id,
        title: isAccept ? '🛠️ แอดมินรับออเดอร์แทนร้าน' : '✅ แอดมินกดอาหารพร้อมแทนร้าน',
        body: isAccept
          ? `ออเดอร์ #${shortId} ถูกแอดมินรับแทนร้านค้าแล้ว`
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
    .select('id, full_name, phone_number, license_plate')
    .eq('role', 'driver')
    .eq('approval_status', 'approved')
    .order('full_name');

  if (currentDriverId) {
    driverQuery = driverQuery.neq('id', currentDriverId);
  }

  const { data: drivers } = await driverQuery;
  if (!drivers || !drivers.length) return alert('ไม่พบคนขับที่อนุมัติแล้ว');

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
          ${drivers.map(d => `
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

export function wireOrdersActionsBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  globalThis.__adminWebBridge.adminMerchantAcceptOrder = adminMerchantAcceptOrder;
  globalThis.__adminWebBridge.adminMarkFoodReady = adminMarkFoodReady;
  globalThis.__adminWebBridge.showEditPickupLocationModal = showEditPickupLocationModal;
  globalThis.__adminWebBridge.useMerchantPickupLocation = useMerchantPickupLocation;
  globalThis.__adminWebBridge.submitPickupLocation = submitPickupLocation;
  globalThis.__adminWebBridge.showReassignModal = showReassignModal;
  globalThis.__adminWebBridge.filterReassignDrivers = filterReassignDrivers;
  globalThis.__adminWebBridge.reassignOrder = reassignOrder;
  globalThis.__adminWebBridge.forceCancelOrder = forceCancelOrder;
  globalThis.__adminWebBridge.rebroadcastOrder = rebroadcastOrder;
}
