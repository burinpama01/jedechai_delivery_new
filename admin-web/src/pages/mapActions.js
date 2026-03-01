let _ctx = null;

function _deps() {
  const supabase = _ctx?.supabase || globalThis.supabase;
  const callAdminAction = _ctx?.callAdminAction || globalThis.callAdminAction;
  const showToast = _ctx?.showToast || globalThis.showToast;
  const escapeHtml = _ctx?.escapeHtml || globalThis.escapeHtml;
  const fmt = _ctx?.fmt || globalThis.fmt;

  return { supabase, callAdminAction, showToast, escapeHtml, fmt };
}

export async function pendingDispatch(orderId, excludeDriverId, ctx) {
  _ctx = ctx || _ctx;
  const { supabase, escapeHtml } = _deps();

  const [{ data: allDrivers }, { data: driverLocs }, { data: activeBookings }] = await Promise.all([
    supabase.from('profiles').select('id, full_name, phone_number, license_plate, latitude, longitude').eq('role', 'driver').eq('approval_status', 'approved'),
    supabase.from('driver_locations').select('driver_id, is_online, is_available, location_lat, location_lng'),
    supabase.from('bookings').select('driver_id').in('status', ['driver_accepted','matched','preparing','arrived_at_merchant','ready_for_pickup','picking_up_order','in_transit']),
  ]);

  const locMap = {};
  (driverLocs || []).forEach(d => { locMap[d.driver_id] = d; });

  const truthyFlag = globalThis._truthyFlag;

  const onlineDrivers = (allDrivers || []).filter(d => {
    if (d.id === excludeDriverId) return false;
    const loc = locMap[d.id];
    const isOnline = loc ? (typeof truthyFlag === 'function' ? truthyFlag(loc.is_online) : !!loc.is_online) : true;
    return isOnline;
  });

  if (!onlineDrivers.length) return alert('ไม่มีคนขับออนไลน์');

  const jobCountMap = {};
  (activeBookings || []).forEach(b => {
    if (b.driver_id) jobCountMap[b.driver_id] = (jobCountMap[b.driver_id] || 0) + 1;
  });

  const { data: orderData } = await supabase.from('bookings').select('origin_lat, origin_lng').eq('id', orderId).single();
  const oLat = orderData?.origin_lat;
  const oLng = orderData?.origin_lng;

  const haversine = globalThis._haversineKm;

  const enriched = onlineDrivers.map(d => {
    const loc = locMap[d.id];
    const jobs = jobCountMap[d.id] || 0;
    const dLat = loc?.location_lat || d.latitude;
    const dLng = loc?.location_lng || d.longitude;
    let dist = null;
    if (oLat && oLng && dLat && dLng && typeof haversine === 'function') {
      dist = haversine(oLat, oLng, dLat, dLng);
    }
    return { ...d, jobs, dist, isAvailable: loc?.is_available };
  }).sort((a, b) => {
    if (a.jobs !== b.jobs) return a.jobs - b.jobs;
    if (a.dist !== null && b.dist !== null) return a.dist - b.dist;
    return 0;
  });

  const title = excludeDriverId ? 'ย้ายคนขับ' : 'โยนงาน';
  const modal = document.createElement('div');
  modal.id = 'pendingDispatchModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-md mx-4 fade-in">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <div>
          <h3 class="font-bold text-gray-800">${title} #${orderId.substring(0,8)}</h3>
          <p class="text-xs text-gray-400">${enriched.length} คนขับออนไลน์ ${excludeDriverId ? '(ไม่รวมคนเดิม)' : ''}</p>
        </div>
        <button onclick="document.getElementById('pendingDispatchModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-4 max-h-[50vh] overflow-y-auto space-y-1.5">
        ${enriched.map(d => {
          const jobBadge = d.jobs > 0
            ? `<span class="px-1.5 py-0.5 rounded text-[9px] font-bold bg-blue-100 text-blue-700">งาน ${d.jobs}</span>`
            : `<span class="px-1.5 py-0.5 rounded text-[9px] font-bold bg-green-100 text-green-700">ว่าง</span>`;
          const distLabel = d.dist !== null ? `<span class="text-[10px] text-gray-400">📏 ${d.dist.toFixed(1)} กม.</span>` : '';
          return `
            <div class="flex items-center gap-3 p-3 rounded-xl border border-gray-100 hover:border-blue-200 hover:bg-blue-50/50 cursor-pointer transition-all" onclick="pendingAssign('${orderId}','${d.id}','${(d.full_name||'-').replace(/'/g,'')}')">
              <div class="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold flex-shrink-0 ${d.jobs > 0 ? 'bg-blue-500' : 'bg-green-500'}">
                ${d.jobs > 0 ? d.jobs : '🏍'}
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium truncate">${escapeHtml(d.full_name)||'-'}</p>
                <p class="text-[10px] text-gray-400">${escapeHtml(d.license_plate)||''} • ${escapeHtml(d.phone_number)||''}</p>
              </div>
              <div class="flex flex-col items-end gap-0.5 flex-shrink-0">
                ${jobBadge}
                ${distLabel}
              </div>
            </div>`;
        }).join('')}
      </div>
    </div>`;

  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });
}

export async function pendingAssign(orderId, driverId, driverName, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml } = _deps();

  if (!confirm(`มอบหมาย #${orderId.substring(0,8)} ให้ "${driverName}" ?`)) return;
  try {
    await callAdminAction({ action: 'assign_order', order_id: orderId, driver_id: driverId });
    document.getElementById('pendingDispatchModal')?.remove();
    showToast('มอบหมายงานสำเร็จ!', 'success');
    if (typeof globalThis._refreshPendingOrders === 'function') await globalThis._refreshPendingOrders();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message || JSON.stringify(e)), 'error');
  }
}

