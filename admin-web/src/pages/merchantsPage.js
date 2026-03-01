let _ctx = null;

function _deps() {
  const supabase = _ctx?.supabase || globalThis.supabase;
  const fmt = _ctx?.fmt || globalThis.fmt;
  const fmtDate = _ctx?.fmtDate || globalThis.fmtDate;
  const escapeHtml = _ctx?.escapeHtml || globalThis.escapeHtml;
  const showToast = _ctx?.showToast || globalThis.showToast;
  const callAdminAction = _ctx?.callAdminAction || globalThis.callAdminAction;
  const refreshCurrentPage = _ctx?.refreshCurrentPage || globalThis.refreshCurrentPage;

  const fetchUserEmails = _ctx?.fetchUserEmails || globalThis.fetchUserEmails;
  const statusBadge = _ctx?.statusBadge || globalThis.statusBadge;
  const onlineBadge = _ctx?.onlineBadge || globalThis.onlineBadge;
  const truthyFlag = _ctx?._truthyFlag || globalThis._truthyFlag;
  const renderMiniBarChart = _ctx?.renderMiniBarChart || globalThis.renderMiniBarChart;
  const exportRowsToCsv = _ctx?.exportRowsToCsv || globalThis.exportRowsToCsv;
  const exportRowsToExcel = _ctx?.exportRowsToExcel || globalThis.exportRowsToExcel;
  const reportFilename = _ctx?.reportFilename || globalThis.reportFilename;
  const uploadProfileImageField = _ctx?.uploadProfileImageField || globalThis.uploadProfileImageField;

  const fetchSystemConfigKeyValues = _ctx?._fetchSystemConfigKeyValues || globalThis._fetchSystemConfigKeyValues;

  return {
    supabase,
    fmt,
    fmtDate,
    escapeHtml,
    showToast,
    callAdminAction,
    refreshCurrentPage,
    fetchUserEmails,
    statusBadge,
    onlineBadge,
    truthyFlag,
    renderMiniBarChart,
    exportRowsToCsv,
    exportRowsToExcel,
    reportFilename,
    uploadProfileImageField,
    fetchSystemConfigKeyValues,
  };
}

