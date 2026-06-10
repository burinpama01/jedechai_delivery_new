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

function topupRoleLabel(role) {
  return role === 'customer' ? 'ลูกค้า' : role === 'driver' ? 'คนขับ' : role || '-';
}

export async function renderTopupsPage(el, ctx) {
  _ctx = ctx || null;
  const { supabase, fmt, fmtDate, escapeHtml, statusBadge, renderMiniBarChart } = _deps();

  const { data: requests } = await supabase
    .from('topup_requests')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(100);

  const userIds = [...new Set((requests || []).map((r) => r.user_id))];
  let userMap = {};
  if (userIds.length) {
    const { data: profiles } = await supabase.from('profiles').select('id, full_name, role').in('id', userIds);
    (profiles || []).forEach((p) => (userMap[p.id] = p));
  }
  const statusCounts = { pending: 0, completed: 0, rejected: 0 };
  (requests || []).forEach((r) => {
    if (statusCounts[r.status] !== undefined) statusCounts[r.status] += 1;
  });

  const pendingTotal = (requests || []).filter((r) => r.status === 'pending').reduce((s, r) => s + Number(r.amount || 0), 0);
  const completedTotal = (requests || []).filter((r) => r.status === 'completed').reduce((s, r) => s + Number(r.amount || 0), 0);
  const rejectedTotal = (requests || []).filter((r) => r.status === 'rejected').reduce((s, r) => s + Number(r.amount || 0), 0);

  const modeBanner = `
    <div class="glass-card p-4 mb-5 flex flex-wrap items-center justify-between gap-3">
      <div class="flex items-center gap-3">
        <div class="w-9 h-9 rounded-xl flex items-center justify-center bg-teal-50">
          <span class="material-icons-round text-teal-500">verified</span>
        </div>
        <div>
          <p class="text-sm font-bold text-gray-800">โหมดปัจจุบัน: Slip2Go Auto + Manual</p>
          <p class="text-xs text-gray-400">ผู้ใช้เติม Wallet ผ่าน PromptPay และแนบสลิป ระบบตรวจผ่าน Slip2Go ก่อนเติมเงินอัตโนมัติ ส่วนแอดมินยังอนุมัติ/เติมเงินด้วยมือได้</p>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <a href="#" onclick="navigateTo('settings');return false" class="px-3 py-2 bg-gray-100 text-gray-600 rounded-xl text-xs font-semibold hover:bg-gray-200">
          <span class="material-icons-round text-sm align-middle">settings</span>
        </a>
      </div>
    </div>`;

  el.innerHTML = `
    <div class="fade-in">
      ${modeBanner}
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-5 mb-5">
        ${renderMiniBarChart('สรุปคำขอเติมเงินตามสถานะ', '100 รายการล่าสุด', [
          { label: 'รอดำเนินการ', value: statusCounts.pending, displayValue: fmt(statusCounts.pending) },
          { label: 'เสร็จสิ้น', value: statusCounts.completed, displayValue: fmt(statusCounts.completed) },
          { label: 'ปฏิเสธ', value: statusCounts.rejected, displayValue: fmt(statusCounts.rejected) },
        ], '#14b8a6')}
        ${renderMiniBarChart('ยอดรวมแต่ละสถานะ (บาท)', '100 รายการล่าสุด', [
          { label: 'รอดำเนินการ', value: pendingTotal, displayValue: '฿' + fmt(Math.round(pendingTotal)) },
          { label: 'เสร็จสิ้น', value: completedTotal, displayValue: '฿' + fmt(Math.round(completedTotal)) },
          { label: 'ปฏิเสธ', value: rejectedTotal, displayValue: '฿' + fmt(Math.round(rejectedTotal)) },
        ], '#0ea5e9')}
      </div>
      <div class="glass-card overflow-hidden">
        <div class="px-6 py-4 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class="w-8 h-8 bg-teal-50 rounded-lg flex items-center justify-center"><span class="material-icons-round text-teal-500 text-sm">add_card</span></div>
            <h3 class="font-bold text-gray-800">คำขอเติมเงิน (${(requests || []).length})</h3>
          </div>
          <div class="flex items-center gap-2">
            <button onclick="exportTopupsCsv()" class="px-4 py-2 rounded-xl text-xs font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100 transition-colors">Export CSV</button>
            <button onclick="exportTopupsExcel()" class="px-4 py-2 rounded-xl text-xs font-semibold bg-cyan-50 text-cyan-700 border border-cyan-200 hover:bg-cyan-100 transition-colors">Export Excel</button>
            <button onclick="showManualTopup()" class="px-5 py-2 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200 flex items-center gap-1.5" style="background:linear-gradient(135deg,#6366f1,#818cf8);"><span class="material-icons-round text-sm">add</span> เติมเงินด้วยมือ</button>
          </div>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead><tr class="bg-gray-50/80">
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ผู้ขอ</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">บทบาท</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">จำนวน</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">สถานะ</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">หลักฐาน</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">วันที่</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">จัดการ</th>
            </tr></thead>
            <tbody>
              ${(requests || []).length === 0
                ? '<tr><td colspan="7" class="px-4 py-8 text-center text-gray-400">ไม่มีคำขอ</td></tr>'
                : (requests || [])
                    .map((r) => {
                      const user = userMap[r.user_id] || {};
                      const slipEvidence = r.slip_image_path
                        ? `<button onclick="viewTopupSlip('${escapeHtml(r.slip_image_path)}')" class="px-3 py-1 bg-blue-100 text-blue-700 rounded-lg text-xs font-medium hover:bg-blue-200">ดูสลิป</button>`
                        : r.verification_reason
                          ? `<span class="text-xs text-amber-600">${escapeHtml(r.verification_reason)}</span>`
                          : '-';
                      return `
                        <tr class="table-row border-b border-gray-50">
                          <td class="px-4 py-3 font-medium">${escapeHtml(user.full_name) || r.user_id?.substring(0, 8) || '-'}</td>
                          <td class="px-4 py-3 text-gray-500">${escapeHtml(topupRoleLabel(user.role))}</td>
                          <td class="px-4 py-3 font-semibold text-green-600">฿${fmt(r.amount)}</td>
                          <td class="px-4 py-3">${statusBadge(r.status)}</td>
                          <td class="px-4 py-3">${slipEvidence}</td>
                          <td class="px-4 py-3 text-gray-500 text-xs">${fmtDate(r.created_at)}</td>
                          <td class="px-4 py-3">
                            ${r.status === 'pending'
                              ? `
                                <button onclick="approveTopup('${r.id}','${r.user_id}',${r.amount})" class="px-3 py-1 bg-green-500 text-white rounded-lg text-xs font-medium hover:bg-green-600 mr-1">อนุมัติ</button>
                                <button onclick="rejectTopup('${r.id}')" class="px-3 py-1 bg-red-500 text-white rounded-lg text-xs font-medium hover:bg-red-600">ปฏิเสธ</button>
                              `
                              : '-'}
                          </td>
                        </tr>
                      `;
                    })
                    .join('')}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  `;

  globalThis._allTopups = (requests || []).map((r) => ({
    ผู้ขอ: userMap[r.user_id]?.full_name || r.user_id?.substring(0, 8) || '-',
    บทบาท: topupRoleLabel(userMap[r.user_id]?.role),
    จำนวน: Math.round(r.amount || 0),
    สถานะ: r.status || '-',
    วันที่: fmtDate(r.created_at),
  }));

  globalThis.exportTopupsCsv = exportTopupsCsv;
  globalThis.exportTopupsExcel = exportTopupsExcel;
  globalThis.approveTopup = approveTopup;
  globalThis.rejectTopup = rejectTopup;
  globalThis.viewTopupSlip = viewTopupSlip;
  globalThis.quickSwitchTopupMode = quickSwitchTopupMode;
  globalThis.showManualTopup = showManualTopup;
}

