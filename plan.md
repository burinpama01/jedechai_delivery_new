# แผนการซ่อมแซมระบบ Jedechai Delivery — Comprehensive Repair Plan

> **สร้างจาก**: `research.md` (สถาปัตยกรรม + codebase analysis) + `audit_report.md` (38 ประเด็น: 12 Critical, 18 High, 8 Medium)
> **สถานะ**: **Phase 1 — IMPLEMENTED** (ดูรายละเอียดด้านล่าง)
> **หลักการจัดลำดับ**: ความรุนแรง × ผลกระทบทางธุรกิจ × dependency chain

---

## สารบัญ

| Phase | ชื่อ | ระดับ | ประเด็นที่ปิด |
|-------|------|-------|---------------|
| **1** | Security Foundation — Admin Web & Secret Keys | Critical | 8 |
| **2** | Financial Atomicity — Wallet & Transaction Integrity | Critical | 6 |
| **3** | Auth & Authorization Hardening | Critical+High | 5 |
| **4** | Booking Flow & State Machine Fixes | Critical+High | 6 |
| **5** | Coupon, Notification & Realtime Fixes | High | 9 |
| **6** | Data Validation & Input Sanitization | High+Medium | 4 |
| **7** | Code Quality & Technical Debt Cleanup | Medium | 5+ |

---

## 🎯 เป้าหมายของแผนงาน (Goal)

ปิดประเด็นทั้ง 38 รายการจาก audit report ใน 7 Phases โดยเรียงตามความเร่งด่วน:

1. **ตัด attack chain ที่ร้ายแรงที่สุด** — Service Role Key บน browser + XSS = full DB compromise
2. **ทำให้ธุรกรรมการเงินเป็น atomic + idempotent** — ป้องกันยอดเงินผิดจาก race condition
3. **ปิดช่องโหว่ auth/authorization** — role confusion, privilege escalation, secret keys ใน APK
4. **แก้ booking flow bugs** — authorization check, state machine, duplicate logic
5. **แก้ coupon/notification/realtime bugs** — usage bypass, notification spam, performance
6. **เพิ่ม input validation** — type safety, format check, min/max
7. **ลด technical debt** — duplicate code, modularization, testing

---

## Phase 1: Security Foundation — Admin Web & Secret Keys

### ประเด็นที่ปิด (8 รายการ)

| # | ระดับ | ประเด็น | อ้างอิง audit |
|---|-------|---------|---------------|
| 1 | Critical | Service role key ใช้บน browser โดยตรง | §1.1, §3.1 |
| 2 | Critical | XSS surface สูงจาก `innerHTML` + unescaped interpolation | §1.2, §12.1-3 |
| 3 | Critical | `auth.admin.listUsers()` ถูกเรียกจาก browser | §12.2 |
| 4 | High | Stored XSS + Service key = full DB compromise chain | §12.1 |
| 5 | High | RLS policy `USING (true)` ในตารางสำคัญ | §3.2 |
| 6 | High | ไม่พบ canonical RLS สำหรับ wallets/wallet_transactions/bookings | §3.3 |
| 7 | High | Duplicate function declarations ใน app.js 7+ ชุด | §12.4 |
| 8 | Medium | Error handling ไม่สม่ำเสมอใน admin web | §1.7 |

### 1A) ย้าย Security Model ของ Admin Web

**ปัจจุบัน**: browser ถือ `SUPABASE_SERVICE_KEY` → bypass RLS ทั้งหมด → key รั่ว = game over

**เป้าหมาย**: browser ถือแค่ `anon key` + admin session → privileged actions ผ่าน Edge Functions เท่านั้น

- **Read path**: ใช้ RLS + policy จำกัดสิทธิ์ — admin อ่านได้เฉพาะข้อมูลที่จำเป็นต่อ dashboard
- **Write path**: ใช้ Edge Functions เป็น gate เดียว — approve/reject/force cancel/financial writes ทั้งหมด
- ทุก Edge Function ตรวจ `profiles.role = 'admin'` จาก auth context ก่อน execute
- ย้าย `fetchUserEmails()` (ที่เรียก `auth.admin.listUsers()`) ไปเป็น Edge Function
- ลบ `SUPABASE_SERVICE_KEY` ออกจาก `config.js` / `config.production.js` / browser assets

### 1B) XSS Sanitization

- สร้าง utility function `escapeHtml()` สำหรับ escape ข้อมูลจาก DB ก่อน interpolate ลง template string
- ทำ search-and-replace ทุกจุดที่ใช้ `innerHTML` กับ user-controlled data → ใช้ `textContent` หรือ `escapeHtml()`
- จุดสำคัญ: ชื่อผู้ใช้, ที่อยู่, หมายเหตุ, เหตุผลปฏิเสธ, ชื่อร้าน, error messages
- Error message interpolation (`app.js:319`) → escape ก่อน render

### 1C) RLS Hardening

- ทบทวน policy ที่ใช้ `USING (true)` → เปลี่ยนเป็น explicit role condition
- เพิ่ม canonical RLS policies สำหรับ `bookings`, `wallets`, `wallet_transactions`, `withdrawal_requests`, `topup_requests`
- นิยาม 3 ระดับ access: **owner** (self data), **admin** (role-based moderation), **service** (Edge Functions only)

### 1D) Admin Web Code Cleanup

- ลบ duplicate function declarations ทั้ง 7+ ชุด (เก็บเฉพาะ definition เดียว)
- ทำให้ error handling สม่ำเสมอ (ใช้ `showToast()` เป็นหลัก, ลบ silent catch ที่ไม่จำเป็น)

