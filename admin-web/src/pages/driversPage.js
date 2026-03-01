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
  };
}

export async function renderDriversPage(el, ctx) {
  _ctx = ctx || null;
  const { supabase, fetchUserEmails, renderMiniBarChart, fmt, truthyFlag } = _deps();

  const [{ data: drivers }] = await Promise.all([
    supabase.from('profiles').select('*').eq('role', 'driver').order('created_at', { ascending: false }),
    typeof fetchUserEmails === 'function' ? fetchUserEmails() : Promise.resolve(null),
  ]);

  const statusRows = [
    { label: 'รออนุมัติ', value: (drivers || []).filter((d) => d.approval_status === 'pending').length },
    { label: 'อนุมัติแล้ว', value: (drivers || []).filter((d) => d.approval_status === 'approved').length },
    {
      label: 'ระงับ/ปฏิเสธ',
      value: (drivers || []).filter((d) => d.approval_status === 'suspended' || d.approval_status === 'rejected').length,
    },
  ];
  const onlineRows = [
    { label: 'ออนไลน์', value: (drivers || []).filter((d) => (typeof truthyFlag === 'function' ? truthyFlag(d.is_online) : !!d.is_online)).length },
    { label: 'ออฟไลน์', value: (drivers || []).filter((d) => !(typeof truthyFlag === 'function' ? truthyFlag(d.is_online) : !!d.is_online)).length },
  ];

  el.innerHTML = `
    <div class="fade-in space-y-5">
      <div class="glass-card p-4 flex gap-2 flex-wrap items-center">
        <button onclick="filterDriversByStatus('')" class="px-4 py-2 bg-white border border-gray-200 rounded-xl text-sm font-semibold hover:bg-gray-50 transition-colors">ทั้งหมด (${(drivers || []).length})</button>
        <button onclick="filterDriversByStatus('pending')" class="px-4 py-2 bg-amber-50 border border-amber-200 rounded-xl text-sm font-semibold text-amber-600 hover:bg-amber-100 transition-colors">รออนุมัติ (${(drivers || []).filter((d) => d.approval_status === 'pending').length})</button>
        <button onclick="filterDriversByStatus('approved')" class="px-4 py-2 bg-emerald-50 border border-emerald-200 rounded-xl text-sm font-semibold text-emerald-600 hover:bg-emerald-100 transition-colors">อนุมัติแล้ว (${(drivers || []).filter((d) => d.approval_status === 'approved').length})</button>
        <div class="flex-1"></div>
        <div class="relative min-w-[240px]">
          <span class="material-icons-round text-gray-400 text-sm absolute left-3 top-1/2 -translate-y-1/2">search</span>
          <input type="text" id="driverSearch" placeholder="ค้นหาชื่อ, อีเมล, เบอร์, ทะเบียน" class="w-full pl-9 pr-3 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50" oninput="filterDrivers()">
        </div>
        <button onclick="exportDriversCsv()" class="px-4 py-2 rounded-xl text-sm font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100 transition-colors">Export CSV</button>
        <button onclick="exportDriversExcel()" class="px-4 py-2 rounded-xl text-sm font-semibold bg-cyan-50 text-cyan-700 border border-cyan-200 hover:bg-cyan-100 transition-colors">Export Excel</button>
        <button onclick="showAddDriverForm()" class="px-5 py-2 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200 flex items-center gap-1.5" style="background:linear-gradient(135deg,#6366f1,#818cf8);"><span class="material-icons-round text-sm">add</span> เพิ่มคนขับ</button>
      </div>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">
        ${renderMiniBarChart('สรุปสถานะการอนุมัติคนขับ', 'ภาพรวมทั้งหมด', statusRows.map((r) => ({ ...r, displayValue: fmt(r.value) })), '#6366f1')}
        ${renderMiniBarChart('สรุปสถานะออนไลน์คนขับ', 'ออนไลน์/ออฟไลน์', onlineRows.map((r) => ({ ...r, displayValue: fmt(r.value) })), '#10b981')}
      </div>
      <div id="driverFormContainer"></div>
      <div class="glass-card overflow-hidden">
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead><tr class="bg-gray-50/80">
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ชื่อ</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">อีเมล</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">เบอร์โทร</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ทะเบียน</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">สถานะ</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ออนไลน์</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">สมัครเมื่อ</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">จัดการ</th>
            </tr></thead>
            <tbody id="driversTableBody" class="divide-y divide-gray-100">
              ${renderDriverRows(drivers || [])}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  `;

  globalThis._allDrivers = drivers || [];
  globalThis._filteredDrivers = drivers || [];
  globalThis._driverStatusFilter = '';

  globalThis.renderDriverRows = renderDriverRows;
  globalThis.filterDriversByStatus = filterDriversByStatus;
  globalThis.filterDrivers = filterDrivers;
  globalThis.exportDriversCsv = exportDriversCsv;
  globalThis.exportDriversExcel = exportDriversExcel;
  globalThis.approveDriver = approveDriver;
  globalThis.rejectDriver = rejectDriver;
  globalThis.showAddDriverForm = showAddDriverForm;
  globalThis.submitAddDriver = submitAddDriver;
  globalThis.editDriverProfile = editDriverProfile;
  globalThis.uploadDriverDoc = uploadDriverDoc;
  globalThis.submitEditDriver = submitEditDriver;
  globalThis.showDriverDetail = showDriverDetail;
  globalThis.openDriverWalletAdjust = openDriverWalletAdjust;
}

