// โฆษณาในแอพ (ตาราง banners) — ลูกค้า / คนขับ / ร้านค้า · แผน: Plan/In_App_Ads_Plan_v1.html
import {
  AD_ACTION_LABELS,
  AD_AUDIENCES,
  AD_FORMAT_LABELS,
  AD_PLACEMENTS,
  AD_POPUP_FREQUENCY_LABELS,
  AD_SCREENS,
  adStatus,
  isoToLocalInput,
  localInputToIso,
  placementOf,
} from './bannerAdsConfig.js';
import { compressImageIfNeeded } from './imageCompress.js';

let _ctx = null;

function _deps() {
  // app.legacy.js เรียก bridge โดยไม่ส่ง ctx และ `supabase` ของ legacy เป็น `let` (ไม่อยู่บน globalThis)
  // → ใช้ ctx ที่ settingsPage เก็บไว้ใน __adminWebContext ตอน render
  const ctx = _ctx || globalThis.__adminWebContext || {};
  const supabase = ctx.supabase || globalThis.supabase;
  const callAdminAction = ctx.callAdminAction || globalThis.callAdminAction;
  const showToast = ctx.showToast || globalThis.showToast;
  const escapeHtml = ctx.escapeHtml || globalThis.escapeHtml || _escape;
  const fmtDate = ctx.fmtDate || globalThis.fmtDate || ((d) => d || '');

  return {
    supabase,
    callAdminAction,
    showToast,
    escapeHtml,
    fmtDate,
  };
}

function _escape(s) {
  return String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c]);
}

const MAX_IMAGE_BYTES = 2 * 1024 * 1024;
const FILTERS = ['all', 'customer', 'driver', 'merchant'];
const STATUS_BADGE = {
  live: ['🟢 กำลังแสดง', 'bg-green-100 text-green-700'],
  scheduled: ['🕒 รอเริ่ม', 'bg-amber-100 text-amber-700'],
  expired: ['⌛ หมดเวลา', 'bg-gray-200 text-gray-600'],
  off: ['🔴 ปิด', 'bg-red-100 text-red-600'],
};

globalThis._bannerFilter = FILTERS.includes(globalThis._bannerFilter) ? globalThis._bannerFilter : 'all';
globalThis._allBanners = globalThis._allBanners || [];
globalThis._bannerEditingId = globalThis._bannerEditingId || null;
let _activeCoupons = [];

const $ = (id) => document.getElementById(id);

export function filterBanners(audience, ctx) {
  _ctx = ctx || _ctx;
  globalThis._bannerFilter = FILTERS.includes(audience) ? audience : 'all';
  FILTERS.forEach((f) => {
    const btn = $('bannerFilter' + f.charAt(0).toUpperCase() + f.slice(1));
    if (btn) {
      btn.className =
        f === globalThis._bannerFilter
          ? 'px-3.5 py-1.5 text-white rounded-xl text-xs font-semibold'
          : 'px-3.5 py-1.5 bg-gray-100 text-gray-600 rounded-xl text-xs font-semibold hover:bg-gray-200 transition-colors';
      btn.style.background = f === globalThis._bannerFilter ? 'linear-gradient(135deg,#6366f1,#818cf8)' : '';
    }
  });
  renderBannerList(null, ctx);
}

function _actionSummary(b, esc) {
  const type = b.action_type || (b.coupon_code ? 'coupon' : 'none');
  if (type === 'coupon' && b.coupon_code) {
    return '🎟️ <span class="font-mono font-semibold text-purple-600">' + esc(b.coupon_code) + '</span>';
  }
  if (type === 'url' && b.action_value) {
    return '🔗 <span class="text-blue-600">' + esc(b.action_value) + '</span>';
  }
  if (type === 'screen' && b.action_value) {
    const aud = placementOf(b.page).audience;
    return '📱 ' + esc(AD_SCREENS[aud]?.[b.action_value] || b.action_value);
  }
  return '';
}

function _scheduleSummary(b, fmtDate) {
  if (!b.starts_at && !b.ends_at) return 'แสดงตลอด';
  return (b.starts_at ? fmtDate(b.starts_at) : 'ตอนนี้') + ' → ' + (b.ends_at ? fmtDate(b.ends_at) : 'ไม่กำหนด');
}

