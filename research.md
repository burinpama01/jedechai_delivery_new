# research.md — Jedechai Delivery Comprehensive Codebase Analysis

> **อัปเดตล่าสุด**: สแกน codebase ทั้งหมดอย่างละเอียด — Flutter app (37 services, 15 models, ทุก screen/widget/config/util), Supabase (44 migrations, 2 Edge Functions), Admin Web (app.js ~8,200 บรรทัด + HTML + config)
> **ภาษา**: อธิบายเป็นภาษาไทย, ศัพท์เทคนิคเป็นภาษาอังกฤษ

## 1. Project Overview (ภาพรวมโปรเจกต์)

โปรเจกต์นี้คือ **Jedechai Delivery (JDC)** — ระบบ **Super App** สำหรับบริการจัดส่งครบวงจร **App Version: 1.0.6+12**

### บริการหลัก 3 ประเภท:
1. **Ride Service** — เรียกรถรับส่งผู้โดยสาร (มอเตอร์ไซค์/รถยนต์)
2. **Food Delivery** — สั่งอาหารจากร้านค้า ส่งถึงบ้าน
3. **Parcel Delivery** — ส่งพัสดุพร้อมถ่ายรูปยืนยัน

### บทบาทผู้ใช้ 4 กลุ่ม (Multi-role):
- **Customer** — เรียกบริการ, ติดตามสถานะ, ชำระเงิน, ดูประวัติ, แชท, รีวิว, ใช้คูปอง, บันทึกที่อยู่
- **Driver** — รับงาน, อัปเดตสถานะ/ตำแหน่ง, จัดการ wallet (เติมเงิน Omise PromptPay / ถอนเงิน), ดูรายได้, foreground tracking
- **Merchant** — จัดการร้านค้า/เมนู/ออเดอร์อาหาร, ตั้งเวลาเปิด-ปิด, สร้างคูปอง, export รายงาน CSV
- **Admin** — ดูภาพรวมระบบ, อนุมัติคนขับ/ร้านค้า, จัดการค่าธรรมเนียม/GP split, อนุมัติถอน/เติมเงิน, จัดการ ticket, ลบบัญชี, แผนที่ realtime, auto-dispatch

### องค์ประกอบเสริม:
- **Supabase Realtime** — สถานะงานและตำแหน่งคนขับแบบ real-time
- **FCM V1 API + Local Notifications** — แจ้งเตือน foreground/background พร้อมเสียง custom สำหรับ merchant
- **Supabase Edge Functions** — scheduled order automation + admin email
- **Admin Web Dashboard** — web panel แยกสำหรับงานปฏิบัติการหลังบ้าน (16 โมดูล)
- **Omise Payment Gateway** — PromptPay QR สำหรับเติมเงิน wallet
- **Version Check** — force-update dialog เมื่อแอปเวอร์ชันต่ำกว่าที่กำหนด
- **Account Deletion** — GDPR-style flow พร้อม admin approval

---

## 2. Tech Stack & Architecture (เทคโนโลยีและสถาปัตยกรรม)

### 2.1 Mobile App (Flutter)

| หมวด | เทคโนโลยี |
|------|-----------|
| Framework | **Flutter (Dart ≥3.0 <4.0)** |
| State Management | **Provider** (ChangeNotifierProvider สำหรับ AuthProvider, CartProvider) |
| Backend Client | **supabase_flutter ^2.12.0** |
| Maps & Geo | **google_maps_flutter 2.9.0**, **geolocator 11.0.0**, **geocoding ^3.0.0**, **flutter_polyline_points ^2.0.0** |
| Push Notifications | **firebase_core ^3.4.0**, **firebase_messaging ^15.0.0**, **flutter_local_notifications ^18.0.1** |
| Payment Gateway | **Omise** (ผ่าน HTTP REST API — `OmiseService`) + Edge Function gateway |
| Media | **image_picker ^1.0.7**, **flutter_image_compress ^2.1.0** |
| Background Service | **flutter_foreground_task ^8.13.2** (persistent notification สำหรับ driver tracking) |
| Environment | **flutter_dotenv ^5.1.0** (โหลดจากไฟล์ `.env`) |
| Storage | **path_provider ^2.1.2**, **shared_preferences ^2.3.2** |
| Export/Share | **share_plus ^7.2.2** (CSV export) |
| URL Launch | **url_launcher ^6.2.5** |
| Auth Helper | **googleapis_auth ^1.4.1** (Firebase Service Account → FCM V1 API) |
| Alarm/Vibration | **flutter_ringtone_player ^4.0.0**, **vibration ^2.0.0** |
| Animation | **lottie ^3.1.0** |
| Splash/Icon | **flutter_native_splash ^2.4.0**, **flutter_launcher_icons ^0.13.1** |
| Version Check | **package_info_plus ^8.2.0** |

