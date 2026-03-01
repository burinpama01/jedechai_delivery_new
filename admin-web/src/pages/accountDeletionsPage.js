let _ctx = null;

function _deps() {
  const supabase = _ctx?.supabase || globalThis.supabase;
  const fmt = _ctx?.fmt || globalThis.fmt;
  const fmtDate = _ctx?.fmtDate || globalThis.fmtDate;
  const escapeHtml = _ctx?.escapeHtml || globalThis.escapeHtml;
  const exportRowsToCsv = _ctx?.exportRowsToCsv || globalThis.exportRowsToCsv;
  const exportRowsToExcel = _ctx?.exportRowsToExcel || globalThis.exportRowsToExcel;
  const reportFilename = _ctx?.reportFilename || globalThis.reportFilename;
  const renderMiniBarChart = _ctx?.renderMiniBarChart || globalThis.renderMiniBarChart;
  const callAdminAction = _ctx?.callAdminAction || globalThis.callAdminAction;
  const showToast = _ctx?.showToast || globalThis.showToast;
  const refreshCurrentPage = _ctx?.refreshCurrentPage || globalThis.refreshCurrentPage;

  return {
    supabase,
    fmt,
    fmtDate,
    escapeHtml,
    exportRowsToCsv,
    exportRowsToExcel,
    reportFilename,
    renderMiniBarChart,
    callAdminAction,
    showToast,
    refreshCurrentPage,
  };
}

