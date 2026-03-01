let _ctx = null;

function _deps() {
  const supabase = _ctx?.supabase || globalThis.supabase;
  const callAdminAction = _ctx?.callAdminAction || globalThis.callAdminAction;
  const showToast = _ctx?.showToast || globalThis.showToast;
  const refreshCurrentPage = _ctx?.refreshCurrentPage || globalThis.refreshCurrentPage;
  const fmt = _ctx?.fmt || globalThis.fmt;
  const fmtDate = _ctx?.fmtDate || globalThis.fmtDate;
  const escapeHtml = _ctx?.escapeHtml || globalThis.escapeHtml;
  const statCard = _ctx?.statCard || globalThis.statCard;
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
    statCard,
    renderMiniBarChart,
    exportRowsToCsv,
    exportRowsToExcel,
    reportFilename,
  };
}

export async function renderComplaintsPage(el, ctx) {
  _ctx = ctx || null;
  const { supabase, fmt, fmtDate, escapeHtml, statCard, renderMiniBarChart } = _deps();

  const { data: tickets } = await supabase
    .from('support_tickets')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(200);

  const userIds = [...new Set((tickets || []).map((t) => t.user_id).filter(Boolean))];
  let userMap = {};
  if (userIds.length) {
    const { data: profiles } = await supabase.from('profiles').select('id, full_name, role').in('id', userIds);
    (profiles || []).forEach((p) => {
      userMap[p.id] = p;
    });
  }

  const statusMap = {
    open: ['เปิดอยู่', 'bg-red-100 text-red-700'],
    in_progress: ['กำลังดำเนินการ', 'bg-yellow-100 text-yellow-700'],
    resolved: ['แก้ไขแล้ว', 'bg-green-100 text-green-700'],
    closed: ['ปิดแล้ว', 'bg-gray-100 text-gray-600'],
  };
  const categoryMap = {
    driver_behavior: '🚗 พฤติกรรมคนขับ',
    food_quality: '🍔 คุณภาพอาหาร',
    late_delivery: '⏰ ส่งช้า',
    wrong_order: '❌ ออเดอร์ผิด',
    payment: '💳 การชำระเงิน',
    app_bug: '🐛 ปัญหาแอพ',
    other: '📋 อื่นๆ',
  };

  const stats = { open: 0, in_progress: 0, resolved: 0, closed: 0 };
  (tickets || []).forEach((t) => {
    if (stats[t.status] !== undefined) stats[t.status]++;
  });
  const categoryCountMap = {};
  (tickets || []).forEach((t) => {
    const key = t.category || 'other';
    categoryCountMap[key] = (categoryCountMap[key] || 0) + 1;
  });
  const categoryRows = Object.keys(categoryCountMap)
    .map((k) => ({ label: categoryMap[k] || k, value: categoryCountMap[k], displayValue: fmt(categoryCountMap[k]) }))
    .sort((a, b) => b.value - a.value)
    .slice(0, 6);

  el.innerHTML = `
    <div class="fade-in space-y-5">
      <div class="glass-card p-4 flex flex-wrap gap-3 items-center justify-end">
        <button onclick="exportComplaintsCsv()" class="px-4 py-2 rounded-xl text-sm font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100 transition-colors">Export CSV</button>
        <button onclick="exportComplaintsExcel()" class="px-4 py-2 rounded-xl text-sm font-semibold bg-cyan-50 text-cyan-700 border border-cyan-200 hover:bg-cyan-100 transition-colors">Export Excel</button>
      </div>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-5">
        ${statCard('error_outline', 'เปิดอยู่', stats.open.toString(), 'bg-pink-500')}
        ${statCard('pending', 'กำลังดำเนินการ', stats.in_progress.toString(), 'bg-orange-500')}
        ${statCard('check_circle', 'แก้ไขแล้ว', stats.resolved.toString(), 'bg-green-500')}
        ${statCard('archive', 'ปิดแล้ว', stats.closed.toString(), 'bg-indigo-500')}
      </div>
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">
        ${renderMiniBarChart(
          'สรุปสถานะคำร้องเรียน',
          '200 รายการล่าสุด',
          [
            { label: 'เปิดอยู่', value: stats.open, displayValue: fmt(stats.open) },
            { label: 'กำลังดำเนินการ', value: stats.in_progress, displayValue: fmt(stats.in_progress) },
            { label: 'แก้ไขแล้ว', value: stats.resolved, displayValue: fmt(stats.resolved) },
            { label: 'ปิดแล้ว', value: stats.closed, displayValue: fmt(stats.closed) },
          ],
          '#f43f5e',
        )}
        ${renderMiniBarChart('หมวดหมู่คำร้องเรียน (Top 6)', '200 รายการล่าสุด', categoryRows, '#6366f1')}
      </div>
      <div class="glass-card p-4 flex gap-2 flex-wrap">
        <button onclick="filterComplaints('')" class="px-4 py-2 bg-white border border-gray-200 rounded-xl text-sm font-semibold hover:bg-gray-50 transition-colors">ทั้งหมด (${(tickets || []).length})</button>
        <button onclick="filterComplaints('open')" class="px-4 py-2 bg-rose-50 border border-rose-200 rounded-xl text-sm font-semibold text-rose-600 hover:bg-rose-100 transition-colors">เปิดอยู่ (${stats.open})</button>
        <button onclick="filterComplaints('in_progress')" class="px-4 py-2 bg-amber-50 border border-amber-200 rounded-xl text-sm font-semibold text-amber-600 hover:bg-amber-100 transition-colors">กำลังดำเนินการ (${stats.in_progress})</button>
      </div>
      <div class="glass-card overflow-hidden">
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead><tr class="bg-gray-50/80">
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ผู้ร้องเรียน</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">บทบาท</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">หมวดหมู่</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">หัวข้อ</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">สถานะ</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">วันที่</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">จัดการ</th>
            </tr></thead>
            <tbody id="complaintsTableBody" class="divide-y divide-gray-100">
              ${renderComplaintRows(tickets || [], userMap, statusMap, categoryMap)}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  `;

  globalThis._allComplaints = tickets || [];
  globalThis._filteredComplaints = tickets || [];
  globalThis._complaintUserMap = userMap;
  globalThis._complaintStatusMap = statusMap;
  globalThis._complaintCategoryMap = categoryMap;

  globalThis.renderComplaintRows = renderComplaintRows;
  globalThis.filterComplaints = filterComplaints;
  globalThis.exportComplaintsCsv = exportComplaintsCsv;
  globalThis.exportComplaintsExcel = exportComplaintsExcel;
  globalThis.updateComplaintStatus = updateComplaintStatus;
  globalThis.resolveComplaint = resolveComplaint;
  globalThis.viewComplaintDetail = viewComplaintDetail;
}