export function renderDriverRows(drivers, ctx) {
  _ctx = ctx || _ctx;
  const { escapeHtml, statusBadge, onlineBadge, fmtDate, truthyFlag } = _deps();

  if (!drivers.length) return '<tr><td colspan="8" class="px-4 py-8 text-center text-gray-400">ไม่มีข้อมูล</td></tr>';
  return drivers
    .map((d) => {
      const isOnline = typeof truthyFlag === 'function' ? truthyFlag(d.is_online) : !!d.is_online;
      return `
        <tr class="table-row border-b border-gray-50">
          <td class="px-4 py-3 font-medium">${escapeHtml(d.full_name) || '-'}</td>
          <td class="px-4 py-3 text-xs text-gray-500">${escapeHtml(globalThis._emailMap?.[d.id]) || '-'}</td>
          <td class="px-4 py-3">${escapeHtml(d.phone_number) || '-'}</td>
          <td class="px-4 py-3">${escapeHtml(d.license_plate) || '-'}</td>
          <td class="px-4 py-3">${statusBadge(d.approval_status || 'pending')}</td>
          <td class="px-4 py-3">${onlineBadge(isOnline)}</td>
          <td class="px-4 py-3 text-gray-500 text-xs">${fmtDate(d.created_at)}</td>
          <td class="px-4 py-3 whitespace-nowrap">
            <button onclick="setUserOnlineStatus('${d.id}', ${isOnline ? 'false' : 'true'}, 'driver')" class="px-3 py-1 ${isOnline ? 'bg-orange-100 text-orange-700 hover:bg-orange-200' : 'bg-emerald-100 text-emerald-700 hover:bg-emerald-200'} rounded-lg text-xs font-medium mr-1">${isOnline ? 'ตั้งออฟไลน์' : 'ตั้งออนไลน์'}</button>
            ${d.approval_status === 'pending'
              ? `
                <button onclick="approveDriver('${d.id}')" class="px-3 py-1 bg-green-500 text-white rounded-lg text-xs font-medium hover:bg-green-600 mr-1">อนุมัติ</button>
                <button onclick="rejectDriver('${d.id}')" class="px-3 py-1 bg-red-500 text-white rounded-lg text-xs font-medium hover:bg-red-600 mr-1">ปฏิเสธ</button>
              `
              : d.approval_status === 'approved'
                ? `
                  <button onclick="suspendUser('${d.id}')" class="px-3 py-1 bg-gray-500 text-white rounded-lg text-xs font-medium hover:bg-gray-600 mr-1">ระงับ</button>
                `
                : d.approval_status === 'suspended' || d.approval_status === 'rejected'
                  ? `
                    <button onclick="approveDriver('${d.id}')" class="px-3 py-1 bg-green-500 text-white rounded-lg text-xs font-medium hover:bg-green-600 mr-1">อนุมัติ</button>
                  `
                  : ''}
            <button onclick="showDriverDetail('${d.id}')" class="px-3 py-1 bg-indigo-100 text-indigo-700 rounded-lg text-xs font-medium hover:bg-indigo-200 mr-1">ดูข้อมูล</button>
            <button onclick="editDriverProfile('${d.id}')" class="px-3 py-1 bg-blue-500 text-white rounded-lg text-xs font-medium hover:bg-blue-600 mr-1">แก้ไข</button>
            <button onclick="deleteUser('${d.id}','${escapeHtml((d.full_name || '').replace(/'/g, ''))}')" class="px-3 py-1 bg-red-100 text-red-600 rounded-lg text-xs font-medium hover:bg-red-200">ลบ</button>
          </td>
        </tr>
      `;
    })
    .join('');
}

