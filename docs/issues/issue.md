# Issue — App-side Bug Audit (2026-09-17)

ขอบเขต: โค้ดฝั่งแอป Flutter ทั้งหมดใน `jedechai_delivery_new/lib/` (207 ไฟล์ / ~107,000 บรรทัด)
วิธีตรวจ: อ่านโค้ดเส้นทางเงิน, สถานะออเดอร์, auth, realtime, location, checkout + สแกนรูปแบบบั๊กที่พบบ่อยของ Flutter (async gap, resource leak, unsafe cast/parse/substring, silent fallback)
หมายเหตุ: **ยังไม่ได้รัน `flutter analyze` / `flutter test`** เพราะ container นี้ไม่มี Flutter SDK — ทุกข้อสรุปมาจากการอ่านโค้ด

---

## ISSUE-101 — [Critical] ยกเลิกคำขอถอนเงินซ้ำได้ → คืนเงินเข้า wallet หลายรอบ

**ไฟล์:** `lib/common/services/withdrawal_service.dart:101-148`

**อาการ:** `cancelWithdrawalRequest()` คืนเงินแบบ read-modify-write ที่ไม่ atomic และไม่มี guard กันยิงซ้ำ

```dart
final request = await _client.from('withdrawal_requests')
    .select().eq('id', requestId).eq('user_id', userId)
    .eq('status', 'pending').maybeSingle();     // <- เช็ค pending ตอน "อ่าน"
...
final newBalance = wallet.balance + amount;      // :126
await _client.from('wallet_transactions').insert({...});
await _client.from('wallets').update({'balance': newBalance}).eq('id', wallet.id);
await _client.from('withdrawal_requests')
    .update({'status': 'cancelled'}).eq('id', requestId);   // :142 ไม่มี .eq('status','pending')
```

**ผลกระทบ:**
1. กดยกเลิกรัว ๆ / เน็ตกระตุกแล้วกดซ้ำ → สอง request อ่านสถานะ `pending` ได้ทั้งคู่ก่อนที่ตัวแรกจะเขียน `cancelled` → **คืนเงินสองรอบ (เสกเงินได้)**
2. `balance = wallet.balance + amount` เป็น lost update — ถ้ามีการหักค่าคอมพร้อมกัน ยอดหักจะถูกเขียนทับหาย
3. ถ้า update wallet สำเร็จแต่ update สถานะพัง ผู้ใช้ได้เงินแล้วและ request ยัง `pending` → ยกเลิกซ้ำได้อีก
4. เขียน `wallet_transactions` ตรง ๆ ไม่ผ่าน RPC ทำให้ audit trail ไม่ตรงกับเส้นทาง `wallet_deduct`

**ข้อสังเกต:** โปรเจคมี RPC atomic อยู่แล้ว (`wallet_topup`, `wallet_deduct` ใน `supabase/migrations/20260306_phase2_atomic_wallet_rpc.sql`) แต่เส้นทางนี้ไม่ได้ใช้

**แนวทางแก้:** ย้ายทั้งก้อนไปเป็น RPC เดียว (`cancel_withdrawal_request`) ที่ `SELECT ... FOR UPDATE` + `UPDATE ... WHERE status='pending'` แล้วเช็ค ROW_COUNT ก่อนคืนเงินผ่าน `wallet_topup`

---

## ISSUE-102 — [Critical] Omise secret key + Supabase service key ถูก bundle ไปกับแอป

**ไฟล์:** `pubspec.yaml:119-120` (`assets: - .env`), `lib/common/config/env_config.dart:11,27`, `lib/common/services/omise_service.dart:91,135`

**อาการ:** `.env` ถูกประกาศเป็น Flutter asset → ไฟล์ถูกแพ็กเข้า APK/IPA แบบ plaintext (แตก APK แล้ว `cat` ได้ทันที) และในนั้นมี

- `OMISE_SECRET_KEY` — `OmiseService.createCharge()` / `checkChargeStatus()` ยิง `https://api.omise.co` ด้วย secret key จากเครื่องลูกค้าโดยตรง
- `SUPABASE_SERVICE_KEY` — service role key ที่ **bypass RLS ทั้งระบบ**

**ผลกระทบ:** ใครก็ตามที่โหลดแอปไปแตกไฟล์ จะสร้าง/ดู/refund charge บนบัญชี Omise ได้ และถ้า service key มีค่าจริง จะอ่าน/แก้ทุกตารางใน Supabase ได้โดยไม่สนใจ RLS

