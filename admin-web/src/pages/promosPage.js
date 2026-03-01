let _ctx = null;
let _promoFilter = 'all';
let _promoMerchants = [];

function _deps() {
  const supabase = _ctx?.supabase || globalThis.supabase;
  const callAdminAction = _ctx?.callAdminAction || globalThis.callAdminAction;
  const showToast = _ctx?.showToast || globalThis.showToast;
  const refreshCurrentPage = _ctx?.refreshCurrentPage || globalThis.refreshCurrentPage;
  const fmt = _ctx?.fmt || globalThis.fmt;
  const fmtDate = _ctx?.fmtDate || globalThis.fmtDate;
  const escapeHtml = _ctx?.escapeHtml || globalThis.escapeHtml;
  const exportRowsToCsv = _ctx?.exportRowsToCsv || globalThis.exportRowsToCsv;
  const exportRowsToExcel = _ctx?.exportRowsToExcel || globalThis.exportRowsToExcel;
  const reportFilename = _ctx?.reportFilename || globalThis.reportFilename;
  const renderMiniBarChart = _ctx?.renderMiniBarChart || globalThis.renderMiniBarChart;

  return {
    supabase,
    callAdminAction,
    showToast,
    refreshCurrentPage,
    fmt,
    fmtDate,
    escapeHtml,
    exportRowsToCsv,
    exportRowsToExcel,
    reportFilename,
    renderMiniBarChart,
  };
}

