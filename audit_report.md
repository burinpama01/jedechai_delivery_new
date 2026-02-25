# Audit Report — Jedechai Delivery Comprehensive Security & Bug Analysis

> **อัปเดตล่าสุด**: สแกน codebase ทั้งหมดอย่างละเอียด — Flutter (37 services, 15 models), Supabase (44 migrations, 2 Edge Functions), Admin Web (app.js ~8,200 บรรทัด)
> **ขอบเขต**: วิเคราะห์เชิงลึกทุกจุดเสี่ยง — Security vulnerabilities, Business logic bugs, Race conditions, Data integrity, XSS, Auth bypass, Privilege escalation
> **หมายเหตุ**: เอกสารนี้ **ยังไม่เสนอ implementation** — เป็นรายงานผลการตรวจสอบเท่านั้น

---

## 1) `admin-web/app.js` Architecture Risk

### ระดับวิกฤต (Critical)

1. **ใช้ Service Role Key บนฝั่ง Browser โดยตรง (Privileged client)**
   - หลักฐาน: `admin-web/app.js` ตั้งค่า `supabase = supabaseAdmin` และอธิบายชัดว่า bypass RLS (`app.js:163-165`) โดยอ่าน key จาก `window.JEDECHAI_CONFIG` (`app.js:7-10`, `app.js:158-164`)
   - ผลกระทบ:
     - ถ้า key รั่ว (ผ่าน source leak / devtools / hosting misconfig) จะกลายเป็น full database compromise ทันที
     - ทุกช่องโหว่ XSS ในหน้า admin จะยกระดับจาก “ขโมย session” เป็น “ขโมย service key + ทำลายข้อมูลทั้งระบบ”
   - ความเสี่ยงรวม: โครงสร้างนี้เป็น **single-point catastrophic failure**

2. **DOM Injection/XSS surface สูงมากจากการใช้ `innerHTML` + interpolate ข้อมูล DB แบบไม่ escape**
   - หลักฐาน: มีการ render ด้วย template string จำนวนมาก เช่น `container.innerHTML` (`app.js:280`), `dc.innerHTML` (`app.js:657`), โมดัล/ตารางอีกจำนวนมาก
   - มีการฝังค่าจาก DB ลง HTML โดยตรงในหลายจุด เช่น ชื่อผู้ใช้/เหตุผล/ที่อยู่/URL โดยไม่ sanitize (เช่นส่วน Orders/Users/Pending/Driver Detail)
   - ผลกระทบ:
     - Stored XSS จากข้อมูลโปรไฟล์/ข้อความที่ผู้ใช้กรอกได้
     - เมื่อรวมกับ service role client จะรุนแรงเป็น data-wide destructive action

### ระดับสูง (High)

3. **ไฟล์เดียวขนาดใหญ่มากและ tightly coupled สูง (`app.js` ~8k+ lines)**
   - ลักษณะปัญหา:
     - Auth, routing, data-access, rendering, business action, realtime subscription อยู่ไฟล์เดียว
     - state แบบ global จำนวนมากบน `window.*` (`app.js` กระจายหลายจุด เช่น `_btnProcessing`, `_allOrders`, `_autoDispatch*`, `_map*`, `_pending*`)
   - ผลกระทบ:
     - blast radius สูงมาก: แก้ส่วนหนึ่งแล้วกระทบส่วนอื่นง่าย
     - testability ต่ำ, regression risk สูง

4. **มี duplicate definitions / logic copy-paste ชัดเจน (สัญญาณ debt สะสม)**
   - `reportFilename` ถูกประกาศซ้ำ (`app.js:22-30`)
   - export helper บางฟังก์ชันถูกนิยามซ้ำในไฟล์เดียว (จากการ grep พบช่วงใกล้ `exportWithdrawalsCsv/Excel` ซ้ำ)
   - ผลกระทบ:
     - behavior ไม่แน่นอนเมื่อบำรุงรักษา (shadowing/override ตามลำดับ parse)
     - เพิ่มโอกาสแก้ไม่ครบทุกจุด

5. **Concurrency/UI refresh loop ซ้อนกันหลายชั้น เสี่ยง request storm และ race ใน UI state**
   - Pending page ใช้ทั้ง polling (`setInterval` ทุก 15s) + realtime subscription พร้อมกัน (`app.js:6179-6185`)
   - callback ไม่มีกลไก lock/debounce สำหรับ `_refreshPendingOrders()`
   - ผลกระทบ:
     - รีเฟรชซ้อนเมื่อ event ถี่ → query ซ้ำ, rendering กระตุก, stale overwrite

### ระดับกลาง (Medium)

6. **Inline event handlers (`onclick="..."`) จำนวนมาก**
   - เพิ่ม coupling ระหว่าง HTML string กับ global function names
   - refactor ยากและเสี่ยงเกิด dead-handler ตอนเปลี่ยนชื่อ function

