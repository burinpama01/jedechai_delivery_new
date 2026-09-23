# ส่งต่องานนำเข้าร้านฝากซื้อจาก Google Maps

วันที่: 2026-09-23  
โปรเจกต์: `jedechai_delivery_new` / Admin Web

## สถานะ

- ผู้ใช้ยืนยันว่าการนำเข้าลิงก์จริงบนหน้าแอดมิน **ผ่านแล้ว** หลังแก้ URL ที่มีรหัสหมุดสองรายการ
- Production: Supabase Edge Function `shop-store-lookup` ACTIVE v5; Admin Web `1.10.3-202609231305` ที่ `https://jedechai-delivery.vercel.app/admin`
- ตรวจ HTTP ของหน้าแอดมินได้ 200; ผล UAT ในบัญชีแอดมินเป็นคำยืนยันจากผู้ใช้ ไม่ใช่ session ที่ agent เข้าทดสอบเอง

## สิ่งที่ส่งต่อ

- `supabase/functions/shop-store-lookup/index.ts`: รองรับลิงก์ย่อ, URL แบบ `ftid`, และลิงก์เต็มที่มี `!1s` หลายรายการ; เลือก CID ของร้านปลายทางและเทียบกับ Google Place Details ก่อนคืนชื่อ ที่อยู่ พิกัด และเวลาเปิดปิดที่มี
- `admin-web/src/pages/shopStoresPage.js`: เติมค่าลงฟอร์มและแสดงข้อความผิดพลาดจาก Edge Function แทน `non-2xx` กว้าง ๆ
- `test/shop-store-lookup.test.js`: ครอบ URL จริงของผู้ใช้, พิกัดจาก Place Details, การนำเข้าซ้ำ, เวลาเปิดปิด และข้อความผิดพลาด
- `admin-web/package.json`: เวอร์ชัน `1.10.3`; `supabase/config.toml`: ตั้งค่า function

## หลักฐานล่าสุด

- `node --test test/shop-store-lookup.test.js`: ผ่าน 8/8
- Google API จริงกับ URL ที่ผู้ใช้ส่ง: บ้านเฮาซุปเปอร์มาร์เก็ต `19.1834234, 100.9150303`; วันจันทร์ `08:00–21:00`
- `code_reviewer`: ไม่พบ blocker ก่อน deploy
- `supabase functions list`: `shop-store-lookup` ACTIVE v5
- `https://jedechai-delivery.vercel.app/admin`: HTTP 200 และ asset `1.10.3-202609231305`

## งานค้างและข้อควรระวัง

- ข้อมูลร้าน 3 รายการที่เคยบันทึกพิกัดเดียวกันไม่ได้แก้อัตโนมัติ; ตรวจหมุดจริงและแก้ทีละร้านก่อนถือว่าข้อมูล production ถูกต้อง (`ISSUE-20260923-004`)
- URL รูปแบบอื่นอาจมีลำดับ feature ต่างกัน หรือร้านไม่อยู่ใน Text Search 5 อันดับแรก; หากตรวจ CID ไม่ตรง ระบบแจ้งข้อผิดพลาดและไม่เติมพิกัดที่เดา
- ไฟล์ function และ test ยังเป็น untracked ใน working tree; Admin Web และ config ยังมีการเปลี่ยนแปลงที่ไม่ได้ commit อย่ารวมไฟล์ Flutter/งานอื่นที่อยู่ใน working tree เข้า commit เดียวกัน
- ไม่มีการเปลี่ยน schema ฐานข้อมูลในงานนี้

## ขั้นตอนเมื่อรับช่วงต่อ

1. ตรวจ `git status --short` และ stage เฉพาะไฟล์ในหัวข้อสิ่งที่ส่งต่อ
2. ยืนยันพิกัดร้านเดิมจากลิงก์หรือหมุดของแต่ละร้านก่อนแก้ข้อมูล production
3. ทดสอบแก้ร้านเดิมอีกครั้งหลังแก้พิกัด และตรวจรายการร้านหลังบันทึก
4. อัปเดต Obsidian `Projects/jedechai_delivery_new/issue.md`, `issue-index.md`, `current.md` เมื่อข้อมูลร้านเดิมถูกแก้ครบ