### ลำดับงานย่อย

1. Inventory ทุก admin action ที่ต้องใช้สิทธิ์สูง (~15-20 actions)
2. ออกแบบ Edge Function contracts (input/output/error semantics)
3. สร้าง authorization guard กลาง (shared helper) สำหรับ admin Edge Functions
4. สร้าง `escapeHtml()` utility + ทำ XSS sanitization pass ทั่ว `app.js`
5. ลบ duplicate functions
6. อัปเดต `app.js` ให้เรียก Edge Function endpoints แทน direct table writes
7. เขียน migration ใหม่สำหรับ RLS hardening
8. ลบ service key จาก web config + ทดสอบ

### ไฟล์ที่ต้องแก้ไข

- `admin-web/app.js` — ปรับ security model, XSS sanitize, ลบ duplicates
- `admin-web/config.js` — ลบ service key
- `admin-web/config.production.js` — ลบ service key
- `supabase/functions/` — สร้าง Edge Functions ใหม่สำหรับ admin privileged actions
- `supabase/migrations/` — เพิ่ม migration สำหรับ RLS hardening

### Dependencies
- ไม่มี dependency กับ Phase อื่น — **ทำก่อนได้เลย**
- Phase 2 จะได้ประโยชน์จาก Edge Functions ที่สร้างใน Phase นี้

### ✅ Phase 1 Implementation Summary (สิ่งที่ทำแล้ว)

**1A) ย้าย Security Model — COMPLETED**

| สิ่งที่ทำ | รายละเอียด |
|-----------|-----------|
| ลบ `SUPABASE_SERVICE_KEY` ออกจาก browser | ลบทุก reference ใน `app.js`, `config.js`, `config.example.js` |
| ลบ `supabaseAdmin` client | ไม่มี service-role client ใน browser อีกต่อไป |
| สร้าง `callAdminAction()` helper | ส่ง request ไป Edge Function พร้อม JWT token |
| ย้าย `auth.admin.listUsers()` | ไปอยู่ใน Edge Function `fetch_user_emails` action |
| ย้าย direct DB writes ทั้งหมด (~40+ จุด) | ผ่าน `callAdminAction()` → Edge Function |

**Actions ที่ย้ายไป Edge Function:**
- **System Config**: `upsert_system_config`, `upsert_system_config_kv`
- **Account Deletion**: `approve_account_deletion`, `reject_account_deletion`
- **Coupons**: `create_coupon`, `toggle_coupon`, `delete_coupon`, `update_coupon`
- **Menu Management**: `create_menu_item`, `update_menu_item`, `delete_menu_item`, `create_menu_option`, `update_menu_option`, `delete_menu_option`, `create_menu_option_group`, `delete_option_group`, `create_option_group_and_link`, `toggle_link_group`, `unlink_option_group`
- **Support Tickets**: `update_ticket_status`, `resolve_ticket`
- **Order Management**: `assign_order`, `cancel_order`, `force_cancel_order`, `rebroadcast_order`, `reassign_order`
- **Wallet/Financial**: `wallet_adjust`, `manual_topup`, `approve_withdrawal_with_slip`
- **Banners**: `create_banner`, `toggle_banner`, `delete_banner`
- **User Management**: `approve_driver/merchant`, `reject_driver/merchant`, `suspend_user`, `unsuspend_user`, `delete_user`, `set_online_status`, `edit_driver`, `edit_merchant`, `add_driver`, `add_merchant`
- **Withdrawal/Topup**: `approve_withdrawal`, `reject_withdrawal`, `approve_topup`, `reject_topup`

**1B) XSS Prevention — PARTIALLY COMPLETED**
- เพิ่ม `escapeHtml()` utility function
- ใช้ `escapeHtml()` ใน error messages ทั่ว `app.js`
- ⚠️ ยังเหลือ: sanitize data display จาก DB ใน `innerHTML` templates (ชื่อผู้ใช้, ที่อยู่, ฯลฯ)

**1C) RLS Hardening — NOT YET STARTED**
- ⚠️ ยังไม่ได้เขียน migration สำหรับ RLS policies

**1D) Admin Web Code Cleanup — NOT YET STARTED**
- ⚠️ ยังไม่ได้ลบ duplicate functions

**ไฟล์ที่แก้ไขแล้ว:**
- `admin-web/app.js` — ย้ายทุก privileged write ไป Edge Function, เพิ่ม `escapeHtml()`, ลบ service key references
- `admin-web/config.js` — ลบ service key, อัปเดต comments
- `admin-web/config.example.js` — ลบ service key, อัปเดต comments
- `supabase/functions/admin-actions/index.ts` — เพิ่ม 30+ handler functions สำหรับทุก admin action
- `supabase/functions/_shared/admin-auth.ts` — shared auth helper (มีอยู่แล้ว, ไม่ต้องแก้)

---

## Phase 2: Financial Atomicity — Wallet & Transaction Integrity

### ประเด็นที่ปิด (6 รายการ)

| # | ระดับ | ประเด็น | อ้างอิง audit |
|---|-------|---------|---------------|
| 1 | Critical | Wallet operations ทั้งหมดเป็น read-then-write ไม่ atomic | §10.1 |
| 2 | Critical | Top-up/withdrawal ไม่มี idempotency guard | §2.1 |
| 3 | Critical | Withdrawal partial failure = request สร้างแต่เงินไม่หัก | §10.2 |
| 4 | Critical | Wallet topup screen มี direct wallet update นอก WalletService | §10.3 |
| 5 | Critical | Booking completion commit status ก่อน financial deduction | §2.3 |
| 6 | High | Driver assignment race — accept by id only, no optimistic lock | §2.4 |

