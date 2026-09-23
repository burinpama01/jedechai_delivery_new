// ตั้งค่าบริการฝากซื้อ/ฝากหิ้ว — section ในหน้า Settings
//
// แยกเป็นโมดูลของตัวเองเพราะ settingsPage.js ยาว ~1000 บรรทัดอยู่แล้ว
// ค่าทั้งหมดเก็บเป็น key/value ใน system_config และถูก snapshot ลงออเดอร์ตอนสร้าง
// -> แก้ค่าที่นี่มีผลกับ "ออเดอร์ใหม่" เท่านั้น ออเดอร์ที่กำลังทำอยู่ไม่เปลี่ยนราคา

export const SHOP_CONFIG_KEYS = [
  "shop_enabled",
  "shop_ai_receipt_enabled",
  "shop_store_radius_km",
  "shop_store_radius_max_km",
  "shop_show_closed_stores",
  "shop_arrival_radius_m",
  "shop_location_freshness_sec",
  "shop_arrival_geofence_enabled",
  "shop_fee_percent",
  "shop_fee_tiers",
  "shop_fee_min",
  "shop_fee_max",
  "shop_fee_multiplier_by_category",
  "shop_driver_share_percent",
  "shop_min_budget",
  "shop_max_budget",
  "shop_new_driver_max_budget",
  "shop_new_driver_completed_jobs",
  "shop_budget_buffer_percent",
  "shop_max_items",
  "shop_driver_to_store_km",
  "shop_far_pickup_enabled",
  "shop_far_pickup_rate_per_km_motorcycle",
  "shop_far_pickup_rate_per_km_car",
  "shop_far_pickup_max_fee",
  "shop_max_pickup_distance_km",
  "shop_cancel_fee_percent",
  "shop_cancel_fee_max",
  "shop_cancel_fee_to_driver_percent",
  "shop_match_timeout_min",
  "shop_photo_confirm_min",
  "shop_photo_escalate_min",
  "shop_receipt_tolerance_baht",
  "shop_receipt_tolerance_percent",
  "shop_receipt_review_threshold_percent",
  "shop_substitution_timeout_min",
  "shop_quote_ttl_sec",
];

const CATEGORIES = [
  ["grocery", "ร้านของชำ"],
  ["mall", "ห้างสรรพสินค้า"],
  ["market", "ตลาดสด"],
  ["convenience", "ร้านสะดวกซื้อ"],
  ["pharmacy", "ร้านขายยา"],
];

const DEFAULTS = {
  shop_store_radius_km: 10,
  shop_store_radius_max_km: 25,
  shop_arrival_radius_m: 150,
  shop_location_freshness_sec: 120,
  shop_fee_percent: 10,
  shop_fee_min: 25,
  shop_fee_max: 200,
  shop_driver_share_percent: 80,
  shop_min_budget: 100,
  shop_max_budget: 5000,
  shop_new_driver_max_budget: 500,
  shop_new_driver_completed_jobs: 20,
  shop_budget_buffer_percent: 15,
  shop_max_items: 30,
  shop_driver_to_store_km: 20,
  shop_far_pickup_rate_per_km_motorcycle: 5,
  shop_far_pickup_rate_per_km_car: 8,
  shop_cancel_fee_percent: 25,
  shop_cancel_fee_max: 100,
  shop_cancel_fee_to_driver_percent: 100,
  shop_match_timeout_min: 10,
  shop_photo_confirm_min: 5,
  shop_photo_escalate_min: 20,
  shop_receipt_tolerance_baht: 5,
  shop_receipt_tolerance_percent: 2,
  shop_receipt_review_threshold_percent: 10,
  shop_substitution_timeout_min: 5,
  shop_quote_ttl_sec: 120,
};

function isOn(raw, fallback = false) {
  if (raw === undefined || raw === null || String(raw).trim() === "") return fallback;
  return ["true", "t", "1", "yes"].includes(String(raw).trim().toLowerCase());
}