**ข้อสังเกต:** `PaymentGatewayService` ทำถูกอยู่แล้ว (เรียกผ่าน Edge Function `payment-create-charge`) ส่วน `OmiseService` ตอนนี้ไม่มี caller ในแอป — แต่ key ยังถูกแพ็กไปอยู่ดี

**แนวทางแก้:** เอา `SUPABASE_SERVICE_KEY` / `OMISE_SECRET_KEY` ออกจาก `.env` ฝั่งแอปให้หมด, ลบ `OmiseService` ที่ไม่ได้ใช้, ย้ายทุก call ที่ต้องใช้ secret ไป Edge Function, และ **rotate key ทั้งสองตัว** (ต้องถือว่ารั่วแล้วถ้าเคยปล่อย build ออกไป)

---

## ISSUE-103 — [Critical] RPC `wallet_deduct` / `complete_booking` เปิดให้ `authenticated` โดยไม่เช็คตัวตน

**ไฟล์:** `supabase/migrations/20260306_phase2_atomic_wallet_rpc.sql:11-62, 514, 521`

**อาการ:** ทั้งสองฟังก์ชันเป็น `SECURITY DEFINER` + `GRANT EXECUTE ... TO authenticated` แต่ **ไม่มีการเทียบ `auth.uid()` กับ `p_user_id` / `p_driver_id`** และ `complete_booking` ก็ไม่เช็คว่า `p_driver_id` ตรงกับ `bookings.driver_id` จริงหรือไม่

**ผลกระทบ:** ผู้ใช้ที่ล็อกอินคนไหนก็ได้ (ลูกค้าธรรมดาก็ได้) เรียก RPC ตรงจาก anon key ได้ → หักเงินออกจาก wallet ของคนอื่นเท่าไรก็ได้ / ปิดงานของคนขับคนอื่นแล้วหักเงินคนนั้น

**หมายเหตุขอบเขต:** ข้อนี้อยู่ฝั่ง backend แต่บันทึกไว้เพราะเป็นช่องที่แอปเปิดโดยตรง และเป็นความเสี่ยงระดับสูงสุดที่เจอในรอบนี้

**แนวทางแก้:** เพิ่ม `IF auth.uid() IS DISTINCT FROM p_user_id THEN RETURN ... 'forbidden'` (ยกเว้น service_role) และใน `complete_booking` เช็ค `driver_id = p_driver_id` ภายใน row ที่ล็อกไว้แล้ว

---

## ISSUE-104 — [Major] หน้า Activity ของลูกค้าแสดง mock bookings เมื่อเน็ตมีปัญหา

**ไฟล์:** `lib/apps/customer/screens/activity_screen.dart:268-325`, `lib/utils/mock_data_service.dart:7-15`

**อาการ:**
```dart
final isRealSupabaseAvailable = await MockDataService.checkRealConnection();
if (!isRealSupabaseAvailable) {
  await Future.delayed(const Duration(seconds: 1));  // "Simulate network delay"
  _bookings = MockDataService.getMockBookings();     // แสดงออเดอร์ปลอม
}
...
} catch (supabaseError) {
  if (ConnectionHelper.isConnectionError(supabaseError)) {
    _bookings = MockDataService.getMockBookings();   // ปลอมอีกรอบ
  }
}
```
และ `checkRealConnection()` เองก็เป็นของปลอม — `await Future.delayed(500ms); return true;` เสมอ

**ผลกระทบ:**
1. เน็ตหลุด → ลูกค้าเห็น "ออเดอร์" ที่ไม่มีอยู่จริงในประวัติตัวเอง แทนที่จะเห็น error ให้ retry (พังความน่าเชื่อถือ + ขัดกฎ "ห้าม fallback เงียบ ๆ" ใน AGENTS.md)
2. `checkRealConnection()` หน่วงเวลาเปล่า 500 ms ทุกครั้งที่โหลดหน้านี้

**แนวทางแก้:** ตัด mock fallback ออกจาก production path ให้หมด, แสดง error state + ปุ่มลองใหม่, ลบ `checkRealConnection()` ที่ไม่ได้เช็คอะไรเลย

---

## ISSUE-105 — [Major] Mock auth fallback ใน `main()` ใช้งานไม่ได้จริง + เสี่ยงล็อกอินปลอม

**ไฟล์:** `lib/main.dart:47-58`, `lib/common/services/auth_service.dart:26-43`, `lib/common/services/mock_auth_service.dart:22-60, 247-254`

**อาการ:**
```dart
try {
  await Supabase.initialize(url: EnvConfig.supabaseUrl, anonKey: EnvConfig.supabaseAnonKey, ...);
} catch (e) {
  await MockAuthService.initialize();   // main.dart:58
}
```
แต่ `MockAuthService.useMockMode => !isSupabaseConfigured` ซึ่งดูจาก **.env มีค่าหรือไม่** เท่านั้น

