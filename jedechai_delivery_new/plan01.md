# แผนงาน (plan01): วิเคราะห์โปรเจค + ออกแบบ Referral Program และระบบคูปองแบบ “เก็บ&ใช้”

> เอกสารนี้เป็น **แผนงาน/สรุปความเข้าใจ** เท่านั้น
>
> ขอบเขตตามกติกา:
> - ไม่เขียน/ไม่เสนอ implementation code ในเอกสารนี้
> - เน้นคำอธิบายเป็นภาษาไทย (คำเทคนิคใช้ English ได้)

---

## 1) ภาพรวมโปรเจค (อัปเดตล่าสุด)

### 1.1 โครงสร้างแอพ
- โปรเจคเป็น Flutter monorepo ในแอพเดียว แต่แยกโมดูล UI ตาม role:
  - `lib/apps/customer/*`
  - `lib/apps/merchant/*`
  - `lib/apps/driver/*`
  - `lib/apps/admin/*`
- จุดเริ่มต้น `lib/main.dart`
  - โหลด `.env` -> init Supabase -> `AuthService.initialize()` -> `FCMNotificationService.initialize()` -> เปิด `AuthGate`
- `AuthGate` เป็นศูนย์กลาง routing หลัง login:
  - ดึง role จาก `profiles.role`
  - ตรวจ `approval_status` และ `profileCompleted`
  - บันทึก FCM token (`FCMNotificationService().saveToken()`)

### 1.2 Backend / Database (Supabase)
- มี `supabase/migrations/*` สำหรับ schema หลัก
- ตารางสำคัญที่พบจาก migrations และการใช้งานใน service layer:
  - `profiles` (role, approval_status, shop_status, fcm_token, ข้อมูลเอกสาร/ธนาคาร ฯลฯ)
  - `bookings` (ride/food/parcel) + ฟิลด์ legacy เพื่อ backward compatibility
  - `booking_items` (รายละเอียดรายการอาหาร)
  - `wallets`, `wallet_transactions` (driver wallet/ธุรกรรม)
  - `system_config`, `service_rates` (config และ rate)
  - `coupons`, `coupon_usages` (ระบบคูปองแบบ “ใส่โค้ด” และบันทึกการใช้)
  - `notifications` (in-app feed) + FCM push ผ่าน `NotificationSender`
  - ฟีเจอร์ใหม่ในชุด migration `20240210_create_new_feature_tables.sql`:
    - `saved_addresses`, `chat_rooms`, `chat_messages`, `support_tickets`, `coupons`, `coupon_usages`

### 1.3 Service Layer ที่เกี่ยวข้อง (High-level)
- `AuthService` / `ProfileService`: สมัคร/เข้าสู่ระบบ + สร้าง/อัปเดต `profiles`
- `FCMNotificationService` / `NotificationSender`: รับ/แสดง noti (foreground/background) + ส่ง push ผ่าน FCM v1
- `BookingService`: flow การจัดการ booking + ผูก logic เรื่อง wallet/coupon/earning
- `CouponService`: validate coupon code และ `recordUsage` (ตาราง `coupon_usages`)
- `WalletService`: wallet ของคนขับ (deduct, topup, transaction history)

### 1.4 สถานะปัจจุบันของระบบคูปอง (สรุป)
- ปัจจุบันรองรับ “คูปองแบบใส่โค้ด” โดย:
  - `validateCoupon(code, serviceType, orderAmount, merchantId)`
  - ใช้เงื่อนไข: active, start/end date, usage_limit/used_count, per_user_limit, min_order_amount, service_type, merchant_id
  - หลังสั่งสำเร็จมีการ `recordUsage(couponId, bookingId, discountAmount)` และ RPC `increment_coupon_usage`
- **ยังไม่มี** แนวคิด “คูปองเก็บ&ใช้” แบบ wallet/claim (เช่น claim มาเก็บก่อน แล้วค่อยเลือกใช้)

---

## 2) เป้าหมายฟีเจอร์ใหม่

### 2.1 ระบบ “ชวนเพื่อน” (Referral Program)
เป้าหมาย:
- เพิ่มการเติบโตผู้ใช้ (acquisition) ผ่านลิงก์/โค้ดชวนเพื่อน
- ให้รางวัลผู้ชวน (referrer) ตามเงื่อนไขที่ควบคุมได้
- ให้ “คูปองต้อนรับ” สำหรับผู้ใช้ใหม่ (ลูกค้าใหม่) ทั้งกรณีมาจาก referral และไม่มาจาก referral
- รองรับรางวัลหลายรูปแบบตาม role (เช่น คูปอง/เครดิต)

ข้อควรระวังสำคัญ:
- Anti-fraud (สมัครหลายบัญชี, อุปกรณ์เดียวกัน, เบอร์/อีเมลซ้ำ, order ปลอม)
- Reward ต้องเกิด “หลัง event ที่ verify ได้” เช่น paid/completed booking
- ต้องมี audit trail ตรวจสอบย้อนหลังได้

### 2.2 ระบบ “คูปองเก็บ&ใช้” (Coupon Claim & Use)
เป้าหมาย:
- ผู้ใช้ “กดเก็บคูปอง” หรือ “เก็บด้วยโค้ด/ลิงก์” มาไว้ในบัญชีก่อน
- ตอน checkout เลือกใช้จาก “คูปองของฉัน” (My Coupons)
- รองรับ:
  - limited per-user
  - expiry per-claim (เช่น เก็บแล้วใช้ได้ภายใน 7 วัน)
  - merchant coupon / platform coupon
  - ไม่ให้ใช้ซ้ำ/ใช้เกินสิทธิ

### 2.3 Benchmark (Shopee / Lazada / TikTok) และสิ่งที่ควรนำมาใช้
> อ้างอิงจากเอกสารสาธารณะที่อ่านได้:
> - Shopee Help Center (voucher types + stacking limit)
> - Lazada Referral Reward Rules / New Buyer Referral T&C
> - TikTok Shop University (Seller coupons / Promo codes / consumer interaction)

#### Shopee (ภาพรวม voucher stacking)
- จำกัดการใช้คูปองต่อ 1 checkout แบบ “cap ตามประเภท”
  - ใช้ได้สูงสุด 3 ใบ โดยเป็น:
    - 1 platform voucher
    - 1 free shipping voucher
    - 1 seller voucher
  - ห้ามซ้อนหลายใบในประเภทเดียวกัน (เช่น seller voucher เลือกได้อย่างใดอย่างหนึ่ง)

