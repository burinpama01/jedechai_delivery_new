# Web Credit Top-Up Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** สร้าง flow เติมเครดิตผ่านเว็บจาก landing page โดยบังคับให้ผู้ใช้ล็อกอินก่อน จึงจะส่งคำขอเติมเครดิตได้จริง และให้ admin ตรวจสอบ/อนุมัติก่อนเครดิตเข้ากระเป๋า

**Architecture:** หน้า landing ส่งผู้ใช้ไป `topup.html`; ถ้ายังไม่ล็อกอิน ให้ redirect ไปหน้า login ก่อน แล้วกลับมาหน้าเติมเครดิตหลัง login สำเร็จ. เฟสแรกใช้ manual PromptPay transfer + submit proof ผ่าน authenticated web page, บันทึกคำขอเข้า Supabase `topup_requests`, จากนั้น admin ใช้หน้าจอเดิมอนุมัติและเรียก wallet top-up RPC แบบ atomic. เฟสถัดไปค่อยเพิ่ม Omise PromptPay auto verification.

**Tech Stack:** Static HTML landing, Supabase Auth JS, Supabase Edge Function, Supabase Postgres/RLS/RPC, Flutter admin top-up screen, existing `WalletService`, existing top-up notification strings.

---

## Scope

แผนนี้อยู่ในโปรเจคที่ `docs/superpowers/plans/2026-05-13-web-credit-topup.md` และออกแบบสำหรับ CTA `เติมเครดิต` บน `landing-deploy/index.html` ที่ตอนนี้ยังเป็น `href="#"`.

ข้อกำหนดหลัก:
- ผู้ใช้ต้องล็อกอินก่อนเสมอ
- ไม่รับ top-up request แบบ anonymous/public form
- user id ต้องมาจาก Supabase session ไม่ใช่จาก input ที่ผู้ใช้พิมพ์เอง
- หน้าเว็บกรอกได้เฉพาะจำนวนเงิน, reference/slip, note
- backend ต้องตรวจ JWT และใช้ `auth.uid()` เป็นเจ้าของ request
- admin อนุมัติแล้วจึงเติมเครดิตเข้ากระเป๋า

เฟสแรกทำเฉพาะ flow ที่ปลอดภัยและตรวจสอบได้:
- ผู้ใช้ login ด้วย Supabase Auth
- เว็บแสดงยอด/ข้อมูลบัญชีจาก session
- เว็บแสดง QR/PromptPay instruction
- ผู้ใช้อัปโหลดสลิปหรือกรอก transfer reference
- ระบบสร้าง top-up request สถานะ `pending`
- admin ตรวจสอบ แล้วอนุมัติ/ปฏิเสธ
- เมื่ออนุมัติ ระบบเติม wallet/credit แบบ atomic และเก็บ transaction history

ยังไม่ทำ auto-credit ทันทีจากหน้าเว็บ จนกว่าจะมี payment webhook ที่เชื่อถือได้.

## Files

- Modify: `landing-deploy/index.html`
  - เปลี่ยน CTA `เติมเครดิต` จาก `href="#"` เป็น `href="topup.html"`
- Create: `landing-deploy/topup.html`
  - หน้าเติมเครดิตบนเว็บแบบ authenticated
  - ถ้าไม่มี session ให้แสดง login panel หรือ redirect ไป `login.html?redirect=topup.html`
  - form จำนวนเงิน, transfer reference, note, slip upload/slip URL
  - แสดงสถานะส่งคำขอสำเร็จ
- Create: `landing-deploy/login.html`
  - หน้า login สำหรับเว็บ top-up ถ้ายังไม่มีหน้า auth ที่ใช้ซ้ำได้
  - รองรับ email/password หรือ magic link ตาม Supabase Auth ที่โปรเจคเปิดใช้
- Create: `landing-deploy/assets/js/auth.js`
  - init Supabase client ด้วย anon key
  - get current session
  - login/logout
  - redirect กลับไป path ที่ส่งมาใน query `redirect`