**Dependency Overrides ที่สำคัญ** (แก้ปัญหา compileSdk/compatibility):
- `google_maps_flutter_android: 2.14.0` (แก้ crash updateHeatmaps)
- `image_picker_android: 0.8.12+17` (compileSdk 35)
- `app_links: 6.1.1` (ป้องกัน SDK 36 requirement)
- `geolocator_android: 4.5.5`

### 2.2 Backend (Supabase)

- **PostgreSQL** — ฐานข้อมูลหลัก
- **Row Level Security (RLS)** — ควบคุมสิทธิ์ระดับแถว
- **Supabase Auth** — authentication + session management
- **Supabase Realtime** — PostgreSQL Changes สำหรับ booking status + driver location
- **Supabase Storage** — bucket `app-uploads` สำหรับรูปภาพ (profile, menu, parcel, documents)
- **Supabase Edge Functions** (Deno runtime) — 2 functions:
  - `process-scheduled-orders` — automation สำหรับ scheduled orders
  - `send-admin-email` — ส่ง email แจ้งเตือน admin (Resend API / fallback email_queue)

### 2.3 Admin Web Dashboard

- **Vanilla HTML/CSS/JS** — ไม่มี build system
- **TailwindCSS** (ผ่าน CDN) + **Inter** font + **Material Icons Round**
- **Leaflet.js** — แผนที่ realtime ติดตามคนขับ
- **Supabase JS Client v2** (ผ่าน ESM CDN import)
- ไฟล์หลัก: `index.html` + `app.js` (~8,200+ บรรทัด)
- Config: `config.js` / `config.production.js` (Supabase URL + Keys)

### 2.4 Architecture Pattern

สถาปัตยกรรมเป็น **Monorepo** แบ่ง 3 ส่วนหลัก:

```
jedechai_delivery_new/          ← Root
├── jedechai_delivery_new/      ← Flutter Mobile App
│   └── lib/
│       ├── apps/               ← Feature modules ตาม role
│       │   ├── customer/       (34 items)
│       │   ├── driver/         (11 items)
│       │   ├── merchant/       (13 items)
│       │   ├── admin/          (13 items)
│       │   └── landing/        (1 item)
│       ├── common/             ← Shared core
│       │   ├── config/         (5 files)
│       │   ├── models/         (15 files)
│       │   ├── providers/      (1 file)
│       │   ├── services/       (37 files)
│       │   ├── widgets/        (13 files)
│       │   └── utils/          (2 files)
│       ├── theme/              (1 file)
│       ├── utils/              (5 files)
│       └── main.dart
├── supabase/                   ← Backend
│   ├── migrations/             (44 SQL files)
│   └── functions/              (2 Edge Functions)
└── admin-web/                  ← Web Admin Panel
    ├── index.html
    ├── app.js (~8,200 lines)
    ├── config.js
    └── config.production.js
```

ในฝั่ง Flutter เป็นแนว **Feature + Shared Core**:
- Feature modules ตาม role อยู่ใน `lib/apps/{customer,driver,merchant,admin}`
- Shared cross-cutting logic อยู่ใน `lib/common/{services,models,widgets,config}`
- Theme ส่วนกลางอยู่ที่ `lib/theme/app_theme.dart`

### 2.5 Domain/Business Architecture

- Domain หลักคือ **Booking-centric architecture**
- `bookings.service_type` เป็นแกนแยก flow (`ride`, `food`, `parcel`)
- Service layer หนา (37 services) ครอบคลุม: booking, wallet, payment, realtime, notification, chat, coupon, fare adjustment, merchant config, parcel, review, ticket, admin, storage, auth, profile, location, version check, report export, account deletion
- การคำนวณราคา/ค่าหัก/wallet check มีทั้งแบบ generic และแบบเฉพาะ food/merchant GP split

---

## 3. App Startup & Navigation Flow

### 3.1 Initialization (`main.dart`)

ลำดับการ initialize:
1. **Google Maps Renderer** — Hybrid Composition สำหรับ Android (แก้ blank tiles บน MIUI/Xiaomi)
2. **dotenv** — โหลด `.env` file
3. **Supabase.initialize** — ใช้ `EnvConfig.supabaseUrl` + `EnvConfig.supabaseAnonKey`, fallback `MockAuthService` หาก init ล้มเหลว
4. **AuthService.initialize** — เตรียม auth state
5. **AuthHelper.initializeAutoRefresh** — auto refresh token ทุก 5 นาที (refresh เมื่อเหลือ <10 นาที)
6. **initializeDateFormatting('th')** — locale ไทย
7. **FCMNotificationService().initialize** — Firebase Cloud Messaging

### 3.2 Root Widget (`MyApp`)