7. **Error handling ไม่สม่ำเสมอ (mix alert/showToast/silent catch)**
   - บางจุด swallow error (`catch {}`), บางจุด alert, บางจุด toast
   - ทำให้ observability ฝั่ง admin ต่ำและ debug เสี่ยงหลุดเคส

---

## 2) Wallet & Payment Logic Flaws (Race conditions / loopholes)

### ระดับวิกฤต (Critical)

1. **Top-up/Withdrawal approval ไม่มี idempotency guard ใน query เงื่อนไข**
   - ตัวอย่าง:
     - `approveTopup()` เติม wallet ก่อน แล้วค่อย update `topup_requests` เป็น completed (`app.js:5730-5743`)
     - `approveWithdrawal()` update status completed โดย filter แค่ `id` (`app.js:2630-2640`)
     - `rejectWithdrawal()` คืนเงินก่อนแล้วค่อย update status rejected (`app.js:2654-2665`)
   - ไม่มีเงื่อนไข `.eq('status','pending')` ใน update ฝั่งสำคัญ
   - ผลกระทบ:
     - re-click / parallel admin action / network retry อาจทำให้เครดิตเข้า-ออกซ้ำ

2. **หลาย flow แยกเป็น multi-step write โดยไม่มี DB transaction/atomicity จริง**
   - Wallet service: insert transaction แล้ว update balance แยกคำสั่ง (`wallet_service.dart:267-281`, `341-353`, `384-395`)
   - Withdrawal service: insert withdrawal request, insert wallet tx, update wallet แยกกัน (`withdrawal_service.dart:41-70`)
   - ผลกระทบ:
     - partial commit ง่ายมากเมื่อคำสั่งหลังล้มเหลว
     - ledger (wallet_transactions) กับ balance หลุด consistency

### ระดับสูง (High)

3. **Booking completion update สถานะก่อน แล้วค่อยทำหัก commission ทีหลัง**
   - `updateBookingStatus()` update `bookings.status` ก่อน (`booking_service.dart:427-430`) แล้วค่อยคำนวณและหักเงินเมื่อ `completed` (`435+`)
   - ถ้าหักเงิน fail จะได้ booking = completed แต่ commission ไม่ถูกตัด
   - เป็น business invariant break ชัดเจน

4. **Race condition ตอนรับงาน (double-assign)**
   - `acceptBooking()` อ่าน booking แล้ว update ด้วยเงื่อนไข `.eq('id', bookingId)` เท่านั้น (`booking_service.dart:729-735`)
   - ไม่มี optimistic condition เช่น `driver_id is null` + expected status
   - ฝั่ง admin pending assign ก็ update ด้วย `id` อย่างเดียว (`app.js:6524-6525`)
   - ผลกระทบ: คนขับสองคนกดรับพร้อมกัน มีโอกาส overwrite assignment

5. **Refund/adjustment flows เปิดทางยอดติดลบหรือยอดผิด state machine ได้**
   - `openDriverWalletAdjust()` อนุญาตยอดติดลบด้วย confirm (`app.js:7754-7756`)
   - `forceCancelOrder()` คืนเงินลูกค้าตาม `price` โดยตรง (`app.js:7797-7811`) โดยไม่เห็น guard ป้องกันคืนซ้ำในฝั่งนี้

### ระดับกลาง (Medium)

6. **Debt ใน BookingService: duplicate logic/duplicate spread**
   - บล็อกคำนวณ surcharge สำหรับ ride ถูกวางซ้ำ 2 ครั้ง (`booking_service.dart:673-715`)
   - update payload มี `...updates` ซ้ำ (`booking_service.dart:733-735`)
   - เป็นสัญญาณ copy-paste debt และเปิดช่อง regression เฉพาะทาง

7. **Payment service มีลักษณะ scaffold/mocked behavior ปะปน production path**
   - `processPayment()` ใช้ delayed + mock transaction id (`payment_service.dart:108-119`)
   - บ่งชี้ว่าชั้น payment orchestration ยังไม่ใช่ hardened flow เต็มรูปแบบ

---

## 3) Security & Supabase RLS

### ระดับวิกฤต (Critical)

1. **RLS bypass by design ใน Admin Web**
   - โค้ดเลือกใช้ service role client สำหรับทุก data operation (`app.js:163-165`)
   - สิทธิ์จึงขึ้นกับการเก็บ key บน frontend แทน policy-based least privilege

2. **นโยบาย RLS บางตารางเปิดกว้างมากด้วย `USING (true)`**
   - พบใน migration สำหรับ `topup_requests`: `Service role can manage all topup requests` ใช้ `FOR ALL USING (true) WITH CHECK (true)` (`20260301_consolidated_rls_and_feature_columns.sql:311-312`)
   - รูปแบบนี้ไม่ผูก role ใน policy expression เอง
   - หาก privilege role ระดับ `authenticated` ถูก grant กว้างเกินคาด จะเป็นช่องเข้าถึง data เกินสิทธิ์

### ระดับสูง (High)