function num(kv, key) {
  const raw = kv?.[key];
  if (raw === undefined || raw === null || String(raw).trim() === "") return DEFAULTS[key] ?? "";
  const n = Number(raw);
  return Number.isFinite(n) ? n : (DEFAULTS[key] ?? "");
}

// config ที่ "ยังไม่กำหนด" — เก็บเป็น 'null' ใน DB, แสดงเป็นช่องว่าง
function nullableNum(kv, key) {
  const raw = kv?.[key];
  if (raw === undefined || raw === null) return "";
  const s = String(raw).trim();
  if (s === "" || s.toLowerCase() === "null") return "";
  const n = Number(s);
  return Number.isFinite(n) ? n : "";
}

function parseTiers(kv) {
  try {
    const parsed = JSON.parse(kv?.shop_fee_tiers || "[]");
    if (Array.isArray(parsed) && parsed.length) return parsed;
  } catch (_) { /* ค่าเสียหาย -> ใช้ค่าเริ่มต้น */ }
  return [{ max: 500, fee: 30 }, { max: 1500, fee: 50 }, { max: null, fee: 80 }];
}

function parseMultipliers(kv) {
  try {
    const parsed = JSON.parse(kv?.shop_fee_multiplier_by_category || "{}");
    if (parsed && typeof parsed === "object") return parsed;
  } catch (_) { /* ignore */ }
  return {};
}

function numInput(id, value, { step = "1", min = "0", placeholder = "" } = {}) {
  return `<input type="number" id="${id}" value="${value === "" ? "" : value}" step="${step}" min="${min}"
    placeholder="${placeholder}"
    class="w-full px-4 py-2.5 border border-gray-200 rounded-xl bg-gray-50/50 transition-all">`;
}

function field(label, inner, hint) {
  return `
    <div>
      <label class="block text-xs font-semibold text-gray-500 mb-1.5 uppercase tracking-wider">${label}</label>
      ${inner}
      ${hint ? `<p class="text-[11px] text-gray-400 mt-1">${hint}</p>` : ""}
    </div>`;
}

function toggle(id, on, label, hint) {
  return `
    <label class="flex items-start gap-3 p-3 rounded-xl border border-gray-200 bg-gray-50/50 cursor-pointer">
      <input type="checkbox" id="${id}" ${on ? "checked" : ""} class="mt-0.5">
      <span>
        <span class="block text-sm font-semibold text-gray-700">${label}</span>
        ${hint ? `<span class="block text-[11px] text-gray-400 mt-0.5">${hint}</span>` : ""}
      </span>
    </label>`;
}

/**
 * คืน HTML ของ section ฝากซื้อ
 * @param {object} kv ค่าจาก system_config แบบ key/value
 * @param {number} storeCount จำนวนร้านที่เปิดใช้งาน (ใช้เตือนก่อนเปิดบริการ)
 */
