let _ctx = null;

function _deps() {
  const supabase = _ctx?.supabase || globalThis.supabase;
  const fmt = _ctx?.fmt || globalThis.fmt;
  const escapeHtml = _ctx?.escapeHtml || globalThis.escapeHtml;
  const statCard = _ctx?.statCard || globalThis.statCard;
  const renderMiniBarChart = _ctx?.renderMiniBarChart || globalThis.renderMiniBarChart;
  const exportRowsToCsv = _ctx?.exportRowsToCsv || globalThis.exportRowsToCsv;
  const exportRowsToExcel = _ctx?.exportRowsToExcel || globalThis.exportRowsToExcel;
  const reportFilename = _ctx?.reportFilename || globalThis.reportFilename;

  return {
    supabase,
    fmt,
    escapeHtml,
    statCard,
    renderMiniBarChart,
    exportRowsToCsv,
    exportRowsToExcel,
    reportFilename,
  };
}

export async function renderRevenuePage(el, ctx) {
  _ctx = ctx || null;

  const { supabase, escapeHtml } = _deps();

  const today = new Date();
  const monthAgo = new Date(today);
  monthAgo.setDate(monthAgo.getDate() - 30);

  const { data: drivers } = await supabase
    .from('profiles')
    .select('id, full_name, phone_number')
    .eq('role', 'driver')
    .order('full_name');

  globalThis._revenueDrivers = drivers || [];

  el.innerHTML = `
    <div class="fade-in space-y-5">
      <div class="glass-card p-4 flex flex-wrap gap-3 items-center">
        <span class="material-icons-round text-indigo-400 text-lg">date_range</span>
        <input type="date" id="revDateFrom" value="${monthAgo.toISOString().split('T')[0]}" class="border border-gray-200 rounded-xl px-3.5 py-2 text-sm bg-gray-50/50 transition-all" />
        <span class="text-gray-300 text-sm font-medium">ถึง</span>
        <input type="date" id="revDateTo" value="${today.toISOString().split('T')[0]}" class="border border-gray-200 rounded-xl px-3.5 py-2 text-sm bg-gray-50/50 transition-all" />
        <select id="revWalletDriver" class="border border-gray-200 rounded-xl px-3.5 py-2 text-sm bg-gray-50/50 transition-all min-w-[260px]">
          <option value="">คนขับทั้งหมด</option>
          ${(drivers || [])
            .map(
              (d) =>
                `<option value="${d.id}">${escapeHtml(d.full_name) || 'ไม่ระบุชื่อ'}${d.phone_number ? ' (' + escapeHtml(d.phone_number) + ')' : ''}</option>`,
            )
            .join('')}
        </select>
        <button onclick="loadRevenue()" class="text-white px-5 py-2 rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">กรอง</button>
        <button onclick="exportRevenueCsv()" class="px-4 py-2 rounded-xl text-sm font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100 transition-colors">Export CSV</button>
        <button onclick="exportRevenueExcel()" class="px-4 py-2 rounded-xl text-sm font-semibold bg-cyan-50 text-cyan-700 border border-cyan-200 hover:bg-cyan-100 transition-colors">Export Excel</button>
      </div>
      <div id="revenueContent"><div class="flex justify-center py-10"><div class="loader"></div></div></div>
    </div>`;

  globalThis.loadRevenue = loadRevenue;
  globalThis.exportRevenueCsv = exportRevenueCsv;
  globalThis.exportRevenueExcel = exportRevenueExcel;

  await loadRevenue();
}