export function filterDriversByStatus(status, ctx) {
  _ctx = ctx || _ctx;
  globalThis._driverStatusFilter = status || '';
  return filterDrivers();
}

export function filterDrivers(ctx) {
  _ctx = ctx || _ctx;
  let filtered = globalThis._allDrivers || [];
  const status = globalThis._driverStatusFilter || '';
  const search = (document.getElementById('driverSearch')?.value || '').toLowerCase();
  if (status) filtered = filtered.filter((d) => d.approval_status === status);
  if (search) {
    filtered = filtered.filter(
      (d) =>
        (d.full_name || '').toLowerCase().includes(search) ||
        (globalThis._emailMap?.[d.id] || '').toLowerCase().includes(search) ||
        (d.phone_number || '').toLowerCase().includes(search) ||
        (d.license_plate || '').toLowerCase().includes(search),
    );
  }
  globalThis._filteredDrivers = filtered;
  const body = document.getElementById('driversTableBody');
  if (body) body.innerHTML = renderDriverRows(filtered);
}

export function exportDriversCsv(ctx) {
  _ctx = ctx || _ctx;
  const { exportRowsToCsv, reportFilename, fmtDate, truthyFlag } = _deps();
  const rows = (globalThis._filteredDrivers || globalThis._allDrivers || []).map((d) => ({
    ชื่อ: d.full_name || '-',
    อีเมล: globalThis._emailMap?.[d.id] || '-',
    เบอร์โทร: d.phone_number || '-',
    ทะเบียน: d.license_plate || '-',
    สถานะ: d.approval_status || '-',
    ออนไลน์: (typeof truthyFlag === 'function' ? truthyFlag(d.is_online) : !!d.is_online) ? 'ออนไลน์' : 'ออฟไลน์',
    สมัครเมื่อ: fmtDate(d.created_at),
  }));
  exportRowsToCsv(reportFilename('drivers_report', 'csv', '', ''), ['ชื่อ', 'อีเมล', 'เบอร์โทร', 'ทะเบียน', 'สถานะ', 'ออนไลน์', 'สมัครเมื่อ'], rows);
}

export function exportDriversExcel(ctx) {
  _ctx = ctx || _ctx;
  const { exportRowsToExcel, reportFilename, fmtDate, truthyFlag } = _deps();
  const rows = (globalThis._filteredDrivers || globalThis._allDrivers || []).map((d) => ({
    ชื่อ: d.full_name || '-',
    อีเมล: globalThis._emailMap?.[d.id] || '-',
    เบอร์โทร: d.phone_number || '-',
    ทะเบียน: d.license_plate || '-',
    สถานะ: d.approval_status || '-',
    ออนไลน์: (typeof truthyFlag === 'function' ? truthyFlag(d.is_online) : !!d.is_online) ? 'ออนไลน์' : 'ออฟไลน์',
    สมัครเมื่อ: fmtDate(d.created_at),
  }));
  exportRowsToExcel(reportFilename('drivers_report', 'xls', '', ''), ['ชื่อ', 'อีเมล', 'เบอร์โทร', 'ทะเบียน', 'สถานะ', 'ออนไลน์', 'สมัครเมื่อ'], rows);
}

