# แผน Refactor: admin-web (Incremental / ไม่ให้โค้ดหายระหว่างทาง)

## เป้าหมาย
- ลดความเสี่ยงจากไฟล์ `admin-web/app.js` ที่ใหญ่และรวมทุกอย่างไว้ที่เดียว
- ทำให้แก้ง่ายขึ้น: แยก concerns (auth, api, routing, ui, pages, state, utils)
- ลดโอกาสเกิดบั๊ก “โค้ดถูกวางผิด scope / ชื่อชนกัน / side effects ตอน load”
- เพิ่มความสามารถในการทดสอบแบบ manual/regression ได้เป็นขั้นตอน

## หลักการสำคัญ (Safety / No-loss)
- **ห้ามลบโค้ดเดิมระหว่างทาง**: ทุก phase จะ “คัดลอก” โค้ดเดิมไปไว้ในไฟล์ใหม่ก่อน แล้วค่อย “สลับการเรียกใช้” ทีละจุด
- **มี reference ตลอด**: `app.js` เดิมยังคงเป็นแหล่งอ้างอิงจนกว่าจะย้ายครบและทดสอบครบ
- **เปลี่ยนแบบเล็ก ๆ**: 1 PR/1 commit ควรย้ายได้ 1 module หรือ 1 page (ไม่ย้ายหลายส่วนพร้อมกัน)
- **เสถียรภาพก่อนความสวย**: refactor เพื่อโครงสร้าง ไม่เปลี่ยน behavior/UX ในรอบแรก
- **ทำให้ย้อนกลับง่าย**: ทุกการสลับการเรียกใช้ต้อง revert ได้ด้วยการคืน import/เรียกไฟล์เดิม

## ภาพรวมสถาปัตยกรรมปัจจุบัน (จากโค้ดเดิม)
- **Entry**: `index.html` โหลด
  - `config.production.js` (optional)
  - `config.js`
  - `app.js`
- **Config**: `window.JEDECHAI_CONFIG` → `SUPABASE_URL`, `SUPABASE_ANON_KEY`
- **Supabase**: สร้าง client ใน `initSupabase()`
  - `supabaseAuth` ใช้สำหรับ auth/session
  - `supabase` ใช้ read ผ่าน RLS + write privileged ผ่าน Edge Function
- **Privileged API**: `callAdminAction(actionBody)` ยิงไป Edge Function `admin-actions`
- **Routing**: `navigateTo(page)` + `loadPage(page)` และ set `currentPage`
- **Global State (implicit)**:
  - `supabase`, `supabaseAuth`, `currentUser`, `_inMemorySession`, `currentPage`
  - ตัวแปร page-specific เช่น `_pendingRefreshTimer`, `_pendingRealtimeChannel`, ฯลฯ
- **UI Utilities**: `escapeHtml`, `showToast`, export helpers, modal helpers ฯลฯ
- **Pages**: render ฟังก์ชันจำนวนมาก เช่น `renderDashboard`, `renderOrders`, `renderPendingOrders`, `renderDrivers`, `renderMerchants`, `renderUsers`, `renderWithdrawals`, `renderTopups`, `renderPromos`, `renderMap`, `renderSettings`, `renderAccountDeletions` ฯลฯ

## ปัญหา/ความเสี่ยงหลักที่ควรแก้ด้วย refactor
- **ไฟล์เดียวใหญ่มาก** → เสี่ยง merge conflict และใส่โค้ดผิดตำแหน่ง
- **global state กระจาย** → page cleanup ไม่สม่ำเสมอ (timer/channel leak)
- **routing + render + side-effects ปนกัน** → ยากต่อการติดตามการเปลี่ยนหน้า
- **API contract กับ Edge Function** กระจายตามปุ่มต่าง ๆ → เสี่ยง action mismatch
- **ชุด utilities ซ้ำ/ใช้ไม่เป็นระบบ** (เช่น export, format, modal)

## โครงสร้างเป้าหมาย (Target Structure)
> หมายเหตุ: ยังเป็น vanilla JS เหมือนเดิมก่อน (ไม่ย้าย framework)

- `admin-web/src/`
  - `main.js` (bootstrap)
  - `config.js` (อ่าน `window.JEDECHAI_CONFIG` + validate)
  - `state/`
    - `store.js` (state กลาง + getters/setters)
  - `services/`
    - `supabaseClient.js` (initSupabase)
    - `adminActionsApi.js` (callAdminAction + error handling)
  - `router/`
    - `router.js` (navigateTo/loadPage registry)
    - `pageRegistry.js` (map page -> renderer)
  - `ui/`
    - `toast.js`
    - `modals.js`
    - `dom.js` (helpers)
  - `utils/`
    - `escapeHtml.js`
    - `format.js` (fmtDate/fmt/timeAgo)
    - `export.js` (csv/excel)
    - `guards.js` (btnGuard)
  - `pages/`
    - `dashboard.js`
    - `orders.js`
    - `pendingOrders.js`
    - `drivers.js`
    - `merchants.js`
    - `users.js`
    - `withdrawals.js`
    - `topups.js`
    - `promos.js`
    - `map.js`
    - `settings.js`
    - `accountDeletions.js`

## แผนการ Refactor แบบเป็น Phase

### Phase 0: เตรียมระบบให้ refactor ได้แบบ incremental (ไม่แตะ behavior)
- เพิ่มโครง `admin-web/src/` และไฟล์ “เปล่า” ตาม target structure
- ปรับ `index.html` ให้โหลด `app.js` เหมือนเดิมก่อน **หรือ** โหลด `src/main.js` เพิ่มแบบไม่กระทบ (เลือกทางที่ revert ง่าย)
- กำหนด rule ว่าไฟล์ใหม่ทุกไฟล์ต้อง **export** ฟังก์ชัน ไม่ใช่ผูก global ทันที