### 2A) Atomic Wallet Operations ผ่าน Postgres RPC Functions

**ปัจจุบัน**: Flutter app ทำ `SELECT balance` → คำนวณ `newBalance` ใน app → `UPDATE balance = newBalance` (read-then-write)

**เป้าหมาย**: ใช้ Postgres function ที่ทำ `UPDATE wallets SET balance = balance + $amount` ภายใน transaction เดียว

- สร้าง RPC functions:
  - `wallet_deduct(wallet_id, amount, description, ref_id)` — หักเงิน + insert transaction + return ผลลัพธ์
  - `wallet_topup(wallet_id, amount, description, ref_id)` — เติมเงิน + insert transaction
  - `wallet_adjust(wallet_id, amount, description, admin_id)` — admin adjustment
- ทุก function ต้อง: ตรวจ balance เพียงพอก่อนหัก (ภายใน transaction เดียวกัน), insert `wallet_transactions` record, return `{success, new_balance, transaction_id}` หรือ `{error: 'insufficient_balance'}`
- ลบ direct wallet update ทุกจุดใน codebase → เรียก RPC แทน

### 2B) Idempotency Guard สำหรับ Topup/Withdrawal

- ทุก approve/reject action ต้องมี expected-state precondition:
  - `UPDATE topup_requests SET status='completed' WHERE id=$id AND status='pending'`
  - ถ้า affected rows = 0 → return `already_processed` (ไม่ทำซ้ำ)
- สร้าง Postgres function `approve_topup(request_id, admin_id)` ที่:
  1. ตรวจ status = 'pending' (ภายใน transaction)
  2. Update request status → 'completed'
  3. เรียก `wallet_topup()` ภายใน transaction เดียวกัน
  4. Return ผลลัพธ์ atomic
- ทำเช่นเดียวกันสำหรับ `reject_topup`, `approve_withdrawal`, `reject_withdrawal`

### 2C) Booking Completion — Settlement-First Model

**ปัจจุบัน**: update status → `completed` ก่อน → แล้วค่อยหัก commission (ถ้า fail = booking completed แต่ไม่หักเงิน)

**เป้าหมาย**: settlement + status update เป็น atomic unit เดียว

- สร้าง Postgres function `complete_booking(booking_id, driver_id, earnings_data)` ที่:
  1. ตรวจ booking status = expected pre-completion state
  2. หักเงินจาก driver wallet (ผ่าน `wallet_deduct`)
  3. Update booking status → 'completed' + driver_earnings + app_earnings
  4. ทั้งหมดภายใน transaction เดียว — ถ้า step ใด fail → rollback ทั้งหมด

### 2D) Optimistic Concurrency สำหรับ Job Assignment

- เปลี่ยน `acceptBooking()` จาก `.eq('id', bookingId)` เป็น `.eq('id', bookingId).is('driver_id', null).eq('status', expectedStatus)`
- ถ้า affected rows = 0 → throw "งานนี้ถูกรับไปแล้ว"
- ทำเช่นเดียวกันสำหรับ admin dispatch path ใน `app.js`

### 2E) ลบ Direct Wallet Update นอก Service

- ลบ direct `wallets.update` ใน `wallet_topup_screen.dart:715-717`
- ทุก wallet operation ต้องผ่าน `WalletService` → RPC function เท่านั้น

### ลำดับงานย่อย

1. ออกแบบ Postgres RPC functions สำหรับ wallet operations
2. เขียน migration สร้าง functions + ทดสอบใน SQL
3. ปรับ `WalletService` ให้เรียก RPC แทน read-then-write
4. ปรับ `WithdrawalService` ให้เรียก RPC
5. ปรับ `AdminService` (approve/reject topup/withdrawal) ให้เรียก RPC
6. สร้าง `complete_booking` RPC function
7. ปรับ `BookingService.updateBookingStatus()` ให้เรียก RPC เมื่อ status = completed
8. เพิ่ม optimistic concurrency ใน `acceptBooking()` + admin dispatch
9. ลบ direct wallet update ใน `wallet_topup_screen.dart`
10. ทำ reconciliation check: `SUM(wallet_transactions.amount) = wallets.balance`

### ไฟล์ที่ต้องแก้ไข

- `supabase/migrations/` — สร้าง RPC functions (wallet_deduct, wallet_topup, approve_topup, approve_withdrawal, complete_booking ฯลฯ)
- `lib/common/services/wallet_service.dart` — เปลี่ยนเป็น RPC calls
- `lib/common/services/withdrawal_service.dart` — เปลี่ยนเป็น RPC calls
- `lib/common/services/booking_service.dart` — completion RPC + optimistic concurrency
- `lib/common/services/admin_service.dart` — approve/reject ผ่าน RPC
- `lib/apps/driver/screens/wallet_topup_screen.dart` — ลบ direct wallet update
- `admin-web/app.js` — ปรับ approve/reject/dispatch ให้ใช้ Edge Function (จาก Phase 1) หรือ RPC

### Dependencies
- **ควรทำหลัง Phase 1** เพราะ admin web actions จะถูกย้ายไป Edge Functions แล้ว → เรียก RPC จาก Edge Function ได้เลย