export function renderBannerList(_, ctx) {
  _ctx = ctx || _ctx;
  const { fmtDate, escapeHtml: esc } = _deps();

  const el = $('bannerList');
  if (!el) return;

  let banners = globalThis._allBanners || [];
  if (globalThis._bannerFilter !== 'all') {
    banners = banners.filter((b) => placementOf(b.page).audience === globalThis._bannerFilter);
  }

  if (!banners.length) {
    el.innerHTML =
      '<p class="text-gray-400 text-sm text-center py-4">ยังไม่มีโฆษณา' +
      (globalThis._bannerFilter !== 'all' ? 'ของ' + AD_AUDIENCES[globalThis._bannerFilter] : '') +
      '</p>';
    return;
  }

  el.innerHTML = banners
    .map((b) => {
      const p = placementOf(b.page);
      const status = adStatus(b);
      const [statusText, statusCls] = STATUS_BADGE[status];
      const isActive = b.is_active !== false;
      const action = _actionSummary(b, esc);
      const id = esc(b.id);
      return (
        '<div class="flex flex-wrap md:flex-nowrap items-center gap-3 p-3 ' +
        (status === 'live' ? 'bg-gray-50' : 'bg-gray-50 opacity-70') +
        ' rounded-lg border">' +
        '<img src="' + esc(b.image_url) + '" alt="" class="w-32 h-16 object-cover rounded-lg border bg-gray-100" />' +
        '<div class="flex-1 min-w-0">' +
        '<p class="text-sm font-medium truncate">' + esc(b.title || 'Banner') + '</p>' +
        '<p class="text-xs text-gray-500 flex flex-wrap gap-x-2 gap-y-0.5 items-center">' +
        '<span class="px-1.5 py-0.5 rounded ' + statusCls + '">' + statusText + '</span>' +
        '<span>' + esc(AD_AUDIENCES[p.audience]) + ' · ' + esc(p.label) + '</span>' +
        (action ? '<span class="truncate max-w-[16rem]">' + action + '</span>' : '') +
        '</p>' +
        '<p class="text-[11px] text-gray-400">🗓️ ' + esc(_scheduleSummary(b, fmtDate)) +
        (p.format === 'popup' ? ' · ' + esc(AD_POPUP_FREQUENCY_LABELS[b.popup_frequency] || '') : '') +
        ' · ลำดับ ' + esc(b.sort_order ?? 0) + '</p>' +
        '</div>' +
        '<div class="flex gap-1.5">' +
        '<button data-ad-edit="' + id + '" class="px-3 py-1 bg-indigo-50 text-indigo-600 rounded-lg text-xs font-medium hover:bg-indigo-100">แก้ไข</button>' +
        '<button data-ad-toggle="' + id + '" data-ad-active="' + isActive + '" class="px-3 py-1 ' +
        (isActive ? 'bg-gray-100 text-gray-600' : 'bg-green-100 text-green-700') +
        ' rounded-lg text-xs font-medium hover:opacity-80">' + (isActive ? 'ปิด' : 'เปิด') + '</button>' +
        '<button data-ad-delete="' + id + '" class="px-3 py-1 bg-red-100 text-red-600 rounded-lg text-xs font-medium hover:bg-red-200">ลบ</button>' +
        '</div>' +
        '</div>'
      );
    })
    .join('');

  el.querySelectorAll('[data-ad-edit]').forEach((btn) => {
    btn.addEventListener('click', () => editBanner(btn.getAttribute('data-ad-edit')));
  });
  el.querySelectorAll('[data-ad-toggle]').forEach((btn) => {
    btn.addEventListener('click', () =>
      toggleBanner(btn.getAttribute('data-ad-toggle'), btn.getAttribute('data-ad-active') === 'true'),
    );
  });
  el.querySelectorAll('[data-ad-delete]').forEach((btn) => {
    btn.addEventListener('click', () => deleteBanner(btn.getAttribute('data-ad-delete')));
  });
}

// ─── ฟอร์ม ─────────────────────────────────────────────

function _fillSelect(sel, entries, selected) {
  if (!sel) return;
  sel.innerHTML = entries
    .map(([v, label]) => '<option value="' + _escape(v) + '"' + (v === selected ? ' selected' : '') + '>' + _escape(label) + '</option>')
    .join('');
}