**ผลกระทบ 2 ทาง:**
1. **.env มีค่าแต่ initialize พัง** (เช่นปัญหา plugin/เน็ตตอนเปิดแอป) → `useMockMode` ยังเป็น `false` → ทุก call หลังจากนั้นที่แตะ `Supabase.instance.client` โยน assertion "You must initialize the supabase instance before calling..." ผู้ใช้เจอ error ประหลาดทั้งแอปแทนที่จะเจอหน้า "เชื่อมต่อไม่ได้" — fallback นี้เป็น dead code ที่ทำงานไม่ได้จริง
2. **.env หาย/ค่าว่างใน release build** → ทั้งแอปวิ่งบน `MockAuthService` ซึ่ง `signInWithEmail()` รับ **อีเมลอะไรก็ได้ + รหัสผ่านยาว ≥ 6 ตัว** แล้วสร้าง session ปลอม role `customer` ให้ทันที

**แนวทางแก้:** ตัด mock auth ออกจาก release build (กันด้วย `kDebugMode` หรือ build flavor), และถ้า `Supabase.initialize` ล้มเหลวให้ขึ้นหน้า fatal error ที่บอกสาเหตุชัด ๆ แทนการ fallback

---

## ISSUE-106 — [Major] Realtime resubscribe ฆ่า stream ที่ UI ฟังอยู่

**ไฟล์:** `lib/common/services/realtime_service.dart:28-51, 55-90, 92-147`

**อาการ:** เมื่อ channel แจ้ง JWT หมดอายุ → `_refreshSessionAndResubscribe()` เรียก `subscribeToDriverLocation(_lastDriverId!)` / `subscribeToBooking(_lastBookingId!)` ใหม่ แต่ฟังก์ชันพวกนี้ **สร้าง `StreamController` ตัวใหม่ และ `close()` ตัวเดิม** (`:58`, `:99`) โดยไม่มีใครเอา stream ใหม่ไปให้ widget

**ผลกระทบ:** widget ที่ `listen()` stream เดิมอยู่ได้รับ `done` แล้วเงียบตลอดไป → หน้าติดตามคนขับของลูกค้า / หน้าติดตามออเดอร์ **หยุดอัปเดตแบบไม่มี error ใด ๆ** ต้องปิดเปิดหน้าใหม่เอง (เกิดทุกครั้งที่ token หมดอายุระหว่างเปิดหน้าค้างไว้)

**ผลข้างเคียงอีกข้อ:** service instance เดียวรองรับได้แค่ 1 driver + 1 booking — subscribe booking ที่สองจะปิดตัวแรกทิ้งเงียบ ๆ

**แนวทางแก้:** ใช้ controller เดิมซ้ำตอน resubscribe (สร้างใหม่เฉพาะตอนถูก `close()` ไปแล้วจริง) หรือเปลี่ยนเป็น map แยกตาม key แล้วให้ caller ถือ subscription ของตัวเอง

---

## ISSUE-107 — [Major] ส่วนลดคูปองไม่คำนวณใหม่เมื่อค่าส่งเปลี่ยน

**ไฟล์:** `lib/common/widgets/coupon_entry_widget.dart:96-101`

```dart
void didUpdateWidget(CouponEntryWidget oldWidget) {
  if (_appliedCoupon != null && oldWidget.orderAmount != widget.orderAmount) {
    _validateCoupon();      // เช็คเฉพาะ orderAmount ไม่เช็ค deliveryFee
  }
}
```

**อาการ:** คูปองชนิด `free_delivery` และ `discount_base == 'delivery_fee'` คิดส่วนลดจาก `widget.deliveryFee` ณ ตอนกดใช้คูปอง แต่ถ้าผู้ใช้เปลี่ยนที่อยู่จัดส่งหลังจากนั้น `food_checkout_screen` จะคำนวณ `_deliveryFee` ใหม่ ส่วน `_couponDiscount` ยังค้างค่าเดิม

**ผลกระทบ (จริงทั้งสองทาง):**
- ค่าส่งเพิ่ม 30 → 80 บาท: คูปอง "ส่งฟรี" ลดแค่ 30 → ลูกค้าจ่ายค่าส่ง 50 บาททั้งที่บอกว่าส่งฟรี
- ค่าส่งลด 30 → 20 บาท: ลด 30 บาททั้งที่ค่าส่งแค่ 20 → **ส่วนลดเกินไปกินราคาอาหาร 10 บาท** (ร้าน/แพลตฟอร์มขาดทุน)

