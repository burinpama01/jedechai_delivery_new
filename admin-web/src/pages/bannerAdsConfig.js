// โฆษณาในแอพ: ตำแหน่งแสดง + หน้าในแอพที่เปิดได้
// ต้องตรงกับ supabase/functions/_shared/banner-ads.ts — test/banner-ads.test.mjs ตรวจให้

export const AD_AUDIENCES = {
  customer: 'ลูกค้า',
  driver: 'คนขับ',
  merchant: 'ร้านค้า',
};

export const AD_FORMAT_LABELS = {
  carousel: 'สไลด์',
  popup: 'ป๊อปอัป',
  card: 'การ์ด',
};

export const AD_PLACEMENTS = {
  home: { audience: 'customer', format: 'carousel', label: 'หน้าแรก (สไลด์)' },
  food: { audience: 'customer', format: 'carousel', label: 'หน้าสั่งอาหาร (สไลด์)' },
  customer_popup: { audience: 'customer', format: 'popup', label: 'ป๊อปอัปตอนเปิดแอพ' },
  customer_card_activity: { audience: 'customer', format: 'card', label: 'การ์ดหน้ากิจกรรม' },
  customer_card_wallet: { audience: 'customer', format: 'card', label: 'การ์ดหน้ากระเป๋าเงิน' },
  driver_home: { audience: 'driver', format: 'carousel', label: 'แดชบอร์ด (สไลด์)' },
  driver_popup: { audience: 'driver', format: 'popup', label: 'ป๊อปอัปตอนเปิดแอพ' },
  driver_card_wallet: { audience: 'driver', format: 'card', label: 'การ์ดหน้ากระเป๋าเงิน' },
  merchant_home: { audience: 'merchant', format: 'carousel', label: 'แดชบอร์ดร้าน (สไลด์)' },
  merchant_popup: { audience: 'merchant', format: 'popup', label: 'ป๊อปอัปตอนเปิดแอพ' },
  merchant_card_orders: { audience: 'merchant', format: 'card', label: 'การ์ดหน้าออเดอร์' },
};

export const AD_SCREENS = {
  customer: {
    referral: 'ชวนเพื่อน',
    my_coupons: 'คูปองของฉัน',
    wallet: 'กระเป๋าเงิน',
    food: 'สั่งอาหาร',
  },
  driver: {
    referral: 'ชวนเพื่อน (คนขับ)',
    wallet: 'กระเป๋าเงิน',
    topup: 'เติมเงิน',
    shift: 'กะงาน',
    performance: 'ผลงาน',
  },
  merchant: {
    gp_plan: 'แพ็กเกจ GP',
    coupons: 'คูปองร้าน',
    menu: 'จัดการเมนู',
  },
};

export const AD_ACTION_LABELS = {
  none: 'ไม่ต้องทำอะไร',
  coupon: 'แสดงโค้ดคูปอง',
  url: 'เปิดลิงก์เว็บ',
  screen: 'เปิดหน้าในแอพ',
};

export const AD_POPUP_FREQUENCY_LABELS = {
  daily: 'วันละครั้ง',
  once: 'ครั้งเดียวต่อคน',
  every_open: 'ทุกครั้งที่เปิดแอพ',
};

/** ตำแหน่งที่ไม่รู้จัก (เช่น ride/parcel เดิม) ถือเป็นฝั่งลูกค้า */
export function placementOf(page) {
  return AD_PLACEMENTS[page || 'home'] || { audience: 'customer', format: 'carousel', label: `${page} (เลิกใช้)` };
}

/** live | scheduled | expired | off */
export function adStatus(b, now = Date.now()) {
  if (b.is_active === false) return 'off';
  if (b.starts_at && Date.parse(b.starts_at) > now) return 'scheduled';
  if (b.ends_at && Date.parse(b.ends_at) <= now) return 'expired';
  return 'live';
}

/** ISO → ค่าของ <input type="datetime-local"> ตามเวลาเครื่อง */
export function isoToLocalInput(iso) {
  if (!iso) return '';
  const d = new Date(iso);
  if (Number.isNaN(d.getTime())) return '';
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}T${pad(d.getHours())}:${pad(d.getMinutes())}`;
}

/** ค่าของ <input type="datetime-local"> → ISO (null ถ้าว่าง) */
export function localInputToIso(value) {
  if (!value) return null;
  const d = new Date(value);
  return Number.isNaN(d.getTime()) ? null : d.toISOString();
}
