# Plan: รองรับ 2 ภาษา (ไทย/อังกฤษ) — เฉพาะฝั่ง App (Flutter)

## เป้าหมาย
- ให้แอปรองรับภาษา **ไทย (th)** และ **อังกฤษ (en)** แบบเป็นระบบ (ไม่ hardcode string กระจายตาม screen)
- รองรับการสลับภาษา:
  - **ตามภาษาระบบ (device locale)** เป็นค่าเริ่มต้น
  - (ตัวเลือก) **ผู้ใช้เลือกภาษาเองในแอป** และจดจำค่า
- จำกัดขอบเขต: **ทำเฉพาะฝั่งแอป** แต่ระบุจุดที่ backend “เกี่ยวข้อง/กระทบ” เพื่อให้แอปแปลได้ถูกต้อง

## สถานะปัจจุบัน (จากการสแกน)
- พบข้อความภาษาไทยจำนวนมากใน `lib/` กระจายหลาย screen/service (UI, validation, error, snackbars, dialogs)
- พบข้อความภาษาไทยใน backend ด้วย (SQL migrations / edge functions) โดยเฉพาะ **notifications** และ **admin-actions**

## หลักการออกแบบ (Decision)
1) **User-facing strings ต้องอยู่ในระบบ Localization ของ Flutter**
- ไม่ hardcode ข้อความใน widget โดยตรง
- แยกข้อความเป็น key และมีคำแปล th/en

2) **Backend ควรส่ง “event/type + data” มากกว่าส่งข้อความสำเร็จรูป** (Touchpoint ที่แอปต้องการ)
- แอปประกอบข้อความจาก type + data ด้วย localized templates
- ระยะเริ่มต้น (phase แรก) อาจยังใช้ข้อความจาก backend ได้ แต่ต้องมีแผนย้ายออก

## Milestones (แผนงานแบบเป็นเฟส)

### Phase 0: เตรียมเครื่องมือ Localization (Foundation)
- เพิ่ม dependency `flutter_localizations` และ `intl`
- เปิดใช้ `flutter gen-l10n`
- สร้างโครง `l10n/`
  - `app_en.arb`
  - `app_th.arb`
- ตั้งค่าใน `MaterialApp`:
  - `localizationsDelegates`
  - `supportedLocales: [Locale('th'), Locale('en')]`
  - `localeResolutionCallback`

**ผลลัพธ์:** แอปคอมไพล์ได้ และสามารถดึง string ผ่าน `AppLocalizations.of(context)`

**Test gate หลังจบ Phase 0**
- `flutter analyze` ผ่าน
- `flutter test` ผ่าน
- เปิดแอปได้ปกติ และ UI ยังแสดง “ข้อมูลเดิม” (ตัวเลข/ราคา/สถานะ/ชื่อร้าน/ชื่อคนขับ/หมายเลขออเดอร์) ถูกต้องเหมือนเดิม

### Phase 1: นิยาม “Dictionary/Keys” กลาง (Minimal set)
โฟกัสข้อความที่ใช้ซ้ำหรือเป็น entry point ที่ผู้ใช้เจอบ่อย:
- Auth:
  - สมัครสมาชิก/เข้าสู่ระบบ
  - ข้อความ error/validation หลัก
- Common UI:
  - ปุ่มพื้นฐาน เช่น OK/Cancel/Confirm/Save
  - Empty states ที่ใช้หลายหน้า
- Coupon/Referral:
  - หน้า My Coupons, Referral screen

**แนวทางการตั้ง key**
- จัดกลุ่มตาม feature: `auth.*`, `common.*`, `coupon.*`, `referral.*`, `wallet.*`, `order.*`

**ผลลัพธ์:** มี key ครอบคลุมจุดสำคัญ และเริ่มเรียกใช้ได้จริงบางหน้า

**Test gate หลังจบ Phase 1**
- ตรวจว่าหน้าที่ย้ายแล้ว (เช่น Auth / Coupons) ยังทำงานครบ:
  - สมัคร/ล็อกอินได้
  - Validation/Error แสดงถูกต้อง (TH/EN)
- Regression check: เนื้อหาที่มาจาก backend/DB ต้องแสดงเหมือนเดิม (ไม่แปลค่าข้อมูลจริงผิด)

### Phase 2: Refactor หน้าหลักทีละ feature (Incremental rollout)
ทำเป็นชุด ๆ เพื่อคุมความเสี่ยงและรีวิวง่าย:
- Auth screens (register/login/forgot)
- Customer core flows (home/checkout/order detail)
- Driver core flows (navigation/dashboard/wallet)
- Merchant core flows (orders/settings)