**แนวทางแก้:** เพิ่ม `|| oldWidget.deliveryFee != widget.deliveryFee` ใน `didUpdateWidget` และ clamp ส่วนลดชนิดค่าส่งไม่ให้เกินค่าส่งปัจจุบันตอนสร้างออเดอร์

---

## ISSUE-108 — [Major] ไม่มีพิกัด → ใช้ระยะทาง 3.0 กม. ตายตัวคิดค่าส่ง

**ไฟล์:** `lib/apps/customer/screens/services/food_checkout_screen.dart:363-372`, `329-358`

```dart
Future<void> _calculateDeliveryFee() async {
  if (_merchantLat == null || _merchantLng == null ||
      _customerLat == null || _customerLng == null) {
    _distanceKm = 3.0;                                  // :369
    _deliveryFee = _calculateFeeFromDistance(_distanceKm);
    return;
  }
```

**อาการ:** `_fetchCurrentLocation()` เรียก `Geolocator.getCurrentPosition()` ตรง ๆ โดยไม่เช็ค permission ก่อน ถ้าผู้ใช้ปฏิเสธ location / GPS จับไม่ได้ → `_customerLat/_customerLng = null` → ตกเข้าเงื่อนไขข้างบน

**ผลกระทบ:** ลูกค้าที่อยู่ไกล 15-20 กม. ได้ราคาค่าส่งของระยะ 3 กม. โดยไม่มีคำเตือนใด ๆ ออเดอร์ถูกสร้างด้วยราคานั้นจริง → คนขับ/แพลตฟอร์มรับภาระส่วนต่าง

**แนวทางแก้:** ถ้าไม่มีพิกัดปลายทาง ต้องบล็อกการสั่ง (บังคับเลือกที่อยู่จากแผนที่/สมุดที่อยู่) ไม่ใช่เดาระยะทาง

---

## ISSUE-109 — [Major] เส้นทางเก่า `updateBookingStatus('completed')` หักค่าคอมซ้ำได้

**ไฟล์:** `lib/common/services/booking_service.dart:510-680`, `lib/common/services/wallet_service.dart:352-366`, `supabase/migrations/20260306_phase2_atomic_wallet_rpc.sql:11-62`

**อาการ:** เมธอด `updateBookingStatus()` สั่ง `UPDATE bookings SET status` ก่อน แล้วค่อยหักค่าคอมทีหลัง โดย
- **ไม่เช็คสถานะเดิม** — เรียกซ้ำตอนที่ booking เป็น `completed` อยู่แล้ว ก็หักเงินซ้ำอีกรอบ
- `wallet_deduct` RPC **ไม่มี idempotency key** — ไม่เช็คว่ามี transaction ของ `related_booking_id` นี้อยู่แล้วหรือยัง
- ถ้า `deductFoodCommission()` คืน `null` (เช่น RPC พัง) ฟังก์ชันแค่ `debugLog('❌ ...')` แล้วจบ — booking เป็น `completed` ไปแล้ว, `driver_earnings`/`app_earnings` ค้าง null, แพลตฟอร์มไม่ได้ค่าคอม และไม่มีใครรู้

**สถานะปัจจุบัน:** ตอนนี้ไม่มี caller ใน `lib/` แล้ว (หน้าคนขับย้ายไปใช้ `completeBooking()` ที่เรียก RPC `complete_booking` ซึ่ง lock row + เช็คสถานะ + settle ก่อนค่อย complete ซึ่งถูกต้อง) — แต่เมธอดยังเป็น public API ที่รอให้ใครเผลอหยิบไปใช้

**แนวทางแก้:** ลบ branch `newStatus == 'completed'` ออกจาก `updateBookingStatus()` (ให้โยน exception ชี้ไป `completeBooking()` แทน) และเพิ่ม unique index บน `wallet_transactions(related_booking_id, type)` สำหรับ type `commission`

---

## ISSUE-110 — [Major] `substring(0, 50)` ของ polyline crash กับเส้นทางสั้น

**ไฟล์:** `lib/apps/driver/screens/driver_navigation_screen.dart:1241`

```dart
debugLog('✅ Polyline encoded: ${encodedPolyline.substring(0, 50)}...');
```

**อาการ:** ถ้า Directions API คืน encoded polyline สั้นกว่า 50 ตัวอักษร (เกิดจริงกับงานระยะสั้น/เส้นทางตรง) → `RangeError` ถูกโยนก่อนจะได้ `decodePolyline()`

**ผลกระทบ:** exception ตกไปเข้า `catch` ของ `_drawRoute()` → วาด `_drawStraightLine()` แทน คนขับเห็นเส้นตรงลากทะลุตึกแทนเส้นทางจริง โดยไม่มีอาการฟ้องว่าผิดพลาด

