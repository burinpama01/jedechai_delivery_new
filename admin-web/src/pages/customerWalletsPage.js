let _ctx = null;

function _deps() {
  return {
    supabase: _ctx?.supabase || globalThis.supabase,
    callAdminAction: _ctx?.callAdminAction || globalThis.callAdminAction,
    showToast: _ctx?.showToast || globalThis.showToast,
    escapeHtml: _ctx?.escapeHtml || globalThis.escapeHtml || ((value) => String(value ?? '')),
    fmt: _ctx?.fmt || globalThis.fmt || ((value) => new Intl.NumberFormat('th-TH').format(value || 0)),
    fmtDate: _ctx?.fmtDate || globalThis.fmtDate || ((value) => value ? new Date(value).toLocaleString('th-TH') : '-'),
    refreshCurrentPage: _ctx?.refreshCurrentPage || globalThis.refreshCurrentPage || (() => {}),
    fetchUserEmails: _ctx?.fetchUserEmails || globalThis.fetchUserEmails,
  };
}

function walletMoney(value) {
  return '฿' + new Intl.NumberFormat('th-TH').format(Math.round(Number(value || 0)));
}

function txLabel(type) {
  switch (type) {
    case 'topup':
      return 'เติมเงิน';
    case 'payment':
      return 'ชำระออเดอร์';
    case 'refund':
      return 'คืนเงิน';
    case 'withdrawal_pending':
      return 'ถอนเงินรอดำเนินการ';
    case 'adjustment':
    case 'admin_adjustment':
      return 'ปรับยอด';
    default:
      return type || '-';
  }
}

function txClass(amount) {
  return Number(amount || 0) >= 0 ? 'text-emerald-600' : 'text-rose-600';
}

function isDisplayableWalletTransaction(tx) {
  return !['invalid_refund', 'invalid_refund_reversal'].includes(tx?.type);
}

async function loadCustomerWalletRows() {
  const { supabase, fetchUserEmails } = _deps();
  const [{ data: customers }, emailMap] = await Promise.all([
    supabase
      .from('profiles')
      .select('id, full_name, phone_number, role, approval_status, created_at')
      .eq('role', 'customer')
      .order('created_at', { ascending: false })
      .limit(200),
    typeof fetchUserEmails === 'function' ? fetchUserEmails() : Promise.resolve({}),
  ]);

  const customerRows = customers || [];
  const customerIds = customerRows.map((c) => c.id).filter(Boolean);
  let wallets = [];
  if (customerIds.length) {
    const { data } = await supabase
      .from('wallets')
      .select('id, user_id, balance, updated_at')
      .in('user_id', customerIds);
    wallets = data || [];
  }

  const walletIds = wallets.map((w) => w.id).filter(Boolean);
  let transactions = [];
  if (walletIds.length) {
    const { data } = await supabase
      .from('wallet_transactions')
      .select('id, wallet_id, amount, type, description, related_booking_id, created_at')
      .in('wallet_id', walletIds)
      .order('created_at', { ascending: false })
      .limit(200);
    transactions = (data || []).filter(isDisplayableWalletTransaction);
  }

  const walletByUser = {};
  wallets.forEach((w) => {
    walletByUser[w.user_id] = w;
  });
  const txByWallet = {};
  transactions.forEach((tx) => {
    if (!txByWallet[tx.wallet_id]) txByWallet[tx.wallet_id] = [];
    txByWallet[tx.wallet_id].push(tx);
  });

  return customerRows.map((customer) => {
    const wallet = walletByUser[customer.id] || null;
    return {
      customer,
      wallet,
      email: emailMap?.[customer.id] || '',
      transactions: wallet?.id ? (txByWallet[wallet.id] || []) : [],
    };
  });
}

