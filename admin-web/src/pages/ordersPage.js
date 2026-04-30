let _ctx = null;

function _deps() {
  const supabase = _ctx?.supabase || globalThis.supabase;
  const fmt = _ctx?.fmt || globalThis.fmt;
  const fmtDate = _ctx?.fmtDate || globalThis.fmtDate;
  const exportRowsToCsv = _ctx?.exportRowsToCsv || globalThis.exportRowsToCsv;
  const exportRowsToExcel = _ctx?.exportRowsToExcel || globalThis.exportRowsToExcel;
  const reportFilename = _ctx?.reportFilename || globalThis.reportFilename;
  const renderMiniBarChart = _ctx?.renderMiniBarChart || globalThis.renderMiniBarChart;

  return {
    supabase,
    fmt,
    fmtDate,
    exportRowsToCsv,
    exportRowsToExcel,
    reportFilename,
    renderMiniBarChart,
  };
}

export async function renderOrdersPage(el, ctx) {
  _ctx = ctx || null;

  const today = new Date();
  const weekAgo = new Date(today);
  weekAgo.setDate(weekAgo.getDate() - 7);

  el.innerHTML = `
    <div class="fade-in space-y-5">
      <div class="glass-card p-4 flex flex-wrap gap-3 items-center">
        <span class="material-icons-round text-indigo-400 text-lg">filter_list</span>
        <input type="date" id="ordDateFrom" value="${weekAgo.toISOString().split('T')[0]}" class="border border-gray-200 rounded-xl px-3.5 py-2 text-sm bg-gray-50/50 transition-all" />
        <span class="text-gray-300 text-sm font-medium">ถึง</span>
        <input type="date" id="ordDateTo" value="${today.toISOString().split('T')[0]}" class="border border-gray-200 rounded-xl px-3.5 py-2 text-sm bg-gray-50/50 transition-all" />
        <select id="orderStatusFilter" onchange="filterOrders()" class="text-sm border border-gray-200 rounded-xl px-3.5 py-2 bg-gray-50/50 transition-all">
          <option value="">ทุกสถานะ</option>
          <option value="pending">รอดำเนินการ</option><option value="preparing">กำลังเตรียม</option>
          <option value="in_transit">กำลังส่ง</option><option value="completed">เสร็จสิ้น</option>
          <option value="cancelled">ยกเลิก</option>
        </select>
        <select id="orderTypeFilter" onchange="filterOrders()" class="text-sm border border-gray-200 rounded-xl px-3.5 py-2 bg-gray-50/50 transition-all">
          <option value="">ทุกประเภท</option>
          <option value="food">อาหาร</option><option value="ride">เรียกรถ</option><option value="parcel">พัสดุ</option>
        </select>
        <button onclick="loadOrders()" class="text-white px-5 py-2 rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">กรอง</button>
        <button onclick="exportOrdersCsv()" class="px-4 py-2 rounded-xl text-sm font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100 transition-colors">Export CSV</button>
        <button onclick="exportOrdersExcel()" class="px-4 py-2 rounded-xl text-sm font-semibold bg-cyan-50 text-cyan-700 border border-cyan-200 hover:bg-cyan-100 transition-colors">Export Excel</button>
      </div>
      <div id="ordersContainer"><div class="flex justify-center py-10"><div class="loader"></div></div></div>
    </div>`;

  await loadOrders();
}

