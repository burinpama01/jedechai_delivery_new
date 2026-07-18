# Jedechai Admin Web Dashboard

ระบบจัดการหลังบ้าน Jedechai Delivery แบบ Web Application (Vanilla JS + Tailwind + Supabase)

## ฟีเจอร์

- **แดชบอร์ด** — ภาพรวมระบบ (ออเดอร์วันนี้, รายได้, ผู้ใช้, กราฟ 7 วัน)
- **ออเดอร์ทั้งหมด** — ดู/กรองออเดอร์ทุกประเภท (food/ride/parcel), รับออเดอร์แทนร้าน, แก้รายการ, reassign, force cancel + refund, rebroadcast
- **แผนที่ Realtime** — ตำแหน่งคนขับ/ออเดอร์ + dispatch
- **ออเดอร์รอจัดการ** — คิวงานค้าง พร้อม realtime + quick filters
- **Laundry** — คำขอซักผ้า, quote, งานขาไป/ขากลับ, แพ็กเกจซักผ้า, จัดการแทนร้าน (ส่ง quote/เปลี่ยนสถานะ/ยกเลิก/คืนเงิน/ตอบแชท)
- **จัดการคนขับ / ร้านค้า / ผู้ใช้** — อนุมัติ, ปฏิเสธ, ระงับ, แก้ไขโปรไฟล์, GP plans, ยอดสั่งซื้อขั้นต่ำต่อร้าน
- **จัดการเมนู** — เมนูอาหาร + option groups ของทุกร้าน
- **การเงิน** — รายได้, คำขอถอนเงิน (อนุมัติ/ปฏิเสธ + slip), คำขอเติมเงิน (verify slip), Customer Wallet (ปรับยอด/เติมเงิน manual)
- **โค้ดส่วนลด / ชวนเพื่อน / ร้องเรียน / Delivery Log แจ้งเตือน / คำขอลบบัญชี**
- **ตั้งค่าระบบ** — ค่าคอมมิชชั่น, Platform Fee, Merchant GP, Minimum Wallet, Banners, App Assets, App Update Policy
- **รีเซ็ตรหัสผ่าน (Public Page)** — หน้า `reset-password.html` สำหรับลิงก์ลืมรหัสผ่านจาก Supabase

## สถาปัตยกรรม

- **การอ่านข้อมูล**: Supabase JS client ด้วย **anon key + admin session** (ผ่าน RLS)
- **การเขียนที่ต้องสิทธิ์สูง**: ยิงทุกอย่างผ่าน Edge Function **`admin-actions`** (ตรวจ JWT ว่าเป็น admin ฝั่ง server แล้วใช้ service role ใน backend เท่านั้น)
- ⛔ **ห้ามใส่ `SUPABASE_SERVICE_KEY` ใน config ฝั่ง browser เด็ดขาด** — โค้ดฝั่งเว็บไม่ใช้และต้องไม่ใช้ service key ไม่ว่ากรณีใด

## โครงสร้างไฟล์

```
admin-web/
├── index.html              — Login + Layout + Sidebar
├── app.js                  — loader (โหลด src/main.js + app.legacy.js)
├── app.legacy.js           — โค้ดเดิม (เหลือ bootstrap/login/shell — หน้าเกือบทั้งหมดย้ายไป src/ แล้ว)
├── src/
│   ├── main.js             — bootstrap + wire bridges
│   ├── config.js           — อ่าน/validate window.JEDECHAI_CONFIG
│   ├── services/           — supabaseClient, authService, adminActionsApi
│   ├── router/             — page registry + lifecycle + meta
│   ├── pages/              — implementation ของแต่ละหน้า (dashboard, orders, laundry, …)
│   ├── ui/                 — toast, helpers
│   └── utils/              — format, export, orderItems
├── config.js               — ค่า dev (placeholder)
├── config.production.js    — ค่า production (gitignored, ห้าม commit)
├── reset-password.html     — หน้า public ตั้งรหัสผ่านใหม่
├── landing.html            — หน้า landing สาธารณะ
├── _redirects / _headers   — Netlify config
└── package.json            — เวอร์ชัน + npm scripts
```

## วิธีพัฒนา (Development)

1. แก้ไข `config.js` ใส่ค่า Supabase (เฉพาะค่า public):

```javascript
window.JEDECHAI_CONFIG = {
  SUPABASE_URL: 'https://your-project.supabase.co',
  SUPABASE_ANON_KEY: 'your-anon-key-here',
};
```

2. รัน `npm run dev` (npx serve) แล้วเปิด `http://localhost:3000`
3. เข้าสู่ระบบด้วยบัญชี Admin (role = 'admin' ใน profiles table)

## วิธี Deploy (Netlify — วิธีที่ยืนยันแล้ว)

> รายละเอียด/ประวัติอยู่ใน Obsidian: `Projects/jedechai_delivery_new/deployment.md`

```bash
# 1) เตรียม artifact (sanitize config → เหลือเฉพาะ SUPABASE_URL + ANON_KEY)
node scripts/prepare-admin-web-netlify-deploy.mjs

# 2) deploy artifact ที่ได้ (ห้าม deploy จากโฟลเดอร์ admin-web ตรงๆ)
npx netlify@26.1.0 deploy --prod --dir=<artifact-dir> --site=<site-id>
```

- สคริปต์ prepare จะ **ปฏิเสธ** config ที่มี service-role key และเขียน `config.production.js` ฉบับ sanitize ให้เอง
- ตัวสคริปต์ยัง stamp เวอร์ชัน asset (`?v=…`) จาก `package.json` ให้อัตโนมัติ กัน browser cache ค้าง

## หน้ารีเซ็ตรหัสผ่าน (สำหรับแอปมือถือ)

- `reset-password.html` รองรับเส้นทาง `/reset-password` ผ่าน `_redirects`
- ตั้งใน Flutter `.env`: `PASSWORD_RESET_REDIRECT_URL=https://<domain>/reset-password`
- เพิ่ม URL เดียวกันใน Supabase Dashboard → Authentication → URL Configuration → Redirect URLs

## ความปลอดภัย

- privileged writes ทั้งหมดผ่าน Edge Function `admin-actions` (ตรวจ admin + rate limit ฝั่ง server)
- `config.production.js` ถูก gitignore และถูก sanitize ก่อน deploy เสมอ
- `robots.txt` + `noindex` บล็อก search engines
- Header `X-Frame-Options: DENY` ป้องกัน clickjacking
- แนะนำเพิ่ม: จำกัด access ด้วย IP whitelist หรือ Netlify Identity

## เทคโนโลยี

- Vanilla HTML/CSS/JS (ES Modules ใน `src/`)
- Tailwind CSS (CDN), Supabase JS Client (CDN), Material Icons, Leaflet.js, Inter Font