export function exportTopupsCsv(ctx) {
  _ctx = ctx || _ctx;
  const { exportRowsToCsv, reportFilename } = _deps();
  const rows = globalThis._allTopups || [];
  exportRowsToCsv(reportFilename('topups_report', 'csv', '', ''), ['ผู้ขอ', 'บทบาท', 'จำนวน', 'สถานะ', 'วันที่'], rows);
}

export function exportTopupsExcel(ctx) {
  _ctx = ctx || _ctx;
  const { exportRowsToExcel, reportFilename } = _deps();
  const rows = globalThis._allTopups || [];
  exportRowsToExcel(reportFilename('topups_report', 'xls', '', ''), ['ผู้ขอ', 'บทบาท', 'จำนวน', 'สถานะ', 'วันที่'], rows);
}

export async function approveTopup(id, userId, amount, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml, refreshCurrentPage, fmt } = _deps();
  if (!confirm(`อนุมัติเติมเงิน ฿${fmt(amount)} ?`)) return;
  try {
    const result = await callAdminAction({ action: 'approve_topup', id, user_id: userId, amount });
    if (result?.already_processed) return showToast('คำขอนี้ถูกดำเนินการไปแล้ว', 'info');
    showToast('อนุมัติเติมเงินสำเร็จ!', 'success');
    refreshCurrentPage();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function rejectTopup(id, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml, refreshCurrentPage } = _deps();
  const reason = prompt('เหตุผลที่ปฏิเสธ:');
  if (!reason) return;
  try {
    await callAdminAction({ action: 'reject_topup', id, reason });
    refreshCurrentPage();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function viewTopupSlip(path, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml } = _deps();
  try {
    const result = await callAdminAction({ action: 'get_topup_slip_url', path });
    if (!result?.signed_url) throw new Error('signed_url_missing');
    document.getElementById('topupSlipModal')?.remove();

    const modal = document.createElement('div');
    modal.id = 'topupSlipModal';
    modal.className = 'fixed inset-0 bg-black/60 flex items-center justify-center z-50 p-4';
    modal.innerHTML = `
      <div class="bg-white rounded-2xl shadow-2xl w-full max-w-3xl max-h-[92vh] overflow-hidden flex flex-col fade-in">
        <div class="px-5 py-4 border-b border-gray-100 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class="w-9 h-9 rounded-xl bg-blue-50 flex items-center justify-center">
              <span class="material-icons-round text-blue-600 text-lg">receipt_long</span>
            </div>
            <div>
              <h3 class="font-bold text-gray-800 text-lg">สลิปเติมเงิน</h3>
              <p class="text-xs text-gray-500">หลักฐานการโอนเงินจากผู้ขอเติมเงิน</p>
            </div>
          </div>
          <button type="button" onclick="document.getElementById('topupSlipModal')?.remove()" class="w-9 h-9 rounded-xl bg-gray-100 text-gray-500 hover:bg-gray-200 flex items-center justify-center">
            <span class="material-icons-round text-lg">close</span>
          </button>
        </div>
        <div class="bg-gray-50 p-4 overflow-auto">
          <img src="${escapeHtml(result.signed_url)}" alt="สลิปเติมเงิน" class="block max-w-full max-h-[74vh] mx-auto rounded-xl border border-gray-200 bg-white object-contain" />
        </div>
      </div>`;
    modal.addEventListener('click', (event) => {
      if (event.target === modal) modal.remove();
    });
    document.body.appendChild(modal);
  } catch (e) {
    showToast('เปิดสลิปไม่สำเร็จ: ' + escapeHtml(e.message || JSON.stringify(e)), 'error');
  }
}

export async function quickSwitchTopupMode(newMode, ctx) {
  _ctx = ctx || _ctx;
  const { showToast } = _deps();
  showToast('โหมดเติมเงินใช้ Slip2Go Auto + Manual แล้ว กรุณาตั้งค่าจากหน้า Settings', 'info');
}

export async function showManualTopup(ctx) {
  _ctx = ctx || _ctx;
  const { supabase, callAdminAction, showToast, escapeHtml, refreshCurrentPage, fmt } = _deps();

  document.getElementById('manualTopupModal')?.remove();

  const modal = document.createElement('div');
  modal.id = 'manualTopupModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-xl mx-4 fade-in max-h-[90vh] overflow-hidden flex flex-col">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <div>
          <h3 class="font-bold text-gray-800 text-lg">เติมเงินด้วยมือ</h3>
          <p class="text-xs text-gray-500 mt-0.5">เลือกคนขับหรือลูกค้าเพื่อเติม Wallet</p>
        </div>
        <button onclick="document.getElementById('manualTopupModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-6 overflow-y-auto flex-1">
        <div id="manualTopupBody" class="space-y-4">
          <div class="flex justify-center py-8"><div class="loader"></div></div>
        </div>
      </div>
      <div class="px-6 py-4 border-t border-gray-100 flex gap-2 justify-end">
        <button id="manualTopupCancelBtn" class="px-4 py-2 bg-gray-100 text-gray-600 rounded-lg text-sm font-medium hover:bg-gray-200">ยกเลิก</button>
        <button id="manualTopupSubmitBtn" class="px-5 py-2 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">เติมเงิน</button>
      </div>
    </div>`;

  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => {
    if (e.target === modal) modal.remove();
  });

  const cancelBtn = modal.querySelector('#manualTopupCancelBtn');
  if (cancelBtn) cancelBtn.addEventListener('click', () => modal.remove());

  const roleFilter = ['driver', 'customer'];
  let walletUsers = [];
  try {
    const { data } = await supabase
      .from('profiles')
      .select('id, full_name, phone_number, role, approval_status')
      .in('role', ['driver', 'customer'])
      .order('full_name');
    walletUsers = (data || []).filter((u) => u.role === 'customer' || u.approval_status === 'approved');
  } catch (e) {
    walletUsers = [];
  }

  const body = modal.querySelector('#manualTopupBody');
  if (!body) return;

  body.innerHTML = `
    <div>
      <label class="block text-sm font-medium mb-1">ผู้ใช้ Wallet</label>
      <select id="manualTopupDriverSelect" class="w-full border rounded-xl px-3.5 py-2 text-sm bg-gray-50/50">
        <option value="">-- เลือกผู้ใช้ --</option>
        ${(walletUsers || [])
          .map((u) => {
            const label = `${topupRoleLabel(u.role)} - ${escapeHtml(u.full_name) || u.id.substring(0, 8)}${u.phone_number ? ' (' + escapeHtml(u.phone_number) + ')' : ''}`;
            return `<option value="${u.id}">${label}</option>`;
          })
          .join('')}
      </select>
      <p class="text-xs text-gray-400 mt-1">แสดงลูกค้า และคนขับที่อนุมัติแล้ว</p>
    </div>
    <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
      <div>
        <label class="block text-sm font-medium mb-1">จำนวนเงิน (฿)</label>
        <input id="manualTopupAmount" type="number" min="1" step="1" class="w-full border rounded-xl px-3.5 py-2 text-sm" placeholder="เช่น 100" />
      </div>
      <div>
        <label class="block text-sm font-medium mb-1">หมายเหตุ</label>
        <input id="manualTopupDesc" class="w-full border rounded-xl px-3.5 py-2 text-sm" placeholder="เหตุผล/หมายเหตุ" value="Admin เติมเงินด้วยมือ" />
      </div>
    </div>
    <div class="rounded-xl border border-amber-200 bg-amber-50 p-4 text-xs text-amber-700">
      ฟีเจอร์นี้ใช้สำหรับกรณีพิเศษเท่านั้น แนะนำให้ใส่หมายเหตุทุกครั้ง
    </div>
  `;

  const submitBtn = modal.querySelector('#manualTopupSubmitBtn');
  if (!submitBtn) return;

  submitBtn.addEventListener('click', async () => {
    const userId = document.getElementById('manualTopupDriverSelect')?.value;
    const amountRaw = document.getElementById('manualTopupAmount')?.value;
    const amount = parseFloat(amountRaw);
    const desc = (document.getElementById('manualTopupDesc')?.value || '').trim() || 'Admin เติมเงินด้วยมือ';

    if (!userId) {
      showToast('กรุณาเลือกผู้ใช้', 'error');
      return;
    }
    if (!amount || amount <= 0) {
      showToast('จำนวนเงินไม่ถูกต้อง', 'error');
      return;
    }

    if (!confirm(`เติมเงินให้ผู้ใช้นี้ ฿${fmt(amount)} ?`)) return;

    try {
      submitBtn.disabled = true;
      submitBtn.textContent = 'กำลังเติมเงิน...';
      await callAdminAction({ action: 'manual_topup', user_id: userId, amount, description: desc });
      showToast(`เติมเงิน ฿${fmt(amount)} สำเร็จ!`, 'success');
      modal.remove();
      refreshCurrentPage();
    } catch (e) {
      showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
    } finally {
      submitBtn.disabled = false;
      submitBtn.textContent = 'เติมเงิน';
    }
  });
}

export function wireTopupsBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  globalThis.__adminWebBridge.renderTopupsPage = renderTopupsPage;
  globalThis.__adminWebBridge.exportTopupsCsv = exportTopupsCsv;
  globalThis.__adminWebBridge.exportTopupsExcel = exportTopupsExcel;
  globalThis.__adminWebBridge.approveTopup = approveTopup;
  globalThis.__adminWebBridge.rejectTopup = rejectTopup;
  globalThis.__adminWebBridge.viewTopupSlip = viewTopupSlip;
  globalThis.__adminWebBridge.quickSwitchTopupMode = quickSwitchTopupMode;
  globalThis.__adminWebBridge.showManualTopup = showManualTopup;
}