export async function renderCustomerWalletsPage(el, ctx) {
  _ctx = ctx || _ctx;
  const { escapeHtml, fmt, fmtDate } = _deps();

  el.innerHTML = `
    <div class="space-y-5">
      <div class="bg-white rounded-2xl shadow-sm border border-gray-100 p-5 flex flex-col gap-3 md:flex-row md:items-center md:justify-between">
        <div>
          <h3 class="font-bold text-gray-800 text-lg">Customer Wallet</h3>
          <p class="text-xs text-gray-400 mt-1">ดูยอด wallet ลูกค้า เติมเงินด้วยมือ และตรวจ transaction ล่าสุด</p>
        </div>
        <button onclick="showCustomerWalletManualTopup()" class="px-5 py-2 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200 flex items-center gap-1.5" style="background:linear-gradient(135deg,#6366f1,#818cf8);">
          <span class="material-icons-round text-sm">add</span> เติมเงินลูกค้าด้วยมือ
        </button>
      </div>
      <div id="customerWalletsContent" class="bg-white rounded-2xl shadow-sm border border-gray-100 p-5">
        <div class="flex justify-center py-10"><div class="loader"></div></div>
      </div>
    </div>`;

  let rows = [];
  try {
    rows = await loadCustomerWalletRows();
  } catch (e) {
    el.querySelector('#customerWalletsContent').innerHTML = `
      <div class="text-center py-10 text-rose-500">
        <span class="material-icons-round text-4xl">error</span>
        <p class="mt-2 text-sm">${escapeHtml(e.message || e)}</p>
      </div>`;
    return;
  }

  const totalBalance = rows.reduce((sum, row) => sum + Number(row.wallet?.balance || 0), 0);
  const activeWallets = rows.filter((row) => row.wallet).length;
  globalThis._customerWalletRows = rows;

  const content = el.querySelector('#customerWalletsContent');
  content.innerHTML = `
    <div class="grid grid-cols-1 sm:grid-cols-3 gap-3 mb-5">
      <div class="rounded-xl border border-emerald-100 bg-emerald-50 p-4">
        <p class="text-xs text-emerald-600 font-semibold">ลูกค้าทั้งหมด</p>
        <p class="text-2xl font-bold text-emerald-800 mt-1">${fmt(rows.length)}</p>
      </div>
      <div class="rounded-xl border border-blue-100 bg-blue-50 p-4">
        <p class="text-xs text-blue-600 font-semibold">Wallet ที่มีแล้ว</p>
        <p class="text-2xl font-bold text-blue-800 mt-1">${fmt(activeWallets)}</p>
      </div>
      <div class="rounded-xl border border-amber-100 bg-amber-50 p-4">
        <p class="text-xs text-amber-600 font-semibold">ยอดรวม Wallet</p>
        <p class="text-2xl font-bold text-amber-800 mt-1">${walletMoney(totalBalance)}</p>
      </div>
    </div>
    <div class="overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="bg-gray-50/80">
            <th class="px-4 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ลูกค้า</th>
            <th class="px-4 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ยอด Wallet</th>
            <th class="px-4 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">Transaction ล่าสุด</th>
            <th class="px-4 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">อัปเดต</th>
            <th class="px-4 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">จัดการ</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100">
          ${rows.map((row) => {
            const customer = row.customer;
            const latest = row.transactions.slice(0, 3);
            return `
              <tr class="table-row border-b border-gray-50 align-top">
                <td class="px-4 py-3">
                  <div class="font-semibold text-gray-800">${escapeHtml(customer.full_name) || customer.id.substring(0, 8)}</div>
                  <div class="text-xs text-gray-400">${escapeHtml(row.email || customer.phone_number || customer.id)}</div>
                </td>
                <td class="px-4 py-3 font-bold text-emerald-600">${walletMoney(row.wallet?.balance || 0)}</td>
                <td class="px-4 py-3">
                  ${latest.length ? latest.map((tx) => `
                    <div class="flex items-start justify-between gap-3 py-1">
                      <span>
                        <span class="block text-xs font-semibold text-gray-700">${escapeHtml(txLabel(tx.type))}</span>
                        <span class="block text-[11px] text-gray-400">${escapeHtml(tx.description || '')}</span>
                      </span>
                      <span class="text-xs font-bold ${txClass(tx.amount)}">${walletMoney(tx.amount)}</span>
                    </div>
                  `).join('') : '<span class="text-xs text-gray-300">ยังไม่มี transaction</span>'}
                </td>
                <td class="px-4 py-3 text-xs text-gray-500">${fmtDate(row.wallet?.updated_at || customer.created_at)}</td>
                <td class="px-4 py-3">
                  <button onclick="showCustomerWalletManualTopup('${customer.id}')" class="px-3 py-1 bg-indigo-100 text-indigo-700 rounded-lg text-xs font-semibold hover:bg-indigo-200">เติมเงิน</button>
                </td>
              </tr>`;
          }).join('')}
        </tbody>
      </table>
    </div>`;
}