3. **ไม่พบ policy ชัดเจนของ `wallets` / `wallet_transactions` / `bookings` ใน migration ที่สแกนได้**
   - จากการค้นในโฟลเดอร์ migration ไม่พบบรรทัด `ENABLE ROW LEVEL SECURITY` หรือ `CREATE POLICY` สำหรับสามตารางนี้โดยตรง
   - ความเสี่ยง:
     - blind spot ด้าน access control จริงใน production schema
     - อาจพึ่งพา migration เก่าที่กระจัดกระจาย / ไม่ canonical

4. **ช่องโหว่จาก Stored XSS + Service key exposure เป็น attack chain เดียวกัน**
   - ถ้ามี XSS ใน admin-web attacker สามารถเรียก `supabase` client ที่เป็น service role แล้ว mutate table ได้กว้างมาก

---

## 4) Error Handling & Edge Cases

### ระดับสูง (High)

1. **Edge Function partial failure handling ยังไม่ atomic**
   - `process-scheduled-orders` ทำงานเป็นลูป insert notification หลายรายการ แล้วค่อย mark field (`scheduled_reminder_sent_at` / `scheduled_release_processed_at`) ทีหลัง
   - ถ้า insert บางส่วนสำเร็จแต่ mark ล้มเหลว อาจเกิด duplicate notification ในรอบถัดไป
   - ลักษณะนี้เป็น at-least-once semantics โดยไม่มี dedup guard เชิง unique key

2. **ธุรกรรมการเงินจำนวนมากไม่มี compensation strategy เมื่อ fail กลางทาง**
   - เห็น pattern "ทำ step A สำเร็จแล้ว step B fail" แต่ไม่มี rollback orchestration
   - เสี่ยง ledger mismatch, status mismatch, และ reconciliation ยาก

3. **Offline/unstable network behavior ส่วนใหญ่เป็น fail-open/fail-silent ระดับ UX**
   - หลาย service คืน `false`/`null` เมื่อ error โดยไม่ preserve intent queue หรือ retry policy
   - ฝั่ง admin หลาย action จบด้วย alert/toast แต่ไม่มี retry contract ที่ deterministic

### ระดับกลาง (Medium)

4. **Non-uniform error channel ทำให้ incident tracing ยาก**
   - mix ทั้ง `showToast`, `alert`, `console.error`, และ silent catch
   - ส่งผลให้การ monitor เหตุผิดปกติใน production ไม่สม่ำเสมอ

---

## 5) สรุปภาพรวมความเสี่ยง (Executive Risk Summary)

- ความเสี่ยงสูงสุดของระบบตอนนี้ไม่ได้อยู่ที่ business formula อย่างเดียว แต่เป็นการผสมกันของ:
  1) **Privileged frontend (service key in browser)**,
  2) **XSS attack surface สูงจาก innerHTML interpolation**,
  3) **การเงินหลายขั้นตอนที่ไม่ atomic + ไม่มี idempotency guard**,
  4) **Blind spot ของ RLS canonical coverage สำหรับตารางแกนกลาง (wallets/wallet_transactions/bookings)**

- ในเชิง technical debt:
  - `admin-web/app.js` อยู่ในสถานะ monolith ที่ coupling สูง, duplicate logic มีจริง, และ maintenance risk เพิ่มแบบไม่เชิงเส้น
  - business-critical flows (booking completion, top-up/withdrawal approve/reject) มีช่องให้เกิด race/partial-commit ที่ส่งผลต่อยอดเงินจริงได้

---

## 6) บัญชีรายการประเด็น (Checklist Snapshot)

- [Critical] Service role key ใช้บน browser โดยตรง (`app.js:163-165`)
- [Critical] XSS surface สูงจาก `innerHTML` + unescaped interpolation หลายจุด
- [Critical] Top-up/withdrawal ไม่มี idempotency guard ที่ระดับ query condition
- [High] Booking completion commit status ก่อน financial deduction
- [High] Driver assignment race (accept/assign by id only)
- [High] RLS policy pattern `USING (true)` ในตารางสำคัญบางตัว
- [High] ไม่พบ canonical RLS policy ครบสำหรับ wallets/wallet_transactions/bookings ใน migration ที่สแกน
- [Medium] Duplicate logic/duplicate definitions ใน app.js และ booking service
- [Medium] Error handling ไม่สม่ำเสมอ, observability ต่ำ

---

## 7) ขอบเขตที่ยังเป็น Blind Spot (จาก audit รอบนี้)

1. ไม่สามารถยืนยัน privilege grants ระดับ role (`anon/authenticated/service_role`) ได้จาก migration เพียงอย่างเดียว จึงยังต้องถือว่าเป็นความเสี่ยงเชิง configuration
2. ไม่พบ runbook reconciliation ทางการเงิน (wallet ledger vs balance) ใน repo
3. ไม่พบ contract test ที่ยืนยัน idempotency ของ top-up/withdrawal/booking completion ในระดับ end-to-end