**Definition of Done**
- หน้าเว็บเดิมใช้งานได้เหมือนเดิม 100%

### Phase 1: แยก Config + Bootstrapping
- ย้าย logic อ่านค่า config และ validate ไป `src/config.js`
- สร้าง `src/main.js` เพื่อเรียก init และ bind events โดยเรียกของเดิมเป็น fallback

**Safety step**
- `app.js` ยังอยู่ครบ และ `main.js` แค่เรียกผ่าน wrapper

### Phase 2: แยก Supabase init + Auth flow
- ย้าย `initSupabase()` → `services/supabaseClient.js`
- ย้าย auth handlers:
  - login submit
  - check existing session on load
  - logout
- สร้าง `state/store.js` เก็บ `currentUser`, `session`, `currentPage`

**Regression checklist**
- login / logout
- reload หน้าแล้ว session ยังอยู่

### Phase 3: แยก `callAdminAction` เป็น service เดียว
- ย้าย `callAdminAction()` ไป `services/adminActionsApi.js`
- ทำให้มีจุดเดียวในการ:
  - แนบ token
  - refresh token logic
  - error mapping (401 → logout)
- เพิ่ม **action registry** แบบ data-only (เช่น export const Actions = {...}) เพื่อช่วยลด typo

**Regression checklist**
- กดปุ่มที่ยิง admin-actions (ยกเลิก/รีแอสไซน์/เปิดปิดร้าน/approve ฯลฯ)

### Phase 4: แยก Utilities/UI helpers
- ย้าย `escapeHtml`, formatters, export helpers, toast, modal helpers, btnGuard
- เป้าหมายคือทำให้ pages เรียกผ่าน helper เดียวกัน

**Regression checklist**
- toast แสดงถูก
- export CSV/Excel ใช้ได้

### Phase 5: แยก Router + Page registry
- แยก `navigateTo`, `loadPage`, titles map ไป `router/`
- ทำ page registry:
  - `{ dashboard: renderDashboard, orders: renderOrders, ... }`
- ทำมาตรฐาน page lifecycle:
  - `onEnter(el, ctx)`
  - `onLeave()` เพื่อ cleanup timer/channel

**Regression checklist**
- สลับหน้าได้ทุกหน้า
- mobile sidebar behavior ยังเหมือนเดิม

### Phase 6: แยก Pages ทีละหน้า (คัดลอกก่อน สลับทีหลัง)
ลำดับที่แนะนำ (เริ่มจากหน้าที่ isolate ง่ายสุดก่อน):
1) `dashboard`
2) `promos`
3) `withdrawals` / `topups`
4) `drivers` / `merchants` / `users`
5) `orders`
6) `pending_orders` (มี realtime/timer ต้องเน้น cleanup)
7) `map` (Leaflet + realtime)
8) `settings` / `account_deletions`

**วิธีทำต่อหน้า**
- คัดลอก `renderXxx` + helpers เฉพาะหน้าไป `pages/xxx.js`
- ทำให้ import utils จาก `utils/` และ service จาก `services/`
- ใน router registry สลับจากของเดิมเป็นของใหม่ **ทีละหน้า**
- ทดสอบหน้านั้นจบก่อนค่อยไปหน้าถัดไป

### Phase 7: เก็บกวาด `app.js` แบบปลอดภัย
- เมื่อทุกหน้าถูกย้ายครบ:
  - ทำ `app.js` เป็น shim เรียก `src/main.js` หรือปล่อยไว้เป็น legacy backup
- คงไฟล์ legacy ไว้ช่วงหนึ่ง (เช่น `app.legacy.js`) ก่อนลบจริงในรอบหลัง

## Testing / Regression Plan (Manual)
- **Auth**
  - login / logout / reload
  - 401 จาก admin-actions ต้องเด้งกลับหน้า login
- **Core actions**
  - approve/reject driver, merchant
  - suspend user
  - toggle shop status
  - order: cancel / force cancel / rebroadcast / reassign
  - withdrawals/topups approve/reject
  - coupons create/update/toggle/delete
  - account deletion approve/reject
- **Realtime/timers**
  - pending_orders เปิดทิ้งไว้ แล้วสลับหน้า ต้องไม่ยิงซ้ำ/ไม่ leak channel
  - map เปิดแล้วสลับหน้า ต้อง cleanup

## แนวทางป้องกัน “โค้ดหายระหว่างทาง” (แนะนำทำจริง)
- ทุก phase ทำ commit แยก และตั้งชื่อชัดเจน เช่น `refactor(admin-web): extract adminActionsApi (no behavior change)`
- ก่อนสลับหน้าใด ๆ ไปใช้ module ใหม่ ให้:
  - เก็บ “entrypoint เก่า” ไว้เสมอ
  - มี flag ชั่วคราว (เช่น `window.__USE_NEW_PAGES__ = false`) ถ้าต้องการสลับเร็ว

## ข้อเสนอเพิ่มเติม (Optional หลัง phase หลัก)
- เพิ่ม type checking เบา ๆ ด้วย JSDoc (`@typedef`) เพื่อช่วยลดพลาด
- เพิ่ม lint/format (ถ้าต้องการ)
- เพิ่ม small test harness สำหรับฟังก์ชัน pure utilities
