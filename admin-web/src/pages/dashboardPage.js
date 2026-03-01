let _ctx = null;

function _deps() {
  const supabase = _ctx?.supabase || globalThis.supabase;
  const fmt = _ctx?.fmt || globalThis.fmt;
  const fmtDate = _ctx?.fmtDate || globalThis.fmtDate;
  const exportRowsToCsv = _ctx?.exportRowsToCsv || globalThis.exportRowsToCsv;
  const exportRowsToExcel = _ctx?.exportRowsToExcel || globalThis.exportRowsToExcel;
  const reportFilename = _ctx?.reportFilename || globalThis.reportFilename;
  const statCard = _ctx?.statCard || globalThis.statCard;
  const renderMiniBarChart = _ctx?.renderMiniBarChart || globalThis.renderMiniBarChart;
  const statusBadge = _ctx?.statusBadge || globalThis.statusBadge;
  const serviceIcon = _ctx?.serviceIcon || globalThis.serviceIcon;
  const _truthyFlag = _ctx?._truthyFlag || globalThis._truthyFlag;

  return {
    supabase,
    fmt,
    fmtDate,
    exportRowsToCsv,
    exportRowsToExcel,
    reportFilename,
    statCard,
    renderMiniBarChart,
    statusBadge,
    serviceIcon,
    _truthyFlag,
  };
}

export async function renderDashboardPage(el, ctx) {
  _ctx = ctx || null;

  const today = new Date();
  today.setHours(0, 0, 0, 0);
  const todayStr = today.toISOString().split('T')[0];

  el.innerHTML = `
    <div class="fade-in space-y-6">
      <div class="glass-card p-4 flex flex-wrap gap-3 items-center">
        <span class="material-icons-round text-indigo-400 text-lg">date_range</span>
        <input type="date" id="dashDateFrom" value="${todayStr}" class="border border-gray-200 rounded-xl px-3.5 py-2 text-sm bg-gray-50/50 transition-all" />
        <span class="text-gray-300 text-sm font-medium">ถึง</span>
        <input type="date" id="dashDateTo" value="${todayStr}" class="border border-gray-200 rounded-xl px-3.5 py-2 text-sm bg-gray-50/50 transition-all" />
        <button onclick="dashboardFilter()" class="text-white px-5 py-2 rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">กรอง</button>
        <button onclick="exportDashboardCsv()" class="px-4 py-2 rounded-xl text-sm font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100 transition-colors">Export CSV</button>
        <button onclick="exportDashboardExcel()" class="px-4 py-2 rounded-xl text-sm font-semibold bg-cyan-50 text-cyan-700 border border-cyan-200 hover:bg-cyan-100 transition-colors">Export Excel</button>
      </div>
      <div id="dashContent"><div class="flex justify-center py-10"><div class="loader"></div></div></div>
    </div>`;

  await dashboardFilter();
}