---

## 8) Authentication & Authorization Bugs (Flutter App)

### ระดับวิกฤต (Critical)

1. **`getUserRole()` default เป็น `'customer'` ในทุกกรณี error — เปิดช่อง role confusion**
   - ไฟล์: `auth_service.dart:261-328`
   - ปัญหา: เมื่อ network timeout, profile ไม่พบ, หรือ error ใดๆ → return `'customer'` เสมอ
   - ผลกระทบ: ถ้า admin/driver/merchant ประสบปัญหา network ชั่วคราว อาจถูก route ไปหน้า customer แทน → เห็นข้อมูลผิด role, สร้าง booking ในฐานะ customer ได้
   - ที่แย่กว่า: `currentUserRole` getter (sync) return `'customer'` hardcode เสมอ (`auth_service.dart:335-338`) — ไม่มี cache จริง

2. **Profile auto-creation จาก `userMetadata` ไม่มี validation ของ role**
   - ไฟล์: `auth_service.dart:287-309`
   - ปัญหา: เมื่อ profile ไม่พบ → สร้างจาก `user.userMetadata` โดยตรง รวมถึง `role` field
   - ผลกระทบ: ถ้า attacker สามารถ set `userMetadata.role = 'admin'` ตอน signup (ผ่าน Supabase Auth API โดยตรง) → จะได้ profile เป็น admin โดยอัตโนมัติ
   - หมายเหตุ: Supabase Auth อนุญาตให้ client ส่ง `data` (metadata) ตอน signup ได้ → ต้องมี server-side validation

3. **Admin operations ใน Flutter ไม่มี role check ก่อนทำงาน**
   - ไฟล์: `admin_service.dart` ทุก method (approveDriver, rejectDriver, approveWithdrawal ฯลฯ)
   - ปัญหา: ตรวจแค่ `AuthService.userId != null` แต่ไม่ตรวจว่า user เป็น admin จริงหรือไม่
   - ผลกระทบ: ถ้า RLS ไม่ครอบคลุม → user ที่ไม่ใช่ admin สามารถเรียก method เหล่านี้ได้
   - มี `isCurrentUserAdmin()` method แต่ไม่ถูกเรียกใช้ใน method อื่นเลย (`admin_service.dart:727-743`)

### ระดับสูง (High)

4. **Firebase Service Account Private Key อยู่ใน `.env` ฝั่ง client**
   - ไฟล์: `env_config.dart:26-27`, `notification_sender.dart:9-10`
   - ปัญหา: Firebase Service Account credentials (รวม private key) ถูกโหลดจาก `.env` ใน Flutter app → ถูก bundle ลง APK/IPA
   - ผลกระทบ: ใครก็ตามที่ decompile APK จะได้ Firebase Service Account key → สามารถส่ง FCM notification ปลอมไปหา user ทุกคนในระบบ, อ่าน/เขียน Firebase resources ตาม scope ที่ key มี

5. **Omise Secret Key อยู่ใน client-side `.env`**
   - ไฟล์: `env_config.dart:50`, `omise_service.dart` (ใช้ Secret Key สำหรับ createCharge)
   - ปัญหา: Omise Secret Key ถูกใช้ใน Flutter app โดยตรง → ถูก bundle ลง APK
   - ผลกระทบ: attacker สามารถสร้าง charge, ดูข้อมูลการชำระเงิน, refund ได้โดยไม่ต้องผ่าน app

---

## 9) Booking Flow Bugs

### ระดับวิกฤต (Critical)

1. **`updateBookingStatus()` ไม่มี authorization check — ใครก็เปลี่ยนสถานะได้**
   - ไฟล์: `booking_service.dart:417-430`
   - ปัญหา: รับ `bookingId` + `newStatus` แล้ว update ทันที ไม่ตรวจว่า:
     - caller เป็น driver/customer/merchant ที่เกี่ยวข้องกับ booking นี้หรือไม่
     - status transition ถูกต้องตาม state machine หรือไม่ (เช่น จาก `pending` ไป `completed` ตรงๆ)
   - ผลกระทบ: ถ้า RLS ไม่ block → user ใดก็ได้สามารถ mark booking เป็น `completed` เพื่อ trigger commission deduction ของคนอื่น

2. **`cancelBooking()` ไม่มี authorization check เลย**
   - ไฟล์: `booking_service.dart:549-553`
   - ปัญหา: รับ `bookingId` แล้ว update เป็น `cancelled` ทันที ไม่ตรวจ ownership หรือ current status
   - ผลกระทบ: user ใดก็ได้สามารถยกเลิก booking ของคนอื่น

### ระดับสูง (High)