#### TikTok Shop (coupon wallet + auto-claim/auto-apply + edit-lock)
- ผู้ใช้มีแนวคิด “coupon package / owned coupons” (คูปองที่เก็บแล้ว)
- ตอน checkout ถ้ามี seller coupon ที่ใช้ได้แต่ผู้ใช้ยังไม่กดเก็บ ระบบสามารถ auto-claim และหักให้เลย
- จำกัด 1 seller coupon ต่อ 1 การจ่ายเงิน/1 order
- การแก้ไขแคมเปญหลังเริ่มมีข้อจำกัด (edit-lock):
  - ถ้าเริ่มแล้วแก้ได้เพียงบาง field เช่น ชื่อ/เวลาจบ/จำนวนคูปอง

#### Lazada (referral qualification + pending earnings + void on cancel)
- นิยาม new user เข้ม: ยังไม่เคยซื้อ และยังไม่เคยติดตั้งแอพ (ตัดสินโดยระบบ)
- reward เกิดเมื่อ referee download/login ผ่านลิงก์ และทำ “first non-digital purchase”
- reward เป็นสถานะ pending ก่อน แล้วรอ 7–14 วันหลังส่งสำเร็จ/ยืนยันรับของ จึงกลายเป็นถอน/ใช้ได้
- ถ้า order ถูก cancel/return/refund จะ void และตัด reward
- anti-fraud สำคัญ: 1 คนควรมี 1 account และ account ซ้ำ/น่าสงสัยอาจถูก suspend

---

## 3) ออกแบบระบบ Referral Program (ระดับสถาปัตยกรรม)

### 3.1 แนวคิดหลัก
- ใช้ “Referral Code” เป็นตัวเชื่อม referrer -> referee
- เก็บความสัมพันธ์แบบ immutable: เมื่อ referee ผูกกับ referrer แล้ว ไม่ควรแก้ไขเองจาก client
- Reward ให้ทำผ่าน server-side rule (เช่น Supabase function/RPC) เพื่อกันโกง

### 3.2 Data Model (ข้อเสนอ)
> หมายเหตุ: เป็นข้อเสนอ schema เพื่อเขียนแผน ไม่ใช่โค้ด migration

ตารางใหม่ที่แนะนำ:
1) `referral_codes`
- `user_id` (เจ้าของโค้ด)
- `code` (unique, short)
- `status` (active/disabled)
- `created_at`

2) `referrals`
- `id`
- `referrer_user_id`
- `referee_user_id`
- `code_used`
- `status` (pending/qualified/rewarded/cancelled)
- `created_at`, `qualified_at`, `rewarded_at`
- constraint: `unique(referee_user_id)` เพื่อกันคนถูกชวนผูกหลายคน

3) `referral_events` (audit)
- `referral_id`
- `event_type` (signup, first_order_created, first_order_completed, reward_granted, revoked)
- `booking_id` (nullable)
- `metadata` JSONB
- `created_at`

4) `referral_rewards` (optional หากต้องการแยกชัด)
- `referral_id`
- `beneficiary_user_id` (ใครได้)
- `reward_type` (coupon/credit/cashback)
- `amount` (ถ้ามี)
- `coupon_id` (ถ้า reward เป็น coupon)
- `status` (pending/granted/revoked)
- `created_at`

### 3.3 Rule Engine (ข้อเสนอเชิงกติกา)
กำหนด “จุดให้รางวัล” (เลือก 1 แบบหรือผสม):
- แบบ A: ให้รางวัลเมื่อ referee ทำ “ออเดอร์แรก completed” (สำหรับผู้ใช้ ลูกค้า/ร้านค้า)
- แบบ B: ให้รางวัลเมื่อ referee “ชำระเงินสำเร็จ” (ถ้ามีระบบจ่ายเงินจริง) (สำหรับคนขับ เปลี่ยนเงื่อนไขเป็นทำ order ครั้งแรกสำเร็จ)
- แบบ C: ให้รางวัลเป็น 2 ช่วง (signup ได้เล็กน้อย + completed ได้หลัก) (ไม่เอาเงื่อนไขนี้)

กติกาการ “ปล่อยรางวัล” (inspired by Lazada):
- สถานะ reward ควรแยกอย่างน้อย:
  - pending (รอ verify)
  - withdrawable/usable (ยืนยันแล้ว)
  - voided/revoked (ยกเลิก/คืนเงิน/ผิดเงื่อนไข)
- ระยะเวลารอ (cooling period):
  - หลัง booking completed ควรมีช่วงเวลาเผื่อการยกเลิก/คืนเงิน ก่อนปล่อยให้เป็น withdrawable
- ถ้า booking ถูก cancel/return/refund (ตามนิยามธุรกิจ) ต้อง void และตัด reward

ตัวอย่างรางวัลที่แนะนำ (ปรับได้ใน `system_config` หรือ table เฉพาะ)(เพิ่มให้แอดมินเว็บปรับแต่งรางวัลได้):
- สำหรับผู้ชวน (referrer)
  - ลูกค้า/ร้านค้า: ให้รางวัลเป็น “คูปอง”
  - คนขับ: ให้รางวัลเป็น “เครดิต” (เข้าระบบกระเป๋าเงินของคนขับ)
- สำหรับผู้ใช้ใหม่ (referee)
  - ให้ “คูปองต้อนรับ” (welcome coupon) 1 ใบ เมื่อเป็นลูกค้าใหม่
    - กรณีมาจาก referral: แจกเมื่อผูกโค้ดสำเร็จ (และ/หรือเมื่อผ่านเงื่อนไขที่กำหนด)
    - กรณีไม่มาจาก referral: แจกจากกติกา “ลูกค้าใหม่” (new customer campaign)

Anti-fraud policies (ระดับแผน):
- 1 account ต่อ 1 device heuristic (เก็บ device fingerprint แบบ soft)
- จำกัดจำนวน referrals ต่อ referrer ต่อวัน/เดือน
- ตรวจซ้ำ: เบอร์โทร/อีเมล/บัตร/บัญชีธนาคาร (ถ้ามี)(ต้องมี)
- ยกเลิกรางวัลถ้า booking ถูก cancel/refund

### 3.4 UX Flow (ข้อเสนอหน้าจอ)
- หน้า “ชวนเพื่อน” ใน Customer App
  - แสดงโค้ด/ลิงก์ชวน
  - ปุ่ม share (deep link)
  - แสดงสถานะเพื่อนที่ชวน (pending/สำเร็จ)
  - แสดงรางวัลที่ได้รับ
