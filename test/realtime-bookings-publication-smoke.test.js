import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

// ISSUE-20260919-001: ออเดอร์ที่เพิ่งสั่งไม่ขึ้นบนหน้าแรกลูกค้า
// Root cause: `bookings` ไม่อยู่ใน supabase_realtime publication ทำให้ .stream()
// ทุกหน้า (home/waiting/order_detail/ride_status) ไม่เคยได้รับ event
// และ commit f488d8f ลบ polling timer ที่เคยชดเชยไว้ (สมมติฐานผิดว่า realtime ทำงาน)
// Fix: migration เพิ่ม bookings เข้า publication (ซ่อมแอปที่ติดตั้งแล้วทันที)
// + hardening ฝั่งแอป refresh ตอน app resume

const migrationSource = readFileSync(
  new URL("../supabase/migrations/20260919230000_add_bookings_to_realtime_publication.sql", import.meta.url),
  "utf8",
);

const homeScreenSource = readFileSync(
  new URL("../jedechai_delivery_new/lib/apps/customer/screens/customer_home_screen.dart", import.meta.url),
  "utf8",
);

test("migration adds public.bookings to supabase_realtime idempotently", () => {
  assert.match(migrationSource, /ALTER PUBLICATION supabase_realtime ADD TABLE public\.bookings/);
  // Idempotent: guard with pg_publication_tables check so re-runs / repaired history stay safe.
  assert.match(migrationSource, /pg_publication_tables/);
  assert.match(migrationSource, /pubname = 'supabase_realtime'/);
  assert.match(migrationSource, /tablename = 'bookings'/);
  assert.match(migrationSource, /IF NOT EXISTS/);
});

test("customer home screen refreshes active bookings when app resumes", () => {
  assert.match(homeScreenSource, /WidgetsBindingObserver/);
  assert.match(homeScreenSource, /didChangeAppLifecycleState/);
  assert.match(homeScreenSource, /AppLifecycleState\.resumed/);
  // Observer must be registered and removed with the widget lifecycle.
  assert.match(homeScreenSource, /WidgetsBinding\.instance\.addObserver\(this\)/);
  assert.match(homeScreenSource, /WidgetsBinding\.instance\.removeObserver\(this\)/);
});

test("customer home screen still subscribes to the bookings realtime stream", () => {
  assert.match(homeScreenSource, /\.stream\(primaryKey: \['id'\]\)/);
  assert.match(homeScreenSource, /'pending_merchant'[\s\S]*_activeBookings = activeBookings/);
});