**หมายเหตุ:** `debugLog()` (`lib/utils/debug_logger.dart`) เช็ค `kDebugMode` **ข้างใน** ฟังก์ชัน แต่ argument ถูก evaluate ที่ call site เสมอ → **bug นี้เกิดใน release build ด้วย** (รูปแบบเดียวกันอยู่ที่ `fcm_notification_service.dart:474,514` ด้วย)

**แนวทางแก้:** ใช้ `encodedPolyline.substring(0, min(50, encodedPolyline.length))` และไล่แก้ทุกจุดที่ interpolate `substring` ตายตัวเข้า `debugLog`

---

## ISSUE-111 — [Major] ราคาต่อรายการใน `booking_items` มี 2 ความหมาย

**ไฟล์:** `lib/apps/customer/providers/cart_provider.dart:29-39`, `lib/common/services/booking_service.dart:1182-1206`, `lib/apps/customer/screens/services/food_checkout_screen.dart:1376-1394`, `lib/apps/merchant/screens/order_detail_screen.dart:1257 vs 1814-1851`, `lib/apps/customer/screens/services/customer_order_detail_screen.dart:1006`

**อาการ:** `CartItem.toJson()` ใส่ `'price': totalPrice` ซึ่งเป็น **ราคารวมทั้งบรรทัด** ((base+options) × quantity) แล้ว

- `food_checkout_screen` (เส้นทางที่ใช้จริง) หารกลับเป็นราคาต่อหน่วยก่อนบันทึก — ถูกต้อง
- `BookingService.insertBookingItems()` เอา `item['price']` ยัดลงคอลัมน์ `price` ตรง ๆ — **เก็บราคารวมลงในช่องราคาต่อหน่วย** (ตอนนี้ไม่มี caller แต่เป็นระเบิดเวลา)
- ฝั่งแสดงผลก็ไม่ตรงกันเอง: `merchant/order_detail_screen.dart:1257` (หน้าหลัก) แสดง `price × quantity` ส่วน `_showCompletionDialog()` ที่บรรทัด 1850 แสดง `price` เฉย ๆ ข้าง ๆ badge `"2x"`

**ผลกระทบ:** ออเดอร์ที่มี quantity ≥ 2 ร้านเห็นยอดต่อรายการไม่ตรงกันระหว่างหน้าหลักกับ dialog ตอนจบงาน (ต่างกันเท่าตัว/หลายเท่า) และถ้ามีใครเรียก `insertBookingItems()` ยอดจะกลายเป็น quantity² × ราคาต่อหน่วย

**แนวทางแก้:** นิยามให้ชัดว่า `booking_items.price` = ราคาต่อหน่วย, แก้ `insertBookingItems()` ให้หารด้วย quantity เหมือน checkout (หรือลบทิ้งถ้าไม่ใช้), และแก้ dialog ให้คูณ quantity

---

## ISSUE-112 — [Major] `isShopOpenNow` เช็ควันผิดสำหรับร้านที่เปิดคร่อมเที่ยงคืน

**ไฟล์:** `lib/common/utils/shop_schedule.dart:36-57`

**อาการ:** โค้ดรองรับช่วงเวลาข้ามวันถูกต้องแล้ว (`nowMinutes >= openMinutes || nowMinutes < closeMinutes`) แต่เช็ควันเปิดจาก `bangkokNow.weekday` **ของวันปัจจุบัน** เท่านั้น

**ตัวอย่างที่พัง:** ร้านตั้ง `shop_open_days = ['fri']`, `18:00–02:00` — เวลา 01:00 ของเช้าวันเสาร์ยังอยู่ในกะของวันศุกร์ แต่โค้ดอ่าน `todayKey = 'sat'` ซึ่งไม่อยู่ใน allowedDays → `return false`

**ผลกระทบ:** ร้านที่เปิดกลางคืนหายจากรายการร้านของลูกค้า (`food_service_screen.dart:69`, `food_home_screen.dart:391,396`) ตั้งแต่เที่ยงคืน และ `merchant_orders_screen.dart:665` จะสั่งปิดร้านอัตโนมัติทั้งที่ควรเปิดอยู่

**แนวทางแก้:** ถ้าเป็นช่วงข้ามวันและตอนนี้ `nowMinutes < closeMinutes` ให้เทียบวันกับ `bangkokNow.weekday - 1` (วันก่อนหน้า) แทน

---

## ISSUE-113 — [Major] `Coupon` แปลงวันที่ไม่ผ่าน `AppTime` → วันหมดอายุเพี้ยนตาม timezone

