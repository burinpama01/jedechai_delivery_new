// โฆษณาในแอพ (ตาราง banners): ตำแหน่งแสดง + ตรวจข้อมูลก่อนเขียน (pure — ทดสอบได้ด้วย node)
// แผน: Plan/In_App_Ads_Plan_v1.html
// ต้องตรงกับ admin-web/src/pages/bannersBridge.js (AD_PLACEMENTS/AD_SCREENS) และ
// jedechai_delivery_new/lib/common/services/app_ad_service.dart — test/banner-ads.test.mjs ตรวจให้

export type AdAudience = "customer" | "driver" | "merchant";
export type AdFormat = "carousel" | "popup" | "card";

export interface AdPlacement {
  audience: AdAudience;
  format: AdFormat;
  label: string;
}

// key = ค่าในคอลัมน์ banners.page · ฝั่งลูกค้าเดิม (home/food) ไม่มี prefix เพื่อให้แอพเก่ายังใช้ได้
export const AD_PLACEMENTS: Record<string, AdPlacement> = {
  home: { audience: "customer", format: "carousel", label: "หน้าแรก (สไลด์)" },
  food: { audience: "customer", format: "carousel", label: "หน้าสั่งอาหาร (สไลด์)" },
  customer_popup: { audience: "customer", format: "popup", label: "ป๊อปอัปตอนเปิดแอพ" },
  customer_card_activity: { audience: "customer", format: "card", label: "การ์ดหน้ากิจกรรม" },
  customer_card_wallet: { audience: "customer", format: "card", label: "การ์ดหน้ากระเป๋าเงิน" },
  driver_home: { audience: "driver", format: "carousel", label: "แดชบอร์ด (สไลด์)" },
  driver_popup: { audience: "driver", format: "popup", label: "ป๊อปอัปตอนเปิดแอพ" },
  driver_card_wallet: { audience: "driver", format: "card", label: "การ์ดหน้ากระเป๋าเงิน" },
  merchant_home: { audience: "merchant", format: "carousel", label: "แดชบอร์ดร้าน (สไลด์)" },
  merchant_popup: { audience: "merchant", format: "popup", label: "ป๊อปอัปตอนเปิดแอพ" },
  merchant_card_orders: { audience: "merchant", format: "card", label: "การ์ดหน้าออเดอร์" },
};

// หน้าในแอพที่โฆษณาเปิดได้ (allowlist ต่อฝั่ง)
export const AD_SCREENS: Record<AdAudience, Record<string, string>> = {
  customer: {
    referral: "ชวนเพื่อน",
    my_coupons: "คูปองของฉัน",
    wallet: "กระเป๋าเงิน",
    food: "สั่งอาหาร",
  },
  driver: {
    referral: "ชวนเพื่อน (คนขับ)",
    wallet: "กระเป๋าเงิน",
    topup: "เติมเงิน",
    shift: "กะงาน",
    performance: "ผลงาน",
  },
  merchant: {
    gp_plan: "แพ็กเกจ GP",
    coupons: "คูปองร้าน",
    menu: "จัดการเมนู",
  },
};

export const AD_ACTION_TYPES = ["none", "coupon", "url", "screen"] as const;
export const AD_POPUP_FREQUENCIES = ["once", "daily", "every_open"] as const;

export interface BannerRow {
  title: string;
  image_url: string;
  page: string;
  sort_order: number;
  action_type: string;
  action_value: string | null;
  coupon_code: string | null;
  starts_at: string | null;
  ends_at: string | null;
  popup_frequency: string;
  is_active?: boolean;
}

type Result = { ok: true; row: BannerRow } | { ok: false; error: string };

function str(v: unknown): string {
  return typeof v === "string" ? v.trim() : "";
}

function optionalIso(v: unknown, field: string): { value: string | null; error?: string } {
  const s = str(v);
  if (!s) return { value: null };
  const t = Date.parse(s);
  if (Number.isNaN(t)) return { value: null, error: `${field} ไม่ใช่วันที่ที่ถูกต้อง` };
  return { value: new Date(t).toISOString() };
}

const BANNER_PUBLIC_PREFIX = "/storage/v1/object/public/admin-uploads/";