function _show(id, visible) {
  const el = $(id);
  if (el) el.classList.toggle('hidden', !visible);
}

/** จัดตัวเลือกให้ตรงกับฝั่ง/ตำแหน่ง/ประเภทการกดที่เลือกอยู่ */
export function onBannerFormChange() {
  const audience = $('bannerAudience')?.value || 'customer';

  const pageSel = $('bannerPage');
  const pages = Object.entries(AD_PLACEMENTS)
    .filter(([, p]) => p.audience === audience)
    .map(([k, p]) => [k, p.label]);
  const curPage = pages.some(([k]) => k === pageSel?.value) ? pageSel.value : pages[0]?.[0];
  _fillSelect(pageSel, pages, curPage);

  // คูปองใช้ได้เฉพาะลูกค้า
  const actionSel = $('bannerAction');
  const actions = Object.entries(AD_ACTION_LABELS).filter(([k]) => k !== 'coupon' || audience === 'customer');
  const curAction = actions.some(([k]) => k === actionSel?.value) ? actionSel.value : 'none';
  _fillSelect(actionSel, actions, curAction);

  const screenSel = $('bannerScreen');
  const screens = Object.entries(AD_SCREENS[audience] || {});
  const curScreen = screens.some(([k]) => k === screenSel?.value) ? screenSel.value : screens[0]?.[0];
  _fillSelect(screenSel, screens, curScreen);

  _show('bannerCouponWrap', curAction === 'coupon');
  _show('bannerUrlWrap', curAction === 'url');
  _show('bannerScreenWrap', curAction === 'screen');
  _show('bannerPopupFreqWrap', AD_PLACEMENTS[curPage]?.format === 'popup');

  const hint = $('bannerSizeHint');
  if (hint) {
    const fmt = AD_PLACEMENTS[curPage]?.format;
    hint.textContent =
      fmt === 'popup' ? 'ป๊อปอัป: แนะนำรูปแนวตั้ง 4:5 (เช่น 1080×1350)'
        : fmt === 'card' ? 'การ์ด: แนะนำรูป 3:1 (เช่น 1200×400)'
          : 'สไลด์: แนะนำรูป 16:9 (เช่น 1280×720)';
  }
}

function _resetForm() {
  globalThis._bannerEditingId = null;
  ['bannerFileInput', 'bannerTitle', 'bannerUrl', 'bannerStartsAt', 'bannerEndsAt'].forEach((id) => {
    if ($(id)) $(id).value = '';
  });
  if ($('bannerSortOrder')) $('bannerSortOrder').value = '0';
  if ($('bannerCoupon')) $('bannerCoupon').value = '';
  if ($('bannerPopupFreq')) $('bannerPopupFreq').value = 'daily';
  if ($('bannerAction')) $('bannerAction').value = 'none';
  if ($('bannerFormTitle')) $('bannerFormTitle').textContent = 'เพิ่มโฆษณาใหม่';
  if ($('bannerSubmitBtn')) $('bannerSubmitBtn').textContent = 'อัปโหลด';
  _show('bannerCancelEditBtn', false);
  onBannerFormChange();
}

export function cancelBannerEdit() {
  _resetForm();
}

export function editBanner(id) {
  const b = (globalThis._allBanners || []).find((x) => x.id === id);
  if (!b) return;
  globalThis._bannerEditingId = id;
  const p = placementOf(b.page);

  if ($('bannerAudience')) $('bannerAudience').value = p.audience;
  onBannerFormChange();
  if ($('bannerPage')) $('bannerPage').value = AD_PLACEMENTS[b.page] ? b.page : $('bannerPage').value;
  if ($('bannerAction')) $('bannerAction').value = b.action_type || (b.coupon_code ? 'coupon' : 'none');
  onBannerFormChange();

  if ($('bannerTitle')) $('bannerTitle').value = b.title || '';
  if ($('bannerCoupon')) $('bannerCoupon').value = b.coupon_code || '';
  if ($('bannerUrl')) $('bannerUrl').value = b.action_type === 'url' ? b.action_value || '' : '';
  if ($('bannerScreen') && b.action_type === 'screen') $('bannerScreen').value = b.action_value || '';
  if ($('bannerStartsAt')) $('bannerStartsAt').value = isoToLocalInput(b.starts_at);
  if ($('bannerEndsAt')) $('bannerEndsAt').value = isoToLocalInput(b.ends_at);
  if ($('bannerPopupFreq')) $('bannerPopupFreq').value = b.popup_frequency || 'daily';
  if ($('bannerSortOrder')) $('bannerSortOrder').value = String(b.sort_order ?? 0);
  if ($('bannerFileInput')) $('bannerFileInput').value = '';

  if ($('bannerFormTitle')) $('bannerFormTitle').textContent = 'แก้ไขโฆษณา: ' + (b.title || 'Banner');
  if ($('bannerSubmitBtn')) $('bannerSubmitBtn').textContent = 'บันทึกการแก้ไข';
  _show('bannerCancelEditBtn', true);
  $('bannerFormCard')?.scrollIntoView({ behavior: 'smooth', block: 'center' });
}