export async function renderAccountDeletionsPage(el, ctx) {
  _ctx = ctx || null;
  const { supabase, fmt, fmtDate, escapeHtml, renderMiniBarChart } = _deps();

  const { data: requests, error } = await supabase
    .from('account_deletion_requests')
    .select('*')
    .order('requested_at', { ascending: false });

  if (error) {
    el.innerHTML = `<p class="text-red-500">Error: ${escapeHtml(error.message)}</p>`;
    return;
  }

  const pending = (requests || []).filter(r => r.status === 'pending');
  const approved = (requests || []).filter(r => r.status === 'approved');
  const rejected = (requests || []).filter(r => r.status === 'rejected');

  const roleLabels = { customer: 'ลูกค้า', driver: 'คนขับ', merchant: 'ร้านค้า' };
  const roleColors = { customer: 'blue', driver: 'emerald', merchant: 'orange' };
  const roleIcons = { customer: 'person', driver: 'directions_car', merchant: 'store' };

  function buildCard(r, showActions) {
    const rc = roleColors[r.user_role] || 'gray';
    const ri = roleIcons[r.user_role] || 'person';
    const dt = fmtDate(r.requested_at);
    const reviewDt = r.reviewed_at ? fmtDate(r.reviewed_at) : '';
    return `
      <div class="glass-card p-5 mb-4">
        <div class="flex items-center gap-3 mb-3">
          <div class="w-11 h-11 rounded-2xl bg-${rc}-50 flex items-center justify-center">
            <span class="material-icons-round text-${rc}-500">${ri}</span>
          </div>
          <div class="flex-1 min-w-0">
            <div class="font-bold text-gray-800 truncate">${escapeHtml(r.user_name) || 'ไม่ทราบชื่อ'}</div>
            <div class="text-xs text-gray-400 truncate">${escapeHtml(r.user_email) || ''}</div>
          </div>
          <span class="inline-flex items-center px-2.5 py-0.5 rounded-lg text-xs font-semibold bg-${rc}-50 text-${rc}-600 border border-${rc}-200">${roleLabels[r.user_role] || r.user_role}</span>
        </div>
        ${r.reason ? `<div class="bg-gray-50 rounded-xl p-3 text-sm text-gray-600 mb-3 border border-gray-100"><span class="font-semibold text-gray-500">เหตุผล:</span> ${escapeHtml(r.reason)}</div>` : ''}
        ${r.rejection_reason ? `<div class="bg-rose-50 rounded-xl p-3 text-sm text-rose-600 mb-3 border border-rose-100"><span class="font-semibold">เหตุผลปฏิเสธ:</span> ${escapeHtml(r.rejection_reason)}</div>` : ''}
        <div class="flex items-center gap-2 text-xs text-gray-400">
          <span class="material-icons-round text-sm">schedule</span> ${dt} ${reviewDt ? `<span class="mx-1">•</span> ตรวจสอบ: ${reviewDt}` : ''}
        </div>
        ${showActions ? `
          <div class="flex gap-3 mt-4">
            <button onclick="rejectDeletion(${r.id})" class="flex-1 flex items-center justify-center gap-1.5 px-4 py-2.5 border border-rose-200 text-rose-600 rounded-xl text-sm font-semibold hover:bg-rose-50 transition-colors">
              <span class="material-icons-round text-sm">close</span> ปฏิเสธ
            </button>
            <button onclick="approveDeletion(${r.id})" class="flex-1 flex items-center justify-center gap-1.5 px-4 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-emerald-200" style="background:linear-gradient(135deg,#10b981,#14b8a6);">
              <span class="material-icons-round text-sm">check</span> อนุมัติ
            </button>
          </div>
        ` : ''}
      </div>`;
  }

  function columnHeader(icon, color, label, count) {
    return `<div class="flex items-center gap-2.5 mb-4">
      <div class="w-9 h-9 bg-${color}-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-${color}-500 text-lg">${icon}</span></div>
      <span class="font-bold text-gray-700">${label}</span>
      <span class="ml-auto text-xs font-semibold px-2 py-0.5 rounded-lg bg-${color}-50 text-${color}-600">${count}</span>
    </div>`;
  }

  el.innerHTML = `
    <div class="fade-in space-y-5">
      <div class="glass-card p-4 flex flex-wrap gap-3 items-center justify-end">
        <button onclick="exportAccountDeletionsCsv()" class="px-4 py-2 rounded-xl text-sm font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100 transition-colors">Export CSV</button>
        <button onclick="exportAccountDeletionsExcel()" class="px-4 py-2 rounded-xl text-sm font-semibold bg-cyan-50 text-cyan-700 border border-cyan-200 hover:bg-cyan-100 transition-colors">Export Excel</button>
      </div>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">
        ${renderMiniBarChart('สรุปคำขอลบบัญชีตามสถานะ', 'รายการทั้งหมด', [
          { label: 'รออนุมัติ', value: pending.length, displayValue: fmt(pending.length) },
          { label: 'อนุมัติแล้ว', value: approved.length, displayValue: fmt(approved.length) },
          { label: 'ปฏิเสธ', value: rejected.length, displayValue: fmt(rejected.length) },
        ], '#f97316')}
        ${renderMiniBarChart('สรุปคำขอลบบัญชีตามบทบาท', 'รายการทั้งหมด', [
          { label: 'ลูกค้า', value: (requests || []).filter((r) => r.user_role === 'customer').length, displayValue: fmt((requests || []).filter((r) => r.user_role === 'customer').length) },
          { label: 'คนขับ', value: (requests || []).filter((r) => r.user_role === 'driver').length, displayValue: fmt((requests || []).filter((r) => r.user_role === 'driver').length) },
          { label: 'ร้านค้า', value: (requests || []).filter((r) => r.user_role === 'merchant').length, displayValue: fmt((requests || []).filter((r) => r.user_role === 'merchant').length) },
        ], '#06b6d4')}
      </div>
      <div class="grid grid-cols-1 lg:grid-cols-3 gap-6">
      <div>
        ${columnHeader('hourglass_top', 'amber', 'รออนุมัติ', pending.length)}
        ${pending.length ? pending.map(r => buildCard(r, true)).join('') : '<div class="glass-card p-8 text-center"><span class="material-icons-round text-gray-200 text-4xl">inbox</span><p class="text-gray-400 text-sm mt-2">ไม่มีคำขอ</p></div>'}
      </div>
      <div>
        ${columnHeader('check_circle', 'emerald', 'อนุมัติแล้ว', approved.length)}
        ${approved.length ? approved.map(r => buildCard(r, false)).join('') : '<div class="glass-card p-8 text-center"><span class="material-icons-round text-gray-200 text-4xl">inbox</span><p class="text-gray-400 text-sm mt-2">ไม่มีคำขอ</p></div>'}
      </div>
      <div>
        ${columnHeader('cancel', 'rose', 'ปฏิเสธ', rejected.length)}
        ${rejected.length ? rejected.map(r => buildCard(r, false)).join('') : '<div class="glass-card p-8 text-center"><span class="material-icons-round text-gray-200 text-4xl">inbox</span><p class="text-gray-400 text-sm mt-2">ไม่มีคำขอ</p></div>'}
      </div>
      </div>
      </div>
    </div>`;

  globalThis._allAccountDeletionRequests = requests || [];

  // ensure legacy onclicks still work
  globalThis.exportAccountDeletionsCsv = exportAccountDeletionsCsv;
  globalThis.exportAccountDeletionsExcel = exportAccountDeletionsExcel;
  globalThis.approveDeletion = approveDeletion;
  globalThis.rejectDeletion = rejectDeletion;
}