export function renderShopSettingsSection(kv = {}, storeCount = 0) {
  const enabled = isOn(kv.shop_enabled, false);
  const tiers = parseTiers(kv);
  const mult = parseMultipliers(kv);

  const tierRows = tiers
    .map((t, i) => {
      const isLast = t.max === null || t.max === undefined;
      return `
      <div class="flex items-center gap-2 mb-2">
        <span class="text-xs text-gray-400 w-14 shrink-0">ขั้น ${i + 1}</span>
        <span class="text-xs text-gray-500">ยอดบิลถึง</span>
        <input type="number" id="shopTierMax${i}" value="${isLast ? "" : t.max}" placeholder="ไม่จำกัด"
          class="w-28 px-3 py-2 border border-gray-200 rounded-lg bg-gray-50/50 text-sm" min="0" step="1">
        <span class="text-xs text-gray-500">บาท คิดค่าบริการ</span>
        <input type="number" id="shopTierFee${i}" value="${t.fee ?? 0}"
          class="w-24 px-3 py-2 border border-gray-200 rounded-lg bg-gray-50/50 text-sm" min="0" step="1">
        <span class="text-xs text-gray-500">บาท</span>
      </div>`;
    })
    .join("");

  const multFields = CATEGORIES.map(([key, label]) =>
    field(
      label,
      numInput(`shopMult_${key}`, mult[key] ?? 1.0, { step: "0.05", min: "0" }),
    ),
  ).join("");

  return `
      <!-- ========= บริการฝากซื้อ/ฝากหิ้ว ========= -->
      <div class="glass-card p-6">
        <div class="flex items-center gap-3 mb-5">
          <div class="w-10 h-10 bg-violet-50 rounded-xl flex items-center justify-center">
            <span class="material-icons-round text-violet-500">shopping_basket</span>
          </div>
          <div>
            <h3 class="font-bold text-gray-800">บริการฝากซื้อ/ฝากหิ้ว</h3>
            <p class="text-xs text-gray-400">ค่าที่แก้ที่นี่มีผลกับออเดอร์ใหม่เท่านั้น ออเดอร์ที่กำลังทำอยู่ใช้ค่าเดิมที่บันทึกไว้ตอนสั่ง</p>
          </div>
        </div>

        ${
          !enabled && storeCount === 0
            ? `<div class="mb-5 p-3 rounded-xl bg-amber-50 border border-amber-200 text-sm text-amber-800">
                 <span class="material-icons-round text-sm align-middle mr-1">warning</span>
                 ยังไม่มีร้านในระบบ — ต้องเพิ่มร้านที่หน้า "ร้านฝากซื้อ" ก่อน แล้วค่อยเปิดบริการ
               </div>`
            : ""
        }

        <div class="grid grid-cols-1 md:grid-cols-2 gap-3 mb-6">
          ${toggle("shopEnabled", enabled, "เปิดบริการฝากซื้อ", "ปิดอยู่ = ลูกค้าไม่เห็นบริการนี้และสั่งไม่ได้")}
          ${toggle("shopAiReceiptEnabled", isOn(kv.shop_ai_receipt_enabled, false), "ให้ AI อ่านยอดจากใบเสร็จ", "ปิดได้ทันทีถ้ามีปัญหา ระบบยังทำงานต่อได้โดยใช้ยอดที่คนขับกรอก")}
        </div>

        <!-- ร้าน -->
        <div class="border-t border-gray-100 pt-5 mb-5">
          <div class="font-semibold text-gray-700 text-sm mb-3">ร้านค้า</div>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-5">
            ${field("รัศมีค้นหาร้าน (กม.)", numInput("shopStoreRadiusKm", num(kv, "shop_store_radius_km"), { step: "0.5", min: "0.5" }), "ใช้กับร้านที่ไม่ได้ตั้งรัศมีเอง")}
            ${field("เพดานรัศมีที่ตั้งได้ (กม.)", numInput("shopStoreRadiusMaxKm", num(kv, "shop_store_radius_max_km"), { step: "0.5", min: "0.5" }), "กันตั้งรัศมีรายร้านสูงเกินจริง")}
            <div class="flex items-end">
              ${toggle("shopShowClosedStores", isOn(kv.shop_show_closed_stores, true), "แสดงร้านที่ปิดอยู่", "แสดงแบบจางและกดไม่ได้")}
            </div>
          </div>
        </div>

        <!-- ค่าบริการ -->
        <div class="border-t border-gray-100 pt-5 mb-5">
          <div class="font-semibold text-gray-700 text-sm mb-1">ค่าบริการฝากซื้อ</div>
          <p class="text-[11px] text-gray-400 mb-3">
            คิดจาก <b>ค่าที่มากกว่า</b> ระหว่างขั้นบันไดกับเปอร์เซ็นต์ แล้วคูณ multiplier ของหมวดร้าน สุดท้าย clamp ด้วยขั้นต่ำ/เพดาน
          </p>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-5 mb-4">
            ${field("เปอร์เซ็นต์ของยอดบิล (%)", numInput("shopFeePercent", num(kv, "shop_fee_percent"), { step: "0.5", min: "0" }))}
            ${field("ค่าบริการขั้นต่ำ (บาท)", numInput("shopFeeMin", num(kv, "shop_fee_min"), { step: "1", min: "0" }))}
            ${field("ค่าบริการสูงสุด (บาท)", numInput("shopFeeMax", num(kv, "shop_fee_max"), { step: "1", min: "0" }))}
          </div>
          <div class="mb-4">
            <label class="block text-xs font-semibold text-gray-500 mb-2 uppercase tracking-wider">ขั้นบันไดตามยอดบิล</label>
            ${tierRows}
            <p class="text-[11px] text-gray-400">ขั้นสุดท้ายเว้น "ยอดบิลถึง" ว่างไว้ = ใช้กับยอดที่เกินทุกขั้น</p>
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-2 uppercase tracking-wider">ตัวคูณตามหมวดร้าน</label>
            <div class="grid grid-cols-2 md:grid-cols-5 gap-4">${multFields}</div>
            <p class="text-[11px] text-gray-400 mt-1">1.0 = คิดเท่ากับสูตรปกติ</p>
          </div>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-5 mt-4">
            ${field("ส่วนแบ่งค่าบริการที่เข้าคนขับ (%)", numInput("shopDriverSharePercent", num(kv, "shop_driver_share_percent"), { step: "1", min: "0" }), "ที่เหลือเป็นรายได้แพลตฟอร์ม")}
          </div>
        </div>

        <!-- วงเงิน -->
        <div class="border-t border-gray-100 pt-5 mb-5">
          <div class="font-semibold text-gray-700 text-sm mb-3">วงเงินต่อออเดอร์</div>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-5">
            ${field("วงเงินขั้นต่ำ (บาท)", numInput("shopMinBudget", num(kv, "shop_min_budget"), { step: "10", min: "1" }))}
            ${field("วงเงินสูงสุด (บาท)", numInput("shopMaxBudget", num(kv, "shop_max_budget"), { step: "100", min: "1" }))}
            ${field("จำนวนรายการสูงสุด", numInput("shopMaxItems", num(kv, "shop_max_items"), { step: "1", min: "1" }))}
            ${field("เพดานวงเงินของคนขับใหม่ (บาท)", numInput("shopNewDriverMaxBudget", num(kv, "shop_new_driver_max_budget"), { step: "50", min: "0" }), "ออเดอร์ที่เกินนี้จะไม่แสดงให้คนขับใหม่เห็น")}
            ${field("ทำงานสำเร็จกี่ครั้งจึงพ้นสถานะคนขับใหม่", numInput("shopNewDriverJobs", num(kv, "shop_new_driver_completed_jobs"), { step: "1", min: "0" }), "นับเฉพาะงานฝากซื้อ · แอดมินปลดล็อกรายคนได้ที่หน้าคนขับ")}
            ${field("บวกเผื่อวงเงินที่แนะนำ (%)", numInput("shopBudgetBufferPercent", num(kv, "shop_budget_buffer_percent"), { step: "1", min: "0" }))}
          </div>
        </div>

        <!-- คนขับ / ระยะ -->
        <div class="border-t border-gray-100 pt-5 mb-5">
          <div class="font-semibold text-gray-700 text-sm mb-3">คนขับและระยะทาง</div>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-5 mb-4">
            ${field("รัศมีคนขับถึงร้าน (กม.)", numInput("shopDriverToStoreKm", num(kv, "shop_driver_to_store_km"), { step: "0.5", min: "0.5" }), "เกินรัศมีนี้จะเริ่มคิดค่าวิ่งไกล")}
            ${field("ค่าวิ่งไกล มอเตอร์ไซค์ (บาท/กม.)", numInput("shopFarRateMoto", num(kv, "shop_far_pickup_rate_per_km_motorcycle"), { step: "1", min: "0" }))}
            ${field("ค่าวิ่งไกล รถยนต์ (บาท/กม.)", numInput("shopFarRateCar", num(kv, "shop_far_pickup_rate_per_km_car"), { step: "1", min: "0" }))}
            ${field("เพดานค่าวิ่งไกล (บาท)", numInput("shopFarMaxFee", nullableNum(kv, "shop_far_pickup_max_fee"), { step: "10", min: "0", placeholder: "เว้นว่าง = ไม่จำกัด" }), "ยังไม่กำหนด = เว้นว่างไว้")}
            ${field("ระยะคนขับไกลสุดที่รับได้ (กม.)", numInput("shopMaxPickupKm", nullableNum(kv, "shop_max_pickup_distance_km"), { step: "1", min: "0", placeholder: "เว้นว่าง = ไม่จำกัด" }), "ไกลเกินนี้ถือว่าไม่มีคนขับ")}
            ${field("รอหาคนขับกี่นาทีก่อนคืนเงิน", numInput("shopMatchTimeoutMin", num(kv, "shop_match_timeout_min"), { step: "1", min: "1" }))}
          </div>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-5">
            ${field("ระยะที่ถือว่าถึงร้าน (เมตร)", numInput("shopArrivalRadiusM", num(kv, "shop_arrival_radius_m"), { step: "10", min: "10" }), "ควร ≥ 150 ให้ตรงกับที่แอปคนขับผ่อนตอน GPS ไม่แม่น")}
            ${field("ตำแหน่งคนขับต้องใหม่ไม่เกิน (วินาที)", numInput("shopLocationFreshnessSec", num(kv, "shop_location_freshness_sec"), { step: "10", min: "30" }))}
            <div class="flex items-end">
              ${toggle("shopArrivalGeofenceEnabled", isOn(kv.shop_arrival_geofence_enabled, true), "บังคับตรวจตำแหน่งตอนกดถึงร้าน", "ปิดได้ถ้าพบปัญหาหน้างาน")}
            </div>
            <div class="flex items-end">
              ${toggle("shopFarPickupEnabled", isOn(kv.shop_far_pickup_enabled, true), "คิดค่าวิ่งไกล", "ปิด = ไม่คิดเพิ่มแม้คนขับอยู่นอกรัศมี")}
            </div>
          </div>
        </div>

        <!-- ยกเลิก -->
        <div class="border-t border-gray-100 pt-5 mb-5">
          <div class="font-semibold text-gray-700 text-sm mb-3">การยกเลิก</div>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-5">
            ${field("ค่าปรับยกเลิกตอนคนขับถึงร้านแล้ว (%)", numInput("shopCancelFeePercent", num(kv, "shop_cancel_fee_percent"), { step: "1", min: "0" }), "คิดจากยอดที่กันไว้")}
            ${field("เพดานค่าปรับ (บาท)", numInput("shopCancelFeeMax", num(kv, "shop_cancel_fee_max"), { step: "10", min: "0" }))}
            ${field("ค่าปรับเข้าคนขับ (%)", numInput("shopCancelFeeToDriver", num(kv, "shop_cancel_fee_to_driver_percent"), { step: "1", min: "0" }), "ที่เหลือเข้าแพลตฟอร์ม")}
          </div>
          <p class="text-[11px] text-gray-400 mt-2">
            ยกเลิกก่อนคนขับถึงร้านไม่มีค่าปรับ · หลังคนขับชำระเงินที่ร้านแล้วลูกค้ายกเลิกไม่ได้ ต้องให้แอดมินจัดการ
          </p>
        </div>

        <!-- หลักฐาน -->
        <div class="border-t border-gray-100 pt-5">
          <div class="font-semibold text-gray-700 text-sm mb-3">หลักฐานและการตรวจสอบ</div>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-5">
            ${field("รอลูกค้ายืนยันรูปสินค้า (นาที)", numInput("shopPhotoConfirmMin", num(kv, "shop_photo_confirm_min"), { step: "1", min: "1" }), "ครบเวลาแล้วขึ้นช่องทางติดต่อคนขับ ไม่ยืนยันอัตโนมัติ")}
            ${field("ส่งเข้าคิวแอดมินหลังผ่านไป (นาที)", numInput("shopPhotoEscalateMin", num(kv, "shop_photo_escalate_min"), { step: "1", min: "1" }))}
            ${field("รอลูกค้าตอบเรื่องของหมด (นาที)", numInput("shopSubstitutionTimeoutMin", num(kv, "shop_substitution_timeout_min"), { step: "1", min: "1" }))}
            ${field("ยอด AI ต่างจากที่คนขับกรอกได้ (บาท)", numInput("shopReceiptToleranceBaht", num(kv, "shop_receipt_tolerance_baht"), { step: "1", min: "0" }))}
            ${field("หรือต่างได้ (%)", numInput("shopReceiptTolerancePercent", num(kv, "shop_receipt_tolerance_percent"), { step: "0.5", min: "0" }), "ใช้ค่าที่มากกว่าใน 2 อัน")}
            ${field("ยอดต่างจากวงเงินเกินเท่าไหร่ให้แอดมินตรวจ (%)", numInput("shopReceiptReviewThreshold", num(kv, "shop_receipt_review_threshold_percent"), { step: "1", min: "0" }))}
            ${field("อายุราคาที่เสนอ (วินาที)", numInput("shopQuoteTtlSec", num(kv, "shop_quote_ttl_sec"), { step: "10", min: "30" }), "เกินเวลานี้ต้องขอราคาใหม่")}
          </div>
        </div>

        <div class="mt-6 flex justify-end">
          <button onclick="saveShopSettings()" class="px-5 py-2.5 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-violet-200" style="background:linear-gradient(135deg,#8b5cf6,#6366f1);">
            <span class="material-icons-round text-sm align-middle mr-1">save</span> บันทึกค่าฝากซื้อ
          </button>
        </div>
      </div>
`;
}