export async function renderPromosPage(el, ctx) {
  _ctx = ctx || null;
  const { supabase, fmt, renderMiniBarChart, escapeHtml } = _deps();

  const [{ data: coupons }, { data: merchants }] = await Promise.all([
    supabase.from('coupons').select('*').order('created_at', { ascending: false }),
    supabase.from('profiles').select('id, full_name').eq('role', 'merchant').order('full_name'),
  ]);

  _promoMerchants = merchants || [];
  const all = coupons || [];
  const merchantOptions = ['<option value="">คูปองส่วนกลาง (ทุกคนใช้ได้)</option>']
    .concat(_promoMerchants.map(m => `<option value="${m.id}">${escapeHtml(m.full_name) || m.id}</option>`))
    .join('');

  const now = new Date().toISOString();
  const stats = {
    total: all.length,
    active: all.filter(c => c.is_active && c.end_date > now && c.start_date <= now).length,
    expired: all.filter(c => c.end_date <= now).length,
    inactive: all.filter(c => !c.is_active).length,
  };
  const serviceCounts = { food: 0, ride: 0, parcel: 0, all: 0 };
  all.forEach((c) => {
    if (!c.service_type) serviceCounts.all += 1;
    else if (serviceCounts[c.service_type] !== undefined) serviceCounts[c.service_type] += 1;
  });

  el.innerHTML = `
    <div class="fade-in space-y-6">
      <div class="glass-card p-4 flex flex-wrap gap-3 items-center justify-end">
        <button onclick="exportPromosCsv()" class="px-4 py-2 rounded-xl text-sm font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100 transition-colors">Export CSV</button>
        <button onclick="exportPromosExcel()" class="px-4 py-2 rounded-xl text-sm font-semibold bg-cyan-50 text-cyan-700 border border-cyan-200 hover:bg-cyan-100 transition-colors">Export Excel</button>
      </div>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-5">
        <div class="glass-card p-5 cursor-pointer group" onclick="setPromoFilter('all')">
          <p class="text-xs font-semibold text-gray-400 uppercase tracking-wider">ทั้งหมด</p>
          <p class="text-2xl font-extrabold text-gray-800 mt-1">${stats.total}</p>
        </div>
        <div class="glass-card p-5 cursor-pointer group" onclick="setPromoFilter('active')">
          <p class="text-xs font-semibold text-emerald-500 uppercase tracking-wider">ใช้งานอยู่</p>
          <p class="text-2xl font-extrabold text-emerald-600 mt-1">${stats.active}</p>
        </div>
        <div class="glass-card p-5 cursor-pointer group" onclick="setPromoFilter('expired')">
          <p class="text-xs font-semibold text-rose-400 uppercase tracking-wider">หมดอายุ</p>
          <p class="text-2xl font-extrabold text-rose-500 mt-1">${stats.expired}</p>
        </div>
        <div class="glass-card p-5 cursor-pointer group" onclick="setPromoFilter('inactive')">
          <p class="text-xs font-semibold text-gray-400 uppercase tracking-wider">ปิดใช้งาน</p>
          <p class="text-2xl font-extrabold text-gray-500 mt-1">${stats.inactive}</p>
        </div>
      </div>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-5">
        ${renderMiniBarChart('สรุปสถานะโค้ดส่วนลด', 'ทั้งหมด ' + fmt(stats.total) + ' โค้ด', [
          { label: 'ใช้งานอยู่', value: stats.active, displayValue: fmt(stats.active) },
          { label: 'หมดอายุ', value: stats.expired, displayValue: fmt(stats.expired) },
          { label: 'ปิดใช้งาน', value: stats.inactive, displayValue: fmt(stats.inactive) },
        ], '#10b981')}
        ${renderMiniBarChart('สรุปบริการที่โค้ดรองรับ', 'ทุกโค้ด', [
          { label: 'ทุกบริการ', value: serviceCounts.all, displayValue: fmt(serviceCounts.all) },
          { label: 'อาหาร', value: serviceCounts.food, displayValue: fmt(serviceCounts.food) },
          { label: 'เรียกรถ', value: serviceCounts.ride, displayValue: fmt(serviceCounts.ride) },
          { label: 'พัสดุ', value: serviceCounts.parcel, displayValue: fmt(serviceCounts.parcel) },
        ], '#6366f1')}
      </div>

      <div class="glass-card p-6">
        <div class="flex items-center gap-3 mb-5">
          <div class="w-10 h-10 bg-pink-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-pink-500">add_circle</span></div>
          <div>
            <h3 class="font-bold text-gray-800">สร้างโค้ดส่วนลดใหม่</h3>
            <p class="text-xs text-gray-400">กรอกข้อมูลโปรโมชั่น</p>
          </div>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
          <div>
            <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">โค้ด <span class="text-rose-400">*</span></label>
            <input id="promoCode" type="text" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm uppercase bg-gray-50/50 transition-all" placeholder="เช่น WELCOME50" maxlength="20">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">ชื่อโปรโมชั่น <span class="text-rose-400">*</span></label>
            <input id="promoName" type="text" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50 transition-all" placeholder="เช่น ลูกค้าใหม่ลด 50%">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">คำอธิบาย</label>
            <input id="promoDesc" type="text" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50 transition-all" placeholder="รายละเอียดเพิ่มเติม (ถ้ามี)">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">ประเภทส่วนลด <span class="text-rose-400">*</span></label>
            <select id="promoType" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50 transition-all" onchange="onPromoTypeChange()">
              <option value="percentage">ลดเปอร์เซ็นต์ (%)</option>
              <option value="fixed">ลดจำนวนเงิน (฿)</option>
              <option value="free_delivery">ส่งฟรี</option>
            </select>
          </div>
          <div id="promoValueWrap">
            <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">มูลค่าส่วนลด <span class="text-rose-400">*</span></label>
            <input id="promoValue" type="number" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50 transition-all" placeholder="เช่น 10" min="0" step="1">
          </div>
          <div id="promoMaxDiscWrap">
            <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">ลดสูงสุด (฿)</label>
            <input id="promoMaxDisc" type="number" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50 transition-all" placeholder="ไม่จำกัด" min="0">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">ยอดขั้นต่ำ (฿)</label>
            <input id="promoMinOrder" type="number" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50 transition-all" placeholder="ไม่กำหนด" min="0">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">ใช้ได้กับบริการ</label>
            <select id="promoService" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50 transition-all">
              <option value="">ทุกบริการ</option>
              <option value="food">สั่งอาหาร</option>
              <option value="ride">เรียกรถ</option>
              <option value="parcel">ส่งพัสดุ</option>
            </select>
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">เจ้าของคูปอง</label>
            <select id="promoMerchant" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50 transition-all">
              ${merchantOptions}
            </select>
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">รูปแบบการแจก</label>
            <select id="promoDistributionType" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50 transition-all">
              <option value="code_only">ใช้โค้ด (Code Only)</option>
              <option value="claimable">กดรับเข้าวอลเล็ท (Claimable)</option>
              <option value="auto_grant">แจกอัตโนมัติ (Auto Grant)</option>
            </select>
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">ฐานการคำนวณส่วนลด</label>
            <select id="promoDiscountBase" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50 transition-all">
              <option value="subtotal">ค่าสินค้า (Subtotal)</option>
              <option value="delivery_fee">ค่าส่ง (Delivery Fee)</option>
            </select>
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">แหล่งทุนส่วนลด</label>
            <select id="promoFundingSource" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50 transition-all">
              <option value="platform">แพลตฟอร์ม</option>
              <option value="merchant">ร้านค้า</option>
              <option value="driver">คนขับ</option>
              <option value="split">แบ่งสัดส่วน</option>
            </select>
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">กลุ่มซ้อนคูปอง (Stacking Group)</label>
            <input id="promoStackingGroup" type="text" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50 transition-all" placeholder="เช่น NEW_USER, FOOD_ONLY">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">จำนวนสิทธิ์การกดรับทั้งหมด</label>
            <input id="promoClaimLimit" type="number" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50 transition-all" placeholder="เว้นว่าง = ไม่จำกัด" min="0">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">จำกัดการกดรับ/คน</label>
            <input id="promoClaimLimitPerUser" type="number" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50 transition-all" value="1" min="0">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">GP คูปองส่งฟรีรวม (ส่วนร้าน)</label>
            <input id="promoGpChargeRate" type="number" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50 transition-all" value="0.25" min="0" step="0.01">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">GP เข้าระบบ (จากส่วนร้าน)</label>
            <input id="promoGpSystemRate" type="number" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50 transition-all" value="0.10" min="0" step="0.01">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">GP ให้คนขับ (จากส่วนร้าน)</label>
            <input id="promoGpDriverRate" type="number" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50 transition-all" value="0.15" min="0" step="0.01">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">จำนวนสิทธิ์ทั้งหมด</label>
            <input id="promoUsageLimit" type="number" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50 transition-all" placeholder="0 = ไม่จำกัด" min="0">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">จำกัด/คน</label>
            <input id="promoPerUser" type="number" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50 transition-all" value="1" min="0">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">เริ่มใช้ได้ <span class="text-rose-400">*</span></label>
            <input id="promoStart" type="datetime-local" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50 transition-all">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">หมดอายุ <span class="text-rose-400">*</span></label>
            <input id="promoEnd" type="datetime-local" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50 transition-all">
          </div>
        </div>
        <button onclick="createPromoCode()" class="mt-5 px-6 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200 flex items-center gap-2" style="background:linear-gradient(135deg,#6366f1,#818cf8);">
          <span class="material-icons-round text-sm">add</span> สร้างโค้ดส่วนลด
        </button>
      </div>

      <div class="glass-card p-6">
        <div class="flex items-center justify-between mb-4">
          <div class="flex items-center gap-3">
            <div class="w-9 h-9 bg-violet-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-violet-500 text-lg">list</span></div>
            <h3 class="font-bold text-gray-800">รายการโค้ดส่วนลด</h3>
          </div>
          <div class="flex gap-2">
            <button onclick="setPromoFilter('all')" class="px-3 py-1.5 rounded-xl text-xs font-semibold transition-colors ${_promoFilter==='all'?'text-white shadow-md':'bg-gray-100 text-gray-600 hover:bg-gray-200'}" ${_promoFilter==='all'?'style=\"background:linear-gradient(135deg,#6366f1,#818cf8);\"':''}>ทั้งหมด</button>
            <button onclick="setPromoFilter('active')" class="px-3 py-1.5 rounded-xl text-xs font-semibold transition-colors ${_promoFilter==='active'?'text-white shadow-md':'bg-gray-100 text-gray-600 hover:bg-gray-200'}" ${_promoFilter==='active'?'style=\"background:linear-gradient(135deg,#10b981,#14b8a6);\"':''}>ใช้งานอยู่</button>
            <button onclick="setPromoFilter('expired')" class="px-3 py-1.5 rounded-xl text-xs font-semibold transition-colors ${_promoFilter==='expired'?'text-white shadow-md':'bg-gray-100 text-gray-600 hover:bg-gray-200'}" ${_promoFilter==='expired'?'style=\"background:linear-gradient(135deg,#f43f5e,#ec4899);\"':''}>หมดอายุ</button>
            <button onclick="setPromoFilter('inactive')" class="px-3 py-1.5 rounded-xl text-xs font-semibold transition-colors ${_promoFilter==='inactive'?'bg-gray-600 text-white':'bg-gray-100 text-gray-600 hover:bg-gray-200'}">ปิดอยู่</button>
          </div>
        </div>
        <div id="promoList" class="space-y-3">
          ${renderPromoList(all)}
        </div>
      </div>
    </div>
  `;

  const nowLocal = new Date();
  const startStr = new Date(nowLocal.getTime() - nowLocal.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
  const endDate = new Date(nowLocal);
  endDate.setMonth(endDate.getMonth() + 1);
  const endStr = new Date(endDate.getTime() - endDate.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
  document.getElementById('promoStart').value = startStr;
  document.getElementById('promoEnd').value = endStr;

  globalThis._allPromos = all;
}

function _filteredPromos() {
  const all = globalThis._allPromos || [];
  const now = new Date().toISOString();
  if (_promoFilter === 'active') return all.filter(c => c.is_active && c.end_date > now && c.start_date <= now);
  if (_promoFilter === 'expired') return all.filter(c => c.end_date <= now);
  if (_promoFilter === 'inactive') return all.filter(c => !c.is_active);
  return all;
}

export function exportPromosCsv() {
  const { exportRowsToCsv, reportFilename, fmtDate } = _deps();
  const rows = _filteredPromos().map((c) => ({
    โค้ด: c.code || '-',
    ชื่อโปรโมชั่น: c.name || '-',
    ประเภทส่วนลด: c.discount_type || '-',
    มูลค่าส่วนลด: c.discount_value ?? 0,
    บริการ: c.service_type || 'all',
    สถานะ: c.is_active ? 'active' : 'inactive',
    เริ่มใช้: fmtDate(c.start_date),
    หมดอายุ: fmtDate(c.end_date),
  }));
  exportRowsToCsv(reportFilename('promos_report', 'csv', _promoFilter, ''), ['โค้ด', 'ชื่อโปรโมชั่น', 'ประเภทส่วนลด', 'มูลค่าส่วนลด', 'บริการ', 'สถานะ', 'เริ่มใช้', 'หมดอายุ'], rows);
}

export function exportPromosExcel() {
  const { exportRowsToExcel, reportFilename, fmtDate } = _deps();
  const rows = _filteredPromos().map((c) => ({
    โค้ด: c.code || '-',
    ชื่อโปรโมชั่น: c.name || '-',
    ประเภทส่วนลด: c.discount_type || '-',
    มูลค่าส่วนลด: c.discount_value ?? 0,
    บริการ: c.service_type || 'all',
    สถานะ: c.is_active ? 'active' : 'inactive',
    เริ่มใช้: fmtDate(c.start_date),
    หมดอายุ: fmtDate(c.end_date),
  }));
  exportRowsToExcel(reportFilename('promos_report', 'xls', _promoFilter, ''), ['โค้ด', 'ชื่อโปรโมชั่น', 'ประเภทส่วนลด', 'มูลค่าส่วนลด', 'บริการ', 'สถานะ', 'เริ่มใช้', 'หมดอายุ'], rows);
}

export function setPromoFilter(f) {
  _promoFilter = f;
  const { refreshCurrentPage } = _deps();
  refreshCurrentPage();
}

export function onPromoTypeChange() {
  const type = document.getElementById('promoType').value;
  const valWrap = document.getElementById('promoValueWrap');
  const maxWrap = document.getElementById('promoMaxDiscWrap');
  if (type === 'free_delivery') {
    valWrap.style.display = 'none';
    maxWrap.style.display = 'none';
  } else {
    valWrap.style.display = '';
    maxWrap.style.display = type === 'percentage' ? '' : 'none';
  }
}

export async function createPromoCode() {
  const {
    callAdminAction,
    showToast,
    refreshCurrentPage,
  } = _deps();

  const code = document.getElementById('promoCode').value.trim().toUpperCase();
  const name = document.getElementById('promoName').value.trim();
  const description = document.getElementById('promoDesc').value.trim() || null;
  const discountType = document.getElementById('promoType').value;
  const discountValue = parseFloat(document.getElementById('promoValue').value) || 0;
  const maxDisc = parseFloat(document.getElementById('promoMaxDisc').value) || null;
  const minOrder = parseFloat(document.getElementById('promoMinOrder').value) || null;
  const serviceType = document.getElementById('promoService').value || null;
  const merchantId = document.getElementById('promoMerchant').value || null;
  const distributionType = document.getElementById('promoDistributionType')?.value || 'code_only';
  const discountBase = document.getElementById('promoDiscountBase')?.value || 'subtotal';
  const fundingSource = document.getElementById('promoFundingSource')?.value || 'platform';
  const stackingGroup = document.getElementById('promoStackingGroup')?.value.trim() || null;
  const claimLimitRaw = document.getElementById('promoClaimLimit')?.value;
  const claimLimit = claimLimitRaw === '' || claimLimitRaw == null ? null : (parseInt(claimLimitRaw) || 0);
  const claimLimitPerUser = parseInt(document.getElementById('promoClaimLimitPerUser')?.value) || 1;
  const gpChargeRate = parseFloat(document.getElementById('promoGpChargeRate').value) || 0.25;
  const gpSystemRate = parseFloat(document.getElementById('promoGpSystemRate').value) || 0.10;
  const gpDriverRate = parseFloat(document.getElementById('promoGpDriverRate').value) || 0.15;
  const usageLimit = parseInt(document.getElementById('promoUsageLimit').value) || 0;
  const perUserLimit = parseInt(document.getElementById('promoPerUser').value) || 1;
  const startDate = document.getElementById('promoStart').value;
  const endDate = document.getElementById('promoEnd').value;

  if (!code) return alert('กรุณากรอกโค้ด');
  if (!name) return alert('กรุณากรอกชื่อโปรโมชั่น');
  if (discountType !== 'free_delivery' && discountValue <= 0) return alert('กรุณากรอกมูลค่าส่วนลด');
  if (!startDate || !endDate) return alert('กรุณากรอกวันเริ่ม/หมดอายุ');
  if (new Date(endDate) <= new Date(startDate)) return alert('วันหมดอายุต้องมากกว่าวันเริ่ม');

  try {
    const insertData = {
      code,
      name,
      description,
      discount_type: discountType,
      discount_value: discountType === 'free_delivery' ? 0 : discountValue,
      max_discount_amount: discountType === 'percentage' ? maxDisc : null,
      discount_base: discountBase,
      distribution_type: distributionType,
      claim_limit: claimLimit,
      claim_limit_per_user: claimLimitPerUser,
      stacking_group: stackingGroup,
      funding_source: fundingSource,
      min_order_amount: minOrder,
      service_type: merchantId ? 'food' : serviceType,
      merchant_id: merchantId,
      created_by_role: merchantId ? 'merchant' : 'admin',
      merchant_gp_charge_rate: discountType === 'free_delivery' ? gpChargeRate : 0,
      merchant_gp_system_rate: discountType === 'free_delivery' ? gpSystemRate : 0,
      merchant_gp_driver_rate: discountType === 'free_delivery' ? gpDriverRate : 0,
      usage_limit: usageLimit,
      per_user_limit: perUserLimit,
      start_date: new Date(startDate).toISOString(),
      end_date: new Date(endDate).toISOString(),
      is_active: true,
      used_count: 0,
    };

    await callAdminAction({ action: 'create_coupon', coupon_data: insertData });

    showToast('สร้างโค้ดส่วนลดสำเร็จ!', 'success');
    refreshCurrentPage();
  } catch (e) {
    if (e.message && (e.message.includes('duplicate') || e.message.includes('unique'))) {
      return alert('โค้ดนี้มีอยู่แล้ว กรุณาใช้โค้ดอื่น');
    }
    alert('เกิดข้อผิดพลาด: ' + e.message);
  }
}

export async function togglePromoActive(id, newState) {
  const { callAdminAction, showToast, refreshCurrentPage, escapeHtml } = _deps();
  try {
    await callAdminAction({ action: 'toggle_coupon', id, is_active: newState });
    showToast(newState ? 'เปิดใช้งานโค้ดแล้ว' : 'ปิดใช้งานโค้ดแล้ว', 'success');
    refreshCurrentPage();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message || JSON.stringify(e)), 'error');
  }
}