- ใช้ **MultiProvider** (AuthProvider + CartProvider)
- **MaterialApp** พร้อม light/dark theme (ThemeMode.system)
- Locale: `th_TH` เป็นหลัก, รองรับ `en_US`
- Root screen: **AuthGate**
- Named routes: `/landing`, `/login`, `/map`, `/driver_dashboard`, `/merchant_dashboard`, `/ride_service`, `/food_service`, `/parcel_service`, `/driver_assigned`

### 3.3 AuthGate — จุด Orchestration กลาง

`AuthGate` เป็น StatefulWidget ที่ตัดสิน flow ทั้งหมดหลัง launch:

1. **Splash Screen** — แสดงโลโก้ (โหลดจาก `SystemConfigService`) + delay 1.5 วินาที
2. **Version Check** — เปรียบเทียบ `app_latest_version` / `app_min_version` จาก `system_config`, แสดง force-update dialog ถ้าเวอร์ชันต่ำกว่า
3. **Authentication Check** — ถ้าไม่ได้ login → `LoginScreen`
4. **Role Fetch** — ดึง role จาก `profiles` table
5. **Account Status Checks** (ตามลำดับ):
   - `suspended` → `AccountSuspendedScreen`
   - `deletion_status == 'pending'` → `PendingDeletionScreen`
   - `pending` / `rejected` (driver/merchant) → `PendingApprovalScreen`
   - Profile ไม่ครบ (driver/merchant) → `ProfileCompletionScreen`
6. **Role-based Navigation**:
   - `admin` → `AdminMainScreen`
   - `driver` → `DriverMainScreen`
   - `merchant` → `MerchantMainScreen`
   - `customer` (default) → `CustomerMainScreen`

นอกจากนี้ยัง: บันทึก FCM token, ขอ Location Permission (พร้อม Prominent Disclosure ตาม Google Play Policy), Listen auth state changes แบบ realtime

---

## 4. Service Layer — รายละเอียดทุก Service (37 ไฟล์)

### 4.1 Core Business Services

**`BookingService`** (~934 บรรทัด) — สร้าง/จัดการ booking ทุก service_type, คำนวณราคาจาก `service_rates` + Google Directions API, state machine (pending→completed), หัก commission จาก wallet เมื่อ completed, ตรวจ wallet balance ก่อนรับงาน, insert booking items สำหรับ food, ส่ง notification คนขับ, realtime subscription

**`WalletService`** (~581 บรรทัด) — ดึง/สร้าง wallet, ตรวจยอดเพียงพอ (`canAcceptJob`, `canAcceptFoodJob`), หัก commission แยกตามประเภท:
- **Ride/Parcel**: Standard commission rate จาก `system_config`
- **Food**: Platform Fee (% ของค่าส่ง) + Merchant GP Split (system rate + driver rate)
- เติมเงิน, ประวัติ transaction, ใช้ค่า dynamic จาก `SystemConfigService`

**`PaymentGatewayService`** — เชื่อม Payment Gateways ผ่าน Supabase Edge Functions, รองรับ Omise/Stripe/GB Prime Pay

**`OmiseService`** — เชื่อม Omise API โดยตรง: PromptPay QR flow (`createPromptPaySource` → `createCharge` → `checkChargeStatus`), Basic Auth (Public Key สำหรับ source, Secret Key สำหรับ charge)

**`PaymentService`** — Orchestrator: `processPayment()` → สร้าง charge → อัปเดต booking → เติม wallet

**`WithdrawalService`** — สร้างคำขอถอนเงิน (optimistic deduction จาก wallet), ยกเลิก (คืนเงิน), ดูประวัติ, จัดการข้อมูลบัญชีธนาคาร

**`CouponService`** — Validate coupon (code, วันหมดอายุ, usage limit, per-user limit, service type, merchant, minimum order), Record usage + increment `used_count` ผ่าน RPC, Admin/Merchant สร้าง coupon, รองรับ 3 ประเภท: `percentage`, `fixed`, `free_delivery`

**`FareAdjustmentService`** — Far Pickup Surcharge เมื่อคนขับอยู่ไกลจากจุดรับ, แยก rate ตาม vehicle type (motorcycle/car), ใช้ merchant custom settings หรือ default, หาคนขับใกล้สุดจาก `driver_locations`

**`MerchantFoodConfigService`** — Resolve per-merchant pricing (delivery + GP split + delivery system fee), 3 Preset Plans (plan_1/2/3), Custom override (base_fare, base_distance, per_km, delivery_fee), GP Split Clamping (system + driver ≤ gp_rate)

### 4.2 Infrastructure Services

**`AuthService`** — Sign in/up ด้วย email+password ผ่าน Supabase Auth, auto-create profile หลัง signup, role management, session refresh/sign out, Mock mode fallback

**`ProfileService`** — CRUD profile, Column safety (`_columnExists()` ตรวจ column ก่อน insert/update), Upsert direct สำหรับ signup flow, Approval status (driver/merchant เริ่ม `pending`, customer เป็น `approved`)