export async function showCustomerWalletManualTopup(userId = '', ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml, fmt, refreshCurrentPage } = _deps();
  const rows = globalThis._customerWalletRows || await loadCustomerWalletRows();

  if (!rows.length) {
    showToast('ยังไม่มีลูกค้าให้เติมเงิน', 'error');
    return;
  }

  const selected = rows.find((row) => row.customer.id === userId) || null;
  if (userId && !selected) {
    showToast('ไม่พบลูกค้าที่ต้องการเติมเงิน', 'error');
    return;
  }

  document.getElementById('customerWalletManualTopupModal')?.remove();

  const options = rows
    .map((row) => {
      const customer = row.customer || {};
      const id = customer.id || '';
      const name = customer.full_name || row.email || id.substring(0, 8) || 'ลูกค้า';
      const phone = customer.phone_number ? ` (${customer.phone_number})` : '';
      const balance = walletMoney(row.wallet?.balance || 0);
      const selectedAttr = id === selected?.customer?.id ? 'selected' : '';
      return `<option value="${escapeHtml(id)}" ${selectedAttr}>${escapeHtml(name + phone)} - ${balance}</option>`;
    })
    .join('');

  const modal = document.createElement('div');
  modal.id = 'customerWalletManualTopupModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50 px-4';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-lg overflow-hidden">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <div>
          <h3 class="font-bold text-gray-800 text-lg">เติมเงินลูกค้า</h3>
          <p class="text-xs text-gray-500 mt-0.5">เติมเครดิตเข้า Customer Wallet ผ่าน Admin</p>
        </div>
        <button type="button" id="customerWalletManualTopupClose" class="w-9 h-9 rounded-xl bg-gray-100 text-gray-500 hover:bg-gray-200 flex items-center justify-center">
          <span class="material-icons-round text-base">close</span>
        </button>
      </div>
      <form id="customerWalletManualTopupForm" class="p-6 space-y-4">
        <label class="block">
          <span class="text-xs font-semibold text-gray-500">ลูกค้า</span>
          <select id="customerWalletManualTopupUserId" class="mt-1 w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-200">
            ${options}
          </select>
        </label>
        <label class="block">
          <span class="text-xs font-semibold text-gray-500">จำนวนเงิน (บาท)</span>
          <input id="customerWalletManualTopupAmount" type="number" min="1" step="1" inputmode="decimal" class="mt-1 w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-200" placeholder="เช่น 100" required>
        </label>
        <label class="block">
          <span class="text-xs font-semibold text-gray-500">หมายเหตุ</span>
          <textarea id="customerWalletManualTopupDescription" rows="3" class="mt-1 w-full border border-gray-200 rounded-xl px-3 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-indigo-200">Admin เติมเงินลูกค้าด้วยมือ</textarea>
        </label>
        <div class="flex justify-end gap-2 pt-2">
          <button type="button" id="customerWalletManualTopupCancel" class="px-4 py-2 bg-gray-100 text-gray-600 rounded-lg text-sm font-medium hover:bg-gray-200">ยกเลิก</button>
          <button type="submit" id="customerWalletManualTopupSubmit" class="px-5 py-2 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">เติมเงิน</button>
        </div>
      </form>
    </div>`;

  document.body.appendChild(modal);

  const closeModal = () => modal.remove();
  modal.addEventListener('click', (e) => {
    if (e.target === modal) closeModal();
  });
  modal.querySelector('#customerWalletManualTopupClose')?.addEventListener('click', closeModal);
  modal.querySelector('#customerWalletManualTopupCancel')?.addEventListener('click', closeModal);

  const form = modal.querySelector('#customerWalletManualTopupForm');
  form?.addEventListener('submit', async (e) => {
    e.preventDefault();
    const selectedUserId = modal.querySelector('#customerWalletManualTopupUserId')?.value || '';
    const amount = Number.parseFloat(modal.querySelector('#customerWalletManualTopupAmount')?.value || '');
    const description = (modal.querySelector('#customerWalletManualTopupDescription')?.value || '').trim() || 'Admin เติมเงินลูกค้าด้วยมือ';
    if (!selectedUserId) return showToast('กรุณาเลือกลูกค้า', 'error');
    if (!Number.isFinite(amount) || amount <= 0) return showToast('จำนวนเงินไม่ถูกต้อง', 'error');

    const submitBtn = modal.querySelector('#customerWalletManualTopupSubmit');
    if (submitBtn) {
      submitBtn.disabled = true;
      submitBtn.textContent = 'กำลังเติมเงิน...';
    }

    try {
      await callAdminAction({ action: 'manual_topup', user_id: selectedUserId, amount, description });
      showToast(`เติมเงิน ฿${fmt(amount)} สำเร็จ`, 'success');
      closeModal();
      refreshCurrentPage();
    } catch (err) {
      showToast('เกิดข้อผิดพลาด: ' + escapeHtml(err.message || err), 'error');
      if (submitBtn) {
        submitBtn.disabled = false;
        submitBtn.textContent = 'เติมเงิน';
      }
    }
  });
}

export function wireCustomerWalletsBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  globalThis.__adminWebBridge.renderCustomerWalletsPage = renderCustomerWalletsPage;
  globalThis.__adminWebBridge.showCustomerWalletManualTopup = showCustomerWalletManualTopup;
  globalThis.showCustomerWalletManualTopup = showCustomerWalletManualTopup;
}