---

## Phase 3: Auth & Authorization Hardening

### ประเด็นที่ปิด (5 รายการ)

| # | ระดับ | ประเด็น | อ้างอิง audit |
|---|-------|---------|---------------|
| 1 | Critical | `getUserRole()` default เป็น customer ในทุกกรณี error | §8.1 |
| 2 | Critical | Profile auto-creation จาก userMetadata ไม่ validate role | §8.2 |
| 3 | High | Admin operations ไม่มี role check ก่อนทำงาน | §8.3 |
| 4 | High | Firebase Service Account Private Key ใน client `.env` | §8.4 |
| 5 | High | Omise Secret Key ใน client `.env` | §8.5 |

### 3A) แก้ `getUserRole()` — ไม่ default เป็น customer เมื่อ error

- เมื่อ network error หรือ profile ไม่พบ → throw error หรือ return `null` แทน `'customer'`
- ให้ `AuthGate` จัดการ error state แยก (แสดงหน้า retry/error แทนการ route ไป customer)
- เพิ่ม role cache ที่ `currentUserRole` getter ใช้ได้จริง (ไม่ hardcode `'customer'`)

### 3B) ป้องกัน Role Injection ผ่าน userMetadata

- ลบ `role` ออกจาก fields ที่อ่านจาก `user.userMetadata` ตอน auto-create profile
- กำหนด role เฉพาะจาก business logic (signup flow กำหนด role → ไม่รับจาก client metadata)
- ทางเลือก: ใช้ Database Trigger (`handle_new_user`) ที่ hardcode role = 'customer' สำหรับ user ใหม่ → admin/driver/merchant ต้องถูกเปลี่ยน role โดย admin เท่านั้น

### 3C) เพิ่ม Role Check ใน AdminService

- เรียก `isCurrentUserAdmin()` ที่ต้นทุก method ใน `AdminService`
- ถ้าไม่ใช่ admin → throw `UnauthorizedException` ทันที
- สร้าง private helper `_ensureAdmin()` เพื่อลด code ซ้ำ

### 3D) ย้าย Secret Keys ออกจาก Client APK

**Firebase Service Account Key:**
- ย้ายการส่ง FCM notification ไปเป็น Supabase Edge Function
- Edge Function ถือ service account key → Flutter app เรียก Edge Function แทน
- ลบ Firebase SA credentials ออกจาก `.env` ฝั่ง client

**Omise Secret Key:**
- ย้าย `createCharge()` และ `checkChargeStatus()` ไปเป็น Edge Function (มี `payment-create-charge` scaffold อยู่แล้ว)
- Flutter app ใช้เฉพาะ Omise Public Key (สำหรับ tokenization)
- ลบ `OMISE_SECRET_KEY` ออกจาก `.env` ฝั่ง client

### ลำดับงานย่อย

1. แก้ `getUserRole()` + `currentUserRole` getter
2. แก้ profile auto-creation logic — ลบ role จาก metadata
3. เพิ่ม `_ensureAdmin()` guard ใน `AdminService`
4. สร้าง Edge Function สำหรับ FCM notification sending
5. ปรับ `NotificationSender` ให้เรียก Edge Function แทน direct FCM API
6. ปรับ `OmiseService` ให้ใช้ Edge Function สำหรับ charge operations
7. ลบ secret keys จาก `.env` ฝั่ง client

### ไฟล์ที่ต้องแก้ไข

- `lib/common/services/auth_service.dart` — แก้ getUserRole, role cache, metadata validation
- `lib/common/services/admin_service.dart` — เพิ่ม role guard ทุก method
- `lib/common/services/notification_sender.dart` — ย้ายไปเรียก Edge Function
- `lib/common/services/omise_service.dart` — ย้าย secret key operations ไป Edge Function
- `lib/common/config/env_config.dart` — ลบ Firebase SA + Omise Secret Key
- `lib/common/widgets/auth_gate.dart` — จัดการ error state จาก getUserRole
- `supabase/functions/` — สร้าง Edge Functions ใหม่ (send-fcm-notification, payment operations)

### Dependencies
- **Phase 1 ควรเสร็จก่อน** (Edge Function infrastructure พร้อม)
- 3D (ย้าย secret keys) สามารถทำคู่ขนานกับ Phase 2 ได้

---

## Phase 4: Booking Flow & State Machine Fixes

### ประเด็นที่ปิด (6 รายการ)

| # | ระดับ | ประเด็น | อ้างอิง audit |
|---|-------|---------|---------------|
| 1 | Critical | `updateBookingStatus()` ไม่มี authorization check | §9.1 |
| 2 | Critical | `cancelBooking()` ไม่มี authorization check | §9.2 |
| 3 | High | Duplicate ride surcharge calculation — copy-paste ซ้ำ 2 ครั้ง | §9.3 |
| 4 | High | `...updates` spread ซ้ำ 2 ครั้งใน acceptBooking | §9.4 |
| 5 | High | `getPendingBookings()` แสดง booking ที่ยังไม่พร้อมให้คนขับ | §9.5 |
| 6 | Medium | Payment service มี scaffold/mocked behavior ปะปน production | §2.7 |

### 4A) Authorization Check สำหรับ Booking Status Updates