3. **Duplicate ride surcharge calculation — คำนวณซ้ำ 2 ครั้ง**
   - ไฟล์: `booking_service.dart:673-715`
   - ปัญหา: บล็อกคำนวณ far pickup surcharge สำหรับ ride ถูก copy-paste ซ้ำ 2 ครั้งติดกัน (บรรทัด 673-693 และ 695-715 เป็นโค้ดเหมือนกันทุกประการ)
   - ผลกระทบ: surcharge ถูกคำนวณ 2 ครั้ง → ราคาอาจถูกปรับเพิ่มซ้ำ (ถ้า updates map ถูก overwrite ก็อาจไม่มีผล แต่เป็น bug ที่ชัดเจน)

4. **`...updates` spread ซ้ำ 2 ครั้งใน acceptBooking**
   - ไฟล์: `booking_service.dart:733-734`
   - ปัญหา: `...updates, ...updates,` — spread object เดียวกัน 2 ครั้ง
   - ผลกระทบ: ไม่มีผลร้ายทันที (เพราะ key เดียวกัน overwrite) แต่เป็น code smell ที่บ่งชี้ copy-paste error

5. **`getPendingBookings()` ดึง booking ที่ไม่ควรแสดงให้คนขับ**
   - ไฟล์: `booking_service.dart:557-568`
   - ปัญหา: filter `driver_id IS NULL` + status `in (pending, pending_merchant, preparing, ready_for_pickup)` — แต่ `pending_merchant` และ `preparing` คือสถานะที่ร้านค้ายังไม่ได้ตอบรับ/กำลังเตรียม → คนขับไม่ควรเห็น
   - ผลกระทบ: คนขับเห็น booking ที่ยังไม่พร้อมให้รับ → กดรับแล้วอาจเกิดปัญหา flow

---

## 10) Wallet & Financial Race Conditions (เพิ่มเติม)

### ระดับวิกฤต (Critical)

1. **Read-then-write pattern ทุก wallet operation — ไม่มี atomic update**
   - ไฟล์: `wallet_service.dart:263-281` (deductFoodCommission), `wallet_service.dart:334-353` (deductCommission), `wallet_service.dart:374-395` (topUpWallet), `withdrawal_service.dart:50-70`, `admin_service.dart:528-538`, `admin_service.dart:605-616`
   - ปัญหา: ทุก operation ทำ `SELECT balance` → คำนวณ `newBalance` ใน app → `UPDATE balance = newBalance` — ไม่ใช้ `balance = balance - amount` หรือ DB function
   - ผลกระทบ: 2 operations พร้อมกัน (เช่น commission deduction + withdrawal) จะอ่าน balance เดิมเหมือนกัน → เขียนทับกัน → ยอดเงินผิด (lost update)
   - ตัวอย่าง: balance = 1000, deduct 100 + topup 500 พร้อมกัน → ทั้งคู่อ่าน 1000 → เขียน 900 และ 1500 → ผลลัพธ์สุดท้ายเป็น 900 หรือ 1500 แทนที่จะเป็น 1400

2. **Withdrawal: insert request ก่อน แล้วค่อยหักเงิน — partial failure = เงินไม่หัก**
   - ไฟล์: `withdrawal_service.dart:40-70`
   - ปัญหา: step 1 insert withdrawal_request สำเร็จ → step 2 หักเงินจาก wallet → ถ้า step 2 fail → มี withdrawal request status=pending แต่เงินไม่ถูกหัก
   - ผลกระทบ: admin เห็น pending withdrawal → approve → เงินถูกโอนออกจริง แต่ wallet ไม่ถูกหัก

3. **Wallet topup screen มี direct wallet update นอก WalletService**
   - ไฟล์: `wallet_topup_screen.dart:715-717`
   - ปัญหา: หน้า UI เรียก `Supabase.instance.client.from('wallets').update({'balance': wallet.balance - amount})` โดยตรง — bypass WalletService
   - ผลกระทบ: ไม่มี transaction record, ไม่มี validation, race condition เดียวกับข้อ 1

---

## 11) Coupon System Bugs

### ระดับสูง (High)

1. **Coupon validation ไม่ตรวจ merchant match อย่างถูกต้อง**
   - ไฟล์: `coupon_service.dart:62-65`
   - ปัญหา: ตรวจ `coupon.merchantId != null && merchantId != null && coupon.merchantId != merchantId` — แต่ถ้า `merchantId` parameter เป็น `null` (ไม่ส่งมา) → coupon ที่ผูกกับ merchant เฉพาะจะถูก validate ผ่านได้ทุกร้าน
   - ผลกระทบ: coupon ของร้าน A สามารถใช้กับร้าน B ได้ถ้า caller ไม่ส่ง merchantId

2. **`recordUsage()` เป็น non-critical — ถ้า fail จะไม่ increment `used_count`**
   - ไฟล์: `coupon_service.dart:117-120`
   - ปัญหา: comment บอกว่า "Non-critical — don't throw, booking already succeeded" → ถ้า RPC `increment_coupon_usage` fail → `used_count` ไม่เพิ่ม → coupon ถูกใช้เกิน limit ได้
   - ผลกระทบ: coupon ที่มี usage_limit = 100 อาจถูกใช้ 200 ครั้งถ้า increment fail บ่อย

