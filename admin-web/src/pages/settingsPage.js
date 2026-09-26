// Settings page — migrated verbatim from app.legacy.js renderSettings (lines 3805-4639)
// as part of the strangler-fig refactor. Action handlers were already migrated
// (settingsActionsBridge/bannersBridge/assetsBridge); this moves the renderer.
// Runtime deps (supabase, escapeHtml, showToast, loadBanners, loadAppAssets,
// inline onclick globals) still resolve through the shared global scope that
// app.legacy.js bootstraps — same contract as the other migrated pages.
import {
  renderShopSettingsSection,
  saveShopSettings,
  SHOP_CONFIG_KEYS,
} from './shopSettingsSection.js';
import { renderAiSettingsSection, loadAiSettingsSection } from './aiSettingsSection.js';

let _ctx = null;

// สำเนาจาก legacy (บรรทัด 3796) — กัน module พึ่ง global ordering
function escapeForInput(value) {
  return String(value ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

export async function renderSettingsPage(el, ctx) {
  _ctx = ctx || null;
  globalThis.__adminWebContext = {
    ...(globalThis.__adminWebContext || {}),
    ...(ctx || {}),
  };

  try {
    const bridged = window.__adminWebBridge?.renderSettingsPage;
    if (typeof bridged === 'function') {
      return await bridged(el, { supabase, supabaseAuth, currentUser });
    }
  } catch (_) {}

  let config = {};
  let rates = [];
  let kvConfig = {};
  try {
    const { data } = await supabase.from('system_config').select('*').eq('id', 1).single();
    config = data || {};
  } catch(e) { /* might not exist */ }
  try {
    kvConfig = await _fetchSystemConfigKeyValues([
      'ride_far_pickup_threshold_km',
      'ride_far_pickup_rate_per_km_motorcycle',
      'ride_far_pickup_rate_per_km_car',
      'food_far_pickup_threshold_km_default',
      'food_far_pickup_rate_per_km_default',
      'merchant_gp_system_rate_default',
      'merchant_gp_driver_rate_default',
      'laundry_merchant_gp_rate_default',
      'laundry_gp_driver_rate_default',
      'laundry_delivery_gp_rate_default',
    ]);
  } catch(e) { /* key-value rows may not exist yet */ }
  try {
    const { data } = await supabase.from('service_rates').select('*').order('service_type');
    rates = data || [];
  } catch(e) {}

  // ── ฝากซื้อ: config + จำนวนร้านที่เปิดใช้งาน (ใช้เตือนก่อนเปิดบริการ) ──
  let shopKvConfig = {};
  let shopStoreCount = 0;
  try {
    shopKvConfig = await _fetchSystemConfigKeyValues(SHOP_CONFIG_KEYS);
  } catch(e) { /* ยังไม่ได้รัน migration ฝากซื้อ — ใช้ค่าเริ่มต้นแทน */ }
  try {
    const { count } = await supabase
      .from('shop_stores')
      .select('id', { count: 'exact', head: true })
      .eq('is_active', true);
    shopStoreCount = count || 0;
  } catch(e) { /* ตารางยังไม่มี */ }

  // Group rates by category
  const rideRates = rates.filter(r => r.service_type.startsWith('ride'));
  const foodRate = rates.find(r => r.service_type === 'food');
  const parcelRate = rates.find(r => r.service_type === 'parcel');
  const otherRates = rates.filter(r => !r.service_type.startsWith('ride') && r.service_type !== 'food' && r.service_type !== 'parcel');

  const vehicleIcon = { ride_motorcycle:'🏍️', ride_car:'🚗', ride_van:'🚐', ride:'🚕' };
  const vehicleLabel = { ride_motorcycle:'มอเตอร์ไซค์', ride_car:'รถยนต์', ride_van:'รถตู้', ride:'เรียกรถ (ทั่วไป)' };
  const landingConfig = normalizeLandingConfig(config.landing_config);
  const appUpdatePolicy = normalizeAppUpdatePolicy(config.app_update_policy);
  const detectionRadiusConfig = normalizeDetectionRadiusConfig(config.detection_radius_config);
  const merchantGpPercent = config.merchant_gp_rate ? (config.merchant_gp_rate * 100) : 10;
  const merchantGpSystemDefault = kvConfig.merchant_gp_system_rate_default != null
    ? parseFloat(kvConfig.merchant_gp_system_rate_default) * 100
    : merchantGpPercent;
  const merchantGpDriverDefault = kvConfig.merchant_gp_driver_rate_default != null
    ? parseFloat(kvConfig.merchant_gp_driver_rate_default) * 100
    : 0;
  const laundryMerchantGpDefault = kvConfig.laundry_merchant_gp_rate_default != null
    ? parseFloat(kvConfig.laundry_merchant_gp_rate_default) * 100
    : 10;
  const laundryGpDriverDefault = kvConfig.laundry_gp_driver_rate_default != null
    ? parseFloat(kvConfig.laundry_gp_driver_rate_default) * 100
    : 0;
  const laundryDeliveryGpDefault = kvConfig.laundry_delivery_gp_rate_default != null
    ? parseFloat(kvConfig.laundry_delivery_gp_rate_default) * 100
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
            <h3 class="font-bold text-gray-800">โหมดเติมเงิน Wallet</h3>
            <p class="text-xs text-gray-400">เลือกช่องทางเติมเงินของคนขับ/ลูกค้า: แนบสลิป (Slip2Go + แอดมิน) หรือ Beam Checkout (QR PromptPay อัตโนมัติ)</p>
          </div>
        </div>

        <!-- สวิตช์โหมดเติมเงิน -->
        <div class="mb-5 rounded-xl border border-gray-200 p-4" data-testid="topup-mode-switch">
          <p class="text-xs font-semibold text-gray-500 mb-2 uppercase tracking-wider">ช่องทางที่ใช้อยู่ตอนนี้</p>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-3">
            <label class="flex items-start gap-3 rounded-xl border-2 p-3 cursor-pointer" id="topupModeOptSlip">
              <input type="radio" name="settTopupMode" value="admin_approve" ${config.topup_mode !== 'beam' ? 'checked' : ''} onchange="setTopupMode('admin_approve')" class="mt-1">
              <span><span class="block font-semibold text-gray-800">แนบสลิป</span><span class="block text-xs text-gray-500">PromptPay QR ของระบบ → แนบสลิป → Slip2Go ตรวจอัตโนมัติ / แอดมินอนุมัติ</span></span>
            </label>
            <label class="flex items-start gap-3 rounded-xl border-2 p-3 cursor-pointer" id="topupModeOptBeam">
              <input type="radio" name="settTopupMode" value="beam" ${config.topup_mode === 'beam' ? 'checked' : ''} onchange="setTopupMode('beam')" class="mt-1">
              <span><span class="block font-semibold text-gray-800">Beam Checkout</span><span class="block text-xs text-gray-500">สแกน QR PromptPay จาก Beam → เงินเข้า Wallet อัตโนมัติ ไม่ต้องแนบสลิป (ต้องทดสอบเชื่อมต่อผ่านก่อน)</span></span>
            </label>
          </div>
        </div>

        <!-- ตั้งค่า Beam -->
        <div class="mb-5 rounded-xl border border-indigo-200 bg-indigo-50/40 p-4" data-testid="beam-settings">
          <div class="flex items-center justify-between mb-3">
            <p class="font-bold text-gray-800">ตั้งค่า Beam Checkout</p>
            <span id="beamTestBadge" class="text-xs px-2 py-1 rounded-full bg-gray-100 text-gray-500">ยังไม่ทดสอบ</span>
          </div>
          <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
            <div>
              <label class="block text-xs font-semibold text-gray-500 mb-1.5">Environment</label>
              <select id="settBeamEnvironment" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-white">
                <option value="playground">Playground (ทดสอบ)</option>
                <option value="production">Production (เงินจริง)</option>
              </select>
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-500 mb-1.5">Merchant ID</label>
              <input type="text" id="settBeamMerchantId" autocomplete="off" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-white" placeholder="จาก Beam Lighthouse → Developers">
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-500 mb-1.5">API Key</label>
              <input type="password" id="settBeamApiKey" autocomplete="new-password" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-white" placeholder="เว้นว่าง = ใช้คีย์เดิม">
              <p id="settBeamApiKeyHint" class="text-xs text-gray-400 mt-1">ยังไม่ได้ตั้งค่า</p>
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-500 mb-1.5">Webhook HMAC Key</label>
              <input type="password" id="settBeamWebhookKey" autocomplete="new-password" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-white" placeholder="เว้นว่าง = ใช้คีย์เดิม">
              <p id="settBeamWebhookKeyHint" class="text-xs text-gray-400 mt-1">ยังไม่ได้ตั้งค่า</p>
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-500 mb-1.5">อายุ QR (นาที)</label>
              <input type="number" id="settBeamQrExpiry" min="5" max="60" step="1" value="15" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-white">
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-500 mb-1.5">Webhook URL (นำไปใส่ใน Beam Lighthouse → Webhook Settings, เลือก charge.succeeded / charge.failed)</label>
              <div class="flex gap-2">
                <input type="text" id="settBeamWebhookUrl" readonly class="w-full px-3 py-2.5 border border-gray-200 rounded-xl bg-gray-50 text-xs">
                <button type="button" onclick="copyBeamWebhookUrl()" class="px-3 rounded-xl border border-gray-200 bg-white text-xs font-semibold">คัดลอก</button>
              </div>
            </div>
          </div>
          <p id="beamLastTestMessage" class="text-xs text-gray-500 mt-3"></p>
          <p class="text-xs text-gray-400 mt-1">คีย์ถูกเก็บฝั่ง server เท่านั้น หน้านี้แสดงแค่ 4 ตัวท้าย · ต้องสลับเป็นโหมดแนบสลิปก่อนเปลี่ยน Merchant ID / API Key / Environment</p>
          <div class="mt-4 flex flex-wrap gap-2 justify-end">
            <button id="testBeamConnectionButton" data-testid="test-beam-connection-button" onclick="testBeamConnection()" class="px-5 py-2.5 rounded-xl text-sm font-semibold border border-indigo-300 bg-white text-indigo-700 hover:bg-indigo-50">
              <span class="material-icons-round text-sm align-middle mr-1">wifi_tethering</span> ทดสอบการเชื่อมต่อ
            </button>
            <button id="saveBeamSettingsButton" data-testid="save-beam-settings-button" onclick="saveBeamSettings()" class="px-5 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90" style="background:linear-gradient(135deg,#4f46e5,#818cf8);">
              <span class="material-icons-round text-sm align-middle mr-1">save</span> บันทึกคีย์ Beam
            </button>
          </div>
        </div>
        <div class="rounded-xl border-2 border-teal-200 bg-teal-50/70 p-4">
          <div class="flex items-start gap-3">
            <span class="material-icons-round text-teal-500 text-2xl">verified</span>
            <div>
              <p class="font-bold text-gray-800">Slip2Go Auto + Manual</p>
              <p class="text-xs text-gray-500 leading-relaxed mt-1">คนขับสแกน QR PromptPay → แนบรูปสลิป → ระบบตรวจยอด/สลิปซ้ำผ่าน Slip2Go แล้วเติมเงินอัตโนมัติ ถ้าระบบตรวจไม่ผ่าน แอดมินยังจัดการคำขอเติมเงินและเติมเงินด้วยมือได้จากหน้านี้</p>
            </div>
          </div>
        </div>
        <div class="mt-5">
          <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">บัญชีปลายทางสำหรับตรวจสลิป</label>
          <input type="text" id="settSlip2goReceiverAccount" value="${config.slip2go_receiver_account || ''}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="เช่น เลขบัญชีหรือ PromptPay ID ที่ต้องตรงกับสลิป">
          <p class="text-xs text-gray-400 mt-1.5">ถ้ากรอกค่า ระบบจะเทียบ receiver account จาก Slip2Go ก่อนเติมเงินอัตโนมัติ</p>
        </div>
        <div class="mt-4 rounded-xl border border-amber-200 bg-amber-50 p-4">
          <label class="flex items-start gap-3 cursor-pointer">
            <input type="checkbox" id="settSlip2goAllowMaskedReceiver" ${config.slip2go_allow_masked_receiver_account === true ? 'checked' : ''} class="mt-1 h-4 w-4 rounded border-amber-300 text-amber-600 focus:ring-amber-500">
            <span>
              <span class="block text-sm font-semibold text-amber-800">ยอมรับบัญชี masked ชั่วคราว</span>
              <span class="block text-xs text-amber-700 mt-1">ใช้เฉพาะกรณี Slip2Go ส่งปลายทางเป็น xxx-xxx-9045 ระหว่างรอข้อมูลบัญชีเต็ม</span>
            </span>
          </label>
          <button type="button" onclick="acceptMaskedSlip2goReceiverAccount()" class="mt-3 px-3 py-2 rounded-lg border border-amber-300 bg-white text-amber-700 text-xs font-semibold hover:bg-amber-100 transition-colors">
            ใช้ xxx-xxx-9045 ชั่วคราว
          </button>
        </div>
        <div class="mt-4 p-3 rounded-lg bg-amber-50 border border-amber-200 text-xs text-amber-700">
          <span class="material-icons-round text-sm align-middle mr-1">info</span>
          <strong>หมายเหตุ:</strong> ต้องตั้งค่า secret <code>SLIP2GO_API_KEY</code> ให้ Supabase Edge Function และรัน migration ก่อนใช้งานจริง
        </div>
        <div class="mt-5 flex justify-end">
          <button onclick="saveTopupModeSettings()" class="px-5 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-teal-200" style="background:linear-gradient(135deg,#0d9488,#14b8a6);">
            <span class="material-icons-round text-sm align-middle mr-1">save</span> บันทึกการตรวจสลิป
          </button>
        </div>
      </div>

      <!-- ========= โปรโมชั่นชวนเพื่อน + การถอน ========= -->
      <div class="glass-card p-6" data-testid="referral-settings">
        <div class="flex items-center gap-3 mb-5">
          <div class="w-10 h-10 bg-pink-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-pink-500">card_giftcard</span></div>
          <div>
            <h3 class="font-bold text-gray-800">โปรโมชั่นชวนเพื่อน & การถอนเงิน</h3>
            <p class="text-xs text-gray-400">รางวัลเข้ากระเป๋า "ถังระบบ" ของผู้ชวน · ขั้นบันไดคูณตามจำนวนชวนสำเร็จสะสม</p>
          </div>
        </div>
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5">ฐานรางวัล: คนขับชวนร้าน (฿)</label>
            <input type="number" id="settRefBaseDriverMerchant" min="0" step="1" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5">ฐานรางวัล: ลูกค้าชวนร้าน (฿)</label>
            <input type="number" id="settRefBaseCustomerMerchant" min="0" step="1" value="10" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5">ฐานรางวัล: ลูกค้าชวนลูกค้า — ผู้ชวน (฿)</label>
            <input type="number" id="settRefBaseCustomerCustomer" min="0" step="1" value="10" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5">ฐานรางวัล: คนขับชวนลูกค้า — ผู้ชวน (฿)</label>
            <input type="number" id="settRefBaseDriverCustomer" min="0" step="1" value="20" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5">ฐานรางวัล: ลูกค้าชวนคนขับ — ผู้ชวน (฿)</label>
            <input type="number" id="settRefBaseCustomerDriver" min="0" step="1" value="10" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5">ฐานรางวัล: คนขับชวนคนขับ — ผู้ชวน (฿)</label>
            <input type="number" id="settRefBaseDriverDriverReferrer" min="0" step="1" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5">รางวัลคนขับใหม่ (ไม่คูณขั้น) (฿)</label>
            <input type="number" id="settRefBaseDriverDriverNew" min="0" step="1" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5">แคปรางวัล/เดือน/ผู้ชวน (เกินแล้วรอแอดมินอนุมัติ)</label>
            <input type="number" id="settRefMaxPerMonth" min="0" step="1" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5">ขั้นบันได (JSON: from/to/multiplier)</label>
            <input type="text" id="settRefTiers" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 font-mono text-xs">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5">ถอนขั้นต่ำ — ถังเติมเอง (฿)</label>
            <input type="number" id="settWithdrawMinTopup" min="0" step="1" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5">ถอนขั้นต่ำ — ถังระบบ (฿)</label>
            <input type="number" id="settWithdrawMinSystem" min="0" step="1" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50">
          </div>
        </div>
        <div id="referralPendingReviewBox" class="mt-4 text-sm text-gray-500"></div>
        <div class="mt-5 flex justify-end gap-2">
          <button onclick="loadReferralSettings()" class="px-4 py-2.5 rounded-xl text-sm font-semibold border border-gray-200 bg-white">รีเฟรช</button>
          <button data-testid="save-referral-settings-button" onclick="saveReferralSettings()" class="px-5 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 shadow-md shadow-pink-200" style="background:linear-gradient(135deg,#db2777,#f472b6);">
            <span class="material-icons-round text-sm align-middle mr-1">save</span> บันทึกการตั้งค่ารางวัล
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
            <label class="mt-4 flex items-center gap-2 text-xs font-semibold text-gray-600">
              <input type="checkbox" id="settAdminLineEnabled" ${config.admin_line_enabled ? 'checked' : ''} class="w-4 h-4 text-green-600 rounded border-gray-300">
              เปิดใช้งาน LINE แจ้งเตือนแอดมิน
            </label>
            <label class="block text-xs font-semibold text-gray-500 mt-3 mb-1.5 uppercase tracking-wider">LINE recipient ID</label>
            <input type="text" id="settAdminLineRecipient" value="${config.admin_line_recipient_id || ''}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="U..., C..., หรือ R...">
            <p class="text-xs text-gray-400 mt-1.5">ใช้ userId, groupId หรือ roomId ที่ LINE Official Account สามารถ push message ได้</p>
            <label class="mt-5 flex items-center gap-2 text-xs font-semibold text-gray-600">
              <input type="checkbox" id="settAdminTelegramEnabled" ${config.admin_telegram_enabled ? 'checked' : ''} class="w-4 h-4 text-blue-500 rounded border-gray-300">
              เปิดใช้งาน Telegram แจ้งเตือนแอดมิน
            </label>
            <label class="block text-xs font-semibold text-gray-500 mt-3 mb-1.5 uppercase tracking-wider">Telegram Chat ID</label>
            <input type="text" id="settAdminTelegramChatId" value="${config.admin_telegram_chat_id || ''}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="-100... หรือ @username">
            <p class="text-xs text-gray-400 mt-1.5">ใช้ Chat ID ของ group/channel หรือ user ID ที่ bot เป็นสมาชิกอยู่</p>
          </div>
        </div>
        <div class="mt-4 flex gap-3">
          <button onclick="saveAdminEmail()" class="px-5 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">
            <span class="material-icons-round text-sm align-middle mr-1">save</span> บันทึกอีเมล
          </button>
          <button onclick="saveAdminLine()" class="px-5 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-green-200" style="background:linear-gradient(135deg,#16a34a,#22c55e);">
            <span class="material-icons-round text-sm align-middle mr-1">save</span> บันทึก LINE
          </button>
          <button onclick="testAdminLine()" class="px-5 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-emerald-200" style="background:linear-gradient(135deg,#059669,#10b981);">
            <span class="material-icons-round text-sm align-middle mr-1">send</span> ทดสอบ LINE
          </button>
          <button onclick="saveAdminTelegram()" class="px-5 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-blue-200" style="background:linear-gradient(135deg,#2563eb,#3b82f6);">
            <span class="material-icons-round text-sm align-middle mr-1">save</span> บันทึก Telegram
          </button>
          <button id="testAdminTelegramButton" data-testid="test-admin-telegram-button" onclick="testAdminTelegram()" class="px-5 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-sky-200" style="background:linear-gradient(135deg,#0284c7,#38bdf8);">
            <span class="material-icons-round text-sm align-middle mr-1">send</span> ทดสอบ Telegram
          </button>
          <button onclick="testAdminEmail()" class="px-5 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-red-200" style="background:linear-gradient(135deg,#ef4444,#f87171);">
            <span class="material-icons-round text-sm align-middle mr-1">send</span> ทดสอบส่งอีเมล
          </button>
        </div>
      </div>

      <!-- ========= StoreOS Connect ========= -->
      <div class="glass-card p-6">
        <div class="flex items-center gap-3 mb-5">
          <div class="w-10 h-10 bg-violet-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-violet-500">hub</span></div>
          <div>
            <h3 class="font-bold text-gray-800">StoreOS Connect</h3>
            <p class="text-xs text-gray-400">ออก JDC key และ webhook secret สำหรับนำไปตั้งค่าที่ StoreOS</p>
          </div>
        </div>
        <div class="grid grid-cols-1 lg:grid-cols-2 gap-4">
          <div class="hidden">
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">merchant_id</label>
            <input type="text" data-retired-storeos-merchant-field="true" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all font-mono text-xs" placeholder="UUID ของร้านจาก JDC">
            <p class="text-xs text-gray-400 mt-1.5">ใช้ merchant_id จากหน้า Merchant Settings ในแอป JDC</p>
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">StoreOS webhook URL</label>
            <input type="url" id="settStoreOsWebhookUrl" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="https://...">
            <p class="text-xs text-gray-400 mt-1.5">ปล่อยว่างได้ถ้ายังไม่พร้อมรับ outbound webhook</p>
          </div>
          <div class="rounded-xl border border-violet-100 bg-violet-50/60 px-4 py-3">
            <p class="text-xs font-semibold text-violet-700 uppercase tracking-wider">System connection</p>
            <p class="text-xs text-violet-600 mt-1.5">JDC uses one key/secret for StoreOS. StoreOS binds each shop by merchant_id copied from the JDC merchant app.</p>
          </div>
          <div class="hidden">
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">StoreOS shop ID</label>
            <input type="text" data-retired-storeos-shop-field="true" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="optional">
            <p class="text-xs text-gray-400 mt-1.5">รหัสร้านฝั่ง StoreOS ถ้ามี</p>
          </div>
        </div>
        <div class="mt-4 flex flex-wrap gap-4">
          <label class="flex items-center gap-2 text-xs font-semibold text-gray-600">
            <input type="checkbox" id="settStoreOsMenuManagedByPos" checked class="w-4 h-4 text-violet-600 rounded border-gray-300">
            ให้ StoreOS จัดการเมนูของร้านนี้
          </label>
          <label class="flex items-center gap-2 text-xs font-semibold text-gray-600">
            <input type="checkbox" id="settStoreOsRotateSecret" class="w-4 h-4 text-rose-600 rounded border-gray-300">
            Rotate webhook secret รอบนี้
          </label>
        </div>
        <div class="mt-5 flex flex-wrap gap-3">
          <button onclick="saveStoreOsConnectionSettings()" class="px-5 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-emerald-200" style="background:linear-gradient(135deg,#059669,#34d399);">
            <span class="material-icons-round text-sm align-middle mr-1">save</span> บันทึกค่า
          </button>
          <button onclick="provisionStoreOsConnection()" class="px-5 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-violet-200" style="background:linear-gradient(135deg,#7c3aed,#a78bfa);">
            <span class="material-icons-round text-sm align-middle mr-1">vpn_key</span> สร้าง/โหลด JDC key
          </button>
          <button onclick="rotateStoreOsWebhookSecret()" class="px-5 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-rose-200" style="background:linear-gradient(135deg,#e11d48,#fb7185);">
            <span class="material-icons-round text-sm align-middle mr-1">sync_lock</span> Rotate webhook secret
          </button>
        </div>
        <div class="mt-5 grid grid-cols-1 lg:grid-cols-2 gap-4">
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">JDC key</label>
            <div class="flex gap-2">
              <input type="text" id="settStoreOsJdcKey" readonly class="flex-1 px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/80 transition-all font-mono text-xs" placeholder="จะแสดงหลังสร้าง connection">
              <button onclick="copyStoreOsCredential('settStoreOsJdcKey')" class="px-3 py-2.5 bg-violet-50 text-violet-700 rounded-xl text-xs font-semibold border border-violet-100 hover:bg-violet-100">Copy</button>
            </div>
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">Webhook secret</label>
            <div class="flex gap-2">
              <input type="text" id="settStoreOsWebhookSecret" readonly class="flex-1 px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/80 transition-all font-mono text-xs" placeholder="แสดงเฉพาะตอนสร้างใหม่หรือ rotate">
              <button onclick="copyStoreOsCredential('settStoreOsWebhookSecret')" class="px-3 py-2.5 bg-rose-50 text-rose-700 rounded-xl text-xs font-semibold border border-rose-100 hover:bg-rose-100">Copy</button>
            </div>
            <p class="text-xs text-gray-400 mt-1.5">Preview: <span id="settStoreOsSecretPreview">-</span></p>
          </div>
        </div>
        <p id="settStoreOsResult" class="mt-4 text-xs text-violet-700 bg-violet-50 border border-violet-100 rounded-xl px-4 py-3">ยังไม่ได้สร้าง connection ในรอบนี้</p>
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
            <div>
              <label class="block text-xs font-semibold text-gray-500 mb-1 uppercase tracking-wider">Laundry GP - หักร้าน (%)</label>
              <input type="number" id="settLaundryMerchantGpRate" value="${laundryMerchantGpDefault.toFixed(1)}" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-white transition-all" step="0.1" min="0" max="100">
              <p class="text-xs text-gray-400 mt-1.5">ค่า default สำหรับยอดซักผ้า ร้านแต่ละราย override ได้</p>
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-500 mb-1 uppercase tracking-wider">Laundry GP ให้คนขับ (%)</label>
              <input type="number" id="settLaundryGpDriverRate" value="${laundryGpDriverDefault.toFixed(1)}" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-white transition-all" step="0.1" min="0" max="100">
              <p class="text-xs text-gray-400 mt-1.5">เพิ่มรายได้คนขับจาก GP ยอดซักผ้า</p>
            </div>
            <div>
              <label class="block text-xs font-semibold text-gray-500 mb-1 uppercase tracking-wider">Laundry GP - หักค่าส่ง (%)</label>
              <input type="number" id="settLaundryDeliveryGpRate" value="${laundryDeliveryGpDefault.toFixed(1)}" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-white transition-all" step="0.1" min="0" max="100">
              <p class="text-xs text-gray-400 mt-1.5">ค่า default สำหรับค่าส่งซักผ้าขาไป/ขากลับ</p>
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

      <div class="flex justify-end">
        <button onclick="saveServiceRatesSettings()" class="px-5 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-blue-200" style="background:linear-gradient(135deg,#3b82f6,#60a5fa);">
          <span class="material-icons-round text-sm align-middle mr-1">save</span> บันทึกอัตราค่าบริการ
        </button>
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

      ${renderShopSettingsSection(shopKvConfig, shopStoreCount)}

      ${renderAiSettingsSection()}

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

      <!-- ========= App Update Policy ========= -->
      <div class="glass-card p-6">
        <div class="flex items-center gap-3 mb-5">
          <div class="w-10 h-10 bg-blue-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-blue-600">system_update_alt</span></div>
          <div>
            <h3 class="font-bold text-gray-800">แจ้งอัปเดตแอป</h3>
            <p class="text-xs text-gray-400">ตั้งค่า optional/force update จาก system_config.app_update_policy</p>
          </div>
        </div>

        <div class="grid grid-cols-1 md:grid-cols-2 gap-5">
          <label class="flex items-center gap-3 p-4 rounded-xl bg-blue-50/60 border border-blue-100">
            <input id="settAppUpdateEnabled" type="checkbox" class="w-5 h-5" ${appUpdatePolicy.enabled ? 'checked' : ''}>
            <span>
              <span class="block text-sm font-semibold text-gray-700">เปิดแจ้งเตือนอัปเดต</span>
              <span class="block text-xs text-gray-500">ค่าเริ่มต้นควรปิดไว้จนกว่าจะพร้อม release</span>
            </span>
          </label>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">โหมด</label>
            <select id="settAppUpdateMode" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all">
              <option value="optional" ${appUpdatePolicy.mode !== 'force' ? 'selected' : ''}>Optional - ผู้ใช้กดไว้ภายหลังได้</option>
              <option value="force" ${appUpdatePolicy.mode === 'force' ? 'selected' : ''}>Force - ต้องอัปเดตก่อนเข้าแอป</option>
            </select>
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">Latest Version</label>
            <input id="settAppUpdateLatestVersion" value="${escapeForInput(appUpdatePolicy.latest_version || '')}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="1.5.2">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">Latest Build</label>
            <input id="settAppUpdateLatestBuild" type="number" min="0" value="${escapeForInput(appUpdatePolicy.latest_build ?? '')}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="92">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">Minimum Supported Version</label>
            <input id="settAppUpdateMinSupportedVersion" value="${escapeForInput(appUpdatePolicy.min_supported_version || '')}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="1.5.0">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">Minimum Supported Build</label>
            <input id="settAppUpdateMinSupportedBuild" type="number" min="0" value="${escapeForInput(appUpdatePolicy.min_supported_build ?? '')}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="90">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">หัวข้อภาษาไทย</label>
            <input id="settAppUpdateTitleTh" value="${escapeForInput(appUpdatePolicy.title_th || DEFAULT_APP_UPDATE_POLICY.title_th)}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">ข้อความแจ้งเตือน</label>
            <input id="settAppUpdateMessageTh" value="${escapeForInput(appUpdatePolicy.message_th || DEFAULT_APP_UPDATE_POLICY.message_th)}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">Android Store URL</label>
            <input id="settAppUpdateAndroidUrl" type="url" value="${escapeForInput(appUpdatePolicy.android_url || '')}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="https://play.google.com/store/apps/details?id=...">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">iOS Store URL</label>
            <input id="settAppUpdateIosUrl" type="url" value="${escapeForInput(appUpdatePolicy.ios_url || '')}" class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all" placeholder="https://apps.apple.com/...">
          </div>
        </div>

        <div class="mt-5 flex justify-end">
          <button onclick="saveAppUpdatePolicySettings()" data-testid="save-app-update-policy-button" class="px-5 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-blue-200" style="background:linear-gradient(135deg,#2563eb,#1d4ed8);">
            <span class="material-icons-round text-sm align-middle mr-1">save</span> บันทึกนโยบายอัปเดตแอป
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
  // ปุ่มบันทึกในหน้านี้เรียกผ่าน inline onclick -> ต้องผูกเข้า global scope
  globalThis.saveShopSettings = () =>
    saveShopSettings({
      showToast: globalThis.showToast,
      _upsertSystemConfigKeyValues: globalThis._upsertSystemConfigKeyValues,
    });

  // AI settings โหลดแยก (RPC แอดมิน) — ไม่ให้หน้า Settings ช้าตาม
  loadAiSettingsSection({
    ...(ctx || {}),
    supabase: ctx?.supabase || supabase,
    _upsertSystemConfigKeyValues: globalThis._upsertSystemConfigKeyValues,
  }).catch((e) => console.warn('loadAiSettingsSection failed', e));

  // Load banners and app assets after render
  loadBanners();
  loadAppAssets();
  // ต้องส่ง ctx ไปด้วย: bridge ไม่มี supabase client ของตัวเอง (globalThis.supabase ไม่มีในแอปนี้)
  // ถ้าเปิดหน้า Settings เป็นหน้าแรก _ctx ของ bridge ยังว่าง -> "reading 'from' of undefined"
  if (typeof globalThis.loadBeamSettings === 'function') globalThis.loadBeamSettings(ctx);
  if (typeof globalThis.loadReferralSettings === 'function') globalThis.loadReferralSettings(ctx);
}

export function wireSettingsBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  globalThis.__adminWebBridge.renderSettingsPage = renderSettingsPage;
}