export function exportAccountDeletionsCsv(ctx) {
  _ctx = ctx || _ctx;
  const { fmtDate, exportRowsToCsv, reportFilename } = _deps();

  const rows = (globalThis._allAccountDeletionRequests || []).map((r) => ({
    ชื่อผู้ใช้: r.user_name || '-',
    อีเมล: r.user_email || '-',
    บทบาท: r.user_role || '-',
    สถานะ: r.status || '-',
    เหตุผล: r.reason || '-',
    เหตุผลปฏิเสธ: r.rejection_reason || '-',
    วันที่ขอ: fmtDate(r.requested_at),
    วันที่ตรวจสอบ: fmtDate(r.reviewed_at),
  }));

  exportRowsToCsv(
    reportFilename('account_deletions_report', 'csv', '', ''),
    ['ชื่อผู้ใช้', 'อีเมล', 'บทบาท', 'สถานะ', 'เหตุผล', 'เหตุผลปฏิเสธ', 'วันที่ขอ', 'วันที่ตรวจสอบ'],
    rows,
  );
}

export function exportAccountDeletionsExcel(ctx) {
  _ctx = ctx || _ctx;
  const { fmtDate, exportRowsToExcel, reportFilename } = _deps();

  const rows = (globalThis._allAccountDeletionRequests || []).map((r) => ({
    ชื่อผู้ใช้: r.user_name || '-',
    อีเมล: r.user_email || '-',
    บทบาท: r.user_role || '-',
    สถานะ: r.status || '-',
    เหตุผล: r.reason || '-',
    เหตุผลปฏิเสธ: r.rejection_reason || '-',
    วันที่ขอ: fmtDate(r.requested_at),
    วันที่ตรวจสอบ: fmtDate(r.reviewed_at),
  }));

  exportRowsToExcel(
    reportFilename('account_deletions_report', 'xls', '', ''),
    ['ชื่อผู้ใช้', 'อีเมล', 'บทบาท', 'สถานะ', 'เหตุผล', 'เหตุผลปฏิเสธ', 'วันที่ขอ', 'วันที่ตรวจสอบ'],
    rows,
  );
}

export async function approveDeletion(id, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml, refreshCurrentPage } = _deps();

  if (!confirm('ยืนยันอนุมัติลบบัญชีนี้?')) return;
  try {
    await callAdminAction({ action: 'approve_deletion', id });
    showToast('อนุมัติลบบัญชีแล้ว', 'success');
    if (typeof refreshCurrentPage === 'function') refreshCurrentPage();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function rejectDeletion(id, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml, refreshCurrentPage } = _deps();

  const reason = prompt('เหตุผลในการปฏิเสธ (ไม่บังคับ):') || '';
  try {
    await callAdminAction({ action: 'reject_deletion', id, reason });
    showToast('ปฏิเสธคำขอแล้ว (บัญชีกลับมาใช้งานได้)', 'info');
    if (typeof refreshCurrentPage === 'function') refreshCurrentPage();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export function wireAccountDeletionsBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  globalThis.__adminWebBridge.renderAccountDeletionsPage = renderAccountDeletionsPage;
  globalThis.__adminWebBridge.exportAccountDeletionsCsv = exportAccountDeletionsCsv;
  globalThis.__adminWebBridge.exportAccountDeletionsExcel = exportAccountDeletionsExcel;
  globalThis.__adminWebBridge.approveDeletion = approveDeletion;
  globalThis.__adminWebBridge.rejectDeletion = rejectDeletion;
}