function _readForm() {
  const action = $('bannerAction')?.value || 'none';
  const data = {
    title: $('bannerTitle')?.value || '',
    page: $('bannerPage')?.value || 'home',
    action_type: action,
    action_value: action === 'url' ? ($('bannerUrl')?.value || '').trim() : action === 'screen' ? $('bannerScreen')?.value || '' : null,
    coupon_code: action === 'coupon' ? $('bannerCoupon')?.value || null : null,
    starts_at: localInputToIso($('bannerStartsAt')?.value),
    ends_at: localInputToIso($('bannerEndsAt')?.value),
    popup_frequency: $('bannerPopupFreq')?.value || 'daily',
    sort_order: Number($('bannerSortOrder')?.value || 0),
  };
  return data;
}

function _validate(data, file, isEdit) {
  if (!isEdit && !file) return 'กรุณาเลือกรูปภาพ';
  if (file && !/^image\/(png|jpeg|webp|gif)$/.test(file.type)) return 'รองรับเฉพาะไฟล์ JPG / PNG / WebP / GIF';
  // ไฟล์ใหญ่ถูกบีบอัดอัตโนมัติตอนอัปโหลด — GIF บีบไม่ได้ (จะเสียภาพเคลื่อนไหว)
  if (file && file.type === 'image/gif' && file.size > MAX_IMAGE_BYTES) return 'GIF ต้องไม่เกิน 2MB';
  if (data.action_type === 'coupon' && !data.coupon_code) return 'เลือกโค้ดคูปอง';
  if (data.action_type === 'url' && !/^https:\/\/\S+$/i.test(data.action_value || '')) return 'ลิงก์ต้องขึ้นต้นด้วย https://';
  if (data.starts_at && data.ends_at && Date.parse(data.ends_at) <= Date.parse(data.starts_at)) return 'วันสิ้นสุดต้องหลังวันเริ่ม';
  return null;
}

export async function loadBanners(ctx) {
  _ctx = ctx || _ctx;
  const { supabase } = _deps();

  const el = $('bannerList');
  if (!el) return;

  // ตัวเลือกฝั่ง / ความถี่ (ครั้งแรกที่หน้าโหลด)
  if ($('bannerAudience') && !$('bannerAudience').options.length) {
    _fillSelect($('bannerAudience'), Object.entries(AD_AUDIENCES), 'customer');
  }
  if ($('bannerPopupFreq') && !$('bannerPopupFreq').options.length) {
    _fillSelect($('bannerPopupFreq'), Object.entries(AD_POPUP_FREQUENCY_LABELS), 'daily');
  }
  onBannerFormChange();

  try {
    const { data: banners, error } = await supabase
      .from('banners')
      .select(
        'id,title,image_url,page,sort_order,is_active,action_type,action_value,coupon_code,starts_at,ends_at,popup_frequency,created_at',
      )
      .order('sort_order')
      .order('created_at', { ascending: false });
    if (error) throw error;

    globalThis._allBanners = banners || [];
    filterBanners(globalThis._bannerFilter, ctx);
  } catch (e) {
    el.innerHTML = '<p class="text-gray-400 text-sm">โหลดรายการโฆษณาไม่สำเร็จ</p>';
  }

  try {
    const { data: coupons } = await supabase
      .from('coupons')
      .select('code, name, is_active, end_date')
      .eq('is_active', true)
      .gte('end_date', new Date().toISOString())
      .order('code');
    _activeCoupons = coupons || [];
    const sel = $('bannerCoupon');
    if (sel) {
      const cur = sel.value;
      sel.innerHTML =
        '<option value="">— เลือกโค้ด —</option>' +
        _activeCoupons
          .map((c) => '<option value="' + _escape(c.code) + '">' + _escape(c.code) + ' — ' + _escape(c.name) + '</option>')
          .join('');
      sel.value = cur;
    }
  } catch (_) {}
}