- หน้า signup/register
  - ช่อง “ใส่โค้ดชวนเพื่อน (ถ้ามี)”
  - หรือรองรับ deep link ที่พาเข้ามาพร้อม code

### 3.5 Admin/Back-office (ขอบเขตตาม requirement ล่าสุด)
- จัดการ Referral
  - ดูรายการ `referrals` ทั้งหมด (filter: ช่วงเวลา, referrer, referee, role, status)
  - ดู `referral_events` (timeline) และ metadata ที่เกี่ยวข้อง
  - จัดการ `referral_codes` (สร้าง/ปิดใช้งาน/รีเซ็ตโค้ด)
  - ปุ่ม revoke/adjust สถานะ referral และ reward (เฉพาะ admin)
- จัดการ Reward (ประวัติและการปรับปรุง)
  - ดูประวัติรางวัลของ:
    - ผู้ใช้
    - ร้านค้า
    - คนขับ
  - ปรับปรุง/ยกเลิก reward เฉพาะกรณี (ต้องมี audit)

- มาตรฐาน “History/Audit + Search” (สำหรับ admin)
  - ดูประวัติแบบละเอียดที่สุด (drill down ได้ถึง 1 รายการ)
  - รองรับการค้นหาและตัวกรอง (เช่น user_id/merchant_id/driver_id, coupon code, referral code, booking_id, ช่วงเวลา, status)
  - รองรับ export (อย่างน้อย CSV) เพื่อการตรวจสอบ

- แนวคิด “Admin-web จัดการได้ทั้งหมด” (config-driven)
  - ตั้งเป้าให้ admin-web เป็นศูนย์กลางการปรับแต่ง:
    - คูปอง (create/edit/delete/disable + ตั้งค่า distribution)
    - reward rules (กำหนดชนิด/มูลค่า/เงื่อนไข/จำกัดจำนวน)
    - referral rules (qualify event, welcome coupon, cap/anti-fraud flags)
    - coupon financial rules (การคำนวณส่วนลด/การหักเปอร์เซ็นต์/การแบ่งภาระส่วนลด)
  - ลดการแก้โค้ดฝั่งแอพ โดยให้แอพอ่าน config/rules จาก backend เป็นหลัก

#### 3.5.1 Admin Ops Detail (Campaign Operations)
วัตถุประสงค์:
- ให้ admin สามารถสร้าง/ปรับ/ปิดแคมเปญได้ครบวงจร และตรวจสอบย้อนหลังได้

แนวปฏิบัติที่แนะนำ (inspired by TikTok edit-lock):
- แบ่งสถานะแคมเปญ:
  - `draft` (ยังไม่เริ่ม)
  - `scheduled` (ตั้งเวลาแล้ว)
  - `active` (เริ่มแล้ว)
  - `ended` (จบแล้ว)
  - `disabled` (ปิดด้วย admin)
- เมื่อ `active` แล้ว:
  - แก้ได้เฉพาะ field ที่ไม่กระทบ fairness ย้อนหลัง (name/end_time/quantity)
  - การแก้ field สำคัญ (discount type, eligibility, stacking rule) ให้สร้าง “แคมเปญใหม่” แทน

สิทธิ (Admin Actions) ที่ต้องมีพร้อม audit:
- `create_campaign`
- `update_campaign`
- `disable_campaign`
- `grant_coupon_to_user` (แจกเฉพาะกิจ)
- `revoke_coupon_from_user` (เฉพาะเคส fraud/คืนเงิน)
- `adjust_reward` (ปรับ reward)
- `void_reward` (ตัดสิทธิ)
- `manual_approve_reward` (ถ้าต้องการโหมดอนุมัติ)

History/Audit ที่ต้องเก็บให้พอรองรับ “จัดการได้ทั้งหมด”:
- ทุก action ของ admin ต้องบันทึก:
  - `admin_user_id`
  - `action_type`
  - `target_type` (coupon/referral/reward/user_coupon)
  - `target_id`
  - `before`/`after` (diff หรือ snapshot แบบ JSON)
  - `reason` (required)
  - `created_at`

#### 3.5.2 Anti-fraud Detail (Referral + Coupon)
แนวคิด: ทำเป็น “hard rules + risk scoring”
- hard rules กันความเสียหายทันที
- risk scoring ใช้เพื่อ flag ให้ admin ตรวจ

Hard rules (แนะนำเริ่มต้น):
- 1 referee ผูกได้ 1 referrer เท่านั้น (unique)
- reward เกิดหลัง event ที่ verify ได้ (เช่น booking completed)
- ถ้า booking cancel/refund ต้อง void reward
- จำกัดจำนวนการ claim ต่อ user ต่อ campaign ตาม `claim_limit_per_user`

Risk signals ที่ควรเก็บ (ไม่จำเป็นต้องบล็อกทันที):
- device fingerprint (soft)
- เบอร์โทร/อีเมลซ้ำ
- บัญชีธนาคารซ้ำ (กรณี driver)
- pattern ออเดอร์ผิดปกติ (จำนวนมากในช่วงสั้น / cancel rate สูง)

Anti-fraud ops ใน admin:
- หน้า “Fraud Flags”
  - list ผู้ใช้/ออเดอร์/คูปอง/referral ที่ถูก flag
  - action: suspend, revoke reward, revoke coupon, add note
- ต้องมี field `fraud_flag_reason` และ `fraud_flag_score` (หรือ metadata) ใน event log

---

## 4) ออกแบบระบบคูปองแบบ “เก็บ&ใช้” (Coupon Claim & Use)

### 4.1 ข้อสังเกตจากระบบปัจจุบัน
- ปัจจุบัน `coupons` + `coupon_usages` ตอบโจทย์ “ใส่โค้ดแล้วใช้เลย”
- แต่ “เก็บ&ใช้” ต้องมี concept ใหม่คือ **coupon ownership** ต่อ user

### 4.2 Data Model (ข้อเสนอ)
ตารางใหม่ที่แนะนำ:
1) `user_coupons` (หรือ `coupon_claims`)
- `id`
- `user_id`
- `coupon_id`
- `claimed_at`
- `expires_at` (ถ้าต้องการ expiry หลังเก็บ)
- `status` (claimed/used/expired/revoked)
- `used_booking_id` (nullable)
- `used_at` (nullable)
- รองรับ “เก็บได้หลายใบ”:
  - ไม่ควรบังคับ `unique(user_id, coupon_id)`
  - แนะนำเพิ่ม `claim_limit_per_user` (หรือ `max_claims_per_user`) ใน `coupons` เพื่อคุมจำนวนใบที่เก็บได้ต่อคน
  - ฝั่ง consume ต้องเลือก 1 ใบ (1 row) ต่อ 1 booking

