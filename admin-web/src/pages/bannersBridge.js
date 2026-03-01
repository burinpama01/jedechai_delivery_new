let _ctx = null;

function _deps() {
  const supabase = _ctx?.supabase || globalThis.supabase;
  const callAdminAction = _ctx?.callAdminAction || globalThis.callAdminAction;
  const showToast = _ctx?.showToast || globalThis.showToast;
  const escapeHtml = _ctx?.escapeHtml || globalThis.escapeHtml;
  const fmtDate = _ctx?.fmtDate || globalThis.fmtDate;

  return {
    supabase,
    callAdminAction,
    showToast,
    escapeHtml,
    fmtDate,
  };
}

const BANNER_PAGE_LABELS = { home: '🏠 หน้าแรก', food: '🍔 สั่งอาหาร', ride: '🚗 เรียกรถ', parcel: '📦 ส่งพัสดุ' };

globalThis._bannerFilter = globalThis._bannerFilter || 'all';
globalThis._allBanners = globalThis._allBanners || [];

export function filterBanners(page, ctx) {
  _ctx = ctx || _ctx;
  globalThis._bannerFilter = page;
  ['all', 'home', 'food', 'ride', 'parcel'].forEach((f) => {
    const btn = document.getElementById('bannerFilter' + f.charAt(0).toUpperCase() + f.slice(1));
    if (btn) {
      btn.className =
        f === page
          ? 'px-3.5 py-1.5 text-white rounded-xl text-xs font-semibold'
          : 'px-3.5 py-1.5 bg-gray-100 text-gray-600 rounded-xl text-xs font-semibold hover:bg-gray-200 transition-colors';
      btn.style.background = f === page ? 'linear-gradient(135deg,#6366f1,#818cf8)' : '';
    }
  });
  renderBannerList(null, ctx);
}

export function renderBannerList(_, ctx) {
  _ctx = ctx || _ctx;
  const { fmtDate } = _deps();

  const el = document.getElementById('bannerList');
  if (!el) return;

  let banners = globalThis._allBanners || [];
  if (globalThis._bannerFilter !== 'all') {
    banners = banners.filter((b) => (b.page || 'home') === globalThis._bannerFilter);
  }

  if (!banners.length) {
    el.innerHTML =
      '<p class="text-gray-400 text-sm text-center py-4">ยังไม่มี Banner' +
      (globalThis._bannerFilter !== 'all' ? ' ในหน้านี้' : '') +
      '</p>';
    return;
  }

  el.innerHTML = banners
    .map((b) => {
      const pageLabel = BANNER_PAGE_LABELS[b.page || 'home'] || '🏠 หน้าแรก';
      const isGif = (b.image_url || '').toLowerCase().endsWith('.gif');
      const isVideo = (b.image_url || '').toLowerCase().endsWith('.mp4');
      let mediaHtml = '';
      if (isVideo) {
        mediaHtml =
          '<video src="' + b.image_url + '" class="w-32 h-16 object-cover rounded-lg border" muted autoplay loop></video>';
      } else {
        mediaHtml =
          '<img src="' +
          b.image_url +
          '" class="w-32 h-16 object-cover rounded-lg border" onerror="this.src=\'data:image/svg+xml;base64,PHN2ZyB3aWR0aD0iMTI4IiBoZWlnaHQ9IjY0IiB2aWV3Qm94PSIwIDAgMTI4IDY0IiBmaWxsPSJub25lIiB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPjxyZWN0IHdpZHRoPSIxMjgiIGhlaWdodD0iNjQiIGZpbGw9IiNGM0Y0RjYiLz48dGV4dCB4PSI2NCIgeT0iMzIiIGZvbnQtZmFtaWx5PSJBcmlhbCIgZm9udC1zaXplPSIxNCIgZmlsbD0iIzk5QTI5QSIgdGV4dC1hbmNob3I9Im1pZGRsZSIgZHk9Ii4zZW0iPkJhbm5lcjwvdGV4dD48L3N2Zz4=\'" />';
      }

      return (
        '<div class="flex items-center gap-3 p-3 ' +
        (b.is_active !== false ? 'bg-gray-50' : 'bg-red-50 opacity-60') +
        ' rounded-lg border">' +
        mediaHtml +
        '<div class="flex-1 min-w-0">' +
        '<p class="text-sm font-medium truncate">' +
        (b.title || 'Banner') +
        (isGif
          ? ' <span class="text-[10px] bg-purple-100 text-purple-600 px-1.5 py-0.5 rounded font-medium">GIF</span>'
          : '') +
        (isVideo
          ? ' <span class="text-[10px] bg-blue-100 text-blue-600 px-1.5 py-0.5 rounded font-medium">VIDEO</span>'
          : '') +
        '</p>' +
        '<p class="text-xs text-gray-400">' +
        (b.is_active !== false ? '🟢 แสดง' : '🔴 ซ่อน') +
        ' • ' +
        pageLabel +
        (b.coupon_code
          ? ' • 🎟️ <span class="font-mono font-semibold text-purple-600">' + b.coupon_code + '</span>'
          : '') +
        ' • ' +
        fmtDate(b.created_at) +
        '</p>' +
        '</div>' +
        '<button onclick="toggleBanner(\'' +
        b.id +
        '\',' +
        (b.is_active !== false) +
        ')" class="px-3 py-1 ' +
        (b.is_active !== false ? 'bg-gray-100 text-gray-600' : 'bg-green-100 text-green-700') +
        ' rounded-lg text-xs font-medium hover:opacity-80">' +
        (b.is_active !== false ? 'ซ่อน' : 'แสดง') +
        '</button>' +
        '<button onclick="deleteBanner(\'' +
        b.id +
        '\')" class="px-3 py-1 bg-red-100 text-red-600 rounded-lg text-xs font-medium hover:bg-red-200">ลบ</button>' +
        '</div>'
      );
    })
    .join('');
}

