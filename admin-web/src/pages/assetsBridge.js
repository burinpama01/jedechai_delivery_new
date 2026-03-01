let _ctx = null;

function _deps() {
  const supabase = _ctx?.supabase || globalThis.supabase;
  const showToast = _ctx?.showToast || globalThis.showToast;

  const escapeHtml = _ctx?.escapeHtml || globalThis.escapeHtml;

  const normalizeLandingConfig = _ctx?.normalizeLandingConfig || globalThis.normalizeLandingConfig;
  const _upsertSystemConfig = _ctx?._upsertSystemConfig || globalThis._upsertSystemConfig;

  return {
    supabase,
    showToast,
    escapeHtml,
    normalizeLandingConfig,
    _upsertSystemConfig,
  };
}

export function setLandingAssetPreview(type, imageUrl, ctx) {
  _ctx = ctx || _ctx;

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

export async function loadAppAssets(ctx) {
  _ctx = ctx || _ctx;
  const { supabase, normalizeLandingConfig } = _deps();

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

    if (typeof normalizeLandingConfig === 'function') {
      const landingConfig = normalizeLandingConfig(config.landing_config);
      setLandingAssetPreview('logo', landingConfig.logo_url || config.logo_url || '', ctx);
      setLandingAssetPreview('hero', landingConfig.hero_image_url || '', ctx);
    }
  } catch (_) {
    // columns might not exist yet
  }
}

export async function uploadAppAsset(type, ctx) {
  _ctx = ctx || _ctx;
  const { supabase, showToast, _upsertSystemConfig } = _deps();

  const inputId = type === 'logo' ? 'logoFileInput' : 'splashFileInput';
  const previewId = type === 'logo' ? 'currentLogo' : 'currentSplash';
  const file = document.getElementById(inputId)?.files?.[0];
  if (!file) return alert('กรุณาเลือกรูปภาพ');

  const previewEl = document.getElementById(previewId);
  if (previewEl) {
    previewEl.innerHTML =
      '<div class="w-24 h-24 bg-gray-100 rounded-xl flex items-center justify-center"><div class="loader"></div></div>';
  }

  try {
    const ext = file.name.split('.').pop();
    const path = `app-assets/${type}_${Date.now()}.${ext}`;
    const { error } = await supabase.storage.from('admin-uploads').upload(path, file, { upsert: true });
    if (error) throw error;

    const { data: urlData } = supabase.storage.from('admin-uploads').getPublicUrl(path);
    const imageUrl = urlData?.publicUrl;
    if (!imageUrl) throw new Error('ไม่สามารถดึง URL ได้');

    const updateField = type === 'logo' ? 'logo_url' : 'splash_url';
    if (typeof _upsertSystemConfig !== 'function') throw new Error('_upsertSystemConfig_not_found');

    await _upsertSystemConfig({ [updateField]: imageUrl });

    if (previewEl) previewEl.innerHTML = `<img src="${imageUrl}" class="w-24 h-24 object-contain rounded-xl border" />`;
    const inputEl = document.getElementById(inputId);
    if (inputEl) inputEl.value = '';

    showToast(`อัปโหลด${type === 'logo' ? 'โลโก้' : 'Splash'}สำเร็จ!`, 'success');
  } catch (e) {
    if (previewEl) {
      previewEl.innerHTML =
        '<div class="w-24 h-24 bg-red-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-red-400">error</span></div>';
    }
    showToast('เกิดข้อผิดพลาด: ' + (e?.message || e), 'error');
  }
}

export async function uploadLandingAsset(type, ctx) {
  _ctx = ctx || _ctx;
  const { supabase, showToast, normalizeLandingConfig, _upsertSystemConfig } = _deps();

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

    const { data: cfgRow } = await supabase.from('system_config').select('landing_config').maybeSingle();
    const landingConfig = typeof normalizeLandingConfig === 'function' ? normalizeLandingConfig(cfgRow?.landing_config) : cfgRow?.landing_config;

    if (!landingConfig || typeof landingConfig !== 'object') throw new Error('landing_config_invalid');
    landingConfig[configField] = imageUrl;

    if (typeof _upsertSystemConfig !== 'function') throw new Error('_upsertSystemConfig_not_found');

    await _upsertSystemConfig({ landing_config: landingConfig });

    setLandingAssetPreview(type, imageUrl, ctx);
    const inputEl = document.getElementById(inputId);
    if (inputEl) inputEl.value = '';
    showToast(`อัปโหลด${displayName}สำเร็จ!`, 'success');
  } catch (e) {
    setLandingAssetPreview(type, previousUrl, ctx);

    if (String(e?.message || '').toLowerCase().includes('landing_config')) {
      showToast('ยังไม่พบคอลัมน์ landing_config (กรุณารัน migration 20260307_add_landing_page_config.sql)', 'error');
      return;
    }
    showToast('เกิดข้อผิดพลาด: ' + (e?.message || e), 'error');
  }
}

export function wireAssetsBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  globalThis.__adminWebBridge.setLandingAssetPreview = setLandingAssetPreview;
  globalThis.__adminWebBridge.loadAppAssets = loadAppAssets;
  globalThis.__adminWebBridge.uploadAppAsset = uploadAppAsset;
  globalThis.__adminWebBridge.uploadLandingAsset = uploadLandingAsset;
}