export async function dashboardFilter() {
  const {
    supabase,
    fmt,
    fmtDate,
    statCard,
    renderMiniBarChart,
    statusBadge,
    serviceIcon,
    _truthyFlag,
  } = _deps();

  const from = document.getElementById('dashDateFrom')?.value;
  const to = document.getElementById('dashDateTo')?.value;
  const startDate = from ? new Date(from + 'T00:00:00').toISOString() : new Date(new Date().setHours(0,0,0,0)).toISOString();
  const endDate = to ? new Date(to + 'T23:59:59').toISOString() : new Date().toISOString();

  const dc = document.getElementById('dashContent');
  if (!dc) return;
  dc.innerHTML = '<div class="flex justify-center py-10"><div class="loader"></div></div>';

  const [periodOrders, completedPeriod, revenueData, pendingDrivers, pendingMerchants, pendingWithdrawals, totalUsers, profilesByRole, recentOrders] = await Promise.all([
    supabase.from('bookings').select('id', { count: 'exact', head: true }).gte('created_at', startDate).lte('created_at', endDate),
    supabase.from('bookings').select('id', { count: 'exact', head: true }).gte('created_at', startDate).lte('created_at', endDate).eq('status', 'completed'),
    supabase.from('bookings').select('price, service_type').gte('created_at', startDate).lte('created_at', endDate).eq('status', 'completed'),
    supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('role', 'driver').eq('approval_status', 'pending'),
    supabase.from('profiles').select('id', { count: 'exact', head: true }).eq('role', 'merchant').eq('approval_status', 'pending'),
    supabase.from('withdrawal_requests').select('id', { count: 'exact', head: true }).eq('status', 'pending'),
    supabase.from('profiles').select('id', { count: 'exact', head: true }),
    supabase.from('profiles').select('role, is_online'),
    supabase.from('bookings').select('*').gte('created_at', startDate).lte('created_at', endDate).order('created_at', { ascending: false }).limit(10),
  ]);

  const revenue = (revenueData.data || []).reduce((s, r) => s + (r.price || 0), 0);
  const serviceCounts = { food: 0, ride: 0, parcel: 0 };
  (revenueData.data || []).forEach((r) => {
    if (serviceCounts[r.service_type] !== undefined) serviceCounts[r.service_type] += 1;
  });
  const roleRows = profilesByRole.data || [];
  const countByRole = (role) => roleRows.filter((p) => p.role === role).length;
  const countOnlineByRole = (role) => roleRows.filter((p) => p.role === role && _truthyFlag(p.is_online)).length;

  const userTypeStats = [
    { label: 'ลูกค้า', role: 'customer', icon: 'person', colorClass: 'blue' },
    { label: 'คนขับ', role: 'driver', icon: 'directions_car', colorClass: 'indigo' },
    { label: 'ร้านค้า', role: 'merchant', icon: 'store', colorClass: 'orange' },
  ].map((item) => ({
    ...item,
    total: countByRole(item.role),
    online: countOnlineByRole(item.role),
  }));

  const onlineUsersTotal = userTypeStats.reduce((sum, item) => sum + item.online, 0);
  const recentRows = (recentOrders.data || []).map((o) => ({
    เลขออเดอร์: `#${(o.id || '').substring(0, 8)}`,
    ประเภท: o.service_type || '-',
    ราคา: Math.round(o.price || 0),
    สถานะ: o.status || '-',
    เวลา: fmtDate(o.created_at),
  }));
  globalThis._dashboardRecentRows = recentRows;

  dc.innerHTML = `
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
        ${statCard('receipt_long', 'ออเดอร์ช่วงนี้', fmt(periodOrders.count || 0), 'bg-blue-500')}
        ${statCard('check_circle', 'เสร็จแล้ว', fmt(completedPeriod.count || 0), 'bg-green-500')}
        ${statCard('payments', 'รายได้', '฿' + fmt(Math.round(revenue)), 'bg-orange-500')}
        ${statCard('people', 'ผู้ใช้ทั้งหมด', fmt(totalUsers.count || 0), 'bg-purple-500')}
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-5 mt-6">
        ${renderMiniBarChart('สรุปบริการที่เสร็จสิ้น', `${from || '-'} ถึง ${to || '-'}`, [
          { label: 'อาหาร', value: serviceCounts.food, displayValue: fmt(serviceCounts.food) },
          { label: 'เรียกรถ', value: serviceCounts.ride, displayValue: fmt(serviceCounts.ride) },
          { label: 'พัสดุ', value: serviceCounts.parcel, displayValue: fmt(serviceCounts.parcel) },
        ], '#6366f1')}
        ${renderMiniBarChart('ผู้ใช้งานออนไลน์ตามประเภท', `ออนไลน์รวม ${fmt(onlineUsersTotal)} คน`, userTypeStats.map((item) => ({
          label: item.label,
          value: item.online,
          displayValue: `${fmt(item.online)} / ${fmt(item.total)}`,
        })), '#10b981')}
      </div>

      <div class="glass-card p-5 mt-6">
        <div class="flex flex-wrap gap-3 items-center justify-between">
          <div class="flex items-center gap-2">
            <span class="material-icons-round text-indigo-500">groups</span>
            <h3 class="font-bold text-gray-800">ผู้ใช้งานตามประเภท</h3>
          </div>
          <span class="inline-flex items-center px-3 py-1 rounded-full text-xs font-semibold bg-green-100 text-green-700">
            ออนไลน์รวม ${fmt(onlineUsersTotal)}
          </span>
        </div>
        <div class="mt-4 space-y-3">
          ${userTypeStats.map((item) => `
            <div class="flex items-center gap-3 p-3 rounded-xl bg-gray-50/80">
              <div class="w-9 h-9 rounded-xl flex items-center justify-center bg-${item.colorClass}-100 text-${item.colorClass}-600">
                <span class="material-icons-round text-base">${item.icon}</span>
              </div>
              <div class="flex-1">
                <p class="text-sm font-semibold text-gray-700">${item.label}</p>
              </div>
              <p class="text-sm text-gray-500">ทั้งหมด ${fmt(item.total)}</p>
              <span class="inline-flex items-center px-2.5 py-1 rounded-lg text-xs font-semibold bg-green-100 text-green-700">
                ออนไลน์ ${fmt(item.online)}
              </span>
            </div>
          `).join('')}
        </div>
      </div>

      <div class="grid grid-cols-1 md:grid-cols-3 gap-5 mt-6">
        ${globalThis.pendingCard('คนขับรอการอนุมัติ', pendingDrivers.count || 0, 'directions_car', 'blue', 'drivers')}
        ${globalThis.pendingCard('ร้านค้ารอการอนุมัติ', pendingMerchants.count || 0, 'store', 'emerald', 'merchants')}
        ${globalThis.pendingCard('คำขอถอนเงิน', pendingWithdrawals.count || 0, 'account_balance_wallet', 'orange', 'withdrawals')}
      </div>

      <div class="glass-card overflow-hidden mt-6">
        <div class="px-6 py-5 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class="w-10 h-10 bg-indigo-50 rounded-xl flex items-center justify-center">
              <span class="material-icons-round text-indigo-500">receipt_long</span>
            </div>
            <div>
              <h3 class="font-bold text-gray-800">ออเดอร์ล่าสุด</h3>
              <p class="text-xs text-gray-400">10 รายการล่าสุด</p>
            </div>
          </div>
          <a href="#" onclick="navigateTo('orders');return false" class="text-sm text-indigo-500 hover:text-indigo-600 font-semibold flex items-center gap-1 transition-colors">ดูทั้งหมด <span class="material-icons-round text-sm">arrow_forward</span></a>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead><tr class="bg-gray-50/80">
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ID</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ประเภท</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ราคา</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">สถานะ</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">เวลา</th>
            </tr></thead>
            <tbody class="divide-y divide-gray-100">
              ${(recentOrders.data || []).map(o => `
                <tr class="table-row">
                  <td class="px-5 py-3.5 font-mono text-xs text-gray-400">#${o.id.substring(0,8)}</td>
                  <td class="px-5 py-3.5"><span class="flex items-center gap-2">${serviceIcon(o.service_type)} <span class="text-gray-600 font-medium">${o.service_type}</span></span></td>
                  <td class="px-5 py-3.5 font-bold text-gray-800">฿${fmt(Math.round(o.price))}</td>
                  <td class="px-5 py-3.5">${statusBadge(o.status)}</td>
                  <td class="px-5 py-3.5 text-gray-400 text-xs">${fmtDate(o.created_at)}</td>
                </tr>
              `).join('')}
            </tbody>
          </table>
        </div>
      </div>
  `;
}

