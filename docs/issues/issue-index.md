# Issue Index

> Batch: App-side bug audit (2026-09-17) — ID เริ่มที่ ISSUE-101 เพื่อเลี่ยงชนกับ ISSUE-0xx เดิมใน Obsidian
> รายละเอียดเต็มอยู่ใน `issue.md`
>
> **สถานะรอบแก้ 2026-09-19:** Fixed 22 / Partial 2 / Deferred 1
> `Fixed*` = แก้ฝั่งโค้ดแล้ว แต่ยังมี action ที่ต้องทำนอก repo (rotate key)
> ⚠️ ยังไม่ได้รัน `flutter analyze` / `flutter test` — container ไม่มี Flutter SDK

| ID | Status | Severity | Title | Area | Last updated |
|---|---|---|---|---|---|
| ISSUE-101 | Fixed | Critical | ยกเลิกคำขอถอนเงินซ้ำได้ → คืนเงินเข้า wallet หลายรอบ (non-atomic refund) | wallet/withdrawal | 2026-09-19 |
| ISSUE-102 | Fixed* | Critical | Omise secret key + Supabase service key ถูก bundle ไปกับแอป (.env เป็น Flutter asset) | security/payment | 2026-09-19 |
| ISSUE-103 | Fixed | Critical | RPC `wallet_deduct` / `complete_booking` เปิดให้ `authenticated` โดยไม่เช็ค `auth.uid()` | security/backend | 2026-09-19 |
| ISSUE-104 | Fixed | Major | หน้า Activity ของลูกค้า fallback ไปแสดง mock bookings เมื่อเน็ตมีปัญหา | customer/activity | 2026-09-19 |
| ISSUE-105 | Fixed | Major | Mock auth fallback ใน `main()` ใช้งานไม่ได้จริง + ถ้า .env ว่างจะล็อกอินปลอมได้ทุกอีเมล | auth/startup | 2026-09-19 |
| ISSUE-106 | Fixed | Major | Realtime resubscribe ปิด StreamController ที่ UI ฟังอยู่ → แผนที่ติดตามหยุดอัปเดตเงียบ ๆ | realtime/tracking | 2026-09-19 |
| ISSUE-107 | Fixed | Major | ส่วนลดคูปองไม่คำนวณใหม่เมื่อค่าส่งเปลี่ยน (free_delivery / delivery_fee) | customer/checkout | 2026-09-19 |
| ISSUE-108 | Fixed | Major | ไม่มีพิกัด → ตั้งระยะทางเป็น 3.0 กม. ตายตัว แล้วคิดค่าส่งจากค่านั้น | customer/checkout | 2026-09-19 |
| ISSUE-109 | Fixed | Major | `updateBookingStatus('completed')` เส้นทางเก่า หักค่าคอมซ้ำได้ ไม่มี idempotency | booking/settlement | 2026-09-19 |
| ISSUE-110 | Fixed | Major | `substring(0, 50)` ของ polyline ทำให้เส้นทางสั้น ๆ crash แล้วตกไปวาดเส้นตรง | driver/navigation | 2026-09-19 |
| ISSUE-111 | Fixed | Major | ราคาต่อรายการใน `booking_items` มี 2 ความหมาย → ยอดเพี้ยนเมื่อ quantity > 1 | order/items | 2026-09-19 |
| ISSUE-112 | Fixed | Major | `isShopOpenNow` เช็ควันผิดสำหรับร้านที่เปิดคร่อมเที่ยงคืน | merchant/schedule | 2026-09-19 |
| ISSUE-113 | Fixed | Major | `Coupon` แปลงวันที่ด้วย `DateTime.parse` ตรง ๆ ไม่ผ่าน `AppTime` → วันหมดอายุเพี้ยนตาม timezone | coupon/time | 2026-09-19 |
| ISSUE-114 | Fixed | Major | `_updateJobStatus` สร้าง `updateData` (รวม backfill driver_id) แล้วไม่เคยส่งขึ้น DB | driver/navigation | 2026-09-19 |
| ISSUE-115 | Partial | Minor | `acceptBooking`: ตัวแปร `newStatus` ตายแล้ว + อัปเดต surcharge แยก call ไม่มี guard | driver/booking | 2026-09-19 |
| ISSUE-116 | Fixed | Minor | ราคาค่าโดยสาร fallback เป็นค่า hardcode 25 + 8/กม. เงียบ ๆ | customer/ride | 2026-09-19 |
| ISSUE-117 | Fixed | Minor | โหลดโปรไฟล์คนขับล้มเหลว → UI เป็น offline แต่ DB ยัง online + `setState` ไม่เช็ค mounted | driver/dashboard | 2026-09-19 |
| ISSUE-118 | Fixed | Minor | `AuthHelper.isSessionValid` force-unwrap `expiresAt!` | auth | 2026-09-19 |
| ISSUE-119 | Fixed | Minor | Geocoding/Places หลายตัวยังเป็น mock hardcode ใน production code | location | 2026-09-19 |
| ISSUE-120 | Partial | Minor | `searchPlaces` ยิง Place Details N+1 ครั้งต่อการค้นหา + ใช้ Google API key จากฝั่ง client | location/cost | 2026-09-19 |
| ISSUE-121 | Fixed | Minor | `RoleAmountCalculator.merchantGpAmount` ไม่ clamp rate ที่ > 1 | settlement | 2026-09-19 |
| ISSUE-122 | Deferred | Minor | `BookingStatus.fromString` คืน `pending` สำหรับสถานะที่ไม่รู้จัก → งานซักผ้าแสดง "กำลังหาคนขับ" | status/ui | 2026-09-19 |
| ISSUE-123 | Fixed | Minor | `dotenv.load` ใน `main()` ไม่มี try/catch → แอปดับตั้งแต่เปิดถ้าไม่มี .env | startup | 2026-09-19 |
| ISSUE-124 | Fixed | Minor | ตะกร้าเพิ่มรายการซ้ำเป็นคนละบรรทัดเสมอ ไม่รวม quantity | customer/cart | 2026-09-19 |
| ISSUE-125 | Fixed | Minor | `_formatScheduledDateTime` ใช้เวลาเครื่อง ขัดกับนโยบายเวลา Bangkok ของโปรเจค | booking/time | 2026-09-19 |