**กติกา refactor**
- ห้ามสร้าง string ใหม่แบบ hardcode
- ถ้าจำเป็นต้องแสดง dynamic values ให้ใช้ ARB parameter เช่น:
  - `walletRewardReceived(amount)`
  - `couponExpires(date)`

**ผลลัพธ์:** ลด hardcode strings จำนวนมาก และความสม่ำเสมอของภาษาเพิ่มขึ้น

**Test gate หลังจบ Phase 2 (ทำทุกชุดย่อย)**
- ทำ checklist ตาม role ที่เกี่ยวข้องกับชุดที่ refactor:
  - customer: home/checkout/order detail
  - driver: navigation/dashboard/wallet
  - merchant: orders/settings
- ตรวจ UI overflow / layout แตก ในภาษาอังกฤษ
- Regression check (สำคัญ):
  - ราคา/ยอดรวม/ส่วนลด/ค่าจัดส่ง ตรงเหมือนเดิม
  - สถานะออเดอร์/เวลา/ที่อยู่/ระยะทาง แสดงถูกต้อง
  - ปุ่ม/flow สำคัญกดแล้วได้ผลเหมือนเดิม

### Phase 3: Language Switcher (ตัวเลือกในแอป) — Optional แต่แนะนำ

**Requirement เพิ่มเติม:** ต้องมี language switcher ตั้งแต่หน้า Login
- แสดงตัวเลือกภาษา (ไทย / English) ได้ตั้งแต่ก่อน login
- ค่าเริ่มต้น: **ตามภาษาระบบ (device locale)**
- เมื่อผู้ใช้เลือกภาษาเอง:
  - เก็บค่าไว้ใน local storage (เช่น `shared_preferences`)
  - ให้ `MaterialApp.locale` ใช้ค่าที่ผู้ใช้เลือก (override device locale)
  - ต้องมีปุ่ม “ใช้ภาษาระบบ” (หรือเทียบเท่า) เพื่อกลับไปโหมด auto

**Requirement เพิ่มเติม:** ต้องมี language switcher ในหน้า Account/Settings
- ผู้ใช้เปลี่ยนภาษาได้ในหน้า account/setting หลัง login
- ต้องแสดงสถานะปัจจุบันชัดเจน:
  - โหมด “ใช้ภาษาระบบ” หรือ
  - เลือกภาษาแบบ fix เป็น TH/EN
- เมื่อเปลี่ยนภาษาแล้ว:
  - UI ทั้งแอปเปลี่ยนทันที
  - ไม่ทำให้ข้อมูล/สถานะที่โหลดจาก backend หายหรือรีเซ็ตผิด (เช่น order list, wallet balance)

**แนวทางการออกแบบ state**
- สร้าง `LanguageController` (หรือ `AppSettingsController`) เป็นแหล่งความจริงของ locale
- สถานะที่ต้องเก็บ:
  - `localeOverride`: nullable (`null` = ใช้ภาษาระบบ)
  - `supportedLocales`: `[th, en]`
- ทุก screen (รวม Login) ต้องอ่าน string ผ่าน localization เท่านั้น

**ผลลัพธ์:** ผู้ใช้เลือกภาษาเองได้ และจำค่าได้

**Test gate หลังจบ Phase 3**
- เปิดแอปครั้งแรกยัง default ตามภาษาระบบ
- เปลี่ยนภาษาใน Login ได้ และไม่ต้อง login ก่อน
- เปลี่ยนภาษาใน Account/Settings ได้หลัง login
- ปิด/เปิดแอปใหม่:
  - ถ้าเคยเลือกภาษาเอง ต้องจำค่าได้
  - ถ้าเลือก “ใช้ภาษาระบบ” ต้องกลับไปตามระบบได้
- Regression check:
  - สลับภาษาแล้วข้อมูลเดิมยังอยู่ (เช่นรายการออเดอร์, คูปอง, wallet)

### Phase 4: Test/QA สำหรับ i18n
- เพิ่ม test ระดับ unit สำหรับ string formatting ที่เป็น logic-heavy (ถ้ามี helper)
- Manual QA checklist:
  - ตัวอักษรไทยไม่ตัด
  - UI overflow ในอังกฤษ (ข้อความยาวขึ้น)
  - หน้าสำคัญทุก role

**ผลลัพธ์:** ลด regression จากข้อความล้น/แปลผิด

**Test gate หลังจบ Phase 4**
- สรุป checklist ทดสอบครบทุก role และเก็บหลักฐาน (screenshots/รายการเคส)
- ตรวจ notification rendering (ถ้าแอปเริ่มใช้ registry):
  - type ที่รู้จักแสดงข้อความตาม locale
  - type ที่ไม่รู้จัก fallback แสดง `title/body` ได้