2) ปรับ `coupons` (ถ้าจำเป็น)
- เพิ่ม field `distribution_type`:
  - `code_only` (แบบเดิม)
  - `claimable` (กดเก็บได้)
  - `auto_grant` (ระบบแจกอัตโนมัติ เช่น referral reward)
- เพิ่ม `claim_limit` / `claim_limit_per_user` (ถ้าอยากแยกจาก usage_limit)

### 4.2.1 Data Fields ที่ต้องมีเพื่อรองรับ stacking/financial/admin
แนะนำเพิ่ม/ยืนยันฟิลด์ใน `coupons` (แนวคิด ไม่ใช่โค้ด):
- `coupon_type`:
  - `platform_discount` / `merchant_discount` / `free_delivery` / `promo_code`
- `discount_base`:
  - `subtotal` หรือ `delivery_fee` (กันคูปองไปหักผิดฐาน)
- `max_discount_amount` (สำคัญมากสำหรับ percent)
- `stacking_group` (optional): ใช้ทำกติกาชนกันแบบยืดหยุ่นกว่าชนตาม type
- `funding_source` (สำหรับการเงิน/บัญชี):
  - `platform` / `merchant` / `driver` / `split`
- `driver_compensation_policy` (เฉพาะ `free_delivery`):
  - เช่น `merchant_gp_transfer` (หัก GP ร้านเข้าระบบแล้วโอนให้คนขับ)

### 4.2.2 DB/RLS/RPC Design (Outline)
เป้าหมาย: ทุก mutation สำคัญต้องเป็น atomic และทำ server-side

ตารางที่แนะนำเพิ่มเพื่อรองรับงานจริง:
- `admin_audit_logs` (หรือใช้ตารางเดิมถ้ามี)
- (optional) `fraud_flags`

RLS outline:
- `coupons`
  - user: อ่านได้เฉพาะคูปองที่ publish/active และเข้าเงื่อนไขการมองเห็น
  - admin: อ่าน/เขียนทั้งหมด
- `user_coupons`
  - user: อ่านของตัวเอง (write ควรทำผ่าน RPC)
  - admin: อ่าน/เขียนทั้งหมด
- `referrals`, `referral_events`, `referral_rewards`
  - user: อ่านเฉพาะที่ตัวเองเกี่ยวข้อง (referrer/referee)
  - admin: อ่าน/เขียนทั้งหมด
- `coupon_usages`
  - user: อ่าน usage ของตัวเอง
  - admin: อ่านทั้งหมด

RPC/Edge functions ที่ควรมี (ชื่อเป็นแนวคิด):
- `coupon_claim(user_id, coupon_id)`
  - ตรวจ active window + claim_limit_per_user + usage_limit + eligibility
  - สร้าง row ใน `user_coupons`
  - เขียน audit
- `coupon_consume(user_id, user_coupon_id, booking_id, pricing_context)`
  - lock/verify `user_coupons.status == claimed`
  - คำนวณส่วนลดด้วย single source of truth (อ้าง stacking rules + cap ค่าส่ง)
  - เปลี่ยน status เป็น used + create `coupon_usages`
  - เขียน audit
- `coupon_release_on_cancel(booking_id)`
  - ถ้า order cancel/refund:
    - mark usage void/reversed
    - คืน `user_coupons` เป็น claimed หรือ revoked (ตาม policy)
  - เขียน audit
- `referral_bind(referee_user_id, referrer_code)`
  - ตรวจ new user eligibility
  - สร้าง `referrals` + event log
- `referral_qualify_on_booking_completed(booking_id)`
  - ตรวจว่า booking เป็นออเดอร์แรกที่ qualify
  - set referral status qualified + สร้าง pending reward
- `referral_reward_release(referral_reward_id)`
  - หลัง cooling period
  - ปล่อย reward (สร้าง `user_coupons` หรือ wallet credit)
- `referral_reward_void_on_cancel(booking_id)`
  - void/revoke reward เมื่อ cancel/refund

ข้อกำหนด atomicity:
- ทุก RPC ที่ mutate ต้องทำงานใน transaction
- ต้องกัน race condition:
  - claim พร้อมกัน
  - consume พร้อมกัน
  - usage_limit ใกล้หมด

### 4.3 การใช้คูปองใน Checkout (แนวคิด)
- Checkout จะมี 2 ทาง:
  - ใส่ code (เดิม)
  - เลือกจาก “คูปองของฉัน” (ใหม่)
- การ validate ต้องรองรับทั้งสองกรณี แต่ควรใช้ validator กลาง
- แนวคิด auto-apply/auto-claim (inspired by TikTok):
  - ถ้ามีคูปองที่เข้าเงื่อนไขและผู้ใช้ “ยังไม่กดเก็บ” แต่ระบบอนุญาตให้ใช้ได้
    - อาจ auto-claim ให้ก่อน (เพื่อให้เกิด owner record) และนำไปใช้ใน order นั้น
  - ผู้ใช้ควรมีสิทธิเลือก “ไม่ใช้คูปอง” แม้จะมีคูปองที่ใช้ได้
- เมื่อสั่งสำเร็จ:
  - บันทึก usage (เดิม: `coupon_usages`)
  - และ mark `user_coupons` เป็น used พร้อม `used_booking_id`

### 4.4 Rule/Eligibility (แนวคิด)
- ใช้เงื่อนไขเดิมจาก `CouponService.validateCoupon` เป็นฐาน
- เพิ่มกติกาสำหรับ “claim”:
  - claim ได้เฉพาะช่วงเวลาที่ active
  - ถ้า `usage_limit` ใกล้หมด ต้องกัน race condition (ควร enforce ที่ DB/RPC)
  - ถ้า coupon เป็น merchant-specific ต้องแสดงเฉพาะร้านนั้น หรือให้เก็บได้แต่ใช้ได้เฉพาะร้าน

#### 4.4.1 Stacking Matrix (ตารางกติกาการซ้อนคูปอง)
หลักการ:
- 1 order ใช้คูปองได้ “ไม่เกิน 1 ใบต่อประเภท” (cap by type)
- ถ้าชนกัน ให้เลือก “ใบที่ประหยัดที่สุด/เหมาะสมที่สุด” ตามกติกาที่กำหนด และผู้ใช้ต้อง override ได้
- คูปองลดค่าส่งต้องไม่เกินค่าส่งจริง

