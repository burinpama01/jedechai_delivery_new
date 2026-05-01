let _ctx = null;

function _deps() {
  const callAdminAction = _ctx?.callAdminAction || globalThis.callAdminAction;
  const showToast = _ctx?.showToast || globalThis.showToast;

  const escapeHtml = _ctx?.escapeHtml || globalThis.escapeHtml;

  const normalizeLandingConfig = _ctx?.normalizeLandingConfig || globalThis.normalizeLandingConfig;
  const DEFAULT_LANDING_CONFIG = _ctx?.DEFAULT_LANDING_CONFIG || globalThis.DEFAULT_LANDING_CONFIG;

  const _upsertSystemConfig = _ctx?._upsertSystemConfig || globalThis._upsertSystemConfig;
  const _upsertSystemConfigKeyValues = _ctx?._upsertSystemConfigKeyValues || globalThis._upsertSystemConfigKeyValues;
  const _fetchSystemConfigKeyValues = _ctx?._fetchSystemConfigKeyValues || globalThis._fetchSystemConfigKeyValues;

  const supabase = _ctx?.supabase || globalThis.supabase;

  return {
    callAdminAction,
    showToast,
    escapeHtml,
    normalizeLandingConfig,
    DEFAULT_LANDING_CONFIG,
    _upsertSystemConfig,
    _upsertSystemConfigKeyValues,
    _fetchSystemConfigKeyValues,
    supabase,
  };
}

async function _ensureFns() {
  const { _upsertSystemConfig } = _deps();
  if (typeof _upsertSystemConfig !== 'function') {
    throw new Error('_upsertSystemConfig_not_found');
  }
}

export async function saveGeneralSettings(ctx) {
  _ctx = ctx || _ctx;
  const { showToast, _upsertSystemConfig } = _deps();
  await _ensureFns();

  try {
    await _upsertSystemConfig({
      commission_rate: parseFloat(document.getElementById('settCommission')?.value) || 15,
      driver_min_wallet: parseInt(document.getElementById('settMinWallet')?.value, 10) || 0,
      promptpay_number: (document.getElementById('settPromptPay')?.value || '').trim() || null,
      max_delivery_radius: parseFloat(document.getElementById('settMaxRadius')?.value) || 30,
    });
    showToast('บันทึกค่าทั่วไปสำเร็จ', 'success');
  } catch (e) {
    try {
      console.error('saveGeneralSettings error:', e);
    } catch (_) {}
    showToast('บันทึกค่าทั่วไปไม่สำเร็จ: ' + (e?.message || JSON.stringify(e)), 'error');
  }
}

export async function saveDetectionRadiusSettings(ctx) {
  _ctx = ctx || _ctx;
  const { showToast, _upsertSystemConfig } = _deps();
  await _ensureFns();

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
    try {
      console.error('saveDetectionRadiusSettings error:', e);
    } catch (_) {}
    if (String(e?.message || '').toLowerCase().includes('detection_radius_config')) {
      showToast('ยังไม่สามารถบันทึกรัศมีตรวจจับได้ กรุณารัน migration 20260308_add_detection_radius_config.sql', 'error');
      return;
    }
    showToast('บันทึกรัศมีตรวจจับไม่สำเร็จ: ' + (e?.message || JSON.stringify(e)), 'error');
  }
}

export async function saveTopupModeSettings(ctx) {
  _ctx = ctx || _ctx;
  const { showToast, _upsertSystemConfig } = _deps();
  await _ensureFns();

  try {
    await _upsertSystemConfig({
      topup_mode: document.querySelector('input[name="settTopupMode"]:checked')?.value || 'admin_approve',
    });
    showToast('บันทึกโหมดเติมเงินสำเร็จ', 'success');
  } catch (e) {
    try {
      console.error('saveTopupModeSettings error:', e);
    } catch (_) {}
    showToast('บันทึกโหมดเติมเงินไม่สำเร็จ: ' + (e?.message || JSON.stringify(e)), 'error');
  }
}

