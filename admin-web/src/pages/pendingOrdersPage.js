let _ctx = null;
let _pendingRefreshTimer = null;
let _pendingRealtimeChannel = null;

function _deps() {
  const supabase = _ctx?.supabase || globalThis.supabase;
  const fmt = _ctx?.fmt || globalThis.fmt;
  const fmtDate = _ctx?.fmtDate || globalThis.fmtDate;
  const statCard = _ctx?.statCard || globalThis.statCard;
  const statusBadge = _ctx?.statusBadge || globalThis.statusBadge;
  const serviceIcon = _ctx?.serviceIcon || globalThis.serviceIcon;

  return {
    supabase,
    fmt,
    fmtDate,
    statCard,
    statusBadge,
    serviceIcon,
  };
}

export async function disposePendingOrdersPage(ctx) {
  _ctx = ctx || _ctx;
  const { supabase } = _deps();

  if (_pendingRefreshTimer) {
    try { clearInterval(_pendingRefreshTimer); } catch (_) {}
    _pendingRefreshTimer = null;
  }
  if (_pendingRealtimeChannel) {
    try { await supabase.removeChannel(_pendingRealtimeChannel); } catch (_) {}
    _pendingRealtimeChannel = null;
  }
}

export async function renderPendingOrdersPage(el, ctx) {
  _ctx = ctx || null;
  const { supabase } = _deps();

  await disposePendingOrdersPage(ctx);

  el.innerHTML = `
    <div class="fade-in space-y-5">
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4" id="poStats"></div>
      <div id="poContent"><div class="flex justify-center py-12"><div class="loader"></div></div></div>
    </div>`;

  await refreshPendingOrders();

  _pendingRefreshTimer = setInterval(refreshPendingOrders, 15000);

  _pendingRealtimeChannel = supabase
    .channel('pending-orders-rt')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'bookings' }, () => {
      refreshPendingOrders();
    }).subscribe();
}