ตารางตัวอย่าง (ค่า default ที่แนะนำ ปรับได้ใน admin-web):

| ประเภทคูปอง | ใช้ได้พร้อมกันกับ | ใช้ไม่ได้พร้อมกันกับ | เพดานต่อออเดอร์ | หมายเหตุ |
|---|---|---|---:|---|
| `platform_discount` (ลด subtotal) | `free_delivery`, `merchant_discount` | `promo_code` (ถ้ากำหนดให้โค้ดไม่ซ้อน) | 1 | หักจาก subtotal เท่านั้น |
| `merchant_discount` (คูปองร้าน) | `platform_discount`, `free_delivery` | `promo_code` (ถ้ากำหนดให้โค้ดไม่ซ้อน) | 1 | ใช้ได้เฉพาะร้านที่กำหนด |
| `free_delivery` (ลดค่าส่ง) | `platform_discount`, `merchant_discount` | `promo_code` (ถ้ากำหนดให้โค้ดไม่ซ้อน) | 1 | cap ไม่เกินค่าส่งจริง |
| `promo_code` (โค้ดโปร) | (ตามนโยบาย) อาจให้ซ้อนเฉพาะ `free_delivery` | `platform_discount`, `merchant_discount` | 1 | แนว TikTok: โค้ดไม่ซ้อนกับคูปองหลัก |

ลำดับการเลือกคูปอง (tie-breaker) ที่แนะนำ:
- ถ้าชนกันในประเภทเดียวกัน:
  - default: auto-select ใบที่ให้ส่วนลด “มากสุด”
  - แต่ผู้ใช้สามารถเปลี่ยนเป็นใบอื่นได้
- ถ้าชนกันข้ามประเภทจากกติกา `promo_code`:
  - ให้ใช้ `promo_code` หรือ “คูปองหลัก” อย่างใดอย่างหนึ่ง (ตาม config)

### 4.5 UX Flow
- หน้า “คูปอง” แยกเป็น:
  - “คูปองแนะนำ/ใช้ได้” (discover/claim)
  - “คูปองของฉัน” (claimed)
  - “ประวัติการใช้” (optional)
- ใน checkout:
  - แสดง “ใช้คูปอง” -> เลือกจากคูปองของฉัน

### 4.6 Admin Tools
- เพิ่มหน้าจอ admin สำหรับจัดการคูปอง:
  - create/edit/delete/disable (ตาม requirement)
  - ตั้ง distribution_type
  - ดูจำนวน claim / จำนวนใช้
- ดูประวัติการใช้คูปอง:
  - ของ “ผู้ใช้” (user coupon usage history)
  - ของ “ร้านค้า” (merchant coupon usage history)
- รายงาน: coupon performance

แนวคิด edit-lock หลังแคมเปญเริ่ม (inspired by TikTok):
- ถ้า coupon/campaign เริ่มแล้ว:
  - แก้ได้เฉพาะ field บางประเภท เช่น ชื่อแคมเปญ, เวลาสิ้นสุด, เพิ่มจำนวนใบ
  - ไม่ให้แก้ field ที่กระทบความยุติธรรมย้อนหลัง เช่น ประเภทส่วนลด, eligibility, min spend

### 4.7 คูปองลูกค้าใหม่ (Welcome Coupon / New Customer Coupon)
- เป้าหมาย:
  - แจกคูปองให้ “ลูกค้าใหม่” อัตโนมัติ เพื่อเพิ่ม conversion ออเดอร์แรก
  - รองรับทั้งกรณีมาจาก referral และไม่มาจาก referral
- แนวคิดการแจก (distribution):
  - แนะนำใช้แนวคิด `distribution_type = auto_grant` (ระบบแจกอัตโนมัติ)
  - จะถูกเพิ่มเข้า `user_coupons` เป็นใบคูปองของผู้ใช้ (เพื่อให้ผู้ใช้เลือกใช้ตอน checkout)
- เกณฑ์ความเป็น “ลูกค้าใหม่” (ต้องนิยามให้ชัดในสเปค):
  - ตัวอย่างนิยาม: ยังไม่เคยมี booking ที่ completed (หรือยังไม่เคยมี food booking completed)
  - ต้องกัน abuse (สมัครหลายบัญชี) โดยอิง anti-fraud policy เดิม
- ความสัมพันธ์กับ referral:
  - ถ้ามาจาก referral อาจใช้ coupon ชุดเดียวกัน หรือแยกเป็น “welcome_by_referral” และ “welcome_general” ก็ได้ (ขึ้นกับการทำแคมเปญ)

---

## 5) แนวทางการ Integrate กับของเดิม (สำคัญ)

### 5.1 จุดเชื่อมกับ `CouponService`
- `CouponService` ปัจจุบันมี validate + recordUsage ซึ่งดีมาก
- ระบบ “เก็บ&ใช้” ควรเพิ่ม concept การ claim โดยไม่ทำให้ validate ซับซ้อนเกินไป
- หลักการ:
  - validate/price calculation อยู่ใน layer เดียว
  - state mutation (claim/consume) ทำ server-side ให้ atomic

### 5.2 จุดเชื่อมกับ `BookingService` / `bookings`
- รางวัล referral ที่เป็น “คูปอง” ควรผูกกับการสร้าง `user_coupons` ให้ user
- รางวัล referral ที่เป็น “เครดิตเงิน” ต้องระวัง: wallet ปัจจุบันดูเหมือนเน้น driver wallet มากกว่า customer wallet
  - ดังนั้นแนะนำ reward เป็น “coupon” ก่อนเพื่อ minimize impact

### 5.3 Notification/Realtime
- เมื่อ claim coupon / ได้ reward referral อาจสร้าง in-app notification (`notifications` table)
- (optional) ส่ง push เพื่อกระตุ้น