**ไฟล์:** `lib/common/models/coupon.dart:100-102, 146-160`

```dart
endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,  // :101
static DateTime _bangkokNow() => DateTime.now().toUtc().add(const Duration(hours: 7));  // :146
bool get isExpired => endDate != null && _bangkokNow().isAfter(endDate!);               // :160
```

**อาการ:** โปรเจคมี policy กลางอยู่แล้วคือ `AppTime.parseDbTimestamp()` (`lib/common/utils/app_time.dart:8-12`) ซึ่งเติม `Z` ให้ string ที่ไม่มี offset — แต่ `Coupon` ใช้ `DateTime.parse()` ดิบ ๆ ทำให้ string ที่ไม่มี offset ถูกตีความเป็น **เวลาเครื่องผู้ใช้** แล้วเอาไปเทียบกับ `_bangkokNow()` ที่เป็น UTC-flag บวก 7 ชั่วโมง

**ผลกระทบ:** เวลาหมดอายุคูปองเพี้ยนไปตาม timezone ของเครื่อง — บนเครื่องที่ตั้งเวลาไทย คูปองที่ควรหมดเที่ยงคืนจะถูกตัดสินว่าหมดอายุตั้งแต่ราว 17:00 (เร็วไป ~7 ชม.) ส่วนเครื่องที่ตั้ง timezone อื่นจะเพี้ยนคนละค่า ผู้ใช้เจอ "คูปองหมดอายุ" ทั้งที่ยังไม่ถึงกำหนด (และ `isValid` ที่ `:152` ก็ใช้การเทียบเดียวกัน)

**แนวทางแก้:** เปลี่ยนทั้ง `fromJson` ให้ใช้ `AppTime.parseDbTimestamp()` และเทียบด้วย instant เดียวกัน (`DateTime.now().toUtc()`) ไม่ต้องบวก offset เอง

---

## ISSUE-114 — [Major] `_updateJobStatus` สร้าง `updateData` แล้วไม่เคยส่งขึ้น DB

**ไฟล์:** `lib/apps/driver/screens/driver_navigation_screen.dart:1679-1745`

**อาการ:** โค้ดประกอบ map `updateData` (รวมกรณีสำคัญคือ backfill `driver_id` เมื่อ booking ยังไม่มีคนขับ) แล้ว `debugLog('📤 Update data: $updateData')` — แต่หลังจากนั้นทุก branch เรียก `completeBooking()` / `markDriverArrivedAtMerchant()` / `markFoodPickedUp()` / `updateBookingStatusGuarded()` ซึ่ง**ไม่รับ `updateData` เลย**

**ผลกระทบ:** การ backfill `driver_id` ไม่เคยเกิดขึ้นจริง และ log บอกว่ากำลังส่งข้อมูลที่ไม่ได้ส่ง → หลอกคนที่มาไล่ bug ทีหลัง

**แนวทางแก้:** ลบ `updateData` ทิ้ง (ถ้า RPC จัดการ driver_id ให้แล้ว) หรือส่งค่าที่ต้องการจริง ๆ เข้าไปใน RPC

---

## ISSUE-115 — [Minor] `acceptBooking`: ตัวแปรตายแล้ว + อัปเดต surcharge แยก call ไม่มี guard

**ไฟล์:** `lib/common/services/booking_service.dart:1137-1165`

1. `String newStatus;` (`:1138`) ถูกคำนวณแยก food/ride แล้ว**ไม่ถูกใช้** — RPC `accept_booking` set `status = 'driver_accepted'` ตายตัวเสมอ ส่วน `debugLog('... with status: $newStatus')` รายงานค่าที่อาจไม่ตรงกับ DB จริง (โชคดีที่ `BookingStatusPolicy` รองรับทั้ง `accepted` และ `driver_accepted` เลยยังไม่พังหน้าจอ)
2. ค่า surcharge (`updates['price']`, `updates['delivery_fee']`, `updates['notes']`) ถูกเขียน**หลัง**เคลม RPC ด้วย `UPDATE` ธรรมดาแยกอีก call — ถ้า call นั้นพัง คนขับได้งานแต่ไม่ได้ค่าชดเชยระยะทาง และไม่มีการแจ้งเตือน/retry

**แนวทางแก้:** ลบ `newStatus`, และย้าย surcharge เข้าไปเป็น parameter ของ `accept_booking` RPC ให้เป็น transaction เดียว

---

## ISSUE-116 — [Minor] ราคาค่าโดยสาร fallback เป็นค่า hardcode เงียบ ๆ