- `updateBookingStatus()`: ตรวจว่า caller เป็น driver/customer/merchant ที่เกี่ยวข้องกับ booking นี้
- กำหนด **status transition matrix** — role ไหนเปลี่ยนจาก status ไหนไป status ไหนได้:
  - **customer**: `pending → cancelled`
  - **merchant**: `pending_merchant → preparing → ready_for_pickup` | `cancelled`
  - **driver**: `accepted → arrived → in_transit → completed`
  - **admin**: ทุก transition (ผ่าน admin path เท่านั้น)
- ถ้า transition ไม่ถูกต้อง → throw error ทันที

### 4B) Authorization Check สำหรับ Cancel Booking

- ตรวจ ownership: `customer_id = current user` (สำหรับ customer cancel)
- ตรวจ current status: อนุญาต cancel เฉพาะ status ที่ยังไม่เริ่มงาน (`pending`, `pending_merchant`)
- หลังคนขับรับงานแล้ว → ต้องผ่าน flow cancellation ที่มี penalty/reason

### 4C) ลบ Duplicate Code

- ลบบล็อก ride surcharge calculation ที่ซ้ำ (เก็บเฉพาะบล็อกแรก บรรทัด 673-693)
- ลบ `...updates` ที่ spread ซ้ำ (เก็บเฉพาะครั้งเดียว)

### 4D) แก้ `getPendingBookings()` Filter

- ลบ `pending_merchant` และ `preparing` ออกจาก status filter สำหรับคนขับ
- คนขับควรเห็นเฉพาะ: `pending` (ride/parcel) และ `ready_for_pickup` (food ที่ร้านเตรียมเสร็จแล้ว)

### ลำดับงานย่อย

1. นิยาม status transition matrix (role × current_status → allowed_next_statuses)
2. สร้าง validation helper `_validateStatusTransition(booking, newStatus, callerRole, callerId)`
3. เพิ่ม authorization check ใน `updateBookingStatus()` + `cancelBooking()`
4. ลบ duplicate surcharge block + duplicate spread
5. แก้ `getPendingBookings()` filter
6. ทดสอบ booking lifecycle ทุก service type

### ไฟล์ที่ต้องแก้ไข

- `lib/common/services/booking_service.dart` — ทุกจุดที่ระบุ
- `lib/common/models/booking_status.dart` — เพิ่ม transition matrix (ถ้าเหมาะสม)

### Dependencies
- **Phase 2 ควรเสร็จก่อน** (complete_booking RPC ถูกสร้างแล้ว → Phase 4 เพิ่ม authorization layer ด้านบน)

---

## Phase 5: Coupon, Notification & Realtime Fixes

### ประเด็นที่ปิด (9 รายการ)

| # | ระดับ | ประเด็น | อ้างอิง audit |
|---|-------|---------|---------------|
| 1 | High | Coupon merchant validation ไม่ถูกต้องเมื่อ merchantId เป็น null | §11.1 |
| 2 | High | `recordUsage()` fail = used_count ไม่เพิ่ม = ใช้เกิน limit | §11.2 |
| 3 | High | `_getUserUsageCount()` return 0 เมื่อ error = bypass per-user limit | §11.3 |
| 4 | High | Notification ส่งไปคนขับทุกคน ไม่ filter proximity | §13.1 |
| 5 | High | FCM token ไม่ถูก invalidate เมื่อ logout | §13.2 |
| 6 | High | Service Account credentials สร้างใหม่ทุกครั้งที่ส่ง notification | §13.3 |
| 7 | High | `getAvailableDriversNearby()` ดึงทุก row + เรียก Google API ทีละคน | §14.1 |
| 8 | High | Google Maps API Key ไม่มี restriction | §14.2 |
| 9 | High | RealtimeService อาจ leak channels | §14.3 |

### 5A) Coupon Fixes

- **Merchant validation**: เปลี่ยนเงื่อนไข — ถ้า `coupon.merchantId != null` แล้ว `merchantId` parameter **ต้อง** ตรงกัน (ไม่อนุญาต null merchantId ผ่าน)
- **Usage count**: เปลี่ยน `recordUsage()` จาก non-critical เป็น **critical** — ถ้า fail → throw error → ไม่อนุญาตให้ booking ดำเนินต่อ (หรือใช้ retry mechanism)
- **User usage count**: เปลี่ยนจาก return 0 เมื่อ error → throw error → coupon validation fail-safe (ปฏิเสธเมื่อไม่แน่ใจ)

### 5B) Notification Fixes

- **Proximity filter**: แก้ `_notifyDriversAboutNewRide()` ให้ query จาก `driver_locations` แทน `profiles` → filter `is_online=true`, `is_available=true` → ใช้ Haversine distance ใน SQL หรือ PostGIS `ST_DWithin` → ส่งเฉพาะคนขับในรัศมี
- **FCM token cleanup**: เพิ่มการลบ `fcm_token` จาก `profiles` ใน `signOut()` method
- **Credential caching**: cache `clientViaServiceAccount()` result → reuse จนกว่า token หมดอายุ (หรือย้ายไป Edge Function ตาม Phase 3D ซึ่งจะแก้ปัญหานี้โดยอัตโนมัติ)

### 5C) Realtime & Location Fixes

- **Nearby drivers**: ย้ายการคำนวณระยะทางไป Postgres function (Haversine SQL) → ไม่ต้องดึงทุก row + ไม่ต้องเรียก Google API ทีละคน
- **Google Maps API Key**: ตั้ง restriction ใน Google Cloud Console (จำกัด API types + Android/iOS app restriction) — เป็น manual step
- **Channel leak**: เพิ่ม debounce/guard ใน `subscribeToDriverLocation()` — ถ้ากำลัง unsubscribe อยู่ → รอจน unsubscribe เสร็จก่อนสร้างใหม่