export async function approveDriver(id, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml, refreshCurrentPage } = _deps();

  if (!confirm('อนุมัติคนขับนี้?')) return;
  try {
    await callAdminAction({ action: 'approve_driver', id });
    showToast('อนุมัติคนขับสำเร็จ', 'success');
    refreshCurrentPage();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function rejectDriver(id, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml, refreshCurrentPage } = _deps();

  const reason = prompt('เหตุผลที่ปฏิเสธ:');
  if (!reason) return;
  try {
    await callAdminAction({ action: 'reject_driver', id, reason });
    showToast('ปฏิเสธคนขับแล้ว', 'info');
    refreshCurrentPage();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export function showAddDriverForm(ctx) {
  _ctx = ctx || _ctx;
  const c = document.getElementById('driverFormContainer');
  if (!c) return;
  c.innerHTML = `
    <div class="glass-card p-6">
      <h4 class="font-bold text-gray-800 mb-4">เพิ่มคนขับใหม่</h4>
      <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
        <div><label class="block text-sm font-medium mb-1">ชื่อ-นามสกุล</label><input id="addDrvName" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
        <div><label class="block text-sm font-medium mb-1">อีเมล</label><input id="addDrvEmail" type="email" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
        <div><label class="block text-sm font-medium mb-1">เบอร์โทร</label><input id="addDrvPhone" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
        <div><label class="block text-sm font-medium mb-1">ทะเบียนรถ</label><input id="addDrvPlate" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
        <div><label class="block text-sm font-medium mb-1">รหัสผ่าน</label><input id="addDrvPass" type="password" class="w-full border rounded-lg px-3 py-2 text-sm" value="123456" /></div>
        <div><label class="block text-sm font-medium mb-1">ประเภทรถ</label>
          <select id="addDrvVehicle" class="w-full border rounded-lg px-3 py-2 text-sm">
            <option value="มอเตอร์ไซค์">มอเตอร์ไซค์</option><option value="รถยนต์">รถยนต์</option>
          </select>
        </div>
      </div>
      <div class="mt-4 flex gap-2">
        <button onclick="submitAddDriver()" class="px-5 py-2 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">บันทึก</button>
        <button onclick="document.getElementById('driverFormContainer').innerHTML=''" class="px-4 py-2 bg-gray-100 text-gray-600 rounded-lg text-sm font-medium hover:bg-gray-200">ยกเลิก</button>
      </div>
    </div>`;
}

export async function submitAddDriver(ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml, refreshCurrentPage } = _deps();

  const email = document.getElementById('addDrvEmail')?.value;
  const pass = document.getElementById('addDrvPass')?.value;
  if (!email || !pass) return alert('กรุณากรอกอีเมลและรหัสผ่าน');
  try {
    await callAdminAction({
      action: 'add_driver',
      email,
      password: pass,
      profile_data: {
        full_name: document.getElementById('addDrvName')?.value,
        phone_number: document.getElementById('addDrvPhone')?.value,
        license_plate: document.getElementById('addDrvPlate')?.value,
        vehicle_type: document.getElementById('addDrvVehicle')?.value,
      },
    });
    showToast('เพิ่มคนขับสำเร็จ!', 'success');
    refreshCurrentPage();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function editDriverProfile(id, ctx) {
  _ctx = ctx || _ctx;
  const { supabase, escapeHtml } = _deps();

  const { data: d } = await supabase.from('profiles').select('*').eq('id', id).single();
  if (!d) return;

  document.getElementById('editDriverModal')?.remove();
  const modal = document.createElement('div');
  modal.id = 'editDriverModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50';

  const docRow = (label, field, url) => `
    <div class="flex items-center gap-3 p-3 rounded-lg border ${url ? 'border-green-200 bg-green-50' : 'border-gray-200'}">
      <div class="flex-1">
        <p class="text-xs font-medium">${label}</p>
        ${url ? `<a href="${url}" target="_blank" class="text-[10px] text-blue-500 hover:underline">ดูเอกสาร</a>` : '<p class="text-[10px] text-gray-400">ยังไม่อัปโหลด</p>'}
      </div>
      <div class="flex items-center gap-2">
        ${url ? `<img src="${url}" class="w-10 h-10 rounded object-cover border" onerror="this.style.display='none'" />` : ''}
        <label class="px-2 py-1 bg-blue-500 text-white rounded text-[10px] cursor-pointer hover:bg-blue-600">
          อัปโหลด<input type="file" accept="image/*" class="hidden" onchange="uploadDriverDoc('${id}','${field}',this)" />
        </label>
      </div>
    </div>`;

  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 fade-in max-h-[90vh] flex flex-col">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <div>
          <h3 class="font-bold text-gray-800 text-lg">แก้ไขข้อมูลคนขับ</h3>
          <p class="text-xs text-gray-500">${escapeHtml(d.full_name) || 'ไม่ระบุชื่อ'}</p>
        </div>
        <button onclick="document.getElementById('editDriverModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-6 overflow-y-auto flex-1 space-y-4">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div><label class="block text-sm font-medium mb-1">ชื่อ-นามสกุล</label><input id="editDrvName" value="${(d.full_name || '').replace(/"/g, '&quot;')}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div><label class="block text-sm font-medium mb-1">เบอร์โทร</label><input id="editDrvPhone" value="${escapeHtml(d.phone_number)}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div><label class="block text-sm font-medium mb-1">ทะเบียนรถ</label><input id="editDrvPlate" value="${escapeHtml(d.license_plate)}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div><label class="block text-sm font-medium mb-1">ประเภทรถ</label>
            <select id="editDrvVehicle" class="w-full border rounded-lg px-3 py-2 text-sm">
              <option value="มอเตอร์ไซค์" ${d.vehicle_type === 'มอเตอร์ไซค์' ? 'selected' : ''}>มอเตอร์ไซค์</option>
              <option value="รถยนต์" ${d.vehicle_type === 'รถยนต์' ? 'selected' : ''}>รถยนต์</option>
            </select>
          </div>
          <div><label class="block text-sm font-medium mb-1">สถานะ</label>
            <select id="editDrvStatus" class="w-full border rounded-lg px-3 py-2 text-sm">
              <option value="approved" ${d.approval_status === 'approved' ? 'selected' : ''}>อนุมัติ</option>
              <option value="pending" ${d.approval_status === 'pending' ? 'selected' : ''}>รอ</option>
              <option value="suspended" ${d.approval_status === 'suspended' ? 'selected' : ''}>ระงับ</option>
              <option value="rejected" ${d.approval_status === 'rejected' ? 'selected' : ''}>ปฏิเสธ</option>
            </select>
          </div>
          <div><label class="block text-sm font-medium mb-1">เหตุผลระงับ/ปฏิเสธ</label><input id="editDrvReason" value="${(d.rejection_reason || '').replace(/"/g, '&quot;')}" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="ระบุเหตุผล (ถ้ามี)" /></div>
        </div>

        <div class="border-t pt-4">
          <p class="text-sm font-bold mb-3">เอกสาร & รูปภาพ</p>
          <div class="grid grid-cols-1 gap-3" id="editDrvDocs">
            ${docRow('รูปโปรไฟล์', 'avatar_url', d.avatar_url)}
            ${docRow('บัตรประชาชน', 'id_card_url', d.id_card_url)}
            ${docRow('ใบขับขี่', 'driver_license_url', d.driver_license_url)}
            ${docRow('รูปรถ/ทะเบียนรถ', 'vehicle_registration_url', d.vehicle_registration_url)}
            ${docRow('รูปป้ายทะเบียน', 'vehicle_plate', d.vehicle_plate)}
          </div>
        </div>

        <div class="border-t pt-4">
          <p class="text-sm font-bold mb-3">ข้อมูลธนาคาร</p>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
            <div><label class="block text-xs mb-1">ธนาคาร</label><input id="editDrvBank" value="${escapeHtml(d.bank_name)}" class="w-full border rounded-lg px-3 py-1.5 text-sm" /></div>
            <div><label class="block text-xs mb-1">เลขบัญชี</label><input id="editDrvAccNum" value="${escapeHtml(d.bank_account_number)}" class="w-full border rounded-lg px-3 py-1.5 text-sm" /></div>
            <div><label class="block text-xs mb-1">ชื่อบัญชี</label><input id="editDrvAccName" value="${(d.bank_account_name || '').replace(/"/g, '&quot;')}" class="w-full border rounded-lg px-3 py-1.5 text-sm" /></div>
          </div>
        </div>
      </div>
      <div class="px-6 py-4 border-t border-gray-100 flex gap-2 justify-end">
        <button onclick="document.getElementById('editDriverModal')?.remove()" class="px-4 py-2 bg-gray-100 text-gray-600 rounded-lg text-sm font-medium hover:bg-gray-200">ยกเลิก</button>
        <button onclick="submitEditDriver('${id}')" class="px-5 py-2 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">บันทึก</button>
      </div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => {
    if (e.target === modal) modal.remove();
  });
}