export function renderComplaintRows(tickets, userMap, statusMap, categoryMap, ctx) {
  _ctx = ctx || _ctx;
  const { escapeHtml, fmtDate } = _deps();

  if (!tickets.length) return '<tr><td colspan="7" class="px-4 py-8 text-center text-gray-400">ไม่มีข้อมูลร้องเรียน</td></tr>';
  const roleMap = { customer: 'ลูกค้า', driver: 'คนขับ', merchant: 'ร้านค้า' };
  return tickets
    .map((t) => {
      const user = userMap[t.user_id] || {};
      const [statusLabel, statusCls] = statusMap[t.status] || [t.status, 'bg-gray-100 text-gray-600'];
      const catLabel = categoryMap[t.category] || t.category || '-';
      return `
      <tr class="table-row border-b border-gray-50">
        <td class="px-4 py-3 font-medium">${escapeHtml(user.full_name) || '-'}</td>
        <td class="px-4 py-3 text-gray-500">${roleMap[user.role] || escapeHtml(user.role) || '-'}</td>
        <td class="px-4 py-3">${escapeHtml(catLabel)}</td>
        <td class="px-4 py-3 max-w-[200px] truncate">${escapeHtml(t.subject) || escapeHtml(t.description?.substring(0, 50)) || '-'}</td>
        <td class="px-4 py-3"><span class="px-2.5 py-1 rounded-full text-xs font-semibold ${statusCls}">${statusLabel}</span></td>
        <td class="px-4 py-3 text-gray-500 text-xs">${fmtDate(t.created_at)}</td>
        <td class="px-4 py-3 whitespace-nowrap">
          ${
            t.status === 'open'
              ? `
            <button onclick="updateComplaintStatus('${t.id}','in_progress')" class="px-3 py-1 bg-yellow-500 text-white rounded-lg text-xs font-medium hover:bg-yellow-600 mr-1">รับเรื่อง</button>
          `
              : ''
          }
          ${
            t.status === 'in_progress'
              ? `
            <button onclick="resolveComplaint('${t.id}')" class="px-3 py-1 bg-green-500 text-white rounded-lg text-xs font-medium hover:bg-green-600 mr-1">แก้ไขแล้ว</button>
          `
              : ''
          }
          ${
            t.status !== 'closed'
              ? `
            <button onclick="updateComplaintStatus('${t.id}','closed')" class="px-3 py-1 bg-gray-500 text-white rounded-lg text-xs font-medium hover:bg-gray-600 mr-1">ปิด</button>
          `
              : ''
          }
          <button onclick="viewComplaintDetail('${t.id}')" class="px-3 py-1 bg-blue-100 text-blue-600 rounded-lg text-xs font-medium hover:bg-blue-200">ดู</button>
        </td>
      </tr>
    `;
    })
    .join('');
}