/// path ในบัคเก็ต admin-uploads ของรูปแบนเนอร์ (เฉพาะใต้ banners/) — อย่างอื่นคืน null ไม่แตะ
export function bannerStoragePath(imageUrl: unknown): string | null {
  if (typeof imageUrl !== "string") return null;
  let pathname: string;
  try {
    pathname = new URL(imageUrl).pathname;
  } catch {
    return null;
  }
  const i = pathname.indexOf(BANNER_PUBLIC_PREFIX);
  if (i < 0) return null;
  const path = decodeURIComponent(pathname.slice(i + BANNER_PUBLIC_PREFIX.length));
  if (!/^banners\/[^/]+$/.test(path)) return null;
  return path;
}

/// ตรวจ + คัดเฉพาะฟิลด์ที่อนุญาต จาก body ของแอดมิน
/// imageRequired=false ใช้ตอนแก้ไข (ไม่เปลี่ยนรูป)
export function sanitizeBannerInput(input: unknown, opts: { imageRequired: boolean }): Result {
  const d = (input && typeof input === "object" ? input : {}) as Record<string, unknown>;

  const page = str(d.page) || "home";
  const placement = AD_PLACEMENTS[page];
  if (!placement) return { ok: false, error: `ตำแหน่งแสดงไม่ถูกต้อง: ${page}` };

  const imageUrl = str(d.image_url);
  if (opts.imageRequired && !imageUrl) return { ok: false, error: "ต้องมีรูปภาพ" };
  if (imageUrl && !/^https:\/\//i.test(imageUrl)) return { ok: false, error: "URL รูปต้องเป็น https" };

  const actionType = str(d.action_type) || (str(d.coupon_code) ? "coupon" : "none");
  if (!(AD_ACTION_TYPES as readonly string[]).includes(actionType)) {
    return { ok: false, error: `ประเภทการกดไม่ถูกต้อง: ${actionType}` };
  }

  let actionValue: string | null = null;
  let couponCode: string | null = null;
  if (actionType === "coupon") {
    couponCode = str(d.coupon_code);
    if (!couponCode) return { ok: false, error: "เลือกโค้ดคูปอง" };
  } else if (actionType === "url") {
    actionValue = str(d.action_value);
    if (!/^https:\/\/[^\s]+$/i.test(actionValue)) return { ok: false, error: "ลิงก์ต้องขึ้นต้นด้วย https://" };
    if (actionValue.length > 2000) return { ok: false, error: "ลิงก์ยาวเกินไป" };
  } else if (actionType === "screen") {
    actionValue = str(d.action_value);
    if (!AD_SCREENS[placement.audience][actionValue]) {
      return { ok: false, error: `หน้าในแอพไม่ถูกต้องสำหรับฝั่งนี้: ${actionValue}` };
    }
  }

  const starts = optionalIso(d.starts_at, "วันเริ่ม");
  if (starts.error) return { ok: false, error: starts.error };
  const ends = optionalIso(d.ends_at, "วันสิ้นสุด");
  if (ends.error) return { ok: false, error: ends.error };
  if (starts.value && ends.value && Date.parse(ends.value) <= Date.parse(starts.value)) {
    return { ok: false, error: "วันสิ้นสุดต้องหลังวันเริ่ม" };
  }

  const freq = str(d.popup_frequency) || "daily";
  if (!(AD_POPUP_FREQUENCIES as readonly string[]).includes(freq)) {
    return { ok: false, error: `ความถี่ป๊อปอัปไม่ถูกต้อง: ${freq}` };
  }

  const sortRaw = Number(d.sort_order ?? 0);
  const sortOrder = Number.isFinite(sortRaw) ? Math.max(-9999, Math.min(9999, Math.trunc(sortRaw))) : 0;

  const title = str(d.title).slice(0, 120) || "Banner";

  const row: BannerRow = {
    title,
    image_url: imageUrl,
    page,
    sort_order: sortOrder,
    action_type: actionType,
    action_value: actionValue,
    coupon_code: couponCode,
    starts_at: starts.value,
    ends_at: ends.value,
    popup_frequency: freq,
  };
  if (typeof d.is_active === "boolean") row.is_active = d.is_active;
  return { ok: true, row };
}
