# JDC Delivery Landing Deploy

> **สถานะ: ถูกผนวกเข้า admin-web แล้ว (2026-09-19) — โฟลเดอร์นี้เป็นต้นฉบับเก่า ห้าม deploy แยก**
>
> เนื้อหา landing (index.html), refund-policy.html, robots.txt และ assets ถูกคัดลอกไปรวมใน `../admin-web/` และ deploy ผ่าน `node scripts/deploy-admin-web-vercel.mjs` (โดย Vercel project เดียวกับ admin) — แก้ landing ให้แก้ที่ `../admin-web/landing.html` เท่านั้น โฟลเดอร์นี้เหลือไว้เพื่ออ้างอิงประวัติ

ต้นฉบับเดิม (ก่อนผนวก):

- `index.html` - public landing page
- `reset-password.html` - password reset page used by app links
- `assets/images/*` - landing visual assets
- `config.production.js` - public Supabase anon config only
- `_headers`, `_redirects` - Netlify/Cloudflare Pages style config
- `vercel.json` - Vercel routing and headers

Do not add Supabase service-role keys to this folder.