export async function loadRevenue(ctx) {
  _ctx = ctx || _ctx;

  const { supabase, fmt, statCard, renderMiniBarChart } = _deps();

  const from = document.getElementById('revDateFrom')?.value;
  const to = document.getElementById('revDateTo')?.value;
  const selectedDriverId = document.getElementById('revWalletDriver')?.value || '';
  const startDate = from
    ? new Date(from + 'T00:00:00').toISOString()
    : new Date(new Date().setDate(new Date().getDate() - 30)).toISOString();
  const endDate = to ? new Date(to + 'T23:59:59').toISOString() : new Date().toISOString();

  const rc = document.getElementById('revenueContent');
  if (!rc) return;
  rc.innerHTML = '<div class="flex justify-center py-10"><div class="loader"></div></div>';

  const driverList = globalThis._revenueDrivers || [];
  const scopedDriverIds = selectedDriverId ? [selectedDriverId] : driverList.map((d) => d.id);

  let walletsRes = { data: [] };
  let walletTxRes = { data: [] };
  let topupRes = { data: [] };
  let withdrawalRes = { data: [] };

  const [bookingsRes, commissionRes, configRes] = await Promise.all([
    supabase
      .from('bookings')
      .select('price, delivery_fee, service_type, status, created_at')
      .gte('created_at', startDate)
      .lte('created_at', endDate)
      .eq('status', 'completed'),
    supabase
      .from('wallet_transactions')
      .select('amount, type, created_at')
      .gte('created_at', startDate)
      .lte('created_at', endDate)
      .eq('type', 'commission'),
    supabase.from('system_config').select('platform_fee_rate, merchant_gp_rate, commission_rate').maybeSingle(),
  ]);

  if (scopedDriverIds.length) {
    walletsRes = await supabase.from('wallets').select('id, user_id, balance').in('user_id', scopedDriverIds);

    const walletIds = (walletsRes.data || []).map((w) => w.id).filter(Boolean);
    if (walletIds.length) {
      walletTxRes = await supabase
        .from('wallet_transactions')
        .select('wallet_id, amount, type, created_at')
        .in('wallet_id', walletIds)
        .gte('created_at', startDate)
        .lte('created_at', endDate)
        .eq('type', 'commission');
    }

    topupRes = await supabase
      .from('topup_requests')
      .select('user_id, amount, created_at, status')
      .in('user_id', scopedDriverIds)
      .gte('created_at', startDate)
      .lte('created_at', endDate)
      .eq('status', 'completed');

    withdrawalRes = await supabase
      .from('withdrawal_requests')
      .select('user_id, amount, created_at, status')
      .in('user_id', scopedDriverIds)
      .gte('created_at', startDate)
      .lte('created_at', endDate)
      .eq('status', 'completed');
  }

  const items = bookingsRes.data || [];
  const commissions = commissionRes.data || [];
  const config = configRes.data || {};
  const wallets = walletsRes.data || [];
  const walletDeductions = walletTxRes.data || [];
  const topups = topupRes.data || [];
  const withdrawals = withdrawalRes.data || [];
  const pfRate = config.platform_fee_rate || 0.15;
  const mgRate = config.merchant_gp_rate || 0.1;
  const cmRate = config.commission_rate || 15;

  const byType = {
    food: { count: 0, revenue: 0, platformFee: 0 },
    ride: { count: 0, revenue: 0, platformFee: 0 },
    parcel: { count: 0, revenue: 0, platformFee: 0 },
  };
  let totalRevenue = 0;
  let totalPlatformIncome = 0;

  items.forEach((b) => {
    const type = b.service_type || 'other';
    const amt = (b.price || 0) + (b.delivery_fee || 0);
    totalRevenue += amt;
    let pf = 0;
    if (type === 'food') {
      pf = (b.delivery_fee || 0) * pfRate + (b.price || 0) * mgRate;
    } else {
      pf = (b.price || 0) * (cmRate / 100);
    }
    totalPlatformIncome += pf;
    if (byType[type]) {
      byType[type].count += 1;
      byType[type].revenue += amt;
      byType[type].platformFee += pf;
    }
  });

  const actualCommission = commissions.reduce((s, c) => s + Math.abs(c.amount || 0), 0);
  const platformIncome = actualCommission > 0 ? actualCommission : totalPlatformIncome;

  const byDate = {};
  items.forEach((b) => {
    const d = new Date(b.created_at).toISOString().split('T')[0];
    if (!byDate[d]) byDate[d] = { total: 0, count: 0 };
    byDate[d].total += (b.price || 0) + (b.delivery_fee || 0);
    byDate[d].count += 1;
  });
  const sortedDates = Object.keys(byDate).sort().reverse();

  const revenueTypeChartRows = [
    { label: 'อาหาร', value: byType.food.revenue, displayValue: '฿' + fmt(Math.round(byType.food.revenue)) },
    { label: 'เรียกรถ', value: byType.ride.revenue, displayValue: '฿' + fmt(Math.round(byType.ride.revenue)) },
    { label: 'พัสดุ', value: byType.parcel.revenue, displayValue: '฿' + fmt(Math.round(byType.parcel.revenue)) },
  ];

  const driverMap = new Map(driverList.map((d) => [d.id, d]));
  const walletByUser = new Map();
  wallets.forEach((w) => {
    walletByUser.set(w.user_id, (walletByUser.get(w.user_id) || 0) + Number(w.balance || 0));
  });

  const walletIdToUser = new Map();
  wallets.forEach((w) => walletIdToUser.set(w.id, w.user_id));

  const perDriver = new Map();
  scopedDriverIds.forEach((userId) => {
    const p = driverMap.get(userId) || {};
    perDriver.set(userId, {
      userId,
      name: p.full_name || 'ไม่ระบุชื่อ',
      phone: p.phone_number || '-',
      balance: walletByUser.get(userId) || 0,
      deducted: 0,
      topup: 0,
      withdraw: 0,
    });
  });

  walletDeductions.forEach((tx) => {
    const userId = walletIdToUser.get(tx.wallet_id);
    if (!userId || !perDriver.has(userId)) return;
    perDriver.get(userId).deducted += Math.abs(Number(tx.amount || 0));
  });

  topups.forEach((t) => {
    if (!perDriver.has(t.user_id)) return;
    perDriver.get(t.user_id).topup += Number(t.amount || 0);
  });

  withdrawals.forEach((w) => {
    if (!perDriver.has(w.user_id)) return;
    perDriver.get(w.user_id).withdraw += Number(w.amount || 0);
  });

  const walletRows = Array.from(perDriver.values()).sort((a, b) => b.balance - a.balance);
  const totalDriverWalletBalance = walletRows.reduce((s, r) => s + r.balance, 0);
  const totalDeducted = walletRows.reduce((s, r) => s + r.deducted, 0);
  const totalTopup = walletRows.reduce((s, r) => s + r.topup, 0);
  const totalWithdraw = walletRows.reduce((s, r) => s + r.withdraw, 0);

  const walletChartRows = [
    { label: 'เครดิตรวม', value: totalDriverWalletBalance, displayValue: '฿' + fmt(Math.round(totalDriverWalletBalance)) },
    { label: 'หักแล้ว', value: totalDeducted, displayValue: '฿' + fmt(Math.round(totalDeducted)) },
    { label: 'เติมเงิน', value: totalTopup, displayValue: '฿' + fmt(Math.round(totalTopup)) },
    { label: 'ถอนเงิน', value: totalWithdraw, displayValue: '฿' + fmt(Math.round(totalWithdraw)) },
  ];

  globalThis._revenueExportRows = walletRows.map((row) => ({
    คนขับ: row.name,
    เบอร์โทร: row.phone,
    เครดิตคงเหลือ: Math.round(row.balance),
    หักแล้ว: Math.round(row.deducted),
    เติมทั้งหมด: Math.round(row.topup),
    ถอนทั้งหมด: Math.round(row.withdraw),
  }));

  rc.innerHTML = `
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
      ${statCard('payments', 'ยอดรวมทั้งหมด', '฿' + fmt(Math.round(totalRevenue)), 'bg-green-500')}
      ${statCard('account_balance', 'GP ระบบ', '฿' + fmt(Math.round(platformIncome)), 'bg-blue-500')}
      ${statCard('restaurant', 'อาหาร', '฿' + fmt(Math.round(byType.food.revenue)) + ' (' + byType.food.count + ')', 'bg-orange-500')}
      ${statCard('local_taxi', 'เรียกรถ+พัสดุ', '฿' + fmt(Math.round(byType.ride.revenue + byType.parcel.revenue)) + ' (' + (byType.ride.count + byType.parcel.count) + ')', 'bg-purple-500')}
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-5 mt-6">
      ${renderMiniBarChart('สรุปรายได้ตามบริการ', `${from || '-'} ถึง ${to || '-'}`, revenueTypeChartRows, '#10b981')}
      ${renderMiniBarChart('สรุปกระเป๋าคนขับ', `${selectedDriverId ? 'รายบุคคล' : 'ทุกคนขับ'}`, walletChartRows, '#06b6d4')}
    </div>

    <div class="glass-card p-6 mt-6">
      <div class="flex items-center gap-3 mb-5">
        <div class="w-10 h-10 bg-cyan-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-cyan-600">account_balance_wallet</span></div>
        <div>
          <h3 class="font-bold text-gray-800">รายงานยอดเครดิต (Wallet)</h3>
          <p class="text-xs text-gray-400">${selectedDriverId ? 'รายบุคคล' : 'คนขับทั้งหมด'} • ${from || '-'} ถึง ${to || '-'}</p>
        </div>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4">
        ${statCard('wallet', 'ยอดเครดิตรวมทั้งหมดของคนขับ', '฿' + fmt(Math.round(totalDriverWalletBalance)), 'bg-cyan-500')}
        ${statCard('trending_down', 'ยอดเครดิตที่หักแล้ว', '฿' + fmt(Math.round(totalDeducted)), 'bg-rose-500')}
        ${statCard('add_circle', 'ยอดเติมทั้งหมด', '฿' + fmt(Math.round(totalTopup)), 'bg-emerald-500')}
        ${statCard('north_east', 'ยอดถอนทั้งหมด', '฿' + fmt(Math.round(totalWithdraw)), 'bg-amber-500')}
      </div>

      <div class="overflow-x-auto mt-5 border border-gray-100 rounded-2xl">
        <table class="w-full text-sm">
          <thead>
            <tr class="bg-gray-50/80">
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">คนขับ</th>
              <th class="px-5 py-3 text-right text-xs font-semibold text-gray-400 uppercase tracking-wider">เครดิตคงเหลือ</th>
              <th class="px-5 py-3 text-right text-xs font-semibold text-gray-400 uppercase tracking-wider">หักแล้ว</th>
              <th class="px-5 py-3 text-right text-xs font-semibold text-gray-400 uppercase tracking-wider">เติมทั้งหมด</th>
              <th class="px-5 py-3 text-right text-xs font-semibold text-gray-400 uppercase tracking-wider">ถอนทั้งหมด</th>
            </tr>
          </thead>
          <tbody class="divide-y divide-gray-100">
            ${walletRows.length === 0
              ? '<tr><td colspan="5" class="px-5 py-8 text-center text-gray-400">ไม่พบข้อมูล Wallet ของคนขับในเงื่อนไขที่เลือก</td></tr>'
              : walletRows
                  .map(
                    (row) => `
                <tr class="table-row">
                  <td class="px-5 py-3.5">
                    <div class="font-semibold text-gray-700">${row.name}</div>
                    <div class="text-xs text-gray-400">${row.phone}</div>
                  </td>
                  <td class="px-5 py-3.5 text-right font-bold text-cyan-700">฿${fmt(Math.round(row.balance))}</td>
                  <td class="px-5 py-3.5 text-right font-semibold text-rose-600">฿${fmt(Math.round(row.deducted))}</td>
                  <td class="px-5 py-3.5 text-right font-semibold text-emerald-600">฿${fmt(Math.round(row.topup))}</td>
                  <td class="px-5 py-3.5 text-right font-semibold text-amber-600">฿${fmt(Math.round(row.withdraw))}</td>
                </tr>
              `,
                  )
                  .join('')}
          </tbody>
        </table>
      </div>
    </div>

    <div class="glass-card p-6 mt-6">
      <div class="flex items-center gap-3 mb-5">
        <div class="w-10 h-10 bg-blue-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-blue-500">analytics</span></div>
        <div>
          <h3 class="font-bold text-gray-800">รายละเอียด GP ระบบ</h3>
          <p class="text-xs text-gray-400">แยกตามประเภทบริการ</p>
        </div>
      </div>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div class="bg-orange-50/70 rounded-2xl p-5 border border-orange-100">
          <div class="flex items-center gap-2 mb-2">
            <div class="w-8 h-8 bg-orange-100 rounded-xl flex items-center justify-center"><span class="material-icons-round text-orange-500 text-sm">restaurant</span></div>
            <p class="text-sm text-orange-600 font-semibold">อาหาร</p>
          </div>
          <p class="text-2xl font-extrabold text-orange-700">฿${fmt(Math.round(byType.food.platformFee))}</p>
          <p class="text-xs text-orange-400 mt-1">Platform Fee ${(pfRate * 100).toFixed(0)}% + GP ${(mgRate * 100).toFixed(0)}%</p>
          <p class="text-xs text-gray-400 mt-0.5">${byType.food.count} ออเดอร์</p>
        </div>
        <div class="bg-blue-50/70 rounded-2xl p-5 border border-blue-100">
          <div class="flex items-center gap-2 mb-2">
            <div class="w-8 h-8 bg-blue-100 rounded-xl flex items-center justify-center"><span class="material-icons-round text-blue-500 text-sm">directions_car</span></div>
            <p class="text-sm text-blue-600 font-semibold">เรียกรถ</p>
          </div>
          <p class="text-2xl font-extrabold text-blue-700">฿${fmt(Math.round(byType.ride.platformFee))}</p>
          <p class="text-xs text-blue-400 mt-1">คอมมิชชั่น ${cmRate}%</p>
          <p class="text-xs text-gray-400 mt-0.5">${byType.ride.count} ออเดอร์</p>
        </div>
        <div class="bg-violet-50/70 rounded-2xl p-5 border border-violet-100">
          <div class="flex items-center gap-2 mb-2">
            <div class="w-8 h-8 bg-violet-100 rounded-xl flex items-center justify-center"><span class="material-icons-round text-violet-500 text-sm">inventory_2</span></div>
            <p class="text-sm text-violet-600 font-semibold">พัสดุ</p>
          </div>
          <p class="text-2xl font-extrabold text-violet-700">฿${fmt(Math.round(byType.parcel.platformFee))}</p>
          <p class="text-xs text-violet-400 mt-1">คอมมิชชั่น ${cmRate}%</p>
          <p class="text-xs text-gray-400 mt-0.5">${byType.parcel.count} ออเดอร์</p>
        </div>
      </div>
    </div>

    <div class="glass-card overflow-hidden mt-6">
      <div class="px-6 py-5 flex items-center justify-between">
        <div class="flex items-center gap-3">
          <div class="w-10 h-10 bg-emerald-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-emerald-500">bar_chart</span></div>
          <div>
            <h3 class="font-bold text-gray-800">รายได้รายวัน</h3>
            <p class="text-xs text-gray-400">${sortedDates.length} วัน</p>
          </div>
        </div>
      </div>
      <div class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead><tr class="bg-gray-50/80">
            <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">วันที่</th>
            <th class="px-5 py-3 text-right text-xs font-semibold text-gray-400 uppercase tracking-wider">จำนวน</th>
            <th class="px-5 py-3 text-right text-xs font-semibold text-gray-400 uppercase tracking-wider">รายได้</th>
            <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider" style="width:40%">กราฟ</th>
          </tr></thead>
          <tbody class="divide-y divide-gray-100">
            ${sortedDates.length === 0
              ? '<tr><td colspan="4" class="px-5 py-8 text-center text-gray-400">ไม่มีข้อมูลในช่วงนี้</td></tr>'
              : sortedDates
                  .map((d) => {
                    const maxRev = Math.max(...Object.values(byDate).map((v) => v.total), 1);
                    const pct = Math.round((byDate[d].total / maxRev) * 100);
                    return `<tr class="table-row">
                <td class="px-5 py-3.5 font-medium text-gray-700">${new Date(d).toLocaleDateString('th-TH', { day: 'numeric', month: 'short', year: 'numeric' })}</td>
                <td class="px-5 py-3.5 text-right text-gray-400">${byDate[d].count} รายการ</td>
                <td class="px-5 py-3.5 text-right font-bold text-emerald-600">฿${fmt(Math.round(byDate[d].total))}</td>
                <td class="px-5 py-3.5"><div class="h-4 bg-gray-100 rounded-full overflow-hidden"><div class="h-full rounded-full transition-all" style="width:${pct}%;background:linear-gradient(90deg,#10b981,#14b8a6);"></div></div></td>
              </tr>`;
                  })
                  .join('')}
          </tbody>
        </table>
      </div>
    </div>
  `;
}