**ไฟล์:** `lib/apps/customer/screens/ride/ride_home_screen.dart:594-606`

**อาการ:** ถ้าโหลด `_rideRates` จาก DB ไม่สำเร็จ ฟังก์ชันจบด้วย `baseFare = 25.0; perKmCharge = 8.0;` ที่ฝังไว้ในโค้ด — ลูกค้าได้ราคาที่ไม่ตรงกับเรตที่แอดมินตั้งไว้ และจองจริงด้วยราคานั้น (รูปแบบเดียวกับ `food_checkout_screen.dart:74-77` ที่ใช้ 15/2km/10)

**แนวทางแก้:** ถ้าโหลดเรตไม่ได้ ควรบล็อกการจองพร้อมข้อความ ไม่ใช่เดาราคา — สอดคล้องกับกฎ "ห้าม fallback เงียบ ๆ" ใน AGENTS.md

---

## ISSUE-117 — [Minor] โหลดโปรไฟล์คนขับล้มเหลว → UI/DB ไม่ตรงกัน + `setState` ไม่เช็ค mounted

**ไฟล์:** `lib/apps/driver/screens/driver_dashboard_screen.dart:424-465`

1. บรรทัด `:463` — `catch` ตั้ง `setState(() => _isOnline = false)` แต่ไม่ได้เขียน `is_online = false` ลง DB และไม่ได้หยุด location tracking → คนขับเห็นว่าตัวเอง offline แต่ระบบยังจ่ายงานให้อยู่
2. บรรทัด `:443-445` — `setState` ก้อนที่สอง (`_acceptedServiceTypes`) อยู่**นอก** `if (mounted)` ของก้อนแรก → ถ้า widget ถูก dispose ระหว่าง await จะโยน "setState() called after dispose()"

---

## ISSUE-118 — [Minor] `AuthHelper.isSessionValid` force-unwrap `expiresAt!`

**ไฟล์:** `lib/utils/auth_helper.dart:70-77`

`session.expiresAt` เป็น `int?` แต่ถูก `!` โดยไม่มี try/catch ครอบ (ต่างจาก `_attemptTokenRefresh` ที่อยู่ใน try) → session ที่ไม่มี `expiresAt` ทำให้ crash

---

## ISSUE-119 — [Minor] Geocoding/Places หลายตัวยังเป็น mock hardcode ใน production code

**ไฟล์:** `lib/common/services/geocoding_service.dart:34-41, 45-60`, `lib/common/services/location_service.dart:137-154`

- `GeocodingService.getCoordinatesFromAddress()` — คืนพิกัดกลางกรุงเทพ `LatLng(13.7563, 100.5018)` เสมอ ไม่ว่าจะใส่ที่อยู่อะไร
- `GeocodingService.searchPlaces()` — คืน "Siam Paragon / Central World" ปลอมตายตัว
- `LocationService.getAddressFromCoordinates()` — คืน "Mock Street, Bangkok" เสมอ

ตอนนี้ยังไม่มี caller จึงยังไม่กระทบผู้ใช้ แต่เป็นกับดักรอคนหยิบไปใช้แล้วส่งของผิดที่

---

## ISSUE-120 — [Minor] `searchPlaces` ยิง Place Details N+1 + ใช้ Google API key จากฝั่ง client

**ไฟล์:** `lib/common/services/location_service.dart:157-215`, `lib/apps/customer/screens/services/food_checkout_screen.dart:374-382`, `lib/apps/driver/screens/driver_navigation_screen.dart`

**อาการ:** ทุกครั้งที่ค้นหาสถานที่ จะยิง Autocomplete 1 ครั้ง + **Place Details อีก 5 ครั้ง** (ลูป `for (final item in predictions)`) และแอปยังเรียก Directions/Places Web Service ตรงจากเครื่องผู้ใช้ด้วย `EnvConfig.googleMapsApiKey`

**ผลกระทบ:** Web service API key แบบนี้ผูก application restriction ไม่ได้ → key ที่แตกจาก APK เอาไปใช้ยิงบิลเข้าโปรเจคได้ไม่จำกัด บวกกับ N+1 ทำให้ค่าใช้จ่ายต่อการค้นหาสูงเกินจำเป็น

**แนวทางแก้:** ย้าย call พวกนี้ไป Edge Function (ใช้ server key + จำกัด rate) และดึงพิกัดจาก Autocomplete ทีเดียวแทนการยิง Details รายตัว

---

## ISSUE-121 — [Minor] `RoleAmountCalculator.merchantGpAmount` ไม่ clamp rate ที่ > 1

**ไฟล์:** `lib/common/utils/role_amount_calculator.dart:78-85` เทียบกับ `lib/common/utils/driver_amount_calculator.dart:24-29`