- Create: `landing-deploy/assets/js/topup.js`
  - require Supabase session
  - validate amount/reference
  - call Supabase Edge Function พร้อม Authorization bearer token
  - disable submit ระหว่างส่ง
- Create: `supabase/functions/web-topup-request/index.ts`
  - รับ authenticated request จากเว็บ
  - validate JWT
  - ใช้ `user.id` จาก token เท่านั้น
  - validate amount/reference
  - insert top-up request สถานะ `pending`
  - ส่ง notification ให้ admin ถ้ามี service เดิมรองรับ
- Modify: `supabase/migrations/<new>_web_topup_requests.sql`
  - เพิ่ม field/policy เฉพาะที่ table เดิมยังไม่รองรับ authenticated web request
  - เพิ่ม indexes และ constraint กัน duplicate/idempotency
- Modify: `lib/apps/admin/screens/admin_topup_screen.dart`
  - ถ้าหน้า admin เดิมอ่านจาก table เดียวกันอยู่แล้ว ไม่ต้องแก้
  - ถ้ายังอ่านเฉพาะ driver app request ให้เพิ่ม source display เป็น `web`
- Modify: `lib/common/services/wallet_service.dart`
  - ไม่แก้ถ้า `wallet_topup` RPC ใช้ได้อยู่แล้ว
  - ถ้ายังไม่มี idempotency key ให้เพิ่มใน RPC/table transaction
- Test: `test/driver/wallet_service_test.dart`
  - เพิ่ม test อนุมัติ top-up แล้ว balance เพิ่มครั้งเดียว
- Test: `test/web_topup_request_policy_test.dart`
  - validate auth required, amount, duplicate request

## Data Model

ใช้ table เดิมก่อน ถ้ามี `topup_requests` อยู่แล้วให้เพิ่ม field เท่าที่จำเป็น:

```sql
alter table topup_requests
  add column if not exists source text not null default 'app',
  add column if not exists slip_url text,
  add column if not exists transfer_reference text,
  add column if not exists idempotency_key text,
  add column if not exists requested_by_user_id uuid references auth.users(id);

create unique index if not exists topup_requests_idempotency_key_idx
  on topup_requests(idempotency_key)
  where idempotency_key is not null;

create index if not exists topup_requests_requested_by_user_id_idx
  on topup_requests(requested_by_user_id);
```

สถานะที่ต้องรองรับ:
- `pending`: รอ admin ตรวจ
- `approved`: admin อนุมัติและ wallet credited แล้ว
- `rejected`: admin ปฏิเสธพร้อมเหตุผล
- `cancelled`: user/admin ยกเลิก

RLS policy:
- ผู้ใช้ที่ล็อกอินดู request ของตัวเองได้เท่านั้น
- ผู้ใช้ที่ล็อกอิน insert request ของตัวเองได้เท่านั้น หรือให้ insert ผ่าน Edge Function เท่านั้น
- admin role ดู/อนุมัติได้ทุก request
- anonymous ห้าม insert/select ทุกกรณี

## Auth Flow

1. User กด `เติมเครดิต` บน landing
2. เปิด `topup.html`
3. `topup.js` เรียก `supabase.auth.getSession()`
4. ถ้าไม่มี session:
   - redirect ไป `login.html?redirect=topup.html`
   - หรือแสดง login panel ในหน้าเดียวกัน
5. Login สำเร็จแล้ว redirect กลับ `topup.html`
6. `topup.html` โหลด profile ของ user ที่ล็อกอิน
7. User กรอกจำนวนเงินและหลักฐานโอน
8. Submit พร้อม `Authorization: Bearer <access_token>`
9. Edge Function verify token และใช้ `user.id` จาก token เป็น owner
10. สร้าง request สถานะ `pending`
11. Admin อนุมัติใน `admin_topup_screen`
12. Wallet balance เพิ่มผ่าน `wallet_topup` RPC และสร้าง `wallet_transactions`

## Task 1: Fix Landing CTA

**Files:**
- Modify: `landing-deploy/index.html`

- [ ] **Step 1: เปลี่ยน link**

แก้:

```html
<a class="primary-button" href="#" style="padding:10px 16px;font-size:14px;">เติมเครดิต</a>
```

เป็น:

```html
<a class="primary-button" href="topup.html" style="padding:10px 16px;font-size:14px;">เติมเครดิต</a>
```

- [ ] **Step 2: ตรวจ link**

Run:

```powershell
Select-String -Path landing-deploy/index.html -Pattern 'href="#"|topup.html|เติมเครดิต'
```

Expected:
- ไม่มี `href="#"`
- มี `href="topup.html"`

## Task 2: Build Web Auth

**Files:**
- Create: `landing-deploy/login.html`
- Create: `landing-deploy/assets/js/auth.js`

- [ ] **Step 1: สร้าง `auth.js`**

Responsibilities:
- create Supabase client
- expose `getSessionOrRedirect()`
- expose `loginWithEmailPassword(email, password)`
- expose `logout()`
- never store service role key

Required behavior:

```js
async function requireSession() {
  const { data, error } = await supabase.auth.getSession();
  if (error || !data.session) {
    const redirect = encodeURIComponent(window.location.pathname.split('/').pop() || 'topup.html');
    window.location.href = `login.html?redirect=${redirect}`;
    return null;
  }
  return data.session;
}
```

- [ ] **Step 2: สร้าง `login.html`**

Fields:
- email
- password
- login button
- error message area

Submit behavior:
- call Supabase Auth login
- on success redirect to query param `redirect`, default `topup.html`

## Task 3: Build Authenticated Top-Up Page

**Files:**
- Create: `landing-deploy/topup.html`
- Create: `landing-deploy/assets/js/topup.js`

- [ ] **Step 1: สร้างหน้า HTML**

หน้าเว็บต้องมี:
- account panel แสดง email/phone จาก session/profile
- amount preset buttons: `100`, `300`, `500`, `1000`
- custom amount input
- transfer reference
- slip upload หรือ slip URL ถ้ายังไม่ทำ storage upload ในเฟสแรก
- note
- submit button
- result panel
- logout button

ห้ามมี field ให้กรอก `user_id` เอง.

- [ ] **Step 2: สร้าง JS submit**

`topup.js` ต้อง:
- require session ก่อน render form
- validate amount
- create idempotency key
- send Authorization bearer token

Payload:

```json
{
  "amount": 300,
  "transferReference": "optional bank ref",
  "slipUrl": "optional uploaded slip url",
  "note": "optional",
  "idempotencyKey": "client-generated-uuid"
}
```

Headers:

```http
Authorization: Bearer <supabase_access_token>
Content-Type: application/json
```

Endpoint:

```text
https://<project>.supabase.co/functions/v1/web-topup-request
```

ถ้า deploy ผ่าน Netlify ให้ Netlify Function ต้อง forward Authorization header ไป Supabase Function.

## Task 4: Add Authenticated Backend Request Endpoint

**Files:**
- Create: `supabase/functions/web-topup-request/index.ts`

- [ ] **Step 1: Verify JWT**

Rules:
- reject ถ้าไม่มี `Authorization`
- reject ถ้า token invalid/expired
- user id ต้องมาจาก token เท่านั้น

- [ ] **Step 2: Validate input**

Rules:
- `amount` ต้องเป็น numeric และปัดเป็น 2 ตำแหน่ง
- minimum จาก config เช่น `100`
- maximum เช่น `5000`
- reject duplicate `idempotencyKey`
- `transferReference` หรือ `slipUrl` ต้องมีอย่างน้อยหนึ่งอย่างใน manual flow

- [ ] **Step 3: Insert request**

Insert:

```ts
{
  user_id: user.id,
  requested_by_user_id: user.id,
  amount,
  status: 'pending',
  source: 'web',
  slip_url: slipUrl,
  transfer_reference: transferReference,
  idempotency_key: idempotencyKey,
  created_at: new Date().toISOString()
}
```

- [ ] **Step 4: Notify admin**

ใช้ notification/email/LINE path เดิมถ้ามี:
- title: `คำขอเติมเครดิตใหม่`
- body: `ผู้ใช้ {email/phone} แจ้งเติมเครดิต ฿{amount}`
- deep link/admin route: top-up approval