export async function refreshPendingOrders(ctx) {
  _ctx = ctx || _ctx;

  const {
    supabase,
    fmt,
    fmtDate,
    statCard,
    statusBadge,
    serviceIcon,
  } = _deps();

  const pendingStatuses = ['pending', 'pending_merchant', 'matched'];
  const stuckStatuses = ['driver_accepted', 'preparing', 'arrived_at_merchant', 'ready_for_pickup', 'picking_up_order'];

  const [{ data: pendingOrders }, { data: stuckOrders }] = await Promise.all([
    supabase.from('bookings')
      .select('id, driver_id, merchant_id, customer_id, status, service_type, price, delivery_fee, pickup_address, destination_address, origin_lat, origin_lng, dest_lat, dest_lng, created_at')
      .in('status', pendingStatuses)
      .order('created_at', { ascending: true }),
    supabase.from('bookings')
      .select('id, driver_id, merchant_id, customer_id, status, service_type, price, delivery_fee, pickup_address, destination_address, origin_lat, origin_lng, dest_lat, dest_lng, created_at')
      .in('status', stuckStatuses)
      .order('created_at', { ascending: true }),
  ]);

  const allIds = [...new Set([
    ...(pendingOrders || []).map(o => o.driver_id),
    ...(pendingOrders || []).map(o => o.merchant_id),
    ...(pendingOrders || []).map(o => o.customer_id),
    ...(stuckOrders || []).map(o => o.driver_id),
    ...(stuckOrders || []).map(o => o.merchant_id),
    ...(stuckOrders || []).map(o => o.customer_id),
  ].filter(Boolean))];

  let namesMap = {};
  if (allIds.length) {
    const { data: profiles } = await supabase.from('profiles').select('id, full_name, phone_number').in('id', allIds);
    (profiles || []).forEach(p => { namesMap[p.id] = { name: p.full_name || '-', phone: p.phone_number || '' }; });
  }

  const noDriver = (pendingOrders || []).filter(o => !o.driver_id);
  const waitingMerchant = (pendingOrders || []).filter(o => o.status === 'pending_merchant');
  const stuckLong = (stuckOrders || []).filter(o => {
    const mins = (Date.now() - new Date(o.created_at).getTime()) / 60000;
    return mins > 30;
  });
  const totalPending = (pendingOrders || []).length + stuckLong.length;

  globalThis._pendingNamesMap = namesMap;

  const statsEl = document.getElementById('poStats');
  if (statsEl) {
    statsEl.innerHTML = `
      ${statCard('pending_actions', 'ทั้งหมดที่รอ', totalPending, 'bg-blue-500')}
      ${statCard('hourglass_empty', 'รอคนขับ', noDriver.length, 'bg-red-500')}
      ${statCard('store', 'รอร้านค้า', waitingMerchant.length, 'bg-amber-500')}
      ${statCard('warning', 'ค้างนาน >30น.', stuckLong.length, 'bg-purple-500')}
    `;
  }

  const thHead = `
    <thead><tr class="bg-gray-50/80">
      <th class="px-3 py-2.5 text-left text-xs font-semibold text-gray-400">ID</th>
      <th class="px-3 py-2.5 text-left text-xs font-semibold text-gray-400">ประเภท</th>
      <th class="px-3 py-2.5 text-left text-xs font-semibold text-gray-400">สถานะ</th>
      <th class="px-3 py-2.5 text-left text-xs font-semibold text-gray-400">ราคา</th>
      <th class="px-3 py-2.5 text-left text-xs font-semibold text-gray-400">ลูกค้า</th>
      <th class="px-3 py-2.5 text-left text-xs font-semibold text-gray-400">ที่อยู่รับ / ส่ง</th>
      <th class="px-3 py-2.5 text-left text-xs font-semibold text-gray-400">คนขับ</th>
      <th class="px-3 py-2.5 text-left text-xs font-semibold text-gray-400">ร้านค้า</th>
      <th class="px-3 py-2.5 text-left text-xs font-semibold text-gray-400">รอมา</th>
      <th class="px-3 py-2.5 text-left text-xs font-semibold text-gray-400">จัดการ</th>
    </tr></thead>`;

  function poRow(o) {
    const mins = Math.floor((Date.now() - new Date(o.created_at).getTime()) / 60000);
    const timeLabel = mins < 60 ? `${mins} นาที` : `${Math.floor(mins / 60)} ชม. ${mins % 60} น.`;
    const isUrgent = mins > 15;
    const custInfo = namesMap[o.customer_id];
    const drvInfo = namesMap[o.driver_id];
    const merInfo = namesMap[o.merchant_id];
    const priceText = o.service_type === 'food'
      ? `฿${fmt(Math.round(o.price || 0))} <span class="text-blue-500 text-[9px]">+ ค่าส่ง ฿${fmt(Math.round(o.delivery_fee || 0))}</span>`
      : `฿${fmt(Math.round(o.price || 0))}`;
    const pickup = o.pickup_address || '-';
    const dest = o.destination_address || '-';

    const canDispatch = !o.driver_id && (globalThis.MAP_DISPATCHABLE_STATUSES || []).includes(o.status);
    const canAdminAccept = typeof globalThis._canAdminMerchantAccept === 'function' ? globalThis._canAdminMerchantAccept(o) : false;
    const canAdminReady = typeof globalThis._canAdminMarkFoodReady === 'function' ? globalThis._canAdminMarkFoodReady(o) : false;

    return `
      <tr class="table-row ${isUrgent ? 'bg-red-50/40' : 'hover:bg-gray-50/50'}">
        <td class="px-3 py-2.5">
          <button onclick="showPendingOrderDetail('${o.id}')" class="font-mono text-xs text-indigo-600 hover:underline cursor-pointer">#${o.id.substring(0, 8)}</button>
        </td>
        <td class="px-3 py-2.5">${serviceIcon(o.service_type)}</td>
        <td class="px-3 py-2.5">${statusBadge(o.status)}</td>
        <td class="px-3 py-2.5 text-xs font-bold text-gray-800">${priceText}</td>
        <td class="px-3 py-2.5 text-xs">
          ${custInfo ? `<span class="font-medium">${custInfo.name}</span>` : '<span class="text-gray-400">-</span>'}
          ${custInfo && custInfo.phone ? `<br/><span class="text-gray-400 text-[10px]">📞 ${custInfo.phone}</span>` : ''}
        </td>
        <td class="px-3 py-2.5 text-[11px] text-gray-600 max-w-[200px]">
          <div class="truncate" title="${pickup}">📍 ${pickup}</div>
          <div class="truncate text-green-600" title="${dest}">🏁 ${dest}</div>
        </td>
        <td class="px-3 py-2.5 text-xs">${drvInfo ? `<span class="text-blue-600 font-medium">🏍 ${drvInfo.name}</span>` : '<span class="text-red-500 font-semibold">ไม่มี</span>'}</td>
        <td class="px-3 py-2.5 text-xs">${merInfo ? `<span class="text-orange-600">🏪 ${merInfo.name}</span>` : '-'}</td>
        <td class="px-3 py-2.5">
          <span class="inline-flex items-center gap-1 text-xs font-semibold ${isUrgent ? 'text-red-600' : 'text-gray-500'}">
            ${isUrgent ? '<span class="w-1.5 h-1.5 rounded-full bg-red-500 animate-pulse"></span>' : ''}
            ${timeLabel}
          </span>
        </td>
        <td class="px-3 py-2.5 whitespace-nowrap">
          <div class="flex items-center gap-1">
            <button onclick="showEditPickupLocationModal('${o.id}')" class="px-2 py-1 bg-blue-100 text-blue-600 rounded-lg text-[10px] font-medium hover:bg-blue-200 transition-colors">แก้พิกัด</button>
            ${canDispatch ? `<button onclick="pendingDispatch('${o.id}')" class="px-2 py-1 bg-blue-500 text-white rounded-lg text-[10px] font-medium hover:bg-blue-600 transition-colors">โยนงาน</button>` : (o.driver_id ? `<button onclick="pendingDispatch('${o.id}','${o.driver_id}')" class="px-2 py-1 bg-amber-500 text-white rounded-lg text-[10px] font-medium hover:bg-amber-600 transition-colors">ย้าย</button>` : '')}
            ${canAdminAccept ? `<button onclick="adminMerchantAcceptOrder('${o.id}')" class="px-2 py-1 bg-emerald-500 text-white rounded-lg text-[10px] font-medium hover:bg-emerald-600 transition-colors">รับแทนร้าน</button>` : ''}
            ${canAdminReady ? `<button onclick="adminMarkFoodReady('${o.id}')" class="px-2 py-1 bg-teal-500 text-white rounded-lg text-[10px] font-medium hover:bg-teal-600 transition-colors">อาหารพร้อม</button>` : ''}
            <button onclick="pendingCancel('${o.id}')" class="px-2 py-1 bg-red-100 text-red-600 rounded-lg text-[10px] font-medium hover:bg-red-200 transition-colors">ยกเลิก</button>
          </div>
        </td>
      </tr>`;
  }

  function tableSection(icon, iconBg, title, subtitle, orders, extraBtn) {
    return `
      <div class="glass-card overflow-hidden">
        <div class="px-5 py-3.5 flex items-center gap-3 border-b border-gray-100">
          <div class="w-8 h-8 ${iconBg} rounded-xl flex items-center justify-center"><span class="material-icons-round text-sm" style="color:inherit">${icon}</span></div>
          <div class="flex-1 min-w-0">
            <h3 class="font-bold text-gray-800 text-sm">${title}</h3>
            <p class="text-[11px] text-gray-400">${subtitle}</p>
          </div>
          ${extraBtn || ''}
          <button onclick="_refreshPendingOrders()" class="p-1.5 rounded-lg hover:bg-gray-100 transition-colors" title="รีเฟรช"><span class="material-icons-round text-gray-400 text-sm">refresh</span></button>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm">${thHead}
            <tbody class="divide-y divide-gray-100">
              ${orders.length ? orders.map(poRow).join('') : `<tr><td colspan="10" class="px-4 py-8 text-center text-gray-400 text-sm">ไม่มีรายการ 🎉</td></tr>`}
            </tbody>
          </table>
        </div>
      </div>`;
  }

  const contentEl = document.getElementById('poContent');
  if (!contentEl) return;

  contentEl.innerHTML = `
    <div class="space-y-5">
      ${tableSection(
        'hourglass_empty', 'bg-red-50 text-red-500',
        'ออเดอร์รอคนขับ', `${noDriver.length} รายการ — ต้องการมอบหมายคนขับ`,
        noDriver,
        `<button onclick=\"navigateTo('map')\" class=\"px-3 py-1.5 text-xs font-semibold text-indigo-600 bg-indigo-50 rounded-lg hover:bg-indigo-100 transition-colors\">🗺 ดูบนแผนที่</button>`
      )}
      ${waitingMerchant.length ? tableSection(
        'store', 'bg-amber-50 text-amber-500',
        'รอร้านค้ายืนยัน', `${waitingMerchant.length} รายการ — ร้านค้ายังไม่ตอบรับ`,
        waitingMerchant
      ) : ''}
      ${stuckLong.length ? tableSection(
        'warning', 'bg-purple-50 text-purple-500',
        'ออเดอร์ค้างนาน (>30 นาที)', `${stuckLong.length} รายการ — อาจต้องติดตามหรือยกเลิก`,
        stuckLong
      ) : ''}
      ${totalPending === 0 ? `
        <div class=\"glass-card p-12 text-center\">
          <span class=\"material-icons-round text-5xl text-green-400\">check_circle</span>
          <p class=\"mt-3 font-bold text-gray-700\">ไม่มีออเดอร์ที่รอจัดการ</p>
          <p class=\"text-sm text-gray-400 mt-1\">ระบบจะอัปเดตอัตโนมัติทุก 15 วินาที</p>
        </div>` : ''}
    </div>`;
}

export async function showPendingOrderDetail(orderId, ctx) {
  _ctx = ctx || _ctx;
  const { supabase, fmt, fmtDate, statusBadge, serviceIcon } = _deps();

  const { data: o } = await supabase.from('bookings').select('*').eq('id', orderId).single();
  if (!o) return alert('ไม่พบออเดอร์');
  const nMap = globalThis._pendingNamesMap || {};
  const cust = nMap[o.customer_id];
  const drv = nMap[o.driver_id];
  const mer = nMap[o.merchant_id];
  const mins = Math.floor((Date.now() - new Date(o.created_at).getTime()) / 60000);
  const timeLabel = mins < 60 ? `${mins} นาที` : `${Math.floor(mins / 60)} ชม. ${mins % 60} น.`;

  let itemsHtml = '';
  if (o.service_type === 'food') {
    const { data: items } = await supabase.from('booking_items').select('*').eq('booking_id', orderId);
    if (items && items.length) {
      itemsHtml = `
        <div class="mt-3 border-t border-gray-100 pt-3">
          <p class="text-xs font-semibold text-gray-500 mb-1.5">📋 รายการอาหาร</p>
          ${items.map(it => `<div class=\"flex justify-between text-xs py-0.5\"><span>${it.name || it.menu_name || '-'} x${it.quantity || 1}</span><span class=\"text-gray-500\">฿${fmt(Math.round((it.price || 0) * (it.quantity || 1)))}</span></div>`).join('')}
        </div>`;
    }
  }

  const canDispatchInDetail = !o.driver_id && (globalThis.MAP_DISPATCHABLE_STATUSES || []).includes(o.status);
  const canAdminAcceptInDetail = typeof globalThis._canAdminMerchantAccept === 'function' ? globalThis._canAdminMerchantAccept(o) : false;
  const canAdminReadyInDetail = typeof globalThis._canAdminMarkFoodReady === 'function' ? globalThis._canAdminMarkFoodReady(o) : false;

  const modal = document.createElement('div');
  modal.id = 'poDetailModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 fade-in max-h-[85vh] overflow-y-auto">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between sticky top-0 bg-white z-10">
        <div>
          <h3 class="font-bold text-gray-800">ออเดอร์ #${orderId.substring(0,8)}</h3>
          <p class="text-xs text-gray-400">${fmtDate(o.created_at)} • รอมา ${timeLabel}</p>
        </div>
        <button onclick="document.getElementById('poDetailModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-5 space-y-3">
        <div class="flex items-center gap-3">
          ${serviceIcon(o.service_type)}
          ${statusBadge(o.status)}
          <span class="text-lg font-bold text-gray-800">฿${fmt(Math.round(o.price||0))}</span>
          ${o.delivery_fee ? `<span class=\"text-xs text-blue-500 bg-blue-50 px-2 py-0.5 rounded-full\">ค่าส่ง ฿${fmt(Math.round(o.delivery_fee))}</span>` : ''}
        </div>
        <div class="grid grid-cols-2 gap-3 text-xs">
          <div class="p-3 rounded-xl bg-gray-50">
            <p class="text-gray-400 mb-1">👤 ลูกค้า</p>
            <p class="font-semibold">${cust ? cust.name : '-'}</p>
            ${cust && cust.phone ? `<p class=\"text-gray-400\">📞 ${cust.phone}</p>` : ''}
          </div>
          <div class="p-3 rounded-xl bg-gray-50">
            <p class="text-gray-400 mb-1">🏍 คนขับ</p>
            <p class="font-semibold ${drv ? 'text-blue-600' : 'text-red-500'}">${drv ? drv.name : 'ยังไม่มี'}</p>
            ${drv && drv.phone ? `<p class=\"text-gray-400\">📞 ${drv.phone}</p>` : ''}
          </div>
          ${mer ? `<div class=\"p-3 rounded-xl bg-gray-50 col-span-2\">
            <p class=\"text-gray-400 mb-1\">🏪 ร้านค้า</p>
            <p class=\"font-semibold text-orange-600\">${mer.name}</p>
            ${mer.phone ? `<p class=\"text-gray-400\">📞 ${mer.phone}</p>` : ''}
          </div>` : ''}
        </div>
        ${itemsHtml}
        <div class="flex gap-2 pt-2 flex-wrap">
          <button onclick="showEditPickupLocationModal('${orderId}')" class="px-3 py-1.5 bg-blue-100 text-blue-600 rounded-lg text-xs font-semibold">แก้พิกัด Pickup</button>
          ${canDispatchInDetail ? `<button onclick=\"pendingDispatch('${orderId}')\" class=\"px-3 py-1.5 bg-blue-500 text-white rounded-lg text-xs font-semibold\">โยนงาน</button>` : ''}
          ${canAdminAcceptInDetail ? `<button onclick=\"adminMerchantAcceptOrder('${orderId}')\" class=\"px-3 py-1.5 bg-emerald-500 text-white rounded-lg text-xs font-semibold\">รับแทนร้าน</button>` : ''}
          ${canAdminReadyInDetail ? `<button onclick=\"adminMarkFoodReady('${orderId}')\" class=\"px-3 py-1.5 bg-teal-500 text-white rounded-lg text-xs font-semibold\">อาหารพร้อม</button>` : ''}
          <button onclick="pendingCancel('${orderId}')" class="px-3 py-1.5 bg-red-100 text-red-600 rounded-lg text-xs font-semibold">ยกเลิก</button>
        </div>
      </div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });
}

export function wirePendingOrdersBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  globalThis.__adminWebBridge.renderPendingOrdersPage = renderPendingOrdersPage;
  globalThis.__adminWebBridge.refreshPendingOrders = refreshPendingOrders;
  globalThis.__adminWebBridge.showPendingOrderDetail = showPendingOrderDetail;
  globalThis.__adminWebBridge.disposePendingOrdersPage = disposePendingOrdersPage;
}