export async function uploadDriverDoc(driverId, field, input, ctx) {
  _ctx = ctx || _ctx;
  const { uploadProfileImageField, showToast } = _deps();

  try {
    await uploadProfileImageField(driverId, field, input, 'driver_docs');
    showToast('อัปโหลดสำเร็จ!', 'success');
    editDriverProfile(driverId);
  } catch (e) {
    showToast('อัปโหลดไม่สำเร็จ: ' + e.message, 'error');
  }
}

export async function submitEditDriver(id, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml, refreshCurrentPage } = _deps();

  try {
    const updateData = {
      full_name: document.getElementById('editDrvName')?.value,
      phone_number: document.getElementById('editDrvPhone')?.value,
      license_plate: document.getElementById('editDrvPlate')?.value,
      vehicle_type: document.getElementById('editDrvVehicle')?.value,
      approval_status: document.getElementById('editDrvStatus')?.value,
      bank_name: document.getElementById('editDrvBank')?.value,
      bank_account_number: document.getElementById('editDrvAccNum')?.value,
      bank_account_name: document.getElementById('editDrvAccName')?.value,
      updated_at: new Date().toISOString(),
    };
    const reason = document.getElementById('editDrvReason')?.value;
    if (reason) updateData.rejection_reason = reason;
    if (updateData.approval_status === 'approved') updateData.approved_at = new Date().toISOString();

    await callAdminAction({ action: 'edit_driver', id, update_data: updateData });
    document.getElementById('editDriverModal')?.remove();
    showToast('บันทึกข้อมูลคนขับสำเร็จ!', 'success');
    refreshCurrentPage();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message || JSON.stringify(e)), 'error');
  }
}