export async function loadOrders() {
  const { supabase, fmt, renderMiniBarChart } = _deps();

  const from = document.getElementById('ordDateFrom')?.value;
  const to = document.getElementById('ordDateTo')?.value;
  const startDate = from ? new Date(from + 'T00:00:00').toISOString() : new Date(new Date().setDate(new Date().getDate() - 7)).toISOString();
  const endDate = to ? new Date(to + 'T23:59:59').toISOString() : new Date().toISOString();

  const oc = document.getElementById('ordersContainer');
  if (!oc) return;
  oc.innerHTML = '<div class="flex justify-center py-10"><div class="loader"></div></div>';

  const { data: orders } = await supabase
    .from('bookings')
    .select('*')
    .gte('created_at', startDate)
    .lte('created_at', endDate)
    .order('created_at', { ascending: false })
    .limit(500);

  globalThis._allOrders = orders || [];
  globalThis._filteredOrders = orders || [];

  const statusCounts = {};
  const typeCounts = {};
  (orders || []).forEach((o) => {
    statusCounts[o.status || '-'] = (statusCounts[o.status || '-'] || 0) + 1;
    typeCounts[o.service_type || '-'] = (typeCounts[o.service_type || '-'] || 0) + 1;
  });

  const statusChartRows = Object.keys(statusCounts).map((k) => ({ label: k, value: statusCounts[k], displayValue: fmt(statusCounts[k]) }));
  const typeChartRows = Object.keys(typeCounts).map((k) => ({ label: k, value: typeCounts[k], displayValue: fmt(typeCounts[k]) }));

  const driverIds = [...new Set((orders || []).map(o => o.driver_id).filter(Boolean))];
  globalThis._orderDriverMap = {};
  if (driverIds.length) {
    const { data: dProfiles } = await supabase.from('profiles').select('id, full_name').in('id', driverIds);
    (dProfiles || []).forEach(p => { globalThis._orderDriverMap[p.id] = p.full_name || p.id.substring(0, 8); });
  }

  oc.innerHTML = `
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-5 mb-5">
        ${renderMiniBarChart('สรุปออเดอร์ตามสถานะ', `${from || '-'} ถึง ${to || '-'}`, statusChartRows, '#f97316')}
        ${renderMiniBarChart('สรุปออเดอร์ตามประเภท', `${from || '-'} ถึง ${to || '-'}`, typeChartRows, '#06b6d4')}
      </div>
      <div class="glass-card overflow-hidden">
        <div class="px-6 py-4 flex items-center gap-3">
          <div class="w-8 h-8 bg-indigo-50 rounded-lg flex items-center justify-center"><span class="material-icons-round text-indigo-500 text-sm">receipt_long</span></div>
          <span class="font-bold text-gray-800">ผลลัพธ์: ${(orders || []).length} รายการ</span>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead><tr class="bg-gray-50/80">
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ID</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ประเภท</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">คนขับ</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">จุดรับ</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">จุดส่ง</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ราคา</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">สถานะ</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">วันที่</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">จัดการ</th>
            </tr></thead>
            <tbody id="ordersTableBody" class="divide-y divide-gray-100">
              ${renderOrderRows(orders || [])}
            </tbody>
          </table>
        </div>
      </div>`;

  filterOrders();
}

