# Jedechai Delivery (Flutter App)

ระบบแอปส่งอาหาร/เรียกรถ/ส่งพัสดุ รองรับบทบาท Customer, Driver, Merchant และ Admin

## 1) Requirements

- Flutter SDK (stable)
- Supabase project
- Firebase project (FCM)
- Google Maps API key

## 2) Environment Setup

สร้างไฟล์ `.env` ที่ root ของ Flutter app (`jedechai_delivery_new/.env`) และใส่ค่าอย่างน้อย:

```env
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_KEY=
PASSWORD_RESET_REDIRECT_URL=

GOOGLE_MAPS_API_KEY=

FIREBASE_PROJECT_ID=
FIREBASE_PRIVATE_KEY_ID=
FIREBASE_PRIVATE_KEY=
FIREBASE_CLIENT_EMAIL=
FIREBASE_CLIENT_ID=

OMISE_PUBLIC_KEY=
OMISE_SECRET_KEY=
```

> สำหรับลืมรหัสผ่าน: ตั้งค่า `PASSWORD_RESET_REDIRECT_URL` ให้เป็น URL จริงที่ผู้ใช้เปิดได้ (ห้ามเป็น localhost)
> และเพิ่ม URL เดียวกันใน Supabase Dashboard → Authentication → URL Configuration → Redirect URLs

## 3) Install & Run

```bash
flutter pub get
flutter run
```

## 3.1) Google Play Release Preparation (Android)

### A) Release signing key (required)

1. Copy template file:

```bash
# Linux/macOS
cp android/key.properties.example android/key.properties

# Windows PowerShell
Copy-Item android/key.properties.example android/key.properties
```

2. Fill real values in `android/key.properties`:

```properties
storeFile=../keystore/release-upload.jks
storePassword=...
keyAlias=upload
keyPassword=...
```

> `android/key.properties` is ignored by git and must never be committed.

### B) Google Maps API key for Android release (required)

Provide `GOOGLE_MAPS_API_KEY` before release build:

- Environment variable, or
- Gradle property `-PGOOGLE_MAPS_API_KEY=...`

Example:

```bash
# Linux/macOS
GOOGLE_MAPS_API_KEY=YOUR_KEY flutter build appbundle --release

# Windows PowerShell
$env:GOOGLE_MAPS_API_KEY="YOUR_KEY"; flutter build appbundle --release
```

or

```bash
./android/gradlew bundleRelease -PGOOGLE_MAPS_API_KEY=YOUR_KEY
# Windows PowerShell: .\android\gradlew.bat bundleRelease -PGOOGLE_MAPS_API_KEY=YOUR_KEY
```

### C) Play Console critical checks

1. **Package name**: currently uses `com.example.jedechai_delivery_new` (must be your production package before first publish).
2. **Versioning**: update `pubspec.yaml` version for every upload.
3. **Permissions policy**: app declares `ACCESS_BACKGROUND_LOCATION`, so Play Console must provide accurate background location declaration and justification.
4. **Data safety form**: complete based on Firebase/Supabase and notification/location usage.

### D) Build output

Generate AAB for Play Store:

```bash
flutter build appbundle --release
```

## 4) Supabase Migrations

มีการยุบรวม migration หลักแล้วเพื่อลดไฟล์ย่อยจำนวนมาก:

- `supabase/migrations/20260301_consolidated_rls_and_feature_columns.sql`

แนวทางแนะนำ:

1. ฐานข้อมูลใหม่: รันไฟล์ consolidated ก่อน
2. จากนั้นรัน migration ฟีเจอร์ที่ใหม่กว่านั้นตามลำดับเวลา
3. ฐานข้อมูลเดิมที่เคยรัน migration มาก่อน สามารถรันไฟล์ consolidated ซ้ำได้ (เป็น idempotent)

## 5) Edge Functions (สำคัญ)

ปัจจุบัน payment gateway ฝั่งแอปเรียกผ่าน Supabase Edge Functions:

- `payment-create-charge`
- `payment-check-status`
- `payment-webhook` (แนะนำสำหรับ webhook จากผู้ให้บริการชำระเงิน)

สามารถเปลี่ยนชื่อ function ได้ด้วย dart define:

```bash
--dart-define=PAYMENT_CREATE_CHARGE_FUNCTION=your-function-name
--dart-define=PAYMENT_CHECK_STATUS_FUNCTION=your-function-name
```

## 6) Quality Checks

```bash
flutter analyze
flutter test
```

> หมายเหตุ: โปรเจคนี้มี warning/info เดิมบางส่วนที่ยังไม่กระทบการรันหลัก