3. **`_getUserUsageCount()` return 0 เมื่อ error — เปิดช่อง bypass per-user limit**
   - ไฟล์: `coupon_service.dart:124-136`
   - ปัญหา: ถ้า query fail → return 0 → coupon validation จะคิดว่า user ยังไม่เคยใช้ → ผ่าน per-user limit check
   - ผลกระทบ: user สามารถใช้ coupon ซ้ำเกิน per_user_limit ได้เมื่อ DB มีปัญหาชั่วคราว

---

## 12) Admin Web — XSS & Security Details (เพิ่มเติม)

### ระดับวิกฤต (Critical)

1. **Stored XSS ผ่าน user-controlled data ที่ render ด้วย innerHTML**
   - ไฟล์: `app.js` หลายจุด — dashboard, orders, drivers, merchants, users, withdrawals, map, pending_orders
   - ปัญหา: ข้อมูลจาก DB (ชื่อผู้ใช้, ที่อยู่, หมายเหตุ, เหตุผลปฏิเสธ, ชื่อร้าน) ถูก interpolate ลง template string แล้ว assign ให้ `innerHTML` โดยไม่ escape
   - ตัวอย่าง: ถ้า user ตั้งชื่อเป็น `<img src=x onerror=alert(document.cookie)>` → ทุกหน้าที่แสดงชื่อนี้จะ execute script
   - ผลกระทบ: เมื่อรวมกับ service role key ที่อยู่ใน browser → attacker สามารถ:
     - อ่าน/เขียน/ลบข้อมูลทุกตารางใน DB
     - สร้าง admin user ใหม่
     - แก้ไขยอดเงินใน wallet ทุกคน
     - ลบ booking/profile ทั้งระบบ

2. **`supabase.auth.admin.listUsers()` ถูกเรียกจาก browser**
   - ไฟล์: `app.js:556-572` (`fetchUserEmails()`)
   - ปัญหา: ใช้ service role client เรียก `auth.admin.listUsers()` เพื่อดึง email ทุก user → เป็น admin-level API ที่ไม่ควรเรียกจาก client
   - ผลกระทบ: ถ้า key รั่ว → attacker ได้ email ของ user ทุกคนในระบบ

3. **Error message interpolation เป็น XSS vector**
   - ไฟล์: `app.js:319` — `container.innerHTML = \`...\${e.message}...\``
   - ปัญหา: error message จาก Supabase อาจมี user input (เช่น ชื่อ column ที่ผิด) → ถูก render เป็น HTML
   - ผลกระทบ: reflected XSS ผ่าน crafted error

### ระดับสูง (High)

4. **Duplicate function declarations ทำให้ behavior ไม่แน่นอน**
   - ไฟล์: `app.js`
   - พบ duplicates:
     - `reportFilename()` ประกาศซ้ำ 2 ครั้ง (บรรทัด 22-25 และ 27-30)
     - `_csvCell()` ประกาศซ้ำ 2 ครั้ง (บรรทัด 327-330 และ 403-406)
     - `exportRowsToCsv()` ประกาศซ้ำ 2 ครั้ง (บรรทัด 332-346 และ 408-422)
     - `exportRowsToExcel()` ประกาศซ้ำ 2 ครั้ง (บรรทัด 348-373 และ 424-449)
     - `renderMiniBarChart()` ประกาศซ้ำ 2 ครั้ง (บรรทัด 375-400 และ 451-476)
     - `exportWithdrawalsCsv/Excel()` ประกาศซ้ำ 2 ครั้ง (บรรทัด 756-763 และ 788-795)
     - `exportDashboardCsv/Excel()` ประกาศซ้ำ 2 ครั้ง (บรรทัด 766-786 และ 798-818)
   - ผลกระทบ: JavaScript hoisting ทำให้ declaration สุดท้ายชนะ → ถ้าแก้ไข function แรกจะไม่มีผล → maintenance trap

---

## 13) Notification & FCM Bugs

### ระดับสูง (High)

1. **`_notifyDriversAboutNewRide()` ส่ง notification ไปคนขับทุกคน — ไม่ filter ตาม proximity/availability**
   - ไฟล์: `booking_service.dart:854-859`
   - ปัญหา: query `profiles` ที่ `role='driver'` + `fcm_token IS NOT NULL` → ส่งทุกคน ไม่ว่าจะ online/offline, available/busy, ใกล้/ไกล
   - ผลกระทบ: คนขับที่อยู่ไกล 500 กม. ก็ได้รับ notification → spam, battery drain, poor UX

2. **FCM token ไม่ถูก invalidate เมื่อ user logout**
   - ไฟล์: `auth_service.dart:194-207` (signOut)
   - ปัญหา: `signOut()` เรียกแค่ `client.auth.signOut()` — ไม่ลบ `fcm_token` จาก `profiles`
   - ผลกระทบ: หลัง logout user ยังได้รับ push notification → privacy issue, notification ไปถึงคนผิด (ถ้า device ถูกขายต่อ)