export function filterComplaints(status, ctx) {
  _ctx = ctx || _ctx;
  let filtered = globalThis._allComplaints || [];
  if (status) filtered = filtered.filter((t) => t.status === status);
  globalThis._filteredComplaints = filtered;
  const tbody = document.getElementById('complaintsTableBody');
  if (tbody) {
    tbody.innerHTML = renderComplaintRows(
      filtered,
      globalThis._complaintUserMap,
      globalThis._complaintStatusMap,
      globalThis._complaintCategoryMap,
    );
  }
}

export function exportComplaintsCsv(ctx) {
  _ctx = ctx || _ctx;
  const { exportRowsToCsv, reportFilename, fmtDate } = _deps();

  const rows = (globalThis._filteredComplaints || globalThis._allComplaints || []).map((t) => ({
    ผู้ร้องเรียน: globalThis._complaintUserMap?.[t.user_id]?.full_name || '-',
    บทบาท: globalThis._complaintUserMap?.[t.user_id]?.role || '-',
    หมวดหมู่: globalThis._complaintCategoryMap?.[t.category] || t.category || '-',
    หัวข้อ: t.subject || '-',
    สถานะ: t.status || '-',
    วันที่: fmtDate(t.created_at),
  }));
  exportRowsToCsv(reportFilename('complaints_report', 'csv', '', ''), ['ผู้ร้องเรียน', 'บทบาท', 'หมวดหมู่', 'หัวข้อ', 'สถานะ', 'วันที่'], rows);
}

export function exportComplaintsExcel(ctx) {
  _ctx = ctx || _ctx;
  const { exportRowsToExcel, reportFilename, fmtDate } = _deps();

  const rows = (globalThis._filteredComplaints || globalThis._allComplaints || []).map((t) => ({
    ผู้ร้องเรียน: globalThis._complaintUserMap?.[t.user_id]?.full_name || '-',
    บทบาท: globalThis._complaintUserMap?.[t.user_id]?.role || '-',
    หมวดหมู่: globalThis._complaintCategoryMap?.[t.category] || t.category || '-',
    หัวข้อ: t.subject || '-',
    สถานะ: t.status || '-',
    วันที่: fmtDate(t.created_at),
  }));
  exportRowsToExcel(reportFilename('complaints_report', 'xls', '', ''), ['ผู้ร้องเรียน', 'บทบาท', 'หมวดหมู่', 'หัวข้อ', 'สถานะ', 'วันที่'], rows);
}

export async function updateComplaintStatus(id, status, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml, refreshCurrentPage } = _deps();

  try {
    await callAdminAction({ action: 'update_ticket_status', id, status });
    refreshCurrentPage();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function resolveComplaint(id, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml, refreshCurrentPage } = _deps();

  const resolution = prompt('วิธีแก้ไข / หมายเหตุ:');
  if (!resolution) return;
  try {
    await callAdminAction({ action: 'resolve_ticket', id, resolution });
    refreshCurrentPage();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function viewComplaintDetail(id, ctx) {
  _ctx = ctx || _ctx;
  const { supabase, escapeHtml, fmtDate } = _deps();

  const { data: t } = await supabase.from('support_tickets').select('*').eq('id', id).single();
  if (!t) return;
  let userName = '-';
  if (t.user_id) {
    const { data: p } = await supabase.from('profiles').select('full_name, role').eq('id', t.user_id).maybeSingle();
    if (p) userName = `${escapeHtml(p.full_name)} (${escapeHtml(p.role)})`;
  }
  alert(
    `📋 รายละเอียดร้องเรียน\n\n` +
      `ผู้ร้องเรียน: ${userName}\n` +
      `หมวดหมู่: ${t.category || '-'}\n` +
      `หัวข้อ: ${t.subject || '-'}\n` +
      `รายละเอียด: ${t.description || '-'}\n` +
      `สถานะ: ${t.status}\n` +
      `Booking ID: ${t.booking_id ? '#' + t.booking_id.substring(0, 8) : '-'}\n` +
      `วันที่: ${fmtDate(t.created_at)}\n` +
      `วิธีแก้ไข: ${t.resolution || 'ยังไม่ได้แก้ไข'}`,
  );
}

export function wireComplaintsBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  globalThis.__adminWebBridge.renderComplaintsPage = renderComplaintsPage;
  globalThis.__adminWebBridge.renderComplaintRows = renderComplaintRows;
  globalThis.__adminWebBridge.filterComplaints = filterComplaints;
  globalThis.__adminWebBridge.exportComplaintsCsv = exportComplaintsCsv;
  globalThis.__adminWebBridge.exportComplaintsExcel = exportComplaintsExcel;
  globalThis.__adminWebBridge.updateComplaintStatus = updateComplaintStatus;
  globalThis.__adminWebBridge.resolveComplaint = resolveComplaint;
  globalThis.__adminWebBridge.viewComplaintDetail = viewComplaintDetail;
}