export async function showDriverDetail(id, ctx) {
  _ctx = ctx || _ctx;
  const { supabase, escapeHtml, statusBadge, fmt, fmtDate } = _deps();

  const { data: d } = await supabase.from('profiles').select('*').eq('id', id).single();
  if (!d) return alert('ไม่พบข้อมูลคนขับ');

  let walletBal = 0;
  try {
    const { data: w } = await supabase.from('wallets').select('balance').eq('user_id', id).maybeSingle();
    if (w) walletBal = w.balance || 0;
  } catch (_) {}

  let jobCount = 0;
  try {
    const { count } = await supabase
      .from('bookings')
      .select('id', { count: 'exact', head: true })
      .eq('driver_id', id)
      .eq('status', 'completed');
    jobCount = count || 0;
  } catch (_) {}

  const modal = document.createElement('div');
  modal.id = 'driverDetailModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-2xl mx-4 fade-in max-h-[85vh] overflow-y-auto">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between sticky top-0 bg-white rounded-t-2xl z-10">
        <h3 class="font-bold text-gray-800 text-lg">ข้อมูลคนขับ</h3>
        <button onclick="document.getElementById('driverDetailModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-6 space-y-4">
        <div class="grid grid-cols-2 gap-4">
          <div class="bg-gray-50 rounded-lg p-3">
            <p class="text-xs text-gray-500">ชื่อ-นามสกุล</p>
            <p class="font-semibold">${escapeHtml(d.full_name) || '-'}</p>
          </div>
          <div class="bg-gray-50 rounded-lg p-3">
            <p class="text-xs text-gray-500">เบอร์โทร</p>
            <p class="font-semibold">${escapeHtml(d.phone_number) || '-'}</p>
          </div>
          <div class="bg-gray-50 rounded-lg p-3">
            <p class="text-xs text-gray-500">ทะเบียนรถ</p>
            <p class="font-semibold">${escapeHtml(d.license_plate) || '-'}</p>
          </div>
          <div class="bg-gray-50 rounded-lg p-3">
            <p class="text-xs text-gray-500">ประเภทรถ</p>
            <p class="font-semibold">${escapeHtml(d.vehicle_type) || '-'}</p>
          </div>
          <div class="bg-gray-50 rounded-lg p-3">
            <p class="text-xs text-gray-500">สถานะ</p>
            <p>${statusBadge(d.approval_status || 'pending')}</p>
          </div>
          <div class="bg-green-50 rounded-lg p-3">
            <p class="text-xs text-gray-500">ยอดเงินใน Wallet</p>
            <p class="font-bold text-green-600 text-lg">฿${fmt(Math.round(walletBal))}</p>
            <button onclick="openDriverWalletAdjust('${id}', ${Number(walletBal) || 0})" class="mt-2 px-3 py-1 bg-green-600 text-white rounded-lg text-xs font-semibold hover:bg-green-700">ปรับยอด Wallet</button>
          </div>
          <div class="bg-blue-50 rounded-lg p-3">
            <p class="text-xs text-gray-500">งานที่เสร็จแล้ว</p>
            <p class="font-bold text-blue-600 text-lg">${fmt(jobCount)} งาน</p>
          </div>
        </div>
        <div class="border-t pt-4">
          <h4 class="font-bold text-sm text-gray-700 mb-2">ข้อมูลธนาคาร</h4>
          <div class="grid grid-cols-3 gap-3">
            <div class="bg-gray-50 rounded-lg p-3">
              <p class="text-xs text-gray-500">ธนาคาร</p>
              <p class="font-medium text-sm">${escapeHtml(d.bank_name) || '-'}</p>
            </div>
            <div class="bg-gray-50 rounded-lg p-3">
              <p class="text-xs text-gray-500">เลขบัญชี</p>
              <p class="font-mono text-sm">${escapeHtml(d.bank_account_number) || '-'}</p>
            </div>
            <div class="bg-gray-50 rounded-lg p-3">
              <p class="text-xs text-gray-500">ชื่อบัญชี</p>
              <p class="font-medium text-sm">${d.bank_account_name || '-'}</p>
            </div>
          </div>
        </div>
        <div class="border-t pt-4">
          <h4 class="font-bold text-sm text-gray-700 mb-2">เอกสาร / รูปถ่าย</h4>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
            ${['id_card_url', 'driver_license_url', 'vehicle_registration_url', 'vehicle_plate']
              .map((field) => {
                const labels = {
                  id_card_url: 'บัตรประชาชน',
                  driver_license_url: 'ใบขับขี่',
                  vehicle_registration_url: 'รูปรถ/ทะเบียนรถ',
                  vehicle_plate: 'ป้ายทะเบียน',
                };
                const url = d[field];
                return `<div class="text-center">
                  <p class="text-xs text-gray-500 mb-1">${labels[field]}</p>
                  ${url ? `<img src="${url}" class="w-full h-24 object-cover rounded-lg border cursor-pointer" onclick="window.open('${url}','_blank')" />` : '<div class="w-full h-24 bg-gray-100 rounded-lg flex items-center justify-center"><span class="material-icons-round text-gray-300 text-2xl">image_not_supported</span></div>'}
                </div>`;
              })
              .join('')}
          </div>
        </div>
        <div class="border-t pt-4 flex items-center justify-between text-sm text-gray-500">
          <span>สมัครเมื่อ: ${fmtDate(d.created_at)}</span>
          ${d.rejection_reason ? `<span class="text-red-500">เหตุผลที่ปฏิเสธ: ${d.rejection_reason}</span>` : ''}
        </div>
      </div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => {
    if (e.target === modal) modal.remove();
  });
}