3. **Service Account credentials ถูกสร้างใหม่ทุกครั้งที่ส่ง notification**
   - ไฟล์: `notification_sender.dart:78-79`
   - ปัญหา: `clientViaServiceAccount()` ถูกเรียกทุกครั้งที่ส่ง notification → สร้าง OAuth token ใหม่ทุกครั้ง
   - ผลกระทบ: performance ช้า (ต้อง HTTP roundtrip ไป Google OAuth ทุกครั้ง), อาจถูก rate limit

---

## 14) Realtime & Location Service Bugs

### ระดับสูง (High)

1. **`getAvailableDriversNearby()` ดึงคนขับทุกคนก่อนแล้ว filter ใน app — ไม่ scale**
   - ไฟล์: `realtime_service.dart:201-221`
   - ปัญหา: `SELECT * FROM driver_locations WHERE is_online=true AND is_available=true` → ดึงทุก row → loop เรียก Google Directions API ทีละคน
   - ผลกระทบ: ถ้ามีคนขับ 1,000 คน online → ดึง 1,000 rows + เรียก Google API 1,000 ครั้ง → ช้ามาก + Google API cost สูง + อาจ exceed quota

2. **Google Maps API Key ถูกส่งใน URL โดยตรง — ไม่มี restriction**
   - ไฟล์: `realtime_service.dart:234-240`, `location_service.dart` (ทุก method)
   - ปัญหา: API key ถูกใช้ใน HTTP GET request → ปรากฏใน URL → ถ้า log ถูกเก็บ/รั่ว → key exposed
   - ผลกระทบ: ถ้า key ไม่มี restriction (HTTP referrer / IP / API type) → ใครก็ใช้ได้ → billing abuse

3. **RealtimeService ไม่มี dispose guard — อาจ leak channels**
   - ไฟล์: `realtime_service.dart:58-92`
   - ปัญหา: `subscribeToDriverLocation()` เรียก `_driverLocationChannel?.unsubscribe()` ก่อนสร้างใหม่ แต่ถ้า widget ถูก rebuild หลายครั้งเร็วๆ → channel เก่าอาจยังไม่ unsubscribe เสร็จก่อนที่จะสร้างใหม่
   - ผลกระทบ: memory leak, duplicate event handling

---

## 15) Data Validation & Input Sanitization Bugs

### ระดับสูง (High)

1. **`createRideBooking()` รับ `dynamic` type สำหรับ address — ไม่มี type safety**
   - ไฟล์: `booking_service.dart:270-271`
   - ปัญหา: `pickupAddress` และ `destinationAddress` เป็น `dynamic` → อาจเป็น String, Map, Object, หรืออะไรก็ได้
   - ผลกระทบ: ถ้าส่ง object ที่มี `toString()` ผิดปกติ → address ใน DB อาจเป็น `Instance of 'AddressPlacemark'` (มี guard แต่ไม่ครอบคลุมทุกกรณี)

2. **Coupon code ไม่มี length/format validation**
   - ไฟล์: `coupon_service.dart:30` — แค่ `trim().toUpperCase()`
   - ปัญหา: ไม่ตรวจ length, ไม่ตรวจ special characters
   - ผลกระทบ: สามารถสร้าง coupon code ที่ยาวมากหรือมี special characters ที่อาจทำให้ UI แตก

3. **Withdrawal amount ไม่มี minimum/maximum validation**
   - ไฟล์: `withdrawal_service.dart:20-77`
   - ปัญหา: ตรวจแค่ `balance < amount` — ไม่มี minimum (เช่น ถอนขั้นต่ำ 100 บาท) หรือ maximum
   - ผลกระทบ: user สามารถถอน 0.01 บาท ซ้ำๆ → สร้าง withdrawal request จำนวนมาก → spam admin

---

## 16) Edge Function Vulnerabilities

### ระดับกลาง (Medium)

1. **`process-scheduled-orders` authentication ใช้ header secret เทียบกับ env var**
   - ปัญหา: ถ้า `SCHEDULER_SECRET` ไม่ถูกตั้งค่า → fallback ใช้ `SUPABASE_SERVICE_ROLE_KEY` → ถ้า key รั่ว → ใครก็เรียก function ได้
   - ผลกระทบ: attacker สามารถ trigger scheduled order processing ซ้ำ → duplicate notifications

2. **`send-admin-email` ไม่มี rate limiting**
   - ปัญหา: ไม่มีการจำกัดจำนวน email ที่ส่งได้ต่อช่วงเวลา
   - ผลกระทบ: ถ้าถูกเรียกซ้ำ → spam email, Resend API cost สูง

---

## 17) สรุปภาพรวมความเสี่ยง (Updated Executive Risk Summary)

### จำนวนประเด็นตามระดับความรุนแรง

