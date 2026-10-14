// โฆษณาในแอพ: ตรวจข้อมูลแบนเนอร์ + ตำแหน่ง/หน้าในแอพต้องตรงกันทั้ง edge fn, admin-web, Flutter
// รัน: node --test test/banner-ads.test.mjs
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  AD_PLACEMENTS,
  AD_SCREENS,
  bannerStoragePath,
  sanitizeBannerInput,
} from "../supabase/functions/_shared/banner-ads.ts";
import { AD_PLACEMENTS as WEB_PLACEMENTS, AD_SCREENS as WEB_SCREENS } from "../admin-web/src/pages/bannerAdsConfig.js";

const IMG = "https://x.supabase.co/storage/v1/object/public/admin-uploads/banners/a.png";
const ok = (d, imageRequired = true) => {
  const r = sanitizeBannerInput(d, { imageRequired });
  assert.equal(r.ok, true, r.error);
  return r.row;
};
const bad = (d, imageRequired = true) => {
  const r = sanitizeBannerInput(d, { imageRequired });
  assert.equal(r.ok, false);
  return r.error;
};

test("ค่าเริ่มต้น: page=home, action none, daily", () => {
  const row = ok({ image_url: IMG });
  assert.equal(row.page, "home");
  assert.equal(row.action_type, "none");
  assert.equal(row.popup_frequency, "daily");
  assert.equal(row.title, "Banner");
});

test("มี coupon_code แต่ไม่ระบุ action → coupon (เข้ากันกับของเดิม)", () => {
  const row = ok({ image_url: IMG, coupon_code: "SAVE10" });
  assert.equal(row.action_type, "coupon");
  assert.equal(row.coupon_code, "SAVE10");
});

test("ทิ้งฟิลด์ที่ไม่อยู่ใน allowlist", () => {
  const row = ok({ image_url: IMG, id: "x", created_at: "2020-01-01", evil: 1 });
  assert.equal("id" in row, false);
  assert.equal("evil" in row, false);
  assert.equal("created_at" in row, false);
});

test("ปฏิเสธตำแหน่ง/รูป/ลิงก์ที่ไม่ถูกต้อง", () => {
  bad({ image_url: IMG, page: "ride" });
  bad({ page: "home" });
  bad({ image_url: "http://x/a.png" });
  bad({ image_url: IMG, action_type: "url", action_value: "javascript:alert(1)" });
  bad({ image_url: IMG, action_type: "url", action_value: "http://example.com" });
  bad({ image_url: IMG, action_type: "coupon" });
  bad({ image_url: IMG, action_type: "deeplink" });
  bad({ image_url: IMG, popup_frequency: "hourly" });
});

test("หน้าในแอพต้องอยู่ใน allowlist ของฝั่งนั้น", () => {
  ok({ image_url: IMG, page: "driver_home", action_type: "screen", action_value: "topup" });
  bad({ image_url: IMG, page: "home", action_type: "screen", action_value: "topup" });
  bad({ image_url: IMG, page: "merchant_popup", action_type: "screen", action_value: "referral" });
});

test("url: เก็บใน action_value, ไม่เก็บคูปอง", () => {
  const row = ok({ image_url: IMG, action_type: "url", action_value: "https://line.me/x", coupon_code: "A" });
  assert.equal(row.action_value, "https://line.me/x");
  assert.equal(row.coupon_code, null);
});

test("ช่วงเวลา: จบต้องหลังเริ่ม, วันที่ผิดถูกปฏิเสธ", () => {
  const row = ok({ image_url: IMG, starts_at: "2026-10-20T00:00:00+07:00", ends_at: "2026-10-31T23:59:00+07:00" });
  assert.equal(row.starts_at, "2026-10-19T17:00:00.000Z");
  bad({ image_url: IMG, starts_at: "2026-10-20", ends_at: "2026-10-19" });
  bad({ image_url: IMG, starts_at: "not-a-date" });
});

test("bannerStoragePath: ลบได้เฉพาะไฟล์ใต้ admin-uploads/banners/", () => {
  assert.equal(bannerStoragePath(IMG), "banners/a.png");
  assert.equal(bannerStoragePath("https://x.supabase.co/storage/v1/object/public/admin-uploads/logos/a.png"), null);
  assert.equal(bannerStoragePath("https://x.supabase.co/storage/v1/object/public/admin-uploads/banners/../logos/a.png"), null);
  assert.equal(bannerStoragePath("https://x.supabase.co/storage/v1/object/public/admin-uploads/banners/%2e%2e%2Flogos%2Fa.png"), null);
  assert.equal(bannerStoragePath("https://x.supabase.co/storage/v1/object/public/other/banners/a.png"), null);
  assert.equal(bannerStoragePath("not a url"), null);
  assert.equal(bannerStoragePath(null), null);
});

test("แก้ไขโดยไม่เปลี่ยนรูปได้", () => {
  const row = ok({ page: "merchant_home", title: "x" }, false);
  assert.equal(row.image_url, "");
});

test("admin-web ใช้ตำแหน่ง/หน้าในแอพชุดเดียวกับ edge fn", () => {
  assert.deepEqual(
    Object.fromEntries(Object.entries(WEB_PLACEMENTS).map(([k, v]) => [k, [v.audience, v.format]])),
    Object.fromEntries(Object.entries(AD_PLACEMENTS).map(([k, v]) => [k, [v.audience, v.format]])),
  );
  assert.deepEqual(
    Object.fromEntries(Object.entries(WEB_SCREENS).map(([k, v]) => [k, Object.keys(v).sort()])),
    Object.fromEntries(Object.entries(AD_SCREENS).map(([k, v]) => [k, Object.keys(v).sort()])),
  );
});

test("Flutter รู้จักทุกตำแหน่งและทุกหน้าในแอพ", () => {
  const dart = readFileSync(
    new URL("../jedechai_delivery_new/lib/common/services/app_ad_service.dart", import.meta.url),
    "utf8",
  );
  for (const key of Object.keys(AD_PLACEMENTS)) {
    assert.ok(dart.includes(`'${key}'`), `app_ad_service.dart ไม่มี placement '${key}'`);
  }
  const nav = readFileSync(
    new URL("../jedechai_delivery_new/lib/common/widgets/app_ad_widgets.dart", import.meta.url),
    "utf8",
  );
  for (const [aud, screens] of Object.entries(AD_SCREENS)) {
    for (const key of Object.keys(screens)) {
      assert.ok(nav.includes(`'${key}'`), `app_ad_widgets.dart ไม่มีหน้า '${key}' (${aud})`);
    }
  }
});
