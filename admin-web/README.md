# Jedechai Admin Web Dashboard

ระบบจัดการหลังบ้าน Jedechai Delivery แบบ Web Application

## ฟีเจอร์

- **แดชบอร์ด** — ภาพรวมระบบ (ออเดอร์วันนี้, รายได้, ผู้ใช้, กราฟ 7 วัน)
- **ออเดอร์ทั้งหมด** — ดูและกรองออเดอร์ตามสถานะ/ประเภท
- **จัดการคนขับ** — อนุมัติ/ปฏิเสธ/ระงับคนขับ
- **จัดการร้านค้า** — อนุมัติ/ปฏิเสธ/ระงับร้านค้า
- **ผู้ใช้ทั้งหมด** — ค้นหาและจัดการผู้ใช้ทุกบทบาท
- **คำขอถอนเงิน** — อนุมัติ/ปฏิเสธคำขอถอนเงิน (คืนเงินอัตโนมัติเมื่อปฏิเสธ)
- **ตั้งค่าระบบ** — ค่าคอมมิชชั่น, Platform Fee, Merchant GP, Minimum Wallet
- **รีเซ็ตรหัสผ่าน (Public Page)** — หน้า `reset-password.html` สำหรับลิงก์ลืมรหัสผ่านจาก Supabase

## วิธีพัฒนา (Development)

1. แก้ไขไฟล์ `config.js` ใส่ค่า Supabase:

```javascript
window.JEDECHAI_CONFIG = {
  SUPABASE_URL: 'https://your-project.supabase.co',
  SUPABASE_ANON_KEY: 'your-anon-key-here',
  SUPABASE_SERVICE_KEY: 'your-service-key-here',
};
```

2. เปิด `index.html` ในเบราว์เซอร์ หรือ `npm run dev`

3. เข้าสู่ระบบด้วยบัญชี Admin (role = 'admin' ใน profiles table)

## หน้ารีเซ็ตรหัสผ่าน (สำหรับแอปมือถือ)

มีหน้า web สำหรับรองรับลิงก์จากอีเมลลืมรหัสผ่านแล้ว:

- `reset-password.html`
- รองรับเส้นทาง `/reset-password` ผ่าน `rewrites` ในไฟล์ `vercel.json`

ให้ตั้งค่าใน Flutter `.env`:

```env
PASSWORD_RESET_REDIRECT_URL=https://your-domain.com/reset-password
```

และเพิ่ม URL เดียวกันใน Supabase Dashboard:

- Authentication → URL Configuration → Redirect URLs

## วิธี Deploy ขึ้น Hosting

### Vercel (แนะนำ)

1. สมัคร [Vercel](https://vercel.com/) แล้ว import Git repository
2. ตั้งค่า Project:
   - **Root Directory:** `admin-web`
   - **Framework Preset:** `Other`
   - **Build Command:** *(ไม่ต้อง — เป็น static site)*
   - **Output Directory:** *(ปล่อยว่าง — deploy ไฟล์ในโฟลเดอร์ตรง ๆ)*
3. Routing (SPA rewrites) และ security headers ถูกกำหนดไว้แล้วในไฟล์ `vercel.json`
4. ⚠️ **ห้าม commit `config.production.js` ลง Git!** (มี `.gitignore` ป้องกันอยู่)

#### Deploy ด้วย Vercel CLI (แนะนำสำหรับ production)

ใช้สคริปต์ staging เพื่อสร้างโฟลเดอร์ deploy ที่มี `config.production.js` แบบ public-only
(มีแค่ `SUPABASE_URL` + `SUPABASE_ANON_KEY` — ตัด service key ออกเสมอ):

```bash
# 1) ตรวจสอบ config ก่อน deploy
npm --prefix admin-web run verify:production-config

# 2) สร้างโฟลเดอร์ deploy (ได้ path ใน stdout เป็น JSON)
node scripts/prepare-admin-web-vercel-deploy.mjs --source admin-web --out /tmp/admin-web-deploy

# 3) deploy โฟลเดอร์นั้นขึ้น Vercel
npx vercel deploy /tmp/admin-web-deploy --prod
```

หมายเหตุ: ไฟล์ `.vercelignore` กันไม่ให้ `config.production.js` ในเครื่องถูกอัปโหลดตรง ๆ
สคริปต์ staging จะปลดบรรทัดนั้นในโฟลเดอร์ deploy แล้วเขียนไฟล์ฉบับ sanitize ทับให้เอง

### Firebase Hosting

```bash
firebase init hosting
# เลือก public directory = admin-web
firebase deploy
```

### HostGator / Shared Hosting

1. Upload ไฟล์ทั้งหมดใน `admin-web/` ไปยัง `public_html/admin/`
2. สร้างไฟล์ `config.production.js` บน server โดยตรง
3. เข้าถึงผ่าน `https://yourdomain.com/admin/`

## ⚠️ ความปลอดภัย

- **`SUPABASE_SERVICE_KEY`** มีสิทธิ์เต็ม (bypass RLS) — ห้ามเผยแพร่!
- ใช้ `config.production.js` แยกไฟล์ Service Key ออกจาก source code
- ไฟล์ `robots.txt` บล็อก search engines ไม่ให้ index หน้า admin
- Header `X-Frame-Options: DENY` ป้องกัน clickjacking
- แนะนำ: จำกัด access ด้วย IP whitelist หรือ Vercel Authentication (Deployment Protection)

## เทคโนโลยี

- **Vanilla HTML/CSS/JS** — ไม่ต้อง build, ไม่ต้องติดตั้ง Node.js
- **Tailwind CSS** (CDN) — สำหรับ styling
- **Supabase JS Client** (CDN) — เชื่อมต่อฐานข้อมูล
- **Material Icons** — ไอคอน
- **Leaflet.js** — แผนที่
- **Inter Font** — ฟอนต์

## โครงสร้างไฟล์

```
admin-web/
├── index.html              — หน้าเว็บหลัก (Login + Dashboard layout)
├── app.js                  — ลอจิก JavaScript ทั้งหมด
├── config.js               — ตั้งค่า Supabase (development)
├── config.production.js    — ตั้งค่า Supabase (production, ไม่ commit!)
├── package.json            — สำหรับ npm run dev
├── reset-password.html     — หน้า web สำหรับตั้งรหัสผ่านใหม่จากอีเมล
├── robots.txt              — บล็อก search engines
├── vercel.json             — Vercel rewrites + security headers
├── .vercelignore           — กันไฟล์ลับ/ขยะไม่ให้ถูกอัปโหลดตอน deploy
├── .gitignore              — ป้องกัน commit production config
└── README.md               — คู่มือนี้
```