export function exportRevenueCsv(ctx) {
  _ctx = ctx || _ctx;
  const { exportRowsToCsv, reportFilename } = _deps();
  const from = document.getElementById('revDateFrom')?.value || '';
  const to = document.getElementById('revDateTo')?.value || '';
  const rows = globalThis._revenueExportRows || [];
  exportRowsToCsv(reportFilename('revenue_wallet_report', 'csv', from, to), ['คนขับ', 'เบอร์โทร', 'เครดิตคงเหลือ', 'หักแล้ว', 'เติมทั้งหมด', 'ถอนทั้งหมด'], rows);
}

export function exportRevenueExcel(ctx) {
  _ctx = ctx || _ctx;
  const { exportRowsToExcel, reportFilename } = _deps();
  const from = document.getElementById('revDateFrom')?.value || '';
  const to = document.getElementById('revDateTo')?.value || '';
  const rows = globalThis._revenueExportRows || [];
  exportRowsToExcel(reportFilename('revenue_wallet_report', 'xls', from, to), ['คนขับ', 'เบอร์โทร', 'เครดิตคงเหลือ', 'หักแล้ว', 'เติมทั้งหมด', 'ถอนทั้งหมด'], rows);
}

export function wireRevenueBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  globalThis.__adminWebBridge.renderRevenuePage = renderRevenuePage;
  globalThis.__adminWebBridge.loadRevenue = loadRevenue;
  globalThis.__adminWebBridge.exportRevenueCsv = exportRevenueCsv;
  globalThis.__adminWebBridge.exportRevenueExcel = exportRevenueExcel;
}