export function exportDashboardCsv() {
  const { exportRowsToCsv, reportFilename } = _deps();
  const from = document.getElementById('dashDateFrom')?.value || '';
  const to = document.getElementById('dashDateTo')?.value || '';
  const rows = globalThis._dashboardRecentRows || [];
  exportRowsToCsv(
    reportFilename('dashboard_recent_orders', 'csv', from, to),
    ['เลขออเดอร์', 'ประเภท', 'ราคา', 'สถานะ', 'เวลา'],
    rows,
  );
}

export function exportDashboardExcel() {
  const { exportRowsToExcel, reportFilename } = _deps();
  const from = document.getElementById('dashDateFrom')?.value || '';
  const to = document.getElementById('dashDateTo')?.value || '';
  const rows = globalThis._dashboardRecentRows || [];
  exportRowsToExcel(
    reportFilename('dashboard_recent_orders', 'xls', from, to),
    ['เลขออเดอร์', 'ประเภท', 'ราคา', 'สถานะ', 'เวลา'],
    rows,
  );
}

export function wireDashboardBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  globalThis.__adminWebBridge.renderDashboardPage = renderDashboardPage;
  globalThis.__adminWebBridge.dashboardFilter = dashboardFilter;
  globalThis.__adminWebBridge.exportDashboardCsv = exportDashboardCsv;
  globalThis.__adminWebBridge.exportDashboardExcel = exportDashboardExcel;
}