**`SystemConfigService`** — โหลดและแคชค่าจาก `system_config` + `service_rates`, ค่าสำคัญ: commission_rate, driver_min_wallet, platform_fee_rate, merchant_gp_rate, detection_radius, logo_url, GP split defaults, Cache invalidation ด้วย `forceRefresh`

**`RealtimeService`** — Subscribe driver location + booking changes (PostgreSQL Changes), Update driver location (upsert `driver_locations`), Get nearby drivers (Google Directions API distance, fallback Haversine), Auto JWT refresh

**`LocationService`** — getCurrentLocation + Prominent Disclosure dialog, calculateDistance (Google Directions API, fallback Haversine), searchPlaces (Google Places Autocomplete), getCoordinatesFromAddress (Google Geocoding), locale ไทย

**`FCMNotificationService`** — Firebase Cloud Messaging init + permission + save token, Local notifications เมื่อ foreground, Notification tap routing ตาม type, Merchant special channel พร้อมเสียง custom

**`NotificationSender`** — ส่ง FCM V1 API ด้วย Firebase Service Account credentials, Persist in-app notification ลง `notifications` table, Auto-cleanup invalid FCM token (404 UNREGISTERED), Merchant data-only message สำหรับ custom sound

**`NotificationService`** — CRUD notifications (send, get, mark read, delete, clear all), Unread count สำหรับ badge, Local snackbar notification

**`DriverForegroundService`** — Persistent notification "กำลังติดตามตำแหน่งคนขับ..." เมื่อ driver online, flutter_foreground_task (Android foreground service), Heartbeat ทุก 5 วินาที, Update notification text ตามสถานะ

### 4.3 Feature Services

**`AdminService`** (~769 บรรทัด) — Dashboard stats (ออเดอร์/รายได้วันนี้, pending counts, online users), Revenue chart 7 วัน, Driver/Merchant approval (approve/reject/suspend), Withdrawal management (approve+transfer slip / reject+คืนเงิน), Top-up management, Admin action logging, User suspension

**`ChatService`** — Booking chat (customer↔driver), Support chat (customer↔admin), Realtime subscription, Push notification เมื่อมีข้อความใหม่, Mark as read, Close chat room

**`ParcelService`** — Create parcel booking + parcel_details, Update photos (pickup/delivery/signature), Parcel lifecycle (created→picked_up→in_transit→delivered)

**`AddressService`** — CRUD saved addresses (home, work, other), Upsert by label

**`TicketService`** — Create support ticket (category, subject, description, priority), My tickets, Admin methods (get all, update status), Ticket stats, Auto-notify admins

**`ReviewService`** — Get reviews สำหรับ driver/merchant, Rating stats (average, distribution 1-5 stars), Customer name lookup

**`AccountDeletionService`** — Request deletion (backup profile data + set `deletion_status='pending'`), Check status, Admin approve/reject

**`ReportExportService`** — Export CSV สำหรับ Admin/Merchant/Driver, UTF-8 BOM สำหรับ Excel ภาษาไทย, Share ผ่าน `share_plus`

**`StorageService`** — Upload file/image ไปยัง Supabase Storage bucket `app-uploads`, Specialized uploads (profile, menu, documents), Content type detection, Signed URL

**`VersionCheckService`** — Semver comparison, Force update dialog (non-dismissable), Platform-specific URL (Android/iOS), Fallback `app_latest_version` → `app_min_version`

**`MenuOptionService`** — CRUD สำหรับ menu option groups + options, Link options กับ menu items

**`PromptPayService`** — สร้าง EMVCo PromptPay QR payload (phone/national ID)

**`ImagePickerService`** — ถ่ายรูป/เลือกจาก gallery + บีบอัดอัตโนมัติ

**`GeocodingService`** — Reverse geocoding ผ่าน Google Maps API

**`MockAuthService`** / **`MockDataService`** — Mock mode สำหรับ development เมื่อ Supabase ไม่พร้อม

**`AppNavigationService`** — Global navigator key สำหรับ navigation จากนอก widget tree

**`SupabaseService`** — Singleton wrapper สำหรับ Supabase client

---

## 5. Data Models (15 Flutter Models)

### 5.1 `Booking` — ศูนย์กลางธุรกรรม
- **Core**: id, customer_id, driver_id, merchant_id, service_type (`ride`/`food`/`parcel`), status
- **Location**: origin/destination (lat, lng, address)
- **Pricing**: distance_km, price, delivery_fee, coupon_id, discount_amount
- **Scheduling**: scheduled_at, scheduled_reminder_sent_at, scheduled_release_processed_at
- **Tracking**: assigned_at, started_at, completed_at, actual_distance_km, trip_duration_minutes
- **Financial**: driver_earnings, app_earnings, payment_method
- **Vehicle**: vehicle_type (motorcycle/car)