`DriverAmountCalculator._clampRate()` clamp เรตไว้ที่ `[0,1]` แต่ `merchantGpAmount()` clamp แค่ด้านล่าง (`rate < 0 ? 0 : rate`) → ถ้าแอดมินกรอก GP เป็น 30 (ตั้งใจหมายถึง 30%) แทนที่จะเป็น 0.3 ร้านจะถูกหักเกินยอดขายทั้งก้อนและ `merchantReceives` กลายเป็น 0

---

## ISSUE-122 — [Minor] สถานะที่ไม่รู้จักถูกแปลงเป็น `pending`

**ไฟล์:** `lib/common/models/booking_status.dart:23-52`, `lib/common/widgets/status_badge.dart:24`

`BookingStatus.fromString()` มี `default: return BookingStatus.pending` แต่ในระบบมีสถานะที่ไม่อยู่ใน enum ใช้งานจริงอยู่ เช่น `quote_requested`, `quoted`, `quote_expired`, `at_merchant`, `confirmed_merchant`, `ready_for_return`, `searching` (งานซักผ้า)

**ผลกระทบ:** `StatusBadge` ของงานเหล่านั้นแสดง "กำลังหาคนขับ" สีส้ม ซึ่งผิดความจริงทั้งหมด

**แนวทางแก้:** เพิ่มสถานะซักผ้าเข้า enum หรือให้ `fromString` คืน `null`/`unknown` แล้วให้ badge แสดงข้อความดิบแทนการเดา

---

## ISSUE-123 — [Minor] `dotenv.load` ไม่มี try/catch ใน `main()`

**ไฟล์:** `lib/main.dart:45`

`await dotenv.load(fileName: '.env')` อยู่นอก try — ถ้า build ไหนไม่มีไฟล์ `.env` (เช่น pipeline CI ที่ไม่ได้ inject) แอปจะดับตั้งแต่ก่อน `runApp()` เป็นจอขาว/ค้าง splash โดยไม่มีข้อความบอกสาเหตุ

---

## ISSUE-124 — [Minor] ตะกร้าเพิ่มรายการซ้ำเป็นคนละบรรทัดเสมอ

**ไฟล์:** `lib/apps/customer/providers/cart_provider.dart:86-107`

`addItem()` ทำ `_items.add(item)` ตลอด ไม่เคยมองหารายการเดิมที่ `menuItemId` + `selectedOptions` เหมือนกันเพื่อบวก quantity → สั่งเมนูเดิมซ้ำ 3 ครั้งได้ 3 บรรทัดในตะกร้าและในใบออเดอร์ของร้าน

---

## ISSUE-125 — [Minor] `_formatScheduledDateTime` ใช้เวลาเครื่อง ขัดกับ policy เวลา Bangkok

**ไฟล์:** `lib/common/services/booking_service.dart:1170-1179`

ใช้ `scheduledAt.toLocal()` ในขณะที่ทั้งโปรเจคใช้ `AppTime.formatBangkok*()` (UTC+7 ตายตัว) → ข้อความ error "งานนี้ตั้งเวลารับไว้ที่ ..." แสดงเวลาไม่ตรงกับที่ลูกค้าเห็นบนเครื่องที่ตั้ง timezone อื่น

---

## Residual risk / test gap

- **ยังไม่ได้รัน `flutter analyze` และ `flutter test`** — container นี้ไม่มี Flutter SDK จึงไม่ได้ verify ด้วย tool จริง ควรรันทั้งสองคำสั่งบนเครื่อง dev ก่อนเริ่มแก้
- ยังไม่ได้ตรวจเชิงลึก: `admin-web/`, Supabase Edge Functions ทั้งหมด, RLS policy รายตาราง, และหน้าจอกลุ่ม admin/laundry
- `warnings_only.txt` ในโปรเจคมี `unnecessary_non_null_assertion` / `unused_element` / `dead_null_aware_expression` ค้างอยู่หลายสิบรายการ (ไม่ได้ยกมาเป็น issue เพราะเป็น lint ไม่ใช่ bug) แต่ `unused_element` หลายตัวใน `driver_navigation_screen.dart` และ `merchant_orders_screen.dart` บ่งชี้ว่ามีฟีเจอร์ที่เขียนไว้แล้วไม่ได้ต่อสาย ควรไล่ดูว่าตั้งใจหรือหลุด
- ข้อ ISSUE-103 เป็น backend แต่ต้องแก้ก่อน/พร้อมกับข้ออื่น เพราะเป็นความเสี่ยงสูงสุดของระบบเงิน