export async function pendingCancel(orderId, ctx) {
  _ctx = ctx || _ctx;

  const reasons = [
    'ลูกค้าแจ้งยกเลิก',
    'ไม่มีคนขับรับงาน',
    'ร้านค้าปิดให้บริการ',
    'ร้านค้าไม่ตอบรับ',
    'สินค้าหมด',
    'ออเดอร์ซ้ำ',
  ];

  const modal = document.createElement('div');
  modal.id = 'poCancelModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-sm mx-4 fade-in">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <h3 class="font-bold text-gray-800">ยกเลิกออเดอร์ #${orderId.substring(0,8)}</h3>
        <button onclick="document.getElementById('poCancelModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-4 space-y-2">
        <p class="text-xs font-medium text-gray-500 mb-2">เลือกเหตุผล:</p>
        ${reasons.map((r, i) => `
          <label class="flex items-center gap-2 p-2.5 rounded-lg border border-gray-100 hover:bg-red-50 cursor-pointer transition-colors">
            <input type="radio" name="cancelReason" value="${r}" class="accent-red-500" ${i === 0 ? 'checked' : ''} />
            <span class="text-sm">${r}</span>
          </label>`).join('')}
        <label class="flex items-center gap-2 p-2.5 rounded-lg border border-gray-100 hover:bg-red-50 cursor-pointer transition-colors">
          <input type="radio" name="cancelReason" value="other" />
          <span class="text-sm">อื่นๆ</span>
        </label>
        <input type="text" id="cancelOtherReason" class="w-full border rounded-lg px-3 py-2 text-sm hidden" placeholder="ระบุเหตุผล..." />
        <button onclick="_doPendingCancel('${orderId}')" class="w-full mt-2 py-2.5 bg-red-500 text-white rounded-xl font-semibold hover:bg-red-600 transition-colors">ยืนยันยกเลิก</button>
      </div>
    </div>`;

  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });

  modal.querySelectorAll('input[name="cancelReason"]').forEach(radio => {
    radio.addEventListener('change', () => {
      const otherInput = document.getElementById('cancelOtherReason');
      if (radio.value === 'other' && radio.checked) otherInput.classList.remove('hidden');
      else otherInput.classList.add('hidden');
    });
  });
}

export async function _doPendingCancel(orderId, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml } = _deps();

  const selected = document.querySelector('input[name="cancelReason"]:checked');
  let reason = selected?.value || '';
  if (reason === 'other') {
    reason = document.getElementById('cancelOtherReason')?.value?.trim();
    if (!reason) return alert('กรุณาระบุเหตุผล');
  }
  if (!reason) return;

  try {
    await callAdminAction({ action: 'cancel_order', order_id: orderId, reason });
    document.getElementById('poCancelModal')?.remove();
    showToast('ยกเลิกออเดอร์สำเร็จ', 'success');
    if (typeof globalThis._refreshPendingOrders === 'function') await globalThis._refreshPendingOrders();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message || JSON.stringify(e)), 'error');
  }
}

export function wireMapActionsBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  globalThis.__adminWebBridge.pendingDispatch = pendingDispatch;
  globalThis.__adminWebBridge.pendingAssign = pendingAssign;
  globalThis.__adminWebBridge.pendingCancel = pendingCancel;
  globalThis.__adminWebBridge._doPendingCancel = _doPendingCancel;
}