export async function loadBanners(ctx) {
  _ctx = ctx || _ctx;
  const { supabase } = _deps();

  const el = document.getElementById('bannerList');
  if (!el) return;

  try {
    const { data: banners } = await supabase
      .from('banners')
      .select('*')
      .order('sort_order')
      .order('created_at', { ascending: false });

    globalThis._allBanners = banners || [];
    renderBannerList(null, ctx);

    try {
      const { data: coupons } = await supabase
        .from('coupons')
        .select('code, name, is_active, end_date')
        .eq('is_active', true)
        .gte('end_date', new Date().toISOString())
        .order('code');
      const sel = document.getElementById('bannerCoupon');
      if (sel && coupons) {
        sel.innerHTML =
          '<option value="">ไม่ผูกโค้ด</option>' +
          coupons.map((c) => `<option value="${c.code}">${c.code} — ${c.name}</option>`).join('');
      }
    } catch (_) {}
  } catch (e) {
    el.innerHTML = '<p class="text-gray-400 text-sm">ไม่สามารถโหลด Banner (ตาราง banners อาจยังไม่มี)</p>';
  }
}

export async function uploadBanner(ctx) {
  _ctx = ctx || _ctx;
  const { supabase, callAdminAction, showToast } = _deps();

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

    if (page) insertData.page = page;
    if (couponCode) insertData.coupon_code = couponCode;

    await callAdminAction({ action: 'create_banner', banner_data: insertData });

    fileInput.value = '';
    if (document.getElementById('bannerTitle')) document.getElementById('bannerTitle').value = '';
    showToast('อัปโหลด Banner สำเร็จ!', 'success');
    loadBanners(ctx);
  } catch (e) {
    try {
      console.error('Upload banner error:', e);
    } catch (_) {}
    showToast('เกิดข้อผิดพลาด: ' + (e?.message || e), 'error');
  }
}

export async function toggleBanner(id, currentActive, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml } = _deps();

  try {
    await callAdminAction({ action: 'toggle_banner', id, is_active: !currentActive });
    showToast(currentActive ? 'ซ่อน Banner แล้ว' : 'แสดง Banner แล้ว', 'success');
    loadBanners(ctx);
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function deleteBanner(id, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml } = _deps();

  if (!confirm('ลบ Banner นี้?')) return;
  try {
    await callAdminAction({ action: 'delete_banner', id });
    showToast('ลบ Banner แล้ว', 'success');
    loadBanners(ctx);
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export function wireBannersBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  globalThis.__adminWebBridge.filterBanners = filterBanners;
  globalThis.__adminWebBridge.renderBannerList = renderBannerList;
  globalThis.__adminWebBridge.loadBanners = loadBanners;
  globalThis.__adminWebBridge.uploadBanner = uploadBanner;
  globalThis.__adminWebBridge.toggleBanner = toggleBanner;
  globalThis.__adminWebBridge.deleteBanner = deleteBanner;
}