export function renderOrderRows(orders) {
  const { fmt, fmtDate } = _deps();
  const serviceIcon = globalThis.serviceIcon;
  const statusBadge = globalThis.statusBadge;
  const canAdminMerchantAccept = globalThis._canAdminMerchantAccept;
  const canAdminMarkFoodReady = globalThis._canAdminMarkFoodReady;

  if (!orders.length) return '<tr><td colspan="9" class="px-4 py-8 text-center text-gray-400">ไม่มีข้อมูล</td></tr>';

  return orders.map(o => {
    const dName = globalThis._orderDriverMap?.[o.driver_id] || (o.driver_id ? o.driver_id.substring(0, 8) : '-');
    const canReassign = ['pending','preparing','driver_accepted','matched','pending_merchant','arrived_at_merchant','ready_for_pickup'].includes(o.status);
    const canRebroadcast = ['pending','pending_merchant','driver_accepted','matched','preparing','arrived_at_merchant','ready_for_pickup'].includes(o.status);
    const canAdminAccept = typeof canAdminMerchantAccept === 'function' ? canAdminMerchantAccept(o) : false;
    const canAdminReady = typeof canAdminMarkFoodReady === 'function' ? canAdminMarkFoodReady(o) : false;
    const canEditPickup = o.status !== 'completed' && o.status !== 'cancelled';
    const totalAmount = Number(o.price || 0) + Number(o.delivery_fee || 0);

    let actions = '';
    if (canReassign || canRebroadcast || canAdminAccept || canAdminReady || canEditPickup) {
      if (canEditPickup) actions += `<button onclick=\"showEditPickupLocationModal('${o.id}')\" class=\"px-2 py-1 bg-blue-100 text-blue-700 rounded-lg text-xs font-medium hover:bg-blue-200 mr-1\">แก้พิกัด</button>`;
      if (canRebroadcast) actions += `<button onclick=\"rebroadcastOrder('${o.id}','${o.service_type}')\" class=\"px-2 py-1 bg-purple-100 text-purple-700 rounded-lg text-xs font-medium hover:bg-purple-200 mr-1\" title=\"โยนออเดอร์ใหม่ให้คนขับทุกคนเห็น\">🔄 โยนใหม่</button>`;
      if (canReassign) actions += `<button onclick=\"showReassignModal('${o.id}','${(dName).replace(/'/g,'')}')\" class=\"px-2 py-1 bg-orange-100 text-orange-700 rounded-lg text-xs font-medium hover:bg-orange-200 mr-1\">ย้ายคนขับ</button>`;
      if (canAdminAccept) actions += `<button onclick=\"adminMerchantAcceptOrder('${o.id}')\" class=\"px-2 py-1 bg-emerald-100 text-emerald-700 rounded-lg text-xs font-medium hover:bg-emerald-200 mr-1\">รับแทนร้าน</button>`;
      if (canAdminReady) actions += `<button onclick=\"adminMarkFoodReady('${o.id}')\" class=\"px-2 py-1 bg-teal-100 text-teal-700 rounded-lg text-xs font-medium hover:bg-teal-200 mr-1\">อาหารพร้อม</button>`;
      if (o.status !== 'completed' && o.status !== 'cancelled') {
        actions += `<button onclick=\"forceCancelOrder('${o.id}','${o.customer_id || ''}',${Math.round(o.price || 0)})\" class=\"px-2 py-1 bg-red-100 text-red-700 rounded-lg text-xs font-medium hover:bg-red-200\">ยกเลิก</button>`;
      }
    } else if (o.status !== 'completed' && o.status !== 'cancelled') {
      actions = `<button onclick=\"forceCancelOrder('${o.id}','${o.customer_id || ''}',${Math.round(o.price || 0)})\" class=\"px-2 py-1 bg-red-100 text-red-700 rounded-lg text-xs font-medium hover:bg-red-200\">ยกเลิก</button>`;
    } else {
      actions = '<span class="text-gray-300 text-xs">-</span>';
    }

    return `
    <tr class="table-row border-b border-gray-50">
      <td class="px-4 py-3 font-mono text-xs text-gray-500">#${o.id.substring(0,8)}</td>
      <td class="px-4 py-3">${typeof serviceIcon === 'function' ? serviceIcon(o.service_type) : ''} ${o.service_type}</td>
      <td class="px-4 py-3 text-xs">${dName}</td>
      <td class="px-4 py-3 text-gray-600 max-w-[120px] truncate">${o.pickup_address || '-'}</td>
      <td class="px-4 py-3 text-gray-600 max-w-[120px] truncate">${o.destination_address || '-'}</td>
      <td class="px-4 py-3 font-semibold">฿${fmt(Math.round(totalAmount))}${o.service_type === 'food' ? `<div class="text-[10px] text-gray-400">อาหาร ฿${fmt(Math.round(o.price || 0))} + ส่ง ฿${fmt(Math.round(o.delivery_fee || 0))}</div>` : ''}</td>
      <td class="px-4 py-3">${typeof statusBadge === 'function' ? statusBadge(o.status) : o.status}</td>
      <td class="px-4 py-3 text-gray-500 text-xs">${fmtDate(o.created_at)}</td>
      <td class="px-4 py-3 whitespace-nowrap">${actions}</td>
    </tr>`;
  }).join('');
}