### ลำดับงานย่อย

1. แก้ coupon validation logic (3 จุด)
2. แก้ notification sending — proximity filter + FCM token cleanup
3. สร้าง Postgres function สำหรับ nearby driver query (Haversine)
4. ปรับ `RealtimeService` — channel dispose guard
5. ตั้ง Google Maps API Key restrictions (manual)

### ไฟล์ที่ต้องแก้ไข

- `lib/common/services/coupon_service.dart` — merchant validation, usage count, error handling
- `lib/common/services/booking_service.dart` — notification proximity filter
- `lib/common/services/auth_service.dart` — FCM token cleanup on signOut
- `lib/common/services/notification_sender.dart` — credential caching
- `lib/common/services/realtime_service.dart` — nearby driver query + channel guard
- `supabase/migrations/` — Postgres function สำหรับ nearby drivers

### Dependencies
- **Phase 3 ควรเสร็จก่อน** (ถ้าย้าย FCM ไป Edge Function แล้ว → credential caching ไม่จำเป็น)
- 5A (coupon) สามารถทำคู่ขนานกับ Phase อื่นได้

---

## Phase 6: Data Validation & Input Sanitization

### ประเด็นที่ปิด (4 รายการ)

| # | ระดับ | ประเด็น | อ้างอิง audit |
|---|-------|---------|---------------|
| 1 | High | `createRideBooking()` รับ dynamic type สำหรับ address | §15.1 |
| 2 | Medium | Coupon code ไม่มี length/format validation | §15.2 |
| 3 | Medium | Withdrawal amount ไม่มี min/max validation | §15.3 |
| 4 | Medium | Edge function auth fallback ใช้ service role key | §16.1 |

### แนวทางแก้ไข

- **Address type safety**: เปลี่ยน `pickupAddress` / `destinationAddress` จาก `dynamic` เป็น `String` → force `.toString()` ที่ caller
- **Coupon code validation**: เพิ่ม regex check (alphanumeric + max 20 chars) ก่อน query DB
- **Withdrawal validation**: เพิ่ม minimum amount (เช่น 100 บาท) + maximum amount (เช่น 50,000 บาท) — ค่าจาก `system_config`
- **Edge function auth**: ตั้ง `SCHEDULER_SECRET` เป็น dedicated secret แยกจาก service role key

### ไฟล์ที่ต้องแก้ไข

- `lib/common/services/booking_service.dart` — address type
- `lib/common/services/coupon_service.dart` — code validation
- `lib/common/services/withdrawal_service.dart` — amount validation
- `supabase/functions/process-scheduled-orders/` — auth config

### Dependencies
- ไม่มี dependency — **ทำคู่ขนานกับ Phase อื่นได้**

---

## Phase 7: Code Quality & Technical Debt Cleanup

### ประเด็นที่ปิด (5+ รายการ)

| # | ระดับ | ประเด็น | อ้างอิง |
|---|-------|---------|---------|
| 1 | Medium | `...updates` spread ซ้ำใน acceptBooking | audit §9.4 |
| 2 | Medium | Error handling ไม่สม่ำเสมอ — mix alert/toast/silent | audit §4.4 |
| 3 | Medium | Edge function ไม่มี rate limiting | audit §16.2 |
| 4 | Debt | Admin web `app.js` ~8,200 บรรทัดรวมทุก concern | research §12.4 |
| 5 | Debt | ไม่มี canonical schema documentation / ERD | research §12.1 |
| 6 | Debt | ไม่มี test suite เชิงธุรกิจที่ครอบคลุม | research §12.5 |
| 7 | Debt | ไม่มี CI/CD pipeline + migration runbook | research §12.2, §12.6 |

### แนวทางแก้ไข (ระยะยาว)

- **Admin web modularization**: แยก `app.js` เป็นโมดูลย่อยตาม feature (dashboard.js, orders.js, drivers.js ฯลฯ) — ใช้ ES modules
- **Error handling standardization**: กำหนด pattern เดียว (Flutter: throw + catch at UI layer, Admin: showToast + console.error)
- **Rate limiting**: เพิ่ม rate limit ใน Edge Functions (ใช้ Deno KV หรือ simple in-memory counter)
- **Schema documentation**: สร้าง ERD จาก migrations ที่มี
- **Test coverage**: เพิ่ม unit tests สำหรับ financial flows (wallet, commission, coupon)
- **CI/CD**: สร้าง pipeline สำหรับ Flutter build + Supabase migration

### Dependencies
- **ทำหลังสุด** — เป็น improvement ไม่ใช่ critical fix

---

## ✅ Testing Strategy (ครอบคลุมทุก Phase)

### T1) Security Validation (Phase 1)

1. ยืนยันว่า admin-web ไม่มี `SUPABASE_SERVICE_KEY` ใน asset/config ฝั่ง client
2. ทดสอบว่า privileged actions เรียกได้ผ่าน Edge Function เท่านั้น
3. ทดสอบ role enforcement: non-admin เรียก admin endpoint → ถูกปฏิเสธ
4. ทดสอบ RLS regression: read/write จาก anon/authenticated ต้องไม่เกินสิทธิ์
5. ทดสอบ XSS: inject `<script>alert(1)</script>` ในชื่อผู้ใช้ → ต้องไม่ execute

### T2) Financial Consistency (Phase 2)