export async function deletePromoCode(id, code) {
  const { callAdminAction, showToast, refreshCurrentPage, escapeHtml } = _deps();
  if (!confirm(`ลบโค้ด "${escapeHtml(code)}" ?\nการลบจะไม่สามารถกู้คืนได้`)) return;
  try {
    await callAdminAction({ action: 'delete_coupon', id });
    showToast('ลบโค้ดสำเร็จ', 'success');
    refreshCurrentPage();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function editPromoCode(id) {
  const { supabase, escapeHtml } = _deps();
  const { data: c } = await supabase.from('coupons').select('*').eq('id', id).single();
  if (!c) return;

  const merchantOptions = ['<option value="">คูปองส่วนกลาง</option>']
    .concat(_promoMerchants.map(m => `<option value="${m.id}" ${c.merchant_id===m.id?'selected':''}>${escapeHtml(m.full_name) || m.id}</option>`))
    .join('');

  const toLocal = (iso) => {
    const d = new Date(iso);
    return new Date(d.getTime() - d.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
  };

  const modal = document.createElement('div');
  modal.id = 'promoEditModal';
  modal.className = 'fixed inset-0 bg-black/50 z-50 flex items-center justify-center p-4';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-lg max-h-[90vh] overflow-y-auto p-6 fade-in">
      <h3 class="font-bold text-gray-800 text-lg mb-4 flex items-center gap-2">
        <span class="material-icons-round text-admin-500">edit</span> แก้ไขโค้ด: ${c.code}
      </h3>
      <div class="space-y-3">
        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">ชื่อโปรโมชั่น</label>
          <input id="editPromoName" type="text" value="${c.name}" class="w-full px-3 py-2 border rounded-lg text-sm">
        </div>
        <div>
          <label class="block text-xs font-medium text-gray-600 mb-1">คำอธิบาย</label>
          <input id="editPromoDesc" type="text" value="${escapeHtml(c.description)}" class="w-full px-3 py-2 border rounded-lg text-sm">
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">ประเภทส่วนลด</label>
            <select id="editPromoType" class="w-full px-3 py-2 border rounded-lg text-sm">
              <option value="percentage" ${c.discount_type==='percentage'?'selected':''}>ลดเปอร์เซ็นต์</option>
              <option value="fixed" ${c.discount_type==='fixed'?'selected':''}>ลดจำนวนเงิน</option>
              <option value="free_delivery" ${c.discount_type==='free_delivery'?'selected':''}>ส่งฟรี</option>
            </select>
          </div>
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">มูลค่าส่วนลด</label>
            <input id="editPromoValue" type="number" value="${c.discount_value||0}" class="w-full px-3 py-2 border rounded-lg text-sm" min="0">
          </div>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">ลดสูงสุด (฿)</label>
            <input id="editPromoMaxDisc" type="number" value="${c.max_discount_amount||''}" class="w-full px-3 py-2 border rounded-lg text-sm" min="0" placeholder="ไม่จำกัด">
          </div>
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">ยอดขั้นต่ำ (฿)</label>
            <input id="editPromoMinOrder" type="number" value="${c.min_order_amount||''}" class="w-full px-3 py-2 border rounded-lg text-sm" min="0" placeholder="ไม่กำหนด">
          </div>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">ใช้ได้กับบริการ</label>
            <select id="editPromoService" class="w-full px-3 py-2 border rounded-lg text-sm">
              <option value="" ${!c.service_type?'selected':''}>ทุกบริการ</option>
              <option value="food" ${c.service_type==='food'?'selected':''}>สั่งอาหาร</option>
              <option value="ride" ${c.service_type==='ride'?'selected':''}>เรียกรถ</option>
              <option value="parcel" ${c.service_type==='parcel'?'selected':''}>ส่งพัสดุ</option>
            </select>
          </div>
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">เจ้าของคูปอง</label>
            <select id="editPromoMerchant" class="w-full px-3 py-2 border rounded-lg text-sm">
              ${merchantOptions}
            </select>
          </div>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">รูปแบบการแจก</label>
            <select id="editPromoDistributionType" class="w-full px-3 py-2 border rounded-lg text-sm">
              <option value="code_only" ${(c.distribution_type||'code_only')==='code_only'?'selected':''}>ใช้โค้ด</option>
              <option value="claimable" ${(c.distribution_type||'code_only')==='claimable'?'selected':''}>กดรับเข้าวอลเล็ท</option>
              <option value="auto_grant" ${(c.distribution_type||'code_only')==='auto_grant'?'selected':''}>แจกอัตโนมัติ</option>
            </select>
          </div>
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">ฐานการคำนวณส่วนลด</label>
            <select id="editPromoDiscountBase" class="w-full px-3 py-2 border rounded-lg text-sm">
              <option value="subtotal" ${(c.discount_base||'subtotal')==='subtotal'?'selected':''}>ค่าสินค้า</option>
              <option value="delivery_fee" ${(c.discount_base||'subtotal')==='delivery_fee'?'selected':''}>ค่าส่ง</option>
            </select>
          </div>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">แหล่งทุนส่วนลด</label>
            <select id="editPromoFundingSource" class="w-full px-3 py-2 border rounded-lg text-sm">
              <option value="platform" ${(c.funding_source||'platform')==='platform'?'selected':''}>แพลตฟอร์ม</option>
              <option value="merchant" ${(c.funding_source||'platform')==='merchant'?'selected':''}>ร้านค้า</option>
              <option value="driver" ${(c.funding_source||'platform')==='driver'?'selected':''}>คนขับ</option>
              <option value="split" ${(c.funding_source||'platform')==='split'?'selected':''}>แบ่งสัดส่วน</option>
            </select>
          </div>
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">กลุ่มซ้อนคูปอง (Stacking Group)</label>
            <input id="editPromoStackingGroup" type="text" value="${escapeHtml(c.stacking_group||'')}" class="w-full px-3 py-2 border rounded-lg text-sm" placeholder="เช่น NEW_USER">
          </div>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">จำนวนสิทธิ์การกดรับทั้งหมด</label>
            <input id="editPromoClaimLimit" type="number" value="${c.claim_limit ?? ''}" class="w-full px-3 py-2 border rounded-lg text-sm" min="0" placeholder="เว้นว่าง = ไม่จำกัด">
          </div>
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">จำกัดการกดรับ/คน</label>
            <input id="editPromoClaimLimitPerUser" type="number" value="${c.claim_limit_per_user ?? 1}" class="w-full px-3 py-2 border rounded-lg text-sm" min="0">
          </div>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">จำกัด/คน</label>
            <input id="editPromoPerUser" type="number" value="${c.per_user_limit||0}" class="w-full px-3 py-2 border rounded-lg text-sm" min="0">
          </div>
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">ยอดกดรับสะสม</label>
            <input type="number" value="${c.current_claims ?? 0}" class="w-full px-3 py-2 border rounded-lg text-sm bg-gray-50" disabled>
          </div>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">จำนวนสิทธิ์ทั้งหมด</label>
            <input id="editPromoUsageLimit" type="number" value="${c.usage_limit||0}" class="w-full px-3 py-2 border rounded-lg text-sm" min="0" placeholder="0 = ไม่จำกัด">
          </div>
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">ใช้แล้ว</label>
            <input type="number" value="${c.used_count||0}" class="w-full px-3 py-2 border rounded-lg text-sm bg-gray-50" disabled>
          </div>
        </div>
        <div class="grid grid-cols-3 gap-3">
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">GP รวม (ส่วนร้าน)</label>
            <input id="editPromoGpChargeRate" type="number" value="${c.merchant_gp_charge_rate ?? 0.25}" class="w-full px-3 py-2 border rounded-lg text-sm" min="0" step="0.01">
          </div>
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">GP ระบบ</label>
            <input id="editPromoGpSystemRate" type="number" value="${c.merchant_gp_system_rate ?? 0.10}" class="w-full px-3 py-2 border rounded-lg text-sm" min="0" step="0.01">
          </div>
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">GP คนขับ</label>
            <input id="editPromoGpDriverRate" type="number" value="${c.merchant_gp_driver_rate ?? 0.15}" class="w-full px-3 py-2 border rounded-lg text-sm" min="0" step="0.01">
          </div>
        </div>
        <div class="grid grid-cols-2 gap-3">
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">เริ่มใช้ได้</label>
            <input id="editPromoStart" type="datetime-local" value="${toLocal(c.start_date)}" class="w-full px-3 py-2 border rounded-lg text-sm">
          </div>
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">หมดอายุ</label>
            <input id="editPromoEnd" type="datetime-local" value="${toLocal(c.end_date)}" class="w-full px-3 py-2 border rounded-lg text-sm">
          </div>
        </div>
      </div>
      <div class="flex gap-2 mt-5">
        <button onclick="submitEditPromo('${id}')" class="px-6 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">บันทึก</button>
        <button onclick="document.getElementById('promoEditModal')?.remove()" class="px-4 py-2.5 bg-gray-100 text-gray-600 rounded-lg text-sm font-medium hover:bg-gray-200">ยกเลิก</button>
      </div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });
}

export async function submitEditPromo(id) {
  const { callAdminAction, showToast, refreshCurrentPage, escapeHtml } = _deps();

  try {
    const discountType = document.getElementById('editPromoType').value;
    const merchantId = document.getElementById('editPromoMerchant').value || null;
    const claimLimitRaw = document.getElementById('editPromoClaimLimit')?.value;
    const claimLimit = claimLimitRaw === '' || claimLimitRaw == null ? null : (parseInt(claimLimitRaw) || 0);
    const updateData = {
      name: document.getElementById('editPromoName').value.trim(),
      description: document.getElementById('editPromoDesc').value.trim() || null,
      discount_type: discountType,
      discount_value: discountType === 'free_delivery' ? 0 : (parseFloat(document.getElementById('editPromoValue').value) || 0),
      max_discount_amount: discountType === 'percentage' ? (parseFloat(document.getElementById('editPromoMaxDisc').value) || null) : null,
      discount_base: document.getElementById('editPromoDiscountBase')?.value || 'subtotal',
      distribution_type: document.getElementById('editPromoDistributionType')?.value || 'code_only',
      funding_source: document.getElementById('editPromoFundingSource')?.value || 'platform',
      stacking_group: document.getElementById('editPromoStackingGroup')?.value.trim() || null,
      claim_limit: claimLimit,
      claim_limit_per_user: parseInt(document.getElementById('editPromoClaimLimitPerUser')?.value) || 1,
      min_order_amount: parseFloat(document.getElementById('editPromoMinOrder').value) || null,
      service_type: merchantId ? 'food' : (document.getElementById('editPromoService').value || null),
      merchant_id: merchantId,
      created_by_role: merchantId ? 'merchant' : 'admin',
      merchant_gp_charge_rate: discountType === 'free_delivery' ? (parseFloat(document.getElementById('editPromoGpChargeRate').value) || 0.25) : 0,
      merchant_gp_system_rate: discountType === 'free_delivery' ? (parseFloat(document.getElementById('editPromoGpSystemRate').value) || 0.10) : 0,
      merchant_gp_driver_rate: discountType === 'free_delivery' ? (parseFloat(document.getElementById('editPromoGpDriverRate').value) || 0.15) : 0,
      usage_limit: parseInt(document.getElementById('editPromoUsageLimit').value) || 0,
      per_user_limit: parseInt(document.getElementById('editPromoPerUser').value) || 0,
      start_date: new Date(document.getElementById('editPromoStart').value).toISOString(),
      end_date: new Date(document.getElementById('editPromoEnd').value).toISOString(),
    };

    if (!updateData.name) return alert('กรุณากรอกชื่อโปรโมชั่น');

    await callAdminAction({ action: 'update_coupon', id, update_data: updateData });

    document.getElementById('promoEditModal')?.remove();
    showToast('แก้ไขโค้ดสำเร็จ!', 'success');
    refreshCurrentPage();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export function renderPromoList(coupons) {
  const { fmtDate, escapeHtml } = _deps();

  const now = new Date().toISOString();
  let filtered = coupons;
  if (_promoFilter === 'active') filtered = coupons.filter(c => c.is_active && c.end_date > now && c.start_date <= now);
  else if (_promoFilter === 'expired') filtered = coupons.filter(c => c.end_date <= now);
  else if (_promoFilter === 'inactive') filtered = coupons.filter(c => !c.is_active);

  if (!filtered.length) return '<p class="text-gray-400 text-sm text-center py-6">ไม่มีรายการ</p>';

  return filtered.map(c => {
    const isExpired = c.end_date <= now;
    const isActive = c.is_active && !isExpired && c.start_date <= now;
    const statusBadge = isActive
      ? '<span class="px-2 py-0.5 bg-green-100 text-green-700 rounded-full text-xs font-medium">ใช้งานอยู่</span>'
      : isExpired
        ? '<span class="px-2 py-0.5 bg-red-100 text-red-600 rounded-full text-xs font-medium">หมดอายุ</span>'
        : !c.is_active
          ? '<span class="px-2 py-0.5 bg-gray-100 text-gray-500 rounded-full text-xs font-medium">ปิดใช้งาน</span>'
          : '<span class="px-2 py-0.5 bg-blue-100 text-blue-600 rounded-full text-xs font-medium">ยังไม่เริ่ม</span>';

    const typeLabel = c.discount_type === 'percentage' ? `ลด ${c.discount_value}%${c.max_discount_amount ? ' (สูงสุด ฿'+c.max_discount_amount+')' : ''}`
      : c.discount_type === 'fixed' ? `ลด ฿${c.discount_value}`
      : 'ส่งฟรี';
    const merchantName = c.merchant_id
      ? (_promoMerchants.find(m => m.id === c.merchant_id)?.full_name || c.merchant_id)
      : null;

    const serviceLabel = !c.service_type ? 'ทุกบริการ' : c.service_type === 'food' ? '🍔 อาหาร' : c.service_type === 'ride' ? '🚗 เรียกรถ' : '📦 พัสดุ';
    const usageText = c.usage_limit > 0 ? `${c.used_count}/${c.usage_limit}` : `${c.used_count} (ไม่จำกัด)`;

    return `
      <div class="p-4 rounded-xl border ${isActive ? 'border-green-200 bg-green-50/30' : isExpired ? 'border-red-100 bg-red-50/20' : 'border-gray-100 bg-gray-50/30'} flex flex-col md:flex-row md:items-center gap-3">
        <div class="flex-1 min-w-0">
          <div class="flex items-center gap-2 mb-1">
            <span class="font-mono font-bold text-sm bg-white px-2 py-0.5 rounded border">${c.code}</span>
            ${statusBadge}
            <span class="text-xs text-gray-400">${serviceLabel}</span>
          </div>
          <p class="text-sm font-medium text-gray-700 truncate">${c.name}</p>
          ${c.description ? `<p class="text-xs text-gray-400 truncate">${escapeHtml(c.description)}</p>` : ''}
          <div class="flex flex-wrap gap-3 mt-1 text-xs text-gray-500">
            <span>💰 ${typeLabel}</span>
            ${merchantName ? `<span>🏪 ร้าน: ${merchantName}</span>` : '<span>🌐 ส่วนกลาง</span>'}
            ${c.min_order_amount ? `<span>🛒 ขั้นต่ำ ฿${c.min_order_amount}</span>` : ''}
            <span>👥 ใช้แล้ว ${usageText}</span>
            <span>👤 ${c.per_user_limit > 0 ? c.per_user_limit+' ครั้ง/คน' : 'ไม่จำกัด/คน'}</span>
          </div>
          <div class="text-xs text-gray-400 mt-1">📅 ${fmtDate(c.start_date)} — ${fmtDate(c.end_date)}</div>
        </div>
        <div class="flex items-center gap-2 flex-shrink-0">
          <button onclick="togglePromoActive('${c.id}', ${!c.is_active})" class="px-3 py-1.5 rounded-lg text-xs font-medium ${c.is_active ? 'bg-orange-100 text-orange-600 hover:bg-orange-200' : 'bg-green-100 text-green-600 hover:bg-green-200'}">${c.is_active ? '⏸ ปิด' : '▶ เปิด'}</button>
          <button onclick="editPromoCode('${c.id}')" class="px-3 py-1.5 bg-blue-100 text-blue-600 rounded-lg text-xs font-medium hover:bg-blue-200">✏️ แก้ไข</button>
          <button onclick="deletePromoCode('${c.id}','${c.code}')" class="px-3 py-1.5 bg-red-100 text-red-600 rounded-lg text-xs font-medium hover:bg-red-200">🗑️ ลบ</button>
        </div>
      </div>`;
  }).join('');
}

export function wirePromosBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  globalThis.__adminWebBridge.renderPromosPage = renderPromosPage;
  globalThis.__adminWebBridge.exportPromosCsv = exportPromosCsv;
  globalThis.__adminWebBridge.exportPromosExcel = exportPromosExcel;
  globalThis.__adminWebBridge.setPromoFilter = setPromoFilter;
  globalThis.__adminWebBridge.onPromoTypeChange = onPromoTypeChange;
  globalThis.__adminWebBridge.createPromoCode = createPromoCode;
  globalThis.__adminWebBridge.togglePromoActive = togglePromoActive;
  globalThis.__adminWebBridge.deletePromoCode = deletePromoCode;
  globalThis.__adminWebBridge.editPromoCode = editPromoCode;
  globalThis.__adminWebBridge.submitEditPromo = submitEditPromo;
  globalThis.__adminWebBridge.renderPromoList = renderPromoList;
}