## Task 5: Admin Approval Integration

**Files:**
- Modify: `lib/apps/admin/screens/admin_topup_screen.dart`
- Reuse: `lib/common/services/wallet_service.dart`

- [ ] **Step 1: ตรวจว่า admin screen อ่าน request จาก table เดิมหรือไม่**

Run:

```powershell
Select-String -Path lib/apps/admin/screens/admin_topup_screen.dart -Pattern 'topup|wallet|from\\(' -Context 2,4
```

- [ ] **Step 2: เพิ่ม source label**

แสดง badge:
- `App` สำหรับ request จาก mobile
- `Web` สำหรับ request จาก landing

- [ ] **Step 3: อนุมัติผ่าน RPC เดิม**

เมื่อ approve:
- call `wallet_topup`
- update request status เป็น `approved`
- save `approved_by`, `approved_at`
- prevent double approve โดยใช้ transaction/RPC หรือ status guard

## Task 6: Security And Abuse Controls

**Files:**
- Modify: Supabase function and migration

- [ ] **Step 1: No anonymous top-up**

ยืนยัน:
- anon user เปิด `topup.html` แล้วถูก redirect ไป login
- anon request ยิง function ตรงแล้วได้ `401`
- anon key ไม่มีสิทธิ์ insert `topup_requests`

- [ ] **Step 2: RLS**

Policy ที่ต้องมี:
- authenticated user select เฉพาะ request ของตัวเอง
- authenticated user insert เฉพาะ `requested_by_user_id = auth.uid()` ถ้าเปิด direct insert
- admin/service role select/update ได้ทุก request
- anonymous ไม่มีสิทธิ์

- [ ] **Step 3: Rate limit**

อย่างน้อย:
- limit ต่อ user id เช่น 5 requests ต่อ 10 นาที
- reject amount > max
- log suspicious duplicate reference

- [ ] **Step 4: Idempotency**

ใช้ `idempotency_key` กัน user กด submit ซ้ำ.

## Task 7: Tests

**Files:**
- Test: `test/driver/wallet_service_test.dart`
- Test: `test/web_topup_request_policy_test.dart`

- [ ] **Step 1: Auth required test**

Cases:
- no token => reject `401`
- invalid token => reject `401`
- valid token => create pending request for token user id

- [ ] **Step 2: Wallet top-up idempotency test**

Case:
- create wallet balance 100
- approve top-up 300 once
- retry approve same request
- expected balance = 400, not 700

- [ ] **Step 3: Request validation test**

Cases:
- amount below minimum rejects
- missing slip/reference rejects
- duplicate idempotency key returns existing request or rejects safely

## Task 8: Deployment Checklist

- [ ] Confirm Supabase Auth method for web login
- [ ] Confirm PromptPay receiver number/name with owner
- [ ] Confirm support email/phone matches landing and app
- [ ] Confirm anon user cannot submit top-up
- [ ] Confirm logged-in user can submit top-up
- [ ] Confirm admin role can see web top-up requests
- [ ] Confirm rejected request does not credit wallet
- [ ] Confirm approved request creates one wallet transaction
- [ ] Confirm CTA works on desktop/mobile
- [ ] Confirm no service role key is exposed in `topup.html`, `login.html`, `auth.js`, or `topup.js`

## Rollout

1. Deploy backend function and migration first
2. Deploy `login.html`, `topup.html`, `auth.js`, `topup.js` to staging
3. Test anonymous redirect to login
4. Test login with staging user
5. Test request creation with staging user
6. Test admin approval in staging
7. Change landing CTA to `topup.html`
8. Monitor first 5 real requests manually

## Future Phase: Auto PromptPay Verification

หลัง manual flow ใช้งานนิ่งแล้ว ค่อยเพิ่ม:
- Omise PromptPay source/charge creation after login
- webhook verify paid event
- auto credit wallet on verified paid charge
- fallback manual review ถ้า webhook delayed
- display realtime payment status on `topup.html`