export async function renderMerchantsPage(el, ctx) {
  _ctx = ctx || null;
  const { supabase, fetchUserEmails, renderMiniBarChart, fmt, truthyFlag } = _deps();

  const [{ data: merchants }] = await Promise.all([
    supabase.from('profiles').select('*').eq('role', 'merchant').order('created_at', { ascending: false }),
    typeof fetchUserEmails === 'function' ? fetchUserEmails() : Promise.resolve(null),
  ]);

  const statusRows = [
    { label: 'รออนุมัติ', value: (merchants || []).filter((m) => m.approval_status === 'pending').length },
    { label: 'อนุมัติแล้ว', value: (merchants || []).filter((m) => m.approval_status === 'approved').length },
    {
      label: 'ระงับ/ปฏิเสธ',
      value: (merchants || []).filter((m) => m.approval_status === 'suspended' || m.approval_status === 'rejected').length,
    },
  ];
  const onlineRows = [
    { label: 'ออนไลน์', value: (merchants || []).filter((m) => (typeof truthyFlag === 'function' ? truthyFlag(m.is_online) : !!m.is_online)).length },
    { label: 'ออฟไลน์', value: (merchants || []).filter((m) => !(typeof truthyFlag === 'function' ? truthyFlag(m.is_online) : !!m.is_online)).length },
  ];

  el.innerHTML = `
    <div class="fade-in space-y-5">
      <div class="glass-card p-4 flex gap-2 flex-wrap items-center">
        <button onclick="filterMerchantsByStatus('')" class="px-4 py-2 bg-white border border-gray-200 rounded-xl text-sm font-semibold hover:bg-gray-50 transition-colors">ทั้งหมด (${(merchants || []).length})</button>
        <button onclick="filterMerchantsByStatus('pending')" class="px-4 py-2 bg-amber-50 border border-amber-200 rounded-xl text-sm font-semibold text-amber-600 hover:bg-amber-100 transition-colors">รออนุมัติ (${(merchants || []).filter((m) => m.approval_status === 'pending').length})</button>
        <button onclick="filterMerchantsByStatus('approved')" class="px-4 py-2 bg-emerald-50 border border-emerald-200 rounded-xl text-sm font-semibold text-emerald-600 hover:bg-emerald-100 transition-colors">อนุมัติแล้ว (${(merchants || []).filter((m) => m.approval_status === 'approved').length})</button>
        <div class="flex-1"></div>
        <div class="relative min-w-[240px]">
          <span class="material-icons-round text-gray-400 text-sm absolute left-3 top-1/2 -translate-y-1/2">search</span>
          <input type="text" id="merchantSearch" placeholder="ค้นหาร้าน, อีเมล, เบอร์, ที่อยู่" class="w-full pl-9 pr-3 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50" oninput="filterMerchants()">
        </div>
        <button onclick="exportMerchantsCsv()" class="px-4 py-2 rounded-xl text-sm font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100 transition-colors">Export CSV</button>
        <button onclick="exportMerchantsExcel()" class="px-4 py-2 rounded-xl text-sm font-semibold bg-cyan-50 text-cyan-700 border border-cyan-200 hover:bg-cyan-100 transition-colors">Export Excel</button>
        <button onclick="showAddMerchantForm()" class="px-5 py-2 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200 flex items-center gap-1.5" style="background:linear-gradient(135deg,#6366f1,#818cf8);"><span class="material-icons-round text-sm">add</span> เพิ่มร้านค้า</button>
      </div>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">
        ${renderMiniBarChart('สรุปสถานะการอนุมัติร้านค้า', 'ภาพรวมทั้งหมด', statusRows.map((r) => ({ ...r, displayValue: fmt(r.value) })), '#f97316')}
        ${renderMiniBarChart('สรุปสถานะออนไลน์ร้านค้า', 'ออนไลน์/ออฟไลน์', onlineRows.map((r) => ({ ...r, displayValue: fmt(r.value) })), '#06b6d4')}
      </div>
      <div id="merchantFormContainer"></div>
      <div class="glass-card overflow-hidden">
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead><tr class="bg-gray-50/80">
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ชื่อร้าน</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">อีเมล</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">เบอร์โทร</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ที่อยู่ร้าน</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">สถานะ</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ออนไลน์</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">สมัครเมื่อ</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">จัดการ</th>
            </tr></thead>
            <tbody id="merchantsTableBody" class="divide-y divide-gray-100">
              ${renderMerchantRows(merchants || [])}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  `;

  globalThis._allMerchants = merchants || [];
  globalThis._filteredMerchants = merchants || [];
  globalThis._merchantStatusFilter = '';

  globalThis.renderMerchantRows = renderMerchantRows;
  globalThis.filterMerchantsByStatus = filterMerchantsByStatus;
  globalThis.filterMerchants = filterMerchants;
  globalThis.exportMerchantsCsv = exportMerchantsCsv;
  globalThis.exportMerchantsExcel = exportMerchantsExcel;
  globalThis.approveMerchant = approveMerchant;
  globalThis.rejectMerchant = rejectMerchant;
  globalThis.showAddMerchantForm = showAddMerchantForm;
  globalThis.submitAddMerchant = submitAddMerchant;
  globalThis.editMerchantProfile = editMerchantProfile;
  globalThis.submitEditMerchant = submitEditMerchant;
  globalThis.uploadMerchantImage = uploadMerchantImage;
  globalThis.toggleMerchantShopStatus = toggleMerchantShopStatus;
}