### 5.2 `BookingStatus` — State Machine (14 สถานะ)
`pending` → `pendingMerchant` → `preparing` → `matched` → `readyForPickup` → `accepted` → `driverAccepted` → `arrived` → `arrivedAtMerchant` → `pickingUpOrder` → `inTransit` → `completed` | `cancelled`

แต่ละสถานะมี: display text (แยกตาม role), สี, ไอคอน

### 5.3 `ParcelDetail`
- sender/recipient: name, phone, address
- parcel: size, estimated_weight_kg, description
- photos: parcel_photo_url, pickup_photo_url, delivery_photo_url, signature_url
- lifecycle: parcel_status, picked_up_at, delivered_at

### 5.4 `Coupon`
- ประเภท: `percentage`, `fixed`, `free_delivery`
- ขอบเขต: service_type, merchant_id, min_order_amount, max_discount_amount
- การใช้งาน: usage_limit, used_count, per_user_limit
- GP settlement: merchant_gp_charge_rate, merchant_gp_system_rate, merchant_gp_driver_rate
- ผู้สร้าง: created_by_role (`admin` / `merchant`)

### 5.5 `ChatMessage` + `ChatRoom`
- **ChatRoom**: booking_id, customer_id, driver_id, room_type (`booking` / `support`), is_active
- **ChatMessage**: sender_id, sender_role, message, image_url, is_read

### 5.6 `MenuOptionGroup` + `MenuOption` + `MenuItemWithOptions`
- **Group**: name, min_selection, max_selection (required/optional, single/multi select)
- **Option**: name, price, is_available
- **MenuItemWithOptions**: combines MenuItem + option groups, คำนวณ total price

### 5.7 อื่นๆ
- **`MenuItem`** — id, merchant_id, name, description, price, category, image_url, is_available
- **`User`** — id, email, role, full_name
- **`Location`** — id, name, latitude, longitude, address
- **`SavedAddress`** — user_id, label, name, address, lat/lng
- **`SupportTicket`** — user_id, category, subject, description, status, priority, resolution
- **`Review`** — booking_id, customer_id, driver_id/merchant_id, rating, comment
- **`Notification`** — user_id, title, body, type, data, is_read
- **`Payment`** — booking_id, amount, method, status

---

## 6. Database Schema & Migrations (44 Migration Files)

### 6.1 ตารางหลักที่พบจาก migrations

| ตาราง | หน้าที่ |
|-------|---------|
| `profiles` | ข้อมูลผู้ใช้ทุก role (ผูก auth.users) |
| `bookings` | ธุรกรรมการจองทุกประเภท |
| `booking_items` | รายการอาหารใน food order |
| `parcel_details` | ข้อมูลพัสดุ |
| `wallets` | กระเป๋าเงิน driver/merchant |
| `wallet_transactions` | ประวัติรายการ wallet |
| `withdrawal_requests` | คำขอถอนเงิน |
| `topup_requests` | คำขอเติมเงิน |
| `menu_items` | เมนูอาหาร |
| `menu_option_groups` | กลุ่มตัวเลือกเมนู |
| `menu_options` | ตัวเลือกเมนู |
| `menu_item_option_links` | เชื่อม menu item กับ option group |
| `coupons` | คูปองส่วนลด |
| `coupon_usages` | ประวัติการใช้คูปอง |
| `saved_addresses` | ที่อยู่ที่บันทึกไว้ |
| `support_tickets` | ticket ร้องเรียน |
| `reviews` | รีวิว |
| `notifications` | การแจ้งเตือน in-app |
| `chat_rooms` | ห้องแชท |
| `chat_messages` | ข้อความแชท |
| `driver_locations` | ตำแหน่งคนขับ (realtime) |
| `driver_activity_logs` | log กิจกรรมคนขับ |
| `admin_actions` | log การกระทำของ admin |
| `account_deletion_requests` | คำขอลบบัญชี |
| `system_config` | ค่าตั้งค่าระบบ |
| `service_rates` | อัตราค่าบริการตาม service_type |
| `banners` | แบนเนอร์โฆษณา |
| `email_queue` | คิวอีเมล (fallback) |

### 6.2 `profiles` — Schema สำคัญ

| Column | หมายเหตุ |
|--------|----------|
| id (UUID) | PK, ผูก auth.users |
| role | customer/driver/merchant/admin |
| full_name, phone_number | ข้อมูลพื้นฐาน |
| approval_status | pending/approved/rejected/suspended |
| rejection_reason, approved_at, approved_by | กระบวนการอนุมัติ |
| vehicle_type, license_plate | driver |
| driver_license_url, vehicle_registration_url | driver documents |
| shop_address, shop_status | merchant |
| shop_open_time, shop_close_time, shop_open_days | merchant schedule |
| shop_license_url, shop_photo_url | merchant documents |
| gp_rate | merchant GP rate (0-1) |
| merchant_gp_system_rate, merchant_gp_driver_rate | GP split |
| custom_delivery_fee, custom_service_fee | per-merchant override |
| custom_base_fare, custom_base_distance, custom_per_km | per-merchant delivery pricing |
| latitude, longitude | merchant location |
| avatar_url, fcm_token, is_online | |
| deletion_status | null/pending/approved |
| bank_name, bank_account_number, bank_account_name | ข้อมูลธนาคาร |