export function filterOrders() {
  const status = document.getElementById('orderStatusFilter').value;
  const type = document.getElementById('orderTypeFilter').value;
  let filtered = globalThis._allOrders || [];
  if (status) filtered = filtered.filter(o => o.status === status);
  if (type) filtered = filtered.filter(o => o.service_type === type);
  globalThis._filteredOrders = filtered;
  const tbody = document.getElementById('ordersTableBody');
  if (tbody) tbody.innerHTML = renderOrderRows(filtered);
}

export function exportOrdersCsv() {
  const { exportRowsToCsv, reportFilename, fmtDate } = _deps();
  const from = document.getElementById('ordDateFrom')?.value || '';
  const to = document.getElementById('ordDateTo')?.value || '';
  const rows = (globalThis._filteredOrders || globalThis._allOrders || []).map((o) => ({
    เลขออเดอร์: `#${(o.id || '').substring(0, 8)}`,
    ประเภท: o.service_type || '-',
    คนขับ: globalThis._orderDriverMap?.[o.driver_id] || (o.driver_id ? o.driver_id.substring(0, 8) : '-'),
    จุดรับ: o.pickup_address || '-',
    จุดส่ง: o.destination_address || '-',
    ยอดรวม: Math.round(Number(o.price || 0) + Number(o.delivery_fee || 0)),
    ค่าอาหาร: o.service_type === 'food' ? Math.round(o.price || 0) : '',
    ค่าส่ง: o.service_type === 'food' ? Math.round(o.delivery_fee || 0) : '',
    สถานะ: o.status || '-',
    วันที่: fmtDate(o.created_at),
  }));
  exportRowsToCsv(reportFilename('orders_report', 'csv', from, to), ['เลขออเดอร์', 'ประเภท', 'คนขับ', 'จุดรับ', 'จุดส่ง', 'ยอดรวม', 'ค่าอาหาร', 'ค่าส่ง', 'สถานะ', 'วันที่'], rows);
}

export function exportOrdersExcel() {
  const { exportRowsToExcel, reportFilename, fmtDate } = _deps();
  const from = document.getElementById('ordDateFrom')?.value || '';
  const to = document.getElementById('ordDateTo')?.value || '';
  const rows = (globalThis._filteredOrders || globalThis._allOrders || []).map((o) => ({
    เลขออเดอร์: `#${(o.id || '').substring(0, 8)}`,
    ประเภท: o.service_type || '-',
    คนขับ: globalThis._orderDriverMap?.[o.driver_id] || (o.driver_id ? o.driver_id.substring(0, 8) : '-'),
    จุดรับ: o.pickup_address || '-',
    จุดส่ง: o.destination_address || '-',
    ยอดรวม: Math.round(Number(o.price || 0) + Number(o.delivery_fee || 0)),
    ค่าอาหาร: o.service_type === 'food' ? Math.round(o.price || 0) : '',
    ค่าส่ง: o.service_type === 'food' ? Math.round(o.delivery_fee || 0) : '',
    สถานะ: o.status || '-',
    วันที่: fmtDate(o.created_at),
  }));
  exportRowsToExcel(reportFilename('orders_report', 'xls', from, to), ['เลขออเดอร์', 'ประเภท', 'คนขับ', 'จุดรับ', 'จุดส่ง', 'ยอดรวม', 'ค่าอาหาร', 'ค่าส่ง', 'สถานะ', 'วันที่'], rows);
}

export function wireOrdersBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  globalThis.__adminWebBridge.renderOrdersPage = renderOrdersPage;
  globalThis.__adminWebBridge.loadOrders = loadOrders;
  globalThis.__adminWebBridge.filterOrders = filterOrders;
  globalThis.__adminWebBridge.renderOrderRows = renderOrderRows;
  globalThis.__adminWebBridge.exportOrdersCsv = exportOrdersCsv;
  globalThis.__adminWebBridge.exportOrdersExcel = exportOrdersExcel;
}