| ระดับ | จำนวน | หมวดหลัก |
|-------|--------|----------|
| **Critical** | 12 | Service key exposure, XSS+key chain, wallet race conditions, auth role confusion, booking auth bypass, wallet non-atomic ops |
| **High** | 18 | Secret keys in APK, duplicate logic, notification spam, coupon bypass, driver assignment race, RLS gaps, FCM token leak |
| **Medium** | 8 | Duplicate functions, error handling inconsistency, input validation, edge function auth |

### Top 5 ความเสี่ยงที่ต้องแก้ไขเร่งด่วนที่สุด

1. **Service Role Key บน Browser** — ถ้า key รั่ว = full database compromise ทันที
2. **Wallet Race Conditions (read-then-write)** — ยอดเงินผิดได้ทุกเมื่อที่มี concurrent operations
3. **XSS + Service Key Chain** — Stored XSS ใน admin web = attacker ได้ service key = game over
4. **Firebase/Omise Secret Keys ใน APK** — decompile APK = ได้ keys ทั้งหมด
5. **Booking status update ไม่มี auth check** — user ใดก็ได้สามารถเปลี่ยนสถานะ booking ของคนอื่น

### ความเสี่ยงเชิงธุรกิจ

- **การเงิน**: wallet balance อาจผิดพลาดจาก race condition → ยอดเงินจริงไม่ตรงกับ ledger → reconciliation ยาก → ความเชื่อมั่นของ driver/merchant ลดลง
- **ข้อมูลส่วนบุคคล**: XSS + service key → attacker เข้าถึงข้อมูลส่วนบุคคลทุกคนในระบบ (ชื่อ, เบอร์โทร, ที่อยู่, ข้อมูลธนาคาร)
- **ชื่อเสียง**: ถ้าเกิด data breach → ผลกระทบต่อ brand + ปัญหาทางกฎหมาย (PDPA)

---

## 18) บัญชีรายการประเด็นทั้งหมด (Full Checklist)

### Critical (ต้องแก้ทันที)
- [ ] Service role key ใช้บน browser โดยตรง (`app.js:163-165`)
- [ ] XSS surface สูงจาก `innerHTML` + unescaped interpolation หลายจุด
- [ ] Top-up/withdrawal ไม่มี idempotency guard
- [ ] Wallet operations ทั้งหมดเป็น read-then-write (ไม่ atomic)
- [ ] `getUserRole()` default เป็น customer ในทุกกรณี error
- [ ] Profile auto-creation จาก userMetadata ไม่ validate role
- [ ] `updateBookingStatus()` ไม่มี authorization check
- [ ] `cancelBooking()` ไม่มี authorization check
- [ ] Booking completion commit status ก่อน financial deduction
- [ ] Withdrawal partial failure = request สร้างแต่เงินไม่หัก
- [ ] Wallet topup screen มี direct wallet update นอก WalletService
- [ ] `auth.admin.listUsers()` ถูกเรียกจาก browser

### High (ต้องแก้เร็ว)
- [ ] Firebase Service Account Private Key ใน client `.env`
- [ ] Omise Secret Key ใน client `.env`
- [ ] Driver assignment race (accept by id only, no optimistic lock)
- [ ] RLS policy `USING (true)` ในตารางสำคัญ
- [ ] ไม่พบ canonical RLS สำหรับ wallets/wallet_transactions/bookings
- [ ] Duplicate ride surcharge calculation (copy-paste ซ้ำ 2 ครั้ง)
- [ ] `getPendingBookings()` แสดง booking ที่ยังไม่พร้อม
- [ ] Notification ส่งไปคนขับทุกคน ไม่ filter proximity
- [ ] FCM token ไม่ถูก invalidate เมื่อ logout
- [ ] Service Account credentials สร้างใหม่ทุกครั้งที่ส่ง notification
- [ ] `getAvailableDriversNearby()` ดึงทุก row + เรียก Google API ทีละคน
- [ ] Google Maps API Key ไม่มี restriction
- [ ] Coupon merchant validation ไม่ถูกต้องเมื่อ merchantId เป็น null
- [ ] `recordUsage()` fail = used_count ไม่เพิ่ม = ใช้เกิน limit
- [ ] `_getUserUsageCount()` return 0 เมื่อ error = bypass per-user limit
- [ ] Admin operations ไม่มี role check ก่อนทำงาน
- [ ] Stored XSS + Service key = full DB compromise chain
- [ ] RealtimeService อาจ leak channels

### Medium (ควรแก้)
- [ ] Duplicate function declarations ใน app.js (7+ functions)
- [ ] `...updates` spread ซ้ำใน acceptBooking
- [ ] Error handling ไม่สม่ำเสมอ (mix alert/toast/silent)
- [ ] Address parameter เป็น dynamic type
- [ ] Coupon code ไม่มี length/format validation
- [ ] Withdrawal amount ไม่มี min/max validation
- [ ] Edge function auth fallback ใช้ service role key
- [ ] Edge function ไม่มี rate limiting