### 6.3 Migration Highlights

- **Consolidated migration** (`20260301`): รวม RLS policies, feature columns, indexes, triggers สำหรับตารางหลักทั้งหมด
- **GP Split** (`20260309`): เพิ่ม `merchant_gp_system_rate`, `merchant_gp_driver_rate` ใน profiles + system_config พร้อม CHECK constraints (0-1 range, split ≤ gp_rate) + backfill จากข้อมูลเดิม
- **Merchant Coupons** (`20260304`): เพิ่ม `created_by_role`, GP charge rates ใน coupons + backfill + indexes
- **Scheduled Orders** (`20260302-03`): เพิ่ม `scheduled_at`, tracking columns สำหรับ automation
- **Vehicle Types** (`20240215`): service_rates แยกตาม vehicle_type
- **Custom Fees** (`20240214`): custom_delivery_fee, custom_service_fee ใน profiles
- **Account Deletion** (`20240218`): ตาราง + RLS สำหรับ GDPR-style deletion flow
- **Reviews** (`20240229`): ตาราง reviews + RLS
- **Shop Hours** (`20240219`): เวลาเปิด-ปิดร้าน
- **Auto Profile Trigger** (`20240216`): trigger สร้าง profile อัตโนมัติเมื่อ user ลงทะเบียน

### 6.4 RLS Strategy

- **User owns data**: `auth.uid() = user_id` สำหรับ SELECT/INSERT/UPDATE
- **Admin access**: role-based check ผ่าน `profiles.role = 'admin'`
- **Service role**: bypass RLS สำหรับ Edge Functions / system operations
- **Idempotent migrations**: ใช้ `IF NOT EXISTS`, `DROP POLICY IF EXISTS` ทุกที่

---

## 7. Supabase Edge Functions (2 Functions)

### 7.1 `process-scheduled-orders` (~304 บรรทัด)

**หน้าที่**: ประมวลผลออเดอร์ที่ตั้งเวลาไว้ล่วงหน้า

- **Authentication**: ตรวจสอบ `x-scheduler-secret` header หรือ `SUPABASE_SERVICE_ROLE_KEY`
- **Reminder**: ส่งแจ้งเตือนลูกค้า/ร้านค้า ก่อนถึงเวลานัด (configurable window)
- **Release**: ปล่อยออเดอร์เข้าระบบเมื่อถึงเวลา (เปลี่ยนสถานะ + แจ้งเตือน)
- **Idempotency**: ใช้ `scheduled_reminder_sent_at` และ `scheduled_release_processed_at` ป้องกันทำซ้ำ
- **CORS**: จัดการ preflight requests

### 7.2 `send-admin-email` (~81 บรรทัด)

**หน้าที่**: ส่ง email แจ้งเตือน admin

- ถ้ามี `RESEND_API_KEY` → ส่งผ่าน **Resend API**
- ถ้าไม่มี → fallback บันทึกลง `email_queue` table

---

## 8. Admin Web Dashboard — รายละเอียดเชิงลึก

### 8.1 Architecture

- **Single Page Application** แบบ vanilla JS (ไม่มี framework/build tool)
- ใช้ **Supabase JS Client v2** (ESM import จาก CDN)
- **TailwindCSS** (CDN) + **Inter** font + **Material Icons Round**
- **Leaflet.js** สำหรับแผนที่ realtime
- UI design: glass-card, gradient backgrounds, animated transitions

### 8.2 โมดูล/หน้าทั้งหมด (16 หน้า)

| หน้า | หน้าที่ |
|------|---------|
| `dashboard` | แดชบอร์ด — ภาพรวมระบบ (stats, charts) |
| `orders` | ออเดอร์ทั้งหมด — รายการสั่งซื้อทุกประเภท |
| `drivers` | จัดการคนขับ — อนุมัติและจัดการ |
| `merchants` | จัดการร้านค้า — อนุมัติและจัดการ |
| `users` | ผู้ใช้ทั้งหมด — ข้อมูลผู้ใช้งาน |
| `withdrawals` | คำขอถอนเงิน — อนุมัติ |
| `revenue` | รายได้ — สรุปรายได้และยอดขาย |
| `menus` | จัดการเมนูร้านค้า — เพิ่ม/แก้ไข |
| `topups` | คำขอเติมเงิน — อนุมัติ |
| `map` | แผนที่ Realtime — ติดตามตำแหน่งคนขับ + auto-dispatch |
| `pending_orders` | ออเดอร์รอจัดการ — ต้องการความช่วยเหลือจากแอดมิน |
| `complaints` | ร้องเรียน — จัดการเรื่องร้องเรียน |
| `promos` | โค้ดส่วนลด — จัดการโปรโมชั่น |
| `settings` | ตั้งค่าระบบ — ค่าธรรมเนียมและตั้งค่าต่างๆ |
| `account_deletions` | คำขอลบบัญชี — จัดการคำขอลบ |