## Backend touchpoints ที่ “เกี่ยวข้อง/กระทบ” (แต่ไม่ทำในแผนนี้)
> หมายเหตุ: แผนนี้ทำฝั่งแอปเท่านั้น แต่จุดด้านล่างทำให้ i18n ในแอป “ไม่สมบูรณ์” ถ้า backend ยังส่งข้อความไทย/อังกฤษแบบ hardcode

## แผนจัดการ Backend touchpoints (เพื่อให้ App แปลได้ 2 ภาษาแบบถูกต้อง)

### เป้าหมายของ touchpoints
- backend ส่ง “**event/type + data**” เป็นหลัก
- app เป็นผู้กำหนดข้อความ `title/body` ด้วย localization (TH/EN)
- รองรับการ rollout แบบ **backward compatible** (ยังใช้ของเดิมได้ระหว่างย้าย)

### Phase B0: ทำสัญญา (Contract) ระหว่าง backend <-> app
กำหนด schema กลางสำหรับสิ่งที่ app จะได้รับ (อย่างน้อยสำหรับ notification/event):
- `type`: string (เช่น `referral_wallet_reward_referee`)
- `data`: object (ค่าที่ใช้ประกอบข้อความ เช่น `amount`, `booking_id`, `coupon_code`, `referral_id`, `referee_id`)
- (แนะนำ) `version`: number เพื่อรองรับการเปลี่ยนโครงสร้างในอนาคต
- (แนะนำ) `message_key`: optional (ถ้าต้องแยก `type` กับ `template`)

**หลักการสำคัญ**
- หลีกเลี่ยงการส่งข้อความไทย/อังกฤษสำเร็จรูปจาก backend
- ให้ backend ส่ง “ค่าจริง” และให้ app format/แปล เช่น จำนวนเงิน, วันที่

### Phase B1: Notifications — ทำให้ backend ส่งข้อมูลแบบ event-driven
**สถานะปัจจุบัน:** backend insert `notifications` พร้อม `title/body` ภาษาไทย

**แนวทางที่รองรับได้ทันที (ไม่พังของเดิม):**
- backend ยัง insert `title/body` ได้เหมือนเดิม
- แต่ต้องให้ `data` ครบ (เช่น `amount`, `coupon_code`) และ `type` ถูกต้อง
- app ปรับการแสดงผลโดย:
  - ถ้ามี `type` ที่รู้จักและ `data` ครบ -> ใช้ localized template ในแอปแทน `title/body`
  - ถ้าไม่รู้จัก/ข้อมูลไม่ครบ -> fallback ใช้ `title/body` ที่ backend ส่งมา

**ผลลัพธ์:** เริ่มรองรับ 2 ภาษาในแอปได้ โดยไม่ต้องแก้ backend ทันทีทุกจุด

### Phase B2: Error Handling / Edge Functions — เปลี่ยนเป็น error_code
**ปัญหา:** edge functions บางตัวส่ง error message เป็นไทย (หรือข้อความดิบ)

**แนวทาง:**
- backend ตอบกลับด้วยโครงสร้าง เช่น
  - `error_code` (เช่น `ADMIN_DELETE_FORBIDDEN`, `WALLET_CREATE_FAILED`)
  - `error_message` (optional สำหรับ debug/fallback)
  - `details` (optional)
- app map `error_code` -> ข้อความ localized (TH/EN)
- fallback: ถ้าไม่มี `error_code` ให้แสดง `error_message` ตามเดิม

### Phase B3: การจัดการ “ภาษา” สำหรับข้อความที่ backend ต้องใช้จริง
มีบางกรณี backend อาจต้องสร้างข้อความเอง (เช่น email templates, logs)

**Policy ที่แนะนำ:**
- In-app notifications: ให้ app เป็นผู้แปล
- Email/External channel: backend อาจต้องใช้ template แยกภาษา แต่ควรส่งตาม `preferred_language` ของ user (ถ้ามี)

### Phase B4: Rollout Strategy (Backward Compatibility)
1) เพิ่ม `type + data` ให้ครบใน notification ใหม่ทุกประเภท
2) ฝั่งแอปเริ่มใช้ localized template ตาม `type` (fallback ใช้ `title/body`)
3) เมื่อ coverage ในแอปครบและ backend ส่งข้อมูลครบแล้ว:
   - ค่อยพิจารณาให้ backend หยุด hardcode `title/body` หรือทำให้เป็นค่า placeholder

