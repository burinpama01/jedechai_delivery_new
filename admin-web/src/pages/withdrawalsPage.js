let _ctx = null;

function _deps() {
  const supabase = _ctx?.supabase || globalThis.supabase;
  const callAdminAction = _ctx?.callAdminAction || globalThis.callAdminAction;
  const showToast = _ctx?.showToast || globalThis.showToast;
  const refreshCurrentPage = _ctx?.refreshCurrentPage || globalThis.refreshCurrentPage;
  const fmt = _ctx?.fmt || globalThis.fmt;
  const fmtDate = _ctx?.fmtDate || globalThis.fmtDate;
  const escapeHtml = _ctx?.escapeHtml || globalThis.escapeHtml;
  const statusBadge = _ctx?.statusBadge || globalThis.statusBadge;
  const renderMiniBarChart = _ctx?.renderMiniBarChart || globalThis.renderMiniBarChart;
  const exportRowsToCsv = _ctx?.exportRowsToCsv || globalThis.exportRowsToCsv;
  const exportRowsToExcel = _ctx?.exportRowsToExcel || globalThis.exportRowsToExcel;
  const reportFilename = _ctx?.reportFilename || globalThis.reportFilename;

  return {
    supabase,
    callAdminAction,
    showToast,
    refreshCurrentPage,
    fmt,
    fmtDate,
    escapeHtml,
    statusBadge,
    renderMiniBarChart,
    exportRowsToCsv,
    exportRowsToExcel,
    reportFilename,
  };
}

export async function renderWithdrawalsPage(el, ctx) {
  _ctx = ctx || null;
  const {
    supabase,
    fmt,
    fmtDate,
    escapeHtml,
    statusBadge,
    renderMiniBarChart,
  } = _deps();

  const { data: requests } = await supabase.from('withdrawal_requests').select('*').order('created_at', { ascending: false }).limit(100);

  const userIds = [...new Set((requests || []).map(r => r.user_id))];
  let userMap = {};
  if (userIds.length) {
    const { data: profiles } = await supabase.from('profiles').select('id, full_name, role').in('id', userIds);
    (profiles || []).forEach(p => userMap[p.id] = p);
  }

  const statusCounts = { pending: 0, completed: 0, rejected: 0 };
  (requests || []).forEach((r) => {
    if (statusCounts[r.status] !== undefined) statusCounts[r.status] += 1;
  });
  const roleCountMap = {};
  (requests || []).forEach((r) => {
    const role = userMap[r.user_id]?.role || 'unknown';
    roleCountMap[role] = (roleCountMap[role] || 0) + 1;
  });
  const roleChartRows = Object.keys(roleCountMap).map((k) => ({ label: k, value: roleCountMap[k], displayValue: fmt(roleCountMap[k]) }));

  el.innerHTML = `
    <div class="fade-in space-y-5">
      <div class="glass-card p-4 flex flex-wrap gap-3 items-center justify-end">
        <button onclick="exportWithdrawalsCsv()" class="px-4 py-2 rounded-xl text-sm font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100 transition-colors">Export CSV</button>
        <button onclick="exportWithdrawalsExcel()" class="px-4 py-2 rounded-xl text-sm font-semibold bg-cyan-50 text-cyan-700 border border-cyan-200 hover:bg-cyan-100 transition-colors">Export Excel</button>
      </div>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">
        ${renderMiniBarChart('สรุปคำขอถอนตามสถานะ', '100 รายการล่าสุด', [
          { label: 'รอดำเนินการ', value: statusCounts.pending, displayValue: fmt(statusCounts.pending) },
          { label: 'เสร็จสิ้น', value: statusCounts.completed, displayValue: fmt(statusCounts.completed) },
          { label: 'ปฏิเสธ', value: statusCounts.rejected, displayValue: fmt(statusCounts.rejected) },
        ], '#f97316')}
        ${renderMiniBarChart('สรุปคำขอตามบทบาทผู้ขอ', '100 รายการล่าสุด', roleChartRows, '#06b6d4')}
      </div>
      <div class="glass-card overflow-hidden">
        <div class="px-6 py-4 flex items-center gap-3">
          <div class="w-8 h-8 bg-orange-50 rounded-lg flex items-center justify-center"><span class="material-icons-round text-orange-500 text-sm">account_balance_wallet</span></div>
          <h3 class="font-bold text-gray-800">คำขอถอนเงิน (${(requests || []).length})</h3>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead><tr class="bg-gray-50/80">
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ผู้ขอ</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">บทบาท</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">จำนวน</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ธนาคาร</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">เลขบัญชี</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">สถานะ</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">วันที่</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">จัดการ</th>
            </tr></thead>
            <tbody>
              ${(requests || []).map(r => {
                const user = userMap[r.user_id] || {};
                return `
                  <tr class="table-row border-b border-gray-50">
                    <td class="px-4 py-3 font-medium">${escapeHtml(user.full_name) || '-'}</td>
                    <td class="px-4 py-3 text-gray-500">${escapeHtml(user.role) || '-'}</td>
                    <td class="px-4 py-3 font-semibold text-green-600">฿${fmt(r.amount)}</td>
                    <td class="px-4 py-3">${escapeHtml(r.bank_name) || '-'}</td>
                    <td class="px-4 py-3 font-mono text-xs">${escapeHtml(r.bank_account_number) || '-'}</td>
                    <td class="px-4 py-3">${statusBadge(r.status)}</td>
                    <td class="px-4 py-3 text-gray-500 text-xs">${fmtDate(r.created_at)}</td>
                    <td class="px-4 py-3">
                      ${r.status === 'pending' ? `
                        <button onclick="approveWithdrawalWithSlip('${r.id}')" class="px-3 py-1 bg-green-500 text-white rounded-lg text-xs font-medium hover:bg-green-600 mr-1">อนุมัติ+สลิป</button>
                        <button onclick="approveWithdrawal('${r.id}')" class="px-3 py-1 bg-green-100 text-green-700 rounded-lg text-xs font-medium hover:bg-green-200 mr-1">อนุมัติ</button>
                        <button onclick="rejectWithdrawal('${r.id}','${r.user_id}',${r.amount})" class="px-3 py-1 bg-red-500 text-white rounded-lg text-xs font-medium hover:bg-red-600">ปฏิเสธ</button>
                      ` : r.transfer_slip_url ? `<a href="${r.transfer_slip_url}" target="_blank" class="px-3 py-1 bg-blue-100 text-blue-700 rounded-lg text-xs font-medium hover:bg-blue-200">ดูสลิป</a>` : '-'}
                    </td>
                  </tr>
                `;
              }).join('')}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  `;

  globalThis._allWithdrawals = (requests || []).map((r) => {
    const u = userMap[r.user_id] || {};
    return {
      ผู้ขอ: u.full_name || '-',
      บทบาท: u.role || '-',
      จำนวน: Math.round(r.amount || 0),
      ธนาคาร: r.bank_name || '-',
      เลขบัญชี: r.bank_account_number || '-',
      สถานะ: r.status || '-',
      วันที่: fmtDate(r.created_at),
    };
  });
}