/** สร้างใหม่ หรือบันทึกการแก้ไข (ถ้ากำลังแก้ไข) */
export async function uploadBanner(ctx) {
  _ctx = ctx || _ctx;
  const { supabase, callAdminAction, showToast } = _deps();

  const editingId = globalThis._bannerEditingId;
  const fileInput = $('bannerFileInput');
  const file = fileInput?.files?.[0] || null;
  const data = _readForm();
  const err = _validate(data, file, !!editingId);
  if (err) {
    showToast(err, 'error');
    return;
  }

  const btn = $('bannerSubmitBtn');
  if (btn) btn.disabled = true;
  try {
    if (file) {
      if (btn) btn.textContent = 'กำลังเตรียมรูป...';
      const fmt = AD_PLACEMENTS[data.page]?.format;
      const { file: upFile, compressed, originalSize, finalSize } = await compressImageIfNeeded(file, {
        maxBytes: MAX_IMAGE_BYTES,
        maxDim: fmt === 'popup' ? 1350 : 1600,
      });
      if (compressed) {
        const mb = (n) => (n / 1024 / 1024).toFixed(2) + 'MB';
        showToast('บีบอัดรูปอัตโนมัติ ' + mb(originalSize) + ' → ' + mb(finalSize), 'success');
      }
      if (btn) btn.textContent = 'กำลังอัปโหลด...';
      const ext = (upFile.name.split('.').pop() || 'png').toLowerCase().replace(/[^a-z0-9]/g, '') || 'png';
      const path = 'banners/banner_' + Date.now() + '.' + ext;
      const { error } = await supabase.storage
        .from('admin-uploads')
        .upload(path, upFile, { upsert: false, contentType: upFile.type });
      if (error) throw error;
      const { data: urlData } = supabase.storage.from('admin-uploads').getPublicUrl(path);
      if (!urlData?.publicUrl) throw new Error('ไม่สามารถดึง URL ได้');
      data.image_url = urlData.publicUrl;
    }

    if (editingId) {
      await callAdminAction({ action: 'update_banner', id: editingId, banner_data: data });
      showToast('บันทึกการแก้ไขแล้ว', 'success');
    } else {
      await callAdminAction({ action: 'create_banner', banner_data: data });
      showToast('เพิ่มโฆษณาแล้ว', 'success');
    }
    _resetForm();
    await loadBanners(ctx);
  } catch (e) {
    try {
      console.error('Save banner error:', e);
    } catch (_) {}
    showToast('เกิดข้อผิดพลาด: ' + (e?.message || e), 'error');
  } finally {
    if (btn) {
      btn.disabled = false;
      btn.textContent = globalThis._bannerEditingId ? 'บันทึกการแก้ไข' : 'อัปโหลด';
    }
  }
}

export async function toggleBanner(id, currentActive, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml } = _deps();

  try {
    await callAdminAction({ action: 'toggle_banner', id, is_active: !currentActive });
    showToast(currentActive ? 'ปิดโฆษณาแล้ว' : 'เปิดโฆษณาแล้ว', 'success');
    loadBanners(ctx);
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function deleteBanner(id, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml } = _deps();

  if (!confirm('ลบโฆษณานี้?')) return;
  try {
    await callAdminAction({ action: 'delete_banner', id });
    if (globalThis._bannerEditingId === id) _resetForm();
    showToast('ลบโฆษณาแล้ว', 'success');
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
  // ฟังก์ชันใหม่ ไม่มีใน app.legacy.js — ผูกกับ window ตรง
  globalThis.onBannerFormChange = onBannerFormChange;
  globalThis.cancelBannerEdit = cancelBannerEdit;
  globalThis.editBanner = editBanner;
}