1. **Double-click test**: กด approve ซ้ำ → ผลการเงินเกิดครั้งเดียว
2. **Parallel test**: 2 admin กด approve พร้อมกัน → 1 สำเร็จ, 1 ได้ `already_processed`
3. **Partial failure test**: จำลอง DB error กลางทาง → ไม่มี partial commit
4. **Ledger reconciliation**: `SUM(wallet_transactions.amount) = wallets.balance` ทุก wallet
5. **Booking completion**: settlement fail → booking ไม่เข้า `completed`

### T3) Auth & Authorization (Phase 3)

1. `getUserRole()` เมื่อ network error → ไม่ได้ role `customer` โดยอัตโนมัติ
2. Signup ด้วย `metadata.role = 'admin'` → profile ไม่ได้เป็น admin
3. Non-admin เรียก `AdminService.approveDriver()` → ถูกปฏิเสธ
4. Decompile APK → ไม่พบ Firebase SA key / Omise Secret Key

### T4) Booking Flow (Phase 4)

1. Customer A พยายาม cancel booking ของ Customer B → ถูกปฏิเสธ
2. Driver พยายามเปลี่ยน status จาก `pending` → `completed` ตรงๆ → ถูกปฏิเสธ
3. คนขับ 2 คนกดรับงานเดียวกัน → 1 สำเร็จ, 1 ได้ error "งานถูกรับไปแล้ว"
4. คนขับไม่เห็น booking ที่ status = `pending_merchant` / `preparing`

### T5) Coupon & Notification (Phase 5)

1. Coupon ของร้าน A ใช้กับร้าน B → ถูกปฏิเสธ
2. Coupon usage_limit = 5, ใช้ครบ 5 ครั้ง → ครั้งที่ 6 ถูกปฏิเสธ
3. Notification ส่งเฉพาะคนขับในรัศมี (ไม่ broadcast ทุกคน)
4. หลัง logout → ไม่ได้รับ push notification

### T6) End-to-End Regression

1. Top-up: pending → approve → wallet updated → request = completed
2. Withdrawal: pending → approve/reject → wallet/ledger/state ถูกต้อง
3. Ride completion: booking status + driver earnings + commission consistent
4. Food completion: booking status + GP split + driver earnings consistent
5. Admin dashboard: ยอดทางการเงินคำนวณถูกต้องหลังเปลี่ยน model

---

## 📊 Dependency Graph (ลำดับการทำงาน)

```
Phase 1 (Security Foundation)          Phase 6 (Data Validation)
    │                                       │ [คู่ขนานได้]
    ▼                                       │
Phase 2 (Financial Atomicity) ◄─────────────┘
    │
    ▼
Phase 3 (Auth Hardening)
    │
    ├──────────────────────┐
    ▼                      ▼
Phase 4 (Booking Flow)   Phase 5 (Coupon/Notification) [คู่ขนานได้]
    │                      │
    └──────────┬───────────┘
               ▼
Phase 7 (Code Quality & Debt)
```

**Critical path**: Phase 1 → 2 → 3 → 4
**คู่ขนานได้**: Phase 5 กับ Phase 4, Phase 6 กับ Phase 1-2
**ทำหลังสุด**: Phase 7

---

## 📋 Release Gates (เกณฑ์ปล่อยงานแต่ละ Phase)

### Migration Status Update — 2026-05-08
- [x] ผู้ใช้ยืนยันว่ารัน Supabase migrations ทั้งหมดด้วยตัวเองครบแล้ว
- [x] ใช้สถานะนี้เป็น baseline ล่าสุดสำหรับการวิเคราะห์ notification bug รอบถัดไป
- [ ] ยังต้องตรวจ production secrets/config ของ Edge Functions แยกต่างหาก เช่น `FIREBASE_SERVICE_ACCOUNT_JSON`, `FIREBASE_PROJECT_ID`, `SUPABASE_SERVICE_ROLE_KEY`

### Notification Bug Analysis — 2026-05-08
- [x] ร้านค้าไม่ได้รับ push เมื่อมี food order ใหม่: เพิ่ม merchant push ใน `createFoodBooking()` ด้วย `merchant.order.created` + legacy `merchant_new_order`
- [x] คนขับไม่ได้รับ push สำหรับงานใหม่ที่ยังไม่ assigned: ปรับ `send-fcm-notification` ให้ยอมรับ persisted `driver.job.available` candidate notification ที่ตรง `notification_id`/`booking_id`
- [x] Food order driver notification ถูกออกแบบให้ visible เฉพาะ `ready_for_pickup`: คง policy นี้ไว้ และ trigger notify driver หลัง flow food-ready
- [x] บาง merchant detail flow อัปเดต status เป็น `ready_for_pickup` โดยตรง: เปลี่ยนเป็น `MerchantOrderService.markFoodReady()` แล้วเรียก `notifyDriversAboutNewBooking()`
- [x] Review blocker: เพิ่ม migration `20260508120000_fix_food_ready_driver_notifications.sql` เพื่อให้ merchant caller เรียก `notify_driver_visible_job` ได้เฉพาะ food booking และให้ `mark_food_ready_guarded` เปลี่ยน unassigned food order เป็น `ready_for_pickup`
- [x] Code review รอบสองผ่านสำหรับ High findings เดิม
- [ ] Flutter targeted tests ยัง timeout ต้องตรวจ toolchain เพิ่ม; node smoke tests ผ่าน 6/6 และ `dart analyze` เฉพาะไฟล์ที่แก้ exit 0
- [ ] ยังต้อง verify migration apply + Edge Function/FCM delivery จริงใน Supabase runtime
- [x] Version bump ก่อน build/commit: `1.1.7+49`
- [x] Release APK build ผ่าน: `build/app/outputs/flutter-apk/app-release.apk`
- [x] Release AAB build ผ่าน: `build/app/outputs/bundle/release/app-release.aab`