export function renderMerchantRows(merchants, ctx) {
  _ctx = ctx || _ctx;
  const { escapeHtml, statusBadge, onlineBadge, fmtDate, truthyFlag } = _deps();

  if (!merchants.length) return '<tr><td colspan="8" class="px-4 py-8 text-center text-gray-400">ไม่มีข้อมูล</td></tr>';
  return merchants
    .map((m) => {
      const isOnline = typeof truthyFlag === 'function' ? truthyFlag(m.is_online) : !!m.is_online;
      const isShopOpen = typeof truthyFlag === 'function' ? truthyFlag(m.shop_status) : !!m.shop_status;
      const safeName = escapeHtml((m.full_name || '').replace(/'/g, ''));
      return `
        <tr class="table-row border-b border-gray-50">
          <td class="px-4 py-3 font-medium">${escapeHtml(m.full_name) || '-'}</td>
          <td class="px-4 py-3 text-xs text-gray-500">${escapeHtml(globalThis._emailMap?.[m.id]) || '-'}</td>
          <td class="px-4 py-3">${escapeHtml(m.phone_number) || '-'}</td>
          <td class="px-4 py-3 text-gray-600 max-w-[200px] truncate">${escapeHtml(m.shop_address) || '-'}</td>
          <td class="px-4 py-3">
            ${statusBadge(m.approval_status || 'pending')}
            ${isShopOpen
              ? '<span class="ml-1 inline-flex px-2 py-0.5 rounded-full text-[10px] font-semibold bg-emerald-100 text-emerald-700">ร้านเปิด</span>'
              : '<span class="ml-1 inline-flex px-2 py-0.5 rounded-full text-[10px] font-semibold bg-slate-200 text-slate-700">ร้านปิด</span>'}
          </td>
          <td class="px-4 py-3">${onlineBadge(isOnline)}</td>
          <td class="px-4 py-3 text-gray-500 text-xs">${fmtDate(m.created_at)}</td>
          <td class="px-4 py-3">
            <button onclick="setUserOnlineStatus('${m.id}', ${isOnline ? 'false' : 'true'}, 'merchant')" class="px-3 py-1 ${isOnline ? 'bg-orange-100 text-orange-700 hover:bg-orange-200' : 'bg-emerald-100 text-emerald-700 hover:bg-emerald-200'} rounded-lg text-xs font-medium mr-1">${isOnline ? 'ตั้งออฟไลน์' : 'ตั้งออนไลน์'}</button>
            ${m.approval_status === 'pending'
              ? `
                <button onclick="approveMerchant('${m.id}')" class="px-3 py-1 bg-green-500 text-white rounded-lg text-xs font-medium hover:bg-green-600 mr-1">อนุมัติ</button>
                <button onclick="rejectMerchant('${m.id}')" class="px-3 py-1 bg-red-500 text-white rounded-lg text-xs font-medium hover:bg-red-600 mr-1">ปฏิเสธ</button>
              `
              : m.approval_status === 'approved'
                ? `
                  <button onclick="toggleMerchantShopStatus('${m.id}', ${isShopOpen ? 'true' : 'false'})" class="px-3 py-1 ${isShopOpen ? 'bg-slate-500 hover:bg-slate-600' : 'bg-cyan-600 hover:bg-cyan-700'} text-white rounded-lg text-xs font-medium mr-1">${isShopOpen ? 'ระงับ(ปิดร้าน)' : 'เปิดร้าน'}</button>
                  <button onclick="suspendUser('${m.id}')" class="px-3 py-1 bg-amber-500 text-white rounded-lg text-xs font-medium hover:bg-amber-600 mr-1">ระงับบัญชี</button>
                `
                : m.approval_status === 'suspended' || m.approval_status === 'rejected'
                  ? `
                    <button onclick="approveMerchant('${m.id}')" class="px-3 py-1 bg-green-500 text-white rounded-lg text-xs font-medium hover:bg-green-600 mr-1">อนุมัติ</button>
                  `
                  : ''}
            <button onclick="editMerchantProfile('${m.id}')" class="px-3 py-1 bg-blue-500 text-white rounded-lg text-xs font-medium hover:bg-blue-600 mr-1">แก้ไข</button>
            <button onclick="showMerchantOrderManager('${m.id}','${safeName}')" class="px-3 py-1 bg-emerald-500 text-white rounded-lg text-xs font-medium hover:bg-emerald-600 mr-1">ออเดอร์</button>
            <button onclick="navigateTo('menus');window._selectedMerchantId='${m.id}';window._selectedMerchantName='${safeName}';" class="px-3 py-1 bg-purple-500 text-white rounded-lg text-xs font-medium hover:bg-purple-600 mr-1">เมนู</button>
            <button onclick="deleteUser('${m.id}','${safeName}')" class="px-3 py-1 bg-red-100 text-red-600 rounded-lg text-xs font-medium hover:bg-red-200">ลบ</button>
          </td>
        </tr>
      `;
    })
    .join('');
}

export function filterMerchantsByStatus(status, ctx) {
  _ctx = ctx || _ctx;
  globalThis._merchantStatusFilter = status || '';
  return filterMerchants();
}

export function filterMerchants(ctx) {
  _ctx = ctx || _ctx;
  let filtered = globalThis._allMerchants || [];
  const status = globalThis._merchantStatusFilter || '';
  const search = (document.getElementById('merchantSearch')?.value || '').toLowerCase();
  if (status) filtered = filtered.filter((m) => m.approval_status === status);
  if (search) {
    filtered = filtered.filter(
      (m) =>
        (m.full_name || '').toLowerCase().includes(search) ||
        (globalThis._emailMap?.[m.id] || '').toLowerCase().includes(search) ||
        (m.phone_number || '').toLowerCase().includes(search) ||
        (m.shop_address || '').toLowerCase().includes(search),
    );
  }
  globalThis._filteredMerchants = filtered;
  const body = document.getElementById('merchantsTableBody');
  if (body) body.innerHTML = renderMerchantRows(filtered);
}

export function exportMerchantsCsv(ctx) {
  _ctx = ctx || _ctx;
  const { exportRowsToCsv, reportFilename, fmtDate, truthyFlag } = _deps();
  const rows = (globalThis._filteredMerchants || globalThis._allMerchants || []).map((m) => ({
    ชื่อร้าน: m.full_name || '-',
    อีเมล: globalThis._emailMap?.[m.id] || '-',
    เบอร์โทร: m.phone_number || '-',
    ที่อยู่ร้าน: m.shop_address || '-',
    สถานะ: m.approval_status || '-',
    ออนไลน์: (typeof truthyFlag === 'function' ? truthyFlag(m.is_online) : !!m.is_online) ? 'ออนไลน์' : 'ออฟไลน์',
    สมัครเมื่อ: fmtDate(m.created_at),
  }));
  exportRowsToCsv(reportFilename('merchants_report', 'csv', '', ''), ['ชื่อร้าน', 'อีเมล', 'เบอร์โทร', 'ที่อยู่ร้าน', 'สถานะ', 'ออนไลน์', 'สมัครเมื่อ'], rows);
}

export function exportMerchantsExcel(ctx) {
  _ctx = ctx || _ctx;
  const { exportRowsToExcel, reportFilename, fmtDate, truthyFlag } = _deps();
  const rows = (globalThis._filteredMerchants || globalThis._allMerchants || []).map((m) => ({
    ชื่อร้าน: m.full_name || '-',
    อีเมล: globalThis._emailMap?.[m.id] || '-',
    เบอร์โทร: m.phone_number || '-',
    ที่อยู่ร้าน: m.shop_address || '-',
    สถานะ: m.approval_status || '-',
    ออนไลน์: (typeof truthyFlag === 'function' ? truthyFlag(m.is_online) : !!m.is_online) ? 'ออนไลน์' : 'ออฟไลน์',
    สมัครเมื่อ: fmtDate(m.created_at),
  }));
  exportRowsToExcel(reportFilename('merchants_report', 'xls', '', ''), ['ชื่อร้าน', 'อีเมล', 'เบอร์โทร', 'ที่อยู่ร้าน', 'สถานะ', 'ออนไลน์', 'สมัครเมื่อ'], rows);
}

export async function approveMerchant(id, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml, refreshCurrentPage } = _deps();
  if (!confirm('อนุมัติร้านค้านี้?')) return;
  try {
    await callAdminAction({ action: 'approve_merchant', id });
    showToast('อนุมัติร้านค้าสำเร็จ', 'success');
    refreshCurrentPage();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function rejectMerchant(id, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml, refreshCurrentPage } = _deps();
  const reason = prompt('เหตุผลที่ปฏิเสธ:');
  if (!reason) return;
  try {
    await callAdminAction({ action: 'reject_merchant', id, reason });
    showToast('ปฏิเสธร้านค้าแล้ว', 'info');
    refreshCurrentPage();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export function showAddMerchantForm(ctx) {
  _ctx = ctx || _ctx;
  const c = document.getElementById('merchantFormContainer');
  if (!c) return;
  c.innerHTML = `
    <div class="glass-card p-6">
      <h4 class="font-bold text-gray-800 mb-4">เพิ่มร้านค้าใหม่</h4>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div><label class="block text-sm font-medium mb-1">ชื่อร้าน</label><input id="addMrcShop" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
        <div><label class="block text-sm font-medium mb-1">อีเมล</label><input id="addMrcEmail" type="email" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
        <div><label class="block text-sm font-medium mb-1">เบอร์โทร</label><input id="addMrcPhone" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
        <div><label class="block text-sm font-medium mb-1">ที่อยู่ร้าน</label><input id="addMrcAddr" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
        <div><label class="block text-sm font-medium mb-1">ชื่อเจ้าของ</label><input id="addMrcName" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
        <div><label class="block text-sm font-medium mb-1">รหัสผ่าน</label><input id="addMrcPass" type="password" class="w-full border rounded-lg px-3 py-2 text-sm" value="123456" /></div>
      </div>
      <div class="mt-4 flex gap-2">
        <button onclick="submitAddMerchant()" class="px-5 py-2 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">บันทึก</button>
        <button onclick="document.getElementById('merchantFormContainer').innerHTML=''" class="px-4 py-2 bg-gray-100 text-gray-600 rounded-lg text-sm font-medium hover:bg-gray-200">ยกเลิก</button>
      </div>
    </div>`;
}

export async function submitAddMerchant(ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml, refreshCurrentPage } = _deps();
  const email = document.getElementById('addMrcEmail')?.value;
  const pass = document.getElementById('addMrcPass')?.value;
  if (!email || !pass) return alert('กรุณากรอกอีเมลและรหัสผ่าน');
  try {
    await callAdminAction({
      action: 'add_merchant',
      email,
      password: pass,
      profile_data: {
        full_name: document.getElementById('addMrcName')?.value || document.getElementById('addMrcShop')?.value,
        phone_number: document.getElementById('addMrcPhone')?.value,
        shop_address: document.getElementById('addMrcAddr')?.value,
      },
    });
    showToast('เพิ่มร้านค้าสำเร็จ!', 'success');
    refreshCurrentPage();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function editMerchantProfile(id, ctx) {
  _ctx = ctx || _ctx;
  const { supabase, escapeHtml, fetchSystemConfigKeyValues } = _deps();

  const { data: m } = await supabase.from('profiles').select('*').eq('id', id).single();
  if (!m) return;

  let merchantSystemSplitPct =
    m.merchant_gp_system_rate != null ? (parseFloat(m.merchant_gp_system_rate) * 100).toFixed(1) : '';
  let merchantDriverSplitPct =
    m.merchant_gp_driver_rate != null ? (parseFloat(m.merchant_gp_driver_rate) * 100).toFixed(1) : '';

  try {
    if (typeof fetchSystemConfigKeyValues === 'function') {
      const splitMap = await fetchSystemConfigKeyValues([
        `merchant_gp_system_rate_${id}`,
        `merchant_gp_driver_rate_${id}`,
      ]);
      const splitSystemRaw = splitMap[`merchant_gp_system_rate_${id}`];
      const splitDriverRaw = splitMap[`merchant_gp_driver_rate_${id}`];
      if (splitSystemRaw != null && splitSystemRaw !== '') {
        merchantSystemSplitPct = (parseFloat(splitSystemRaw) * 100).toFixed(1);
      }
      if (splitDriverRaw != null && splitDriverRaw !== '') {
        merchantDriverSplitPct = (parseFloat(splitDriverRaw) * 100).toFixed(1);
      }
    }
  } catch (_) {
    // ignore and use defaults
  }

  const c = document.getElementById('merchantFormContainer');
  if (!c) return;
  c.innerHTML = `
    <div class="glass-card p-6">
      <h4 class="font-bold text-gray-800 mb-4 flex items-center gap-2">
        <span class="material-icons-round text-blue-500">store</span> แก้ไขข้อมูลร้านค้า
      </h4>
      <div class="mb-5">
        <p class="text-sm font-semibold text-gray-600 mb-2 border-b pb-1">📋 ข้อมูลร้าน</p>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div><label class="block text-sm font-medium mb-1">ชื่อร้าน / เจ้าของ</label><input id="editMrcName" value="${escapeHtml(m.full_name)}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div><label class="block text-sm font-medium mb-1">เบอร์โทร</label><input id="editMrcPhone" value="${escapeHtml(m.phone_number)}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div class="md:col-span-2"><label class="block text-sm font-medium mb-1">ที่อยู่ร้าน</label><input id="editMrcAddr" value="${escapeHtml(m.shop_address)}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div><label class="block text-sm font-medium mb-1">สถานะร้าน</label>
            <select id="editMrcOpenStatus" class="w-full border rounded-lg px-3 py-2 text-sm">
              <option value="open" ${m.shop_status !== false ? 'selected' : ''}>เปิด</option>
              <option value="closed" ${m.shop_status === false ? 'selected' : ''}>ปิดร้าน</option>
            </select>
          </div>
        </div>
      </div>

      <div class="mb-5">
        <p class="text-sm font-semibold text-gray-600 mb-2 border-b pb-1">🖼 รูปโปรไฟล์/รูปร้าน</p>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div class="rounded-lg border border-gray-200 p-3 bg-gray-50">
            <p class="text-xs font-medium mb-2">รูปโปรไฟล์</p>
            <div class="flex items-center gap-3">
              ${m.avatar_url ? `<img src="${m.avatar_url}" class="w-12 h-12 rounded-lg object-cover border" onerror="this.style.display='none'" />` : '<div class="w-12 h-12 rounded-lg bg-gray-200 flex items-center justify-center"><span class="material-icons-round text-gray-400 text-sm">person</span></div>'}
              <label class="px-2.5 py-1.5 bg-blue-500 text-white rounded text-xs cursor-pointer hover:bg-blue-600">
                อัปโหลด<input type="file" accept="image/*" class="hidden" onchange="uploadMerchantImage('${id}','avatar_url',this)" />
              </label>
            </div>
          </div>
          <div class="rounded-lg border border-gray-200 p-3 bg-gray-50">
            <p class="text-xs font-medium mb-2">รูปร้าน</p>
            <div class="flex items-center gap-3">
              ${m.shop_photo_url ? `<img src="${m.shop_photo_url}" class="w-12 h-12 rounded-lg object-cover border" onerror="this.style.display='none'" />` : '<div class="w-12 h-12 rounded-lg bg-gray-200 flex items-center justify-center"><span class="material-icons-round text-gray-400 text-sm">store</span></div>'}
              <label class="px-2.5 py-1.5 bg-blue-500 text-white rounded text-xs cursor-pointer hover:bg-blue-600">
                อัปโหลด<input type="file" accept="image/*" class="hidden" onchange="uploadMerchantImage('${id}','shop_photo_url',this)" />
              </label>
            </div>
          </div>
        </div>
      </div>

      <div class="mb-5">
        <p class="text-sm font-semibold text-gray-600 mb-2 border-b pb-1">🕐 เวลาและวันเปิดร้าน</p>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-3">
          <div><label class="block text-sm font-medium mb-1">เวลาเปิดร้าน</label><input id="editMrcOpenTime" type="time" value="${m.shop_open_time || '08:00'}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div><label class="block text-sm font-medium mb-1">เวลาปิดร้าน</label><input id="editMrcCloseTime" type="time" value="${m.shop_close_time || '22:00'}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
        </div>
        <label class="block text-sm font-medium mb-2">วันที่เปิดร้าน <span class="text-red-500">*</span></label>
        <div id="editMrcDaysWrap" class="flex flex-wrap gap-2 mb-1">
          ${['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']
            .map((d) => {
              const thLabel = { mon: 'จ', tue: 'อ', wed: 'พ', thu: 'พฤ', fri: 'ศ', sat: 'ส', sun: 'อา' }[d];
              const checked = Array.isArray(m.shop_open_days) && m.shop_open_days.includes(d);
              return `<label class="inline-flex items-center gap-1 px-3 py-1.5 rounded-full border text-sm font-semibold cursor-pointer select-none transition-colors ${checked ? 'bg-indigo-100 border-indigo-400 text-indigo-700' : 'bg-white border-gray-300 text-gray-600 hover:bg-gray-50'}">
                <input type="checkbox" value="${d}" class="editMrcDayChk hidden" ${checked ? 'checked' : ''} onchange="this.parentElement.className=this.checked?'inline-flex items-center gap-1 px-3 py-1.5 rounded-full border text-sm font-semibold cursor-pointer select-none transition-colors bg-indigo-100 border-indigo-400 text-indigo-700':'inline-flex items-center gap-1 px-3 py-1.5 rounded-full border text-sm font-semibold cursor-pointer select-none transition-colors bg-white border-gray-300 text-gray-600 hover:bg-gray-50'">
                ${thLabel}</label>`;
            })
            .join('')}
        </div>
        <p class="text-xs text-gray-400">เลือกอย่างน้อย 1 วัน</p>
      </div>

      <div class="mb-5">
        <p class="text-sm font-semibold text-gray-600 mb-2 border-b pb-1">⚙️ การรับออเดอร์</p>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="block text-sm font-medium mb-1">รูปแบบรับออเดอร์</label>
            <select id="editMrcAcceptMode" class="w-full border rounded-lg px-3 py-2 text-sm">
              <option value="manual" ${(m.order_accept_mode || 'manual') === 'manual' ? 'selected' : ''}>รับออเดอร์ด้วยตนเอง</option>
              <option value="auto" ${(m.order_accept_mode || 'manual') === 'auto' ? 'selected' : ''}>รับออเดอร์อัตโนมัติ</option>
            </select>
            <p class="text-xs text-gray-400 mt-1">โหมดอัตโนมัติจะรับออเดอร์ใหม่ให้ร้านทันที (เมื่อร้านเปิด)</p>
          </div>
          <div class="flex items-center gap-3 mt-6 md:mt-0">
            <input id="editMrcAutoSchedule" type="checkbox" class="w-4 h-4" ${(m.shop_auto_schedule_enabled ?? true) ? 'checked' : ''}>
            <label for="editMrcAutoSchedule" class="text-sm font-medium text-gray-700">เปิด-ปิดร้านอัตโนมัติตามวันและเวลา</label>
          </div>
        </div>
      </div>

      <div class="mb-5">
        <p class="text-sm font-semibold text-gray-600 mb-2 border-b pb-1">💰 ค่าธรรมเนียมเฉพาะร้าน <span class="text-xs text-gray-400 font-normal">(ว่าง = ใช้ค่าเริ่มต้นระบบ)</span></p>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <div>
            <label class="block text-sm font-medium mb-1">GP Share (%)</label>
            <input id="editMrcGP" type="number" value="${m.gp_rate != null ? (m.gp_rate * 100).toFixed(0) : ''}" class="w-full border rounded-lg px-3 py-2 text-sm" min="0" max="50" step="1" placeholder="ค่าเริ่มต้นระบบ">
            <p class="text-xs text-gray-400 mt-0.5">หักจากยอดอาหาร</p>
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">ค่าส่งเริ่มต้น (฿)</label>
            <input id="editMrcBaseFare" type="number" value="${m.custom_base_fare != null ? m.custom_base_fare : ''}" class="w-full border rounded-lg px-3 py-2 text-sm" min="0" step="1" placeholder="ค่าเริ่มต้นระบบ">
            <p class="text-xs text-gray-400 mt-0.5">ค่าส่งเริ่มต้นของร้าน</p>
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">GP เข้าระบบ (%)</label>
            <input id="editMrcGpSystemRate" type="number" value="${merchantSystemSplitPct}" class="w-full border rounded-lg px-3 py-2 text-sm" min="0" max="100" step="0.1" placeholder="ใช้ค่า default ระบบ">
            <p class="text-xs text-gray-400 mt-0.5">หัก wallet คนขับเข้าระบบ</p>
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">GP ให้คนขับ (%)</label>
            <input id="editMrcGpDriverRate" type="number" value="${merchantDriverSplitPct}" class="w-full border rounded-lg px-3 py-2 text-sm" min="0" max="100" step="0.1" placeholder="ใช้ค่า default ระบบ">
            <p class="text-xs text-gray-400 mt-0.5">เพิ่มรายได้คนขับ (ไม่หัก wallet)</p>
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">ระยะเริ่มต้น (กม.)</label>
            <input id="editMrcBaseDist" type="number" value="${m.custom_base_distance != null ? m.custom_base_distance : ''}" class="w-full border rounded-lg px-3 py-2 text-sm" min="0" step="0.5" placeholder="ค่าเริ่มต้นระบบ">
            <p class="text-xs text-gray-400 mt-0.5">ระยะที่รวมในค่าส่งเริ่มต้น (คิดจากตำแหน่งร้าน)</p>
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">ค่าส่ง/กิโลเมตร (฿)</label>
            <input id="editMrcPerKm" type="number" value="${m.custom_per_km != null ? m.custom_per_km : ''}" class="w-full border rounded-lg px-3 py-2 text-sm" min="0" step="1" placeholder="ค่าเริ่มต้นระบบ">
            <p class="text-xs text-gray-400 mt-0.5">บวกเพิ่มต่อกิโลเมตร (เกินระยะเริ่มต้น)</p>
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">ค่าส่งคงที่ (฿)</label>
            <input id="editMrcDeliveryFee" type="number" value="${m.custom_delivery_fee != null ? m.custom_delivery_fee : ''}" class="w-full border rounded-lg px-3 py-2 text-sm" min="0" step="1" placeholder="ไม่กำหนด">
            <p class="text-xs text-gray-400 mt-0.5">ถ้ากรอก ใช้ค่านี้แทนการคำนวณ</p>
          </div>
          <div>
            <label class="block text-sm font-medium mb-1">ค่าบริการเพิ่มเติม (฿)</label>
            <input id="editMrcServiceFee" type="number" value="${m.custom_service_fee != null ? m.custom_service_fee : ''}" class="w-full border rounded-lg px-3 py-2 text-sm" min="0" step="1" placeholder="ไม่มี">
            <p class="text-xs text-gray-400 mt-0.5">ค่าบริการเพิ่มเติมนอกเหนือค่าส่ง</p>
          </div>
        </div>
      </div>

      <div class="flex gap-2">
        <button onclick="submitEditMerchant('${id}')" class="px-6 py-2 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">บันทึก</button>
        <button onclick="document.getElementById('merchantFormContainer').innerHTML=''" class="px-4 py-2 bg-gray-100 text-gray-600 rounded-lg text-sm font-medium hover:bg-gray-200">ยกเลิก</button>
      </div>
    </div>`;
}

export async function submitEditMerchant(id, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml, refreshCurrentPage } = _deps();

  try {
    const dayChecks = document.querySelectorAll('.editMrcDayChk:checked');
    if (dayChecks.length === 0) {
      showToast('กรุณาเลือกวันเปิดร้านอย่างน้อย 1 วัน', 'error');
      return;
    }
    const selectedDays = Array.from(dayChecks).map((cb) => cb.value);

    const gpRaw = document.getElementById('editMrcGP')?.value;
    const gpSystemRaw = document.getElementById('editMrcGpSystemRate')?.value;
    const gpDriverRaw = document.getElementById('editMrcGpDriverRate')?.value;
    const baseFareVal = document.getElementById('editMrcBaseFare')?.value;
    const baseDistVal = document.getElementById('editMrcBaseDist')?.value;
    const perKmVal = document.getElementById('editMrcPerKm')?.value;
    const deliveryFeeVal = document.getElementById('editMrcDeliveryFee')?.value;
    const serviceFeeVal = document.getElementById('editMrcServiceFee')?.value;

    const updateData = {
      full_name: document.getElementById('editMrcName')?.value,
      phone_number: document.getElementById('editMrcPhone')?.value,
      shop_address: document.getElementById('editMrcAddr')?.value,
      gp_rate: gpRaw !== '' && gpRaw != null ? parseFloat(gpRaw) / 100 : null,
      merchant_gp_system_rate: gpSystemRaw !== '' && gpSystemRaw != null ? parseFloat(gpSystemRaw) / 100 : null,
      merchant_gp_driver_rate: gpDriverRaw !== '' && gpDriverRaw != null ? parseFloat(gpDriverRaw) / 100 : null,
      custom_base_fare: baseFareVal !== '' ? parseFloat(baseFareVal) : null,
      custom_base_distance: baseDistVal !== '' ? parseFloat(baseDistVal) : null,
      custom_per_km: perKmVal !== '' ? parseFloat(perKmVal) : null,
      custom_delivery_fee: deliveryFeeVal !== '' ? parseFloat(deliveryFeeVal) : null,
      custom_service_fee: serviceFeeVal !== '' ? parseFloat(serviceFeeVal) : null,
      shop_status: document.getElementById('editMrcOpenStatus')?.value !== 'closed',
      order_accept_mode: document.getElementById('editMrcAcceptMode')?.value || 'manual',
      shop_auto_schedule_enabled: !!document.getElementById('editMrcAutoSchedule')?.checked,
      shop_open_time: document.getElementById('editMrcOpenTime')?.value || '08:00',
      shop_close_time: document.getElementById('editMrcCloseTime')?.value || '22:00',
      shop_open_days: selectedDays,
      updated_at: new Date().toISOString(),
    };

    const gpTotal = gpRaw !== '' && gpRaw != null ? parseFloat(gpRaw) / 100 : null;
    const gpSystem = gpSystemRaw !== '' && gpSystemRaw != null ? parseFloat(gpSystemRaw) / 100 : null;
    const gpDriver = gpDriverRaw !== '' && gpDriverRaw != null ? parseFloat(gpDriverRaw) / 100 : null;
    if (gpTotal != null && gpSystem != null && gpDriver != null) {
      const splitTotal = gpSystem + gpDriver;
      if (splitTotal - gpTotal > 0.0001) {
        throw new Error(
          `GP Share รวมต้องไม่เกิน GP ที่ตั้งไว้ (GP ${(gpTotal * 100).toFixed(1)}%, split ${(splitTotal * 100).toFixed(1)}%)`,
        );
      }
    }

    const result = await callAdminAction({ action: 'edit_merchant', id, update_data: updateData });

    if (result?.split_persisted === false) {
      showToast('บันทึกข้อมูลร้านค้าสำเร็จ แต่ schema นี้ไม่รองรับการบันทึก GP split รายร้าน (ระบบจะใช้ค่า default)', 'warning');
    } else {
      showToast('บันทึกข้อมูลร้านค้าสำเร็จ!', 'success');
    }
    const container = document.getElementById('merchantFormContainer');
    if (container) container.innerHTML = '';
    refreshCurrentPage();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message || JSON.stringify(e)), 'error');
  }
}

export async function uploadMerchantImage(merchantId, field, input, ctx) {
  _ctx = ctx || _ctx;
  const { uploadProfileImageField, showToast } = _deps();

  try {
    await uploadProfileImageField(merchantId, field, input, 'profiles');
    showToast('อัปโหลดรูปภาพสำเร็จ!', 'success');
    await editMerchantProfile(merchantId);
  } catch (e) {
    showToast('อัปโหลดรูปไม่สำเร็จ: ' + (e.message || JSON.stringify(e)), 'error');
  }
}

export async function toggleMerchantShopStatus(id, currentlyOpen, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml } = _deps();

  const makeOpen = !currentlyOpen;
  const confirmed = confirm(
    makeOpen ? 'ต้องการเปิดร้านนี้ใช่หรือไม่?' : 'ต้องการระงับการเปิดร้าน (ปิดร้านชั่วคราว) ใช่หรือไม่?',
  );
  if (!confirmed) return;

  try {
    await callAdminAction({ action: 'toggle_shop_status', id, make_open: makeOpen });
    showToast(makeOpen ? 'เปิดร้านสำเร็จ' : 'ปิดร้านสำเร็จ', 'info');
    if (typeof globalThis._patchProfileInLocalCaches === 'function') {
      globalThis._patchProfileInLocalCaches(id, { shop_status: makeOpen, updated_at: new Date().toISOString() });
    }
    if (typeof globalThis._rerenderCurrentManagementRows === 'function') {
      globalThis._rerenderCurrentManagementRows();
    }
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export function wireMerchantsBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  globalThis.__adminWebBridge.renderMerchantsPage = renderMerchantsPage;
  globalThis.__adminWebBridge.renderMerchantRows = renderMerchantRows;
  globalThis.__adminWebBridge.filterMerchantsByStatus = filterMerchantsByStatus;
  globalThis.__adminWebBridge.filterMerchants = filterMerchants;
  globalThis.__adminWebBridge.exportMerchantsCsv = exportMerchantsCsv;
  globalThis.__adminWebBridge.exportMerchantsExcel = exportMerchantsExcel;
  globalThis.__adminWebBridge.approveMerchant = approveMerchant;
  globalThis.__adminWebBridge.rejectMerchant = rejectMerchant;
  globalThis.__adminWebBridge.showAddMerchantForm = showAddMerchantForm;
  globalThis.__adminWebBridge.submitAddMerchant = submitAddMerchant;
  globalThis.__adminWebBridge.editMerchantProfile = editMerchantProfile;
  globalThis.__adminWebBridge.submitEditMerchant = submitEditMerchant;
  globalThis.__adminWebBridge.uploadMerchantImage = uploadMerchantImage;
  globalThis.__adminWebBridge.toggleMerchantShopStatus = toggleMerchantShopStatus;
}