### 5.4 เพิ่มการวิเคราะห์: การคำนวณยอดส่วนลด และการหักเปอร์เซ็นต์จากคูปอง
- เป้าหมายของส่วนนี้คือทำให้ “การเงิน” ชัดเจนว่าคูปองกระทบรายได้ใคร และกระทบ fee ไหนบ้าง
- ประเด็นที่ต้องนิยามในสเปค:
  - ส่วนลดคูปองถูกหักจากฐานตาม “ประเภทส่วนลด”:
    - ส่วนลดยอดอาหาร: หักจาก “ยอดอาหาร (subtotal)” (คนขับยังได้รายได้จากค่าส่งตามปกติ)
    - ส่วนลดค่าส่ง: หักจาก “ค่าส่ง” (ต้องนิยามชัดว่าใครรับภาระส่วนลดค่าส่ง)
    - ทั้งบิล: ไม่แนะนำ (ทำให้การกระทบรายได้/การบัญชีซับซ้อน)
  - กรณี `free_delivery`:
    - ค่าส่งที่ถูกยกเว้น ต้องถูกจำกัดไม่เกินค่าส่งจริง
    - ใครเป็นคนรับภาระ (platform / merchant / driver) และจะบันทึกในระบบอย่างไร
    - requirement ล่าสุด: ระบบต้องชดเชยให้กับคนขับ โดยสามารถใช้นโยบาย เช่น “หัก GP ร้านเข้าระบบ แล้วโอนให้คนขับ”
  - ถ้าเป็น `percentage`/`fixed`:
    - ส่วนลดไปลดฐานคำนวณอะไร (เช่น merchant GP, platform fee) หรือไม่
  - การ “หักเปอร์เซ็นต์จากการใช้คูปอง”:
    - requirement ล่าสุด: ไม่ต้องหัก (ปิดเงื่อนไขนี้)
- แนวทางเพื่อรองรับ admin-web “จัดการได้ทั้งหมด”:
  - สร้าง policy/rule ที่ปรับได้ (เช่น split ของส่วนลด: platform_share / merchant_share / driver_share)
  - แสดงผลใน admin เป็นสูตรชัดเจน และเก็บ audit ทุกครั้งที่มีการเปลี่ยนกติกา

### 5.5 Scenario Tests (ตัวอย่างเคสคำนวณที่ต้องได้ผลลัพธ์ตรงกัน)
> ใช้เป็น test cases สำหรับ dev + อ้างอิงใน admin “Promotion Simulator”

นิยามสั้น:
- `subtotal` = ยอดอาหาร
- `delivery_fee` = ค่าส่งจริง
- `delivery_discount_applied` = ส่วนลดค่าส่งที่นำไปหักจริง (ต้อง <= delivery_fee)

เคส 1: ลด subtotal อย่างเดียว
- subtotal 100, delivery_fee 10, คูปอง `platform_discount` 20
- ผลที่ต้องได้:
  - หักจาก subtotal = 20
  - ยอดค่าส่งไม่เปลี่ยน
  - คนขับได้ค่าส่งตาม policy ปกติ

เคส 2: free_delivery ต่ำกว่าค่าส่ง
- subtotal 100, delivery_fee 10, คูปอง `free_delivery` 5
- ผลที่ต้องได้:
  - delivery_discount_applied = 5
  - ลูกค้าจ่ายค่าส่ง 5

เคส 3: free_delivery สูงกว่าค่าส่ง (ต้อง cap)
- subtotal 100, delivery_fee 10, คูปอง `free_delivery` 20
- ผลที่ต้องได้:
  - delivery_discount_applied = 10 (cap)
  - ส่วนลดส่วนเกิน 10 บาท “ตัดทิ้ง” ไม่ไปลด subtotal
  - ต้องชดเชยคนขับตาม policy ที่กำหนด (เช่น หัก GP ร้านเข้าระบบแล้วโอนให้คนขับ)

เคส 4: stacking `platform_discount` + `free_delivery`
- subtotal 200, delivery_fee 30
- คูปอง: `platform_discount` 40 + `free_delivery` 20
- ผลที่ต้องได้:
  - หัก subtotal 40
  - หักค่าส่ง 20 (ไม่เกิน 30)

เคส 5: ชนกันในประเภทเดียวกัน (เลือกใบที่คุ้มสุด แต่ผู้ใช้ override ได้)
- subtotal 300, delivery_fee 20
- มี `platform_discount` 30 และ `platform_discount` 50
- ผลที่ต้องได้:
  - auto-select 50 (default)
  - ผู้ใช้เปลี่ยนเป็น 30 ได้

เคส 6: `promo_code` ไม่ซ้อนกับคูปองหลัก
- subtotal 300, delivery_fee 20
- มี `promo_code` 15% และ `platform_discount` 50
- ผลที่ต้องได้:
  - เลือกได้อย่างใดอย่างหนึ่ง (ตาม config)
  - simulator ต้องบอกเหตุผลชัดว่า “โค้ดไม่ซ้อนกับคูปองหลัก”

เคส 7: merchant-only coupon (ใช้ผิดร้าน)
- subtotal 250, delivery_fee 25
- คูปอง `merchant_discount` ของร้าน A แต่ checkout ร้าน B
- ผลที่ต้องได้:
  - ใช้ไม่ได้ พร้อมเหตุผล merchant mismatch

เคส 8: หมดอายุ / เกินจำนวนใช้
- คูปองหมดอายุ หรือ used_count == usage_limit
- ผลที่ต้องได้:
  - ใช้ไม่ได้ พร้อมเหตุผล

เคส 9: per-user limit
- คูปองกำหนด per_user_limit = 1 และ user เคยใช้แล้ว
- ผลที่ต้องได้:
  - ใช้ไม่ได้ พร้อมเหตุผล

เคส 10: auto-claim + apply (แนว TikTok)
- ผู้ใช้ไม่ได้กดเก็บ แต่คูปองเป็นแบบ claimable และเข้าเงื่อนไข
- ผลที่ต้องได้:
  - ระบบทำ auto-claim ให้เกิด owner record ก่อน
  - แล้ว apply ใน order เดียวกัน

---

## 6) Milestones (แผนทำงานแบบเป็นเฟส)

### Phase 0: Discovery/Spec (1–2 วัน)
- ยืนยัน requirement เชิงธุรกิจ:
  - Referral reward เป็นอะไร (coupon/credit) และ event ใดเป็นตัว qualify (คูปอง สำหรับ ผู้ใช้และร้านค้า credit สำหรับ คนขับ)
  - New customer coupon: แจกเมื่อไร (สมัครทันที/ออเดอร์แรก/complete ครั้งแรก) และเป็นคูปองชุดเดียวกับ referral หรือไม่
  - Coupon claim: เก็บได้กี่ใบ/หมดอายุแบบไหน
  - Coupon financial rules: คำนวณส่วนลดจากฐานไหน และใครรับภาระส่วนลด/การหักเปอร์เซ็นต์
- ยืนยัน roles ที่เกี่ยวข้อง (customer/merchant/driver/admin) 

### Phase 1: Database Design + RLS Plan (2–4 วัน)
- ออกแบบ schema ที่เสนอ (referral_codes, referrals, referral_events, user_coupons)
- ออกแบบ RLS:
  - user อ่าน referral/coupon ของตัวเอง
  - admin อ่านทั้งหมด