### 8.3 ฟีเจอร์เด่นใน Admin Web

- **Realtime Map** — แสดงตำแหน่งคนขับบน Leaflet map, auto-refresh, realtime channel subscription
- **Auto-dispatch** — ระบบจับคู่คนขับอัตโนมัติสำหรับ pending orders บนแผนที่
- **Admin merchant accept/ready** — admin สามารถรับออเดอร์แทนร้านค้า หรือ mark food ready
- **CSV/Excel Export** — export ข้อมูลเป็น CSV (UTF-8 BOM) หรือ Excel (HTML table format)
- **Profile image upload** — อัปโหลดรูปโปรไฟล์ผ่าน admin (ลอง bucket `app-uploads` แล้ว fallback `admin-uploads`)
- **Status badges** — แสดงสถานะด้วย badge สีต่างๆ (Thai labels)
- **Online badge** — แสดงสถานะออนไลน์/ออฟไลน์ของคนขับ
- **Email lookup cache** — cache email จาก auth.users
- **Resource cleanup** — ทำความสะอาด map/realtime channels เมื่อเปลี่ยนหน้า

### 8.4 Admin Web Status Constants

```
MAP_PENDING_NO_DRIVER_STATUSES = ['pending', 'matched', 'pending_merchant']
MAP_DISPATCHABLE_STATUSES = ['pending', 'matched']
ADMIN_MERCHANT_ACCEPT_STATUSES = ['pending_merchant', 'pending']
ADMIN_MERCHANT_READY_STATUSES = ['preparing', 'driver_accepted', 'arrived_at_merchant', 'matched', 'accepted', 'arrived']
```

---

## 9. Key Business Logic Flows

### 9.1 Booking Flow (Ride/Parcel)
1. Customer สร้าง booking → status `pending`
2. ระบบหาคนขับใกล้สุด (RealtimeService + Google Directions API)
3. ส่ง FCM notification ไปคนขับ
4. คนขับรับงาน → ตรวจ wallet balance → status `accepted`/`driver_accepted`
5. คนขับเดินทาง → status `arrived` → `in_transit`
6. คนขับส่งเสร็จ → status `completed` → หัก commission จาก wallet

### 9.2 Food Delivery Flow
1. Customer สั่งอาหาร → status `pending_merchant`
2. Merchant รับออเดอร์ → status `preparing`
3. ระบบหาคนขับ → ส่ง notification
4. คนขับรับ → status `driver_accepted` → `arrived_at_merchant`
5. Merchant เตรียมเสร็จ → status `ready_for_pickup`
6. คนขับรับอาหาร → status `picking_up_order` → `in_transit`
7. ส่งเสร็จ → status `completed` → หัก commission (Platform Fee + GP Split)

### 9.3 Commission Structure
- **Ride/Parcel**: `commission_rate` × price → หักจาก driver wallet
- **Food**: 
  - **Platform Fee**: `platform_fee_rate` × delivery_fee → หักจาก driver
  - **Merchant GP**: `gp_rate` × food_total → แบ่งเป็น system_rate + driver_rate
  - GP Split สามารถ customize ต่อ merchant ได้

### 9.4 Wallet Flow
- Driver/Merchant ต้องมียอดเงินขั้นต่ำ (`driver_min_wallet`) ก่อนรับงาน
- เติมเงินผ่าน Omise PromptPay QR หรือ admin approve topup request
- ถอนเงินผ่าน withdrawal request → admin approve → โอนเงินจริง

### 9.5 Scheduled Orders
- Customer ตั้งเวลานัดหมาย (`scheduled_at`)
- Edge Function `process-scheduled-orders` ทำงานตาม cron:
  - ส่ง reminder ก่อนถึงเวลา
  - Release ออเดอร์เข้าระบบเมื่อถึงเวลา
- ใช้ idempotency fields ป้องกันทำซ้ำ

---

## 10. Environment Variables & Configuration

### 10.1 `.env` file (Flutter)
- `SUPABASE_URL`, `SUPABASE_ANON_KEY` — Supabase connection
- `GOOGLE_MAPS_API_KEY` — Google Maps/Places/Directions/Geocoding
- `OMISE_PUBLIC_KEY`, `OMISE_SECRET_KEY` — Omise payment
- Firebase Service Account credentials (สำหรับ FCM V1 API)