export function exportWithdrawalsCsv() {
  const { exportRowsToCsv, reportFilename } = _deps();
  const rows = globalThis._allWithdrawals || [];
  exportRowsToCsv(reportFilename('withdrawals_report', 'csv', '', ''), ['ผู้ขอ', 'บทบาท', 'จำนวน', 'ธนาคาร', 'เลขบัญชี', 'สถานะ', 'วันที่'], rows);
}

export function exportWithdrawalsExcel() {
  const { exportRowsToExcel, reportFilename } = _deps();
  const rows = globalThis._allWithdrawals || [];
  exportRowsToExcel(reportFilename('withdrawals_report', 'xls', '', ''), ['ผู้ขอ', 'บทบาท', 'จำนวน', 'ธนาคาร', 'เลขบัญชี', 'สถานะ', 'วันที่'], rows);
}

export async function approveWithdrawal(id) {
  const { callAdminAction, showToast, escapeHtml, refreshCurrentPage } = _deps();
  if (!confirm('อนุมัติการถอนเงินนี้?')) return;
  try {
    const result = await callAdminAction({ action: 'approve_withdrawal', id });
    if (result?.already_processed) return showToast('คำขอนี้ถูกดำเนินการไปแล้ว', 'info');
    showToast('อนุมัติการถอนเงินสำเร็จ', 'success');
    refreshCurrentPage();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function rejectWithdrawal(id, userId, amount) {
  const { callAdminAction, showToast, escapeHtml, refreshCurrentPage } = _deps();
  const reason = prompt('เหตุผลที่ปฏิเสธ:');
  if (!reason) return;
  try {
    const result = await callAdminAction({ action: 'reject_withdrawal', id, reason });
    if (result?.already_processed) return showToast('คำขอนี้ถูกดำเนินการไปแล้ว', 'info');
    showToast('ปฏิเสธการถอนเงิน + คืนเงินเข้า Wallet แล้ว', 'info');
    refreshCurrentPage();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function approveWithdrawalWithSlip(id) {
  const { supabase, callAdminAction, showToast, refreshCurrentPage } = _deps();

  if (!confirm('อนุมัติการถอนเงินนี้?')) return;
  const fileInput = document.createElement('input');
  fileInput.type = 'file';
  fileInput.accept = 'image/*';
  fileInput.onchange = async (e) => {
    const file = e.target.files[0];
    let slipUrl = null;
    if (file) {
      try {
        const ext = file.name.split('.').pop();
        const path = `withdrawal-slips/${id}_${Date.now()}.${ext}`;
        const { error } = await supabase.storage.from('admin-uploads').upload(path, file);
        if (!error) {
          const { data: urlData } = supabase.storage.from('admin-uploads').getPublicUrl(path);
          slipUrl = urlData?.publicUrl;
        }
      } catch (err) {
        console.error('Slip upload error:', err);
      }
    }
    await callAdminAction({ action: 'approve_withdrawal_with_slip', id, transfer_slip_url: slipUrl });
    showToast('อนุมัติสำเร็จ!' + (slipUrl ? ' (แนบสลิปแล้ว)' : ''), 'success');
    refreshCurrentPage();
  };
  fileInput.click();
  setTimeout(() => {
    if (!fileInput.value) {
    }
  }, 500);
}

export function wireWithdrawalsBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  globalThis.__adminWebBridge.renderWithdrawalsPage = renderWithdrawalsPage;
  globalThis.__adminWebBridge.exportWithdrawalsCsv = exportWithdrawalsCsv;
  globalThis.__adminWebBridge.exportWithdrawalsExcel = exportWithdrawalsExcel;
  globalThis.__adminWebBridge.approveWithdrawal = approveWithdrawal;
  globalThis.__adminWebBridge.rejectWithdrawal = rejectWithdrawal;
  globalThis.__adminWebBridge.approveWithdrawalWithSlip = approveWithdrawalWithSlip;
}