- ออกแบบ RPC/Edge function ที่ต้องมีเพื่อ atomic operations (claim/consume/reward)

### Phase 1B: Admin Audit/History Requirements (1–2 วัน)
- ออกแบบ “แหล่งความจริง” ของ history/audit ให้ admin ดูได้ครบ:
  - Coupon: claim history + usage history แยก user/merchant
  - Reward: reward history แยก driver/user/merchant
  - Referral: referral + referral event + referral code
- นิยาม field ที่ต้องเก็บเพิ่มในตาราง audit เพื่อทำรายงาน/ค้นหาย้อนหลังได้
- นิยาม search keys และ index ที่ต้องมี (เพื่อรองรับการค้นหาใน admin-web)

### Phase 2: UX/UI Plan (2–4 วัน)
- Customer:
  - หน้าชวนเพื่อน
  - หน้าคูปอง (discover + my coupons)
  - checkout เลือกคูปอง
- Admin:
  - หน้าดู referrals
  - หน้าจัดการคูปอง

### Phase 3: QA / Test Plan (2–3 วัน)
- Test cases:
  - Referral: ผูกโค้ดถูกต้อง, ผูกซ้ำไม่ได้, reward ออกเมื่อ qualify, revoke เมื่อ cancel
  - Coupon claim: claim ได้ตามเงื่อนไข, claim ซ้ำ/เกิน limit ถูกบล็อก, ใช้แล้ว mark used
  - Race condition: claim พร้อมกันหลายเครื่อง, usage_limit ใกล้หมด

---

## 7) ความเสี่ยง (Risks) และแนวทางลดความเสี่ยง

- Risk: fraud/abuse ใน referral
  - Mitigation: ให้ reward หลัง completed + cap จำนวน/วัน + audit events
- Risk: race condition coupon usage/claim
  - Mitigation: ทำ atomic ด้วย RPC/transaction ใน DB
- Risk: RLS ซับซ้อน
  - Mitigation: แยก policy per table + มี admin override ชัดเจน
- Risk: ความไม่ชัดเจนเรื่อง “เครดิตเงิน” ฝั่ง customer
  - Mitigation: เริ่ม reward เป็น coupon ก่อน แล้วค่อยขยายเป็น credit ในเฟสถัดไป

- Risk: admin ปรับ reward/coupon ย้อนหลังแล้วกระทบความถูกต้องบัญชี
  - Mitigation: ทุกการปรับต้องเป็น append-only log (audit) และมีสถานะ revoked/adjusted แทนการลบข้อมูลสำคัญ

---

## 8) คำถามที่ต้องการคำตอบจากคุณ (เพื่อ finalize spec)

### Referral Program
1) ต้องการ reward เป็นอะไร?
- คูปอง (สำหรับผู้ใช้และร้านค้า)
- เครดิตเงินในกระเป๋า (สำหรับคนขับ)

2) ให้ reward เมื่อ event ไหน?
- ผู้ใช้เมื่อเพื่อน “ทำออเดอร์แรกสำเร็จ (completed)”
- คนขับเมื่อเพื่อน “ทำออเดอร์แรกสำเร็จ (completed)"

3) ต้องการให้ reward ทั้ง 2 ฝั่งไหม?
- ผู้ชวน + ผู้ใช้ใหม่ (referee ได้คูปองต้อนรับ)

4) คูปองต้อนรับสำหรับ “ลูกค้าใหม่ที่ไม่มาจาก referral” ต้องการแจกไหม?
- แจก
- ไม่แจก

### Coupon เก็บ&ใช้
5) คูปองเก็บได้ครั้งเดียวต่อคน หรือเก็บได้หลายใบ?
- คูปองเก็บได้หลายใบ
6) หลังเก็บแล้วต้องหมดอายุเร็วขึ้นไหม (expires_at per claim)?
- มีวันหมดอายุ
7) ต้องการให้ร้านค้าสร้างคูปอง “แจกให้ลูกค้าเก็บ” ได้ไหม หรือ admin เท่านั้น?
- admin เท่านั้น

### Coupon Financial (เพิ่มเติม)
8) ส่วนลดคูปองต้องหักจากฐานไหน?
- เงื่อนไข: เฉพาะยอดอาหาร ต่อเมื่อเป็นส่วนลดยอดอาหาร (คนขับได้รายได้จากค่าส่ง ระบบไม่ได้)
- เงื่อนไข: เฉพาะค่าส่ง ต่อเมื่อเป็นส่วนลดค่าส่ง (คนขับได้รายได้จาก gp split หรือ gp ร้านค้า ระบบไม่ได้)
- เงื่อนไข: ทั้งบิล (ไม่แนะนำ)
9) การ “หักเปอร์เซ็นต์จากการใช้คูปอง” ต้องการรูปแบบไหน? 
- ไม่ต้องหัก ปิดเงื่อนไขนี้

### Admin (เพิ่มเติมเพื่อปิด requirement)
10) หน้าประวัติที่ต้องมีใน admin ต้องการ “ระดับความละเอียด” แค่ไหน?
- ดูเฉพาะรายการ (table)
- กดเข้าไปดูรายละเอียด 1 รายการ (เช่น coupon usage 1 ครั้ง / reward 1 รายการ / referral 1 คู่)
- ดูประวัติทั้งหมดละเอียดที่สุด
- รองรับการค้นหา
11) การ “จัดการรางวัล” ใน admin หมายถึงอะไรบ้าง?
- แก้ไขจำนวนเงิน/ชนิดรางวัล
- revoke/คืนสถานะ
- อนุมัติ/ไม่อนุมัติ (manual approval)
- จัดการได้ทั้งหมด

---

## 8.1 Decision Log (สรุปค่าที่ต้อง “ล็อก” ก่อนเริ่มทำจริง)
> ส่วนนี้ทำให้สเปคปิดได้เร็ว: ทุกข้อควรมี “ค่า default” และระบุว่า admin ปรับได้หรือไม่

1) Coupon stacking policy (default)
- default: ใช้ได้ 3 ประเภท (platform_discount + free_delivery + merchant_discount) และ 1 ใบต่อประเภท
- `promo_code`:
  - default: ไม่ซ้อนกับคูปองหลัก
- admin ปรับได้: ได้ (ผ่าน config)

2) Auto-claim/auto-apply
- default: เปิดเฉพาะคูปองบางแบบ (เช่น claimable ที่ทำเพื่อ onboarding)
- admin ปรับได้: ได้