### 10.2 `system_config` table (dynamic config)
- `commission_rate` — อัตราค่าคอมมิชชั่น
- `driver_min_wallet` — ยอดเงินขั้นต่ำสำหรับรับงาน
- `platform_fee_rate` — ค่าธรรมเนียมแพลตฟอร์ม
- `merchant_gp_rate` — อัตรา GP ร้านค้า
- `merchant_gp_system_rate_default`, `merchant_gp_driver_rate_default` — GP split defaults
- `detection_radius_config` (jsonb) — รัศมีค้นหาคนขับ
- `app_latest_version`, `app_min_version` — version check
- `app_update_url`, `app_update_url_android`, `app_update_url_ios` — store URLs
- `app_update_message` — ข้อความอัปเดต
- `logo_url`, `splash_url` — branding

### 10.3 `service_rates` table
- `base_price`, `base_distance`, `price_per_km` ตาม `service_type` + `vehicle_type`

### 10.4 Admin Web Config (`config.js`)
- `SUPABASE_URL`, `SUPABASE_KEY` — Supabase connection สำหรับ admin panel

---

## 11. Utilities & Helpers

- **`OrderCodeFormatter`** — format order IDs ด้วย prefix ตาม service type: `FD` (food), `RD` (ride), `PC` (parcel), default `JD`
- **`AuthHelper`** — auto refresh JWT token ทุก 5 นาที, session validation, sign-out on token expiry
- **`DebugLogger`** — centralized debug logging utility
- **`EnvConfig`** — อ่านค่าจาก `.env` file (supabaseUrl, supabaseAnonKey, googleMapsApiKey)

---

## 12. Blind Spots / Missing Info

1. **Single source-of-truth ของ schema** — migration มีหลายรุ่น (consolidated + incremental), ไม่มี ERD/Schema doc แบบ canonical

2. **Production deployment topology** — ไม่เห็น CI/CD config, release pipeline, infra manifests

3. **Payment Edge Functions** — `PaymentGatewayService` เรียก edge functions (`payment-create-charge`, `payment-check-status`, `payment-webhook`) แต่ไม่เห็น source ใน repo

4. **Admin web maintainability** — `app.js` ~8,200 บรรทัดรวมทุก concern ในไฟล์เดียว, มี duplicate functions (เช่น `_csvCell`, `exportRowsToCsv`, `exportRowsToExcel`, `renderMiniBarChart` ถูกประกาศซ้ำ 2 ครั้ง)

5. **Testing strategy** — ไม่เห็น test suite เชิงธุรกิจที่ครอบคลุม flow สำคัญ

6. **Data migration runbook** — ไม่มี definitive runbook สำหรับทุก environment scenario (new db / legacy db / partial migrated)

7. **Observability/Monitoring** — มี debug logging แต่ไม่เห็นระบบ monitor/alerting เชิง production (centralized logs, metrics, alert policy)

8. **Google Maps API key security** — API key ถูกใช้ใน client-side code โดยตรง, ควรมี API key restrictions

---

## 13. สรุปความเข้าใจโดยย่อ

**JDC Delivery** เป็นระบบ Delivery แบบหลายบริการในแอปเดียว (Ride/Food/Parcel) โดยใช้ **Supabase** เป็น backend หลักและแยกหน้าที่ตาม role ชัดเจน (Customer/Driver/Merchant/Admin) พร้อม **web admin panel** สำหรับงานปฏิบัติการหลังบ้าน 16 โมดูล

แกนสถาปัตยกรรมอยู่ที่ **booking-centric model** + **service layer หนา (37 services)** ที่รวม logic ธุรกิจเรื่องราคา ค่าธรรมเนียม การจับคู่งาน การติดตามสถานะ และ wallet settlement โดยเฉพาะ **food delivery flow** ที่ซับซ้อนกว่าบริการอื่นเพราะมี **GP split** (system + driver) และ **coupon impact**

ระบบมี maturity ที่ดีในด้าน:
- **Realtime** — driver location tracking + booking status updates
- **Notifications** — FCM V1 API + local notifications + custom merchant sound
- **Scheduled automation** — Edge Function สำหรับ scheduled orders
- **Role gating** — AuthGate orchestration + approval workflow
- **RLS** — Row Level Security ครอบคลุมทุกตาราง
- **Payment** — Omise PromptPay QR + multi-gateway support
- **Admin operations** — comprehensive web dashboard พร้อม realtime map + auto-dispatch

จุดที่ควรปรับปรุง:
- **Admin web modularization** — แยก `app.js` ออกเป็นโมดูลย่อย + แก้ duplicate functions
- **Canonical schema documentation** — สร้าง ERD/Schema doc ที่เป็น single source of truth
- **Test coverage** — เพิ่ม automated tests สำหรับ business-critical flows
- **Deployment automation** — สร้าง CI/CD pipeline + migration runbook
