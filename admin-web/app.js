// ============================================
// Jedechai Admin Web App
// ============================================

// --- Configuration ---
// Read from config.js or fallback
const SUPABASE_URL = window.JEDECHAI_CONFIG?.SUPABASE_URL || '';
const SUPABASE_ANON_KEY = window.JEDECHAI_CONFIG?.SUPABASE_ANON_KEY || '';
const SUPABASE_SERVICE_KEY = window.JEDECHAI_CONFIG?.SUPABASE_SERVICE_KEY || '';

let supabase = null;
let supabaseAdmin = null;
let supabaseAuth = null;
let currentUser = null;
let currentPage = 'dashboard';
const MOBILE_BREAKPOINT = 1280;

function isMobileViewport() {
  return window.innerWidth < MOBILE_BREAKPOINT;
}

function reportFilename(prefix, ext, from, to) {
  const clean = (v) => (v || '').toString().replace(/[^0-9a-zA-Z_-]/g, '') || 'all';
  return `${prefix}_${clean(from)}_${clean(to)}.${ext}`;
}

async function setUserOnlineStatus(id, isOnline, role = '') {
  try {
    const nowIso = new Date().toISOString();
    const { error } = await supabase
      .from('profiles')
      .update({ is_online: !!isOnline, updated_at: nowIso })
      .eq('id', id);
    if (error) throw error;

    if (role === 'driver') {
      const driverLocationPatch = {
        is_online: !!isOnline,
        updated_at: nowIso,
      };
      if (!isOnline) {
        driverLocationPatch.is_available = false;
      }

      const { error: locError } = await supabase
        .from('driver_locations')
        .update(driverLocationPatch)
        .eq('driver_id', id);
      if (locError) throw locError;
    }

    showToast(isOnline ? 'ตั้งสถานะออนไลน์แล้ว' : 'ตั้งสถานะออฟไลน์แล้ว', 'success');
    refreshCurrentPage();
  } catch (e) {
    showToast('อัปเดตสถานะออนไลน์ไม่สำเร็จ: ' + (e.message || JSON.stringify(e)), 'error');
  }
}

function setSidebarOpen(isOpen) {
  const sidebar = document.getElementById('appSidebar');
  const backdrop = document.getElementById('sidebarBackdrop');
  if (!sidebar || !backdrop) return;

  if (isOpen) {
    sidebar.classList.remove('-translate-x-full');
    backdrop.classList.remove('hidden');
    document.body.classList.add('overflow-hidden');
    return;
  }

  sidebar.classList.add('-translate-x-full');
  backdrop.classList.add('hidden');
  document.body.classList.remove('overflow-hidden');
}

function initializeResponsiveShell() {
  const menuToggleBtn = document.getElementById('menuToggleBtn');
  const backdrop = document.getElementById('sidebarBackdrop');

  if (menuToggleBtn && !menuToggleBtn.dataset.bound) {
    menuToggleBtn.addEventListener('click', () => setSidebarOpen(true));
    menuToggleBtn.dataset.bound = 'true';
  }

  if (backdrop && !backdrop.dataset.bound) {
    backdrop.addEventListener('click', () => setSidebarOpen(false));
    backdrop.dataset.bound = 'true';
  }

  if (!window._responsiveShellResizeBound) {
    window.addEventListener('resize', () => {
      if (!isMobileViewport()) {
        setSidebarOpen(false);
      }
    });
    window._responsiveShellResizeBound = true;
  }

  if (!isMobileViewport()) {
    setSidebarOpen(false);
  }
}

// Global button debounce - prevents double-click on all async buttons
window._btnProcessing = {};
function btnGuard(key, fn) {
  return async function(...args) {
    if (window._btnProcessing[key]) return;
    window._btnProcessing[key] = true;
    const btn = document.activeElement;
    if (btn?.tagName === 'BUTTON') { btn.disabled = true; btn.style.opacity = '0.6'; }
    try { await fn(...args); }
    finally {
      window._btnProcessing[key] = false;
      if (btn?.tagName === 'BUTTON') { btn.disabled = false; btn.style.opacity = '1'; }
    }
  };
}

// --- Initialize ---
function initSupabase() {
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    document.getElementById('loginError').textContent = 'กรุณาตั้งค่า Supabase ใน config.js';
    document.getElementById('loginError').classList.remove('hidden');
    return false;
  }
  if (!SUPABASE_SERVICE_KEY) {
    document.getElementById('loginError').textContent =
      'ไม่พบ SUPABASE_SERVICE_KEY: กรุณาตั้งค่าใน config.production.js (ไฟล์นี้ต้องไม่ commit)';
    document.getElementById('loginError').classList.remove('hidden');
    return false;
  }
  // Check if Supabase client is loaded
  if (typeof window.supabaseClient === 'undefined') {
    document.getElementById('loginError').textContent = 'Supabase library ไม่โหลดสำเร็จ';
    document.getElementById('loginError').classList.remove('hidden');
    return false;
  }
  // Use the imported createClient function
  try {
    const authClientOptions = {
      auth: {
        flowType: 'implicit',
        detectSessionInUrl: false,
      },
    };

    supabaseAuth = window.supabaseClient(
      SUPABASE_URL,
      SUPABASE_ANON_KEY,
      authClientOptions,
    );
    supabaseAdmin = window.supabaseClient(
      SUPABASE_URL,
      SUPABASE_SERVICE_KEY,
      authClientOptions,
    );
    // Use service role key for ALL data operations (bypasses RLS completely)
    supabase = supabaseAdmin;
    return true;
  } catch (e) {
    document.getElementById('loginError').textContent = 'เชื่อมต่อ Supabase ไม่สำเร็จ: ' + e.message;
    document.getElementById('loginError').classList.remove('hidden');
    return false;
  }
}

// --- Auth ---
document.getElementById('loginForm').addEventListener('submit', async (e) => {
  e.preventDefault();
  const email = document.getElementById('loginEmail').value;
  const password = document.getElementById('loginPassword').value;
  const errorEl = document.getElementById('loginError');
  const btn = document.getElementById('loginBtn');

  btn.disabled = true;
  btn.textContent = 'กำลังเข้าสู่ระบบ...';
  errorEl.classList.add('hidden');

  if (!initSupabase()) { btn.disabled = false; btn.textContent = 'เข้าสู่ระบบ'; return; }

  try {
    const { data, error } = await supabaseAuth.auth.signInWithPassword({ email, password });
    if (error) throw error;

    // Check admin role (use supabaseAdmin to bypass RLS)
    const { data: profile } = await supabaseAdmin.from('profiles').select('role, full_name').eq('id', data.user.id).single();
    if (profile?.role !== 'admin') {
      await supabaseAuth.auth.signOut();
      throw new Error('บัญชีนี้ไม่มีสิทธิ์ Admin');
    }

    currentUser = { ...data.user, profile };
    showMainApp();
  } catch (err) {
    errorEl.textContent = err.message || 'เข้าสู่ระบบไม่สำเร็จ';
    errorEl.classList.remove('hidden');
  } finally {
    btn.disabled = false;
    btn.textContent = 'เข้าสู่ระบบ';
  }
});

async function logout() {
  if (supabaseAuth) await supabaseAuth.auth.signOut();
  currentUser = null;
  setSidebarOpen(false);
  document.getElementById('mainApp').classList.add('hidden');
  document.getElementById('loginScreen').classList.remove('hidden');
}

function showMainApp() {
  initializeResponsiveShell();
  document.getElementById('loginScreen').classList.add('hidden');
  document.getElementById('mainApp').classList.remove('hidden');
  setSidebarOpen(false);
  const name = currentUser?.profile?.full_name || 'Admin';
  document.getElementById('adminName').textContent = name;
  const sidebarName = document.getElementById('sidebarAdminName');
  if (sidebarName) sidebarName.textContent = name;
  navigateTo('dashboard');
}

// --- Check existing session on load ---
window.addEventListener('DOMContentLoaded', async () => {
  initializeResponsiveShell();
  if (!initSupabase()) return;
  try {
    const { data: { session } } = await supabaseAuth.auth.getSession();
    if (session) {
      const { data: profile } = await supabaseAdmin.from('profiles').select('role, full_name').eq('id', session.user.id).single();
      if (profile?.role === 'admin') {
        currentUser = { ...session.user, profile };
        showMainApp();
      }
    }
  } catch (e) { /* ignore */ }
});

// --- Navigation ---
document.getElementById('sidebarNav').addEventListener('click', (e) => {
  const link = e.target.closest('[data-page]');
  if (!link) return;
  e.preventDefault();
  navigateTo(link.dataset.page);
  if (isMobileViewport()) {
    setSidebarOpen(false);
  }
});

function navigateTo(page) {
  currentPage = page;
  document.querySelectorAll('.sidebar-link').forEach(l => l.classList.remove('active'));
  document.querySelector(`[data-page="${page}"]`)?.classList.add('active');

  const titles = {
    dashboard: ['แดชบอร์ด','ภาพรวมระบบทั้งหมด'], orders: ['ออเดอร์ทั้งหมด','รายการสั่งซื้อทุกประเภท'], drivers: ['จัดการคนขับ','อนุมัติและจัดการคนขับ'],
    merchants: ['จัดการร้านค้า','อนุมัติและจัดการร้านค้า'], users: ['ผู้ใช้ทั้งหมด','ข้อมูลผู้ใช้งานในระบบ'], withdrawals: ['คำขอถอนเงิน','อนุมัติคำขอถอนเงิน'],
    revenue: ['รายได้','สรุปรายได้และยอดขาย'], menus: ['จัดการเมนูร้านค้า','เพิ่ม/แก้ไขเมนูอาหาร'], topups: ['คำขอเติมเงิน','อนุมัติคำขอเติมเงิน'],
    map: ['แผนที่ Realtime','ติดตามตำแหน่งคนขับแบบเรียลไทม์'], pending_orders: ['ออเดอร์รอจัดการ','ออเดอร์ที่ต้องการความช่วยเหลือจากแอดมิน'],
    complaints: ['ร้องเรียน','จัดการเรื่องร้องเรียน'], promos: ['โค้ดส่วนลด','จัดการโปรโมชั่น'],
    settings: ['ตั้งค่าระบบ','กำหนดค่าธรรมเนียมและตั้งค่าต่างๆ'], account_deletions: ['คำขอลบบัญชี','จัดการคำขอลบบัญชีผู้ใช้']
  };
  const [title, subtitle] = titles[page] || [page, ''];
  document.getElementById('pageTitle').textContent = title;
  const subtitleEl = document.getElementById('pageSubtitle');
  if (subtitleEl) subtitleEl.textContent = subtitle;
  loadPage(page);
}

function refreshCurrentPage() { loadPage(currentPage); }

async function loadPage(page) {
  const container = document.getElementById('pageContent');
  container.innerHTML = '<div class="flex justify-center py-20"><div class="loader"></div></div>';

  // Clean up map resources when leaving map page
  if (page !== 'map') {
    if (_mapRefreshTimer) { clearInterval(_mapRefreshTimer); _mapRefreshTimer = null; }
    if (_mapRealtimeChannel) { supabase.removeChannel(_mapRealtimeChannel); _mapRealtimeChannel = null; }
    if (_mapInstance) { _mapInstance.remove(); _mapInstance = null; }
    if (window._autoDispatchTickTimer) { clearInterval(window._autoDispatchTickTimer); window._autoDispatchTickTimer = null; }
    if (window._autoDispatchTimers) {
      Object.values(window._autoDispatchTimers).forEach(t => { try { clearTimeout(t); } catch(_) {} });
      window._autoDispatchTimers = {};
    }
    if (window._autoDispatchState) window._autoDispatchState = {};
  }
  // Clean up pending orders resources when leaving
  if (page !== 'pending_orders') {
    if (_pendingRefreshTimer) { clearInterval(_pendingRefreshTimer); _pendingRefreshTimer = null; }
    if (_pendingRealtimeChannel) { supabase.removeChannel(_pendingRealtimeChannel); _pendingRealtimeChannel = null; }
  }

  try {
    switch (page) {
      case 'dashboard': await renderDashboard(container); break;
      case 'orders': await renderOrders(container); break;
      case 'drivers': await renderDrivers(container); break;
      case 'merchants': await renderMerchants(container); break;
      case 'users': await renderUsers(container); break;
      case 'withdrawals': await renderWithdrawals(container); break;
      case 'revenue': await renderRevenue(container); break;
      case 'menus': await renderMenus(container); break;
      case 'topups': await renderTopups(container); break;
      case 'map': await renderMap(container); break;
      case 'pending_orders': await renderPendingOrders(container); break;
      case 'complaints': await renderComplaints(container); break;
      case 'promos': await renderPromos(container); break;
      case 'settings': await renderSettings(container); break;
      case 'account_deletions': await renderAccountDeletions(container); break;
    }
  } catch (e) {
    container.innerHTML = `<div class="text-center py-20 text-red-500"><span class="material-icons-round text-4xl">error</span><p class="mt-2">${e.message}</p></div>`;
  }
}

// --- Helpers ---
function fmt(n) { return new Intl.NumberFormat('th-TH').format(n || 0); }
function fmtDate(d) { return d ? new Date(d).toLocaleDateString('th-TH', { day:'numeric', month:'short', year:'numeric', hour:'2-digit', minute:'2-digit' }) : '-'; }

function _csvCell(value) {
  const v = value == null ? '' : String(value);
  return `"${v.replace(/"/g, '""')}"`;
}

function exportRowsToCsv(filename, headers, rows) {
  const csv = [
    headers.map(_csvCell).join(','),
    ...(rows || []).map((row) => headers.map((h) => _csvCell(row[h])).join(',')),
  ].join('\n');
  const blob = new Blob(['\uFEFF' + csv], { type: 'text/csv;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

function exportRowsToExcel(filename, headers, rows) {
  const headHtml = headers.map((h) => `<th style="border:1px solid #d1d5db;padding:8px;background:#f9fafb">${h}</th>`).join('');
  const bodyHtml = (rows || []).map((row) => {
    const cols = headers.map((h) => `<td style="border:1px solid #e5e7eb;padding:8px">${row[h] ?? ''}</td>`).join('');
    return `<tr>${cols}</tr>`;
  }).join('');
  const html = `
    <html xmlns:o="urn:schemas-microsoft-com:office:office" xmlns:x="urn:schemas-microsoft-com:office:excel" xmlns="http://www.w3.org/TR/REC-html40">
      <head><meta charset="UTF-8"></head>
      <body>
        <table>
          <thead><tr>${headHtml}</tr></thead>
          <tbody>${bodyHtml}</tbody>
        </table>
      </body>
    </html>`;
  const blob = new Blob([html], { type: 'application/vnd.ms-excel;charset=utf-8;' });
  const url = URL.createObjectURL(blob);
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  document.body.removeChild(a);
  URL.revokeObjectURL(url);
}

function renderMiniBarChart(title, subtitle, rows, colorHex = '#6366f1') {
  const safeRows = rows || [];
  const maxValue = Math.max(...safeRows.map((r) => Number(r.value || 0)), 1);
  return `
    <div class="glass-card p-5">
      <div class="mb-4">
        <h4 class="font-bold text-gray-800">${title}</h4>
        <p class="text-xs text-gray-400">${subtitle}</p>
      </div>
      <div class="space-y-2.5">
        ${safeRows.length === 0 ? '<p class="text-sm text-gray-400 py-3">ไม่มีข้อมูลในช่วงวันที่ที่เลือก</p>' : safeRows.map((r) => {
          const pct = Math.round((Number(r.value || 0) / maxValue) * 100);
          return `
            <div>
              <div class="flex items-center justify-between text-xs mb-1">
                <span class="text-gray-500">${r.label}</span>
                <span class="font-semibold text-gray-700">${r.displayValue || fmt(Math.round(r.value || 0))}</span>
              </div>
              <div class="h-2 bg-gray-100 rounded-full overflow-hidden">
                <div class="h-full rounded-full" style="width:${pct}%;background:${colorHex};"></div>
              </div>
            </div>`;
        }).join('')}
      </div>
    </div>`;
}

function statusBadge(status) {
  const map = {
    pending: ['รอดำเนินการ','bg-amber-50 text-amber-600 border border-amber-200'], pending_merchant: ['รอร้านค้า','bg-amber-50 text-amber-600 border border-amber-200'],
    preparing: ['กำลังเตรียม','bg-sky-50 text-sky-600 border border-sky-200'], driver_accepted: ['คนขับรับแล้ว','bg-sky-50 text-sky-600 border border-sky-200'],
    matched: ['จับคู่แล้ว','bg-indigo-50 text-indigo-600 border border-indigo-200'], arrived_at_merchant: ['ถึงร้านแล้ว','bg-violet-50 text-violet-600 border border-violet-200'],
    ready_for_pickup: ['พร้อมรับ','bg-teal-50 text-teal-600 border border-teal-200'], picking_up_order: ['กำลังรับ','bg-cyan-50 text-cyan-600 border border-cyan-200'],
    in_transit: ['กำลังส่ง','bg-orange-50 text-orange-600 border border-orange-200'], arrived: ['ถึงจุดรับ','bg-emerald-50 text-emerald-600 border border-emerald-200'],
    completed: ['เสร็จสิ้น','bg-emerald-50 text-emerald-600 border border-emerald-200'], cancelled: ['ยกเลิก','bg-rose-50 text-rose-600 border border-rose-200'],
    approved: ['อนุมัติ','bg-emerald-50 text-emerald-600 border border-emerald-200'], rejected: ['ปฏิเสธ','bg-rose-50 text-rose-600 border border-rose-200'],
    suspended: ['ระงับ','bg-gray-100 text-gray-600 border border-gray-200'],
  };
  const [label, cls] = map[status] || [status, 'bg-gray-100 text-gray-600'];
  return `<span class="inline-flex items-center px-2.5 py-0.5 rounded-lg text-xs font-semibold ${cls}">${label}</span>`;
}

function onlineBadge(isOnline) {
  return isOnline
    ? '<span class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-lg text-xs font-semibold bg-emerald-50 text-emerald-600 border border-emerald-200"><span class="w-1.5 h-1.5 rounded-full bg-emerald-500"></span>ออนไลน์</span>'
    : '<span class="inline-flex items-center gap-1 px-2.5 py-0.5 rounded-lg text-xs font-semibold bg-gray-100 text-gray-600 border border-gray-200"><span class="w-1.5 h-1.5 rounded-full bg-gray-400"></span>ออฟไลน์</span>';
}

async function uploadProfileImageField(userId, field, input, folderPrefix = 'profiles') {
  if (!input?.files?.length) return null;
  const file = input.files[0];
  const ext = (file.name.split('.').pop() || 'jpg').toLowerCase();
  const filePath = `${folderPrefix}/${userId}/${field}_${Date.now()}.${ext}`;
  const buckets = ['app-uploads', 'admin-uploads'];

  let lastError = null;
  for (const bucket of buckets) {
    const { error } = await supabase.storage
      .from(bucket)
      .upload(filePath, file, { cacheControl: '3600', upsert: true });

    if (error) {
      lastError = error;
      continue;
    }

    const { data: urlData } = supabase.storage.from(bucket).getPublicUrl(filePath);
    const publicUrl = urlData?.publicUrl;
    if (!publicUrl) throw new Error('ไม่สามารถสร้าง public URL ได้');

    const { error: updateErr } = await supabase
      .from('profiles')
      .update({ [field]: publicUrl, updated_at: new Date().toISOString() })
      .eq('id', userId);
    if (updateErr) throw updateErr;

    return publicUrl;
  }

  throw lastError || new Error('อัปโหลดรูปภาพไม่สำเร็จ');
}

const MAP_PENDING_NO_DRIVER_STATUSES = ['pending', 'matched', 'pending_merchant'];
const MAP_DISPATCHABLE_STATUSES = ['pending', 'matched'];
const ADMIN_MERCHANT_ACCEPT_STATUSES = ['pending_merchant', 'pending'];
const ADMIN_MERCHANT_READY_STATUSES = ['preparing', 'driver_accepted', 'arrived_at_merchant', 'matched', 'accepted', 'arrived'];

function _truthyFlag(value) {
  return value === true || value === 1 || value === '1' || value === 'true' || value === 't';
}

function _explicitlyFalseFlag(value) {
  return value === false || value === 0 || value === '0' || value === 'false' || value === 'f';
}

function _canAdminMerchantAccept(order) {
  return !!order && order.service_type === 'food' && ADMIN_MERCHANT_ACCEPT_STATUSES.includes(order.status);
}

function _canAdminMarkFoodReady(order) {
  return !!order && order.service_type === 'food' && ADMIN_MERCHANT_READY_STATUSES.includes(order.status);
}

// Email lookup cache
window._emailMap = {};
async function fetchUserEmails() {
  if (Object.keys(window._emailMap).length > 0) return window._emailMap;
  try {
    let allUsers = [];
    let page = 1;
    while (true) {
      const { data, error } = await supabase.auth.admin.listUsers({ page, perPage: 500 });
      if (error) break;
      if (!data?.users?.length) break;
      allUsers = allUsers.concat(data.users);
      if (data.users.length < 500) break;
      page++;
    }
    allUsers.forEach(u => { window._emailMap[u.id] = u.email || ''; });
  } catch(e) { console.error('fetchUserEmails error:', e); }
  return window._emailMap;
}

function serviceIcon(type) {
  const icons = {
    ride: '<span class="inline-flex items-center justify-center w-6 h-6 rounded-md bg-blue-100 text-blue-600"><span class="material-icons-round text-sm">directions_car</span></span>',
    food: '<span class="inline-flex items-center justify-center w-6 h-6 rounded-md bg-orange-100 text-orange-600"><span class="material-icons-round text-sm">restaurant</span></span>',
    parcel: '<span class="inline-flex items-center justify-center w-6 h-6 rounded-md bg-purple-100 text-purple-600"><span class="material-icons-round text-sm">inventory_2</span></span>',
  };
  return icons[type] || '<span class="inline-flex items-center justify-center w-6 h-6 rounded-md bg-gray-100 text-gray-600"><span class="material-icons-round text-sm">receipt</span></span>';
}

// ============================================
// Dashboard
// ============================================
async function renderDashboard(el) {
  const today = new Date(); today.setHours(0,0,0,0);
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

async function dashboardFilter() {
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
  window._dashboardRecentRows = recentRows;

  dc.innerHTML = `
      <!-- Stat Cards -->
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

      <!-- User Type Online Stats -->
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

      <!-- Pending Actions -->
      <div class="grid grid-cols-1 md:grid-cols-3 gap-5 mt-6">
        ${pendingCard('คนขับรอการอนุมัติ', pendingDrivers.count || 0, 'directions_car', 'blue', 'drivers')}
        ${pendingCard('ร้านค้ารอการอนุมัติ', pendingMerchants.count || 0, 'store', 'emerald', 'merchants')}
        ${pendingCard('คำขอถอนเงิน', pendingWithdrawals.count || 0, 'account_balance_wallet', 'orange', 'withdrawals')}
      </div>

      <!-- Recent Orders -->
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
    </div>
  `;
}

function exportWithdrawalsCsv() {
  const rows = window._allWithdrawals || [];
  exportRowsToCsv(reportFilename('withdrawals_report', 'csv', '', ''), ['ผู้ขอ', 'บทบาท', 'จำนวน', 'ธนาคาร', 'เลขบัญชี', 'สถานะ', 'วันที่'], rows);
}

function exportWithdrawalsExcel() {
  const rows = window._allWithdrawals || [];
  exportRowsToExcel(reportFilename('withdrawals_report', 'xls', '', ''), ['ผู้ขอ', 'บทบาท', 'จำนวน', 'ธนาคาร', 'เลขบัญชี', 'สถานะ', 'วันที่'], rows);
}

function exportDashboardCsv() {
  const from = document.getElementById('dashDateFrom')?.value || '';
  const to = document.getElementById('dashDateTo')?.value || '';
  const rows = window._dashboardRecentRows || [];
  exportRowsToCsv(
    reportFilename('dashboard_recent_orders', 'csv', from, to),
    ['เลขออเดอร์', 'ประเภท', 'ราคา', 'สถานะ', 'เวลา'],
    rows,
  );
}

function exportDashboardExcel() {
  const from = document.getElementById('dashDateFrom')?.value || '';
  const to = document.getElementById('dashDateTo')?.value || '';
  const rows = window._dashboardRecentRows || [];
  exportRowsToExcel(
    reportFilename('dashboard_recent_orders', 'xls', from, to),
    ['เลขออเดอร์', 'ประเภท', 'ราคา', 'สถานะ', 'เวลา'],
    rows,
  );
}

function statCard(icon, title, value, gradient) {
  const gradients = {
    'bg-blue-500': 'from-blue-500 to-cyan-400',
    'bg-green-500': 'from-emerald-500 to-teal-400',
    'bg-emerald-500': 'from-emerald-500 to-green-400',
    'bg-orange-500': 'from-orange-500 to-amber-400',
    'bg-purple-500': 'from-violet-500 to-purple-400',
    'bg-cyan-500': 'from-cyan-500 to-sky-400',
    'bg-rose-500': 'from-rose-500 to-pink-400',
    'bg-pink-500': 'from-pink-500 to-rose-400',
    'bg-indigo-500': 'from-indigo-500 to-blue-400',
    'bg-amber-500': 'from-amber-500 to-yellow-400',
    'bg-red-500': 'from-red-500 to-rose-400',
  };
  const grad = gradients[gradient] || 'from-indigo-500 to-purple-400';
  return `
    <div class="stat-card rounded-2xl p-5 text-white shadow-lg" style="background: linear-gradient(135deg, var(--tw-gradient-from), var(--tw-gradient-to));">
      <div class="bg-gradient-to-br ${grad} rounded-2xl p-5">
        <div class="flex items-center justify-between">
          <div>
            <p class="text-white/70 text-xs font-semibold uppercase tracking-wider">${title}</p>
            <p class="text-3xl font-extrabold mt-2">${value}</p>
          </div>
          <div class="w-14 h-14 bg-white/20 backdrop-blur rounded-2xl flex items-center justify-center">
            <span class="material-icons-round text-white text-2xl">${icon}</span>
          </div>
        </div>
      </div>
    </div>
  `;
}

function pendingCard(title, count, icon, color, page) {
  return `
    <div class="glass-card p-5 cursor-pointer group" onclick="navigateTo('${page}')">
      <div class="flex items-center gap-4">
        <div class="w-12 h-12 bg-${color}-50 rounded-2xl flex items-center justify-center group-hover:scale-110 transition-transform">
          <span class="material-icons-round text-${color}-500 text-xl">${icon}</span>
        </div>
        <div class="flex-1">
          <p class="text-xs font-semibold text-gray-400 uppercase tracking-wider">${title}</p>
          <p class="text-2xl font-extrabold text-gray-800 mt-0.5">${count}</p>
        </div>
        ${count > 0 ? `<span class="w-3 h-3 bg-rose-500 rounded-full pulse-dot"></span>` : '<span class="material-icons-round text-gray-300 text-lg">check_circle</span>'}
      </div>
    </div>
  `;
}

// ============================================
// Orders Page
// ============================================
async function renderOrders(el) {
  const today = new Date();
  const weekAgo = new Date(today); weekAgo.setDate(weekAgo.getDate() - 7);

  el.innerHTML = `
    <div class="fade-in space-y-5">
      <div class="glass-card p-4 flex flex-wrap gap-3 items-center">
        <span class="material-icons-round text-indigo-400 text-lg">filter_list</span>
        <input type="date" id="ordDateFrom" value="${weekAgo.toISOString().split('T')[0]}" class="border border-gray-200 rounded-xl px-3.5 py-2 text-sm bg-gray-50/50 transition-all" />
        <span class="text-gray-300 text-sm font-medium">ถึง</span>
        <input type="date" id="ordDateTo" value="${today.toISOString().split('T')[0]}" class="border border-gray-200 rounded-xl px-3.5 py-2 text-sm bg-gray-50/50 transition-all" />
        <select id="orderStatusFilter" onchange="filterOrders()" class="text-sm border border-gray-200 rounded-xl px-3.5 py-2 bg-gray-50/50 transition-all">
          <option value="">ทุกสถานะ</option>
          <option value="pending">รอดำเนินการ</option><option value="preparing">กำลังเตรียม</option>
          <option value="in_transit">กำลังส่ง</option><option value="completed">เสร็จสิ้น</option>
          <option value="cancelled">ยกเลิก</option>
        </select>
        <select id="orderTypeFilter" onchange="filterOrders()" class="text-sm border border-gray-200 rounded-xl px-3.5 py-2 bg-gray-50/50 transition-all">
          <option value="">ทุกประเภท</option>
          <option value="food">อาหาร</option><option value="ride">เรียกรถ</option><option value="parcel">พัสดุ</option>
        </select>
        <button onclick="loadOrders()" class="text-white px-5 py-2 rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">กรอง</button>
        <button onclick="exportOrdersCsv()" class="px-4 py-2 rounded-xl text-sm font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100 transition-colors">Export CSV</button>
        <button onclick="exportOrdersExcel()" class="px-4 py-2 rounded-xl text-sm font-semibold bg-cyan-50 text-cyan-700 border border-cyan-200 hover:bg-cyan-100 transition-colors">Export Excel</button>
      </div>
      <div id="ordersContainer"><div class="flex justify-center py-10"><div class="loader"></div></div></div>
    </div>`;
  await loadOrders();
}

async function loadOrders() {
  const from = document.getElementById('ordDateFrom')?.value;
  const to = document.getElementById('ordDateTo')?.value;
  const startDate = from ? new Date(from + 'T00:00:00').toISOString() : new Date(new Date().setDate(new Date().getDate()-7)).toISOString();
  const endDate = to ? new Date(to + 'T23:59:59').toISOString() : new Date().toISOString();

  const oc = document.getElementById('ordersContainer');
  if (!oc) return;
  oc.innerHTML = '<div class="flex justify-center py-10"><div class="loader"></div></div>';

  const { data: orders } = await supabase.from('bookings').select('*').gte('created_at', startDate).lte('created_at', endDate).order('created_at', { ascending: false }).limit(500);
  window._allOrders = orders || [];
  window._filteredOrders = orders || [];

  const statusCounts = {};
  const typeCounts = {};
  (orders || []).forEach((o) => {
    statusCounts[o.status || '-'] = (statusCounts[o.status || '-'] || 0) + 1;
    typeCounts[o.service_type || '-'] = (typeCounts[o.service_type || '-'] || 0) + 1;
  });
  const statusChartRows = Object.keys(statusCounts).map((k) => ({ label: k, value: statusCounts[k], displayValue: fmt(statusCounts[k]) }));
  const typeChartRows = Object.keys(typeCounts).map((k) => ({ label: k, value: typeCounts[k], displayValue: fmt(typeCounts[k]) }));

  // Fetch driver names for orders
  const driverIds = [...new Set((orders||[]).map(o => o.driver_id).filter(Boolean))];
  window._orderDriverMap = {};
  if (driverIds.length) {
    const { data: dProfiles } = await supabase.from('profiles').select('id, full_name').in('id', driverIds);
    (dProfiles||[]).forEach(p => { window._orderDriverMap[p.id] = p.full_name || p.id.substring(0,8); });
  }

  oc.innerHTML = `
      <div class="grid grid-cols-1 lg:grid-cols-2 gap-5 mb-5">
        ${renderMiniBarChart('สรุปออเดอร์ตามสถานะ', `${from || '-'} ถึง ${to || '-'}`, statusChartRows, '#f97316')}
        ${renderMiniBarChart('สรุปออเดอร์ตามประเภท', `${from || '-'} ถึง ${to || '-'}`, typeChartRows, '#06b6d4')}
      </div>
      <div class="glass-card overflow-hidden">
        <div class="px-6 py-4 flex items-center gap-3">
          <div class="w-8 h-8 bg-indigo-50 rounded-lg flex items-center justify-center"><span class="material-icons-round text-indigo-500 text-sm">receipt_long</span></div>
          <span class="font-bold text-gray-800">ผลลัพธ์: ${(orders||[]).length} รายการ</span>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead><tr class="bg-gray-50/80">
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ID</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ประเภท</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">คนขับ</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">จุดรับ</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">จุดส่ง</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ราคา</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">สถานะ</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">วันที่</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">จัดการ</th>
            </tr></thead>
            <tbody id="ordersTableBody" class="divide-y divide-gray-100">
              ${renderOrderRows(orders || [])}
            </tbody>
          </table>
        </div>
      </div>`;
  filterOrders();
}

function renderOrderRows(orders) {
  if (!orders.length) return '<tr><td colspan="9" class="px-4 py-8 text-center text-gray-400">ไม่มีข้อมูล</td></tr>';
  return orders.map(o => {
    const dName = window._orderDriverMap?.[o.driver_id] || (o.driver_id ? o.driver_id.substring(0,8) : '-');
    const canReassign = ['pending','preparing','driver_accepted','matched','pending_merchant','arrived_at_merchant','ready_for_pickup'].includes(o.status);
    const canRebroadcast = ['pending','pending_merchant','driver_accepted','matched','preparing','arrived_at_merchant','ready_for_pickup'].includes(o.status);
    const canAdminMerchantAccept = _canAdminMerchantAccept(o);
    const canAdminMarkReady = _canAdminMarkFoodReady(o);
    let actions = '';
    if (canReassign || canRebroadcast || canAdminMerchantAccept || canAdminMarkReady) {
      if (canRebroadcast) actions += `<button onclick="rebroadcastOrder('${o.id}','${o.service_type}')" class="px-2 py-1 bg-purple-100 text-purple-700 rounded-lg text-xs font-medium hover:bg-purple-200 mr-1" title="โยนออเดอร์ใหม่ให้คนขับทุกคนเห็น">🔄 โยนใหม่</button>`;
      if (canReassign) actions += `<button onclick="showReassignModal('${o.id}','${(dName).replace(/'/g,'')}')" class="px-2 py-1 bg-orange-100 text-orange-700 rounded-lg text-xs font-medium hover:bg-orange-200 mr-1">ย้ายคนขับ</button>`;
      if (canAdminMerchantAccept) actions += `<button onclick="adminMerchantAcceptOrder('${o.id}')" class="px-2 py-1 bg-emerald-100 text-emerald-700 rounded-lg text-xs font-medium hover:bg-emerald-200 mr-1">รับแทนร้าน</button>`;
      if (canAdminMarkReady) actions += `<button onclick="adminMarkFoodReady('${o.id}')" class="px-2 py-1 bg-teal-100 text-teal-700 rounded-lg text-xs font-medium hover:bg-teal-200 mr-1">อาหารพร้อม</button>`;
      if (o.status !== 'completed' && o.status !== 'cancelled') {
        actions += `<button onclick="forceCancelOrder('${o.id}','${o.customer_id||''}',${Math.round(o.price||0)})" class="px-2 py-1 bg-red-100 text-red-700 rounded-lg text-xs font-medium hover:bg-red-200">ยกเลิก</button>`;
      }
    } else if (o.status !== 'completed' && o.status !== 'cancelled') {
      actions = `<button onclick="forceCancelOrder('${o.id}','${o.customer_id||''}',${Math.round(o.price||0)})" class="px-2 py-1 bg-red-100 text-red-700 rounded-lg text-xs font-medium hover:bg-red-200">ยกเลิก</button>`;
    } else {
      actions = '<span class="text-gray-300 text-xs">-</span>';
    }
    return `
    <tr class="table-row border-b border-gray-50">
      <td class="px-4 py-3 font-mono text-xs text-gray-500">#${o.id.substring(0,8)}</td>
      <td class="px-4 py-3">${serviceIcon(o.service_type)} ${o.service_type}</td>
      <td class="px-4 py-3 text-xs">${dName}</td>
      <td class="px-4 py-3 text-gray-600 max-w-[120px] truncate">${o.pickup_address || '-'}</td>
      <td class="px-4 py-3 text-gray-600 max-w-[120px] truncate">${o.destination_address || '-'}</td>
      <td class="px-4 py-3 font-semibold">฿${fmt(Math.round(o.price))}</td>
      <td class="px-4 py-3">${statusBadge(o.status)}</td>
      <td class="px-4 py-3 text-gray-500 text-xs">${fmtDate(o.created_at)}</td>
      <td class="px-4 py-3 whitespace-nowrap">${actions}</td>
    </tr>`;
  }).join('');
}

function filterOrders() {
  const status = document.getElementById('orderStatusFilter').value;
  const type = document.getElementById('orderTypeFilter').value;
  let filtered = window._allOrders || [];
  if (status) filtered = filtered.filter(o => o.status === status);
  if (type) filtered = filtered.filter(o => o.service_type === type);
  window._filteredOrders = filtered;
  document.getElementById('ordersTableBody').innerHTML = renderOrderRows(filtered);
}

function exportOrdersCsv() {
  const from = document.getElementById('ordDateFrom')?.value || '';
  const to = document.getElementById('ordDateTo')?.value || '';
  const rows = (window._filteredOrders || window._allOrders || []).map((o) => ({
    เลขออเดอร์: `#${(o.id || '').substring(0, 8)}`,
    ประเภท: o.service_type || '-',
    คนขับ: window._orderDriverMap?.[o.driver_id] || (o.driver_id ? o.driver_id.substring(0, 8) : '-'),
    จุดรับ: o.pickup_address || '-',
    จุดส่ง: o.destination_address || '-',
    ราคา: Math.round(o.price || 0),
    สถานะ: o.status || '-',
    วันที่: fmtDate(o.created_at),
  }));
  exportRowsToCsv(reportFilename('orders_report', 'csv', from, to), ['เลขออเดอร์', 'ประเภท', 'คนขับ', 'จุดรับ', 'จุดส่ง', 'ราคา', 'สถานะ', 'วันที่'], rows);
}

function exportOrdersExcel() {
  const from = document.getElementById('ordDateFrom')?.value || '';
  const to = document.getElementById('ordDateTo')?.value || '';
  const rows = (window._filteredOrders || window._allOrders || []).map((o) => ({
    เลขออเดอร์: `#${(o.id || '').substring(0, 8)}`,
    ประเภท: o.service_type || '-',
    คนขับ: window._orderDriverMap?.[o.driver_id] || (o.driver_id ? o.driver_id.substring(0, 8) : '-'),
    จุดรับ: o.pickup_address || '-',
    จุดส่ง: o.destination_address || '-',
    ราคา: Math.round(o.price || 0),
    สถานะ: o.status || '-',
    วันที่: fmtDate(o.created_at),
  }));
  exportRowsToExcel(reportFilename('orders_report', 'xls', from, to), ['เลขออเดอร์', 'ประเภท', 'คนขับ', 'จุดรับ', 'จุดส่ง', 'ราคา', 'สถานะ', 'วันที่'], rows);
}

// ============================================
// Drivers Page
// ============================================
async function renderDrivers(el) {
  const [{ data: drivers }, emailMap] = await Promise.all([
    supabase.from('profiles').select('*').eq('role', 'driver').order('created_at', { ascending: false }),
    fetchUserEmails()
  ]);
  const statusRows = [
    { label: 'รออนุมัติ', value: (drivers || []).filter(d => d.approval_status === 'pending').length },
    { label: 'อนุมัติแล้ว', value: (drivers || []).filter(d => d.approval_status === 'approved').length },
    { label: 'ระงับ/ปฏิเสธ', value: (drivers || []).filter(d => d.approval_status === 'suspended' || d.approval_status === 'rejected').length },
  ];
  const onlineRows = [
    { label: 'ออนไลน์', value: (drivers || []).filter(d => _truthyFlag(d.is_online)).length },
    { label: 'ออฟไลน์', value: (drivers || []).filter(d => !_truthyFlag(d.is_online)).length },
  ];

  el.innerHTML = `
    <div class="fade-in space-y-5">
      <div class="glass-card p-4 flex gap-2 flex-wrap items-center">
        <button onclick="filterDriversByStatus('')" class="px-4 py-2 bg-white border border-gray-200 rounded-xl text-sm font-semibold hover:bg-gray-50 transition-colors">ทั้งหมด (${(drivers||[]).length})</button>
        <button onclick="filterDriversByStatus('pending')" class="px-4 py-2 bg-amber-50 border border-amber-200 rounded-xl text-sm font-semibold text-amber-600 hover:bg-amber-100 transition-colors">รออนุมัติ (${(drivers||[]).filter(d=>d.approval_status==='pending').length})</button>
        <button onclick="filterDriversByStatus('approved')" class="px-4 py-2 bg-emerald-50 border border-emerald-200 rounded-xl text-sm font-semibold text-emerald-600 hover:bg-emerald-100 transition-colors">อนุมัติแล้ว (${(drivers||[]).filter(d=>d.approval_status==='approved').length})</button>
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
  window._allDrivers = drivers || [];
  window._filteredDrivers = drivers || [];
  window._driverStatusFilter = '';
}

function renderDriverRows(drivers) {
  if (!drivers.length) return '<tr><td colspan="8" class="px-4 py-8 text-center text-gray-400">ไม่มีข้อมูล</td></tr>';
  return drivers.map(d => `
    <tr class="table-row border-b border-gray-50">
      <td class="px-4 py-3 font-medium">${d.full_name || '-'}</td>
      <td class="px-4 py-3 text-xs text-gray-500">${window._emailMap[d.id] || '-'}</td>
      <td class="px-4 py-3">${d.phone_number || '-'}</td>
      <td class="px-4 py-3">${d.license_plate || '-'}</td>
      <td class="px-4 py-3">${statusBadge(d.approval_status || 'pending')}</td>
      <td class="px-4 py-3">${onlineBadge(_truthyFlag(d.is_online))}</td>
      <td class="px-4 py-3 text-gray-500 text-xs">${fmtDate(d.created_at)}</td>
      <td class="px-4 py-3 whitespace-nowrap">
        <button onclick="setUserOnlineStatus('${d.id}', ${_truthyFlag(d.is_online) ? 'false' : 'true'}, 'driver')" class="px-3 py-1 ${_truthyFlag(d.is_online) ? 'bg-orange-100 text-orange-700 hover:bg-orange-200' : 'bg-emerald-100 text-emerald-700 hover:bg-emerald-200'} rounded-lg text-xs font-medium mr-1">${_truthyFlag(d.is_online) ? 'ตั้งออฟไลน์' : 'ตั้งออนไลน์'}</button>
        ${d.approval_status === 'pending' ? `
          <button onclick="approveDriver('${d.id}')" class="px-3 py-1 bg-green-500 text-white rounded-lg text-xs font-medium hover:bg-green-600 mr-1">อนุมัติ</button>
          <button onclick="rejectDriver('${d.id}')" class="px-3 py-1 bg-red-500 text-white rounded-lg text-xs font-medium hover:bg-red-600 mr-1">ปฏิเสธ</button>
        ` : d.approval_status === 'approved' ? `
          <button onclick="suspendUser('${d.id}')" class="px-3 py-1 bg-gray-500 text-white rounded-lg text-xs font-medium hover:bg-gray-600 mr-1">ระงับ</button>
        ` : d.approval_status === 'suspended' || d.approval_status === 'rejected' ? `
          <button onclick="approveDriver('${d.id}')" class="px-3 py-1 bg-green-500 text-white rounded-lg text-xs font-medium hover:bg-green-600 mr-1">อนุมัติ</button>
        ` : ''}
        <button onclick="showDriverDetail('${d.id}')" class="px-3 py-1 bg-indigo-100 text-indigo-700 rounded-lg text-xs font-medium hover:bg-indigo-200 mr-1">ดูข้อมูล</button>
        <button onclick="editDriverProfile('${d.id}')" class="px-3 py-1 bg-blue-500 text-white rounded-lg text-xs font-medium hover:bg-blue-600 mr-1">แก้ไข</button>
        <button onclick="deleteUser('${d.id}','${(d.full_name||'').replace(/'/g,'')}')" class="px-3 py-1 bg-red-100 text-red-600 rounded-lg text-xs font-medium hover:bg-red-200">ลบ</button>
      </td>
    </tr>
  `).join('');
}

function filterDriversByStatus(status) {
  window._driverStatusFilter = status || '';
  filterDrivers();
}

function filterDrivers() {
  let filtered = window._allDrivers || [];
  const status = window._driverStatusFilter || '';
  const search = (document.getElementById('driverSearch')?.value || '').toLowerCase();
  if (status) filtered = filtered.filter(d => d.approval_status === status);
  if (search) {
    filtered = filtered.filter(d =>
      (d.full_name || '').toLowerCase().includes(search) ||
      (window._emailMap[d.id] || '').toLowerCase().includes(search) ||
      (d.phone_number || '').toLowerCase().includes(search) ||
      (d.license_plate || '').toLowerCase().includes(search),
    );
  }
  window._filteredDrivers = filtered;
  document.getElementById('driversTableBody').innerHTML = renderDriverRows(filtered);
}

function exportDriversCsv() {
  const rows = (window._filteredDrivers || window._allDrivers || []).map((d) => ({
    ชื่อ: d.full_name || '-',
    อีเมล: window._emailMap?.[d.id] || '-',
    เบอร์โทร: d.phone_number || '-',
    ทะเบียน: d.license_plate || '-',
    สถานะ: d.approval_status || '-',
    ออนไลน์: _truthyFlag(d.is_online) ? 'ออนไลน์' : 'ออฟไลน์',
    สมัครเมื่อ: fmtDate(d.created_at),
  }));
  exportRowsToCsv(reportFilename('drivers_report', 'csv', '', ''), ['ชื่อ', 'อีเมล', 'เบอร์โทร', 'ทะเบียน', 'สถานะ', 'ออนไลน์', 'สมัครเมื่อ'], rows);
}

function exportDriversExcel() {
  const rows = (window._filteredDrivers || window._allDrivers || []).map((d) => ({
    ชื่อ: d.full_name || '-',
    อีเมล: window._emailMap?.[d.id] || '-',
    เบอร์โทร: d.phone_number || '-',
    ทะเบียน: d.license_plate || '-',
    สถานะ: d.approval_status || '-',
    ออนไลน์: _truthyFlag(d.is_online) ? 'ออนไลน์' : 'ออฟไลน์',
    สมัครเมื่อ: fmtDate(d.created_at),
  }));
  exportRowsToExcel(reportFilename('drivers_report', 'xls', '', ''), ['ชื่อ', 'อีเมล', 'เบอร์โทร', 'ทะเบียน', 'สถานะ', 'ออนไลน์', 'สมัครเมื่อ'], rows);
}

async function approveDriver(id) {
  if (!confirm('อนุมัติคนขับนี้?')) return;
  const { error } = await supabase.from('profiles').update({ approval_status: 'approved', approved_at: new Date().toISOString() }).eq('id', id);
  if (error) return showToast('เกิดข้อผิดพลาด: ' + error.message, 'error');
  await _notifyAdminActionTargets([
    {
      user_id: id,
      title: '✅ บัญชีคนขับได้รับอนุมัติแล้ว',
      body: 'แอดมินอนุมัติบัญชีคนขับของคุณแล้ว สามารถเริ่มรับงานได้',
      type: 'admin_approve_driver',
      data: { type: 'admin_approve_driver', user_id: id },
    },
  ]);
  showToast('อนุมัติคนขับสำเร็จ', 'success');
  refreshCurrentPage();
}

async function rejectDriver(id) {
  const reason = prompt('เหตุผลที่ปฏิเสธ:');
  if (!reason) return;
  const { error } = await supabase.from('profiles').update({ approval_status: 'rejected', rejection_reason: reason }).eq('id', id);
  if (error) return showToast('เกิดข้อผิดพลาด: ' + error.message, 'error');
  await _notifyAdminActionTargets([
    {
      user_id: id,
      title: '❌ บัญชีคนขับถูกปฏิเสธ',
      body: `แอดมินปฏิเสธการอนุมัติบัญชีคนขับ: ${reason}`,
      type: 'admin_reject_driver',
      data: { type: 'admin_reject_driver', user_id: id, reason },
    },
  ]);
  showToast('ปฏิเสธคนขับแล้ว', 'info');
  refreshCurrentPage();
}

function showAddDriverForm() {
  const c = document.getElementById('driverFormContainer');
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

async function submitAddDriver() {
  const email = document.getElementById('addDrvEmail').value;
  const pass = document.getElementById('addDrvPass').value;
  if (!email || !pass) return alert('กรุณากรอกอีเมลและรหัสผ่าน');
  try {
    const { data, error } = await supabase.auth.signUp({ email, password: pass, options: { data: { role: 'driver' } } });
    if (error) throw error;
    if (data.user) {
      await supabase.from('profiles').upsert({
        id: data.user.id, role: 'driver', approval_status: 'approved',
        full_name: document.getElementById('addDrvName').value,
        phone_number: document.getElementById('addDrvPhone').value,
        license_plate: document.getElementById('addDrvPlate').value,
        vehicle_type: document.getElementById('addDrvVehicle').value,
        created_at: new Date().toISOString(), updated_at: new Date().toISOString(),
      });
      await supabase.from('wallets').insert({ user_id: data.user.id, balance: 0 });
    }
    alert('เพิ่มคนขับสำเร็จ!');
    refreshCurrentPage();
  } catch(e) { alert('เกิดข้อผิดพลาด: ' + e.message); }
}

async function editDriverProfile(id) {
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
          <p class="text-xs text-gray-500">${d.full_name || 'ไม่ระบุชื่อ'}</p>
        </div>
        <button onclick="document.getElementById('editDriverModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-6 overflow-y-auto flex-1 space-y-4">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div><label class="block text-sm font-medium mb-1">ชื่อ-นามสกุล</label><input id="editDrvName" value="${(d.full_name||'').replace(/"/g,'&quot;')}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div><label class="block text-sm font-medium mb-1">เบอร์โทร</label><input id="editDrvPhone" value="${d.phone_number||''}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div><label class="block text-sm font-medium mb-1">ทะเบียนรถ</label><input id="editDrvPlate" value="${d.license_plate||''}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div><label class="block text-sm font-medium mb-1">ประเภทรถ</label>
            <select id="editDrvVehicle" class="w-full border rounded-lg px-3 py-2 text-sm">
              <option value="มอเตอร์ไซค์" ${d.vehicle_type==='มอเตอร์ไซค์'?'selected':''}>มอเตอร์ไซค์</option>
              <option value="รถยนต์" ${d.vehicle_type==='รถยนต์'?'selected':''}>รถยนต์</option>
            </select>
          </div>
          <div><label class="block text-sm font-medium mb-1">สถานะ</label>
            <select id="editDrvStatus" class="w-full border rounded-lg px-3 py-2 text-sm">
              <option value="approved" ${d.approval_status==='approved'?'selected':''}>อนุมัติ</option>
              <option value="pending" ${d.approval_status==='pending'?'selected':''}>รอ</option>
              <option value="suspended" ${d.approval_status==='suspended'?'selected':''}>ระงับ</option>
              <option value="rejected" ${d.approval_status==='rejected'?'selected':''}>ปฏิเสธ</option>
            </select>
          </div>
          <div><label class="block text-sm font-medium mb-1">เหตุผลระงับ/ปฏิเสธ</label><input id="editDrvReason" value="${(d.rejection_reason||'').replace(/"/g,'&quot;')}" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="ระบุเหตุผล (ถ้ามี)" /></div>
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
            <div><label class="block text-xs mb-1">ธนาคาร</label><input id="editDrvBank" value="${d.bank_name||''}" class="w-full border rounded-lg px-3 py-1.5 text-sm" /></div>
            <div><label class="block text-xs mb-1">เลขบัญชี</label><input id="editDrvAccNum" value="${d.bank_account_number||''}" class="w-full border rounded-lg px-3 py-1.5 text-sm" /></div>
            <div><label class="block text-xs mb-1">ชื่อบัญชี</label><input id="editDrvAccName" value="${(d.bank_account_name||'').replace(/"/g,'&quot;')}" class="w-full border rounded-lg px-3 py-1.5 text-sm" /></div>
          </div>
        </div>
      </div>
      <div class="px-6 py-4 border-t border-gray-100 flex gap-2 justify-end">
        <button onclick="document.getElementById('editDriverModal')?.remove()" class="px-4 py-2 bg-gray-100 text-gray-600 rounded-lg text-sm font-medium hover:bg-gray-200">ยกเลิก</button>
        <button onclick="submitEditDriver('${id}')" class="px-5 py-2 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">บันทึก</button>
      </div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });
}

async function uploadDriverDoc(driverId, field, input) {
  try {
    await uploadProfileImageField(driverId, field, input, 'driver_docs');
    showToast('อัปโหลดสำเร็จ!', 'success');
    editDriverProfile(driverId); // Refresh modal
  } catch(e) { showToast('อัปโหลดไม่สำเร็จ: ' + e.message, 'error'); }
}

async function submitEditDriver(id) {
  try {
    const updateData = {
      full_name: document.getElementById('editDrvName').value,
      phone_number: document.getElementById('editDrvPhone').value,
      license_plate: document.getElementById('editDrvPlate').value,
      vehicle_type: document.getElementById('editDrvVehicle').value,
      approval_status: document.getElementById('editDrvStatus').value,
      bank_name: document.getElementById('editDrvBank').value,
      bank_account_number: document.getElementById('editDrvAccNum').value,
      bank_account_name: document.getElementById('editDrvAccName').value,
      updated_at: new Date().toISOString(),
    };
    const reason = document.getElementById('editDrvReason').value;
    if (reason) updateData.rejection_reason = reason;
    if (updateData.approval_status === 'approved') updateData.approved_at = new Date().toISOString();
    
    const { error } = await supabase.from('profiles').update(updateData).eq('id', id);
    if (error) throw error;
    document.getElementById('editDriverModal')?.remove();
    showToast('บันทึกข้อมูลคนขับสำเร็จ!', 'success');
    refreshCurrentPage();
  } catch(e) { showToast('เกิดข้อผิดพลาด: ' + (e.message || JSON.stringify(e)), 'error'); }
}

async function uploadMerchantImage(merchantId, field, input) {
  try {
    await uploadProfileImageField(merchantId, field, input, 'profiles');
    showToast('อัปโหลดรูปภาพสำเร็จ!', 'success');
    await editMerchantProfile(merchantId);
  } catch (e) {
    showToast('อัปโหลดรูปไม่สำเร็จ: ' + (e.message || JSON.stringify(e)), 'error');
  }
}

async function deleteUser(id, name) {
  if (!confirm(`ลบผู้ใช้ "${name}" ?\nข้อมูลจะถูกลบถาวร`)) return;
  try {
    const { data: profile, error: profileReadErr } = await supabase
      .from('profiles')
      .select('id, role')
      .eq('id', id)
      .maybeSingle();
    if (profileReadErr) throw profileReadErr;
    if (profile?.role === 'admin') {
      throw new Error('ไม่อนุญาตให้ลบบัญชีแอดมิน');
    }

    const { error: profileDeleteErr } = await supabase.from('profiles').delete().eq('id', id);
    if (profileDeleteErr) throw profileDeleteErr;

    const { error: authDeleteErr } = await supabase.auth.admin.deleteUser(id);
    if (authDeleteErr && !String(authDeleteErr.message || '').toLowerCase().includes('not found')) {
      throw authDeleteErr;
    }

    showToast('ลบสำเร็จ!', 'success');
    _removeProfileFromLocalCaches(id);
    _rerenderCurrentManagementRows();
    setTimeout(refreshCurrentPage, 0);
  } catch(e) { showToast('เกิดข้อผิดพลาด: ' + (e.message || JSON.stringify(e)), 'error'); }
}

// ============================================
// Merchants Page
// ============================================
async function renderMerchants(el) {
  const [{ data: merchants }] = await Promise.all([
    supabase.from('profiles').select('*').eq('role', 'merchant').order('created_at', { ascending: false }),
    fetchUserEmails()
  ]);
  const statusRows = [
    { label: 'รออนุมัติ', value: (merchants || []).filter(m => m.approval_status === 'pending').length },
    { label: 'อนุมัติแล้ว', value: (merchants || []).filter(m => m.approval_status === 'approved').length },
    { label: 'ระงับ/ปฏิเสธ', value: (merchants || []).filter(m => m.approval_status === 'suspended' || m.approval_status === 'rejected').length },
  ];
  const onlineRows = [
    { label: 'ออนไลน์', value: (merchants || []).filter(m => _truthyFlag(m.is_online)).length },
    { label: 'ออฟไลน์', value: (merchants || []).filter(m => !_truthyFlag(m.is_online)).length },
  ];

  el.innerHTML = `
    <div class="fade-in space-y-5">
      <div class="glass-card p-4 flex gap-2 flex-wrap items-center">
        <button onclick="filterMerchantsByStatus('')" class="px-4 py-2 bg-white border border-gray-200 rounded-xl text-sm font-semibold hover:bg-gray-50 transition-colors">ทั้งหมด (${(merchants||[]).length})</button>
        <button onclick="filterMerchantsByStatus('pending')" class="px-4 py-2 bg-amber-50 border border-amber-200 rounded-xl text-sm font-semibold text-amber-600 hover:bg-amber-100 transition-colors">รออนุมัติ (${(merchants||[]).filter(m=>m.approval_status==='pending').length})</button>
        <button onclick="filterMerchantsByStatus('approved')" class="px-4 py-2 bg-emerald-50 border border-emerald-200 rounded-xl text-sm font-semibold text-emerald-600 hover:bg-emerald-100 transition-colors">อนุมัติแล้ว (${(merchants||[]).filter(m=>m.approval_status==='approved').length})</button>
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
  window._allMerchants = merchants || [];
  window._filteredMerchants = merchants || [];
  window._merchantStatusFilter = '';
}

function renderMerchantRows(merchants) {
  if (!merchants.length) return '<tr><td colspan="8" class="px-4 py-8 text-center text-gray-400">ไม่มีข้อมูล</td></tr>';
  return merchants.map(m => `
    <tr class="table-row border-b border-gray-50">
      <td class="px-4 py-3 font-medium">${m.full_name || '-'}</td>
      <td class="px-4 py-3 text-xs text-gray-500">${window._emailMap[m.id] || '-'}</td>
      <td class="px-4 py-3">${m.phone_number || '-'}</td>
      <td class="px-4 py-3 text-gray-600 max-w-[200px] truncate">${m.shop_address || '-'}</td>
      <td class="px-4 py-3">${statusBadge(m.approval_status || 'pending')}</td>
      <td class="px-4 py-3">${onlineBadge(_truthyFlag(m.is_online))}</td>
      <td class="px-4 py-3 text-gray-500 text-xs">${fmtDate(m.created_at)}</td>
      <td class="px-4 py-3">
        <button onclick="setUserOnlineStatus('${m.id}', ${_truthyFlag(m.is_online) ? 'false' : 'true'}, 'merchant')" class="px-3 py-1 ${_truthyFlag(m.is_online) ? 'bg-orange-100 text-orange-700 hover:bg-orange-200' : 'bg-emerald-100 text-emerald-700 hover:bg-emerald-200'} rounded-lg text-xs font-medium mr-1">${_truthyFlag(m.is_online) ? 'ตั้งออฟไลน์' : 'ตั้งออนไลน์'}</button>
        ${m.approval_status === 'pending' ? `
          <button onclick="approveMerchant('${m.id}')" class="px-3 py-1 bg-green-500 text-white rounded-lg text-xs font-medium hover:bg-green-600 mr-1">อนุมัติ</button>
          <button onclick="rejectMerchant('${m.id}')" class="px-3 py-1 bg-red-500 text-white rounded-lg text-xs font-medium hover:bg-red-600 mr-1">ปฏิเสธ</button>
        ` : m.approval_status === 'approved' ? `
          <button onclick="suspendUser('${m.id}')" class="px-3 py-1 bg-gray-500 text-white rounded-lg text-xs font-medium hover:bg-gray-600 mr-1">ระงับ</button>
        ` : m.approval_status === 'suspended' || m.approval_status === 'rejected' ? `
          <button onclick="approveMerchant('${m.id}')" class="px-3 py-1 bg-green-500 text-white rounded-lg text-xs font-medium hover:bg-green-600 mr-1">อนุมัติ</button>
        ` : ''}
        <button onclick="editMerchantProfile('${m.id}')" class="px-3 py-1 bg-blue-500 text-white rounded-lg text-xs font-medium hover:bg-blue-600 mr-1">แก้ไข</button>
        <button onclick="showMerchantOrderManager('${m.id}','${(m.full_name||'').replace(/'/g,'')}')" class="px-3 py-1 bg-emerald-500 text-white rounded-lg text-xs font-medium hover:bg-emerald-600 mr-1">ออเดอร์</button>
        <button onclick="navigateTo('menus');window._selectedMerchantId='${m.id}';window._selectedMerchantName='${(m.full_name||'').replace(/'/g,'')}';" class="px-3 py-1 bg-purple-500 text-white rounded-lg text-xs font-medium hover:bg-purple-600 mr-1">เมนู</button>
        <button onclick="deleteUser('${m.id}','${(m.full_name||'').replace(/'/g,'')}')" class="px-3 py-1 bg-red-100 text-red-600 rounded-lg text-xs font-medium hover:bg-red-200">ลบ</button>
      </td>
    </tr>
  `).join('');
}

function filterMerchantsByStatus(status) {
  window._merchantStatusFilter = status || '';
  filterMerchants();
}

function filterMerchants() {
  let filtered = window._allMerchants || [];
  const status = window._merchantStatusFilter || '';
  const search = (document.getElementById('merchantSearch')?.value || '').toLowerCase();
  if (status) filtered = filtered.filter(m => m.approval_status === status);
  if (search) {
    filtered = filtered.filter(m =>
      (m.full_name || '').toLowerCase().includes(search) ||
      (window._emailMap[m.id] || '').toLowerCase().includes(search) ||
      (m.phone_number || '').toLowerCase().includes(search) ||
      (m.shop_address || '').toLowerCase().includes(search),
    );
  }
  window._filteredMerchants = filtered;
  document.getElementById('merchantsTableBody').innerHTML = renderMerchantRows(filtered);
}

function exportMerchantsCsv() {
  const rows = (window._filteredMerchants || window._allMerchants || []).map((m) => ({
    ชื่อร้าน: m.full_name || '-',
    อีเมล: window._emailMap?.[m.id] || '-',
    เบอร์โทร: m.phone_number || '-',
    ที่อยู่ร้าน: m.shop_address || '-',
    สถานะ: m.approval_status || '-',
    ออนไลน์: _truthyFlag(m.is_online) ? 'ออนไลน์' : 'ออฟไลน์',
    สมัครเมื่อ: fmtDate(m.created_at),
  }));
  exportRowsToCsv(reportFilename('merchants_report', 'csv', '', ''), ['ชื่อร้าน', 'อีเมล', 'เบอร์โทร', 'ที่อยู่ร้าน', 'สถานะ', 'ออนไลน์', 'สมัครเมื่อ'], rows);
}

function exportMerchantsExcel() {
  const rows = (window._filteredMerchants || window._allMerchants || []).map((m) => ({
    ชื่อร้าน: m.full_name || '-',
    อีเมล: window._emailMap?.[m.id] || '-',
    เบอร์โทร: m.phone_number || '-',
    ที่อยู่ร้าน: m.shop_address || '-',
    สถานะ: m.approval_status || '-',
    ออนไลน์: _truthyFlag(m.is_online) ? 'ออนไลน์' : 'ออฟไลน์',
    สมัครเมื่อ: fmtDate(m.created_at),
  }));
  exportRowsToExcel(reportFilename('merchants_report', 'xls', '', ''), ['ชื่อร้าน', 'อีเมล', 'เบอร์โทร', 'ที่อยู่ร้าน', 'สถานะ', 'ออนไลน์', 'สมัครเมื่อ'], rows);
}

function _patchProfileInLocalCaches(userId, patch) {
  const patchList = (list) => (list || []).map((item) => (item.id === userId ? { ...item, ...patch } : item));
  window._allUsers = patchList(window._allUsers);
  window._allDrivers = patchList(window._allDrivers);
  window._allMerchants = patchList(window._allMerchants);
}

function _removeProfileFromLocalCaches(userId) {
  const prune = (list) => (list || []).filter((item) => item.id !== userId);
  window._allUsers = prune(window._allUsers);
  window._allDrivers = prune(window._allDrivers);
  window._allMerchants = prune(window._allMerchants);
}

function _rerenderCurrentManagementRows() {
  if (currentPage === 'users') {
    filterUsers();
    return;
  }
  if (currentPage === 'drivers') {
    filterDrivers();
    return;
  }
  if (currentPage === 'merchants') {
    filterMerchants();
  }
}

async function approveMerchant(id) {
  if (!confirm('อนุมัติร้านค้านี้?')) return;
  const { error } = await supabase.from('profiles').update({ approval_status: 'approved', approved_at: new Date().toISOString() }).eq('id', id);
  if (error) return showToast('เกิดข้อผิดพลาด: ' + error.message, 'error');
  await _notifyAdminActionTargets([
    {
      user_id: id,
      title: '✅ บัญชีร้านค้าได้รับอนุมัติแล้ว',
      body: 'แอดมินอนุมัติร้านค้าของคุณแล้ว สามารถเปิดร้านได้',
      type: 'admin_approve_merchant',
      data: { type: 'admin_approve_merchant', user_id: id },
    },
  ]);
  showToast('อนุมัติร้านค้าสำเร็จ', 'success');
  refreshCurrentPage();
}

async function rejectMerchant(id) {
  const reason = prompt('เหตุผลที่ปฏิเสธ:');
  if (!reason) return;
  const { error } = await supabase.from('profiles').update({ approval_status: 'rejected', rejection_reason: reason }).eq('id', id);
  if (error) return showToast('เกิดข้อผิดพลาด: ' + error.message, 'error');
  await _notifyAdminActionTargets([
    {
      user_id: id,
      title: '❌ บัญชีร้านค้าถูกปฏิเสธ',
      body: `แอดมินปฏิเสธการอนุมัติร้านค้า: ${reason}`,
      type: 'admin_reject_merchant',
      data: { type: 'admin_reject_merchant', user_id: id, reason },
    },
  ]);
  showToast('ปฏิเสธร้านค้าแล้ว', 'info');
  refreshCurrentPage();
}

function showAddMerchantForm() {
  const c = document.getElementById('merchantFormContainer');
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

async function submitAddMerchant() {
  const email = document.getElementById('addMrcEmail').value;
  const pass = document.getElementById('addMrcPass').value;
  if (!email || !pass) return alert('กรุณากรอกอีเมลและรหัสผ่าน');
  try {
    const { data, error } = await supabase.auth.signUp({ email, password: pass, options: { data: { role: 'merchant' } } });
    if (error) throw error;
    if (data.user) {
      await supabase.from('profiles').upsert({
        id: data.user.id, role: 'merchant', approval_status: 'approved',
        full_name: document.getElementById('addMrcName').value || document.getElementById('addMrcShop').value,
        phone_number: document.getElementById('addMrcPhone').value,
        shop_address: document.getElementById('addMrcAddr').value,
        created_at: new Date().toISOString(), updated_at: new Date().toISOString(),
      });
    }
    alert('เพิ่มร้านค้าสำเร็จ!');
    refreshCurrentPage();
  } catch(e) { alert('เกิดข้อผิดพลาด: ' + e.message); }
}

async function editMerchantProfile(id) {
  const { data: m } = await supabase.from('profiles').select('*').eq('id', id).single();
  if (!m) return;
  let merchantSystemSplitPct = '';
  let merchantDriverSplitPct = '';
  try {
    const { data: splitRows } = await supabase
      .from('system_config')
      .select('key,value')
      .in('key', [
        `merchant_gp_system_rate_${id}`,
        `merchant_gp_driver_rate_${id}`,
      ]);
    const splitMap = {};
    (splitRows || []).forEach((row) => {
      if (row?.key) splitMap[row.key] = row.value;
    });
    const splitSystemRaw = splitMap[`merchant_gp_system_rate_${id}`];
    const splitDriverRaw = splitMap[`merchant_gp_driver_rate_${id}`];
    if (splitSystemRaw != null && splitSystemRaw !== '') {
      merchantSystemSplitPct = (parseFloat(splitSystemRaw) * 100).toFixed(1);
    }
    if (splitDriverRaw != null && splitDriverRaw !== '') {
      merchantDriverSplitPct = (parseFloat(splitDriverRaw) * 100).toFixed(1);
    }
  } catch (_) {
    // ignore and use defaults
  }
  const c = document.getElementById('merchantFormContainer');
  c.innerHTML = `
    <div class="glass-card p-6">
      <h4 class="font-bold text-gray-800 mb-4 flex items-center gap-2">
        <span class="material-icons-round text-blue-500">store</span> แก้ไขข้อมูลร้านค้า
      </h4>
      
      <!-- ข้อมูลร้าน -->
      <div class="mb-5">
        <p class="text-sm font-semibold text-gray-600 mb-2 border-b pb-1">📋 ข้อมูลร้าน</p>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div><label class="block text-sm font-medium mb-1">ชื่อร้าน / เจ้าของ</label><input id="editMrcName" value="${m.full_name||''}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div><label class="block text-sm font-medium mb-1">เบอร์โทร</label><input id="editMrcPhone" value="${m.phone_number||''}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div class="md:col-span-2"><label class="block text-sm font-medium mb-1">ที่อยู่ร้าน</label><input id="editMrcAddr" value="${m.shop_address||''}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div><label class="block text-sm font-medium mb-1">สถานะร้าน</label>
            <select id="editMrcOpenStatus" class="w-full border rounded-lg px-3 py-2 text-sm">
              <option value="open" ${m.shop_status !== false ? 'selected' : ''}>เปิด</option>
              <option value="closed" ${m.shop_status === false ? 'selected' : ''}>ปิด (ระงับ)</option>
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

      <!-- เวลาเปิด-ปิด + วันเปิดร้าน -->
      <div class="mb-5">
        <p class="text-sm font-semibold text-gray-600 mb-2 border-b pb-1">🕐 เวลาและวันเปิดร้าน</p>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-3">
          <div><label class="block text-sm font-medium mb-1">เวลาเปิดร้าน</label><input id="editMrcOpenTime" type="time" value="${m.shop_open_time || '08:00'}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div><label class="block text-sm font-medium mb-1">เวลาปิดร้าน</label><input id="editMrcCloseTime" type="time" value="${m.shop_close_time || '22:00'}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
        </div>
        <label class="block text-sm font-medium mb-2">วันที่เปิดร้าน <span class="text-red-500">*</span></label>
        <div id="editMrcDaysWrap" class="flex flex-wrap gap-2 mb-1">
          ${['mon','tue','wed','thu','fri','sat','sun'].map(d => {
            const thLabel = {mon:'จ',tue:'อ',wed:'พ',thu:'พฤ',fri:'ศ',sat:'ส',sun:'อา'}[d];
            const checked = Array.isArray(m.shop_open_days) && m.shop_open_days.includes(d);
            return `<label class="inline-flex items-center gap-1 px-3 py-1.5 rounded-full border text-sm font-semibold cursor-pointer select-none transition-colors ${ checked ? 'bg-indigo-100 border-indigo-400 text-indigo-700' : 'bg-white border-gray-300 text-gray-600 hover:bg-gray-50'}">
              <input type="checkbox" value="${d}" class="editMrcDayChk hidden" ${checked ? 'checked' : ''} onchange="this.parentElement.className=this.checked?'inline-flex items-center gap-1 px-3 py-1.5 rounded-full border text-sm font-semibold cursor-pointer select-none transition-colors bg-indigo-100 border-indigo-400 text-indigo-700':'inline-flex items-center gap-1 px-3 py-1.5 rounded-full border text-sm font-semibold cursor-pointer select-none transition-colors bg-white border-gray-300 text-gray-600 hover:bg-gray-50'">
              ${thLabel}</label>`;
          }).join('')}
        </div>
        <p class="text-xs text-gray-400">เลือกอย่างน้อย 1 วัน</p>
      </div>

      <!-- การรับออเดอร์ / เปิดปิดร้านอัตโนมัติ -->
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

      <!-- ค่าธรรมเนียมเฉพาะร้าน -->
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

async function submitEditMerchant(id) {
  try {
    // Validate open days
    const dayChecks = document.querySelectorAll('.editMrcDayChk:checked');
    if (dayChecks.length === 0) {
      showToast('กรุณาเลือกวันเปิดร้านอย่างน้อย 1 วัน', 'error');
      return;
    }
    const selectedDays = Array.from(dayChecks).map(cb => cb.value);

    const gpRaw = document.getElementById('editMrcGP')?.value;
    const gpSystemRaw = document.getElementById('editMrcGpSystemRate')?.value;
    const gpDriverRaw = document.getElementById('editMrcGpDriverRate')?.value;
    const baseFareVal = document.getElementById('editMrcBaseFare')?.value;
    const baseDistVal = document.getElementById('editMrcBaseDist')?.value;
    const perKmVal = document.getElementById('editMrcPerKm')?.value;
    const deliveryFeeVal = document.getElementById('editMrcDeliveryFee')?.value;
    const serviceFeeVal = document.getElementById('editMrcServiceFee')?.value;
    const updateData = {
      full_name: document.getElementById('editMrcName').value,
      phone_number: document.getElementById('editMrcPhone').value,
      shop_address: document.getElementById('editMrcAddr').value,
      gp_rate: gpRaw !== '' && gpRaw != null ? parseFloat(gpRaw) / 100 : null,
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
      if (Math.abs(splitTotal - gpTotal) > 0.0001) {
        throw new Error(`GP Share รวมต้องเท่ากับ GP เข้าระบบ + GP ให้คนขับ (รวม ${(gpTotal * 100).toFixed(1)}%, split ${(splitTotal * 100).toFixed(1)}%)`);
      }
    }

    const { error } = await supabase.from('profiles').update(updateData).eq('id', id);
    if (error) throw error;

    await _upsertSystemConfigKeyValues([
      {
        key: `merchant_gp_system_rate_${id}`,
        value: gpSystem != null ? gpSystem.toFixed(4) : '',
      },
      {
        key: `merchant_gp_driver_rate_${id}`,
        value: gpDriver != null ? gpDriver.toFixed(4) : '',
      },
    ]);

    showToast('บันทึกข้อมูลร้านค้าสำเร็จ!', 'success');
    document.getElementById('merchantFormContainer').innerHTML = '';
    refreshCurrentPage();
  } catch(e) { showToast('เกิดข้อผิดพลาด: ' + (e.message || JSON.stringify(e)), 'error'); }
}

async function showMerchantOrderManager(merchantId, merchantName = '') {
  document.getElementById('merchantOrderManagerModal')?.remove();

  const modal = document.createElement('div');
  modal.id = 'merchantOrderManagerModal';
  modal.dataset.merchantId = merchantId;
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-5xl mx-4 fade-in max-h-[90vh] overflow-hidden flex flex-col">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <div>
          <h3 class="font-bold text-gray-800 text-lg">จัดการออเดอร์ร้านค้าแทนร้าน</h3>
          <p class="text-xs text-gray-500 mt-1">${merchantName || merchantId}</p>
        </div>
        <div class="flex items-center gap-2">
          <button onclick="refreshMerchantOrderManager('${merchantId}')" class="px-3 py-1.5 bg-indigo-50 text-indigo-600 rounded-lg text-xs font-semibold hover:bg-indigo-100">รีเฟรช</button>
          <button onclick="document.getElementById('merchantOrderManagerModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
        </div>
      </div>
      <div id="merchantOrderManagerBody" class="p-5 overflow-auto flex-1">
        <div class="flex justify-center py-10"><div class="loader"></div></div>
      </div>
    </div>`;

  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });

  await refreshMerchantOrderManager(merchantId);
}

async function refreshMerchantOrderManager(merchantId) {
  const bodyEl = document.getElementById('merchantOrderManagerBody');
  if (!bodyEl) return;

  const managedStatuses = [
    'pending',
    'pending_merchant',
    'preparing',
    'driver_accepted',
    'arrived_at_merchant',
    'matched',
    'ready_for_pickup',
    'picking_up_order',
    'in_transit',
  ];

  const { data: orders, error } = await supabase
    .from('bookings')
    .select('id, status, service_type, driver_id, customer_id, price, delivery_fee, pickup_address, destination_address, created_at')
    .eq('merchant_id', merchantId)
    .eq('service_type', 'food')
    .in('status', managedStatuses)
    .order('created_at', { ascending: false })
    .limit(100);

  if (error) {
    bodyEl.innerHTML = `<div class="text-red-500 text-sm">ไม่สามารถโหลดออเดอร์ร้านค้าได้: ${error.message}</div>`;
    return;
  }

  if (!orders?.length) {
    bodyEl.innerHTML = '<div class="text-gray-400 text-sm text-center py-8">ไม่มีออเดอร์ที่กำลังดำเนินการ</div>';
    return;
  }

  const profileIds = [...new Set(
    (orders || [])
      .flatMap((o) => [o.driver_id, o.customer_id])
      .filter(Boolean),
  )];
  const profileMap = {};
  if (profileIds.length) {
    const { data: profiles } = await supabase.from('profiles').select('id, full_name').in('id', profileIds);
    (profiles || []).forEach((p) => { profileMap[p.id] = p.full_name || '-'; });
  }

  bodyEl.innerHTML = `
    <div class="overflow-x-auto">
      <table class="w-full text-sm">
        <thead>
          <tr class="bg-gray-50/80">
            <th class="px-4 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ออเดอร์</th>
            <th class="px-4 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">สถานะ</th>
            <th class="px-4 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ลูกค้า</th>
            <th class="px-4 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">คนขับ</th>
            <th class="px-4 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ราคา</th>
            <th class="px-4 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">สร้างเมื่อ</th>
            <th class="px-4 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">จัดการ</th>
          </tr>
        </thead>
        <tbody class="divide-y divide-gray-100">
          ${(orders || []).map((o) => {
            const canAccept = _canAdminMerchantAccept(o);
            const canReady = _canAdminMarkFoodReady(o);
            let actionButtons = '<span class="text-gray-300 text-xs">-</span>';
            if (canAccept || canReady) {
              actionButtons = `
                <div class="flex items-center gap-1 flex-wrap">
                  <button onclick="showPendingOrderDetail('${o.id}')" class="px-2 py-1 bg-indigo-100 text-indigo-700 rounded-lg text-xs font-medium hover:bg-indigo-200">รายละเอียด</button>
                  ${canAccept ? `<button onclick="adminMerchantAcceptOrder('${o.id}')" class="px-2 py-1 bg-emerald-100 text-emerald-700 rounded-lg text-xs font-medium hover:bg-emerald-200">รับแทนร้าน</button>` : ''}
                  ${canReady ? `<button onclick="adminMarkFoodReady('${o.id}')" class="px-2 py-1 bg-teal-100 text-teal-700 rounded-lg text-xs font-medium hover:bg-teal-200">อาหารพร้อม</button>` : ''}
                </div>`;
            } else {
              actionButtons = `<button onclick="showPendingOrderDetail('${o.id}')" class="px-2 py-1 bg-indigo-100 text-indigo-700 rounded-lg text-xs font-medium hover:bg-indigo-200">รายละเอียด</button>`;
            }

            return `
              <tr>
                <td class="px-4 py-3">
                  <p class="font-mono text-xs text-indigo-600">#${o.id.substring(0, 8)}</p>
                  <p class="text-[11px] text-gray-500 truncate max-w-[220px]">📍 ${o.pickup_address || '-'}</p>
                </td>
                <td class="px-4 py-3">${statusBadge(o.status)}</td>
                <td class="px-4 py-3 text-xs">${profileMap[o.customer_id] || '-'}</td>
                <td class="px-4 py-3 text-xs">${profileMap[o.driver_id] || '<span class="text-red-500">ยังไม่มี</span>'}</td>
                <td class="px-4 py-3 text-xs font-semibold">฿${fmt(Math.round((o.price || 0) + (o.delivery_fee || 0)))}</td>
                <td class="px-4 py-3 text-xs text-gray-500">${fmtDate(o.created_at)}</td>
                <td class="px-4 py-3">${actionButtons}</td>
              </tr>`;
          }).join('')}
        </tbody>
      </table>
    </div>`;
}

async function _refreshAdminOrderViews() {
  if (currentPage === 'orders') {
    await loadOrders();
  }
  if (currentPage === 'pending_orders') {
    await _refreshPendingOrders();
  }
  if (currentPage === 'map') {
    await refreshMapData();
  }

  const merchantOrderModal = document.getElementById('merchantOrderManagerModal');
  const merchantId = merchantOrderModal?.dataset?.merchantId;
  if (merchantId) {
    await refreshMerchantOrderManager(merchantId);
  }
}

async function adminMerchantAcceptOrder(orderId) {
  await _adminActAsMerchantOrder(orderId, 'accept');
}

async function adminMarkFoodReady(orderId) {
  await _adminActAsMerchantOrder(orderId, 'ready');
}

async function _adminActAsMerchantOrder(orderId, action) {
  const isAccept = action === 'accept';
  const confirmText = isAccept
    ? `ให้แอดมินรับออเดอร์ #${orderId.substring(0, 8)} แทนร้านค้า?`
    : `ให้อัปเดตออเดอร์ #${orderId.substring(0, 8)} เป็น "อาหารพร้อม" แทนร้านค้า?`;

  if (!confirm(confirmText)) return;

  try {
    const nowIso = new Date().toISOString();
    const { data: booking, error: bookingError } = await supabase
      .from('bookings')
      .select('id, status, service_type, merchant_id, customer_id, driver_id')
      .eq('id', orderId)
      .maybeSingle();

    if (bookingError) throw bookingError;
    if (!booking) throw new Error('ไม่พบออเดอร์ที่ต้องการ');
    if (booking.service_type !== 'food') {
      throw new Error('ฟีเจอร์นี้ใช้ได้เฉพาะออเดอร์อาหารเท่านั้น');
    }

    let updateQuery = supabase
      .from('bookings')
      .update({
        status: isAccept ? 'preparing' : 'ready_for_pickup',
        updated_at: nowIso,
      })
      .eq('id', orderId);

    if (isAccept) {
      updateQuery = updateQuery.in('status', ADMIN_MERCHANT_ACCEPT_STATUSES);
    } else {
      updateQuery = updateQuery.in('status', ADMIN_MERCHANT_READY_STATUSES);
    }

    const { data: updatedRows, error: updateError } = await updateQuery.select('id, status');
    if (updateError) throw updateError;
    if (!updatedRows?.length) {
      throw new Error(
        isAccept
          ? 'ออเดอร์ไม่ได้อยู่ในสถานะรอร้านค้ารับแล้ว กรุณารีเฟรชข้อมูล'
          : 'ไม่สามารถอัปเดตเป็นอาหารพร้อมได้ในสถานะปัจจุบัน',
      );
    }

    const shortId = orderId.substring(0, 8);
    const notifyRows = [];
    if (booking.merchant_id) {
      notifyRows.push({
        user_id: booking.merchant_id,
        title: isAccept ? '🛠️ แอดมินรับออเดอร์แทนร้าน' : '✅ แอดมินกดอาหารพร้อมแทนร้าน',
        body: isAccept
          ? `ออเดอร์ #${shortId} ถูกแอดมินรับแทนร้านค้าแล้ว`
          : `ออเดอร์ #${shortId} ถูกแอดมินอัปเดตเป็นอาหารพร้อมแล้ว`,
        type: isAccept ? 'admin_accept_order_for_merchant' : 'admin_mark_food_ready_for_merchant',
        data: {
          type: isAccept ? 'admin_accept_order_for_merchant' : 'admin_mark_food_ready_for_merchant',
          booking_id: orderId,
          merchant_id: booking.merchant_id,
        },
      });
    }
    if (booking.customer_id) {
      notifyRows.push({
        user_id: booking.customer_id,
        title: isAccept ? '🍳 ร้านค้าเริ่มเตรียมอาหารแล้ว' : '🍱 อาหารพร้อมจัดส่งแล้ว',
        body: isAccept
          ? `ออเดอร์ #${shortId} กำลังอยู่ระหว่างการเตรียมอาหาร`
          : `ออเดอร์ #${shortId} พร้อมให้คนขับไปรับแล้ว`,
        type: isAccept ? 'admin_customer_order_preparing' : 'admin_customer_food_ready',
        data: {
          type: isAccept ? 'admin_customer_order_preparing' : 'admin_customer_food_ready',
          booking_id: orderId,
        },
      });
    }
    if (booking.driver_id) {
      notifyRows.push({
        user_id: booking.driver_id,
        title: isAccept ? '🏪 ร้านค้ารับออเดอร์แล้ว' : '🍱 อาหารพร้อมรับแล้ว',
        body: isAccept
          ? `ออเดอร์ #${shortId} ร้านค้าเริ่มเตรียมอาหารแล้ว`
          : `ออเดอร์ #${shortId} ร้านค้าแจ้งว่าอาหารพร้อมรับแล้ว`,
        type: isAccept ? 'admin_driver_order_preparing' : 'admin_driver_food_ready',
        data: {
          type: isAccept ? 'admin_driver_order_preparing' : 'admin_driver_food_ready',
          booking_id: orderId,
        },
      });
    }

    await _notifyAdminActionTargets(notifyRows);
    showToast(isAccept ? 'แอดมินรับออเดอร์แทนร้านสำเร็จ' : 'แอดมินอัปเดตเป็นอาหารพร้อมสำเร็จ', 'success');
    await _refreshAdminOrderViews();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + (e.message || JSON.stringify(e)), 'error');
  }
}

// ============================================
// Users Page
// ============================================
async function renderUsers(el) {
  const [{ data: users }] = await Promise.all([
    supabase.from('profiles').select('*').order('created_at', { ascending: false }).limit(200),
    fetchUserEmails()
  ]);

  const counts = { customer: 0, driver: 0, merchant: 0, admin: 0 };
  (users || []).forEach(u => { if (counts[u.role] !== undefined) counts[u.role]++; });

  el.innerHTML = `
    <div class="fade-in space-y-5">
      <div class="grid grid-cols-2 md:grid-cols-4 gap-5">
        ${statCard('people', 'ทั้งหมด', fmt((users||[]).length), 'bg-indigo-500')}
        ${statCard('person', 'ลูกค้า', fmt(counts.customer), 'bg-blue-500')}
        ${statCard('directions_car', 'คนขับ', fmt(counts.driver), 'bg-green-500')}
        ${statCard('store', 'ร้านค้า', fmt(counts.merchant), 'bg-orange-500')}
      </div>
      <div class="glass-card overflow-hidden">
        <div class="px-6 py-4 flex items-center gap-3">
          <span class="material-icons-round text-indigo-400">search</span>
          <input type="text" id="userSearch" placeholder="ค้นหาชื่อ, อีเมล..." class="text-sm border border-gray-200 rounded-xl px-3.5 py-2 flex-1 bg-gray-50/50 transition-all" oninput="filterUsers()">
          <select id="userRoleFilter" onchange="filterUsers()" class="text-sm border border-gray-200 rounded-xl px-3.5 py-2 bg-gray-50/50 transition-all">
            <option value="">ทุกบทบาท</option>
            <option value="customer">ลูกค้า</option>
            <option value="driver">คนขับ</option>
            <option value="merchant">ร้านค้า</option>
            <option value="admin">แอดมิน</option>
          </select>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm">
            <thead><tr class="bg-gray-50/80">
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ชื่อ</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">อีเมล</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">เบอร์โทร</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">บทบาท</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">สถานะ</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ออนไลน์</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">สมัครเมื่อ</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">จัดการ</th>
            </tr></thead>
            <tbody id="usersTableBody" class="divide-y divide-gray-100">
              ${renderUserRows(users || [])}
            </tbody>
          </table>
        </div>
      </div>
    </div>
  `;
  window._allUsers = users || [];
}

function renderUserRows(users) {
  if (!users.length) return '<tr><td colspan="8" class="px-4 py-8 text-center text-gray-400">ไม่มีข้อมูล</td></tr>';
  const roleMap = { customer: 'ลูกค้า', driver: 'คนขับ', merchant: 'ร้านค้า', admin: 'แอดมิน' };
  const roleColor = { customer: 'blue', driver: 'green', merchant: 'orange', admin: 'purple' };
  return users.map(u => `
    <tr class="table-row border-b border-gray-50">
      <td class="px-4 py-3 font-medium">${u.full_name || '-'}</td>
      <td class="px-4 py-3 text-xs text-gray-500">${window._emailMap[u.id] || '-'}</td>
      <td class="px-4 py-3">${u.phone_number || '-'}</td>
      <td class="px-4 py-3"><span class="px-2 py-1 rounded-full text-xs font-semibold bg-${roleColor[u.role]||'gray'}-100 text-${roleColor[u.role]||'gray'}-700">${roleMap[u.role] || u.role}</span></td>
      <td class="px-4 py-3">${statusBadge(u.approval_status || 'approved')}</td>
      <td class="px-4 py-3">${onlineBadge(_truthyFlag(u.is_online))}</td>
      <td class="px-4 py-3 text-gray-500 text-xs">${fmtDate(u.created_at)}</td>
      <td class="px-4 py-3">
        ${u.role !== 'admin' ? `
          <button onclick="setUserOnlineStatus('${u.id}', ${_truthyFlag(u.is_online) ? 'false' : 'true'}, '${u.role || ''}')" class="px-3 py-1 ${_truthyFlag(u.is_online) ? 'bg-orange-100 text-orange-700 hover:bg-orange-200' : 'bg-emerald-100 text-emerald-700 hover:bg-emerald-200'} rounded-lg text-xs font-medium mr-1">${_truthyFlag(u.is_online) ? 'ออฟไลน์' : 'ออนไลน์'}</button>
          <button onclick="editUserProfile('${u.id}')" class="px-3 py-1 bg-blue-500 text-white rounded-lg text-xs font-medium hover:bg-blue-600 mr-1">แก้ไข</button>
          <button onclick="suspendUser('${u.id}')" class="px-3 py-1 bg-gray-100 text-gray-600 rounded-lg text-xs font-medium hover:bg-gray-200 mr-1">ระงับ</button>
          <button onclick="deleteUser('${u.id}','${(u.full_name||'').replace(/'/g,'')}')" class="px-3 py-1 bg-red-100 text-red-600 rounded-lg text-xs font-medium hover:bg-red-200">ลบ</button>
        ` : '<span class="text-gray-300 text-xs">-</span>'}
      </td>
    </tr>
  `).join('');
}

async function editUserProfile(id) {
  const { data: u } = await supabase.from('profiles').select('*').eq('id', id).single();
  if (!u) return;

  document.getElementById('editUserModal')?.remove();
  const modal = document.createElement('div');
  modal.id = 'editUserModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 fade-in max-h-[90vh] flex flex-col">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <div>
          <h3 class="font-bold text-gray-800 text-lg">แก้ไขข้อมูลผู้ใช้</h3>
          <p class="text-xs text-gray-500">${u.full_name || '-'} • ${u.role || '-'}</p>
        </div>
        <button onclick="document.getElementById('editUserModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-6 overflow-y-auto flex-1 space-y-4">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div><label class="block text-sm font-medium mb-1">ชื่อ-นามสกุล</label><input id="editUsrName" value="${(u.full_name||'').replace(/"/g,'&quot;')}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div><label class="block text-sm font-medium mb-1">เบอร์โทร</label><input id="editUsrPhone" value="${u.phone_number||''}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div><label class="block text-sm font-medium mb-1">ประเภทผู้ใช้</label>
            <select id="editUsrRole" class="w-full border rounded-lg px-3 py-2 text-sm" ${u.role === 'admin' ? 'disabled' : ''}>
              <option value="customer" ${u.role==='customer'?'selected':''}>ลูกค้า</option>
              <option value="driver" ${u.role==='driver'?'selected':''}>คนขับ</option>
              <option value="merchant" ${u.role==='merchant'?'selected':''}>ร้านค้า</option>
              ${u.role === 'admin' ? '<option value="admin" selected>แอดมิน</option>' : ''}
            </select>
            <input type="hidden" id="editUsrOriginalRole" value="${u.role || ''}">
          </div>
          <div><label class="block text-sm font-medium mb-1">สถานะบัญชี</label>
            <select id="editUsrStatus" class="w-full border rounded-lg px-3 py-2 text-sm">
              <option value="approved" ${u.approval_status==='approved'?'selected':''}>อนุมัติ</option>
              <option value="pending" ${u.approval_status==='pending'?'selected':''}>รอ</option>
              <option value="suspended" ${u.approval_status==='suspended'?'selected':''}>ระงับ</option>
              <option value="rejected" ${u.approval_status==='rejected'?'selected':''}>ปฏิเสธ</option>
            </select>
          </div>
          <div><label class="block text-sm font-medium mb-1">ออนไลน์</label>
            <select id="editUsrOnline" class="w-full border rounded-lg px-3 py-2 text-sm">
              <option value="1" ${_truthyFlag(u.is_online)?'selected':''}>ออนไลน์</option>
              <option value="0" ${!_truthyFlag(u.is_online)?'selected':''}>ออฟไลน์</option>
            </select>
          </div>
          <div class="md:col-span-2"><label class="block text-sm font-medium mb-1">ที่อยู่ร้าน (สำหรับร้านค้า)</label><input id="editUsrShopAddr" value="${(u.shop_address||'').replace(/"/g,'&quot;')}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div><label class="block text-sm font-medium mb-1">ทะเบียนรถ (สำหรับคนขับ)</label><input id="editUsrPlate" value="${(u.license_plate||'').replace(/"/g,'&quot;')}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div><label class="block text-sm font-medium mb-1">ประเภทรถ (สำหรับคนขับ)</label><input id="editUsrVehicle" value="${(u.vehicle_type||'').replace(/"/g,'&quot;')}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
        </div>

        <div class="border-t pt-4">
          <p class="text-sm font-bold mb-2">รูปโปรไฟล์</p>
          <div class="flex items-center gap-3">
            ${u.avatar_url ? `<img src="${u.avatar_url}" class="w-12 h-12 rounded-lg object-cover border" onerror="this.style.display='none'" />` : '<div class="w-12 h-12 rounded-lg bg-gray-200 flex items-center justify-center"><span class="material-icons-round text-gray-400 text-sm">person</span></div>'}
            <label class="px-2.5 py-1.5 bg-blue-500 text-white rounded text-xs cursor-pointer hover:bg-blue-600">
              อัปโหลด<input type="file" accept="image/*" class="hidden" onchange="uploadUserAvatar('${id}',this)" />
            </label>
          </div>
        </div>
      </div>
      <div class="px-6 py-4 border-t border-gray-100 flex gap-2 justify-end">
        <button onclick="document.getElementById('editUserModal')?.remove()" class="px-4 py-2 bg-gray-100 text-gray-600 rounded-lg text-sm font-medium hover:bg-gray-200">ยกเลิก</button>
        <button onclick="submitEditUser('${id}')" class="px-5 py-2 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">บันทึก</button>
      </div>
    </div>`;

  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });
}

async function uploadUserAvatar(userId, input) {
  try {
    await uploadProfileImageField(userId, 'avatar_url', input, 'profiles');
    showToast('อัปโหลดรูปโปรไฟล์สำเร็จ!', 'success');
    await editUserProfile(userId);
  } catch (e) {
    showToast('อัปโหลดรูปไม่สำเร็จ: ' + (e.message || JSON.stringify(e)), 'error');
  }
}

async function submitEditUser(id) {
  try {
    const originalRole = document.getElementById('editUsrOriginalRole')?.value || 'customer';
    const nextRole = document.getElementById('editUsrRole')?.value || originalRole;
    const updateData = {
      full_name: document.getElementById('editUsrName')?.value || '',
      phone_number: document.getElementById('editUsrPhone')?.value || '',
      approval_status: document.getElementById('editUsrStatus')?.value || 'approved',
      is_online: document.getElementById('editUsrOnline')?.value === '1',
      role: nextRole,
      updated_at: new Date().toISOString(),
    };

    if (nextRole === 'merchant') {
      updateData.shop_address = document.getElementById('editUsrShopAddr')?.value || '';
    } else {
      updateData.shop_address = null;
    }

    if (nextRole === 'driver') {
      updateData.license_plate = document.getElementById('editUsrPlate')?.value || '';
      updateData.vehicle_type = document.getElementById('editUsrVehicle')?.value || '';
    } else {
      updateData.license_plate = null;
      updateData.vehicle_type = null;
    }

    const { error } = await supabase.from('profiles').update(updateData).eq('id', id);
    if (error) throw error;

    if (originalRole !== 'driver' && nextRole === 'driver') {
      const { error: locUpsertErr } = await supabase
        .from('driver_locations')
        .upsert({
          driver_id: id,
          is_online: updateData.is_online,
          is_available: false,
          updated_at: new Date().toISOString(),
        }, { onConflict: 'driver_id' });
      if (locUpsertErr) throw locUpsertErr;
    }

    if (originalRole === 'driver' && nextRole !== 'driver') {
      const { error: locPatchErr } = await supabase
        .from('driver_locations')
        .update({ is_online: false, is_available: false, updated_at: new Date().toISOString() })
        .eq('driver_id', id);
      if (locPatchErr) throw locPatchErr;
    }

    _patchProfileInLocalCaches(id, updateData);
    _rerenderCurrentManagementRows();

    document.getElementById('editUserModal')?.remove();
    showToast('บันทึกข้อมูลผู้ใช้สำเร็จ!', 'success');
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + (e.message || JSON.stringify(e)), 'error');
  }
}

function filterUsers() {
  const search = (document.getElementById('userSearch')?.value || '').toLowerCase();
  const role = document.getElementById('userRoleFilter')?.value || '';
  let filtered = window._allUsers || [];
  if (role) filtered = filtered.filter(u => u.role === role);
  if (search) filtered = filtered.filter(u => (u.full_name||'').toLowerCase().includes(search) || (u.phone_number||'').includes(search) || (window._emailMap[u.id]||'').toLowerCase().includes(search));
  document.getElementById('usersTableBody').innerHTML = renderUserRows(filtered);
}

async function suspendUser(id) {
  const reason = prompt('เหตุผลที่ระงับบัญชี:');
  if (!reason) return;
  const patch = {
    approval_status: 'suspended',
    rejection_reason: reason,
    updated_at: new Date().toISOString(),
  };
  const { error } = await supabase.from('profiles').update(patch).eq('id', id);
  if (error) return showToast('เกิดข้อผิดพลาด: ' + error.message, 'error');
  try {
    await _notifyAdminActionTargets([
      {
        user_id: id,
        title: '⛔ บัญชีถูกระงับโดยแอดมิน',
        body: `บัญชีของคุณถูกระงับชั่วคราว: ${reason}`,
        type: 'admin_suspend_user',
        data: { type: 'admin_suspend_user', user_id: id, reason },
      },
    ]);
  } catch (notifyErr) {
    console.warn('Suspend notify warning:', notifyErr);
  }

  _patchProfileInLocalCaches(id, patch);
  _rerenderCurrentManagementRows();

  showToast('ระงับบัญชีแล้ว', 'info');
}

// ============================================
// Withdrawals Page
// ============================================
async function renderWithdrawals(el) {
  const { data: requests } = await supabase.from('withdrawal_requests').select('*').order('created_at', { ascending: false }).limit(100);

  // Fetch user names
  const userIds = [...new Set((requests||[]).map(r => r.user_id))];
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
          <h3 class="font-bold text-gray-800">คำขอถอนเงิน (${(requests||[]).length})</h3>
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
                    <td class="px-4 py-3 font-medium">${user.full_name || '-'}</td>
                    <td class="px-4 py-3 text-gray-500">${user.role || '-'}</td>
                    <td class="px-4 py-3 font-semibold text-green-600">฿${fmt(r.amount)}</td>
                    <td class="px-4 py-3">${r.bank_name || '-'}</td>
                    <td class="px-4 py-3 font-mono text-xs">${r.bank_account_number || '-'}</td>
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
  window._allWithdrawals = (requests || []).map((r) => {
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

async function approveWithdrawal(id) {
  if (!confirm('อนุมัติการถอนเงินนี้?')) return;
  const { data: req, error: reqErr } = await supabase
    .from('withdrawal_requests')
    .select('user_id, amount')
    .eq('id', id)
    .single();
  if (reqErr) return showToast('เกิดข้อผิดพลาด: ' + reqErr.message, 'error');

  const { error } = await supabase.from('withdrawal_requests').update({ status: 'completed', processed_at: new Date().toISOString() }).eq('id', id);
  if (error) return showToast('เกิดข้อผิดพลาด: ' + error.message, 'error');
  await _notifyAdminActionTargets([
    {
      user_id: req.user_id,
      title: '✅ อนุมัติถอนเงินแล้ว',
      body: `คำขอถอนเงิน ฿${fmt(req.amount || 0)} ได้รับการอนุมัติแล้ว`,
      type: 'admin_approve_withdrawal',
      data: { type: 'admin_approve_withdrawal', request_id: id, amount: String(req.amount || 0) },
    },
  ]);
  showToast('อนุมัติการถอนเงินสำเร็จ', 'success');
  refreshCurrentPage();
}

async function rejectWithdrawal(id, userId, amount) {
  const reason = prompt('เหตุผลที่ปฏิเสธ:');
  if (!reason) return;
  // Refund to wallet
  try {
    const { data: wallet } = await supabase.from('wallets').select('id, balance').eq('user_id', userId).single();
    if (wallet) {
      await supabase.from('wallets').update({ balance: (wallet.balance || 0) + amount }).eq('id', wallet.id);
    }
  } catch(e) { console.error('Refund error:', e); }
  const { error } = await supabase.from('withdrawal_requests').update({ status: 'rejected', admin_note: reason, processed_at: new Date().toISOString() }).eq('id', id);
  if (error) return showToast('เกิดข้อผิดพลาด: ' + error.message, 'error');
  await _notifyAdminActionTargets([
    {
      user_id: userId,
      title: '❌ ปฏิเสธคำขอถอนเงิน',
      body: `คำขอถอนเงิน ฿${fmt(amount || 0)} ถูกปฏิเสธ: ${reason}`,
      type: 'admin_reject_withdrawal',
      data: { type: 'admin_reject_withdrawal', request_id: id, amount: String(amount || 0), reason },
    },
  ]);
  showToast('ปฏิเสธการถอนเงิน + คืนเงินเข้า Wallet แล้ว', 'info');
  refreshCurrentPage();
}

// ============================================
// Promo Codes Page
// ============================================
let _promoFilter = 'all'; // all, active, expired, inactive
let _promoMerchants = [];

async function renderPromos(el) {
  const [{ data: coupons }, { data: merchants }] = await Promise.all([
    supabase.from('coupons').select('*').order('created_at', { ascending: false }),
    supabase.from('profiles').select('id, full_name').eq('role', 'merchant').order('full_name'),
  ]);
  _promoMerchants = merchants || [];
  const all = coupons || [];
  const merchantOptions = ['<option value="">คูปองส่วนกลาง (ทุกคนใช้ได้)</option>']
    .concat(_promoMerchants.map(m => `<option value="${m.id}">${m.full_name || m.id}</option>`))
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
      <!-- Stats -->
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

      <!-- Create New -->
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

      <!-- Coupon List -->
      <div class="glass-card p-6">
        <div class="flex items-center justify-between mb-4">
          <div class="flex items-center gap-3">
            <div class="w-9 h-9 bg-violet-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-violet-500 text-lg">list</span></div>
            <h3 class="font-bold text-gray-800">รายการโค้ดส่วนลด</h3>
          </div>
          <div class="flex gap-2">
            <button onclick="setPromoFilter('all')" class="px-3 py-1.5 rounded-xl text-xs font-semibold transition-colors ${_promoFilter==='all'?'text-white shadow-md':'bg-gray-100 text-gray-600 hover:bg-gray-200'}" ${_promoFilter==='all'?'style="background:linear-gradient(135deg,#6366f1,#818cf8);"':''}>ทั้งหมด</button>
            <button onclick="setPromoFilter('active')" class="px-3 py-1.5 rounded-xl text-xs font-semibold transition-colors ${_promoFilter==='active'?'text-white shadow-md':'bg-gray-100 text-gray-600 hover:bg-gray-200'}" ${_promoFilter==='active'?'style="background:linear-gradient(135deg,#10b981,#14b8a6);"':''}>ใช้งานอยู่</button>
            <button onclick="setPromoFilter('expired')" class="px-3 py-1.5 rounded-xl text-xs font-semibold transition-colors ${_promoFilter==='expired'?'text-white shadow-md':'bg-gray-100 text-gray-600 hover:bg-gray-200'}" ${_promoFilter==='expired'?'style="background:linear-gradient(135deg,#f43f5e,#ec4899);"':''}>หมดอายุ</button>
            <button onclick="setPromoFilter('inactive')" class="px-3 py-1.5 rounded-xl text-xs font-semibold transition-colors ${_promoFilter==='inactive'?'bg-gray-600 text-white':'bg-gray-100 text-gray-600 hover:bg-gray-200'}">ปิดอยู่</button>
          </div>
        </div>
        <div id="promoList" class="space-y-3">
          ${renderPromoList(all)}
        </div>
      </div>
    </div>
  `;

  // Set default dates
  const nowLocal = new Date();
  const startStr = new Date(nowLocal.getTime() - nowLocal.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
  const endDate = new Date(nowLocal);
  endDate.setMonth(endDate.getMonth() + 1);
  const endStr = new Date(endDate.getTime() - endDate.getTimezoneOffset() * 60000).toISOString().slice(0, 16);
  document.getElementById('promoStart').value = startStr;
  document.getElementById('promoEnd').value = endStr;
  window._allPromos = all;
}

function _filteredPromos() {
  const all = window._allPromos || [];
  const now = new Date().toISOString();
  if (_promoFilter === 'active') return all.filter(c => c.is_active && c.end_date > now && c.start_date <= now);
  if (_promoFilter === 'expired') return all.filter(c => c.end_date <= now);
  if (_promoFilter === 'inactive') return all.filter(c => !c.is_active);
  return all;
}

function exportPromosCsv() {
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

function exportPromosExcel() {
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

function renderPromoList(coupons) {
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
          ${c.description ? `<p class="text-xs text-gray-400 truncate">${c.description}</p>` : ''}
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

function setPromoFilter(f) {
  _promoFilter = f;
  refreshCurrentPage();
}

function onPromoTypeChange() {
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

async function createPromoCode() {
  const code = document.getElementById('promoCode').value.trim().toUpperCase();
  const name = document.getElementById('promoName').value.trim();
  const description = document.getElementById('promoDesc').value.trim() || null;
  const discountType = document.getElementById('promoType').value;
  const discountValue = parseFloat(document.getElementById('promoValue').value) || 0;
  const maxDisc = parseFloat(document.getElementById('promoMaxDisc').value) || null;
  const minOrder = parseFloat(document.getElementById('promoMinOrder').value) || null;
  const serviceType = document.getElementById('promoService').value || null;
  const merchantId = document.getElementById('promoMerchant').value || null;
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

    const { error } = await supabase.from('coupons').insert(insertData);
    if (error) {
      if (error.message.includes('duplicate') || error.message.includes('unique')) {
        return alert('โค้ดนี้มีอยู่แล้ว กรุณาใช้โค้ดอื่น');
      }
      throw error;
    }

    showToast('สร้างโค้ดส่วนลดสำเร็จ!', 'success');
    refreshCurrentPage();
  } catch (e) {
    alert('เกิดข้อผิดพลาด: ' + e.message);
  }
}

async function togglePromoActive(id, newState) {
  try {
    const { error } = await supabase.from('coupons').update({ is_active: newState }).eq('id', id);
    if (error) throw error;
    showToast(newState ? 'เปิดใช้งานโค้ดแล้ว' : 'ปิดใช้งานโค้ดแล้ว', 'success');
    refreshCurrentPage();
  } catch (e) { showToast('เกิดข้อผิดพลาด: ' + (e.message || JSON.stringify(e)), 'error'); }
}

async function deletePromoCode(id, code) {
  if (!confirm(`ลบโค้ด "${code}" ?\nการลบจะไม่สามารถกู้คืนได้`)) return;
  try {
    // Delete usages first
    await supabase.from('coupon_usages').delete().eq('coupon_id', id);
    await supabase.from('coupons').delete().eq('id', id);
    showToast('ลบโค้ดสำเร็จ', 'success');
    refreshCurrentPage();
  } catch (e) { alert('เกิดข้อผิดพลาด: ' + e.message); }
}

async function editPromoCode(id) {
  const { data: c } = await supabase.from('coupons').select('*').eq('id', id).single();
  if (!c) return;
  const merchantOptions = ['<option value="">คูปองส่วนกลาง</option>']
    .concat(_promoMerchants.map(m => `<option value="${m.id}" ${c.merchant_id===m.id?'selected':''}>${m.full_name || m.id}</option>`))
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
          <input id="editPromoDesc" type="text" value="${c.description||''}" class="w-full px-3 py-2 border rounded-lg text-sm">
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
          <div>
            <label class="block text-xs font-medium text-gray-600 mb-1">จำกัด/คน</label>
            <input id="editPromoPerUser" type="number" value="${c.per_user_limit||0}" class="w-full px-3 py-2 border rounded-lg text-sm" min="0">
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

async function submitEditPromo(id) {
  try {
    const discountType = document.getElementById('editPromoType').value;
    const merchantId = document.getElementById('editPromoMerchant').value || null;
    const updateData = {
      name: document.getElementById('editPromoName').value.trim(),
      description: document.getElementById('editPromoDesc').value.trim() || null,
      discount_type: discountType,
      discount_value: discountType === 'free_delivery' ? 0 : (parseFloat(document.getElementById('editPromoValue').value) || 0),
      max_discount_amount: discountType === 'percentage' ? (parseFloat(document.getElementById('editPromoMaxDisc').value) || null) : null,
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

    const { error } = await supabase.from('coupons').update(updateData).eq('id', id);
    if (error) throw error;

    document.getElementById('promoEditModal')?.remove();
    showToast('แก้ไขโค้ดสำเร็จ!', 'success');
    refreshCurrentPage();
  } catch (e) {
    alert('เกิดข้อผิดพลาด: ' + e.message);
  }
}

// ============================================
// Account Deletions Page
// ============================================
async function renderAccountDeletions(el) {
  const { data: requests, error } = await supabase
    .from('account_deletion_requests')
    .select('*')
    .order('requested_at', { ascending: false });

  if (error) { el.innerHTML = `<p class="text-red-500">Error: ${error.message}</p>`; return; }

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
            <div class="font-bold text-gray-800 truncate">${r.user_name || 'ไม่ทราบชื่อ'}</div>
            <div class="text-xs text-gray-400 truncate">${r.user_email || ''}</div>
          </div>
          <span class="inline-flex items-center px-2.5 py-0.5 rounded-lg text-xs font-semibold bg-${rc}-50 text-${rc}-600 border border-${rc}-200">${roleLabels[r.user_role] || r.user_role}</span>
        </div>
        ${r.reason ? `<div class="bg-gray-50 rounded-xl p-3 text-sm text-gray-600 mb-3 border border-gray-100"><span class="font-semibold text-gray-500">เหตุผล:</span> ${r.reason}</div>` : ''}
        ${r.rejection_reason ? `<div class="bg-rose-50 rounded-xl p-3 text-sm text-rose-600 mb-3 border border-rose-100"><span class="font-semibold">เหตุผลปฏิเสธ:</span> ${r.rejection_reason}</div>` : ''}
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
    </div>`;
  window._allAccountDeletionRequests = requests || [];
}

function exportAccountDeletionsCsv() {
  const rows = (window._allAccountDeletionRequests || []).map((r) => ({
    ชื่อผู้ใช้: r.user_name || '-',
    อีเมล: r.user_email || '-',
    บทบาท: r.user_role || '-',
    สถานะ: r.status || '-',
    เหตุผล: r.reason || '-',
    เหตุผลปฏิเสธ: r.rejection_reason || '-',
    วันที่ขอ: fmtDate(r.requested_at),
    วันที่ตรวจสอบ: fmtDate(r.reviewed_at),
  }));
  exportRowsToCsv(reportFilename('account_deletions_report', 'csv', '', ''), ['ชื่อผู้ใช้', 'อีเมล', 'บทบาท', 'สถานะ', 'เหตุผล', 'เหตุผลปฏิเสธ', 'วันที่ขอ', 'วันที่ตรวจสอบ'], rows);
}

function exportAccountDeletionsExcel() {
  const rows = (window._allAccountDeletionRequests || []).map((r) => ({
    ชื่อผู้ใช้: r.user_name || '-',
    อีเมล: r.user_email || '-',
    บทบาท: r.user_role || '-',
    สถานะ: r.status || '-',
    เหตุผล: r.reason || '-',
    เหตุผลปฏิเสธ: r.rejection_reason || '-',
    วันที่ขอ: fmtDate(r.requested_at),
    วันที่ตรวจสอบ: fmtDate(r.reviewed_at),
  }));
  exportRowsToExcel(reportFilename('account_deletions_report', 'xls', '', ''), ['ชื่อผู้ใช้', 'อีเมล', 'บทบาท', 'สถานะ', 'เหตุผล', 'เหตุผลปฏิเสธ', 'วันที่ขอ', 'วันที่ตรวจสอบ'], rows);
}

async function approveDeletion(id) {
  if (!confirm('ยืนยันอนุมัติลบบัญชีนี้?')) return;
  try {
    const { data: req } = await supabase.from('account_deletion_requests').select('user_id').eq('id', id).single();
    const adminId = (await supabase.auth.getUser()).data?.user?.id;
    await supabase.from('account_deletion_requests').update({
      status: 'approved', reviewed_at: new Date().toISOString(), reviewed_by: adminId
    }).eq('id', id);
    await supabase.from('profiles').update({ deletion_status: 'approved' }).eq('id', req.user_id);
    showToast('อนุมัติลบบัญชีแล้ว', 'success');
    refreshCurrentPage();
  } catch (e) { showToast('เกิดข้อผิดพลาด: ' + e.message, 'error'); }
}

async function rejectDeletion(id) {
  const reason = prompt('เหตุผลในการปฏิเสธ (ไม่บังคับ):') || '';
  try {
    const { data: req } = await supabase.from('account_deletion_requests').select('user_id').eq('id', id).single();
    const adminId = (await supabase.auth.getUser()).data?.user?.id;
    await supabase.from('account_deletion_requests').update({
      status: 'rejected', reviewed_at: new Date().toISOString(), reviewed_by: adminId, rejection_reason: reason
    }).eq('id', id);
    await supabase.from('profiles').update({ deletion_status: null }).eq('id', req.user_id);
    showToast('ปฏิเสธคำขอแล้ว (บัญชีกลับมาใช้งานได้)', 'info');
    refreshCurrentPage();
  } catch (e) { showToast('เกิดข้อผิดพลาด: ' + e.message, 'error'); }
}

// ============================================
// Settings Page
// ============================================
const DEFAULT_LANDING_CONFIG = Object.freeze({
  brand_name: 'JDC Delivery',
  badge_text: 'บริการขนส่งครบวงจรในจังหวัดน่าน',
  hero_title: 'ส่งไว เรียกง่าย จบในแอปเดียว',
  hero_subtitle:
    'JDC Delivery รวมบริการเรียกรถ ส่งอาหาร และพัสดุแบบเรียลไทม์ ให้ลูกค้า คนขับ และร้านค้า ทำงานร่วมกันได้ในแพลตฟอร์มเดียว พร้อมระบบติดตามที่โปร่งใสทุกขั้นตอน',
  play_store_url: 'https://play.google.com/store/apps/details?id=com.jedechai.delivery',
  app_store_url: 'https://apps.apple.com/th/',
  ride_icon: '🛵',
  food_icon: '🍲',
  parcel_icon: '📦',
  reviews_title: 'เสียงจากลูกค้าและร้านค้า',
  reviews_subtitle: 'ความเห็นจริงจากผู้ใช้งานที่เติบโตไปกับระบบของเรา',
  review_1_name: 'คุณออม',
  review_1_role: 'ลูกค้า - เมืองน่าน',
  review_1_text: 'สั่งอาหารช่วงค่ำได้ไวมาก คนขับโทรแจ้งทุกครั้ง และติดตามสถานะได้แบบเรียลไทม์',
  review_2_name: 'ร้านครัวเหนือ',
  review_2_role: 'พาร์ทเนอร์ร้านค้า',
  review_2_text: 'ระบบหลังบ้านใช้ง่าย อัปเดตสถานะออเดอร์ชัดเจน ทำให้จัดการร้านได้คล่องขึ้น',
  review_3_name: 'คุณต้น',
  review_3_role: 'คนขับพาร์ทเนอร์',
  review_3_text: 'มีงานต่อเนื่องและดูประวัติรายได้ได้ง่าย ช่วยวางแผนการวิ่งงานทั้งวัน',
  logo_url: '',
  hero_image_url: '',
});

function normalizeLandingConfig(rawLandingConfig) {
  if (!rawLandingConfig || typeof rawLandingConfig !== 'object' || Array.isArray(rawLandingConfig)) {
    return { ...DEFAULT_LANDING_CONFIG };
  }
  return { ...DEFAULT_LANDING_CONFIG, ...rawLandingConfig };
}

const DEFAULT_DETECTION_RADIUS_CONFIG = Object.freeze({
  driver_to_customer_km: 20,
  customer_to_driver_km: 30,
  customer_to_merchant_km: 30,
  driver_to_order_km: 20,
  parcel_driver_to_pickup_km: 30,
});

function normalizeDetectionRadiusConfig(rawConfig) {
  if (!rawConfig || typeof rawConfig !== 'object' || Array.isArray(rawConfig)) {
    return { ...DEFAULT_DETECTION_RADIUS_CONFIG };
  }
  return { ...DEFAULT_DETECTION_RADIUS_CONFIG, ...rawConfig };
}

function escapeForInput(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

async function renderSettings(el) {
  let config = {};
  let rates = [];
  let kvConfig = {};
  try {
    const { data } = await supabase.from('system_config').select('*').single();
    config = data || {};
  } catch(e) { /* might not exist */ }
  try {
    const { data: kvRows } = await supabase
      .from('system_config')
      .select('key,value')
      .in('key', [
        'ride_far_pickup_threshold_km',
        'ride_far_pickup_rate_per_km_motorcycle',
        'ride_far_pickup_rate_per_km_car',
        'food_far_pickup_threshold_km_default',
        'food_far_pickup_rate_per_km_default',
        'merchant_gp_system_rate_default',
        'merchant_gp_driver_rate_default',
      ]);
    (kvRows || []).forEach((row) => {
      if (row?.key && row?.value != null) {
        kvConfig[row.key] = row.value;
      }
    });
  } catch(e) { /* key-value rows may not exist yet */ }
  try {
    const { data } = await supabase.from('service_rates').select('*').order('service_type');
    rates = data || [];
  } catch(e) {}

  // Group rates by category
  const rideRates = rates.filter(r => r.service_type.startsWith('ride'));
  const foodRate = rates.find(r => r.service_type === 'food');
  const parcelRate = rates.find(r => r.service_type === 'parcel');
  const otherRates = rates.filter(r => !r.service_type.startsWith('ride') && r.service_type !== 'food' && r.service_type !== 'parcel');

  const vehicleIcon = { ride_motorcycle:'🏍️', ride_car:'🚗', ride_van:'🚐', ride:'🚕' };
  const vehicleLabel = { ride_motorcycle:'มอเตอร์ไซค์', ride_car:'รถยนต์', ride_van:'รถตู้', ride:'เรียกรถ (ทั่วไป)' };
  const landingConfig = normalizeLandingConfig(config.landing_config);
  const detectionRadiusConfig = normalizeDetectionRadiusConfig(config.detection_radius_config);
  const merchantGpPercent = config.merchant_gp_rate ? (config.merchant_gp_rate * 100) : 10;
  const merchantGpSystemDefault = kvConfig.merchant_gp_system_rate_default != null
    ? parseFloat(kvConfig.merchant_gp_system_rate_default) * 100
    : merchantGpPercent;
  const merchantGpDriverDefault = kvConfig.merchant_gp_driver_rate_default != null
    ? parseFloat(kvConfig.merchant_gp_driver_rate_default) * 100
    : 0;

  function rateInputs(r) {
    return `<div class="mb-3 p-4 bg-gray-50/70 rounded-xl border border-gray-100" data-rate-type="${r.service_type}">
      <p class="font-semibold text-gray-700 mb-3">${vehicleIcon[r.service_type] || '📦'} ${vehicleLabel[r.service_type] || r.service_type}</p>
      <div class="grid grid-cols-3 gap-3">
        <div><label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">ราคาเริ่มต้น (฿)</label><input type="number" class="rate-base-price w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-white transition-all" value="${r.base_price || 0}" step="1" min="0"></div>
        <div><label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">ระยะเริ่มต้น (กม.)</label><input type="number" class="rate-base-dist w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-white transition-all" value="${r.base_distance || 0}" step="0.5" min="0"></div>
        <div><label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">ราคา/กม. (฿)</label><input type="number" class="rate-per-km w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-white transition-all" value="${r.price_per_km || 0}" step="1" min="0"></div>
      </div>
    </div>`;
  }

  el.innerHTML = `
    <div class="fade-in space-y-6">

      <!-- ========= ค่าธรรมเนียมระบบ ========= -->
      <div class="glass-card p-6">
        <div class="flex items-center gap-3 mb-5">
          <div class="w-10 h-10 bg-indigo-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-indigo-500">tune</span></div>
          <div>
            <h3 class="font-bold text-gray-800">ตั้งค่าทั่วไป</h3>
            <p class="text-xs text-gray-400">กำหนดค่าคอมมิชชั่นและค่าพื้นฐาน</p>
          </div>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">ค่าคอมมิชชั่นคนขับ (%)</label>
            <input type="number" id="settCommission" value="${config.commission_rate || 15}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" step="0.5" min="0" max="50">
            <p class="text-xs text-gray-400 mt-1.5">หักจากรายได้คนขับแต่ละงาน (เรียกรถ/ส่งพัสดุ)</p>
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">ยอดขั้นต่ำใน Wallet (฿)</label>
            <input type="number" id="settMinWallet" value="${config.driver_min_wallet || 0}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" step="10" min="0">
            <p class="text-xs text-gray-400 mt-1.5">คนขับต้องมีเงินขั้นต่ำเพื่อรับงาน</p>
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">เบอร์ PromptPay (สำหรับเติมเงิน)</label>
            <input type="text" id="settPromptPay" value="${config.promptpay_number || ''}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="เช่น 0812345678">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">รัศมีจัดส่งสูงสุด (กม.)</label>
            <input type="number" id="settMaxRadius" value="${config.max_delivery_radius || 30}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" step="0.5" min="1">
            <p class="text-xs text-gray-400 mt-1.5">ถ้าลูกค้าสั่งเกินรัศมีนี้ จะแจ้งเตือนและคิดค่าส่งตามระยะทาง</p>
          </div>
        </div>
        <div class="mt-5 flex justify-end">
          <button onclick="saveGeneralSettings()" class="px-5 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">
            <span class="material-icons-round text-sm align-middle mr-1">save</span> บันทึกค่าทั่วไป
          </button>
        </div>
      </div>

      <div class="glass-card p-6">
        <div class="flex items-center gap-3 mb-5">
          <div class="w-10 h-10 bg-sky-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-sky-500">radar</span></div>
          <div>
            <h3 class="font-bold text-gray-800">ตั้งค่าระยะตรวจจับแต่ละประเภท (กม.)</h3>
            <p class="text-xs text-gray-400">กำหนดรัศมีแยกตามคู่ผู้ใช้งาน/งาน เช่น คนขับ-ลูกค้า หรือ ลูกค้า-ร้านค้า</p>
          </div>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">คนขับ → ลูกค้า</label>
            <input type="number" id="settRadiusDriverToCustomer" value="${detectionRadiusConfig.driver_to_customer_km || 20}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" step="0.5" min="1">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">ลูกค้า → คนขับ</label>
            <input type="number" id="settRadiusCustomerToDriver" value="${detectionRadiusConfig.customer_to_driver_km || 30}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" step="0.5" min="1">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">ลูกค้า → ร้านค้า</label>
            <input type="number" id="settRadiusCustomerToMerchant" value="${detectionRadiusConfig.customer_to_merchant_km || 30}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" step="0.5" min="1">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">คนขับ → ออเดอร์ (หน้ารับงาน)</label>
            <input type="number" id="settRadiusDriverToOrder" value="${detectionRadiusConfig.driver_to_order_km || 20}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" step="0.5" min="1">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">คนขับพัสดุ → จุดรับ</label>
            <input type="number" id="settRadiusParcelDriverToPickup" value="${detectionRadiusConfig.parcel_driver_to_pickup_km || 30}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" step="0.5" min="1">
          </div>
        </div>
        <div class="mt-5 flex justify-end">
          <button onclick="saveDetectionRadiusSettings()" class="px-5 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-sky-200" style="background:linear-gradient(135deg,#0ea5e9,#38bdf8);">
            <span class="material-icons-round text-sm align-middle mr-1">save</span> บันทึกรัศมีตรวจจับ
          </button>
        </div>
      </div>

      <!-- ========= โหมดเติมเงิน Wallet ========= -->
      <div class="glass-card p-6">
        <div class="flex items-center gap-3 mb-5">
          <div class="w-10 h-10 bg-teal-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-teal-500">account_balance_wallet</span></div>
          <div>
            <h3 class="font-bold text-gray-800">โหมดเติมเงิน Wallet คนขับ</h3>
            <p class="text-xs text-gray-400">สลับระหว่างเติมเงินผ่าน Omise (อัตโนมัติ) หรือแอดมินอนุมัติด้วยมือ</p>
          </div>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <label class="cursor-pointer p-4 rounded-xl border-2 transition-all ${(config.topup_mode || 'admin_approve') === 'omise' ? 'border-teal-400 bg-teal-50' : 'border-gray-200 bg-white hover:bg-gray-50'}" onclick="document.getElementById('settTopupModeOmise').checked=true; document.querySelectorAll('.topup-mode-card').forEach(c=>c.className=c.dataset.off); this.className=this.dataset.on;">
            <input type="radio" name="settTopupMode" id="settTopupModeOmise" value="omise" class="hidden" ${(config.topup_mode || 'admin_approve') === 'omise' ? 'checked' : ''}>
            <div class="topup-mode-card" data-on="cursor-pointer p-4 rounded-xl border-2 transition-all border-teal-400 bg-teal-50" data-off="cursor-pointer p-4 rounded-xl border-2 transition-all border-gray-200 bg-white hover:bg-gray-50">
              <div class="flex items-center gap-3 mb-2">
                <span class="material-icons-round text-teal-500 text-xl">bolt</span>
                <span class="font-bold text-gray-800">Omise (อัตโนมัติ)</span>
              </div>
              <p class="text-xs text-gray-500 leading-relaxed">คนขับสแกน QR จ่ายเงินผ่าน Omise PromptPay → ระบบเติมเงินเข้า Wallet อัตโนมัติทันที ไม่ต้องรอแอดมินอนุมัติ</p>
              <p class="text-[11px] text-orange-500 mt-2 font-semibold">⚠️ ต้องตั้งค่า Omise API Key ใน .env ก่อน</p>
            </div>
          </label>
          <label class="cursor-pointer p-4 rounded-xl border-2 transition-all ${(config.topup_mode || 'admin_approve') === 'admin_approve' ? 'border-teal-400 bg-teal-50' : 'border-gray-200 bg-white hover:bg-gray-50'}" onclick="document.getElementById('settTopupModeAdmin').checked=true; document.querySelectorAll('.topup-mode-card').forEach(c=>c.className=c.dataset.off); this.className=this.dataset.on;">
            <input type="radio" name="settTopupMode" id="settTopupModeAdmin" value="admin_approve" class="hidden" ${(config.topup_mode || 'admin_approve') === 'admin_approve' ? 'checked' : ''}>
            <div class="topup-mode-card" data-on="cursor-pointer p-4 rounded-xl border-2 transition-all border-teal-400 bg-teal-50" data-off="cursor-pointer p-4 rounded-xl border-2 transition-all border-gray-200 bg-white hover:bg-gray-50">
              <div class="flex items-center gap-3 mb-2">
                <span class="material-icons-round text-indigo-500 text-xl">admin_panel_settings</span>
                <span class="font-bold text-gray-800">แอดมินอนุมัติ</span>
              </div>
              <p class="text-xs text-gray-500 leading-relaxed">คนขับสแกน QR โอนเงินผ่าน PromptPay ของระบบ → ส่งคำขอเติมเงินรอแอดมินตรวจสอบและอนุมัติ</p>
              <p class="text-[11px] text-blue-500 mt-2 font-semibold">💡 ใช้เมื่อ Omise มีปัญหาหรือยังไม่ได้ตั้งค่า</p>
            </div>
          </label>
        </div>
        <div class="mt-4 p-3 rounded-lg bg-amber-50 border border-amber-200 text-xs text-amber-700">
          <span class="material-icons-round text-sm align-middle mr-1">info</span>
          <strong>หมายเหตุ:</strong> เมื่อเปลี่ยนโหมด แอปคนขับจะอัปเดตอัตโนมัติในครั้งถัดไปที่เปิดหน้าเติมเงิน (ไม่ต้อง build APK ใหม่)
        </div>
        <div class="mt-5 flex justify-end">
          <button onclick="saveTopupModeSettings()" class="px-5 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-teal-200" style="background:linear-gradient(135deg,#0d9488,#14b8a6);">
            <span class="material-icons-round text-sm align-middle mr-1">save</span> บันทึกโหมดเติมเงิน
          </button>
        </div>
      </div>

      <!-- ========= อีเมลแจ้งเตือนแอดมิน ========= -->
      <div class="glass-card p-6">
        <div class="flex items-center gap-3 mb-5">
          <div class="w-10 h-10 bg-red-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-red-500">email</span></div>
          <div>
            <h3 class="font-bold text-gray-800">อีเมลแจ้งเตือนแอดมิน</h3>
            <p class="text-xs text-gray-400">ระบบจะส่งอีเมลแจ้งเตือนเมื่อมีคำขอเติมเงิน, ถอนเงิน ฯลฯ</p>
          </div>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">อีเมลหลัก (แจ้งเตือน)</label>
            <input type="email" id="settAdminEmail" value="${config.admin_notification_email || ''}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="admin@example.com">
            <p class="text-xs text-gray-400 mt-1.5">อีเมลที่จะได้รับแจ้งเตือนทุกครั้งที่มีคำขอเติมเงิน/ถอนเงินใหม่</p>
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">อีเมลสำรอง (CC)</label>
            <input type="email" id="settAdminEmailCC" value="${config.admin_notification_email_cc || ''}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="backup@example.com">
            <p class="text-xs text-gray-400 mt-1.5">อีเมล CC เพิ่มเติม (ถ้ามี)</p>
          </div>
        </div>
        <div class="mt-4 flex gap-3">
          <button onclick="saveAdminEmail()" class="px-5 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">
            <span class="material-icons-round text-sm align-middle mr-1">save</span> บันทึกอีเมล
          </button>
          <button onclick="testAdminEmail()" class="px-5 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-red-200" style="background:linear-gradient(135deg,#ef4444,#f87171);">
            <span class="material-icons-round text-sm align-middle mr-1">send</span> ทดสอบส่งอีเมล
          </button>
        </div>
      </div>

      <!-- ========= บริการเรียกรถ ========= -->
      <div class="glass-card p-6">
        <div class="flex items-center gap-3 mb-5">
          <div class="w-10 h-10 bg-blue-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-blue-500">local_taxi</span></div>
          <div>
            <h3 class="font-bold text-gray-800">บริการเรียกรถ</h3>
            <p class="text-xs text-gray-400">ตั้งค่าตามประเภทรถ</p>
          </div>
        </div>
        ${rideRates.length ? rideRates.map(r => rateInputs(r)).join('') : '<p class="text-gray-400 text-sm">ยังไม่มีข้อมูล — กรุณา run SQL migration เพื่อสร้างแถวเรท</p>'}
      </div>

      <!-- ========= บริการส่งอาหาร ========= -->
      <div class="glass-card p-6">
        <div class="flex items-center gap-3 mb-5">
          <div class="w-10 h-10 bg-orange-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-orange-500">restaurant</span></div>
          <div>
            <h3 class="font-bold text-gray-800">บริการส่งอาหาร</h3>
            <p class="text-xs text-gray-400">ค่าส่งเริ่มต้น + ส่วนแบ่งแพลตฟอร์ม</p>
          </div>
        </div>

        <p class="text-xs font-semibold text-gray-400 mb-2 uppercase tracking-wider">ค่าส่งเริ่มต้น</p>
        ${foodRate ? `
          <div class="p-4 bg-gray-50/70 rounded-xl border border-gray-100 mb-5" data-rate-type="food">
            <div class="grid grid-cols-3 gap-3">
              <div><label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">ค่าส่งเริ่มต้น (฿)</label><input type="number" class="rate-base-price w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-white transition-all" value="${foodRate.base_price || 0}" step="1" min="0"></div>
              <div><label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">ระยะเริ่มต้น (กม.)</label><input type="number" class="rate-base-dist w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-white transition-all" value="${foodRate.base_distance || 0}" step="0.5" min="0"></div>
              <div><label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">ค่าส่ง/กม. (฿)</label><input type="number" class="rate-per-km w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-white transition-all" value="${foodRate.price_per_km || 0}" step="1" min="0"></div>
            </div>
          </div>
        ` : '<p class="text-gray-400 text-sm mb-5">ยังไม่มีข้อมูล — กรุณา run SQL migration</p>'}

        <p class="text-xs font-semibold text-gray-400 mb-2 uppercase tracking-wider">ส่วนแบ่งแพลตฟอร์ม</p>
        <div class="p-4 bg-orange-50/50 rounded-xl border border-orange-100">
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-xs font-semibold text-gray-500 mb-1 uppercase tracking-wider">Platform Fee - หักจากค่าส่ง (%)</label>
              <input type="number" id="settPlatformFee" value="${config.platform_fee_rate ? (config.platform_fee_rate * 100).toFixed(0) : 15}" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-white transition-all" step="1" min="0" max="50">
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-500 mb-1 uppercase tracking-wider">Merchant GP - หักจากยอดอาหาร (%)</label>
              <input type="number" id="settMerchantGP" value="${config.merchant_gp_rate ? (config.merchant_gp_rate * 100).toFixed(0) : 10}" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-white transition-all" step="1" min="0" max="50">
              <p class="text-xs text-gray-400 mt-1.5">ปรับเฉพาะร้านได้ที่หน้าร้านค้า</p>
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-500 mb-1 uppercase tracking-wider">Merchant GP เข้าระบบ (%)</label>
              <input type="number" id="settMerchantGpSystemRate" value="${merchantGpSystemDefault.toFixed(1)}" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-white transition-all" step="0.1" min="0" max="100">
              <p class="text-xs text-gray-400 mt-1.5">ส่วนนี้หักจาก wallet คนขับเข้าระบบ</p>
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-500 mb-1 uppercase tracking-wider">Merchant GP ให้คนขับ (%)</label>
              <input type="number" id="settMerchantGpDriverRate" value="${merchantGpDriverDefault.toFixed(1)}" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-white transition-all" step="0.1" min="0" max="100">
              <p class="text-xs text-gray-400 mt-1.5">เพิ่มรายได้คนขับ แต่ไม่หัก wallet</p>
            </div>
          </div>
          <p class="text-xs text-orange-600 mt-2">Merchant GP รวม ต้องเท่ากับ (เข้าระบบ + ให้คนขับ) เช่น 20% = ระบบ 10% + คนขับ 10%</p>
        </div>
      </div>

      <div class="glass-card p-6">
        <div class="flex items-center gap-3 mb-5">
          <div class="w-10 h-10 bg-indigo-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-indigo-500">route</span></div>
          <div>
            <h3 class="font-bold text-gray-800">ค่าปรับเมื่อคนขับไกลจุดรับ</h3>
            <p class="text-xs text-gray-400">ตั้งค่า Ride/Food แบบ key-value ใน system_config</p>
          </div>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1 uppercase tracking-wider">Ride Threshold (กม.)</label>
            <input type="number" id="settRideFarPickupThreshold" value="${kvConfig.ride_far_pickup_threshold_km ?? 3}" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-white transition-all" step="0.1" min="0">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1 uppercase tracking-wider">Ride Rate/km (มอเตอร์ไซค์)</label>
            <input type="number" id="settRideFarPickupMotoRate" value="${kvConfig.ride_far_pickup_rate_per_km_motorcycle ?? 5}" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-white transition-all" step="0.1" min="0">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1 uppercase tracking-wider">Ride Rate/km (รถยนต์)</label>
            <input type="number" id="settRideFarPickupCarRate" value="${kvConfig.ride_far_pickup_rate_per_km_car ?? 7}" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-white transition-all" step="0.1" min="0">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1 uppercase tracking-wider">Food Default Threshold (กม.)</label>
            <input type="number" id="settFoodFarPickupThreshold" value="${kvConfig.food_far_pickup_threshold_km_default ?? 3}" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-white transition-all" step="0.1" min="0">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1 uppercase tracking-wider">Food Default Rate/km</label>
            <input type="number" id="settFoodFarPickupRate" value="${kvConfig.food_far_pickup_rate_per_km_default ?? 5}" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-white transition-all" step="0.1" min="0">
          </div>
        </div>
      </div>

      <!-- ========= บริการส่งพัสดุ ========= -->
      <div class="glass-card p-6">
        <div class="flex items-center gap-3 mb-5">
          <div class="w-10 h-10 bg-emerald-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-emerald-500">inventory_2</span></div>
          <div>
            <h3 class="font-bold text-gray-800">บริการส่งพัสดุ</h3>
            <p class="text-xs text-gray-400">กำหนดอัตราค่าส่งพัสดุ</p>
          </div>
        </div>
        ${parcelRate ? `
          <div class="p-4 bg-gray-50/70 rounded-xl border border-gray-100" data-rate-type="parcel">
            <div class="grid grid-cols-3 gap-3">
              <div><label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">ราคาเริ่มต้น (฿)</label><input type="number" class="rate-base-price w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-white transition-all" value="${parcelRate.base_price || 0}" step="1" min="0"></div>
              <div><label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">ระยะเริ่มต้น (กม.)</label><input type="number" class="rate-base-dist w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-white transition-all" value="${parcelRate.base_distance || 0}" step="0.5" min="0"></div>
              <div><label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">ราคา/กม. (฿)</label><input type="number" class="rate-per-km w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-white transition-all" value="${parcelRate.price_per_km || 0}" step="1" min="0"></div>
            </div>
          </div>
        ` : '<p class="text-gray-400 text-sm">ยังไม่มีข้อมูล — กรุณา run SQL migration</p>'}
      </div>

      <div class="flex justify-end">
        <button onclick="saveServiceRatesSettings()" class="px-5 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-blue-200" style="background:linear-gradient(135deg,#3b82f6,#60a5fa);">
          <span class="material-icons-round text-sm align-middle mr-1">save</span> บันทึกอัตราค่าบริการ
        </button>
      </div>

      ${otherRates.length ? `
      <!-- ========= อัตราอื่น ๆ ========= -->
      <div class="glass-card p-6">
        <div class="flex items-center gap-3 mb-5">
          <div class="w-10 h-10 bg-gray-100 rounded-xl flex items-center justify-center"><span class="material-icons-round text-gray-500">more_horiz</span></div>
          <h3 class="font-bold text-gray-800">อัตราอื่น ๆ</h3>
        </div>
        ${otherRates.map(r => rateInputs(r)).join('')}
      </div>` : ''}

      <!-- ========= ป้ายโปรโมชั่น ========= -->
      <div class="glass-card p-6">
        <div class="flex items-center gap-3 mb-5">
          <div class="w-10 h-10 bg-pink-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-pink-500">local_offer</span></div>
          <div>
            <h3 class="font-bold text-gray-800">ป้ายโปรโมชั่น</h3>
            <p class="text-xs text-gray-400">แท็กบนหน้าสั่งอาหาร</p>
          </div>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">ข้อความโปรโมชั่น</label>
            <input type="text" id="settPromoText" value="${config.promo_text || 'ส่งฟรี! สั่งครบ ฿200'}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="เช่น ส่งฟรี! สั่งครบ ฿200">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">เปิด/ปิดการแสดง</label>
            <label class="relative inline-flex items-center cursor-pointer mt-2">
              <input type="checkbox" id="settPromoEnabled" ${config.promo_enabled ? 'checked' : ''} class="sr-only peer">
              <div class="w-11 h-6 bg-gray-200 peer-focus:outline-none rounded-full peer peer-checked:after:translate-x-full peer-checked:after:border-white after:content-[''] after:absolute after:top-[2px] after:left-[2px] after:bg-white after:border-gray-300 after:border after:rounded-full after:h-5 after:w-5 after:transition-all peer-checked:bg-emerald-500"></div>
              <span class="ml-3 text-sm font-medium text-gray-700">แสดงป้ายโปรโมชั่น</span>
            </label>
          </div>
        </div>
        <div class="mt-5 flex justify-end">
          <button onclick="savePromoSettings()" class="px-5 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-pink-200" style="background:linear-gradient(135deg,#ec4899,#f472b6);">
            <span class="material-icons-round text-sm align-middle mr-1">save</span> บันทึกป้ายโปรโมชั่น
          </button>
        </div>
      </div>

      <!-- ========= Landing Page (Web) ========= -->
      <div class="glass-card p-6">
        <div class="flex items-center gap-3 mb-5">
          <div class="w-10 h-10 bg-amber-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-amber-500">public</span></div>
          <div>
            <h3 class="font-bold text-gray-800">Landing Page (เว็บสาธารณะ)</h3>
            <p class="text-xs text-gray-400">ปรับข้อความ สีไอคอน รีวิว และลิงก์ดาวน์โหลดแอปได้จากหน้านี้</p>
          </div>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">ชื่อแบรนด์</label>
            <input type="text" id="settLandingBrandName" value="${escapeForInput(landingConfig.brand_name)}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="เช่น JDC Delivery">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">ข้อความ Badge</label>
            <input type="text" id="settLandingBadgeText" value="${escapeForInput(landingConfig.badge_text)}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="เช่น บริการขนส่งครบวงจรในจังหวัดน่าน">
          </div>
          <div class="md:col-span-2">
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">หัวข้อหลัก</label>
            <input type="text" id="settLandingHeroTitle" value="${escapeForInput(landingConfig.hero_title)}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="เช่น ส่งไว เรียกง่าย จบในแอปเดียว">
          </div>
          <div class="md:col-span-2">
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">คำอธิบายหลัก</label>
            <textarea id="settLandingHeroSubtitle" rows="3" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="ข้อความอธิบายหน้า Landing">${escapeForInput(landingConfig.hero_subtitle)}</textarea>
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">ลิงก์ Play Store</label>
            <input type="url" id="settLandingPlayStoreUrl" value="${escapeForInput(landingConfig.play_store_url)}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="https://play.google.com/store/apps/details?id=...">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">ลิงก์ App Store</label>
            <input type="url" id="settLandingAppStoreUrl" value="${escapeForInput(landingConfig.app_store_url)}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="https://apps.apple.com/...">
          </div>
        </div>

        <div class="mt-5">
          <p class="text-xs font-semibold text-gray-400 mb-2 uppercase tracking-wider">ไอคอนบริการ</p>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
            <div>
              <label class="block text-xs font-semibold text-gray-500 mb-1">Ride</label>
              <input type="text" id="settLandingRideIcon" value="${escapeForInput(landingConfig.ride_icon)}" maxlength="4" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="🛵">
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-500 mb-1">Food</label>
              <input type="text" id="settLandingFoodIcon" value="${escapeForInput(landingConfig.food_icon)}" maxlength="4" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="🍲">
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-500 mb-1">Parcel</label>
              <input type="text" id="settLandingParcelIcon" value="${escapeForInput(landingConfig.parcel_icon)}" maxlength="4" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="📦">
            </div>
          </div>
        </div>

        <div class="mt-5">
          <p class="text-xs font-semibold text-gray-400 mb-2 uppercase tracking-wider">ส่วนรีวิวลูกค้า/ร้านค้า</p>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mb-3">
            <input type="text" id="settLandingReviewsTitle" value="${escapeForInput(landingConfig.reviews_title)}" class="px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="หัวข้อรีวิว">
            <input type="text" id="settLandingReviewsSubtitle" value="${escapeForInput(landingConfig.reviews_subtitle)}" class="px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="คำอธิบายรีวิว">
          </div>

          <div class="space-y-3">
            <div class="p-4 bg-gray-50/70 rounded-xl border border-gray-100">
              <p class="text-xs font-semibold text-gray-500 mb-2">รีวิว #1</p>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mb-3">
                <input type="text" id="settLandingReview1Name" value="${escapeForInput(landingConfig.review_1_name)}" class="px-4 py-2.5 border border-gray-200 rounded-xl bg-white transition-all" placeholder="ชื่อ">
                <input type="text" id="settLandingReview1Role" value="${escapeForInput(landingConfig.review_1_role)}" class="px-4 py-2.5 border border-gray-200 rounded-xl bg-white transition-all" placeholder="บทบาท/ร้านค้า">
              </div>
              <textarea id="settLandingReview1Text" rows="2" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-white transition-all" placeholder="ข้อความรีวิว">${escapeForInput(landingConfig.review_1_text)}</textarea>
            </div>

            <div class="p-4 bg-gray-50/70 rounded-xl border border-gray-100">
              <p class="text-xs font-semibold text-gray-500 mb-2">รีวิว #2</p>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mb-3">
                <input type="text" id="settLandingReview2Name" value="${escapeForInput(landingConfig.review_2_name)}" class="px-4 py-2.5 border border-gray-200 rounded-xl bg-white transition-all" placeholder="ชื่อ">
                <input type="text" id="settLandingReview2Role" value="${escapeForInput(landingConfig.review_2_role)}" class="px-4 py-2.5 border border-gray-200 rounded-xl bg-white transition-all" placeholder="บทบาท/ร้านค้า">
              </div>
              <textarea id="settLandingReview2Text" rows="2" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-white transition-all" placeholder="ข้อความรีวิว">${escapeForInput(landingConfig.review_2_text)}</textarea>
            </div>

            <div class="p-4 bg-gray-50/70 rounded-xl border border-gray-100">
              <p class="text-xs font-semibold text-gray-500 mb-2">รีวิว #3</p>
              <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mb-3">
                <input type="text" id="settLandingReview3Name" value="${escapeForInput(landingConfig.review_3_name)}" class="px-4 py-2.5 border border-gray-200 rounded-xl bg-white transition-all" placeholder="ชื่อ">
                <input type="text" id="settLandingReview3Role" value="${escapeForInput(landingConfig.review_3_role)}" class="px-4 py-2.5 border border-gray-200 rounded-xl bg-white transition-all" placeholder="บทบาท/ร้านค้า">
              </div>
              <textarea id="settLandingReview3Text" rows="2" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-white transition-all" placeholder="ข้อความรีวิว">${escapeForInput(landingConfig.review_3_text)}</textarea>
            </div>
          </div>
        </div>

        <div class="mt-5">
          <p class="text-xs font-semibold text-gray-400 mb-2 uppercase tracking-wider">รูปภาพหน้า Landing</p>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
            <div>
              <p class="text-xs font-semibold text-gray-500 mb-2">โลโก้หน้า Landing</p>
              <div id="currentLandingLogo" class="w-24 h-24 bg-gray-50 rounded-2xl flex items-center justify-center mb-3 border border-gray-100 overflow-hidden">
                <span class="material-icons-round text-gray-200 text-3xl">image</span>
              </div>
              <input type="hidden" id="settLandingLogoUrl" value="${escapeForInput(landingConfig.logo_url)}">
              <input type="file" id="landingLogoFileInput" accept="image/*" class="text-sm border border-gray-200 rounded-xl px-3.5 py-2 w-full bg-gray-50/50 transition-all" />
              <button onclick="uploadLandingAsset('logo')" class="mt-2 w-full py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-amber-200" style="background:linear-gradient(135deg,#f59e0b,#d97706);">อัปโหลดโลโก้หน้า Landing</button>
            </div>
            <div>
              <p class="text-xs font-semibold text-gray-500 mb-2">รูป Hero หน้า Landing</p>
              <div id="currentLandingHero" class="w-full h-28 bg-gray-50 rounded-2xl flex items-center justify-center mb-3 border border-gray-100 overflow-hidden">
                <span class="material-icons-round text-gray-200 text-3xl">landscape</span>
              </div>
              <input type="hidden" id="settLandingHeroImageUrl" value="${escapeForInput(landingConfig.hero_image_url)}">
              <input type="file" id="landingHeroFileInput" accept="image/*" class="text-sm border border-gray-200 rounded-xl px-3.5 py-2 w-full bg-gray-50/50 transition-all" />
              <button onclick="uploadLandingAsset('hero')" class="mt-2 w-full py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-amber-200" style="background:linear-gradient(135deg,#f59e0b,#d97706);">อัปโหลดรูป Hero</button>
            </div>
          </div>
        </div>

        <div class="mt-5 flex justify-end">
          <button onclick="saveLandingSettings()" class="px-5 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-amber-200" style="background:linear-gradient(135deg,#f59e0b,#fbbf24);">
            <span class="material-icons-round text-sm align-middle mr-1">save</span> บันทึก Landing Page
          </button>
        </div>
      </div>

      <!-- Banners Management -->
      <div class="glass-card p-6">
        <div class="flex items-center gap-3 mb-5">
          <div class="w-10 h-10 bg-violet-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-violet-500">view_carousel</span></div>
          <div>
            <h3 class="font-bold text-gray-800">จัดการ Banner โปรโมชั่น</h3>
            <p class="text-xs text-gray-400">รูป 16:9, ไม่เกิน 2MB — เลือกหน้าที่ต้องการแสดง</p>
          </div>
        </div>
        
        <!-- Banner filter tabs -->
        <div class="flex gap-2 mb-4 flex-wrap">
          <button onclick="filterBanners('all')" id="bannerFilterAll" class="px-3.5 py-1.5 text-white rounded-xl text-xs font-semibold" style="background:linear-gradient(135deg,#6366f1,#818cf8);">ทั้งหมด</button>
          <button onclick="filterBanners('home')" id="bannerFilterHome" class="px-3.5 py-1.5 bg-gray-100 text-gray-600 rounded-xl text-xs font-semibold hover:bg-gray-200 transition-colors">หน้าแรก</button>
          <button onclick="filterBanners('food')" id="bannerFilterFood" class="px-3.5 py-1.5 bg-gray-100 text-gray-600 rounded-xl text-xs font-semibold hover:bg-gray-200 transition-colors">สั่งอาหาร</button>
          <button onclick="filterBanners('ride')" id="bannerFilterRide" class="px-3.5 py-1.5 bg-gray-100 text-gray-600 rounded-xl text-xs font-semibold hover:bg-gray-200 transition-colors">เรียกรถ</button>
          <button onclick="filterBanners('parcel')" id="bannerFilterParcel" class="px-3.5 py-1.5 bg-gray-100 text-gray-600 rounded-xl text-xs font-semibold hover:bg-gray-200 transition-colors">ส่งพัสดุ</button>
        </div>

        <div id="bannerList" class="space-y-3 mb-4">
          <p class="text-gray-400 text-sm">กำลังโหลด...</p>
        </div>
        <div class="bg-gray-50/70 rounded-xl border border-gray-100 p-5">
          <h4 class="text-sm font-bold text-gray-700 mb-3 flex items-center gap-2"><span class="material-icons-round text-indigo-400 text-sm">add_photo_alternate</span> เพิ่ม Banner ใหม่</h4>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
            <div>
              <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">รูปภาพ</label>
              <input type="file" id="bannerFileInput" accept="image/*,video/mp4,image/gif" class="text-sm border border-gray-200 rounded-xl px-3.5 py-2 w-full bg-white transition-all" />
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">ชื่อ Banner</label>
              <input type="text" id="bannerTitle" placeholder="ชื่อ Banner (ถ้ามี)" class="text-sm border border-gray-200 rounded-xl px-3.5 py-2 w-full bg-white transition-all" />
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">แสดงในหน้า</label>
              <select id="bannerPage" class="text-sm border border-gray-200 rounded-xl px-3.5 py-2 w-full bg-white transition-all">
                <option value="home">หน้าแรก</option>
                <option value="food">สั่งอาหาร</option>
                <option value="ride">เรียกรถ</option>
                <option value="parcel">ส่งพัสดุ</option>
              </select>
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">โค้ดส่วนลด (ถ้ามี)</label>
              <select id="bannerCoupon" class="text-sm border border-gray-200 rounded-xl px-3.5 py-2 w-full bg-white transition-all">
                <option value="">ไม่ผูกโค้ด</option>
              </select>
              <p class="text-[10px] text-gray-400 mt-0.5">ลูกค้ากดป้ายจะเห็นโค้ดส่วนลด</p>
            </div>
            <div class="flex items-end">
              <button onclick="uploadBanner()" class="w-full py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">อัปโหลด</button>
            </div>
          </div>
        </div>
      </div>

      <!-- Logo & Splash Screen -->
      <div class="glass-card p-6">
        <div class="flex items-center gap-3 mb-5">
          <div class="w-10 h-10 bg-cyan-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-cyan-500">image</span></div>
          <div>
            <h3 class="font-bold text-gray-800">โลโก้ & Splash Screen</h3>
            <p class="text-xs text-gray-400">อัปโหลดรูปโลโก้และหน้าจอ Splash</p>
          </div>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-6">
          <div>
            <p class="text-xs font-semibold text-gray-400 mb-2 uppercase tracking-wider">โลโก้แอป</p>
            <div id="currentLogo" class="w-24 h-24 bg-gray-50 rounded-2xl flex items-center justify-center mb-3 border border-gray-100">
              <span class="material-icons-round text-gray-200 text-3xl">image</span>
            </div>
            <input type="file" id="logoFileInput" accept="image/*" class="text-sm border border-gray-200 rounded-xl px-3.5 py-2 w-full bg-gray-50/50 transition-all" />
            <button onclick="uploadAppAsset('logo')" class="mt-2 w-full py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">อัปโหลดโลโก้</button>
          </div>
          <div>
            <p class="text-xs font-semibold text-gray-400 mb-2 uppercase tracking-wider">Splash Screen</p>
            <div id="currentSplash" class="w-24 h-24 bg-gray-50 rounded-2xl flex items-center justify-center mb-3 border border-gray-100">
              <span class="material-icons-round text-gray-200 text-3xl">phone_android</span>
            </div>
            <input type="file" id="splashFileInput" accept="image/*" class="text-sm border border-gray-200 rounded-xl px-3.5 py-2 w-full bg-gray-50/50 transition-all" />
            <button onclick="uploadAppAsset('splash')" class="mt-2 w-full py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">อัปโหลด Splash</button>
          </div>
        </div>
      </div>

      <div class="glass-card p-5">
        <div class="flex items-center gap-3">
          <div class="w-8 h-8 bg-gray-100 rounded-lg flex items-center justify-center"><span class="material-icons-round text-gray-400 text-sm">info</span></div>
          <div class="flex-1 flex flex-wrap gap-6 text-xs text-gray-400">
            <span>Supabase: <span class="font-mono">${SUPABASE_URL.substring(0, 30)}...</span></span>
            <span>เวอร์ชัน: <span class="font-semibold text-gray-600">2.0.0</span></span>
          </div>
        </div>
      </div>
    </div>
  `;
  // Load banners and app assets after render
  loadBanners();
  loadAppAssets();
}

async function _getSystemConfigId() {
  const { data: existing } = await supabase.from('system_config').select('id').maybeSingle();
  return existing?.id ?? 1;
}

async function _upsertSystemConfig(patch) {
  const configId = await _getSystemConfigId();
  const payload = {
    id: configId,
    ...patch,
    updated_at: new Date().toISOString(),
  };
  const { error } = await supabase.from('system_config').upsert(payload, { onConflict: 'id' });
  if (error) throw error;
}

async function _upsertSystemConfigKeyValues(rows) {
  if (!rows || !rows.length) return;
  const payload = rows.map((row) => ({
    key: row.key,
    value: String(row.value),
    updated_at: new Date().toISOString(),
  }));
  const { error } = await supabase
    .from('system_config')
    .upsert(payload, { onConflict: 'key' });
  if (error) throw error;
}

async function saveGeneralSettings() {
  try {
    await _upsertSystemConfig({
      commission_rate: parseFloat(document.getElementById('settCommission')?.value) || 15,
      driver_min_wallet: parseInt(document.getElementById('settMinWallet')?.value, 10) || 0,
      promptpay_number: (document.getElementById('settPromptPay')?.value || '').trim() || null,
      max_delivery_radius: parseFloat(document.getElementById('settMaxRadius')?.value) || 30,
    });
    showToast('บันทึกค่าทั่วไปสำเร็จ', 'success');
  } catch (e) {
    console.error('saveGeneralSettings error:', e);
    showToast('บันทึกค่าทั่วไปไม่สำเร็จ: ' + (e.message || JSON.stringify(e)), 'error');
  }
}

async function saveDetectionRadiusSettings() {
  try {
    await _upsertSystemConfig({
      detection_radius_config: {
        driver_to_customer_km: parseFloat(document.getElementById('settRadiusDriverToCustomer')?.value) || 20,
        customer_to_driver_km: parseFloat(document.getElementById('settRadiusCustomerToDriver')?.value) || 30,
        customer_to_merchant_km: parseFloat(document.getElementById('settRadiusCustomerToMerchant')?.value) || 30,
        driver_to_order_km: parseFloat(document.getElementById('settRadiusDriverToOrder')?.value) || 20,
        parcel_driver_to_pickup_km: parseFloat(document.getElementById('settRadiusParcelDriverToPickup')?.value) || 30,
      },
    });
    showToast('บันทึกรัศมีตรวจจับสำเร็จ', 'success');
  } catch (e) {
    console.error('saveDetectionRadiusSettings error:', e);
    if (String(e.message || '').toLowerCase().includes('detection_radius_config')) {
      showToast('ยังไม่สามารถบันทึกรัศมีตรวจจับได้ กรุณารัน migration 20260308_add_detection_radius_config.sql', 'error');
      return;
    }
    showToast('บันทึกรัศมีตรวจจับไม่สำเร็จ: ' + (e.message || JSON.stringify(e)), 'error');
  }
}

async function saveTopupModeSettings() {
  try {
    await _upsertSystemConfig({
      topup_mode: document.querySelector('input[name="settTopupMode"]:checked')?.value || 'admin_approve',
    });
    showToast('บันทึกโหมดเติมเงินสำเร็จ', 'success');
  } catch (e) {
    console.error('saveTopupModeSettings error:', e);
    showToast('บันทึกโหมดเติมเงินไม่สำเร็จ: ' + (e.message || JSON.stringify(e)), 'error');
  }
}

async function saveServiceRatesSettings() {
  try {
    const merchantGp = (parseFloat(document.getElementById('settMerchantGP')?.value) || 10) / 100;
    const merchantGpSystem = (parseFloat(document.getElementById('settMerchantGpSystemRate')?.value) || 0) / 100;
    const merchantGpDriver = (parseFloat(document.getElementById('settMerchantGpDriverRate')?.value) || 0) / 100;
    const splitTotal = merchantGpSystem + merchantGpDriver;
    if (Math.abs(splitTotal - merchantGp) > 0.0001) {
      throw new Error(`Merchant GP รวมต้องเท่ากับ เข้าระบบ + ให้คนขับ (รวม ${(merchantGp * 100).toFixed(1)}%, split ${(splitTotal * 100).toFixed(1)}%)`);
    }

    await _upsertSystemConfig({
      platform_fee_rate: (parseFloat(document.getElementById('settPlatformFee')?.value) || 15) / 100,
      merchant_gp_rate: merchantGp,
    });

    await _upsertSystemConfigKeyValues([
      {
        key: 'merchant_gp_system_rate_default',
        value: merchantGpSystem.toFixed(4),
      },
      {
        key: 'merchant_gp_driver_rate_default',
        value: merchantGpDriver.toFixed(4),
      },
      {
        key: 'ride_far_pickup_threshold_km',
        value: (parseFloat(document.getElementById('settRideFarPickupThreshold')?.value) || 3).toFixed(2),
      },
      {
        key: 'ride_far_pickup_rate_per_km_motorcycle',
        value: (parseFloat(document.getElementById('settRideFarPickupMotoRate')?.value) || 5).toFixed(2),
      },
      {
        key: 'ride_far_pickup_rate_per_km_car',
        value: (parseFloat(document.getElementById('settRideFarPickupCarRate')?.value) || 7).toFixed(2),
      },
      {
        key: 'food_far_pickup_threshold_km_default',
        value: (parseFloat(document.getElementById('settFoodFarPickupThreshold')?.value) || 3).toFixed(2),
      },
      {
        key: 'food_far_pickup_rate_per_km_default',
        value: (parseFloat(document.getElementById('settFoodFarPickupRate')?.value) || 5).toFixed(2),
      },
    ]);

    const rateEls = document.querySelectorAll('[data-rate-type]');
    for (const el of rateEls) {
      const type = el.dataset.rateType;
      const bp = parseFloat(el.querySelector('.rate-base-price')?.value) || 0;
      const bd = parseFloat(el.querySelector('.rate-base-dist')?.value) || 0;
      const pk = parseFloat(el.querySelector('.rate-per-km')?.value) || 0;
      const { error: rateErr } = await supabase.from('service_rates')
        .update({ base_price: bp, base_distance: bd, price_per_km: pk })
        .eq('service_type', type);
      if (rateErr) throw rateErr;
    }

    showToast('บันทึกอัตราค่าบริการสำเร็จ', 'success');
  } catch (e) {
    console.error('saveServiceRatesSettings error:', e);
    showToast('บันทึกอัตราค่าบริการไม่สำเร็จ: ' + (e.message || JSON.stringify(e)), 'error');
  }
}

async function savePromoSettings() {
  try {
    await _upsertSystemConfig({
      promo_text: document.getElementById('settPromoText')?.value || 'ส่งฟรี! สั่งครบ ฿200',
      promo_enabled: document.getElementById('settPromoEnabled')?.checked || false,
    });
    showToast('บันทึกป้ายโปรโมชั่นสำเร็จ', 'success');
  } catch (e) {
    console.error('savePromoSettings error:', e);
    showToast('บันทึกป้ายโปรโมชั่นไม่สำเร็จ: ' + (e.message || JSON.stringify(e)), 'error');
  }
}

async function saveLandingSettings() {
  try {
    const landingConfig = normalizeLandingConfig({
      brand_name: document.getElementById('settLandingBrandName')?.value?.trim() || DEFAULT_LANDING_CONFIG.brand_name,
      badge_text: document.getElementById('settLandingBadgeText')?.value?.trim() || DEFAULT_LANDING_CONFIG.badge_text,
      hero_title: document.getElementById('settLandingHeroTitle')?.value?.trim() || DEFAULT_LANDING_CONFIG.hero_title,
      hero_subtitle: document.getElementById('settLandingHeroSubtitle')?.value?.trim() || DEFAULT_LANDING_CONFIG.hero_subtitle,
      play_store_url: document.getElementById('settLandingPlayStoreUrl')?.value?.trim() || DEFAULT_LANDING_CONFIG.play_store_url,
      app_store_url: document.getElementById('settLandingAppStoreUrl')?.value?.trim() || DEFAULT_LANDING_CONFIG.app_store_url,
      ride_icon: document.getElementById('settLandingRideIcon')?.value?.trim() || DEFAULT_LANDING_CONFIG.ride_icon,
      food_icon: document.getElementById('settLandingFoodIcon')?.value?.trim() || DEFAULT_LANDING_CONFIG.food_icon,
      parcel_icon: document.getElementById('settLandingParcelIcon')?.value?.trim() || DEFAULT_LANDING_CONFIG.parcel_icon,
      reviews_title: document.getElementById('settLandingReviewsTitle')?.value?.trim() || DEFAULT_LANDING_CONFIG.reviews_title,
      reviews_subtitle: document.getElementById('settLandingReviewsSubtitle')?.value?.trim() || DEFAULT_LANDING_CONFIG.reviews_subtitle,
      review_1_name: document.getElementById('settLandingReview1Name')?.value?.trim() || DEFAULT_LANDING_CONFIG.review_1_name,
      review_1_role: document.getElementById('settLandingReview1Role')?.value?.trim() || DEFAULT_LANDING_CONFIG.review_1_role,
      review_1_text: document.getElementById('settLandingReview1Text')?.value?.trim() || DEFAULT_LANDING_CONFIG.review_1_text,
      review_2_name: document.getElementById('settLandingReview2Name')?.value?.trim() || DEFAULT_LANDING_CONFIG.review_2_name,
      review_2_role: document.getElementById('settLandingReview2Role')?.value?.trim() || DEFAULT_LANDING_CONFIG.review_2_role,
      review_2_text: document.getElementById('settLandingReview2Text')?.value?.trim() || DEFAULT_LANDING_CONFIG.review_2_text,
      review_3_name: document.getElementById('settLandingReview3Name')?.value?.trim() || DEFAULT_LANDING_CONFIG.review_3_name,
      review_3_role: document.getElementById('settLandingReview3Role')?.value?.trim() || DEFAULT_LANDING_CONFIG.review_3_role,
      review_3_text: document.getElementById('settLandingReview3Text')?.value?.trim() || DEFAULT_LANDING_CONFIG.review_3_text,
      logo_url: document.getElementById('settLandingLogoUrl')?.value?.trim() || '',
      hero_image_url: document.getElementById('settLandingHeroImageUrl')?.value?.trim() || '',
    });

    await _upsertSystemConfig({ landing_config: landingConfig });
    showToast('บันทึก Landing Page สำเร็จ', 'success');
  } catch (e) {
    console.error('saveLandingSettings error:', e);
    if (String(e.message || '').toLowerCase().includes('landing_config')) {
      showToast('ยังไม่สามารถบันทึก Landing Page ได้ กรุณารัน migration 20260307_add_landing_page_config.sql', 'error');
      return;
    }
    showToast('บันทึก Landing Page ไม่สำเร็จ: ' + (e.message || JSON.stringify(e)), 'error');
  }
}

// ============================================
// Save Admin Email only
// ============================================
async function saveAdminEmail() {
  const adminEmail = document.getElementById('settAdminEmail')?.value?.trim();
  const adminEmailCC = document.getElementById('settAdminEmailCC')?.value?.trim();
  console.log('💾 Saving admin email:', { adminEmail, adminEmailCC });

  try {
    const { data: existing } = await supabase.from('system_config').select('id').maybeSingle();
    const configId = existing?.id ?? 1;

    const { data, error } = await supabase.from('system_config').upsert({
      id: configId,
      admin_notification_email: adminEmail || null,
      admin_notification_email_cc: adminEmailCC || null,
      updated_at: new Date().toISOString(),
    }, { onConflict: 'id' });

    console.log('💾 Save result:', { data, error });
    if (error) {
      console.error('Save email error:', error);
      showToast('บันทึกไม่สำเร็จ: ' + error.message + ' (อาจยังไม่ได้รัน migration เพิ่มคอลัมน์)', 'error');
      return;
    }
    showToast('บันทึกอีเมลสำเร็จ!', 'success');
  } catch (e) {
    console.error('Save email exception:', e);
    showToast('เกิดข้อผิดพลาด: ' + e.message, 'error');
  }
}

// ============================================
// Test Admin Email (via Edge Function)
// ============================================
async function testAdminEmail() {
  const email = document.getElementById('settAdminEmail')?.value?.trim();
  if (!email) { showToast('กรุณากรอกอีเมลหลักก่อน', 'error'); return; }

  showToast('กำลังส่งอีเมลทดสอบ...', 'info');
  try {
    const { data, error } = await supabase.functions.invoke('send-admin-email', {
      body: {
        to: email,
        subject: '🔔 ทดสอบแจ้งเตือน — Jedechai Delivery Admin',
        html: `<div style="font-family:sans-serif;max-width:500px;margin:0 auto;padding:20px;">
  <h2 style="color:#1565C0;">🔔 ทดสอบระบบแจ้งเตือน</h2>
  <div style="background:#f5f5f5;padding:16px;border-radius:12px;margin:16px 0;">
    <p>ถ้าคุณเห็นอีเมลนี้ แสดงว่าระบบแจ้งเตือนทางอีเมลทำงานปกติ ✅</p>
    <p style="color:#666;font-size:13px;">ส่งเมื่อ: ${new Date().toLocaleString('th-TH')}</p>
  </div>
  <hr style="border:none;border-top:1px solid #eee;margin:20px 0;">
  <p style="color:#999;font-size:12px;">Jedechai Delivery Admin System</p>
</div>`,
      },
    });
    if (error) throw error;
    console.log('📧 Edge Function response:', JSON.stringify(data));
    if (data?.provider === 'queue') {
      showToast('⚠️ ยังไม่ได้ตั้ง RESEND_API_KEY ใน Edge Function — อีเมลถูก queue ไว้แต่ไม่ได้ส่งจริง', 'error');
      return;
    }
    if (data?.data?.statusCode && data.data.statusCode >= 400) {
      showToast('⚠️ Resend API error: ' + (data.data.message || JSON.stringify(data.data)), 'error');
      return;
    }
    showToast('ส่งอีเมลทดสอบสำเร็จ! ตรวจสอบกล่องจดหมายของคุณ (provider: ' + (data?.provider || 'unknown') + ')', 'success');
  } catch (e) {
    console.error('Test email error:', e);
    showToast('ส่งอีเมลไม่สำเร็จ: ' + (e.message || 'ตรวจสอบ Edge Function'), 'error');
  }
}

// ============================================
// Revenue Page
// ============================================
async function renderRevenue(el) {
  const today = new Date();
  const monthAgo = new Date(today); monthAgo.setDate(monthAgo.getDate() - 30);

  const { data: drivers } = await supabase
    .from('profiles')
    .select('id, full_name, phone_number')
    .eq('role', 'driver')
    .order('full_name');

  window._revenueDrivers = drivers || [];

  el.innerHTML = `
    <div class="fade-in space-y-5">
      <div class="glass-card p-4 flex flex-wrap gap-3 items-center">
        <span class="material-icons-round text-indigo-400 text-lg">date_range</span>
        <input type="date" id="revDateFrom" value="${monthAgo.toISOString().split('T')[0]}" class="border border-gray-200 rounded-xl px-3.5 py-2 text-sm bg-gray-50/50 transition-all" />
        <span class="text-gray-300 text-sm font-medium">ถึง</span>
        <input type="date" id="revDateTo" value="${today.toISOString().split('T')[0]}" class="border border-gray-200 rounded-xl px-3.5 py-2 text-sm bg-gray-50/50 transition-all" />
        <select id="revWalletDriver" class="border border-gray-200 rounded-xl px-3.5 py-2 text-sm bg-gray-50/50 transition-all min-w-[260px]">
          <option value="">คนขับทั้งหมด</option>
          ${(drivers || []).map(d => `<option value="${d.id}">${d.full_name || 'ไม่ระบุชื่อ'}${d.phone_number ? ' (' + d.phone_number + ')' : ''}</option>`).join('')}
        </select>
        <button onclick="loadRevenue()" class="text-white px-5 py-2 rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">กรอง</button>
        <button onclick="exportRevenueCsv()" class="px-4 py-2 rounded-xl text-sm font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100 transition-colors">Export CSV</button>
        <button onclick="exportRevenueExcel()" class="px-4 py-2 rounded-xl text-sm font-semibold bg-cyan-50 text-cyan-700 border border-cyan-200 hover:bg-cyan-100 transition-colors">Export Excel</button>
      </div>
      <div id="revenueContent"><div class="flex justify-center py-10"><div class="loader"></div></div></div>
    </div>`;
  await loadRevenue();
}

async function loadRevenue() {
  const from = document.getElementById('revDateFrom')?.value;
  const to = document.getElementById('revDateTo')?.value;
  const selectedDriverId = document.getElementById('revWalletDriver')?.value || '';
  const startDate = from ? new Date(from + 'T00:00:00').toISOString() : new Date(new Date().setDate(new Date().getDate()-30)).toISOString();
  const endDate = to ? new Date(to + 'T23:59:59').toISOString() : new Date().toISOString();

  const rc = document.getElementById('revenueContent');
  if (!rc) return;
  rc.innerHTML = '<div class="flex justify-center py-10"><div class="loader"></div></div>';

  const driverList = window._revenueDrivers || [];
  const scopedDriverIds = selectedDriverId
    ? [selectedDriverId]
    : driverList.map(d => d.id);

  // Fetch bookings + wallet transactions (commission = platform income)
  let walletsRes = { data: [] };
  let walletTxRes = { data: [] };
  let topupRes = { data: [] };
  let withdrawalRes = { data: [] };

  const [bookingsRes, commissionRes, configRes] = await Promise.all([
    supabase.from('bookings').select('price, delivery_fee, service_type, status, created_at')
      .gte('created_at', startDate).lte('created_at', endDate).eq('status', 'completed'),
    supabase.from('wallet_transactions').select('amount, type, created_at')
      .gte('created_at', startDate).lte('created_at', endDate).eq('type', 'commission'),
    supabase.from('system_config').select('platform_fee_rate, merchant_gp_rate, commission_rate').maybeSingle(),
  ]);

  if (scopedDriverIds.length) {
    walletsRes = await supabase
      .from('wallets')
      .select('id, user_id, balance')
      .in('user_id', scopedDriverIds);

    const walletIds = (walletsRes.data || []).map(w => w.id).filter(Boolean);
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
  const mgRate = config.merchant_gp_rate || 0.10;
  const cmRate = config.commission_rate || 15;

  const byType = { food: { count: 0, revenue: 0, platformFee: 0 }, ride: { count: 0, revenue: 0, platformFee: 0 }, parcel: { count: 0, revenue: 0, platformFee: 0 } };
  let totalRevenue = 0;
  let totalPlatformIncome = 0;

  items.forEach(b => {
    const type = b.service_type || 'other';
    const amt = (b.price || 0) + (b.delivery_fee || 0);
    totalRevenue += amt;
    // Estimate platform income
    let pf = 0;
    if (type === 'food') {
      pf = (b.delivery_fee || 0) * pfRate + (b.price || 0) * mgRate;
    } else {
      pf = (b.price || 0) * (cmRate / 100);
    }
    totalPlatformIncome += pf;
    if (byType[type]) { byType[type].count++; byType[type].revenue += amt; byType[type].platformFee += pf; }
  });

  // Actual commission from wallet (if available)
  const actualCommission = commissions.reduce((s, c) => s + Math.abs(c.amount || 0), 0);
  const platformIncome = actualCommission > 0 ? actualCommission : totalPlatformIncome;

  // Group by date
  const byDate = {};
  items.forEach(b => {
    const d = new Date(b.created_at).toISOString().split('T')[0];
    if (!byDate[d]) byDate[d] = { total: 0, count: 0 };
    byDate[d].total += (b.price || 0) + (b.delivery_fee || 0);
    byDate[d].count++;
  });
  const sortedDates = Object.keys(byDate).sort().reverse();
  const revenueTypeChartRows = [
    { label: 'อาหาร', value: byType.food.revenue, displayValue: '฿' + fmt(Math.round(byType.food.revenue)) },
    { label: 'เรียกรถ', value: byType.ride.revenue, displayValue: '฿' + fmt(Math.round(byType.ride.revenue)) },
    { label: 'พัสดุ', value: byType.parcel.revenue, displayValue: '฿' + fmt(Math.round(byType.parcel.revenue)) },
  ];

  const driverMap = new Map(driverList.map(d => [d.id, d]));
  const walletByUser = new Map();
  wallets.forEach(w => {
    walletByUser.set(w.user_id, (walletByUser.get(w.user_id) || 0) + Number(w.balance || 0));
  });

  const walletIdToUser = new Map();
  wallets.forEach(w => walletIdToUser.set(w.id, w.user_id));

  const perDriver = new Map();
  scopedDriverIds.forEach(userId => {
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

  walletDeductions.forEach(tx => {
    const userId = walletIdToUser.get(tx.wallet_id);
    if (!userId || !perDriver.has(userId)) return;
    perDriver.get(userId).deducted += Math.abs(Number(tx.amount || 0));
  });

  topups.forEach(t => {
    if (!perDriver.has(t.user_id)) return;
    perDriver.get(t.user_id).topup += Number(t.amount || 0);
  });

  withdrawals.forEach(w => {
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
  window._revenueExportRows = walletRows.map((row) => ({
    คนขับ: row.name,
    เบอร์โทร: row.phone,
    เครดิตคงเหลือ: Math.round(row.balance),
    หักแล้ว: Math.round(row.deducted),
    เติมทั้งหมด: Math.round(row.topup),
    ถอนทั้งหมด: Math.round(row.withdraw),
  }));

  rc.innerHTML = `
    <!-- Summary Cards -->
    <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-5">
      ${statCard('payments', 'ยอดรวมทั้งหมด', '฿' + fmt(Math.round(totalRevenue)), 'bg-green-500')}
      ${statCard('account_balance', 'รายได้ค่าบริการ', '฿' + fmt(Math.round(platformIncome)), 'bg-blue-500')}
      ${statCard('restaurant', 'อาหาร', '฿' + fmt(Math.round(byType.food.revenue)) + ' (' + byType.food.count + ')', 'bg-orange-500')}
      ${statCard('local_taxi', 'เรียกรถ+พัสดุ', '฿' + fmt(Math.round(byType.ride.revenue + byType.parcel.revenue)) + ' (' + (byType.ride.count + byType.parcel.count) + ')', 'bg-purple-500')}
    </div>

    <div class="grid grid-cols-1 lg:grid-cols-2 gap-5 mt-6">
      ${renderMiniBarChart('สรุปรายได้ตามบริการ', `${from || '-'} ถึง ${to || '-'}`, revenueTypeChartRows, '#10b981')}
      ${renderMiniBarChart('สรุปกระเป๋าคนขับ', `${selectedDriverId ? 'รายบุคคล' : 'ทุกคนขับ'}`, walletChartRows, '#06b6d4')}
    </div>

    <!-- Wallet Credit Summary -->
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
              : walletRows.map(row => `
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
              `).join('')}
          </tbody>
        </table>
      </div>
    </div>

    <!-- Platform Income Breakdown -->
    <div class="glass-card p-6 mt-6">
      <div class="flex items-center gap-3 mb-5">
        <div class="w-10 h-10 bg-blue-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-blue-500">analytics</span></div>
        <div>
          <h3 class="font-bold text-gray-800">รายละเอียดค่าบริการระบบ</h3>
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
          <p class="text-xs text-orange-400 mt-1">Platform Fee ${(pfRate*100).toFixed(0)}% + GP ${(mgRate*100).toFixed(0)}%</p>
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

    <!-- Daily Revenue Table -->
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
            ${sortedDates.length === 0 ? '<tr><td colspan="4" class="px-5 py-8 text-center text-gray-400">ไม่มีข้อมูลในช่วงนี้</td></tr>' :
            sortedDates.map(d => {
              const maxRev = Math.max(...Object.values(byDate).map(v=>v.total), 1);
              const pct = Math.round((byDate[d].total / maxRev) * 100);
              return `<tr class="table-row">
                <td class="px-5 py-3.5 font-medium text-gray-700">${new Date(d).toLocaleDateString('th-TH', {day:'numeric',month:'short',year:'numeric'})}</td>
                <td class="px-5 py-3.5 text-right text-gray-400">${byDate[d].count} รายการ</td>
                <td class="px-5 py-3.5 text-right font-bold text-emerald-600">฿${fmt(Math.round(byDate[d].total))}</td>
                <td class="px-5 py-3.5"><div class="h-4 bg-gray-100 rounded-full overflow-hidden"><div class="h-full rounded-full transition-all" style="width:${pct}%;background:linear-gradient(90deg,#10b981,#14b8a6);"></div></div></td>
              </tr>`;
            }).join('')}
          </tbody>
        </table>
      </div>
    </div>
  `;
}

function exportRevenueCsv() {
  const from = document.getElementById('revDateFrom')?.value || '';
  const to = document.getElementById('revDateTo')?.value || '';
  const rows = window._revenueExportRows || [];
  exportRowsToCsv(reportFilename('revenue_wallet_report', 'csv', from, to), ['คนขับ', 'เบอร์โทร', 'เครดิตคงเหลือ', 'หักแล้ว', 'เติมทั้งหมด', 'ถอนทั้งหมด'], rows);
}

function exportRevenueExcel() {
  const from = document.getElementById('revDateFrom')?.value || '';
  const to = document.getElementById('revDateTo')?.value || '';
  const rows = window._revenueExportRows || [];
  exportRowsToExcel(reportFilename('revenue_wallet_report', 'xls', from, to), ['คนขับ', 'เบอร์โทร', 'เครดิตคงเหลือ', 'หักแล้ว', 'เติมทั้งหมด', 'ถอนทั้งหมด'], rows);
}

// ============================================
// Menu Management Page
// ============================================
async function renderMenus(el) {
  const { data: merchants } = await supabase.from('profiles').select('id, full_name, shop_address').eq('role', 'merchant').eq('approval_status', 'approved').order('full_name');

  const preselected = window._selectedMerchantId || '';
  el.innerHTML = `
    <div class="fade-in space-y-5">
      <div class="glass-card p-4 flex flex-wrap gap-3 items-center">
        <span class="material-icons-round text-indigo-400 text-lg">store</span>
        <select id="menuMerchantSelect" onchange="loadMerchantMenus()" class="border border-gray-200 rounded-xl px-3.5 py-2 text-sm flex-1 max-w-md bg-gray-50/50 transition-all">
          <option value="">-- เลือกร้านค้า --</option>
          ${(merchants || []).map(m => `<option value="${m.id}" ${m.id===preselected?'selected':''}>${m.full_name}${m.shop_address ? ' — '+m.shop_address : ''}</option>`).join('')}
        </select>
        <div class="relative min-w-[260px]">
          <span class="material-icons-round text-gray-400 text-sm absolute left-3 top-1/2 -translate-y-1/2">search</span>
          <input type="text" id="menuSearch" placeholder="ค้นหาเมนู, หมวดหมู่" class="w-full pl-9 pr-3 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50" oninput="filterMerchantMenus()">
        </div>
        <button onclick="showAddMenuForm()" class="px-5 py-2 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200 flex items-center gap-1.5" style="background:linear-gradient(135deg,#6366f1,#818cf8);"><span class="material-icons-round text-sm">add</span> เพิ่มเมนู</button>
      </div>
      <div id="menuFormContainer"></div>
      <div id="menuListContainer"><p class="text-gray-400 text-center py-10">กรุณาเลือกร้านค้า</p></div>
    </div>  `;
  window._selectedMerchantId = '';
  window._allMerchantMenus = [];
  if (preselected) { document.getElementById('menuMerchantSelect').value = preselected; loadMerchantMenus(); }
}

const MENU_CATEGORIES = ['อาหารตามสั่ง','ก๋วยเตี๋ยว','เครื่องดื่ม','ของหวาน','ฟาสต์ฟู้ด','อาหารเช้า','อาหารญี่ปุ่น','อาหารอีสาน','ของทานเล่น','อื่นๆ'];
function categoryDropdownHtml(id, selected) {
  return `<select id="${id}" class="w-full border rounded-lg px-3 py-2 text-sm">${MENU_CATEGORIES.map(c => `<option value="${c}" ${c===selected?'selected':''}>${c}</option>`).join('')}</select>`;
}

async function loadMerchantMenus() {
  const merchantId = document.getElementById('menuMerchantSelect')?.value;
  const mc = document.getElementById('menuListContainer');
  if (!merchantId || !mc) { if(mc) mc.innerHTML = '<p class="text-gray-400 text-center py-10">กรุณาเลือกร้านค้า</p>'; return; }

  mc.innerHTML = '<div class="flex justify-center py-10"><div class="loader"></div></div>';
  const { data: menus } = await supabase.from('menu_items').select('*').eq('merchant_id', merchantId).order('category').order('name');
  window._allMerchantMenus = menus || [];

  mc.innerHTML = `
    <div class="glass-card overflow-hidden">
      <div class="px-6 py-4 flex items-center gap-3">
        <div class="w-8 h-8 bg-orange-50 rounded-lg flex items-center justify-center"><span class="material-icons-round text-orange-500 text-sm">restaurant_menu</span></div>
        <span class="font-bold text-gray-800">เมนูทั้งหมด (${(menus||[]).length})</span>
      </div>
      <div class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead><tr class="bg-gray-50/80">
            <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">รูป</th>
            <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ชื่อเมนู</th>
            <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">หมวดหมู่</th>
            <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ราคา</th>
            <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">สถานะ</th>
            <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">จัดการ</th>
          </tr></thead>
          <tbody id="menuTableBody">
            ${renderMenuRows(window._allMerchantMenus)}
          </tbody>
        </table>
      </div>
    </div>`;

  filterMerchantMenus();
}

function renderMenuRows(menus) {
  if (!(menus || []).length) {
    return '<tr><td colspan="6" class="px-4 py-8 text-center text-gray-400">ไม่มีเมนู</td></tr>';
  }

  return (menus || []).map(m => `
    <tr class="table-row border-b border-gray-50">
      <td class="px-4 py-3">${m.image_url ? `<img src="${m.image_url}" class="w-10 h-10 rounded-lg object-cover" />` : '<div class="w-10 h-10 bg-gray-100 rounded-lg flex items-center justify-center"><span class="material-icons-round text-gray-400 text-sm">image</span></div>'}</td>
      <td class="px-4 py-3 font-medium">${m.name || '-'}</td>
      <td class="px-4 py-3 text-gray-500">${m.category || '-'}</td>
      <td class="px-4 py-3 font-semibold">฿${fmt(m.price)}</td>
      <td class="px-4 py-3">${m.is_available !== false ? '<span class="text-green-600 text-xs font-semibold">พร้อมขาย</span>' : '<span class="text-gray-400 text-xs">ปิดขาย</span>'}</td>
      <td class="px-4 py-3 whitespace-nowrap">
        <button onclick="editMenuItem('${m.id}')" class="px-3 py-1 bg-blue-500 text-white rounded-lg text-xs font-medium hover:bg-blue-600 mr-1">แก้ไข</button>
        <button onclick="deleteMenuItem('${m.id}','${(m.name||'').replace(/'/g,'')}')" class="px-3 py-1 bg-red-100 text-red-600 rounded-lg text-xs font-medium hover:bg-red-200">ลบ</button>
      </td>
    </tr>
  `).join('');
}

function filterMerchantMenus() {
  const body = document.getElementById('menuTableBody');
  if (!body) return;

  const search = (document.getElementById('menuSearch')?.value || '').toLowerCase();
  let filtered = window._allMerchantMenus || [];
  if (search) {
    filtered = filtered.filter(m =>
      (m.name || '').toLowerCase().includes(search) ||
      (m.category || '').toLowerCase().includes(search) ||
      (m.description || '').toLowerCase().includes(search),
    );
  }
  body.innerHTML = renderMenuRows(filtered);
}

window._addMenuSelectedGroups = [];

async function showAddMenuForm() {
  const merchantId = document.getElementById('menuMerchantSelect')?.value;
  if (!merchantId) return alert('กรุณาเลือกร้านค้าก่อน');
  window._addMenuSelectedGroups = [];
  const c = document.getElementById('menuFormContainer');
  c.innerHTML = `
    <div class="glass-card p-6">
      <h4 class="font-bold text-gray-800 mb-4">เพิ่มเมนูใหม่</h4>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div><label class="block text-sm font-medium mb-1">ชื่อเมนู</label><input id="addMenuName" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
        <div><label class="block text-sm font-medium mb-1">หมวดหมู่</label>${categoryDropdownHtml('addMenuCat','อาหารตามสั่ง')}</div>
        <div><label class="block text-sm font-medium mb-1">ราคา (฿)</label><input id="addMenuPrice" type="number" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
        <div class="md:col-span-2"><label class="block text-sm font-medium mb-1">รายละเอียด</label><input id="addMenuDesc" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
        <div><label class="block text-sm font-medium mb-1">URL รูปภาพ</label><input id="addMenuImg" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="วาง URL หรืออัพโหลดไฟล์ด้านล่าง" /></div>
        <div>
          <label class="block text-sm font-medium mb-1">อัพโหลดรูปภาพ</label>
          <input type="file" id="addMenuFile" accept="image/*" class="w-full border rounded-lg px-3 py-1.5 text-sm file:mr-2 file:py-1 file:px-3 file:rounded-lg file:border-0 file:text-sm file:bg-indigo-100 file:text-indigo-700 hover:file:bg-indigo-200" onchange="previewMenuImage(this,'addMenuPreview')" />
          <div id="addMenuPreview" class="mt-2"></div>
        </div>
      </div>

      <!-- Option Groups for new menu -->
      <div class="mt-4 border rounded-xl p-4">
        <div class="flex items-center justify-between mb-3">
          <h5 class="font-bold text-gray-700 text-sm flex items-center gap-2"><span class="material-icons-round text-sm">tune</span> ตัวเลือกเมนู</h5>
          <button onclick="showAddMenuOptionGroupPicker('${merchantId}')" class="px-3 py-1 bg-green-500 text-white rounded-lg text-xs font-medium hover:bg-green-600 flex items-center gap-1"><span class="material-icons-round text-xs">add</span> เพิ่มตัวเลือก</button>
        </div>
        <div id="addMenuOptionGroupsList"><p class="text-gray-400 text-sm py-2">ยังไม่มีตัวเลือก</p></div>
      </div>

      <div class="mt-4 flex gap-2">
        <button onclick="submitAddMenu('${merchantId}')" class="px-5 py-2 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">บันทึก</button>
        <button onclick="document.getElementById('menuFormContainer').innerHTML=''" class="px-4 py-2 bg-gray-100 text-gray-600 rounded-lg text-sm font-medium hover:bg-gray-200">ยกเลิก</button>
      </div>
    </div>`;
}

async function showAddMenuOptionGroupPicker(merchantId) {
  const { data: groups } = await supabase.from('menu_option_groups').select('*, menu_options(*)').eq('merchant_id', merchantId).order('name');
  const selectedIds = new Set(window._addMenuSelectedGroups.map(g => g.id));

  let groupsHtml = '';
  if (!groups || groups.length === 0) {
    groupsHtml = '<p class="text-gray-400 text-sm">ยังไม่มีกลุ่มตัวเลือก</p>';
  } else {
    groupsHtml = groups.map(g => {
      const isSel = selectedIds.has(g.id);
      const safeName = (g.name || '').replace(/'/g, '');
      const optionsHtml = (g.menu_options || []).length > 0
        ? '<div class="mt-1 flex flex-wrap gap-1">' + (g.menu_options || []).map(o => '<span class="px-1.5 py-0.5 bg-gray-100 rounded text-xs">' + o.name + (o.price > 0 ? ' +฿' + o.price : '') + '</span>').join('') + '</div>'
        : '';
      const toggleBtn = isSel
        ? '<button onclick="toggleAddMenuGroup(\'' + g.id + '\',false,\'' + merchantId + '\')" class="px-3 py-1 bg-red-100 text-red-600 rounded-lg text-xs font-medium hover:bg-red-200">เอาออก</button>'
        : '<button onclick="toggleAddMenuGroup(\'' + g.id + '\',true,\'' + merchantId + '\')" class="px-3 py-1 bg-green-500 text-white rounded-lg text-xs font-medium hover:bg-green-600">เพิ่ม</button>';
      return '<div class="border rounded-lg p-3 mb-2 ' + (isSel ? 'bg-green-50 border-green-200' : '') + '">'
        + '<div class="flex items-center justify-between"><div>'
        + '<span class="font-medium text-sm">' + g.name + '</span>'
        + '<span class="text-xs text-gray-500 ml-2">(' + g.min_selection + '-' + g.max_selection + ')</span>'
        + optionsHtml
        + '</div><div class="flex items-center gap-2">'
        + '<button onclick="showManageOptionsModalStandalone(\'' + g.id + '\',\'' + safeName + '\',\'' + merchantId + '\')" class="px-2 py-1 bg-gray-100 text-gray-600 rounded text-xs hover:bg-gray-200">จัดการตัวเลือก</button>'
        + '<button onclick="deleteOptionGroup(\'' + g.id + '\',\'' + merchantId + '\')" class="px-2 py-1 bg-red-100 text-red-600 rounded text-xs hover:bg-red-200">ลบกลุ่ม</button>'
        + toggleBtn
        + '</div></div></div>';
    }).join('');
  }

  const modal = document.createElement('div');
  modal.id = 'addMenuOptionGroupPickerModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-2xl mx-4 fade-in max-h-[80vh] flex flex-col">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <h3 class="font-bold text-gray-800 text-lg">เลือกกลุ่มตัวเลือก</h3>
        <button onclick="document.getElementById('addMenuOptionGroupPickerModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-6 overflow-y-auto flex-1">
        <div class="bg-blue-50 rounded-xl p-4 mb-4">
          <h4 class="font-bold text-sm text-blue-800 mb-3">สร้างกลุ่มตัวเลือกใหม่</h4>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
            <div><input id="newAddGroupName" placeholder="ชื่อกลุ่ม เช่น ระดับความเผ็ด" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
            <div class="flex gap-2">
              <input id="newAddGroupMin" type="number" value="0" min="0" placeholder="ขั้นต่ำ" class="w-full border rounded-lg px-3 py-2 text-sm" />
              <input id="newAddGroupMax" type="number" value="1" min="1" placeholder="สูงสุด" class="w-full border rounded-lg px-3 py-2 text-sm" />
            </div>
            <div><button onclick="createOptionGroupForAddMenu('${merchantId}')" class="w-full px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">สร้าง</button></div>
          </div>
        </div>
        <h4 class="font-bold text-sm text-gray-700 mb-2">กลุ่มตัวเลือกที่มีอยู่</h4>
        ${groupsHtml}
      </div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });
}

async function createOptionGroupForAddMenu(merchantId) {
  const name = document.getElementById('newAddGroupName')?.value?.trim();
  const min = parseInt(document.getElementById('newAddGroupMin')?.value) || 0;
  const max = parseInt(document.getElementById('newAddGroupMax')?.value) || 1;
  if (!name) return alert('กรุณากรอกชื่อกลุ่ม');
  try {
    const { data: grp } = await supabase.from('menu_option_groups').insert({ merchant_id: merchantId, name, min_selection: min, max_selection: max }).select().single();
    if (grp) window._addMenuSelectedGroups.push(grp);
    document.getElementById('addMenuOptionGroupPickerModal')?.remove();
    showAddMenuOptionGroupPicker(merchantId);
    renderAddMenuOptionGroups();
    showToast('สร้างกลุ่มตัวเลือกสำเร็จ!', 'success');
  } catch(e) { showToast('เกิดข้อผิดพลาด: ' + e.message, 'error'); }
}

function toggleAddMenuGroup(groupId, add, merchantId) {
  if (add) {
    if (!window._addMenuSelectedGroups.find(g => g.id === groupId)) {
      window._addMenuSelectedGroups.push({ id: groupId });
    }
  } else {
    window._addMenuSelectedGroups = window._addMenuSelectedGroups.filter(g => g.id !== groupId);
  }
  document.getElementById('addMenuOptionGroupPickerModal')?.remove();
  showAddMenuOptionGroupPicker(merchantId);
  renderAddMenuOptionGroups();
}

function renderAddMenuOptionGroups() {
  const el = document.getElementById('addMenuOptionGroupsList');
  if (!el) return;
  if (window._addMenuSelectedGroups.length === 0) {
    el.innerHTML = '<p class="text-gray-400 text-sm py-2">ยังไม่มีตัวเลือก</p>';
    return;
  }
  el.innerHTML = window._addMenuSelectedGroups.map(g => `
    <div class="border rounded-lg p-2 mb-1 flex items-center justify-between bg-green-50 border-green-200">
      <span class="text-sm font-medium">${g.name || g.id.substring(0,8)}</span>
      <button onclick="window._addMenuSelectedGroups=window._addMenuSelectedGroups.filter(x=>x.id!=='${g.id}');renderAddMenuOptionGroups();" class="text-xs text-red-500 hover:underline">ลบออก</button>
    </div>`).join('');
}

async function showManageOptionsModalStandalone(groupId, groupName, merchantId) {
  const { data: options } = await supabase.from('menu_options').select('*').eq('group_id', groupId).order('name');
  
  let optionsHtml = '';
  if (!options || options.length === 0) {
    optionsHtml = '<p class="text-gray-400 text-sm">ยังไม่มีตัวเลือก</p>';
  } else {
    optionsHtml = options.map(o => {
      const priceHtml = o.price > 0 ? '<span class="text-xs text-green-600 font-semibold">+฿' + o.price + '</span>' : '';
      return '<div class="flex items-center justify-between py-2 border-b border-gray-50">'
        + '<div class="flex items-center gap-3">'
        + '<span class="text-sm font-medium ' + (o.is_available ? '' : 'line-through text-gray-400') + '">' + o.name + '</span>'
        + priceHtml
        + '</div>'
        + '<div class="flex items-center gap-2">'
        + '<button onclick="toggleOptSA(\'' + o.id + '\',' + !o.is_available + ',\'' + groupId + '\',\'' + groupName + '\',\'' + merchantId + '\')" class="text-xs ' + (o.is_available ? 'text-orange-500' : 'text-green-500') + ' hover:underline">' + (o.is_available ? 'ปิด' : 'เปิด') + '</button>'
        + '<button onclick="deleteOptSA(\'' + o.id + '\',\'' + groupId + '\',\'' + groupName + '\',\'' + merchantId + '\')" class="text-xs text-red-500 hover:underline">ลบ</button>'
        + '</div></div>';
    }).join('');
  }

  const modal = document.createElement('div');
  modal.id = 'manageOptionsStandaloneModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-[60]';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 fade-in">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <h3 class="font-bold text-gray-800">ตัวเลือกใน "${groupName}"</h3>
        <button onclick="document.getElementById('manageOptionsStandaloneModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-6">
        <div class="flex gap-2 mb-4">
          <input id="newOptNameSA" placeholder="ชื่อตัวเลือก" class="flex-1 border rounded-lg px-3 py-2 text-sm" />
          <input id="newOptPriceSA" type="number" value="0" placeholder="ราคาเพิ่ม" class="w-24 border rounded-lg px-3 py-2 text-sm" />
          <button onclick="addMenuOptionStandalone('${groupId}','${groupName}','${merchantId}')" class="px-4 py-2 bg-green-500 text-white rounded-lg text-sm font-medium hover:bg-green-600">เพิ่ม</button>
        </div>
        <div>${optionsHtml}</div>
      </div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });
}

async function addMenuOptionStandalone(groupId, groupName, merchantId) {
  const name = document.getElementById('newOptNameSA')?.value?.trim();
  const price = parseInt(document.getElementById('newOptPriceSA')?.value) || 0;
  if (!name) return alert('กรุณากรอกชื่อตัวเลือก');
  try {
    await supabase.from('menu_options').insert({ group_id: groupId, name, price, is_available: true });
    document.getElementById('manageOptionsStandaloneModal')?.remove();
    showManageOptionsModalStandalone(groupId, groupName, merchantId);
  } catch(e) { showToast('เกิดข้อผิดพลาด: ' + e.message, 'error'); }
}

async function toggleOptSA(optionId, newState, groupId, groupName, merchantId) {
  const { error } = await supabase.from('menu_options').update({ is_available: newState }).eq('id', optionId);
  if (error) return showToast('เกิดข้อผิดพลาด: ' + error.message, 'error');
  document.getElementById('manageOptionsStandaloneModal')?.remove();
  showManageOptionsModalStandalone(groupId, groupName, merchantId);
}

async function deleteOptSA(optionId, groupId, groupName, merchantId) {
  if (!confirm('ลบตัวเลือกนี้?')) return;
  await supabase.from('menu_options').delete().eq('id', optionId);
  document.getElementById('manageOptionsStandaloneModal')?.remove();
  showManageOptionsModalStandalone(groupId, groupName, merchantId);
}

async function deleteOptionGroup(groupId, merchantId) {
  if (!confirm('ลบกลุ่มตัวเลือกนี้ทั้งหมด? (รวมตัวเลือกทั้งหมดในกลุ่ม)')) return;
  try {
    await supabase.from('menu_options').delete().eq('group_id', groupId);
    await supabase.from('menu_item_option_links').delete().eq('option_group_id', groupId);
    await supabase.from('menu_option_groups').delete().eq('id', groupId);
    window._addMenuSelectedGroups = window._addMenuSelectedGroups.filter(g => g.id !== groupId);
    renderAddMenuOptionGroups();
    document.getElementById('addMenuOptionGroupPickerModal')?.remove();
    showAddMenuOptionGroupPicker(merchantId);
    showToast('ลบกลุ่มตัวเลือกสำเร็จ', 'success');
  } catch(e) { showToast('เกิดข้อผิดพลาด: ' + e.message, 'error'); }
}

function previewMenuImage(input, previewId) {
  const preview = document.getElementById(previewId);
  if (!preview) return;
  if (input.files && input.files[0]) {
    const reader = new FileReader();
    reader.onload = (e) => {
      preview.innerHTML = `<img src="${e.target.result}" class="w-16 h-16 rounded-lg object-cover border" />`;
    };
    reader.readAsDataURL(input.files[0]);
  } else {
    preview.innerHTML = '';
  }
}

async function uploadMenuImage(file, merchantId) {
  const ext = file.name.split('.').pop();
  const fileName = `menu_${merchantId}_${Date.now()}.${ext}`;
  
  // Try menu-images bucket first, then admin-uploads as fallback
  const buckets = ['menu-images', 'admin-uploads'];
  
  for (const bucket of buckets) {
    const filePath = bucket === 'menu-images' ? fileName : `menu-images/${fileName}`;
    const { data, error } = await supabase.storage.from(bucket).upload(filePath, file, { cacheControl: '3600', upsert: true });
    if (!error) {
      const { data: urlData } = supabase.storage.from(bucket).getPublicUrl(filePath);
      console.log(`✅ Menu image uploaded to ${bucket}/${filePath}`);
      return urlData.publicUrl;
    }
    console.warn(`⚠️ Upload to ${bucket} failed:`, error.message);
  }
  
  // Both buckets failed - try creating menu-images bucket
  try {
    console.log('🔧 Attempting to create menu-images bucket...');
    await supabase.storage.createBucket('menu-images', { public: true, fileSizeLimit: 5242880, allowedMimeTypes: ['image/jpeg','image/png','image/webp','image/gif'] });
    const { data, error } = await supabase.storage.from('menu-images').upload(fileName, file, { cacheControl: '3600', upsert: true });
    if (error) throw error;
    const { data: urlData } = supabase.storage.from('menu-images').getPublicUrl(fileName);
    return urlData.publicUrl;
  } catch(e) {
    console.error('❌ All upload attempts failed:', e);
    throw new Error('อัพโหลดรูปไม่สำเร็จ — กรุณาสร้าง Storage Bucket "menu-images" ใน Supabase Dashboard > Storage ก่อน (ตั้งเป็น Public)');
  }
}

async function submitAddMenu(merchantId) {
  try {
    let imageUrl = document.getElementById('addMenuImg').value;
    const fileInput = document.getElementById('addMenuFile');
    if (fileInput?.files?.length) {
      imageUrl = await uploadMenuImage(fileInput.files[0], merchantId);
    }
    const { data: newItem } = await supabase.from('menu_items').insert({
      merchant_id: merchantId,
      name: document.getElementById('addMenuName').value,
      category: document.getElementById('addMenuCat').value,
      price: parseFloat(document.getElementById('addMenuPrice').value) || 0,
      description: document.getElementById('addMenuDesc').value,
      image_url: imageUrl,
      is_available: true,
    }).select().single();

    // Link selected option groups
    if (newItem && window._addMenuSelectedGroups.length > 0) {
      for (let i = 0; i < window._addMenuSelectedGroups.length; i++) {
        const g = window._addMenuSelectedGroups[i];
        await supabase.from('menu_item_option_links').insert({
          menu_item_id: newItem.id,
          option_group_id: g.id,
          sort_order: i,
        });
      }
    }

    document.getElementById('menuFormContainer').innerHTML = '';
    showToast('เพิ่มเมนูสำเร็จ!', 'success');
    loadMerchantMenus();
  } catch(e) { showToast('เกิดข้อผิดพลาด: ' + e.message, 'error'); }
}

async function editMenuItem(id) {
  const { data: m } = await supabase.from('menu_items').select('*').eq('id', id).single();
  if (!m) return;

  // Fetch linked option groups for this menu item
  let linkedGroups = [];
  try {
    const { data: links } = await supabase.from('menu_item_option_links').select('option_group_id, sort_order, menu_option_groups(id, name, min_selection, max_selection, menu_options(id, name, price, is_available))').eq('menu_item_id', id).order('sort_order');
    linkedGroups = (links || []).map(l => l.menu_option_groups).filter(Boolean);
  } catch(e) { console.warn('Error loading option groups:', e); }

  // Remove existing modal if any
  document.getElementById('editMenuModal')?.remove();

  const modal = document.createElement('div');
  modal.id = 'editMenuModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-2xl mx-4 fade-in max-h-[90vh] flex flex-col">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <div>
          <h3 class="font-bold text-gray-800 text-lg">แก้ไขเมนู</h3>
          <p class="text-xs text-gray-500 mt-0.5">${m.name || 'ไม่มีชื่อ'}</p>
        </div>
        <button onclick="document.getElementById('editMenuModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-6 overflow-y-auto flex-1 space-y-4">
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div><label class="block text-sm font-medium mb-1">ชื่อเมนู</label><input id="editMenuName" value="${(m.name||'').replace(/"/g,'&quot;')}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div><label class="block text-sm font-medium mb-1">หมวดหมู่</label>${categoryDropdownHtml('editMenuCat', m.category||'อาหารตามสั่ง')}</div>
          <div><label class="block text-sm font-medium mb-1">ราคา (฿)</label><input id="editMenuPrice" type="number" value="${m.price||0}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div class="md:col-span-2"><label class="block text-sm font-medium mb-1">รายละเอียด</label><input id="editMenuDesc" value="${(m.description||'').replace(/"/g,'&quot;')}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div><label class="flex items-center gap-2 text-sm mt-6"><input type="checkbox" id="editMenuAvail" ${m.is_available !== false ? 'checked' : ''} class="w-4 h-4 rounded" /> พร้อมขาย</label></div>
        </div>

        <!-- Image Upload -->
        <div class="border rounded-xl p-4 bg-gray-50">
          <label class="block text-sm font-bold mb-2">รูปภาพเมนู</label>
          <div class="flex items-start gap-4">
            <div id="editMenuPreview" class="flex-shrink-0">${m.image_url ? `<img src="${m.image_url}" class="w-20 h-20 rounded-lg object-cover border" />` : '<div class="w-20 h-20 bg-gray-200 rounded-lg flex items-center justify-center"><span class="material-icons-round text-gray-400">image</span></div>'}</div>
            <div class="flex-1 space-y-2">
              <input id="editMenuImg" value="${m.image_url||''}" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="วาง URL รูปภาพ" />
              <input type="file" id="editMenuFile" accept="image/*" class="w-full border rounded-lg px-3 py-1.5 text-sm file:mr-2 file:py-1 file:px-3 file:rounded-lg file:border-0 file:text-sm file:bg-indigo-100 file:text-indigo-700 hover:file:bg-indigo-200" onchange="previewMenuImage(this,'editMenuPreview')" />
            </div>
          </div>
        </div>

        <!-- Option Groups Section -->
        <div class="border rounded-xl p-4">
          <div class="flex items-center justify-between mb-3">
            <h5 class="font-bold text-gray-700 text-sm flex items-center gap-2"><span class="material-icons-round text-sm">tune</span> ตัวเลือกเมนู</h5>
            <button onclick="showLinkOptionGroupModal('${id}','${m.merchant_id}')" class="px-3 py-1 bg-green-500 text-white rounded-lg text-xs font-medium hover:bg-green-600 flex items-center gap-1"><span class="material-icons-round text-xs">add</span> เพิ่มตัวเลือก</button>
          </div>
          <div id="menuOptionGroupsList">
            ${linkedGroups.length === 0 ? '<p class="text-gray-400 text-sm py-2">ยังไม่มีตัวเลือก</p>' :
              linkedGroups.map(g => `
                <div class="border rounded-lg p-3 mb-2">
                  <div class="flex items-center justify-between">
                    <div>
                      <span class="font-medium text-sm">${g.name}</span>
                      <span class="text-xs text-gray-500 ml-2">(เลือก ${g.min_selection}-${g.max_selection} รายการ)</span>
                    </div>
                    <button onclick="unlinkOptionGroupFromMenu('${id}','${g.id}')" class="text-red-500 hover:text-red-700 text-xs">ลบออก</button>
                  </div>
                  ${(g.menu_options||[]).length > 0 ? `<div class="mt-2 flex flex-wrap gap-2">${(g.menu_options||[]).map(o => `<span class="px-2 py-1 bg-gray-100 rounded text-xs ${o.is_available ? '' : 'line-through text-gray-400'}">${o.name}${o.price > 0 ? ' +฿'+o.price : ''}</span>`).join('')}</div>` : ''}
                </div>
              `).join('')}
          </div>
        </div>
      </div>
      <div class="px-6 py-4 border-t border-gray-100 flex gap-2 justify-end">
        <button onclick="document.getElementById('editMenuModal')?.remove()" class="px-4 py-2 bg-gray-100 text-gray-600 rounded-lg text-sm font-medium hover:bg-gray-200">ยกเลิก</button>
        <button onclick="submitEditMenu('${id}','${m.merchant_id}')" class="px-5 py-2 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">บันทึก</button>
      </div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });
}

async function submitEditMenu(id, merchantId) {
  try {
    let imageUrl = document.getElementById('editMenuImg').value;
    const fileInput = document.getElementById('editMenuFile');
    if (fileInput?.files?.length) {
      imageUrl = await uploadMenuImage(fileInput.files[0], merchantId || 'unknown');
    }
    await supabase.from('menu_items').update({
      name: document.getElementById('editMenuName').value,
      category: document.getElementById('editMenuCat').value,
      price: parseFloat(document.getElementById('editMenuPrice').value) || 0,
      description: document.getElementById('editMenuDesc').value,
      image_url: imageUrl,
      is_available: document.getElementById('editMenuAvail').checked,
    }).eq('id', id);
    document.getElementById('editMenuModal')?.remove();
    showToast('บันทึกเมนูสำเร็จ!', 'success');
    loadMerchantMenus();
  } catch(e) { showToast('เกิดข้อผิดพลาด: ' + e.message, 'error'); }
}

async function unlinkOptionGroupFromMenu(menuItemId, groupId) {
  if (!confirm('ลบกลุ่มตัวเลือกนี้ออกจากเมนู?')) return;
  try {
    await supabase.from('menu_item_option_links').delete().eq('menu_item_id', menuItemId).eq('option_group_id', groupId);
    editMenuItem(menuItemId); // Refresh
  } catch(e) { alert('เกิดข้อผิดพลาด: ' + e.message); }
}

async function showLinkOptionGroupModal(menuItemId, merchantId) {
  // Fetch existing groups for this merchant
  const { data: groups } = await supabase.from('menu_option_groups').select('*, menu_options(*)').eq('merchant_id', merchantId).order('name');
  // Fetch already linked groups
  const { data: links } = await supabase.from('menu_item_option_links').select('option_group_id').eq('menu_item_id', menuItemId);
  const linkedIds = new Set((links||[]).map(l => l.option_group_id));

  const modal = document.createElement('div');
  modal.id = 'optionGroupModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-2xl mx-4 fade-in max-h-[80vh] flex flex-col">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <h3 class="font-bold text-gray-800 text-lg">จัดการกลุ่มตัวเลือก</h3>
        <button onclick="document.getElementById('optionGroupModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-6 overflow-y-auto flex-1">
        <!-- Create new group -->
        <div class="bg-blue-50 rounded-xl p-4 mb-4">
          <h4 class="font-bold text-sm text-blue-800 mb-3">สร้างกลุ่มตัวเลือกใหม่</h4>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
            <div><input id="newGroupName" placeholder="ชื่อกลุ่ม เช่น ระดับความเผ็ด" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
            <div class="flex gap-2">
              <input id="newGroupMin" type="number" value="0" min="0" placeholder="เลือกขั้นต่ำ" class="w-full border rounded-lg px-3 py-2 text-sm" />
              <input id="newGroupMax" type="number" value="1" min="1" placeholder="เลือกสูงสุด" class="w-full border rounded-lg px-3 py-2 text-sm" />
            </div>
            <div><button onclick="createOptionGroupAndLink('${menuItemId}','${merchantId}')" class="w-full px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">สร้างและเพิ่ม</button></div>
          </div>
        </div>

        <!-- Existing groups to link -->
        <h4 class="font-bold text-sm text-gray-700 mb-2">กลุ่มตัวเลือกที่มีอยู่ (คลิกเพื่อเพิ่ม/เอาออก)</h4>
        ${(!groups || groups.length === 0) ? '<p class="text-gray-400 text-sm">ยังไม่มีกลุ่มตัวเลือก</p>' :
          groups.map(g => {
            const isLinked = linkedIds.has(g.id);
            return `
            <div class="border rounded-lg p-3 mb-2 ${isLinked ? 'bg-green-50 border-green-200' : ''}">
              <div class="flex items-center justify-between">
                <div>
                  <span class="font-medium text-sm">${g.name}</span>
                  <span class="text-xs text-gray-500 ml-2">(${g.min_selection}-${g.max_selection})</span>
                  ${(g.menu_options||[]).length > 0 ? `<div class="mt-1 flex flex-wrap gap-1">${(g.menu_options||[]).map(o => `<span class="px-1.5 py-0.5 bg-gray-100 rounded text-xs">${o.name}${o.price > 0 ? ' +฿'+o.price : ''}</span>`).join('')}</div>` : ''}
                </div>
                <div class="flex items-center gap-2">
                  <button onclick="showManageOptionsModal('${g.id}','${g.name}','${merchantId}','${menuItemId}')" class="px-2 py-1 bg-gray-100 text-gray-600 rounded text-xs hover:bg-gray-200">แก้ไขตัวเลือก</button>
                  ${isLinked ?
                    `<button onclick="toggleLinkGroup('${menuItemId}','${g.id}',false)" class="px-3 py-1 bg-red-100 text-red-600 rounded-lg text-xs font-medium hover:bg-red-200">เอาออก</button>` :
                    `<button onclick="toggleLinkGroup('${menuItemId}','${g.id}',true)" class="px-3 py-1 bg-green-500 text-white rounded-lg text-xs font-medium hover:bg-green-600">เพิ่ม</button>`}
                </div>
              </div>
            </div>`;
          }).join('')}
      </div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });
}

async function createOptionGroupAndLink(menuItemId, merchantId) {
  const name = document.getElementById('newGroupName')?.value?.trim();
  const min = parseInt(document.getElementById('newGroupMin')?.value) || 0;
  const max = parseInt(document.getElementById('newGroupMax')?.value) || 1;
  if (!name) return alert('กรุณากรอกชื่อกลุ่ม');
  try {
    const { data: grp } = await supabase.from('menu_option_groups').insert({ merchant_id: merchantId, name, min_selection: min, max_selection: max }).select().single();
    if (grp) {
      await supabase.from('menu_item_option_links').insert({ menu_item_id: menuItemId, option_group_id: grp.id, sort_order: 0 });
    }
    document.getElementById('optionGroupModal')?.remove();
    editMenuItem(menuItemId);
    alert('สร้างกลุ่มตัวเลือกสำเร็จ!');
  } catch(e) { alert('เกิดข้อผิดพลาด: ' + e.message); }
}

async function toggleLinkGroup(menuItemId, groupId, link) {
  try {
    if (link) {
      await supabase.from('menu_item_option_links').insert({ menu_item_id: menuItemId, option_group_id: groupId, sort_order: 0 });
    } else {
      await supabase.from('menu_item_option_links').delete().eq('menu_item_id', menuItemId).eq('option_group_id', groupId);
    }
    document.getElementById('optionGroupModal')?.remove();
    showLinkOptionGroupModal(menuItemId, document.getElementById('menuMerchantSelect')?.value || '');
    editMenuItem(menuItemId);
  } catch(e) { alert('เกิดข้อผิดพลาด: ' + e.message); }
}

async function showManageOptionsModal(groupId, groupName, merchantId, menuItemId) {
  const { data: options } = await supabase.from('menu_options').select('*').eq('group_id', groupId).order('name');

  const modal = document.createElement('div');
  modal.id = 'manageOptionsModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-[60]';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 fade-in">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <h3 class="font-bold text-gray-800">ตัวเลือกใน "${groupName}"</h3>
        <button onclick="document.getElementById('manageOptionsModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-6">
        <div class="flex gap-2 mb-4">
          <input id="newOptName" placeholder="ชื่อตัวเลือก" class="flex-1 border rounded-lg px-3 py-2 text-sm" />
          <input id="newOptPrice" type="number" value="0" placeholder="ราคาเพิ่ม" class="w-24 border rounded-lg px-3 py-2 text-sm" />
          <button onclick="addMenuOption('${groupId}','${groupName}','${merchantId}','${menuItemId}')" class="px-4 py-2 bg-green-500 text-white rounded-lg text-sm font-medium hover:bg-green-600">เพิ่ม</button>
        </div>
        <div id="optionsList">
          ${(options||[]).length === 0 ? '<p class="text-gray-400 text-sm">ยังไม่มีตัวเลือก</p>' :
            (options||[]).map(o => `
              <div class="flex items-center justify-between py-2 border-b border-gray-50">
                <div class="flex items-center gap-3">
                  <span class="text-sm font-medium ${o.is_available ? '' : 'line-through text-gray-400'}">${o.name}</span>
                  ${o.price > 0 ? `<span class="text-xs text-green-600 font-semibold">+฿${o.price}</span>` : ''}
                </div>
                <div class="flex items-center gap-2">
                  <button onclick="toggleOptionAvail('${o.id}',${!o.is_available},'${groupId}','${groupName}','${merchantId}','${menuItemId}')" class="text-xs ${o.is_available ? 'text-orange-500' : 'text-green-500'} hover:underline">${o.is_available ? 'ปิด' : 'เปิด'}</button>
                  <button onclick="deleteMenuOption('${o.id}','${groupId}','${groupName}','${merchantId}','${menuItemId}')" class="text-xs text-red-500 hover:underline">ลบ</button>
                </div>
              </div>
            `).join('')}
        </div>
      </div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });
}

async function addMenuOption(groupId, groupName, merchantId, menuItemId) {
  const name = document.getElementById('newOptName')?.value?.trim();
  const price = parseInt(document.getElementById('newOptPrice')?.value) || 0;
  if (!name) return alert('กรุณากรอกชื่อตัวเลือก');
  try {
    await supabase.from('menu_options').insert({ group_id: groupId, name, price, is_available: true });
    document.getElementById('manageOptionsModal')?.remove();
    showManageOptionsModal(groupId, groupName, merchantId, menuItemId);
  } catch(e) { alert('เกิดข้อผิดพลาด: ' + e.message); }
}

async function toggleOptionAvail(optionId, newState, groupId, groupName, merchantId, menuItemId) {
  try {
    await supabase.from('menu_options').update({ is_available: newState }).eq('id', optionId);
    document.getElementById('manageOptionsModal')?.remove();
    showManageOptionsModal(groupId, groupName, merchantId, menuItemId);
  } catch(e) { alert('เกิดข้อผิดพลาด: ' + e.message); }
}

async function deleteMenuOption(optionId, groupId, groupName, merchantId, menuItemId) {
  if (!confirm('ลบตัวเลือกนี้?')) return;
  try {
    await supabase.from('menu_options').delete().eq('id', optionId);
    document.getElementById('manageOptionsModal')?.remove();
    showManageOptionsModal(groupId, groupName, merchantId, menuItemId);
  } catch(e) { alert('เกิดข้อผิดพลาด: ' + e.message); }
}

async function deleteMenuItem(id, name) {
  if (!confirm(`ลบเมนู "${name}" ?`)) return;
  try {
    await supabase.from('menu_items').delete().eq('id', id);
    alert('ลบสำเร็จ!');
    loadMerchantMenus();
  } catch(e) { alert('เกิดข้อผิดพลาด: ' + e.message); }
}

// ============================================
// Top-up Requests Page
// ============================================
async function renderTopups(el) {
  let currentTopupMode = 'admin_approve';
  try {
    const { data: cfg } = await supabase.from('system_config').select('topup_mode').maybeSingle();
    if (cfg?.topup_mode) currentTopupMode = cfg.topup_mode;
  } catch(_) {}

  const { data: requests } = await supabase.from('topup_requests').select('*').order('created_at', { ascending: false }).limit(100);

  const userIds = [...new Set((requests||[]).map(r => r.user_id))];
  let userMap = {};
  if (userIds.length) {
    const { data: profiles } = await supabase.from('profiles').select('id, full_name').in('id', userIds);
    (profiles || []).forEach(p => userMap[p.id] = p);
  }

  const isOmise = currentTopupMode === 'omise';
  const statusCounts = { pending: 0, completed: 0, rejected: 0 };
  (requests || []).forEach((r) => {
    if (statusCounts[r.status] !== undefined) statusCounts[r.status] += 1;
  });
  const modeBanner = `
    <div class="glass-card p-4 mb-5 flex flex-wrap items-center justify-between gap-3">
      <div class="flex items-center gap-3">
        <div class="w-9 h-9 rounded-xl flex items-center justify-center ${isOmise ? 'bg-teal-50' : 'bg-indigo-50'}">
          <span class="material-icons-round ${isOmise ? 'text-teal-500' : 'text-indigo-500'}">${isOmise ? 'bolt' : 'admin_panel_settings'}</span>
        </div>
        <div>
          <p class="text-sm font-bold text-gray-800">โหมดปัจจุบัน: ${isOmise ? 'Omise (อัตโนมัติ)' : 'แอดมินอนุมัติ'}</p>
          <p class="text-xs text-gray-400">${isOmise ? 'คนขับจ่ายผ่าน Omise → เติมเงินอัตโนมัติ' : 'คนขับโอน PromptPay → รอแอดมินอนุมัติ'}</p>
        </div>
      </div>
      <div class="flex items-center gap-2">
        <button onclick="quickSwitchTopupMode('${isOmise ? 'admin_approve' : 'omise'}')" class="px-4 py-2 rounded-xl text-xs font-semibold transition-all ${isOmise ? 'bg-indigo-100 text-indigo-700 hover:bg-indigo-200' : 'bg-teal-100 text-teal-700 hover:bg-teal-200'}">
          <span class="material-icons-round text-sm align-middle mr-1">${isOmise ? 'admin_panel_settings' : 'bolt'}</span>
          สลับเป็น${isOmise ? 'แอดมินอนุมัติ' : 'Omise อัตโนมัติ'}
        </button>
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
          { label: 'รอดำเนินการ', value: (requests || []).filter((r) => r.status === 'pending').reduce((s, r) => s + Number(r.amount || 0), 0), displayValue: '฿' + fmt(Math.round((requests || []).filter((r) => r.status === 'pending').reduce((s, r) => s + Number(r.amount || 0), 0))) },
          { label: 'เสร็จสิ้น', value: (requests || []).filter((r) => r.status === 'completed').reduce((s, r) => s + Number(r.amount || 0), 0), displayValue: '฿' + fmt(Math.round((requests || []).filter((r) => r.status === 'completed').reduce((s, r) => s + Number(r.amount || 0), 0))) },
          { label: 'ปฏิเสธ', value: (requests || []).filter((r) => r.status === 'rejected').reduce((s, r) => s + Number(r.amount || 0), 0), displayValue: '฿' + fmt(Math.round((requests || []).filter((r) => r.status === 'rejected').reduce((s, r) => s + Number(r.amount || 0), 0))) },
        ], '#0ea5e9')}
      </div>
      <div class="glass-card overflow-hidden">
        <div class="px-6 py-4 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class="w-8 h-8 bg-teal-50 rounded-lg flex items-center justify-center"><span class="material-icons-round text-teal-500 text-sm">add_card</span></div>
            <h3 class="font-bold text-gray-800">คำขอเติมเงิน (${(requests||[]).length})</h3>
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
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">จำนวน</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">สถานะ</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">วันที่</th>
              <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">จัดการ</th>
            </tr></thead>
            <tbody>
              ${(requests||[]).length === 0 ? '<tr><td colspan="5" class="px-4 py-8 text-center text-gray-400">ไม่มีคำขอ</td></tr>' :
              (requests||[]).map(r => {
                const user = userMap[r.user_id] || {};
                return `
                  <tr class="table-row border-b border-gray-50">
                    <td class="px-4 py-3 font-medium">${user.full_name || r.user_id?.substring(0,8) || '-'}</td>
                    <td class="px-4 py-3 font-semibold text-green-600">฿${fmt(r.amount)}</td>
                    <td class="px-4 py-3">${statusBadge(r.status)}</td>
                    <td class="px-4 py-3 text-gray-500 text-xs">${fmtDate(r.created_at)}</td>
                    <td class="px-4 py-3">
                      ${r.status === 'pending' ? `
                        <button onclick="approveTopup('${r.id}','${r.user_id}',${r.amount})" class="px-3 py-1 bg-green-500 text-white rounded-lg text-xs font-medium hover:bg-green-600 mr-1">อนุมัติ</button>
                        <button onclick="rejectTopup('${r.id}')" class="px-3 py-1 bg-red-500 text-white rounded-lg text-xs font-medium hover:bg-red-600">ปฏิเสธ</button>
                      ` : '-'}
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
  window._allTopups = (requests || []).map((r) => ({
    ผู้ขอ: userMap[r.user_id]?.full_name || r.user_id?.substring(0, 8) || '-',
    จำนวน: Math.round(r.amount || 0),
    สถานะ: r.status || '-',
    วันที่: fmtDate(r.created_at),
  }));
}

function exportTopupsCsv() {
  const rows = window._allTopups || [];
  exportRowsToCsv(reportFilename('topups_report', 'csv', '', ''), ['ผู้ขอ', 'จำนวน', 'สถานะ', 'วันที่'], rows);
}

function exportTopupsExcel() {
  const rows = window._allTopups || [];
  exportRowsToExcel(reportFilename('topups_report', 'xls', '', ''), ['ผู้ขอ', 'จำนวน', 'สถานะ', 'วันที่'], rows);
}

async function approveTopup(id, userId, amount) {
  if (!confirm(`อนุมัติเติมเงิน ฿${fmt(amount)} ?`)) return;
  try {
    // Get or create wallet
    let { data: wallet } = await supabase.from('wallets').select('id, balance').eq('user_id', userId).maybeSingle();
    if (!wallet) {
      const { data: newW } = await supabase.from('wallets').insert({ user_id: userId, balance: 0 }).select().single();
      wallet = newW;
    }
    if (wallet) {
      await supabase.from('wallets').update({ balance: (wallet.balance || 0) + amount }).eq('id', wallet.id);
      await supabase.from('wallet_transactions').insert({ wallet_id: wallet.id, amount, type: 'topup', description: 'เติมเงินผ่าน Admin (฿' + amount + ')' });
    }
    await supabase.from('topup_requests').update({ status: 'completed', processed_at: new Date().toISOString() }).eq('id', id);
    alert('อนุมัติเติมเงินสำเร็จ!');
    refreshCurrentPage();
  } catch(e) { alert('เกิดข้อผิดพลาด: ' + e.message); }
}

async function rejectTopup(id) {
  const reason = prompt('เหตุผลที่ปฏิเสธ:');
  if (!reason) return;
  await supabase.from('topup_requests').update({ status: 'rejected', admin_note: reason, processed_at: new Date().toISOString() }).eq('id', id);
  refreshCurrentPage();
}

async function quickSwitchTopupMode(newMode) {
  const label = newMode === 'omise' ? 'Omise (อัตโนมัติ)' : 'แอดมินอนุมัติ';
  if (!confirm(`สลับโหมดเติมเงินเป็น "${label}" ?\n\nแอปคนขับจะเปลี่ยนโหมดอัตโนมัติในครั้งถัดไปที่เปิดหน้าเติมเงิน`)) return;
  try {
    const { data: existing } = await supabase.from('system_config').select('id').maybeSingle();
    const configId = existing?.id ?? 1;
    const { error } = await supabase.from('system_config').upsert({ id: configId, topup_mode: newMode, updated_at: new Date().toISOString() }, { onConflict: 'id' });
    if (error) throw error;
    showToast(`เปลี่ยนโหมดเติมเงินเป็น "${label}" สำเร็จ`, 'success');
    refreshCurrentPage();
  } catch(e) { showToast('เกิดข้อผิดพลาด: ' + (e.message || JSON.stringify(e)), 'error'); }
}

// ============================================
// Complaints Page
// ============================================
async function renderComplaints(el) {
  const { data: tickets } = await supabase.from('support_tickets').select('*').order('created_at', { ascending: false }).limit(200);

  // Fetch user names
  const userIds = [...new Set((tickets||[]).map(t => t.user_id).filter(Boolean))];
  let userMap = {};
  if (userIds.length) {
    const { data: profiles } = await supabase.from('profiles').select('id, full_name, role').in('id', userIds);
    (profiles || []).forEach(p => userMap[p.id] = p);
  }

  const statusMap = {
    open: ['เปิดอยู่','bg-red-100 text-red-700'],
    in_progress: ['กำลังดำเนินการ','bg-yellow-100 text-yellow-700'],
    resolved: ['แก้ไขแล้ว','bg-green-100 text-green-700'],
    closed: ['ปิดแล้ว','bg-gray-100 text-gray-600'],
  };
  const categoryMap = {
    driver_behavior: '🚗 พฤติกรรมคนขับ', food_quality: '🍔 คุณภาพอาหาร',
    late_delivery: '⏰ ส่งช้า', wrong_order: '❌ ออเดอร์ผิด',
    payment: '💳 การชำระเงิน', app_bug: '🐛 ปัญหาแอพ', other: '📋 อื่นๆ',
  };

  const stats = { open: 0, in_progress: 0, resolved: 0, closed: 0 };
  (tickets||[]).forEach(t => { if (stats[t.status] !== undefined) stats[t.status]++; });
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
        ${renderMiniBarChart('สรุปสถานะคำร้องเรียน', '200 รายการล่าสุด', [
          { label: 'เปิดอยู่', value: stats.open, displayValue: fmt(stats.open) },
          { label: 'กำลังดำเนินการ', value: stats.in_progress, displayValue: fmt(stats.in_progress) },
          { label: 'แก้ไขแล้ว', value: stats.resolved, displayValue: fmt(stats.resolved) },
          { label: 'ปิดแล้ว', value: stats.closed, displayValue: fmt(stats.closed) },
        ], '#f43f5e')}
        ${renderMiniBarChart('หมวดหมู่คำร้องเรียน (Top 6)', '200 รายการล่าสุด', categoryRows, '#6366f1')}
      </div>
      <div class="glass-card p-4 flex gap-2 flex-wrap">
        <button onclick="filterComplaints('')" class="px-4 py-2 bg-white border border-gray-200 rounded-xl text-sm font-semibold hover:bg-gray-50 transition-colors">ทั้งหมด (${(tickets||[]).length})</button>
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
  window._allComplaints = tickets || [];
  window._filteredComplaints = tickets || [];
  window._complaintUserMap = userMap;
  window._complaintStatusMap = statusMap;
  window._complaintCategoryMap = categoryMap;
}

function renderComplaintRows(tickets, userMap, statusMap, categoryMap) {
  if (!tickets.length) return '<tr><td colspan="7" class="px-4 py-8 text-center text-gray-400">ไม่มีข้อมูลร้องเรียน</td></tr>';
  const roleMap = { customer: 'ลูกค้า', driver: 'คนขับ', merchant: 'ร้านค้า' };
  return tickets.map(t => {
    const user = userMap[t.user_id] || {};
    const [statusLabel, statusCls] = statusMap[t.status] || [t.status, 'bg-gray-100 text-gray-600'];
    const catLabel = categoryMap[t.category] || t.category || '-';
    return `
      <tr class="table-row border-b border-gray-50">
        <td class="px-4 py-3 font-medium">${user.full_name || '-'}</td>
        <td class="px-4 py-3 text-gray-500">${roleMap[user.role] || user.role || '-'}</td>
        <td class="px-4 py-3">${catLabel}</td>
        <td class="px-4 py-3 max-w-[200px] truncate">${t.subject || t.description?.substring(0,50) || '-'}</td>
        <td class="px-4 py-3"><span class="px-2.5 py-1 rounded-full text-xs font-semibold ${statusCls}">${statusLabel}</span></td>
        <td class="px-4 py-3 text-gray-500 text-xs">${fmtDate(t.created_at)}</td>
        <td class="px-4 py-3 whitespace-nowrap">
          ${t.status === 'open' ? `
            <button onclick="updateComplaintStatus('${t.id}','in_progress')" class="px-3 py-1 bg-yellow-500 text-white rounded-lg text-xs font-medium hover:bg-yellow-600 mr-1">รับเรื่อง</button>
          ` : ''}
          ${t.status === 'in_progress' ? `
            <button onclick="resolveComplaint('${t.id}')" class="px-3 py-1 bg-green-500 text-white rounded-lg text-xs font-medium hover:bg-green-600 mr-1">แก้ไขแล้ว</button>
          ` : ''}
          ${t.status !== 'closed' ? `
            <button onclick="updateComplaintStatus('${t.id}','closed')" class="px-3 py-1 bg-gray-500 text-white rounded-lg text-xs font-medium hover:bg-gray-600 mr-1">ปิด</button>
          ` : ''}
          <button onclick="viewComplaintDetail('${t.id}')" class="px-3 py-1 bg-blue-100 text-blue-600 rounded-lg text-xs font-medium hover:bg-blue-200">ดู</button>
        </td>
      </tr>
    `;
  }).join('');
}

function filterComplaints(status) {
  let filtered = window._allComplaints || [];
  if (status) filtered = filtered.filter(t => t.status === status);
  window._filteredComplaints = filtered;
  document.getElementById('complaintsTableBody').innerHTML = renderComplaintRows(
    filtered, window._complaintUserMap, window._complaintStatusMap, window._complaintCategoryMap
  );
}

function exportComplaintsCsv() {
  const rows = (window._filteredComplaints || window._allComplaints || []).map((t) => ({
    ผู้ร้องเรียน: window._complaintUserMap?.[t.user_id]?.full_name || '-',
    บทบาท: window._complaintUserMap?.[t.user_id]?.role || '-',
    หมวดหมู่: window._complaintCategoryMap?.[t.category] || t.category || '-',
    หัวข้อ: t.subject || '-',
    สถานะ: t.status || '-',
    วันที่: fmtDate(t.created_at),
  }));
  exportRowsToCsv(reportFilename('complaints_report', 'csv', '', ''), ['ผู้ร้องเรียน', 'บทบาท', 'หมวดหมู่', 'หัวข้อ', 'สถานะ', 'วันที่'], rows);
}

function exportComplaintsExcel() {
  const rows = (window._filteredComplaints || window._allComplaints || []).map((t) => ({
    ผู้ร้องเรียน: window._complaintUserMap?.[t.user_id]?.full_name || '-',
    บทบาท: window._complaintUserMap?.[t.user_id]?.role || '-',
    หมวดหมู่: window._complaintCategoryMap?.[t.category] || t.category || '-',
    หัวข้อ: t.subject || '-',
    สถานะ: t.status || '-',
    วันที่: fmtDate(t.created_at),
  }));
  exportRowsToExcel(reportFilename('complaints_report', 'xls', '', ''), ['ผู้ร้องเรียน', 'บทบาท', 'หมวดหมู่', 'หัวข้อ', 'สถานะ', 'วันที่'], rows);
}

async function updateComplaintStatus(id, status) {
  try {
    await supabase.from('support_tickets').update({ status, updated_at: new Date().toISOString() }).eq('id', id);
    refreshCurrentPage();
  } catch(e) { alert('เกิดข้อผิดพลาด: ' + e.message); }
}

async function resolveComplaint(id) {
  const resolution = prompt('วิธีแก้ไข / หมายเหตุ:');
  if (!resolution) return;
  try {
    await supabase.from('support_tickets').update({
      status: 'resolved', resolution, resolved_at: new Date().toISOString(), updated_at: new Date().toISOString()
    }).eq('id', id);
    refreshCurrentPage();
  } catch(e) { alert('เกิดข้อผิดพลาด: ' + e.message); }
}

async function viewComplaintDetail(id) {
  const { data: t } = await supabase.from('support_tickets').select('*').eq('id', id).single();
  if (!t) return;
  let userName = '-';
  if (t.user_id) {
    const { data: p } = await supabase.from('profiles').select('full_name, role').eq('id', t.user_id).maybeSingle();
    if (p) userName = `${p.full_name} (${p.role})`;
  }
  alert(
    `📋 รายละเอียดร้องเรียน\n\n` +
    `ผู้ร้องเรียน: ${userName}\n` +
    `หมวดหมู่: ${t.category || '-'}\n` +
    `หัวข้อ: ${t.subject || '-'}\n` +
    `รายละเอียด: ${t.description || '-'}\n` +
    `สถานะ: ${t.status}\n` +
    `Booking ID: ${t.booking_id ? '#'+t.booking_id.substring(0,8) : '-'}\n` +
    `วันที่: ${fmtDate(t.created_at)}\n` +
    `วิธีแก้ไข: ${t.resolution || 'ยังไม่ได้แก้ไข'}`
  );
}

// ============================================
// Order Reassignment (T4)
// ============================================
async function _notifyAdminActionTargets(rows = []) {
  const validRows = rows.filter(r => r && r.user_id && r.title && r.body);
  if (!validRows.length) return;

  const { error } = await supabase.from('notifications').insert(validRows);
  if (error) {
    console.warn('Admin action notification insert failed:', error.message || error);
  }
}

async function _applyAdminOrderReassign(orderId, newDriverId, updateFields = {}) {
  const { data: booking, error: bookingErr } = await supabase
    .from('bookings')
    .select('id, customer_id, merchant_id, driver_id, service_type, status')
    .eq('id', orderId)
    .single();
  if (bookingErr) throw bookingErr;

  const previousDriverId = booking.driver_id;
  if (previousDriverId && previousDriverId === newDriverId) {
    throw new Error('คนขับที่เลือกเป็นคนเดิมของออเดอร์นี้');
  }
  const reassignAt = new Date().toISOString();
  const payload = {
    driver_id: newDriverId,
    assigned_at: reassignAt,
    ...updateFields,
  };

  const { error: updateErr } = await supabase
    .from('bookings')
    .update(payload)
    .eq('id', orderId);
  if (updateErr) throw updateErr;

  const notifyRows = [];
  const shortId = (orderId || '').substring(0, 8);
  const baseData = {
    type: 'admin_reassign',
    booking_id: orderId,
    new_driver_id: newDriverId,
    old_driver_id: previousDriverId || '',
    service_type: booking.service_type || '',
    status_after: payload.status || booking.status || '',
    reassigned_at: reassignAt,
  };

  notifyRows.push({
    user_id: newDriverId,
    title: '📌 แอดมินมอบหมายงานใหม่',
    body: `คุณได้รับงาน #${shortId} จากแอดมินแล้ว`,
    type: 'admin_reassign_new_driver',
    data: { ...baseData, role: 'new_driver' },
  });

  if (previousDriverId && previousDriverId !== newDriverId) {
    notifyRows.push({
      user_id: previousDriverId,
      title: '🔄 แอดมินย้ายงาน',
      body: `งาน #${shortId} ถูกย้ายไปให้คนขับท่านอื่น`,
      type: 'admin_reassign_old_driver',
      data: { ...baseData, role: 'old_driver' },
    });
  }

  if (booking.customer_id) {
    notifyRows.push({
      user_id: booking.customer_id,
      title: '🚗 เปลี่ยนคนขับโดยแอดมิน',
      body: `ออเดอร์ #${shortId} มีการมอบหมายคนขับใหม่แล้ว`,
      type: 'admin_reassign_customer',
      data: { ...baseData, role: 'customer' },
    });
  }

  if (booking.merchant_id && booking.service_type === 'food') {
    notifyRows.push({
      user_id: booking.merchant_id,
      title: '🍔 เปลี่ยนคนขับออเดอร์',
      body: `ออเดอร์ #${shortId} มีการเปลี่ยนคนขับโดยแอดมิน`,
      type: 'admin_reassign_merchant',
      data: { ...baseData, role: 'merchant' },
    });
  }

  await _notifyAdminActionTargets(notifyRows);
}

async function showReassignModal(orderId, currentDriverName) {
  const { data: booking } = await supabase
    .from('bookings')
    .select('driver_id')
    .eq('id', orderId)
    .maybeSingle();
  const currentDriverId = booking?.driver_id || null;

  let driverQuery = supabase
    .from('profiles')
    .select('id, full_name, phone_number, license_plate')
    .eq('role', 'driver')
    .eq('approval_status', 'approved')
    .order('full_name');

  if (currentDriverId) {
    driverQuery = driverQuery.neq('id', currentDriverId);
  }

  const { data: drivers } = await driverQuery;
  if (!drivers || !drivers.length) return alert('ไม่พบคนขับที่อนุมัติแล้ว');

  const modal = document.createElement('div');
  modal.id = 'reassignModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 fade-in">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <div>
          <h3 class="font-bold text-gray-800 text-lg">ย้ายออเดอร์ให้คนขับอื่น</h3>
          <p class="text-xs text-gray-500 mt-1">ออเดอร์ #${orderId.substring(0,8)} — คนขับปัจจุบัน: ${currentDriverName || 'ยังไม่มี'}</p>
        </div>
        <button onclick="document.getElementById('reassignModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-6 max-h-[60vh] overflow-y-auto">
        <input type="text" id="reassignSearch" placeholder="ค้นหาคนขับ..." class="w-full border rounded-lg px-3 py-2 text-sm mb-3" oninput="filterReassignDrivers()" />
        <div id="reassignDriverList">
          ${drivers.map(d => `
            <div class="reassign-driver-item flex items-center justify-between p-3 rounded-lg hover:bg-blue-50 cursor-pointer border border-gray-100 mb-2 transition-colors" data-name="${(d.full_name||'').toLowerCase()}" onclick="reassignOrder('${orderId}','${d.id}','${(d.full_name||'').replace(/'/g,'')}')">
              <div class="flex items-center gap-3">
                <div class="w-9 h-9 bg-blue-100 rounded-full flex items-center justify-center"><span class="material-icons-round text-blue-600 text-sm">person</span></div>
                <div>
                  <p class="font-medium text-sm">${d.full_name || '-'}</p>
                  <p class="text-xs text-gray-500">${d.phone_number || ''} ${d.license_plate ? '• '+d.license_plate : ''}</p>
                </div>
              </div>
              <span class="material-icons-round text-gray-300 text-lg">chevron_right</span>
            </div>
          `).join('')}
        </div>
      </div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });
}

function filterReassignDrivers() {
  const q = (document.getElementById('reassignSearch')?.value || '').toLowerCase();
  document.querySelectorAll('.reassign-driver-item').forEach(el => {
    el.style.display = el.dataset.name.includes(q) ? '' : 'none';
  });
}

async function reassignOrder(orderId, newDriverId, driverName) {
  if (!confirm(`ย้ายออเดอร์ #${orderId.substring(0,8)} ให้ "${driverName}" ?`)) return;
  try {
    await _applyAdminOrderReassign(orderId, newDriverId, { status: 'driver_accepted' });
    document.getElementById('reassignModal')?.remove();
    showToast('ย้ายออเดอร์สำเร็จ!', 'success');
    loadOrders();
  } catch(e) { showToast('เกิดข้อผิดพลาด: ' + (e.message || JSON.stringify(e)), 'error'); }
}

// ============================================
// Pending Orders Page (T5)
// ============================================
let _pendingRefreshTimer = null;
let _pendingRealtimeChannel = null;

async function renderPendingOrders(el) {
  // Clean up previous timers
  if (_pendingRefreshTimer) { clearInterval(_pendingRefreshTimer); _pendingRefreshTimer = null; }
  if (_pendingRealtimeChannel) { supabase.removeChannel(_pendingRealtimeChannel); _pendingRealtimeChannel = null; }

  el.innerHTML = `
    <div class="fade-in space-y-5">
      <div class="grid grid-cols-1 md:grid-cols-4 gap-4" id="poStats"></div>
      <div id="poContent"><div class="flex justify-center py-12"><div class="loader"></div></div></div>
    </div>`;

  await _refreshPendingOrders();

  // Auto-refresh every 15s
  _pendingRefreshTimer = setInterval(_refreshPendingOrders, 15000);

  // Realtime subscription for bookings changes
  _pendingRealtimeChannel = supabase.channel('pending-orders-rt')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'bookings' }, () => {
      _refreshPendingOrders();
    }).subscribe();
}

async function _refreshPendingOrders() {
  const pendingStatuses = ['pending','pending_merchant','matched'];
  const stuckStatuses = ['driver_accepted','preparing','arrived_at_merchant','ready_for_pickup','picking_up_order'];

  const [{ data: pendingOrders }, { data: stuckOrders }] = await Promise.all([
    supabase.from('bookings').select('id, driver_id, merchant_id, customer_id, status, service_type, price, delivery_fee, pickup_address, destination_address, origin_lat, origin_lng, dest_lat, dest_lng, created_at').in('status', pendingStatuses).order('created_at', { ascending: true }),
    supabase.from('bookings').select('id, driver_id, merchant_id, customer_id, status, service_type, price, delivery_fee, pickup_address, destination_address, origin_lat, origin_lng, dest_lat, dest_lng, created_at').in('status', stuckStatuses).order('created_at', { ascending: true }),
  ]);

  // Resolve all profile names (driver + merchant + customer)
  const allIds = [...new Set([
    ...(pendingOrders||[]).map(o=>o.driver_id),
    ...(pendingOrders||[]).map(o=>o.merchant_id),
    ...(pendingOrders||[]).map(o=>o.customer_id),
    ...(stuckOrders||[]).map(o=>o.driver_id),
    ...(stuckOrders||[]).map(o=>o.merchant_id),
    ...(stuckOrders||[]).map(o=>o.customer_id),
  ].filter(Boolean))];
  let namesMap = {};
  if (allIds.length) {
    const { data: profiles } = await supabase.from('profiles').select('id, full_name, phone_number').in('id', allIds);
    (profiles||[]).forEach(p => { namesMap[p.id] = { name: p.full_name || '-', phone: p.phone_number || '' }; });
  }

  // Categorize
  const noDriver = (pendingOrders||[]).filter(o => !o.driver_id);
  const waitingMerchant = (pendingOrders||[]).filter(o => o.status === 'pending_merchant');
  const stuckLong = (stuckOrders||[]).filter(o => {
    const mins = (Date.now() - new Date(o.created_at).getTime()) / 60000;
    return mins > 30;
  });
  const totalPending = (pendingOrders||[]).length + stuckLong.length;

  // Store for use by dispatch modal
  window._pendingNamesMap = namesMap;

  // Stats
  const statsEl = document.getElementById('poStats');
  if (statsEl) {
    statsEl.innerHTML = `
      ${statCard('pending_actions', 'ทั้งหมดที่รอ', totalPending, 'bg-blue-500')}
      ${statCard('hourglass_empty', 'รอคนขับ', noDriver.length, 'bg-red-500')}
      ${statCard('store', 'รอร้านค้า', waitingMerchant.length, 'bg-amber-500')}
      ${statCard('warning', 'ค้างนาน >30น.', stuckLong.length, 'bg-purple-500')}
    `;
  }

  const thHead = `
    <thead><tr class="bg-gray-50/80">
      <th class="px-3 py-2.5 text-left text-xs font-semibold text-gray-400">ID</th>
      <th class="px-3 py-2.5 text-left text-xs font-semibold text-gray-400">ประเภท</th>
      <th class="px-3 py-2.5 text-left text-xs font-semibold text-gray-400">สถานะ</th>
      <th class="px-3 py-2.5 text-left text-xs font-semibold text-gray-400">ราคา</th>
      <th class="px-3 py-2.5 text-left text-xs font-semibold text-gray-400">ลูกค้า</th>
      <th class="px-3 py-2.5 text-left text-xs font-semibold text-gray-400">ที่อยู่รับ / ส่ง</th>
      <th class="px-3 py-2.5 text-left text-xs font-semibold text-gray-400">คนขับ</th>
      <th class="px-3 py-2.5 text-left text-xs font-semibold text-gray-400">ร้านค้า</th>
      <th class="px-3 py-2.5 text-left text-xs font-semibold text-gray-400">รอมา</th>
      <th class="px-3 py-2.5 text-left text-xs font-semibold text-gray-400">จัดการ</th>
    </tr></thead>`;

  function poRow(o) {
    const mins = Math.floor((Date.now() - new Date(o.created_at).getTime()) / 60000);
    const timeLabel = mins < 60 ? `${mins} นาที` : `${Math.floor(mins/60)} ชม. ${mins%60} น.`;
    const isUrgent = mins > 15;
    const custInfo = namesMap[o.customer_id];
    const drvInfo = namesMap[o.driver_id];
    const merInfo = namesMap[o.merchant_id];
    const priceText = o.service_type === 'food'
      ? `฿${fmt(Math.round(o.price||0))} <span class="text-blue-500 text-[9px]">+ ค่าส่ง ฿${fmt(Math.round(o.delivery_fee||0))}</span>`
      : `฿${fmt(Math.round(o.price||0))}`;
    const pickup = o.pickup_address || '-';
    const dest = o.destination_address || '-';
    const canDispatch = !o.driver_id && MAP_DISPATCHABLE_STATUSES.includes(o.status);
    const canAdminAccept = _canAdminMerchantAccept(o);
    const canAdminReady = _canAdminMarkFoodReady(o);

    return `
      <tr class="table-row ${isUrgent ? 'bg-red-50/40' : 'hover:bg-gray-50/50'}">
        <td class="px-3 py-2.5">
          <button onclick="showPendingOrderDetail('${o.id}')" class="font-mono text-xs text-indigo-600 hover:underline cursor-pointer">#${o.id.substring(0,8)}</button>
        </td>
        <td class="px-3 py-2.5">${serviceIcon(o.service_type)}</td>
        <td class="px-3 py-2.5">${statusBadge(o.status)}</td>
        <td class="px-3 py-2.5 text-xs font-bold text-gray-800">${priceText}</td>
        <td class="px-3 py-2.5 text-xs">
          ${custInfo ? `<span class="font-medium">${custInfo.name}</span>` : '<span class="text-gray-400">-</span>'}
          ${custInfo && custInfo.phone ? `<br/><span class="text-gray-400 text-[10px]">📞 ${custInfo.phone}</span>` : ''}
        </td>
        <td class="px-3 py-2.5 text-[11px] text-gray-600 max-w-[200px]">
          <div class="truncate" title="${pickup}">📍 ${pickup}</div>
          <div class="truncate text-green-600" title="${dest}">🏁 ${dest}</div>
        </td>
        <td class="px-3 py-2.5 text-xs">${drvInfo ? `<span class="text-blue-600 font-medium">🏍 ${drvInfo.name}</span>` : '<span class="text-red-500 font-semibold">ไม่มี</span>'}</td>
        <td class="px-3 py-2.5 text-xs">${merInfo ? `<span class="text-orange-600">🏪 ${merInfo.name}</span>` : '-'}</td>
        <td class="px-3 py-2.5">
          <span class="inline-flex items-center gap-1 text-xs font-semibold ${isUrgent ? 'text-red-600' : 'text-gray-500'}">
            ${isUrgent ? '<span class="w-1.5 h-1.5 rounded-full bg-red-500 animate-pulse"></span>' : ''}
            ${timeLabel}
          </span>
        </td>
        <td class="px-3 py-2.5 whitespace-nowrap">
          <div class="flex items-center gap-1">
            ${canDispatch ? `<button onclick="pendingDispatch('${o.id}')" class="px-2 py-1 bg-blue-500 text-white rounded-lg text-[10px] font-medium hover:bg-blue-600 transition-colors">โยนงาน</button>` : (o.driver_id ? `<button onclick="pendingDispatch('${o.id}','${o.driver_id}')" class="px-2 py-1 bg-amber-500 text-white rounded-lg text-[10px] font-medium hover:bg-amber-600 transition-colors">ย้าย</button>` : '')}
            ${canAdminAccept ? `<button onclick="adminMerchantAcceptOrder('${o.id}')" class="px-2 py-1 bg-emerald-500 text-white rounded-lg text-[10px] font-medium hover:bg-emerald-600 transition-colors">รับแทนร้าน</button>` : ''}
            ${canAdminReady ? `<button onclick="adminMarkFoodReady('${o.id}')" class="px-2 py-1 bg-teal-500 text-white rounded-lg text-[10px] font-medium hover:bg-teal-600 transition-colors">อาหารพร้อม</button>` : ''}
            <button onclick="pendingCancel('${o.id}')" class="px-2 py-1 bg-red-100 text-red-600 rounded-lg text-[10px] font-medium hover:bg-red-200 transition-colors">ยกเลิก</button>
          </div>
        </td>
      </tr>`;
  }

  function tableSection(icon, iconBg, title, subtitle, orders, extraBtn) {
    return `
      <div class="glass-card overflow-hidden">
        <div class="px-5 py-3.5 flex items-center gap-3 border-b border-gray-100">
          <div class="w-8 h-8 ${iconBg} rounded-xl flex items-center justify-center"><span class="material-icons-round text-sm" style="color:inherit">${icon}</span></div>
          <div class="flex-1 min-w-0">
            <h3 class="font-bold text-gray-800 text-sm">${title}</h3>
            <p class="text-[11px] text-gray-400">${subtitle}</p>
          </div>
          ${extraBtn || ''}
          <button onclick="_refreshPendingOrders()" class="p-1.5 rounded-lg hover:bg-gray-100 transition-colors" title="รีเฟรช"><span class="material-icons-round text-gray-400 text-sm">refresh</span></button>
        </div>
        <div class="overflow-x-auto">
          <table class="w-full text-sm">${thHead}
            <tbody class="divide-y divide-gray-100">
              ${orders.length ? orders.map(poRow).join('') : `<tr><td colspan="10" class="px-4 py-8 text-center text-gray-400 text-sm">ไม่มีรายการ 🎉</td></tr>`}
            </tbody>
          </table>
        </div>
      </div>`;
  }

  const contentEl = document.getElementById('poContent');
  if (!contentEl) return;

  contentEl.innerHTML = `
    <div class="space-y-5">
      ${tableSection(
        'hourglass_empty', 'bg-red-50 text-red-500',
        'ออเดอร์รอคนขับ', `${noDriver.length} รายการ — ต้องการมอบหมายคนขับ`,
        noDriver,
        `<button onclick="navigateTo('map')" class="px-3 py-1.5 text-xs font-semibold text-indigo-600 bg-indigo-50 rounded-lg hover:bg-indigo-100 transition-colors">🗺 ดูบนแผนที่</button>`
      )}
      ${waitingMerchant.length ? tableSection(
        'store', 'bg-amber-50 text-amber-500',
        'รอร้านค้ายืนยัน', `${waitingMerchant.length} รายการ — ร้านค้ายังไม่ตอบรับ`,
        waitingMerchant
      ) : ''}
      ${stuckLong.length ? tableSection(
        'warning', 'bg-purple-50 text-purple-500',
        'ออเดอร์ค้างนาน (>30 นาที)', `${stuckLong.length} รายการ — อาจต้องติดตามหรือยกเลิก`,
        stuckLong
      ) : ''}
      ${totalPending === 0 ? `
        <div class="glass-card p-12 text-center">
          <span class="material-icons-round text-5xl text-green-400">check_circle</span>
          <p class="mt-3 font-bold text-gray-700">ไม่มีออเดอร์ที่รอจัดการ</p>
          <p class="text-sm text-gray-400 mt-1">ระบบจะอัปเดตอัตโนมัติทุก 15 วินาที</p>
        </div>` : ''}
    </div>`;
}

async function showPendingOrderDetail(orderId) {
  const { data: o } = await supabase.from('bookings').select('*').eq('id', orderId).single();
  if (!o) return alert('ไม่พบออเดอร์');
  const nMap = window._pendingNamesMap || {};
  const cust = nMap[o.customer_id];
  const drv = nMap[o.driver_id];
  const mer = nMap[o.merchant_id];
  const mins = Math.floor((Date.now() - new Date(o.created_at).getTime()) / 60000);
  const timeLabel = mins < 60 ? `${mins} นาที` : `${Math.floor(mins/60)} ชม. ${mins%60} น.`;

  // Fetch order items if food
  let itemsHtml = '';
  if (o.service_type === 'food') {
    const { data: items } = await supabase.from('booking_items').select('*').eq('booking_id', orderId);
    if (items && items.length) {
      itemsHtml = `
        <div class="mt-3 border-t border-gray-100 pt-3">
          <p class="text-xs font-semibold text-gray-500 mb-1.5">📋 รายการอาหาร</p>
          ${items.map(it => `<div class="flex justify-between text-xs py-0.5"><span>${it.name || it.menu_name || '-'} x${it.quantity||1}</span><span class="text-gray-500">฿${fmt(Math.round((it.price||0)*(it.quantity||1)))}</span></div>`).join('')}
        </div>`;      
    }
  }

  const canDispatchInDetail = !o.driver_id && MAP_DISPATCHABLE_STATUSES.includes(o.status);
  const canAdminAcceptInDetail = _canAdminMerchantAccept(o);
  const canAdminReadyInDetail = _canAdminMarkFoodReady(o);

  const modal = document.createElement('div');
  modal.id = 'poDetailModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 fade-in max-h-[85vh] overflow-y-auto">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between sticky top-0 bg-white z-10">
        <div>
          <h3 class="font-bold text-gray-800">ออเดอร์ #${orderId.substring(0,8)}</h3>
          <p class="text-xs text-gray-400">${fmtDate(o.created_at)} • รอมา ${timeLabel}</p>
        </div>
        <button onclick="document.getElementById('poDetailModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-5 space-y-3">
        <div class="flex items-center gap-3">
          ${serviceIcon(o.service_type)}
          ${statusBadge(o.status)}
          <span class="text-lg font-bold text-gray-800">฿${fmt(Math.round(o.price||0))}</span>
          ${o.delivery_fee ? `<span class="text-xs text-blue-500 bg-blue-50 px-2 py-0.5 rounded-full">ค่าส่ง ฿${fmt(Math.round(o.delivery_fee))}</span>` : ''}
        </div>
        <div class="grid grid-cols-2 gap-3 text-xs">
          <div class="p-3 rounded-xl bg-gray-50">
            <p class="text-gray-400 mb-1">👤 ลูกค้า</p>
            <p class="font-semibold">${cust ? cust.name : '-'}</p>
            ${cust && cust.phone ? `<p class="text-gray-400">📞 ${cust.phone}</p>` : ''}
          </div>
          <div class="p-3 rounded-xl bg-gray-50">
            <p class="text-gray-400 mb-1">🏍 คนขับ</p>
            <p class="font-semibold ${drv ? 'text-blue-600' : 'text-red-500'}">${drv ? drv.name : 'ยังไม่มี'}</p>
            ${drv && drv.phone ? `<p class="text-gray-400">📞 ${drv.phone}</p>` : ''}
          </div>
          ${mer ? `<div class="p-3 rounded-xl bg-gray-50 col-span-2">
            <p class="text-gray-400 mb-1">🏪 ร้านค้า</p>
            <p class="font-semibold text-orange-600">${mer.name}</p>
            ${mer.phone ? `<p class="text-gray-400">📞 ${mer.phone}</p>` : ''}
          </div>` : ''}
        </div>
        <div class="p-3 rounded-xl bg-gray-50 text-xs space-y-1">
          <div><span class="text-gray-400">📍 รับ:</span> <span class="text-gray-700">${o.pickup_address || '-'}</span></div>
          <div><span class="text-gray-400">🏁 ส่ง:</span> <span class="text-gray-700">${o.destination_address || '-'}</span></div>
          ${o.notes ? `<div><span class="text-gray-400">📝 หมายเหตุ:</span> <span class="text-gray-700">${o.notes}</span></div>` : ''}
        </div>
        ${itemsHtml}
        <div class="flex gap-2 pt-2 flex-wrap">
          ${canDispatchInDetail ? `<button onclick="document.getElementById('poDetailModal')?.remove();pendingDispatch('${o.id}')" class="flex-1 py-2 bg-blue-500 text-white rounded-xl text-sm font-semibold hover:bg-blue-600 transition-colors">โยนงานให้คนขับ</button>` : (o.driver_id ? `<button onclick="document.getElementById('poDetailModal')?.remove();pendingDispatch('${o.id}','${o.driver_id}')" class="flex-1 py-2 bg-amber-500 text-white rounded-xl text-sm font-semibold hover:bg-amber-600 transition-colors">ย้ายคนขับ</button>` : '')}
          ${canAdminAcceptInDetail ? `<button onclick="document.getElementById('poDetailModal')?.remove();adminMerchantAcceptOrder('${o.id}')" class="flex-1 py-2 bg-emerald-500 text-white rounded-xl text-sm font-semibold hover:bg-emerald-600 transition-colors">รับแทนร้าน</button>` : ''}
          ${canAdminReadyInDetail ? `<button onclick="document.getElementById('poDetailModal')?.remove();adminMarkFoodReady('${o.id}')" class="flex-1 py-2 bg-teal-500 text-white rounded-xl text-sm font-semibold hover:bg-teal-600 transition-colors">กดอาหารพร้อม</button>` : ''}
          <button onclick="document.getElementById('poDetailModal')?.remove();pendingCancel('${o.id}')" class="px-4 py-2 bg-red-100 text-red-600 rounded-xl text-sm font-semibold hover:bg-red-200 transition-colors">ยกเลิก</button>
        </div>
      </div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });
}

async function pendingDispatch(orderId, excludeDriverId) {
  // Fetch drivers from profiles (same source as map page) + driver_locations + active bookings
  const [{ data: allDrivers }, { data: driverLocs }, { data: activeBookings }] = await Promise.all([
    supabase.from('profiles').select('id, full_name, phone_number, license_plate, latitude, longitude').eq('role', 'driver').eq('approval_status', 'approved'),
    supabase.from('driver_locations').select('driver_id, is_online, is_available, location_lat, location_lng'),
    supabase.from('bookings').select('driver_id').in('status', ['driver_accepted','matched','preparing','arrived_at_merchant','ready_for_pickup','picking_up_order','in_transit']),
  ]);

  // Build driver_locations lookup
  const locMap = {};
  (driverLocs||[]).forEach(d => { locMap[d.driver_id] = d; });

  // Determine online status same way as map: if no driver_locations record → default online
  const onlineDrivers = (allDrivers||[]).filter(d => {
    if (d.id === excludeDriverId) return false;
    const loc = locMap[d.id];
    const isOnline = loc ? _truthyFlag(loc.is_online) : true; // same default as map page
    return isOnline;
  });

  if (!onlineDrivers.length) return alert('ไม่มีคนขับออนไลน์');

  // Build job count map
  const jobCountMap = {};
  (activeBookings||[]).forEach(b => { if (b.driver_id) jobCountMap[b.driver_id] = (jobCountMap[b.driver_id]||0) + 1; });

  // Get order location for distance calc
  const { data: orderData } = await supabase.from('bookings').select('origin_lat, origin_lng').eq('id', orderId).single();
  const oLat = orderData?.origin_lat, oLng = orderData?.origin_lng;

  // Sort: free drivers first, then by distance
  const enriched = onlineDrivers.map(d => {
    const loc = locMap[d.id];
    const jobs = jobCountMap[d.id] || 0;
    // Use driver_locations position first, fallback to profiles position
    const dLat = loc?.location_lat || d.latitude;
    const dLng = loc?.location_lng || d.longitude;
    let dist = null;
    if (oLat && oLng && dLat && dLng) {
      dist = _haversineKm(oLat, oLng, dLat, dLng);
    }
    return { ...d, jobs, dist, isAvailable: loc?.is_available };
  }).sort((a, b) => {
    if (a.jobs !== b.jobs) return a.jobs - b.jobs;
    if (a.dist !== null && b.dist !== null) return a.dist - b.dist;
    return 0;
  });

  const title = excludeDriverId ? 'ย้ายคนขับ' : 'โยนงาน';
  const modal = document.createElement('div');
  modal.id = 'pendingDispatchModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-md mx-4 fade-in">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <div>
          <h3 class="font-bold text-gray-800">${title} #${orderId.substring(0,8)}</h3>
          <p class="text-xs text-gray-400">${enriched.length} คนขับออนไลน์ ${excludeDriverId ? '(ไม่รวมคนเดิม)' : ''}</p>
        </div>
        <button onclick="document.getElementById('pendingDispatchModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-4 max-h-[50vh] overflow-y-auto space-y-1.5">
        ${enriched.map(d => {
          const jobBadge = d.jobs > 0
            ? `<span class="px-1.5 py-0.5 rounded text-[9px] font-bold bg-blue-100 text-blue-700">งาน ${d.jobs}</span>`
            : `<span class="px-1.5 py-0.5 rounded text-[9px] font-bold bg-green-100 text-green-700">ว่าง</span>`;
          const distLabel = d.dist !== null ? `<span class="text-[10px] text-gray-400">📏 ${d.dist.toFixed(1)} กม.</span>` : '';
          return `
            <div class="flex items-center gap-3 p-3 rounded-xl border border-gray-100 hover:border-blue-200 hover:bg-blue-50/50 cursor-pointer transition-all" onclick="pendingAssign('${orderId}','${d.id}','${(d.full_name||'-').replace(/'/g,'')}')">
              <div class="w-8 h-8 rounded-full flex items-center justify-center text-white text-xs font-bold flex-shrink-0 ${d.jobs > 0 ? 'bg-blue-500' : 'bg-green-500'}">
                ${d.jobs > 0 ? d.jobs : '🏍'}
              </div>
              <div class="flex-1 min-w-0">
                <p class="text-sm font-medium truncate">${d.full_name||'-'}</p>
                <p class="text-[10px] text-gray-400">${d.license_plate||''} • ${d.phone_number||''}</p>
              </div>
              <div class="flex flex-col items-end gap-0.5 flex-shrink-0">
                ${jobBadge}
                ${distLabel}
              </div>
            </div>`;
        }).join('')}
      </div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });
}

async function pendingAssign(orderId, driverId, driverName) {
  if (!confirm(`มอบหมาย #${orderId.substring(0,8)} ให้ "${driverName}" ?`)) return;
  try {
    const { error } = await supabase.from('bookings').update({ driver_id: driverId, status: 'driver_accepted', assigned_at: new Date().toISOString() }).eq('id', orderId);
    if (error) throw error;
    document.getElementById('pendingDispatchModal')?.remove();
    showToast('มอบหมายงานสำเร็จ!', 'success');
    _refreshPendingOrders();
  } catch(e) { showToast('เกิดข้อผิดพลาด: ' + (e.message || JSON.stringify(e)), 'error'); }
}

async function pendingCancel(orderId) {
  const reasons = [
    'ลูกค้าแจ้งยกเลิก',
    'ไม่มีคนขับรับงาน',
    'ร้านค้าปิดให้บริการ',
    'ร้านค้าไม่ตอบรับ',
    'สินค้าหมด',
    'ออเดอร์ซ้ำ',
  ];

  const modal = document.createElement('div');
  modal.id = 'poCancelModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-sm mx-4 fade-in">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <h3 class="font-bold text-gray-800">ยกเลิกออเดอร์ #${orderId.substring(0,8)}</h3>
        <button onclick="document.getElementById('poCancelModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-4 space-y-2">
        <p class="text-xs font-medium text-gray-500 mb-2">เลือกเหตุผล:</p>
        ${reasons.map((r, i) => `
          <label class="flex items-center gap-2 p-2.5 rounded-lg border border-gray-100 hover:bg-red-50 cursor-pointer transition-colors">
            <input type="radio" name="cancelReason" value="${r}" class="accent-red-500" ${i === 0 ? 'checked' : ''} />
            <span class="text-sm">${r}</span>
          </label>`).join('')}
        <label class="flex items-center gap-2 p-2.5 rounded-lg border border-gray-100 hover:bg-red-50 cursor-pointer transition-colors">
          <input type="radio" name="cancelReason" value="other" />
          <span class="text-sm">อื่นๆ</span>
        </label>
        <input type="text" id="cancelOtherReason" class="w-full border rounded-lg px-3 py-2 text-sm hidden" placeholder="ระบุเหตุผล..." />
        <button onclick="_doPendingCancel('${orderId}')" class="w-full mt-2 py-2.5 bg-red-500 text-white rounded-xl font-semibold hover:bg-red-600 transition-colors">ยืนยันยกเลิก</button>
      </div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });

  // Show/hide other input
  modal.querySelectorAll('input[name="cancelReason"]').forEach(radio => {
    radio.addEventListener('change', () => {
      const otherInput = document.getElementById('cancelOtherReason');
      if (radio.value === 'other' && radio.checked) otherInput.classList.remove('hidden');
      else otherInput.classList.add('hidden');
    });
  });
}

async function _doPendingCancel(orderId) {
  const selected = document.querySelector('input[name="cancelReason"]:checked');
  let reason = selected?.value || '';
  if (reason === 'other') {
    reason = document.getElementById('cancelOtherReason')?.value?.trim();
    if (!reason) return alert('กรุณาระบุเหตุผล');
  }
  if (!reason) return;
  try {
    const { error } = await supabase.from('bookings').update({ status: 'cancelled', cancellation_reason: reason, updated_at: new Date().toISOString() }).eq('id', orderId);
    if (error) throw error;
    document.getElementById('poCancelModal')?.remove();
    showToast('ยกเลิกออเดอร์สำเร็จ', 'success');
    _refreshPendingOrders();
  } catch(e) { showToast('เกิดข้อผิดพลาด: ' + (e.message || JSON.stringify(e)), 'error'); }
}

// ============================================
// Realtime Map Page
// ============================================
let _mapInstance = null;
let _mapRefreshTimer = null;
let _mapRealtimeChannel = null;
let _mapSidebarTab = 'drivers'; // 'drivers' or 'orders'

function _getInitialMapCenter() {
  const fallback = { center: [13.7563, 100.5018], zoom: 12 }; // Bangkok

  const resolveFallbackCenter = async () => {
    // Fallback 1: admin profile location
    if (currentUser?.id) {
      const { data: me } = await supabase
        .from('profiles')
        .select('latitude, longitude')
        .eq('id', currentUser.id)
        .maybeSingle();

      const meLat = (me?.latitude ?? null);
      const meLng = (me?.longitude ?? null);
      if (meLat && meLng) {
        return { center: [meLat, meLng], zoom: 14 };
      }
    }

    // Fallback 2: latest known driver location
    const { data: latestDriverLoc } = await supabase
      .from('driver_locations')
      .select('location_lat, location_lng, updated_at')
      .not('location_lat', 'is', null)
      .not('location_lng', 'is', null)
      .order('updated_at', { ascending: false })
      .limit(1)
      .maybeSingle();

    if (latestDriverLoc?.location_lat && latestDriverLoc?.location_lng) {
      return { center: [latestDriverLoc.location_lat, latestDriverLoc.location_lng], zoom: 13 };
    }

    return fallback;
  };

  if (!navigator.geolocation) return resolveFallbackCenter();

  return new Promise((resolve) => {
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        resolve({
          center: [pos.coords.latitude, pos.coords.longitude],
          zoom: 14,
        });
      },
      async () => resolve(await resolveFallbackCenter()),
      { enableHighAccuracy: true, timeout: 8000, maximumAge: 120000 },
    );
  });
}

async function renderMap(el) {
  // Clear previous timer & realtime
  if (_mapRefreshTimer) { clearInterval(_mapRefreshTimer); _mapRefreshTimer = null; }
  if (_mapRealtimeChannel) { supabase.removeChannel(_mapRealtimeChannel); _mapRealtimeChannel = null; }

  el.innerHTML = `
    <div class="fade-in space-y-4">
      <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4" id="mapStats"></div>
      <div class="flex flex-col xl:flex-row gap-4">
        <!-- Sidebar -->
        <div class="w-full xl:w-80 xl:flex-shrink-0 glass-card overflow-hidden flex flex-col xl:max-h-[700px]">
          <!-- Tab switcher -->
          <div class="flex border-b border-gray-100">
            <button onclick="setMapSidebarTab('drivers')" id="mapTabDrivers" class="flex-1 px-3 py-2.5 text-xs font-bold text-white transition-colors" style="background:linear-gradient(135deg,#6366f1,#818cf8);">🏍 คนขับ</button>
            <button onclick="setMapSidebarTab('orders')" id="mapTabOrders" class="flex-1 px-3 py-2.5 text-xs font-bold bg-gray-50 text-gray-600 hover:bg-gray-100 transition-colors">📦 ออเดอร์</button>
          </div>
          <!-- Driver panel -->
          <div id="mapDriverPanel">
            <div class="px-4 py-2 border-b border-gray-100">
              <input type="text" id="mapDriverSearch" placeholder="ค้นหาคนขับ..." class="w-full border rounded-lg px-2 py-1.5 text-xs" oninput="filterMapDriverList()" />
              <div class="flex gap-1 mt-2">
                <button onclick="setMapDriverFilter('all')" id="mapFilterAll" class="flex-1 px-2 py-1 rounded-lg text-[10px] font-semibold text-white" style="background:linear-gradient(135deg,#6366f1,#818cf8);">ทั้งหมด</button>
                <button onclick="setMapDriverFilter('online')" id="mapFilterOnline" class="flex-1 px-2 py-1 rounded text-[10px] font-medium bg-gray-100 text-gray-600 hover:bg-gray-200">ออนไลน์</button>
                <button onclick="setMapDriverFilter('available')" id="mapFilterAvailable" class="flex-1 px-2 py-1 rounded text-[10px] font-medium bg-gray-100 text-gray-600 hover:bg-gray-200">ว่าง</button>
                <button onclick="setMapDriverFilter('pending')" id="mapFilterPending" class="flex-1 px-2 py-1 rounded text-[10px] font-medium bg-gray-100 text-gray-600 hover:bg-gray-200">รออนุมัติ</button>
              </div>
            </div>
            <div id="mapDriverList" class="flex-1 overflow-y-auto p-2 space-y-1 max-h-[360px] md:max-h-[460px] xl:max-h-[520px]">
              <p class="text-gray-400 text-xs text-center py-4">กำลังโหลด...</p>
            </div>
          </div>
          <!-- Orders panel (hidden by default) -->
          <div id="mapOrderPanel" class="hidden">
            <div class="px-4 py-2 border-b border-gray-100">
              <div class="flex gap-1">
                <button onclick="setMapOrderFilter('active')" id="mapOrderFilterActive" class="flex-1 px-2 py-1 rounded text-[10px] font-medium bg-orange-500 text-white">กำลังดำเนินการ</button>
                <button onclick="setMapOrderFilter('pending')" id="mapOrderFilterPending" class="flex-1 px-2 py-1 rounded text-[10px] font-medium bg-gray-100 text-gray-600">รอคนขับ</button>
                <button onclick="setMapOrderFilter('all')" id="mapOrderFilterAll" class="flex-1 px-2 py-1 rounded text-[10px] font-medium bg-gray-100 text-gray-600">ทั้งหมด</button>
              </div>
            </div>
            <div id="mapOrderList" class="flex-1 overflow-y-auto p-2 space-y-1 max-h-[380px] md:max-h-[485px] xl:max-h-[545px]">
              <p class="text-gray-400 text-xs text-center py-4">กำลังโหลด...</p>
            </div>
          </div>
        </div>
        <!-- Map -->
        <div class="flex-1 min-w-0 glass-card overflow-hidden">
          <div class="px-6 py-3 border-b border-gray-100 flex items-center justify-between">
            <div class="flex items-center gap-2">
              <span class="font-bold text-gray-800">แผนที่ Realtime</span>
              <span id="mapRealtimeStatus" class="w-2 h-2 rounded-full bg-green-500 animate-pulse" title="Realtime connected"></span>
            </div>
            <div class="flex items-center gap-2 flex-wrap justify-end">
              <span class="flex items-center gap-1 text-xs whitespace-nowrap"><span class="w-3 h-3 rounded-full bg-green-500 inline-block"></span> ออนไลน์</span>
              <span class="flex items-center gap-1 text-xs whitespace-nowrap"><span class="w-3 h-3 rounded-full bg-blue-500 inline-block"></span> มีงาน</span>
              <span class="flex items-center gap-1 text-xs whitespace-nowrap"><span class="w-3 h-3 rounded-full bg-orange-500 inline-block"></span> ร้านค้า</span>
              <span class="flex items-center gap-1 text-xs whitespace-nowrap"><span class="w-3 h-3 rounded-full bg-amber-500 inline-block"></span> รออนุมัติ</span>
              <span class="flex items-center gap-1 text-xs whitespace-nowrap"><span class="w-3 h-3 rounded-full bg-red-500 inline-block border border-red-300"></span> ออเดอร์</span>
              <span class="flex items-center gap-1 text-xs whitespace-nowrap"><span style="width:16px;height:3px;background:#3B82F6;display:inline-block;border-radius:2px;"></span> ไปร้าน</span>
              <span class="flex items-center gap-1 text-xs whitespace-nowrap"><span style="width:16px;height:3px;background:#22C55E;display:inline-block;border-radius:2px;"></span> ส่งลูกค้า</span>
              <button onclick="refreshMapData()" class="px-3 py-1 text-white rounded-lg text-xs font-semibold hover:opacity-90 transition-all" style="background:linear-gradient(135deg,#6366f1,#818cf8);">รีเฟรช</button>
            </div>
          </div>
          <div id="adminMap" class="h-[420px] md:h-[560px] xl:h-[640px] w-full"></div>
        </div>
      </div>
    </div>`;

  // Initialize map
  setTimeout(async () => {
    if (_mapInstance) { _mapInstance.remove(); _mapInstance = null; }
    const initial = await _getInitialMapCenter();
    _mapInstance = L.map('adminMap').setView(initial.center, initial.zoom);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap'
    }).addTo(_mapInstance);
    refreshMapData();
    _setupMapRealtime();
  }, 100);

  // Fallback refresh every 30 seconds
  _mapRefreshTimer = setInterval(refreshMapData, 30000);
}

// Supabase Realtime subscriptions for map
let _mapRefreshDebounce = null;
function _debouncedMapRefresh() {
  if (_mapRefreshDebounce) clearTimeout(_mapRefreshDebounce);
  _mapRefreshDebounce = setTimeout(() => { refreshMapData(); }, 800);
}

function _setupMapRealtime() {
  if (_mapRealtimeChannel) { supabase.removeChannel(_mapRealtimeChannel); }
  
  _mapRealtimeChannel = supabase.channel('admin-map-realtime')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'bookings' }, (payload) => {
      debugLog('📦 Booking change:', payload.eventType, payload.new?.id?.substring(0,8));
      _debouncedMapRefresh();
    })
    .on('postgres_changes', { event: '*', schema: 'public', table: 'driver_locations' }, (payload) => {
      debugLog('📍 Driver location change:', payload.new?.driver_id?.substring(0,8));
      _debouncedMapRefresh();
    })
    .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles' }, (payload) => {
      // Always refresh on any profile change — role filter is unreliable
      // because replica identity may not include 'role' column in payload
      debugLog('👤 Profile change:', payload.new?.id?.substring(0,8), 'role:', payload.new?.role, 'online:', payload.new?.is_online);
      _debouncedMapRefresh();
    })
    .subscribe((status) => {
      const dot = document.getElementById('mapRealtimeStatus');
      if (dot) {
        dot.className = status === 'SUBSCRIBED' 
          ? 'w-2 h-2 rounded-full bg-green-500 animate-pulse' 
          : 'w-2 h-2 rounded-full bg-red-500';
        dot.title = status === 'SUBSCRIBED' ? 'Realtime connected' : 'Realtime: ' + status;
      }
    });
}

function debugLog(...args) { if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') console.log(...args); }

window._mapDriverMarkers = [];
window._mapMerchantMarkers = [];
window._mapOrderMarkers = [];
window._mapRouteLines = [];
window._mapAllOrders = [];
window._mapOrderFilter = 'active';
window._osrmRouteCache = {};

// ============================================
// Auto-Dispatch (Map)
// ============================================
// Requirement:
// - Start countdown 120s when: service_type=food, merchant accepted and waiting driver (status=preparing), and no driver accepted (driver_id is null)
// - Run only if nobody accepts during countdown
// - Prefer nearest idle driver; if busy, allow only if route is roughly same direction
window._autoDispatchTimers = window._autoDispatchTimers || {};
window._autoDispatchState = window._autoDispatchState || {}; // orderId -> { endAt, status, reason }
window._autoDispatchTickTimer = window._autoDispatchTickTimer || null;

function _autoDispatchIsEligible(order) {
  if (!order) return false;
  if (order.service_type !== 'food') return false;
  // Flow update: merchant accepts first, then waits for driver to accept before marking ready_for_pickup.
  // So we start countdown at 'preparing'.
  if (order.status !== 'preparing') return false;
  if (order.driver_id) return false;
  if (!order.origin_lat || !order.origin_lng) return false;
  if (!order.dest_lat || !order.dest_lng) return false;
  return true;
}

function _autoDispatchCancel(orderId, reason) {
  if (!orderId) return;
  if (window._autoDispatchTimers?.[orderId]) {
    try { clearTimeout(window._autoDispatchTimers[orderId]); } catch(_) {}
    delete window._autoDispatchTimers[orderId];
  }
  if (window._autoDispatchState?.[orderId]) {
    delete window._autoDispatchState[orderId];
  }
  if (reason) debugLog('🧹 AutoDispatch cancel', orderId.substring(0,8), reason);
}

function _autoDispatchSecondsLeft(orderId) {
  const st = window._autoDispatchState?.[orderId];
  if (!st?.endAt) return null;
  const leftMs = st.endAt - Date.now();
  return Math.max(0, Math.ceil(leftMs / 1000));
}

function _vector(a, b) {
  return { x: (b.lng - a.lng), y: (b.lat - a.lat) };
}

function _cosSim(v1, v2) {
  const dot = v1.x * v2.x + v1.y * v2.y;
  const n1 = Math.sqrt(v1.x * v1.x + v1.y * v1.y);
  const n2 = Math.sqrt(v2.x * v2.x + v2.y * v2.y);
  if (!n1 || !n2) return 0;
  return dot / (n1 * n2);
}

function _routeIsSameDirection(busyOrder, newOrder) {
  // Heuristic: compare direction vectors (pickup->dest)
  // + require new pickup not too far from busy driver's current route start
  try {
    if (!busyOrder?.origin_lat || !busyOrder?.origin_lng || !busyOrder?.dest_lat || !busyOrder?.dest_lng) return false;
    const vBusy = _vector(
      { lat: busyOrder.origin_lat, lng: busyOrder.origin_lng },
      { lat: busyOrder.dest_lat, lng: busyOrder.dest_lng }
    );
    const vNew = _vector(
      { lat: newOrder.origin_lat, lng: newOrder.origin_lng },
      { lat: newOrder.dest_lat, lng: newOrder.dest_lng }
    );
    const sim = _cosSim(vBusy, vNew);
    // cos(45deg) ~= 0.707
    if (sim < 0.70) return false;

    // Also require pickup of new order is not extremely far from busy order path start
    const distToPickup = _haversineKm(busyOrder.origin_lat, busyOrder.origin_lng, newOrder.origin_lat, newOrder.origin_lng);
    return distToPickup <= 5.0;
  } catch(_) {
    return false;
  }
}

function _pickBestDriverForAutoDispatch(order) {
  // Use in-memory data from map refresh (fast)
  const drivers = window._mapDriverData || [];
  const activeOrders = window._mapAllOrders || [];
  if (!drivers.length) return null;

  // Build busy order map per driver (pick the most relevant active order)
  const activeStatuses = ['driver_accepted','matched','preparing','arrived_at_merchant','ready_for_pickup','picking_up_order','in_transit'];
  const driverActiveOrders = {};
  activeOrders
    .filter(o => o.driver_id && activeStatuses.includes(o.status))
    .forEach(o => {
      // Prefer delivery statuses over pre-pickup for route check
      const score = (o.status === 'in_transit' || o.status === 'picking_up_order') ? 2 : 1;
      const prev = driverActiveOrders[o.driver_id];
      if (!prev || (prev._score || 0) < score) driverActiveOrders[o.driver_id] = { ...o, _score: score };
    });

  // Candidate scoring
  const candidates = [];
  for (const d of drivers) {
    if (!d.isOnline) continue;
    if (!d.lat || !d.lng) continue;
    const distToMerchant = _haversineKm(d.lat, d.lng, order.origin_lat, order.origin_lng);
    const isIdle = d.jobCount === 0;
    if (isIdle) {
      // idle preferred
      candidates.push({ driver: d, dist: distToMerchant, tier: 0, reason: 'idle_nearest' });
    } else {
      const busyOrder = driverActiveOrders[d.id];
      if (busyOrder && _routeIsSameDirection(busyOrder, order)) {
        candidates.push({ driver: d, dist: distToMerchant, tier: 1, reason: 'busy_same_route' });
      }
    }
  }

  if (!candidates.length) return null;
  candidates.sort((a, b) => (a.tier - b.tier) || (a.dist - b.dist));
  return candidates[0];
}

async function _autoAssignOrderToDriver(orderId, driverId, meta) {
  const nowIso = new Date().toISOString();
  const payload = {
    driver_id: driverId,
    status: 'driver_accepted',
    assigned_at: nowIso,
    updated_at: nowIso,
  };

  const { error } = await supabase.from('bookings').update(payload).eq('id', orderId);
  if (error) throw error;

  // optional: log into console only (no DB schema assumptions)
  debugLog('✅ AutoDispatch assigned', orderId.substring(0,8), '→', driverId.substring(0,8), meta);
}

async function _autoDispatchExecute(orderId) {
  try {
    const { data: o, error } = await supabase
      .from('bookings')
      .select('id, driver_id, status, service_type, origin_lat, origin_lng, dest_lat, dest_lng, created_at')
      .eq('id', orderId)
      .maybeSingle();
    if (error) throw error;
    if (!_autoDispatchIsEligible(o)) {
      _autoDispatchCancel(orderId, 'not_eligible_at_execute');
      return;
    }

    const picked = _pickBestDriverForAutoDispatch(o);
    if (!picked) {
      // Keep state but stop timer — admin can still dispatch manually
      window._autoDispatchState[orderId] = { ...(window._autoDispatchState[orderId] || {}), status: 'no_driver', reason: 'no_candidate' };
      debugLog('⚠️ AutoDispatch no driver candidate', orderId.substring(0,8));
      return;
    }

    await _autoAssignOrderToDriver(orderId, picked.driver.id, { reason: picked.reason, distKm: picked.dist });
    _autoDispatchCancel(orderId, 'assigned');
    showToast(`Auto-Assign: มอบหมาย #${orderId.substring(0,8)} ให้ ${picked.driver.name || picked.driver.id.substring(0,8)}`, 'success');
    refreshMapData();
  } catch (e) {
    console.error('AutoDispatch execute error:', e);
    window._autoDispatchState[orderId] = { ...(window._autoDispatchState[orderId] || {}), status: 'error', reason: e?.message || 'error' };
    // Keep state for UI; do not loop indefinitely
  }
}

function _autoDispatchEnsure(order) {
  if (!_autoDispatchIsEligible(order)) {
    if (order?.id) _autoDispatchCancel(order.id, 'became_ineligible');
    return;
  }
  const orderId = order.id;
  if (!orderId) return;

  // Already started
  if (window._autoDispatchTimers?.[orderId] && window._autoDispatchState?.[orderId]?.endAt) return;

  const endAt = Date.now() + 120000; // 120s
  window._autoDispatchState[orderId] = { endAt, status: 'countdown', reason: null };
  window._autoDispatchTimers[orderId] = setTimeout(() => _autoDispatchExecute(orderId), 120000);
  debugLog('⏳ AutoDispatch started', orderId.substring(0,8), '120s');

  if (!window._autoDispatchTickTimer) {
    // Update UI once per second for countdown
    window._autoDispatchTickTimer = setInterval(() => {
      try {
        // Only rerender list if map page is active
        if (currentPage === 'map') renderMapOrderList();
      } catch(_) {}
    }, 1000);
  }
}

// Fetch actual road route from OSRM (free public API)
async function _fetchOSRMRoute(lat1, lng1, lat2, lng2) {
  const cacheKey = `${lat1.toFixed(5)},${lng1.toFixed(5)}_${lat2.toFixed(5)},${lng2.toFixed(5)}`;
  if (window._osrmRouteCache[cacheKey]) return window._osrmRouteCache[cacheKey];
  try {
    const url = `https://router.project-osrm.org/route/v1/driving/${lng1},${lat1};${lng2},${lat2}?overview=full&geometries=geojson`;
    const res = await fetch(url);
    if (!res.ok) return null;
    const data = await res.json();
    if (data.code !== 'Ok' || !data.routes?.length) return null;
    const route = data.routes[0];
    const coords = route.geometry.coordinates.map(c => [c[1], c[0]]); // GeoJSON [lng,lat] → Leaflet [lat,lng]
    const distKm = (route.distance / 1000).toFixed(1);
    const result = { coords, distKm };
    window._osrmRouteCache[cacheKey] = result;
    // Limit cache size
    const keys = Object.keys(window._osrmRouteCache);
    if (keys.length > 50) delete window._osrmRouteCache[keys[0]];
    return result;
  } catch(e) {
    console.error('OSRM route error:', e);
    return null;
  }
}

// Draw route line (actual road or fallback straight line)
async function _drawRouteLine(fromLat, fromLng, toLat, toLng, color, weight, opacity, dashArray, tooltipPrefix) {
  if (!_mapInstance) return;
  const route = await _fetchOSRMRoute(fromLat, fromLng, toLat, toLng);
  let line;
  if (route && route.coords.length > 1) {
    line = L.polyline(route.coords, { color, weight, opacity, dashArray: dashArray || null }).addTo(_mapInstance);
    if (tooltipPrefix) line.bindTooltip(`${tooltipPrefix} ${route.distKm} กม.`, { permanent: false, className: 'route-tooltip' });
  } else {
    // Fallback: straight line
    const dist = _haversineKm(fromLat, fromLng, toLat, toLng).toFixed(1);
    line = L.polyline([[fromLat, fromLng],[toLat, toLng]], { color, weight, opacity, dashArray: dashArray || null }).addTo(_mapInstance);
    if (tooltipPrefix) line.bindTooltip(`${tooltipPrefix} ~${dist} กม.`, { permanent: false, className: 'route-tooltip' });
  }
  window._mapRouteLines.push(line);
}

// Haversine distance in km
function _haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat/2)**2 + Math.cos(lat1*Math.PI/180)*Math.cos(lat2*Math.PI/180)*Math.sin(dLng/2)**2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
}

async function refreshMapData() {
  if (!_mapInstance) return;

  try {
    // Fetch drivers with location
    const { data: drivers } = await supabase
      .from('profiles')
      .select('id, full_name, phone_number, license_plate, latitude, longitude, is_online, approval_status, updated_at')
      .eq('role', 'driver')
      .in('approval_status', ['approved', 'pending']);

    // Also try driver_locations table
    const { data: driverLocs } = await supabase.from('driver_locations').select('driver_id, location_lat, location_lng, is_online, is_available, current_booking_id');

    const dLocMap = {};
    (driverLocs || []).forEach(d => { dLocMap[d.driver_id] = d; });

    // Fetch active orders with full details
    const activeStatuses = ['pending','pending_merchant','preparing','driver_accepted','matched','arrived','arrived_at_merchant','ready_for_pickup','picking_up_order','in_transit'];
    const { data: activeOrders } = await supabase.from('bookings').select('id, driver_id, merchant_id, customer_id, status, service_type, price, delivery_fee, origin_lat, origin_lng, dest_lat, dest_lng, pickup_address, destination_address, created_at').in('status', activeStatuses).order('created_at', { ascending: false });

    // Fetch driver names for orders
    const driverIds = [...new Set((activeOrders || []).filter(o => o.driver_id).map(o => o.driver_id))];
    let driverNamesMap = {};
    if (driverIds.length) {
      const { data: dNames } = await supabase.from('profiles').select('id, full_name').in('id', driverIds);
      (dNames || []).forEach(d => { driverNamesMap[d.id] = d.full_name || '-'; });
    }

    // Count orders per driver
    const driverOrderCount = {};
    (activeOrders || []).forEach(o => {
      if (o.driver_id) driverOrderCount[o.driver_id] = (driverOrderCount[o.driver_id] || 0) + 1;
    });

    // Merchants with active orders
    const merchantIds = [...new Set((activeOrders || []).filter(o => o.merchant_id).map(o => o.merchant_id))];
    let merchantsMap = {};
    if (merchantIds.length) {
      const { data: mProfiles } = await supabase.from('profiles').select('id, full_name, shop_address, latitude, longitude').in('id', merchantIds);
      (mProfiles || []).forEach(m => { merchantsMap[m.id] = m; });
    }

    const merchantOrderCount = {};
    (activeOrders || []).forEach(o => {
      if (o.merchant_id) merchantOrderCount[o.merchant_id] = (merchantOrderCount[o.merchant_id] || 0) + 1;
    });

    // Clear existing markers + route lines
    window._mapDriverMarkers.forEach(m => _mapInstance.removeLayer(m));
    window._mapMerchantMarkers.forEach(m => _mapInstance.removeLayer(m));
    window._mapOrderMarkers.forEach(m => _mapInstance.removeLayer(m));
    window._mapRouteLines.forEach(l => _mapInstance.removeLayer(l));
    window._mapDriverMarkers = [];
    window._mapMerchantMarkers = [];
    window._mapOrderMarkers = [];
    window._mapRouteLines = [];

    let onlineCount = 0, busyCount = 0, merchantCount = merchantIds.length;
    const pendingOrderCount = (activeOrders || []).filter(o => MAP_PENDING_NO_DRIVER_STATUSES.includes(o.status) && !o.driver_id).length;
    const pendingDriverCount = (drivers || []).filter(d => d.approval_status === 'pending').length;

    // Add driver markers
    (drivers || []).forEach(d => {
      let lat = d.latitude, lng = d.longitude;
      const loc = dLocMap[d.id];
      if (loc && loc.location_lat && loc.location_lng) { lat = loc.location_lat; lng = loc.location_lng; }
      if (!lat || !lng) return;

      const jobCount = driverOrderCount[d.id] || 0;
      // Determine online status: truthy check (handles null/undefined/string/number)
      const profileOnline = _truthyFlag(d.is_online);
      const locOnline = loc ? _truthyFlag(loc.is_online) : false;
      const profileExplicitOffline = _explicitlyFalseFlag(d.is_online);
      // Driver with active jobs is always considered online
      const isOnline = jobCount > 0 ? true : (profileExplicitOffline ? false : (profileOnline || locOnline));
      if (isOnline) onlineCount++;
      if (jobCount > 0) busyCount++;

      const isPending = d.approval_status === 'pending';
      const color = isPending ? '#F59E0B' : (jobCount > 0 ? '#3B82F6' : (isOnline ? '#22C55E' : '#9CA3AF'));
      const borderColor = isPending ? '#FBBF24' : '#fff';
      const icon = L.divIcon({
        className: '',
        html: `<div style="background:${color};color:#fff;width:32px;height:32px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:700;border:2px solid ${borderColor};box-shadow:0 2px 6px rgba(0,0,0,.3);">${isPending ? '⏳' : (jobCount > 0 ? jobCount : '🏍')}</div>`,
        iconSize: [32, 32], iconAnchor: [16, 16],
      });

      // Calculate distance to nearest pending order
      let nearestDist = null;
      (activeOrders || [])
        .filter(o => MAP_PENDING_NO_DRIVER_STATUSES.includes(o.status) && !o.driver_id && o.origin_lat && o.origin_lng)
        .forEach(o => {
        const d2 = _haversineKm(lat, lng, o.origin_lat, o.origin_lng);
        if (nearestDist === null || d2 < nearestDist) nearestDist = d2;
        });
      const distText = nearestDist !== null ? `📏 ใกล้ออเดอร์: ${nearestDist.toFixed(1)} กม.` : '';

      if (!_mapInstance) return;
      const marker = L.marker([lat, lng], { icon }).addTo(_mapInstance);
      const statusBadge = isPending ? '<br/><span style="background:#FEF3C7;color:#92400E;padding:1px 8px;border-radius:8px;font-size:10px;font-weight:600;">⏳ รออนุมัติ</span>' : '';
      marker.bindPopup(`<b>${d.full_name || '-'}</b>${statusBadge}<br/>📞 ${d.phone_number || '-'}<br/>🚗 ${d.license_plate || '-'}<br/>📦 งาน: ${jobCount}<br/>${isOnline ? '🟢 ออนไลน์' : '🔴 ออฟไลน์'}${distText ? '<br/>' + distText : ''}`);
      window._mapDriverMarkers.push(marker);
    });

    // Add merchant markers
    merchantIds.forEach(mId => {
      const m = merchantsMap[mId];
      if (!m) return;
      let lat = m.latitude, lng = m.longitude;
      if (!lat || !lng) {
        const order = (activeOrders || []).find(o => o.merchant_id === mId && o.origin_lat && o.origin_lng);
        if (order) { lat = order.origin_lat; lng = order.origin_lng; }
      }
      if (!lat || !lng) return;

      const oCount = merchantOrderCount[mId] || 0;
      const icon = L.divIcon({
        className: '',
        html: `<div style="background:#F97316;color:#fff;width:32px;height:32px;border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:700;border:2px solid #fff;box-shadow:0 2px 6px rgba(0,0,0,.3);">${oCount}</div>`,
        iconSize: [32, 32], iconAnchor: [16, 16],
      });

      if (!_mapInstance) return;
      const marker = L.marker([lat, lng], { icon }).addTo(_mapInstance);
      marker.bindPopup(`<b>🏪 ${m.full_name || '-'}</b><br/>📍 ${m.shop_address || '-'}<br/>📦 ออเดอร์: ${oCount}`);
      window._mapMerchantMarkers.push(marker);
    });

    // Add order markers (red pins for pending orders without driver)
    (activeOrders || []).forEach(o => {
      const isPending = MAP_PENDING_NO_DRIVER_STATUSES.includes(o.status) && !o.driver_id;
      const lat = isPending ? (o.origin_lat || o.dest_lat) : null;
      const lng = isPending ? (o.origin_lng || o.dest_lng) : null;
      if (!lat || !lng) return;

      const canDispatch = MAP_DISPATCHABLE_STATUSES.includes(o.status) && !o.driver_id;
      const canAdminAccept = _canAdminMerchantAccept(o);
      const popupAction = canDispatch
        ? `<button onclick="showOrderDispatchModal('${o.id}')" style="background:#3B82F6;color:#fff;padding:4px 12px;border-radius:6px;font-size:11px;margin-top:4px;border:none;cursor:pointer;">โยนงาน</button>`
        : canAdminAccept
          ? `<button onclick="adminMerchantAcceptOrder('${o.id}')" style="background:#10B981;color:#fff;padding:4px 12px;border-radius:6px;font-size:11px;margin-top:4px;border:none;cursor:pointer;">รับแทนร้าน</button>`
          : '';

      const icon = L.divIcon({
        className: '',
        html: `<div style="background:#EF4444;color:#fff;width:28px;height:28px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:10px;font-weight:700;border:2px solid #FCA5A5;box-shadow:0 2px 6px rgba(0,0,0,.3);animation:pulse 2s infinite;">📦</div>`,
        iconSize: [28, 28], iconAnchor: [14, 14],
      });

      if (!_mapInstance) return;
      const marker = L.marker([lat, lng], { icon }).addTo(_mapInstance);
      marker.bindPopup(`<b>📦 #${o.id.substring(0,8)}</b><br/>${serviceIcon(o.service_type)} ${getStatusText(o.status)}<br/>📍 ${o.pickup_address || '-'}<br/>💰 ฿${fmt(Math.round(o.price||0))}${popupAction ? `<br/>${popupAction}` : ''}`);
      window._mapOrderMarkers.push(marker);
    });

    // ── T6: Draw route polylines for active orders with drivers (actual road routes via OSRM) ──
    const routeColors = {
      toMerchant: '#3B82F6',    // Blue — driver heading to merchant
      toCustomer: '#22C55E',    // Green — driver delivering to customer
      preparing:  '#A855F7',    // Purple — food being prepared
    };
    // Build driver position map
    const driverPosMap = {};
    (drivers || []).forEach(d => {
      let lat = d.latitude, lng = d.longitude;
      const loc = dLocMap[d.id];
      if (loc && loc.location_lat && loc.location_lng) { lat = loc.location_lat; lng = loc.location_lng; }
      if (lat && lng) driverPosMap[d.id] = { lat, lng };
    });

    // Build route drawing promises (fetch all routes in parallel)
    const routePromises = [];
    (activeOrders || []).forEach(o => {
      if (!o.driver_id || !_mapInstance) return;
      const dPos = driverPosMap[o.driver_id];
      if (!dPos) return;

      const prePickupStatuses = ['driver_accepted','matched','preparing','arrived_at_merchant','ready_for_pickup'];
      const inDeliveryStatuses = ['picking_up_order','in_transit'];

      if (prePickupStatuses.includes(o.status)) {
        // Route: driver → merchant (origin)
        if (o.origin_lat && o.origin_lng) {
          routePromises.push(_drawRouteLine(dPos.lat, dPos.lng, o.origin_lat, o.origin_lng, routeColors.toMerchant, 3, 0.7, '8,6', '🏍→🏪'));
        }
        // Route: merchant → customer (dest) — dashed lighter preview
        if (o.origin_lat && o.origin_lng && o.dest_lat && o.dest_lng) {
          routePromises.push(_drawRouteLine(o.origin_lat, o.origin_lng, o.dest_lat, o.dest_lng, routeColors.preparing, 2, 0.4, '4,8', null));
        }
      } else if (inDeliveryStatuses.includes(o.status)) {
        // Route: driver → customer destination
        if (o.dest_lat && o.dest_lng) {
          routePromises.push(_drawRouteLine(dPos.lat, dPos.lng, o.dest_lat, o.dest_lng, routeColors.toCustomer, 4, 0.8, null, '🏍→📍'));
        }
      }
    });
    // Draw all routes in parallel (non-blocking)
    Promise.all(routePromises).catch(e => console.error('Route drawing error:', e));

    // Update stats (4 cards)
    const statsEl = document.getElementById('mapStats');
    if (statsEl) {
      statsEl.innerHTML = `
        ${statCard('directions_car', 'คนขับออนไลน์', onlineCount, 'bg-green-500')}
        ${statCard('local_shipping', 'คนขับมีงาน', busyCount, 'bg-blue-500')}
        ${statCard('hourglass_top', 'คนขับรออนุมัติ', pendingDriverCount, 'bg-amber-500')}
        ${statCard('store', 'ร้านค้ามีออเดอร์', merchantCount, 'bg-orange-500')}
        ${statCard('pending_actions', 'ออเดอร์รอดำเนินการ', pendingOrderCount, 'bg-red-500')}
      `;
    }

    // Update driver list sidebar — include distance to nearest pending order
    window._mapDriverData = [];
    const pendingOrderLocs = (activeOrders || []).filter(o => MAP_PENDING_NO_DRIVER_STATUSES.includes(o.status) && !o.driver_id && o.origin_lat && o.origin_lng);
    (drivers || []).forEach(d => {
      let lat = d.latitude, lng = d.longitude;
      const loc = dLocMap[d.id];
      if (loc && loc.location_lat && loc.location_lng) { lat = loc.location_lat; lng = loc.location_lng; }
      if (!lat || !lng) return;
      const jobCount = driverOrderCount[d.id] || 0;
      const profileOnline = _truthyFlag(d.is_online);
      const locOnline = loc ? _truthyFlag(loc.is_online) : false;
      const profileExplicitOffline = _explicitlyFalseFlag(d.is_online);
      const isOnline = jobCount > 0 ? true : (profileExplicitOffline ? false : (profileOnline || locOnline));
      let nearestDist = null;
      pendingOrderLocs.forEach(o => {
        const d2 = _haversineKm(lat, lng, o.origin_lat, o.origin_lng);
        if (nearestDist === null || d2 < nearestDist) nearestDist = d2;
      });
      window._mapDriverData.push({ id: d.id, name: d.full_name || '-', phone: d.phone_number || '', plate: d.license_plate || '', lat, lng, jobCount, isOnline, nearestDist, approvalStatus: d.approval_status || 'pending' });
    });
    renderMapDriverList();

    // Update orders data
    window._mapAllOrders = (activeOrders || []).map(o => ({
      ...o,
      driverName: o.driver_id ? (driverNamesMap[o.driver_id] || '-') : null,
      merchantName: o.merchant_id ? (merchantsMap[o.merchant_id]?.full_name || '-') : null,
    }));
    window._mapPendingOrders = window._mapAllOrders.filter(o => MAP_DISPATCHABLE_STATUSES.includes(o.status) && !o.driver_id);

    // Auto-Dispatch watch: start/cancel countdown based on latest data
    (window._mapAllOrders || []).forEach(o => {
      if (_autoDispatchIsEligible(o)) _autoDispatchEnsure(o);
      else if (o?.id) _autoDispatchCancel(o.id, 'not_eligible');
    });

    renderMapOrderList();

    // Update tab badges
    const ordersTab = document.getElementById('mapTabOrders');
    if (ordersTab) ordersTab.innerHTML = `📦 ออเดอร์ (${(activeOrders||[]).length})`;

  } catch(e) {
    console.error('Map refresh error:', e);
  }
}

window._mapDriverFilter = 'all';

function setMapDriverFilter(filter) {
  window._mapDriverFilter = filter;
  ['all','online','available','pending'].forEach(f => {
    const btn = document.getElementById('mapFilter' + f.charAt(0).toUpperCase() + f.slice(1));
    if (btn) {
      btn.className = f === filter
        ? 'flex-1 px-2 py-1 rounded-lg text-[10px] font-semibold text-white'
        : 'flex-1 px-2 py-1 rounded-lg text-[10px] font-semibold bg-gray-100 text-gray-600 hover:bg-gray-200';
      btn.style.background = f === filter ? 'linear-gradient(135deg,#6366f1,#818cf8)' : '';
    }
  });
  renderMapDriverList();
}

function renderMapDriverList() {
  const driverListEl = document.getElementById('mapDriverList');
  if (!driverListEl) return;
  const q = (document.getElementById('mapDriverSearch')?.value || '').toLowerCase();
  let items = window._mapDriverData || [];
  if (window._mapDriverFilter === 'online') items = items.filter(d => d.isOnline);
  if (window._mapDriverFilter === 'available') items = items.filter(d => d.isOnline && d.jobCount === 0);
  if (window._mapDriverFilter === 'pending') items = items.filter(d => d.approvalStatus === 'pending');
  if (q) items = items.filter(d => d.name.toLowerCase().includes(q));

  if (!items.length) {
    driverListEl.innerHTML = '<p class="text-gray-400 text-xs text-center py-4">ไม่พบคนขับ</p>';
    return;
  }
  driverListEl.innerHTML = items.map(d => {
    const isPending = d.approvalStatus === 'pending';
    const color = isPending ? 'amber' : (d.jobCount > 0 ? 'blue' : (d.isOnline ? 'green' : 'gray'));
    const dotColor = isPending ? 'bg-amber-500' : (color === 'blue' ? 'bg-blue-500' : (color === 'green' ? 'bg-green-500' : 'bg-gray-400'));
    const canDispatch = !isPending && d.isOnline && d.jobCount === 0 && (window._mapPendingOrders||[]).length > 0;
    const distLabel = d.nearestDist !== null && d.nearestDist !== undefined ? `📏 ${d.nearestDist.toFixed(1)} กม.` : '';
    const pendingBadge = isPending ? '<span class="text-[9px] bg-amber-100 text-amber-700 px-1 rounded font-semibold">รออนุมัติ</span> ' : '';
    const borderClass = isPending ? 'border-amber-200 bg-amber-50/30' : (d.isOnline ? (d.jobCount > 0 ? 'border-blue-200 bg-blue-50/30' : 'border-green-200 bg-green-50/30') : 'border-gray-100 bg-gray-50/30');
    return `
      <div class="map-driver-item flex items-center gap-2 px-3 py-2 rounded-lg hover:bg-blue-50 cursor-pointer transition-colors border ${borderClass}" data-name="${d.name.toLowerCase()}" data-online="${d.isOnline}" data-jobs="${d.jobCount}">
        <span class="w-2.5 h-2.5 rounded-full ${dotColor} flex-shrink-0 ${d.isOnline && d.jobCount === 0 && !isPending ? 'animate-pulse' : ''}"></span>
        <div class="flex-1 min-w-0" onclick="zoomToDriver(${d.lat},${d.lng},'${d.name.replace(/'/g,'')}')">
          <p class="text-xs font-medium truncate">${pendingBadge}${d.name}</p>
          <p class="text-[10px] text-gray-400">${d.plate} ${isPending ? '• <span class=text-amber-600>รอการอนุมัติ</span>' : d.jobCount > 0 ? '• <span class=text-blue-600>งาน '+d.jobCount+'</span>' : d.isOnline ? '• <span class=text-green-600>ว่าง</span>' : '• <span class=text-gray-500>ออฟไลน์</span>'} ${distLabel ? '• '+distLabel : ''}</p>
        </div>
        ${canDispatch ? `<button onclick="showMapDispatchModal('${d.id}','${d.name.replace(/'/g,'')}')" class="px-1.5 py-0.5 bg-orange-500 text-white rounded text-[10px] font-medium hover:bg-orange-600 flex-shrink-0" title="โยนงาน">โยนงาน</button>` : `<span class="material-icons-round text-gray-300 text-sm flex-shrink-0 cursor-pointer" onclick="zoomToDriver(${d.lat},${d.lng},'${d.name.replace(/'/g,'')}')">my_location</span>`}
      </div>`;
  }).join('');
}

function zoomToDriver(lat, lng, name) {
  if (!_mapInstance) return;
  _mapInstance.setView([lat, lng], 16, { animate: true });
  window._mapDriverMarkers.forEach(m => {
    const pos = m.getLatLng();
    if (Math.abs(pos.lat - lat) < 0.0001 && Math.abs(pos.lng - lng) < 0.0001) m.openPopup();
  });
}

function filterMapDriverList() { renderMapDriverList(); }

// Sidebar Tab Switching
function setMapSidebarTab(tab) {
  _mapSidebarTab = tab;
  const driversTab = document.getElementById('mapTabDrivers');
  const ordersTab = document.getElementById('mapTabOrders');
  const driverPanel = document.getElementById('mapDriverPanel');
  const orderPanel = document.getElementById('mapOrderPanel');
  
  if (tab === 'drivers') {
    if (driversTab) { driversTab.className = 'flex-1 px-3 py-2.5 text-xs font-bold text-white transition-colors'; driversTab.style.background = 'linear-gradient(135deg,#6366f1,#818cf8)'; }
    if (ordersTab) { ordersTab.className = 'flex-1 px-3 py-2.5 text-xs font-bold bg-gray-50 text-gray-600 hover:bg-gray-100 transition-colors'; ordersTab.style.background = ''; }
    if (driverPanel) driverPanel.classList.remove('hidden');
    if (orderPanel) orderPanel.classList.add('hidden');
  } else {
    if (driversTab) { driversTab.className = 'flex-1 px-3 py-2.5 text-xs font-bold bg-gray-50 text-gray-600 hover:bg-gray-100 transition-colors'; driversTab.style.background = ''; }
    if (ordersTab) { ordersTab.className = 'flex-1 px-3 py-2.5 text-xs font-bold text-white transition-colors'; ordersTab.style.background = 'linear-gradient(135deg,#6366f1,#818cf8)'; }
    if (driverPanel) driverPanel.classList.add('hidden');
    if (orderPanel) orderPanel.classList.remove('hidden');
    renderMapOrderList();
  }
}

// Order Filter
function setMapOrderFilter(filter) {
  window._mapOrderFilter = filter;
  ['active','pending','all'].forEach(f => {
    const btn = document.getElementById('mapOrderFilter' + f.charAt(0).toUpperCase() + f.slice(1));
    if (btn) {
      btn.className = f === filter
        ? 'flex-1 px-2 py-1 rounded text-[10px] font-medium bg-orange-500 text-white'
        : 'flex-1 px-2 py-1 rounded text-[10px] font-medium bg-gray-100 text-gray-600 hover:bg-gray-200';
    }
  });
  renderMapOrderList();
}

// Render Order List in Sidebar
function renderMapOrderList() {
  const listEl = document.getElementById('mapOrderList');
  if (!listEl) return;
  
  let orders = window._mapAllOrders || [];
  const filter = window._mapOrderFilter || 'active';
  
  if (filter === 'pending') {
    orders = orders.filter(o => MAP_PENDING_NO_DRIVER_STATUSES.includes(o.status) && !o.driver_id);
  } else if (filter === 'active') {
    orders = orders.filter(o => !MAP_PENDING_NO_DRIVER_STATUSES.includes(o.status) || o.driver_id);
  }
  
  if (!orders.length) {
    listEl.innerHTML = '<p class="text-gray-400 text-xs text-center py-4">ไม่มีออเดอร์</p>';
    return;
  }
  
  listEl.innerHTML = orders.map(o => {
    const isPending = MAP_PENDING_NO_DRIVER_STATUSES.includes(o.status) && !o.driver_id;
    const isDispatchable = MAP_DISPATCHABLE_STATUSES.includes(o.status) && !o.driver_id;
    const canAdminAccept = _canAdminMerchantAccept(o);
    const canAdminReady = _canAdminMarkFoodReady(o);
    const hasLoc = o.origin_lat && o.origin_lng;
    const timeDiff = _timeAgo(o.created_at);

    const isAuto = _autoDispatchIsEligible(o);
    const left = isAuto ? _autoDispatchSecondsLeft(o.id) : null;
    const countdownBadge = isAuto && left !== null
      ? `<span class="px-1.5 py-0.5 rounded text-[9px] font-bold bg-purple-100 text-purple-700">⏳ ${left}s</span>`
      : '';
    
    return `
      <div class="flex flex-col gap-1 px-3 py-2 rounded-lg border ${isPending ? 'border-red-200 bg-red-50' : 'border-gray-100 bg-white'} hover:shadow-sm transition-shadow">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-1.5">
            <span class="text-xs">${serviceIcon(o.service_type)}</span>
            <span class="text-xs font-bold text-gray-800">#${o.id.substring(0,8)}</span>
            <span class="px-1.5 py-0.5 rounded text-[9px] font-medium ${getStatusStyle(o.status)}">${getStatusText(o.status)}</span>
            ${countdownBadge}
          </div>
          <span class="text-[10px] font-bold text-green-600">฿${fmt(Math.round(o.price||0))}</span>
        </div>
        <div class="flex items-center justify-between">
          <div class="flex-1 min-w-0">
            <p class="text-[10px] text-gray-500 truncate">📍 ${o.pickup_address || '-'}</p>
            ${o.driverName ? `<p class="text-[10px] text-blue-600">🏍 ${o.driverName}</p>` : ''}
            ${o.merchantName ? `<p class="text-[10px] text-orange-600">🏪 ${o.merchantName}</p>` : ''}
            <p class="text-[9px] text-gray-400">${timeDiff}</p>
          </div>
          <div class="flex items-center gap-1 flex-shrink-0 flex-wrap justify-end">
            ${hasLoc ? `<button onclick="zoomToOrder(${o.origin_lat},${o.origin_lng},'${o.id.substring(0,8)}')" class="p-1 text-gray-400 hover:text-blue-500" title="ดูบนแผนที่"><span class="material-icons-round text-sm">my_location</span></button>` : ''}
            ${isDispatchable ? `<button onclick="showOrderDispatchModal('${o.id}')" class="px-2 py-0.5 bg-blue-500 text-white rounded text-[10px] font-medium hover:bg-blue-600">โยนงาน</button>` : (o.driver_id ? `<button onclick="showReassignDriverModal('${o.id}')" class="px-2 py-0.5 bg-amber-500 text-white rounded text-[10px] font-medium hover:bg-amber-600" title="ย้ายคนขับ">ย้าย</button>` : '')}
            ${canAdminAccept ? `<button onclick="adminMerchantAcceptOrder('${o.id}')" class="px-2 py-0.5 bg-emerald-500 text-white rounded text-[10px] font-medium hover:bg-emerald-600">รับแทนร้าน</button>` : ''}
            ${canAdminReady ? `<button onclick="adminMarkFoodReady('${o.id}')" class="px-2 py-0.5 bg-teal-500 text-white rounded text-[10px] font-medium hover:bg-teal-600">อาหารพร้อม</button>` : ''}
          </div>
        </div>
      </div>`;
  }).join('');
}

function _timeAgo(dateStr) {
  if (!dateStr) return '';
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return 'เมื่อสักครู่';
  if (mins < 60) return `${mins} นาทีที่แล้ว`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs} ชั่วโมงที่แล้ว`;
  return `${Math.floor(hrs / 24)} วันที่แล้ว`;
}

function zoomToOrder(lat, lng, orderId) {
  if (!_mapInstance) return;
  _mapInstance.setView([lat, lng], 16, { animate: true });
  // Open popup for matching order marker
  window._mapOrderMarkers.forEach(m => {
    const pos = m.getLatLng();
    if (Math.abs(pos.lat - lat) < 0.001 && Math.abs(pos.lng - lng) < 0.001) m.openPopup();
  });
}

// Dispatch order from order list (shows available drivers)
function showOrderDispatchModal(orderId) {
  const order = (window._mapAllOrders || []).find(o => o.id === orderId);
  if (!order) return alert('ไม่พบออเดอร์');
  if (_canAdminMerchantAccept(order)) {
    alert('ออเดอร์นี้ยังรอร้านค้ารับ กรุณากด "รับแทนร้าน" ก่อนโยนงานให้คนขับ');
    return;
  }
  const availableDrivers = (window._mapDriverData || []).filter(d => d.isOnline && d.jobCount === 0);
  if (!availableDrivers.length) return alert('ไม่มีคนขับว่างในขณะนี้');
  
  const modal = document.createElement('div');
  modal.id = 'dispatchModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-md mx-4 fade-in">
      <div class="px-6 py-4 border-b border-gray-100">
        <div class="flex items-center justify-between">
          <div>
            <h3 class="font-bold text-gray-800">โยนงาน #${orderId.substring(0,8)}</h3>
            <p class="text-xs text-gray-500 mt-1">${serviceIcon(order.service_type)} ${getStatusText(order.status)} • ฿${fmt(Math.round(order.price||0))}</p>
            <p class="text-xs text-gray-400 mt-0.5">📍 ${order.pickup_address || '-'}</p>
          </div>
          <button onclick="document.getElementById('dispatchModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
        </div>
      </div>
      <div class="p-4">
        <p class="text-xs font-medium text-gray-600 mb-2">เลือกคนขับ (${availableDrivers.length} คนว่าง)</p>
        <div class="max-h-[50vh] overflow-y-auto space-y-2">
          ${availableDrivers.map(d => `
            <div class="flex items-center justify-between p-3 rounded-lg border border-gray-100 hover:bg-blue-50 cursor-pointer transition-colors" onclick="dispatchOrderToDriver('${orderId}','${d.id}','${d.name.replace(/'/g,'')}')">
              <div class="flex items-center gap-2">
                <span class="w-2.5 h-2.5 rounded-full bg-green-500"></span>
                <div>
                  <p class="text-sm font-medium">${d.name}</p>
                  <p class="text-[10px] text-gray-400">${d.plate} • ${d.phone}</p>
                </div>
              </div>
              <span class="material-icons-round text-blue-500 text-sm">send</span>
            </div>
          `).join('')}
        </div>
      </div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });
}

function showMapDispatchModal(driverId, driverName) {
  const orders = window._mapPendingOrders || [];
  if (!orders.length) return alert('ไม่มีออเดอร์รอคนขับ');
  const modal = document.createElement('div');
  modal.id = 'dispatchModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-md mx-4 fade-in">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <div>
          <h3 class="font-bold text-gray-800">โยนงานให้ ${driverName}</h3>
          <p class="text-xs text-gray-500 mt-1">เลือกออเดอร์ที่ต้องการมอบหมาย</p>
        </div>
        <button onclick="document.getElementById('dispatchModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-4 max-h-[50vh] overflow-y-auto space-y-2">
        ${orders.map(o => `
          <div class="flex items-center justify-between p-3 rounded-lg border border-gray-100 hover:bg-blue-50 cursor-pointer transition-colors" onclick="dispatchOrderToDriver('${o.id}','${driverId}','${driverName.replace(/'/g,'')}')">
            <div>
              <p class="text-sm font-medium">${serviceIcon(o.service_type)} #${o.id.substring(0,8)}</p>
              <p class="text-xs text-gray-500">${o.pickup_address || '-'}</p>
            </div>
            <div class="text-right">
              <p class="font-bold text-sm">฿${fmt(Math.round(o.price||0))}</p>
              <span class="px-1.5 py-0.5 rounded text-[9px] font-medium ${getStatusStyle(o.status)}">${getStatusText(o.status)}</span>
            </div>
          </div>
        `).join('')}
      </div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });
}

async function dispatchOrderToDriver(orderId, driverId, driverName) {
  if (!confirm(`มอบหมายออเดอร์ #${orderId.substring(0,8)} ให้ "${driverName}" ?`)) return;
  try {
    await _applyAdminOrderReassign(orderId, driverId, { status: 'driver_accepted' });
    document.getElementById('dispatchModal')?.remove();
    showToast('มอบหมายงานสำเร็จ!', 'success');
    refreshMapData();
  } catch(e) { showToast('เกิดข้อผิดพลาด: ' + (e.message || JSON.stringify(e)), 'error'); }
}

// Reassign driver for an order that already has a driver
async function showReassignDriverModal(orderId) {
  const order = (window._mapAllOrders || []).find(o => o.id === orderId);
  if (!order) return alert('ไม่พบออเดอร์');
  const availableDrivers = (window._mapDriverData || []).filter(d => d.isOnline && d.id !== order.driver_id);
  if (!availableDrivers.length) return alert('ไม่มีคนขับออนไลน์คนอื่น');
  
  const modal = document.createElement('div');
  modal.id = 'dispatchModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-md mx-4 fade-in">
      <div class="px-6 py-4 border-b border-gray-100">
        <div class="flex items-center justify-between">
          <div>
            <h3 class="font-bold text-gray-800">ย้ายคนขับ #${orderId.substring(0,8)}</h3>
            <p class="text-xs text-gray-500 mt-1">${serviceIcon(order.service_type)} ${getStatusText(order.status)} • ฿${fmt(Math.round(order.price||0))}</p>
            ${order.driverName ? `<p class="text-xs text-blue-600 mt-0.5">🏍 คนขับปัจจุบัน: ${order.driverName}</p>` : ''}
          </div>
          <button onclick="document.getElementById('dispatchModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
        </div>
      </div>
      <div class="p-4">
        <p class="text-xs font-medium text-gray-600 mb-2">เลือกคนขับใหม่ (${availableDrivers.length} คนออนไลน์)</p>
        <div class="max-h-[50vh] overflow-y-auto space-y-2">
          ${availableDrivers.map(d => `
            <div class="flex items-center justify-between p-3 rounded-lg border border-gray-100 hover:bg-amber-50 cursor-pointer transition-colors" onclick="reassignOrderToDriver('${orderId}','${d.id}','${d.name.replace(/'/g,'')}')">
              <div class="flex items-center gap-2">
                <span class="w-2.5 h-2.5 rounded-full ${d.jobCount > 0 ? 'bg-blue-500' : 'bg-green-500'}"></span>
                <div>
                  <p class="text-sm font-medium">${d.name}</p>
                  <p class="text-[10px] text-gray-400">${d.plate} • ${d.phone} ${d.jobCount > 0 ? '• งาน '+d.jobCount : '• ว่าง'}</p>
                </div>
              </div>
              <span class="material-icons-round text-amber-500 text-sm">swap_horiz</span>
            </div>
          `).join('')}
        </div>
      </div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });
}

async function reassignOrderToDriver(orderId, newDriverId, newDriverName) {
  if (!confirm(`ย้ายออเดอร์ #${orderId.substring(0,8)} ให้ "${newDriverName}" ?`)) return;
  try {
    await _applyAdminOrderReassign(orderId, newDriverId);
    document.getElementById('dispatchModal')?.remove();
    showToast('ย้ายคนขับสำเร็จ!', 'success');
    refreshMapData();
  } catch(e) { showToast('เกิดข้อผิดพลาด: ' + (e.message || JSON.stringify(e)), 'error'); }
}

// ============================================
// Driver Detail Modal
// ============================================
async function showDriverDetail(id) {
  const { data: d } = await supabase.from('profiles').select('*').eq('id', id).single();
  if (!d) return alert('ไม่พบข้อมูลคนขับ');
  // Get wallet balance
  let walletBal = 0;
  try {
    const { data: w } = await supabase.from('wallets').select('balance').eq('user_id', id).maybeSingle();
    if (w) walletBal = w.balance || 0;
  } catch(e) {}
  // Get completed jobs count
  let jobCount = 0;
  try {
    const { count } = await supabase.from('bookings').select('id', { count: 'exact', head: true }).eq('driver_id', id).eq('status', 'completed');
    jobCount = count || 0;
  } catch(e) {}

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
        <!-- Basic Info -->
        <div class="grid grid-cols-2 gap-4">
          <div class="bg-gray-50 rounded-lg p-3">
            <p class="text-xs text-gray-500">ชื่อ-นามสกุล</p>
            <p class="font-semibold">${d.full_name || '-'}</p>
          </div>
          <div class="bg-gray-50 rounded-lg p-3">
            <p class="text-xs text-gray-500">เบอร์โทร</p>
            <p class="font-semibold">${d.phone_number || '-'}</p>
          </div>
          <div class="bg-gray-50 rounded-lg p-3">
            <p class="text-xs text-gray-500">ทะเบียนรถ</p>
            <p class="font-semibold">${d.license_plate || '-'}</p>
          </div>
          <div class="bg-gray-50 rounded-lg p-3">
            <p class="text-xs text-gray-500">ประเภทรถ</p>
            <p class="font-semibold">${d.vehicle_type || '-'}</p>
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
        <!-- Bank Info -->
        <div class="border-t pt-4">
          <h4 class="font-bold text-sm text-gray-700 mb-2">ข้อมูลธนาคาร</h4>
          <div class="grid grid-cols-3 gap-3">
            <div class="bg-gray-50 rounded-lg p-3">
              <p class="text-xs text-gray-500">ธนาคาร</p>
              <p class="font-medium text-sm">${d.bank_name || '-'}</p>
            </div>
            <div class="bg-gray-50 rounded-lg p-3">
              <p class="text-xs text-gray-500">เลขบัญชี</p>
              <p class="font-mono text-sm">${d.bank_account_number || '-'}</p>
            </div>
            <div class="bg-gray-50 rounded-lg p-3">
              <p class="text-xs text-gray-500">ชื่อบัญชี</p>
              <p class="font-medium text-sm">${d.bank_account_name || '-'}</p>
            </div>
          </div>
        </div>
        <!-- Document Photos -->
        <div class="border-t pt-4">
          <h4 class="font-bold text-sm text-gray-700 mb-2">เอกสาร / รูปถ่าย</h4>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-3">
            ${['id_card_url','driver_license_url','vehicle_registration_url','vehicle_plate'].map(field => {
              const labels = { id_card_url:'บัตรประชาชน', driver_license_url:'ใบขับขี่', vehicle_registration_url:'รูปรถ/ทะเบียนรถ', vehicle_plate:'ป้ายทะเบียน' };
              const url = d[field];
              return `<div class="text-center">
                <p class="text-xs text-gray-500 mb-1">${labels[field]}</p>
                ${url ? `<img src="${url}" class="w-full h-24 object-cover rounded-lg border cursor-pointer" onclick="window.open('${url}','_blank')" />` : '<div class="w-full h-24 bg-gray-100 rounded-lg flex items-center justify-center"><span class="material-icons-round text-gray-300 text-2xl">image_not_supported</span></div>'}
              </div>`;
            }).join('')}
          </div>
        </div>
        <!-- Registration Date -->
        <div class="border-t pt-4 flex items-center justify-between text-sm text-gray-500">
          <span>สมัครเมื่อ: ${fmtDate(d.created_at)}</span>
          ${d.rejection_reason ? `<span class="text-red-500">เหตุผลที่ปฏิเสธ: ${d.rejection_reason}</span>` : ''}
        </div>
      </div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => { if (e.target === modal) modal.remove(); });
}

async function openDriverWalletAdjust(driverId, currentBalance = 0) {
  const amountRaw = prompt(`ยอดปัจจุบัน ฿${fmt(Math.round(currentBalance || 0))}\nกรอกจำนวนเงินที่ต้องการปรับ (+เพิ่ม / -หัก):`);
  if (amountRaw == null) return;

  const amount = parseFloat(String(amountRaw).replace(/,/g, '').trim());
  if (!Number.isFinite(amount) || amount === 0) {
    alert('กรุณากรอกจำนวนเงินที่ถูกต้อง (และต้องไม่เป็น 0)');
    return;
  }

  const reason = prompt('เหตุผลการปรับยอด (เช่น คนขับชำระเงินสด):') || 'Admin wallet adjustment';

  try {
    let { data: wallet, error: walletErr } = await supabase
      .from('wallets')
      .select('id, balance')
      .eq('user_id', driverId)
      .maybeSingle();

    if (walletErr) throw walletErr;

    if (!wallet) {
      const { data: newWallet, error: createErr } = await supabase
        .from('wallets')
        .insert({ user_id: driverId, balance: 0 })
        .select('id, balance')
        .single();
      if (createErr) throw createErr;
      wallet = newWallet;
    }

    const before = wallet.balance || 0;
    const after = before + amount;
    if (after < 0 && !confirm(`ยอดคงเหลือใหม่จะติดลบ (฿${fmt(Math.round(after))}) ต้องการทำต่อหรือไม่?`)) {
      return;
    }

    const { error: updateErr } = await supabase
      .from('wallets')
      .update({ balance: after, updated_at: new Date().toISOString() })
      .eq('id', wallet.id);
    if (updateErr) throw updateErr;

    const { error: txErr } = await supabase.from('wallet_transactions').insert({
      wallet_id: wallet.id,
      amount,
      type: 'admin_adjustment',
      description: `${reason} (Admin ปรับยอดจาก ฿${fmt(Math.round(before))} เป็น ฿${fmt(Math.round(after))})`,
    });
    if (txErr) throw txErr;

    showToast(`ปรับยอด Wallet สำเร็จ (${amount > 0 ? '+' : ''}${fmt(Math.round(amount))})`, 'success');
    document.getElementById('driverDetailModal')?.remove();
    await showDriverDetail(driverId);
  } catch (e) {
    showToast('ปรับยอด Wallet ไม่สำเร็จ: ' + (e.message || JSON.stringify(e)), 'error');
  }
}

// ============================================
// Force Cancel Order (with refund)
// ============================================
async function forceCancelOrder(orderId, customerId, price) {
  const reason = prompt('เหตุผลที่ยกเลิก (ฉุกเฉิน):');
  if (!reason) return;
  const doRefund = confirm('คืนเงินเข้า Wallet ลูกค้าด้วยหรือไม่?');
  try {
    // Update booking status
    const { error: cancelErr } = await supabase.from('bookings').update({
      status: 'cancelled',
      cancellation_reason: 'admin_force_cancel: ' + reason,
      updated_at: new Date().toISOString(),
    }).eq('id', orderId);
    if (cancelErr) throw cancelErr;

    // Refund to customer wallet if requested
    if (doRefund && customerId && price > 0) {
      try {
        let { data: wallet } = await supabase.from('wallets').select('id, balance').eq('user_id', customerId).maybeSingle();
        if (!wallet) {
          const { data: newW } = await supabase.from('wallets').insert({ user_id: customerId, balance: 0 }).select().single();
          wallet = newW;
        }
        if (wallet) {
          await supabase.from('wallets').update({ balance: (wallet.balance || 0) + price }).eq('id', wallet.id);
          await supabase.from('wallet_transactions').insert({
            wallet_id: wallet.id,
            amount: price,
            type: 'refund',
            description: 'คืนเงินจากยกเลิกออเดอร์ #' + orderId.substring(0,8) + ' (Admin)',
          });
        }
      } catch(e) { console.error('Refund error:', e); }
    }
    alert('ยกเลิกออเดอร์สำเร็จ!' + (doRefund ? ' (คืนเงินแล้ว)' : ''));
    loadOrders();
  } catch(e) { alert('เกิดข้อผิดพลาด: ' + e.message); }
}

// ============================================
// Re-broadcast Order (reset to pending so all drivers see it)
// ============================================
async function rebroadcastOrder(orderId, serviceType) {
  if (!confirm(`โยนออเดอร์ #${orderId.substring(0,8)} ใหม่?\n\nระบบจะลบคนขับเดิมออก แล้วโยนออเดอร์ให้คนขับทุกคนเห็นอีกครั้ง`)) return;
  try {
    // Determine the correct initial status based on service type
    // food → pending_merchant (needs merchant to accept first)
    // ride/parcel → pending (goes directly to drivers)
    const resetStatus = serviceType === 'food' ? 'pending_merchant' : 'pending';

    const { error } = await supabase.from('bookings').update({
      driver_id: null,
      status: resetStatus,
      assigned_at: null,
      updated_at: new Date().toISOString(),
    }).eq('id', orderId);
    if (error) throw error;

    showToast('โยนออเดอร์ใหม่สำเร็จ! คนขับทุกคนจะเห็นออเดอร์นี้', 'success');
    loadOrders();
  } catch(e) { showToast('เกิดข้อผิดพลาด: ' + (e.message || JSON.stringify(e)), 'error'); }
}

// ============================================
// Manual Top-up (Admin adds money to driver/merchant wallet)
// ============================================
async function showManualTopup() {
  const userId = prompt('กรอก User ID ที่ต้องการเติมเงิน:');
  if (!userId) return;
  const amount = parseFloat(prompt('จำนวนเงินที่ต้องการเติม (฿):'));
  if (!amount || amount <= 0) return alert('จำนวนเงินไม่ถูกต้อง');
  const desc = prompt('เหตุผล/หมายเหตุ:') || 'Admin เติมเงินด้วยมือ';
  try {
    let { data: wallet } = await supabase.from('wallets').select('id, balance').eq('user_id', userId).maybeSingle();
    if (!wallet) {
      const { data: newW } = await supabase.from('wallets').insert({ user_id: userId, balance: 0 }).select().single();
      wallet = newW;
    }
    if (!wallet) throw new Error('ไม่สามารถสร้าง wallet ได้');
    await supabase.from('wallets').update({ balance: (wallet.balance || 0) + amount }).eq('id', wallet.id);
    await supabase.from('wallet_transactions').insert({
      wallet_id: wallet.id, amount, type: 'topup',
      description: desc + ' (Admin Manual)',
    });
    alert(`เติมเงิน ฿${fmt(amount)} สำเร็จ!`);
    refreshCurrentPage();
  } catch(e) { alert('เกิดข้อผิดพลาด: ' + e.message); }
}

// ============================================
// Withdrawal Slip Upload on Approve
// ============================================
async function approveWithdrawalWithSlip(id) {
  if (!confirm('อนุมัติการถอนเงินนี้?')) return;
  // Create file input for slip upload
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
        const { error } = await supabaseAdmin.storage.from('admin-uploads').upload(path, file);
        if (!error) {
          const { data: urlData } = supabaseAdmin.storage.from('admin-uploads').getPublicUrl(path);
          slipUrl = urlData?.publicUrl;
        }
      } catch(err) { console.error('Slip upload error:', err); }
    }
    await supabase.from('withdrawal_requests').update({
      status: 'completed',
      processed_at: new Date().toISOString(),
      transfer_slip_url: slipUrl,
    }).eq('id', id);
    alert('อนุมัติสำเร็จ!' + (slipUrl ? ' (แนบสลิปแล้ว)' : ''));
    refreshCurrentPage();
  };
  // If user cancels file picker, still approve without slip
  fileInput.click();
  setTimeout(() => {
    if (!fileInput.value) {
      // User might have cancelled - do nothing, they can click approve again
    }
  }, 500);
}

// ============================================
// Banners Management
// ============================================
window._bannerFilter = 'all';
window._allBanners = [];

const BANNER_PAGE_LABELS = { home: '🏠 หน้าแรก', food: '🍔 สั่งอาหาร', ride: '🚗 เรียกรถ', parcel: '📦 ส่งพัสดุ' };

function filterBanners(page) {
  window._bannerFilter = page;
  ['all','home','food','ride','parcel'].forEach(f => {
    const btn = document.getElementById('bannerFilter' + f.charAt(0).toUpperCase() + f.slice(1));
    if (btn) {
      btn.className = f === page
        ? 'px-3.5 py-1.5 text-white rounded-xl text-xs font-semibold'
        : 'px-3.5 py-1.5 bg-gray-100 text-gray-600 rounded-xl text-xs font-semibold hover:bg-gray-200 transition-colors';
      btn.style.background = f === page ? 'linear-gradient(135deg,#6366f1,#818cf8)' : '';
    }
  });
  renderBannerList();
}

function renderBannerList() {
  const el = document.getElementById('bannerList');
  if (!el) return;
  let banners = window._allBanners || [];
  if (window._bannerFilter !== 'all') {
    banners = banners.filter(b => (b.page || 'home') === window._bannerFilter);
  }
  if (!banners.length) {
    el.innerHTML = '<p class="text-gray-400 text-sm text-center py-4">ยังไม่มี Banner' + (window._bannerFilter !== 'all' ? ' ในหน้านี้' : '') + '</p>';
    return;
  }
  el.innerHTML = banners.map(b => {
    const pageLabel = BANNER_PAGE_LABELS[b.page || 'home'] || '🏠 หน้าแรก';
    const isGif = (b.image_url || '').toLowerCase().endsWith('.gif');
    const isVideo = (b.image_url || '').toLowerCase().endsWith('.mp4');
    let mediaHtml = '';
    if (isVideo) {
      mediaHtml = '<video src="' + b.image_url + '" class="w-32 h-16 object-cover rounded-lg border" muted autoplay loop></video>';
    } else {
      mediaHtml = '<img src="' + b.image_url + '" class="w-32 h-16 object-cover rounded-lg border" onerror="this.src=\'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTI4IiBoZWlnaHQ9IjY0IiB2aWV3Qm94PSIwIDAgMTI4IDY0IiBmaWxsPSJub25lIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPjxyZWN0IHdpZHRoPSIxMjgiIGhlaWdodD0iNjQiIGZpbGw9IiNGM0Y0RjYiLz48dGV4dCB4PSI2NCIgeT0iMzIiIGZvbnQtZmFtaWx5PSJBcmlhbCIgZm9udC1zaXplPSIxNCIgZmlsbD0iIzk5QTI5QSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPkJhbm5lcjwvdGV4dD48L3N2Zz4=\'" />';
    }
    return '<div class="flex items-center gap-3 p-3 ' + (b.is_active !== false ? 'bg-gray-50' : 'bg-red-50 opacity-60') + ' rounded-lg border">'
      + mediaHtml
      + '<div class="flex-1 min-w-0">'
      + '<p class="text-sm font-medium truncate">' + (b.title || 'Banner') + (isGif ? ' <span class="text-[10px] bg-purple-100 text-purple-600 px-1.5 py-0.5 rounded font-medium">GIF</span>' : '') + (isVideo ? ' <span class="text-[10px] bg-blue-100 text-blue-600 px-1.5 py-0.5 rounded font-medium">VIDEO</span>' : '') + '</p>'
      + '<p class="text-xs text-gray-400">' + (b.is_active !== false ? '🟢 แสดง' : '🔴 ซ่อน') + ' • ' + pageLabel + (b.coupon_code ? ' • 🎟️ <span class="font-mono font-semibold text-purple-600">' + b.coupon_code + '</span>' : '') + ' • ' + fmtDate(b.created_at) + '</p>'
      + '</div>'
      + '<button onclick="toggleBanner(\'' + b.id + '\',' + (b.is_active !== false) + ')" class="px-3 py-1 ' + (b.is_active !== false ? 'bg-gray-100 text-gray-600' : 'bg-green-100 text-green-700') + ' rounded-lg text-xs font-medium hover:opacity-80">' + (b.is_active !== false ? 'ซ่อน' : 'แสดง') + '</button>'
      + '<button onclick="deleteBanner(\'' + b.id + '\')" class="px-3 py-1 bg-red-100 text-red-600 rounded-lg text-xs font-medium hover:bg-red-200">ลบ</button>'
      + '</div>';
  }).join('');
}

async function loadBanners() {
  const el = document.getElementById('bannerList');
  if (!el) return;
  try {
    const { data: banners } = await supabase.from('banners').select('*').order('sort_order').order('created_at', { ascending: false });
    window._allBanners = banners || [];
    renderBannerList();
    // Populate coupon dropdown
    try {
      const { data: coupons } = await supabase.from('coupons').select('code, name, is_active, end_date').eq('is_active', true).gte('end_date', new Date().toISOString()).order('code');
      const sel = document.getElementById('bannerCoupon');
      if (sel && coupons) {
        sel.innerHTML = '<option value="">ไม่ผูกโค้ด</option>' + coupons.map(c => `<option value="${c.code}">${c.code} — ${c.name}</option>`).join('');
      }
    } catch(_) {}
  } catch(e) {
    el.innerHTML = '<p class="text-gray-400 text-sm">ไม่สามารถโหลด Banner (ตาราง banners อาจยังไม่มี)</p>';
  }
}

async function uploadBanner() {
  const fileInput = document.getElementById('bannerFileInput');
  const title = document.getElementById('bannerTitle')?.value || '';
  const page = document.getElementById('bannerPage')?.value || 'home';
  const file = fileInput?.files?.[0];
  if (!file) return alert('กรุณาเลือกรูปภาพ');
  try {
    const ext = file.name.split('.').pop();
    const path = 'banners/banner_' + Date.now() + '.' + ext;
    const { error } = await supabase.storage.from('admin-uploads').upload(path, file, { upsert: true });
    if (error) throw error;
    const { data: urlData } = supabase.storage.from('admin-uploads').getPublicUrl(path);
    const imageUrl = urlData?.publicUrl;
    if (!imageUrl) throw new Error('ไม่สามารถดึง URL ได้');
    const couponCode = document.getElementById('bannerCoupon')?.value || null;
    const insertData = {
      title: title || 'Banner',
      image_url: imageUrl,
      is_active: true,
      sort_order: 0,
    };
    // Only include optional columns if they have values (avoids 400 if columns don't exist yet)
    if (page) insertData.page = page;
    if (couponCode) insertData.coupon_code = couponCode;
    
    const { error: insertError } = await supabase.from('banners').insert(insertData);
    if (insertError) {
      console.error('Banner insert error:', insertError);
      // If column doesn't exist, retry with minimal fields
      if (insertError.message?.includes('column') || insertError.code === '42703') {
        const { error: retryError } = await supabase.from('banners').insert({
          title: title || 'Banner',
          image_url: imageUrl,
          is_active: true,
          sort_order: 0,
        });
        if (retryError) throw retryError;
      } else {
        throw insertError;
      }
    }
    fileInput.value = '';
    if (document.getElementById('bannerTitle')) document.getElementById('bannerTitle').value = '';
    showToast('อัปโหลด Banner สำเร็จ!', 'success');
    loadBanners();
  } catch(e) { console.error('Upload banner error:', e); showToast('เกิดข้อผิดพลาด: ' + (e.message || e), 'error'); }
}

async function toggleBanner(id, currentActive) {
  await supabase.from('banners').update({ is_active: !currentActive }).eq('id', id);
  showToast(currentActive ? 'ซ่อน Banner แล้ว' : 'แสดง Banner แล้ว', 'success');
  loadBanners();
}

async function deleteBanner(id) {
  if (!confirm('ลบ Banner นี้?')) return;
  await supabase.from('banners').delete().eq('id', id);
  showToast('ลบ Banner แล้ว', 'success');
  loadBanners();
}

// ============================================
// Logo & Splash Upload
// ============================================
function setLandingAssetPreview(type, imageUrl) {
  const isLogo = type === 'logo';
  const previewId = isLogo ? 'currentLandingLogo' : 'currentLandingHero';
  const hiddenInputId = isLogo ? 'settLandingLogoUrl' : 'settLandingHeroImageUrl';
  const previewEl = document.getElementById(previewId);
  const hiddenEl = document.getElementById(hiddenInputId);

  if (hiddenEl) hiddenEl.value = imageUrl || '';

  if (!previewEl) return;
  if (!imageUrl) {
    previewEl.innerHTML = isLogo
      ? '<span class="material-icons-round text-gray-200 text-3xl">image</span>'
      : '<span class="material-icons-round text-gray-200 text-3xl">landscape</span>';
    return;
  }

  previewEl.innerHTML = isLogo
    ? `<img src="${imageUrl}" class="w-24 h-24 object-contain rounded-xl border" />`
    : `<img src="${imageUrl}" class="w-full h-28 object-cover rounded-xl border" />`;
}

async function loadAppAssets() {
  try {
    const { data: config, error } = await supabase.from('system_config').select('*').maybeSingle();
    if (error || !config) return;
    if (config.logo_url) {
      const logoEl = document.getElementById('currentLogo');
      if (logoEl) logoEl.innerHTML = `<img src="${config.logo_url}" class="w-24 h-24 object-contain rounded-xl" />`;
    }
    if (config.splash_url) {
      const splashEl = document.getElementById('currentSplash');
      if (splashEl) splashEl.innerHTML = `<img src="${config.splash_url}" class="w-24 h-24 object-contain rounded-xl" />`;
    }

    const landingConfig = normalizeLandingConfig(config.landing_config);
    setLandingAssetPreview('logo', landingConfig.logo_url || config.logo_url || '');
    setLandingAssetPreview('hero', landingConfig.hero_image_url || '');
  } catch(e) { /* columns might not exist yet */ }
}

function getStatusStyle(status) {
  const styles = {
    pending: 'bg-yellow-100 text-yellow-800',
    pending_merchant: 'bg-amber-100 text-amber-800',
    preparing: 'bg-sky-100 text-sky-800',
    matched: 'bg-orange-100 text-orange-800',
    driver_accepted: 'bg-blue-100 text-blue-800',
    arrived: 'bg-purple-100 text-purple-800',
    arrived_at_merchant: 'bg-indigo-100 text-indigo-800',
    ready_for_pickup: 'bg-cyan-100 text-cyan-800',
    picking_up_order: 'bg-teal-100 text-teal-800',
    in_transit: 'bg-green-100 text-green-800',
    completed: 'bg-gray-100 text-gray-800',
    cancelled: 'bg-red-100 text-red-800',
  };
  return styles[status] || 'bg-gray-100 text-gray-800';
}

function getStatusText(status) {
  const texts = {
    pending: 'รอคนขับ',
    pending_merchant: 'รอร้านค้ารับ',
    preparing: 'กำลังเตรียมอาหาร',
    matched: 'จับคู่แล้ว',
    driver_accepted: 'รับงานแล้ว',
    arrived: 'ถึงจุดรับแล้ว',
    arrived_at_merchant: 'ถึงร้านแล้ว',
    ready_for_pickup: 'พร้อมรับสินค้า',
    picking_up_order: 'กำลังรับสินค้า',
    in_transit: 'กำลังส่ง',
    completed: 'ส่งแล้ว',
    cancelled: 'ยกเลิก',
  };
  return texts[status] || status;
}

async function uploadAppAsset(type) {
  const inputId = type === 'logo' ? 'logoFileInput' : 'splashFileInput';
  const previewId = type === 'logo' ? 'currentLogo' : 'currentSplash';
  const file = document.getElementById(inputId)?.files?.[0];
  if (!file) return alert('กรุณาเลือกรูปภาพ');
  
  // Show uploading state
  const previewEl = document.getElementById(previewId);
  if (previewEl) previewEl.innerHTML = '<div class="w-24 h-24 bg-gray-100 rounded-xl flex items-center justify-center"><div class="loader"></div></div>';
  
  try {
    const ext = file.name.split('.').pop();
    const path = `app-assets/${type}_${Date.now()}.${ext}`;
    const { error } = await supabase.storage.from('admin-uploads').upload(path, file, { upsert: true });
    if (error) throw error;
    const { data: urlData } = supabase.storage.from('admin-uploads').getPublicUrl(path);
    const imageUrl = urlData?.publicUrl;
    if (!imageUrl) throw new Error('ไม่สามารถดึง URL ได้');
    const updateField = type === 'logo' ? 'logo_url' : 'splash_url';
    const { data: cfgRow } = await supabase.from('system_config').select('id').maybeSingle();
    const cfgId = cfgRow?.id ?? 1;
    const { error: updateErr } = await supabase.from('system_config').upsert({ id: cfgId, [updateField]: imageUrl }, { onConflict: 'id' });
    if (updateErr) { console.error('Asset save error:', updateErr); throw updateErr; }
    
    // Update preview immediately
    if (previewEl) previewEl.innerHTML = `<img src="${imageUrl}" class="w-24 h-24 object-contain rounded-xl border" />`;
    document.getElementById(inputId).value = '';
    
    // Show success toast
    showToast(`อัปโหลด${type === 'logo' ? 'โลโก้' : 'Splash'}สำเร็จ!`, 'success');
  } catch(e) {
    if (previewEl) previewEl.innerHTML = '<div class="w-24 h-24 bg-red-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-red-400">error</span></div>';
    showToast('เกิดข้อผิดพลาด: ' + e.message, 'error');
  }
}

async function uploadLandingAsset(type) {
  const isLogo = type === 'logo';
  const inputId = isLogo ? 'landingLogoFileInput' : 'landingHeroFileInput';
  const previewId = isLogo ? 'currentLandingLogo' : 'currentLandingHero';
  const hiddenInputId = isLogo ? 'settLandingLogoUrl' : 'settLandingHeroImageUrl';
  const configField = isLogo ? 'logo_url' : 'hero_image_url';
  const displayName = isLogo ? 'โลโก้หน้า Landing' : 'ภาพ Hero หน้า Landing';
  const file = document.getElementById(inputId)?.files?.[0];
  if (!file) return alert('กรุณาเลือกรูปภาพ');

  const previewEl = document.getElementById(previewId);
  const previousUrl = document.getElementById(hiddenInputId)?.value || '';

  if (previewEl) {
    previewEl.innerHTML = '<div class="w-full h-full flex items-center justify-center"><div class="loader"></div></div>';
  }

  try {
    const ext = file.name.split('.').pop();
    const path = `landing-assets/${type}_${Date.now()}.${ext}`;
    const { error: uploadError } = await supabase.storage.from('admin-uploads').upload(path, file, { upsert: true });
    if (uploadError) throw uploadError;

    const { data: urlData } = supabase.storage.from('admin-uploads').getPublicUrl(path);
    const imageUrl = urlData?.publicUrl;
    if (!imageUrl) throw new Error('ไม่สามารถดึง URL ได้');

    const { data: cfgRow } = await supabase.from('system_config').select('id, landing_config').maybeSingle();
    const cfgId = cfgRow?.id ?? 1;
    const landingConfig = normalizeLandingConfig(cfgRow?.landing_config);
    landingConfig[configField] = imageUrl;

    const { error: updateErr } = await supabase.from('system_config').upsert({
      id: cfgId,
      landing_config: landingConfig,
      updated_at: new Date().toISOString(),
    }, { onConflict: 'id' });

    if (updateErr) {
      if (String(updateErr.message || '').toLowerCase().includes('landing_config')) {
        throw new Error('ยังไม่พบคอลัมน์ landing_config (กรุณารัน migration 20260307_add_landing_page_config.sql)');
      }
      throw updateErr;
    }

    setLandingAssetPreview(type, imageUrl);
    document.getElementById(inputId).value = '';
    showToast(`อัปโหลด${displayName}สำเร็จ!`, 'success');
  } catch (e) {
    setLandingAssetPreview(type, previousUrl);
    showToast('เกิดข้อผิดพลาด: ' + e.message, 'error');
  }
}

// Toast notification helper
function showToast(message, type = 'success') {
  const toast = document.createElement('div');
  const styles = {
    success: 'background:linear-gradient(135deg,#10b981,#14b8a6); color:white;',
    error: 'background:linear-gradient(135deg,#f43f5e,#ec4899); color:white;',
    info: 'background:linear-gradient(135deg,#6366f1,#818cf8); color:white;',
  };
  const icons = { success: 'check_circle', error: 'error', info: 'info' };
  toast.className = 'fixed bottom-6 right-6 z-50 fade-in';
  toast.innerHTML = `<div class="flex items-center gap-3 px-5 py-3.5 rounded-2xl shadow-2xl text-sm font-semibold" style="${styles[type] || styles.info}">
    <span class="material-icons-round text-lg">${icons[type] || 'info'}</span> ${message}
  </div>`;
  document.body.appendChild(toast);
  setTimeout(() => { toast.style.opacity = '0'; toast.style.transition = 'opacity 0.5s'; setTimeout(() => toast.remove(), 500); }, 3000);
}