### Phase 1 Release Gate
- [x] ไม่มี service role key บน browser/admin assets ✅ — ลบ `SUPABASE_SERVICE_KEY` + `supabaseAdmin` ออกจาก `app.js`, `config.js`, `config.example.js`
- [x] Privileged write ทั้งหมดผ่าน Edge Function ✅ — 40+ direct DB writes ย้ายไป `callAdminAction()` → `admin-actions` Edge Function
- [x] XSS sanitization pass ครบทุก `innerHTML` interpolation ✅ — `escapeHtml()` ครอบคลุม full_name, phone, email, address, bank, reason, description ทุกจุด
- [x] RLS policies ครอบคลุมตารางหลักทั้งหมด ✅ — migration `20260305_rls_hardening_phase1.sql` (wallets, wallet_transactions, bookings, withdrawal_requests, coupons, notifications, menu_items, support_tickets, etc.)
- [x] Duplicate functions ถูกลบ ✅ — ลบ duplicate `reportFilename`, `_csvCell`, `exportRowsToCsv`, `exportRowsToExcel`, `renderMiniBarChart`, `exportAccountDeletionsCsv/Excel`

### Phase 2 Release Gate
- [x] Wallet operations ทั้งหมดผ่าน RPC (ไม่มี read-then-write) ✅ — `wallet_deduct`, `wallet_topup`, `wallet_adjust` RPC functions + Flutter WalletService ใช้ RPC
- [x] Idempotency guards ✅ — `approve_topup_request`, `reject_topup_request`, `approve_withdrawal_request`, `reject_withdrawal_request` ตรวจ status=pending ก่อน
- [x] Booking completion atomic (settlement fail → ไม่ completed) ✅ — `complete_booking` RPC: deduct first, update status only on success
- [x] Optimistic concurrency for job assignment ✅ — `accept_booking` RPC: atomic claim with `WHERE driver_id IS NULL AND status = expected`
- [x] Withdrawal service ใช้ atomic RPC ✅ — `withdrawal_service.dart` ใช้ `wallet_deduct` RPC แทน read-then-write

### Phase 3 Release Gate
- [x] `getUserRole()` error → throw (ไม่ default เป็น customer) ✅ — rethrow on error, throw on missing profile
- [x] Signup metadata role injection → ถูกปฏิเสธ ✅ — `const safeRole = 'customer'` ไม่อ่าน role จาก metadata
- [x] AdminService มี `_ensureAdmin()` role guard ✅ — เพิ่มใน `getDashboardStats()` + ใช้ได้ทุก method
- [x] FCM token ถูกลบเมื่อ logout ✅ — `signOut()` ลบ fcm_token จาก profiles
- [x] Role cache + clearRoleCache() on signOut ✅
- [x] `send-fcm-notification` Edge Function สร้างแล้ว ✅ — Firebase SA credentials อยู่ server-side เท่านั้น

### Phase 4 Release Gate
- [x] Booking status update มี authorization check ✅ — `updateBookingStatus()` ตรวจ customer/driver/merchant/admin
- [x] Cancel booking ตรวจ ownership + status ✅ — `cancelBooking()` ตรวจ isOwner + cancellableStatuses
- [x] ไม่มี duplicate code ใน surcharge calculation ✅ — ลบ duplicate ride surcharge block + duplicate `...updates` spread
- [x] คนขับเห็นเฉพาะ booking ที่พร้อมรับ ✅ — `getPendingBookings()` filter เป็น `pending,ready_for_pickup` (ไม่รวม pending_merchant, preparing)

### Phase 5 Release Gate
- [x] Coupon merchant validation ถูกต้อง ✅ — reject เมื่อ merchantId param เป็น null แต่ coupon ต้องการ specific merchant
- [x] Coupon usage recording เป็น critical (throw on failure) ✅ — `recordUsage()` rethrow แทน swallow error
- [x] `_getUserUsageCount()` throw on error ✅ — ไม่ return 0 ซึ่งจะ bypass per-user limit
- [x] FCM token ถูกลบเมื่อ logout ✅ — (ทำใน Phase 3)
- [x] Nearby driver query ใช้ SQL ✅ — `get_nearby_drivers` Postgres function (Haversine) ใน migration
- [x] RealtimeService channel leak guard ✅ — เพิ่ม `_isUnsubscribingDriver/Booking` flags

### Phase 6 Release Gate
- [x] Address type safety ✅ — `createRideBooking` เปลี่ยน `dynamic` → `Object?`
- [x] Coupon code length/format validation ✅ — ตรวจ max 20 chars + `[A-Z0-9_-]` regex
- [x] Withdrawal amount min/max validation ✅ — min ฿100, max ฿50,000
- [x] Edge function ใช้ dedicated secret (ไม่ fallback service role key) ✅ — `process-scheduled-orders` ลบ service key fallback

### Phase 7 Release Gate
- [x] Edge function rate limiting ✅ — `admin-actions` มี in-memory rate limiter (60 req/min per admin)
- [ ] Flutter build + admin web ทำงานปกติ (regression test ผ่าน) — **ต้องทดสอบ**