export async function saveServiceRatesSettings(ctx) {
  _ctx = ctx || _ctx;
  const { showToast, _upsertSystemConfig, _upsertSystemConfigKeyValues, _fetchSystemConfigKeyValues, supabase } = _deps();
  await _ensureFns();

  try {
    const merchantGp = (parseFloat(document.getElementById('settMerchantGP')?.value) || 10) / 100;
    const merchantGpSystem = (parseFloat(document.getElementById('settMerchantGpSystemRate')?.value) || 0) / 100;
    const merchantGpDriver = (parseFloat(document.getElementById('settMerchantGpDriverRate')?.value) || 0) / 100;
    const splitTotal = merchantGpSystem + merchantGpDriver;
    if (splitTotal - merchantGp > 0.0001) {
      throw new Error(
        `Merchant GP split รวมต้องไม่เกิน Merchant GP (รวม ${(merchantGp * 100).toFixed(1)}%, split ${(splitTotal * 100).toFixed(1)}%)`,
      );
    }

    await _upsertSystemConfig({
      platform_fee_rate: (parseFloat(document.getElementById('settPlatformFee')?.value) || 15) / 100,
      merchant_gp_rate: merchantGp,
    });

    if (typeof _upsertSystemConfigKeyValues === 'function') {
      await _upsertSystemConfigKeyValues([
        { key: 'merchant_gp_system_rate_default', value: merchantGpSystem.toFixed(4) },
        { key: 'merchant_gp_driver_rate_default', value: merchantGpDriver.toFixed(4) },
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

      if (typeof _fetchSystemConfigKeyValues === 'function') {
        const verifyDefaults = await _fetchSystemConfigKeyValues([
          'merchant_gp_system_rate_default',
          'merchant_gp_driver_rate_default',
        ]);
        if (
          String(verifyDefaults.merchant_gp_system_rate_default ?? '') !== merchantGpSystem.toFixed(4) ||
          String(verifyDefaults.merchant_gp_driver_rate_default ?? '') !== merchantGpDriver.toFixed(4)
        ) {
          throw new Error('บันทึกค่า Merchant GP split default ไม่สำเร็จใน schema ปัจจุบัน');
        }
      }
    }

    const rateEls = document.querySelectorAll('[data-rate-type]');
    for (const el of rateEls) {
      const type = el.dataset.rateType;
      const bp = parseFloat(el.querySelector('.rate-base-price')?.value) || 0;
      const bd = parseFloat(el.querySelector('.rate-base-dist')?.value) || 0;
      const pk = parseFloat(el.querySelector('.rate-per-km')?.value) || 0;
      const { error: rateErr } = await supabase
        .from('service_rates')
        .update({ base_price: bp, base_distance: bd, price_per_km: pk })
        .eq('service_type', type);
      if (rateErr) throw rateErr;
    }

    showToast('บันทึกอัตราค่าบริการสำเร็จ', 'success');
  } catch (e) {
    try {
      console.error('saveServiceRatesSettings error:', e);
    } catch (_) {}
    showToast('บันทึกอัตราค่าบริการไม่สำเร็จ: ' + (e?.message || JSON.stringify(e)), 'error');
  }
}

export async function savePromoSettings(ctx) {
  _ctx = ctx || _ctx;
  const { showToast, _upsertSystemConfig } = _deps();
  await _ensureFns();

  try {
    await _upsertSystemConfig({
      promo_text: document.getElementById('settPromoText')?.value || 'ส่งฟรี! สั่งครบ ฿200',
      promo_enabled: document.getElementById('settPromoEnabled')?.checked || false,
    });
    showToast('บันทึกป้ายโปรโมชั่นสำเร็จ', 'success');
  } catch (e) {
    try {
      console.error('savePromoSettings error:', e);
    } catch (_) {}
    showToast('บันทึกป้ายโปรโมชั่นไม่สำเร็จ: ' + (e?.message || JSON.stringify(e)), 'error');
  }
}

export async function saveLandingSettings(ctx) {
  _ctx = ctx || _ctx;
  const { showToast, normalizeLandingConfig, DEFAULT_LANDING_CONFIG, _upsertSystemConfig } = _deps();
  await _ensureFns();

  try {
    if (typeof normalizeLandingConfig !== 'function') throw new Error('normalizeLandingConfig_not_found');

    const landingConfig = normalizeLandingConfig({
      brand_name: document.getElementById('settLandingBrandName')?.value?.trim() || DEFAULT_LANDING_CONFIG?.brand_name,
      badge_text: document.getElementById('settLandingBadgeText')?.value?.trim() || DEFAULT_LANDING_CONFIG?.badge_text,
      hero_title: document.getElementById('settLandingHeroTitle')?.value?.trim() || DEFAULT_LANDING_CONFIG?.hero_title,
      hero_subtitle: document.getElementById('settLandingHeroSubtitle')?.value?.trim() || DEFAULT_LANDING_CONFIG?.hero_subtitle,
      play_store_url: document.getElementById('settLandingPlayStoreUrl')?.value?.trim() || DEFAULT_LANDING_CONFIG?.play_store_url,
      app_store_url: document.getElementById('settLandingAppStoreUrl')?.value?.trim() || DEFAULT_LANDING_CONFIG?.app_store_url,
      ride_icon: document.getElementById('settLandingRideIcon')?.value?.trim() || DEFAULT_LANDING_CONFIG?.ride_icon,
      food_icon: document.getElementById('settLandingFoodIcon')?.value?.trim() || DEFAULT_LANDING_CONFIG?.food_icon,
      parcel_icon: document.getElementById('settLandingParcelIcon')?.value?.trim() || DEFAULT_LANDING_CONFIG?.parcel_icon,
      reviews_title: document.getElementById('settLandingReviewsTitle')?.value?.trim() || DEFAULT_LANDING_CONFIG?.reviews_title,
      reviews_subtitle: document.getElementById('settLandingReviewsSubtitle')?.value?.trim() || DEFAULT_LANDING_CONFIG?.reviews_subtitle,
      review_1_name: document.getElementById('settLandingReview1Name')?.value?.trim() || DEFAULT_LANDING_CONFIG?.review_1_name,
      review_1_role: document.getElementById('settLandingReview1Role')?.value?.trim() || DEFAULT_LANDING_CONFIG?.review_1_role,
      review_1_text: document.getElementById('settLandingReview1Text')?.value?.trim() || DEFAULT_LANDING_CONFIG?.review_1_text,
      review_2_name: document.getElementById('settLandingReview2Name')?.value?.trim() || DEFAULT_LANDING_CONFIG?.review_2_name,
      review_2_role: document.getElementById('settLandingReview2Role')?.value?.trim() || DEFAULT_LANDING_CONFIG?.review_2_role,
      review_2_text: document.getElementById('settLandingReview2Text')?.value?.trim() || DEFAULT_LANDING_CONFIG?.review_2_text,
      review_3_name: document.getElementById('settLandingReview3Name')?.value?.trim() || DEFAULT_LANDING_CONFIG?.review_3_name,
      review_3_role: document.getElementById('settLandingReview3Role')?.value?.trim() || DEFAULT_LANDING_CONFIG?.review_3_role,
      review_3_text: document.getElementById('settLandingReview3Text')?.value?.trim() || DEFAULT_LANDING_CONFIG?.review_3_text,
      logo_url: document.getElementById('settLandingLogoUrl')?.value?.trim() || '',
      hero_image_url: document.getElementById('settLandingHeroImageUrl')?.value?.trim() || '',
    });

    await _upsertSystemConfig({ landing_config: landingConfig });
    showToast('บันทึก Landing Page สำเร็จ', 'success');
  } catch (e) {
    try {
      console.error('saveLandingSettings error:', e);
    } catch (_) {}
    if (String(e?.message || '').toLowerCase().includes('landing_config')) {
      showToast('ยังไม่สามารถบันทึก Landing Page ได้ กรุณารัน migration 20260307_add_landing_page_config.sql', 'error');
      return;
    }
    showToast('บันทึก Landing Page ไม่สำเร็จ: ' + (e?.message || JSON.stringify(e)), 'error');
  }
}

export async function saveAdminEmail(ctx) {
  _ctx = ctx || _ctx;
  const { showToast, _upsertSystemConfig } = _deps();
  await _ensureFns();

  const adminEmail = document.getElementById('settAdminEmail')?.value?.trim();
  const adminEmailCC = document.getElementById('settAdminEmailCC')?.value?.trim();

  try {
    await _upsertSystemConfig({
      admin_notification_email: adminEmail || null,
      admin_notification_email_cc: adminEmailCC || null,
    });

    showToast('บันทึกอีเมลสำเร็จ!', 'success');
  } catch (e) {
    try {
      console.error('Save email exception:', e);
    } catch (_) {}
    showToast('เกิดข้อผิดพลาด: ' + (e?.message || e), 'error');
  }
}

export async function saveAdminLine(ctx) {
  _ctx = ctx || _ctx;
  const { showToast, _upsertSystemConfig } = _deps();
  await _ensureFns();

  const enabled = document.getElementById('settAdminLineEnabled')?.checked || false;
  const recipientId = document.getElementById('settAdminLineRecipient')?.value?.trim();

  try {
    await _upsertSystemConfig({
      admin_line_enabled: enabled,
      admin_line_recipient_id: recipientId || null,
    });

    showToast('บันทึก LINE แจ้งเตือนแอดมินสำเร็จ', 'success');
  } catch (e) {
    try {
      console.error('Save LINE exception:', e);
    } catch (_) {}
    showToast('บันทึก LINE ไม่สำเร็จ: ' + (e?.message || e), 'error');
  }
}

export async function testAdminLine(ctx) {
  _ctx = ctx || _ctx;
  const { showToast, supabase } = _deps();

  const recipientId = document.getElementById('settAdminLineRecipient')?.value?.trim();
  if (!recipientId) {
    showToast('กรุณากรอก LINE recipient ID ก่อน', 'error');
    return;
  }

  showToast('กำลังส่ง LINE ทดสอบ...', 'info');
  try {
    const { data, error } = await supabase.functions.invoke('send-admin-line', {
      body: {
        test: true,
        title: 'JDC Admin Test',
        message: 'ทดสอบระบบแจ้งเตือนแอดมินผ่าน LINE จาก Jedechai Delivery',
        event_type: 'admin_line_test',
        to: recipientId,
        data: {
          source: 'admin_web_settings',
        },
      },
    });
    if (error) {
      const details = await readFunctionError(error);
      throw new Error(details || error.message || 'edge_function_failed');
    }
    if (data?.success === false) {
      throw new Error(data?.result?.error ? JSON.stringify(data.result.error) : 'line_send_failed');
    }

    showToast('ส่ง LINE ทดสอบสำเร็จ', 'success');
  } catch (e) {
    try {
      console.error('Test LINE error:', e);
    } catch (_) {}
    showToast('ส่ง LINE ไม่สำเร็จ: ' + (e?.message || 'ตรวจสอบ Edge Function/LINE token'), 'error');
  }
}

export async function testAdminEmail(ctx) {
  _ctx = ctx || _ctx;
  const { showToast, supabase } = _deps();

  const email = document.getElementById('settAdminEmail')?.value?.trim();
  if (!email) {
    showToast('กรุณากรอกอีเมลหลักก่อน', 'error');
    return;
  }

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

    try {
      console.log('📧 Edge Function response:', JSON.stringify(data));
    } catch (_) {}

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
    try {
      console.error('Test email error:', e);
    } catch (_) {}
    showToast('ส่งอีเมลไม่สำเร็จ: ' + (e?.message || 'ตรวจสอบ Edge Function'), 'error');
  }
}

async function readFunctionError(error) {
  const response = error?.context;
  if (!response || typeof response.text !== 'function') return '';

  try {
    const raw = await response.text();
    if (!raw) return '';
    try {
      const data = JSON.parse(raw);
      if (data?.error) return String(data.error);
      if (data?.result?.error) {
        return typeof data.result.error === 'string'
          ? data.result.error
          : JSON.stringify(data.result.error);
      }
      return JSON.stringify(data);
    } catch (_) {
      return raw;
    }
  } catch (_) {
    return '';
  }
}

export function wireSettingsActionsBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  globalThis.__adminWebBridge.saveGeneralSettings = saveGeneralSettings;
  globalThis.__adminWebBridge.saveDetectionRadiusSettings = saveDetectionRadiusSettings;
  globalThis.__adminWebBridge.saveTopupModeSettings = saveTopupModeSettings;
  globalThis.__adminWebBridge.saveServiceRatesSettings = saveServiceRatesSettings;
  globalThis.__adminWebBridge.savePromoSettings = savePromoSettings;
  globalThis.__adminWebBridge.saveLandingSettings = saveLandingSettings;
  globalThis.__adminWebBridge.saveAdminEmail = saveAdminEmail;
  globalThis.__adminWebBridge.saveAdminLine = saveAdminLine;
  globalThis.__adminWebBridge.testAdminEmail = testAdminEmail;
  globalThis.__adminWebBridge.testAdminLine = testAdminLine;
}