export async function openDriverWalletAdjust(driverId, currentBalance = 0, ctx) {
  _ctx = ctx || _ctx;
  const { fmt, callAdminAction, showToast, escapeHtml } = _deps();

  document.getElementById('walletAdjustModal')?.remove();

  const modal = document.createElement('div');
  modal.id = 'walletAdjustModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-[60]';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 fade-in overflow-hidden">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <div>
          <h3 class="font-bold text-gray-800">แก้ไขยอด Wallet</h3>
          <p class="text-xs text-gray-500 mt-0.5">ยอดปัจจุบัน: ฿${fmt(Math.round(currentBalance || 0))}</p>
        </div>
        <button onclick="document.getElementById('walletAdjustModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-6 space-y-4">
        <div>
          <label class="block text-sm font-medium mb-1">ยอดใหม่ (฿)</label>
          <input id="walletNewBalance" type="number" min="0" step="1" value="${Math.round(currentBalance || 0)}" class="w-full border rounded-xl px-3.5 py-2 text-sm" />
          <p class="text-xs text-gray-400 mt-1">ระบบจะคำนวณส่วนต่างให้อัตโนมัติ (เพิ่ม/หัก)</p>
        </div>
        <div>
          <label class="block text-sm font-medium mb-1">เหตุผล/หมายเหตุ</label>
          <input id="walletAdjustReason" class="w-full border rounded-xl px-3.5 py-2 text-sm" placeholder="เช่น คนขับชำระเงินสด" />
        </div>
        <div class="rounded-xl border border-amber-200 bg-amber-50 p-4 text-xs text-amber-700">
          ฟีเจอร์นี้มีผลต่อยอดเงินจริง กรุณาตรวจสอบก่อนบันทึก
        </div>
      </div>
      <div class="px-6 py-4 border-t border-gray-100 flex gap-2 justify-end">
        <button onclick="document.getElementById('walletAdjustModal')?.remove()" class="px-4 py-2 bg-gray-100 text-gray-600 rounded-lg text-sm font-medium hover:bg-gray-200">ยกเลิก</button>
        <button id="walletAdjustSubmit" class="px-5 py-2 bg-green-600 text-white rounded-xl text-sm font-semibold hover:bg-green-700">บันทึก</button>
      </div>
    </div>`;

  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => {
    if (e.target === modal) modal.remove();
  });

  const submitBtn = document.getElementById('walletAdjustSubmit');
  submitBtn?.addEventListener('click', async () => {
    const newBalRaw = document.getElementById('walletNewBalance')?.value;
    const newBal = parseFloat(String(newBalRaw ?? '').replace(/,/g, '').trim());
    if (!Number.isFinite(newBal) || newBal < 0) {
      showToast('กรุณากรอกยอดใหม่ให้ถูกต้อง', 'error');
      return;
    }

    const before = Number(currentBalance || 0);
    const after = newBal;
    const delta = after - before;

    if (Math.abs(delta) < 0.0001) {
      showToast('ยอดใหม่เท่าเดิม ไม่มีการเปลี่ยนแปลง', 'info');
      return;
    }

    const reasonInput = (document.getElementById('walletAdjustReason')?.value || '').trim();
    const reason = reasonInput || 'Admin wallet set balance';

    if (!confirm(`ยืนยันแก้ไขยอด Wallet?\n\nก่อน: ฿${fmt(Math.round(before))}\nหลัง: ฿${fmt(Math.round(after))}\nส่วนต่าง: ${delta > 0 ? '+' : ''}฿${fmt(Math.round(delta))}`)) {
      return;
    }

    try {
      submitBtn.disabled = true;
      submitBtn.textContent = 'กำลังบันทึก...';
      await callAdminAction({
        action: 'wallet_adjust',
        user_id: driverId,
        amount: delta,
        reason: `${reason} (set balance ฿${Math.round(before)} → ฿${Math.round(after)})`,
      });
      showToast(`บันทึกยอด Wallet สำเร็จ (฿${fmt(Math.round(before))} → ฿${fmt(Math.round(after))})`, 'success');
      document.getElementById('walletAdjustModal')?.remove();
      document.getElementById('driverDetailModal')?.remove();
      await showDriverDetail(driverId);
    } catch (e) {
      showToast('บันทึกยอด Wallet ไม่สำเร็จ: ' + escapeHtml(e.message || JSON.stringify(e)), 'error');
    } finally {
      submitBtn.disabled = false;
      submitBtn.textContent = 'บันทึก';
    }
  });
}

export function wireDriversBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  globalThis.__adminWebBridge.renderDriversPage = renderDriversPage;
  globalThis.__adminWebBridge.renderDriverRows = renderDriverRows;
  globalThis.__adminWebBridge.filterDriversByStatus = filterDriversByStatus;
  globalThis.__adminWebBridge.filterDrivers = filterDrivers;
  globalThis.__adminWebBridge.exportDriversCsv = exportDriversCsv;
  globalThis.__adminWebBridge.exportDriversExcel = exportDriversExcel;
  globalThis.__adminWebBridge.approveDriver = approveDriver;
  globalThis.__adminWebBridge.rejectDriver = rejectDriver;
  globalThis.__adminWebBridge.showAddDriverForm = showAddDriverForm;
  globalThis.__adminWebBridge.submitAddDriver = submitAddDriver;
  globalThis.__adminWebBridge.editDriverProfile = editDriverProfile;
  globalThis.__adminWebBridge.uploadDriverDoc = uploadDriverDoc;
  globalThis.__adminWebBridge.submitEditDriver = submitEditDriver;
  globalThis.__adminWebBridge.showDriverDetail = showDriverDetail;
  globalThis.__adminWebBridge.openDriverWalletAdjust = openDriverWalletAdjust;
}