// ── อ่านค่าจากฟอร์ม + validate ──────────────────────────────
// คืน { rows } เมื่อผ่าน หรือ { error } เมื่อไม่ผ่าน (แยกออกมาเพื่อเทสต์ได้)
export function collectShopSettings(getValue) {
  const numOf = (id) => {
    const raw = getValue(id);
    if (raw === undefined || raw === null || String(raw).trim() === "") return null;
    const n = Number(raw);
    return Number.isFinite(n) ? n : NaN;
  };
  const boolOf = (id) => (getValue(id) ? "true" : "false");

  const required = {
    shop_store_radius_km: numOf("shopStoreRadiusKm"),
    shop_store_radius_max_km: numOf("shopStoreRadiusMaxKm"),
    shop_arrival_radius_m: numOf("shopArrivalRadiusM"),
    shop_location_freshness_sec: numOf("shopLocationFreshnessSec"),
    shop_fee_percent: numOf("shopFeePercent"),
    shop_fee_min: numOf("shopFeeMin"),
    shop_fee_max: numOf("shopFeeMax"),
    shop_driver_share_percent: numOf("shopDriverSharePercent"),
    shop_min_budget: numOf("shopMinBudget"),
    shop_max_budget: numOf("shopMaxBudget"),
    shop_new_driver_max_budget: numOf("shopNewDriverMaxBudget"),
    shop_new_driver_completed_jobs: numOf("shopNewDriverJobs"),
    shop_budget_buffer_percent: numOf("shopBudgetBufferPercent"),
    shop_max_items: numOf("shopMaxItems"),
    shop_driver_to_store_km: numOf("shopDriverToStoreKm"),
    shop_far_pickup_rate_per_km_motorcycle: numOf("shopFarRateMoto"),
    shop_far_pickup_rate_per_km_car: numOf("shopFarRateCar"),
    shop_cancel_fee_percent: numOf("shopCancelFeePercent"),
    shop_cancel_fee_max: numOf("shopCancelFeeMax"),
    shop_cancel_fee_to_driver_percent: numOf("shopCancelFeeToDriver"),
    shop_match_timeout_min: numOf("shopMatchTimeoutMin"),
    shop_photo_confirm_min: numOf("shopPhotoConfirmMin"),
    shop_photo_escalate_min: numOf("shopPhotoEscalateMin"),
    shop_substitution_timeout_min: numOf("shopSubstitutionTimeoutMin"),
    shop_receipt_tolerance_baht: numOf("shopReceiptToleranceBaht"),
    shop_receipt_tolerance_percent: numOf("shopReceiptTolerancePercent"),
    shop_receipt_review_threshold_percent: numOf("shopReceiptReviewThreshold"),
    shop_quote_ttl_sec: numOf("shopQuoteTtlSec"),
  };

  for (const [key, value] of Object.entries(required)) {
    if (value === null || Number.isNaN(value)) {
      return { error: `ค่า ${key} ต้องเป็นตัวเลข` };
    }
    if (value < 0) return { error: `ค่า ${key} ต้องไม่ติดลบ` };
  }

  // ความสัมพันธ์ระหว่างค่า — จับให้ได้ก่อนบันทึก ไม่งั้นระบบจะทำงานเพี้ยนเงียบ ๆ
  if (required.shop_min_budget > required.shop_max_budget) {
    return { error: "วงเงินขั้นต่ำต้องไม่มากกว่าวงเงินสูงสุด" };
  }
  if (required.shop_fee_min > required.shop_fee_max) {
    return { error: "ค่าบริการขั้นต่ำต้องไม่มากกว่าค่าบริการสูงสุด" };
  }
  if (required.shop_store_radius_km > required.shop_store_radius_max_km) {
    return { error: "รัศมีค้นหาร้านต้องไม่เกินเพดานรัศมี" };
  }
  if (required.shop_driver_share_percent > 100) {
    return { error: "ส่วนแบ่งคนขับต้องไม่เกิน 100%" };
  }
  if (required.shop_cancel_fee_to_driver_percent > 100) {
    return { error: "ค่าปรับที่เข้าคนขับต้องไม่เกิน 100%" };
  }
  if (required.shop_cancel_fee_percent > 100) {
    return { error: "เปอร์เซ็นต์ค่าปรับต้องไม่เกิน 100%" };
  }
  if (required.shop_photo_escalate_min < required.shop_photo_confirm_min) {
    return { error: "เวลาส่งเข้าคิวแอดมินต้องไม่น้อยกว่าเวลารอลูกค้ายืนยัน" };
  }
  if (required.shop_new_driver_max_budget > required.shop_max_budget) {
    return { error: "เพดานคนขับใหม่ต้องไม่เกินวงเงินสูงสุด" };
  }

  // ขั้นบันได — ต้องเรียงจากน้อยไปมาก และขั้นสุดท้ายต้องเป็นไม่จำกัด
  const tiers = [];
  for (let i = 0; i < 3; i++) {
    const maxRaw = getValue(`shopTierMax${i}`);
    const feeRaw = getValue(`shopTierFee${i}`);
    if (feeRaw === undefined || feeRaw === null || String(feeRaw).trim() === "") continue;
    const fee = Number(feeRaw);
    if (!Number.isFinite(fee) || fee < 0) return { error: `ค่าบริการขั้น ${i + 1} ไม่ถูกต้อง` };
    const hasMax = maxRaw !== undefined && maxRaw !== null && String(maxRaw).trim() !== "";
    const max = hasMax ? Number(maxRaw) : null;
    if (hasMax && (!Number.isFinite(max) || max <= 0)) {
      return { error: `ยอดบิลของขั้น ${i + 1} ไม่ถูกต้อง` };
    }
    tiers.push({ max, fee });
  }
  if (!tiers.length) return { error: "ต้องมีขั้นบันไดค่าบริการอย่างน้อย 1 ขั้น" };
  if (tiers[tiers.length - 1].max !== null) {
    return { error: "ขั้นสุดท้ายต้องเว้น 'ยอดบิลถึง' ว่างไว้ (ไม่จำกัด)" };
  }
  for (let i = 1; i < tiers.length; i++) {
    const prev = tiers[i - 1].max;
    const cur = tiers[i].max;
    if (prev !== null && cur !== null && cur <= prev) {
      return { error: "ยอดบิลของขั้นบันไดต้องเรียงจากน้อยไปมาก" };
    }
  }

  // multiplier ตามหมวด
  const mult = {};
  for (const [key] of CATEGORIES) {
    const raw = getValue(`shopMult_${key}`);
    const n = raw === undefined || raw === null || String(raw).trim() === "" ? 1.0 : Number(raw);
    if (!Number.isFinite(n) || n < 0) return { error: `ตัวคูณของหมวด ${key} ไม่ถูกต้อง` };
    mult[key] = n;
  }

  // ค่าที่ "ยังไม่กำหนด" — เว้นว่าง = เก็บเป็น 'null'
  const farMax = getValue("shopFarMaxFee");
  const maxPickup = getValue("shopMaxPickupKm");
  const nullable = (raw, label) => {
    if (raw === undefined || raw === null || String(raw).trim() === "") return "null";
    const n = Number(raw);
    if (!Number.isFinite(n) || n < 0) return { error: `${label} ไม่ถูกต้อง` };
    return String(n);
  };
  const farMaxVal = nullable(farMax, "เพดานค่าวิ่งไกล");
  if (typeof farMaxVal === "object") return farMaxVal;
  const maxPickupVal = nullable(maxPickup, "ระยะคนขับไกลสุด");
  if (typeof maxPickupVal === "object") return maxPickupVal;

  const rows = [
    { key: "shop_enabled", value: boolOf("shopEnabled") },
    { key: "shop_ai_receipt_enabled", value: boolOf("shopAiReceiptEnabled") },
    { key: "shop_show_closed_stores", value: boolOf("shopShowClosedStores") },
    { key: "shop_arrival_geofence_enabled", value: boolOf("shopArrivalGeofenceEnabled") },
    { key: "shop_far_pickup_enabled", value: boolOf("shopFarPickupEnabled") },
    { key: "shop_fee_tiers", value: JSON.stringify(tiers) },
    { key: "shop_fee_multiplier_by_category", value: JSON.stringify(mult) },
    { key: "shop_far_pickup_max_fee", value: farMaxVal },
    { key: "shop_max_pickup_distance_km", value: maxPickupVal },
    ...Object.entries(required).map(([key, value]) => ({ key, value: String(value) })),
  ];

  return { rows };
}

export async function saveShopSettings(ctx) {
  const showToast = ctx?.showToast || globalThis.showToast;
  const upsert = ctx?._upsertSystemConfigKeyValues || globalThis._upsertSystemConfigKeyValues;

  const result = collectShopSettings((id) => {
    const el = document.getElementById(id);
    if (!el) return null;
    return el.type === "checkbox" ? el.checked : el.value;
  });

  if (result.error) {
    showToast?.(result.error, "error");
    return;
  }

  if (typeof upsert !== "function") {
    showToast?.("บันทึกไม่ได้: ไม่พบตัวช่วยบันทึกค่าระบบ", "error");
    return;
  }

  try {
    await upsert(result.rows);
    showToast?.("บันทึกค่าฝากซื้อสำเร็จ", "success");
  } catch (e) {
    showToast?.("บันทึกค่าฝากซื้อไม่สำเร็จ: " + (e?.message || JSON.stringify(e)), "error");
  }
}