3) Delivery discount cap
- default: cap ไม่เกินค่าส่งจริง และส่วนเกินตัดทิ้ง
- admin ปรับได้: ไม่ควรให้ปิด (เป็นกติกาความถูกต้อง)

4) Driver compensation for delivery discount
- default: คนขับต้องได้รับการชดเชยตาม policy
- นโยบายเริ่มต้นที่รองรับ requirement ล่าสุด:
  - หัก GP ร้านเข้าระบบ แล้วโอนให้คนขับ
- admin ปรับได้: ได้ (แต่ต้องมี audit)

5) Referral qualification event
- default: referee ต้องมี booking แรก “completed”
- reward release: pending -> cooling period -> withdrawable/usable
- cancel/refund: void

6) นิยาม “ลูกค้าใหม่” (Welcome coupon)
- default: ยังไม่เคยมี food booking completed
- admin ปรับได้: ได้

7) Admin edit-lock
- default: หลังแคมเปญเริ่ม แก้ได้เฉพาะ name/end_time/quantity
- admin ปรับได้: ได้ (แต่ไม่แนะนำ)

8) Data retention / audit
- default: append-only event log (ไม่ลบ)
- admin ปรับได้: ไม่ควร

---

## 8.2 Spec Checklist (ต้องตอบให้ครบก่อนเริ่ม implementation)
- สรุป `coupon_type` ที่ใช้จริงทั้งหมด
  - `platform_discount`
  - `free_delivery`
  - `merchant_discount`
  - `promo_code`
- สรุป stacking matrix เวอร์ชัน final
  - `platform_discount` + `merchant_discount`
  - `free_delivery` + `merchant_discount`
- นิยาม `service_type` ที่คูปองรองรับ (food/ride/parcel)
  - `platform_discount`: food/ride
  - `free_delivery`: food/ride
  - `merchant_discount`: food/ride
  - `promo_code`: food/ride
- นิยาม event สำหรับ referral qualify + revoke
  - `referral_qualify`
  - `referral_revoke`
- นิยาม policy ชดเชยคนขับเมื่อส่วนลดค่าส่งเกิดขึ้น (source of fund + accounting)
  - `platform_discount`: GP ร้าน
  - `free_delivery`: GP ร้าน
  - `merchant_discount`: GP ร้าน
  - `promo_code`: GP ร้าน
- นิยาม field ที่ต้องแสดงใน admin history/search/export
- นิยามสิทธิ admin actions (revoke/adjust/manual approval)

---

## 9) สถานะ
- ทำการวิเคราะห์โปรเจคหลังอัปเดตแล้ว (โครงสร้าง + Supabase migrations + services หลัก)
- ออกแบบแนวคิด Referral และ Coupon Claim&Use ระดับสถาปัตยกรรมแล้ว
- เอกสารนี้พร้อมสำหรับ review เพื่อยืนยัน requirement ก่อนลงรายละเอียดเชิง implementation ในรอบถัดไป

### อธิบายผลกระทบเมื่อเพิ่มฟีเจอร์ใหม่นี้

#### ผลกระทบด้าน Database / Schema
- ต้องเพิ่มตาราง/คอลัมน์ที่เกี่ยวข้องกับ:
  - referral (code, relation, events, rewards)
  - coupon claim/ownership (`user_coupons`)
  - (ถ้ามี) ตาราง/ข้อมูลสำหรับ welcome coupon (auto-grant)
- ต้องเตรียม index สำหรับ admin search:
  - `user_id`, `merchant_id`, `driver_id`, `coupon_id`, `code`, `booking_id`, `status`, `created_at`

#### ผลกระทบด้าน RLS / Security
- RLS ต้องรองรับ:
  - user เห็นข้อมูลของตัวเองเท่านั้น (coupon claims/usages/referrals)
  - admin เห็นทุกอย่าง + ค้นหาได้
- จุดเสี่ยง: การทำ atomic (claim/consume/reward) ต้องทำ server-side เพื่อลดการโกงและ race condition

#### ผลกระทบด้าน Logic การคำนวณราคา (Checkout / Booking)
- ต้องมี “single source of truth” ในการคำนวณส่วนลด:
  - ส่วนลดยอดอาหาร -> หักจาก subtotal
  - ส่วนลดค่าส่ง/free_delivery -> หักจากค่าส่งเท่านั้น (เช่น 100 บาท ค่าส่ง 10 บาท แต่ใช้ส่วนลดค่าส่ง 20 บาท ต้องหัก 10 บาท ไม่หัก 20 บาท แต่ต้องชดเชยให้กับคนขับโดยใช้การหัก gp จากร้านเข้าระบบเปลี่ยนให้คนขับ)
  - ทั้งบิล -> ไม่แนะนำ
- ต้องยืนยันผลกระทบต่อรายได้คนขับ:
  - คนขับได้รายได้จากค่าส่งตามปกติเมื่อเป็นส่วนลดยอดอาหาร
  - กรณีลดค่าส่ง ต้องชัดว่าใครชดเชย และคนขับยังได้ตาม policy
  - ระบบชดเชยให้กับคนขับ

#### ผลกระทบด้าน Wallet/Accounting
- reward เป็น “เครดิตคนขับ” จะกระทบ:
  - wallet balance
  - wallet transaction history
  - audit ที่ admin ต้องตรวจสอบย้อนหลังได้

#### ผลกระทบด้าน Notifications
- เมื่อ:
  - ผู้ใช้ได้ welcome coupon
  - ได้ reward จาก referral
  - claim/consume coupon สำเร็จ
  - (optional) ส่ง in-app notification และ/หรือ push

#### ผลกระทบด้าน Admin-web (UI/UX + Data)
- ต้องรองรับ:
  - จัดการคูปองทั้งหมด (create/edit/delete/disable)
  - จัดการ referral/referral code/referral event
  - จัดการ reward ทั้งหมด
  - history/audit แบบละเอียด + ค้นหา + export
- แนวทางลดการแก้โค้ด:
  - ทำเป็น config-driven (ปรับ rules/campaigns/financial policy ได้จาก admin)

#### ผลกระทบด้าน QA / Monitoring
- ต้องเพิ่ม test cases:
  - welcome coupon (referral และ non-referral)
  - coupon claim หลายใบ + expiry
  - สิทธิ์ admin search และ export
  - race condition ตอน claim/consume
- ต้องมี monitoring/alert สำหรับ:
  - coupon แจกผิดเงื่อนไข
  - reward ซ้ำ
  - รายได้คนขับผิดพลาดจากการหักค่าส่ง