**การตรวจสอบระหว่าง rollout**
- ทำรายการ `type` ทั้งหมดที่แอปรู้จัก (registry)
- ตรวจว่า `data` ที่ต้องใช้สำหรับแต่ละ `type` ถูกส่งมาครบ

### Registry Table (สำหรับ app): Notification/Event Types -> required data -> localization keys
> ตารางนี้เป็น “รายการกลาง” ที่ทำให้ทีมรู้ว่า backend ต้องส่ง `data` อะไร และ app ต้องมี template/keys อะไร

| Backend `type` | Required `data` fields | App localization key (title) | App localization key (body/template) | Notes |
|---|---|---|---|---|
| `referral_wallet_reward_referee` | `referral_id`, `amount`, `booking_id` | `noti.referralWalletRewardRefereeTitle` | `noti.referralWalletRewardRefereeBody(amount)` | amount ต้อง format ตาม locale |
| `referral_wallet_reward_referrer` | `referral_id`, `amount`, `booking_id`, `referee_id` | `noti.referralWalletRewardReferrerTitle` | `noti.referralWalletRewardReferrerBody(amount)` | อาจเพิ่มชื่อผู้ถูกชวนในอนาคต |
| `referral_reward_referee` | `referral_id`, `coupon_code` | `noti.referralCouponRewardRefereeTitle` | `noti.referralCouponRewardRefereeBody(couponCode)` | coupon code ควร uppercase ใน UI |
| `referral_reward_referrer` | `referral_id`, `coupon_code`, `referee_id` | `noti.referralCouponRewardReferrerTitle` | `noti.referralCouponRewardReferrerBody(couponCode)` |  |
| `admin_approve_driver` | `user_id` | `noti.adminApproveDriverTitle` | `noti.adminApproveDriverBody` | แนะนำให้ backend ส่ง type ชัดเจนต่อ role |
| `admin_reject_driver` | `user_id`, `reason` | `noti.adminRejectDriverTitle` | `noti.adminRejectDriverBody(reason)` | reason อาจเป็นข้อความดิบ ควรพิจารณาเป็น reason_code |
| `admin_suspend_user` | `user_id`, `reason` | `noti.adminSuspendUserTitle` | `noti.adminSuspendUserBody(reason)` |  |
| `admin_unsuspend_user` | `user_id` | `noti.adminUnsuspendUserTitle` | `noti.adminUnsuspendUserBody` |  |

**กติกา registry**
- ถ้า app รองรับ `type` ใดแล้ว ต้องกำหนด required fields ชัดเจน
- ถ้า `data` ไม่ครบ ให้ fallback ไปใช้ `title/body` จาก backend
- สำหรับ field ที่เป็นข้อความอิสระ (เช่น `reason`) ระยะยาวควรเป็น `reason_code` เพื่อแปลได้ 2 ภาษา

### A) Notifications ที่ถูกสร้างจาก SQL (Supabase migrations/functions)
ตัวอย่างประเภทที่พบ:
- `referral_wallet_reward_referee`
- `referral_wallet_reward_referrer`
- `referral_reward_referee`
- `referral_reward_referrer`

**ปัญหา:** backend ส่ง `title/body` เป็นข้อความไทยสำเร็จรูป

**แนวทางเพื่อรองรับ i18n ในแอป (เป้าหมายในอนาคต):**
- backend ส่งเพียง:
  - `type`
  - `data` (เช่น `amount`, `referral_id`, `booking_id`, `coupon_code`)
- แอป map `type` -> localized title/body template

### B) Edge Functions (เช่น `supabase/functions/admin-actions/index.ts`)
มีข้อความไทยใน title/body/error response

**แนวทางในอนาคต:**
- ฝั่งแอปแสดง error message จาก “code” มากกว่าข้อความดิบ
- หรือ backend แยก error เป็น `error_code` + `message` แล้วแอปแปล `error_code`

## Definition of Done (DoD)
- แอปรองรับ `th/en` ผ่าน `gen-l10n`
- หน้าหลักของแต่ละ role (customer/driver/merchant/admin) ไม่ hardcode string สำคัญแล้ว
- มี language switcher (ถ้าทำ Phase 3)
- คู่มือเพิ่มคำแปล: เพิ่ม key ที่ `app_en.arb`/`app_th.arb` และเรียกใช้ผ่าน `AppLocalizations`

## ลำดับการทำที่แนะนำ (เร็วและคุ้ม)
1) Phase 0 (foundation)
2) Phase 1 (keys กลาง + common buttons/errors)
3) Phase 2 เฉพาะ Auth + Coupons/Referral ก่อน (เพราะมีข้อความไทย/อังกฤษปนเยอะ)
4) Phase 3 (language switcher)
5) Phase 4 (QA)
