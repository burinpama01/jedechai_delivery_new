import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const bookingServiceSource = readFileSync(
  new URL("../jedechai_delivery_new/lib/common/services/booking_service.dart", import.meta.url),
  "utf8",
);

const merchantDetailSource = readFileSync(
  new URL("../jedechai_delivery_new/lib/apps/merchant/screens/order_detail_screen.dart", import.meta.url),
  "utf8",
);

const notificationMigrationSource = readFileSync(
  new URL("../supabase/migrations/20260508120000_fix_food_ready_driver_notifications.sql", import.meta.url),
  "utf8",
);

test("food booking creation sends push to merchant with canonical and legacy types", () => {
  assert.match(bookingServiceSource, /_notifyMerchantNewFoodOrder/);
  assert.match(bookingServiceSource, /NotificationTypes\.merchantOrderCreated/);
  assert.match(bookingServiceSource, /NotificationTypes\.legacyMerchantNewOrder/);
});

test("merchant detail food-ready flow uses guarded service path and triggers driver notification", () => {
  assert.match(merchantDetailSource, /MerchantOrderService/);
  assert.match(merchantDetailSource, /markFoodReady\(/);
  assert.match(merchantDetailSource, /notifyDriversAboutNewBooking/);
  assert.doesNotMatch(merchantDetailSource, /\.from\('bookings'\)\s*\.update\(\{\s*'status':\s*'ready_for_pickup'/s);
});

test("food-ready migration allows merchant caller and exposes unassigned ready orders", () => {
  assert.match(notificationMigrationSource, /CREATE OR REPLACE FUNCTION public\.notify_driver_visible_job/);
  assert.match(notificationMigrationSource, /auth\.uid\(\) = v_booking\.merchant_id/);
  assert.match(notificationMigrationSource, /v_booking\.service_type = 'food'/);
  assert.match(notificationMigrationSource, /v_booking\.driver_id IS NULL/);
  assert.match(notificationMigrationSource, /SET status = 'ready_for_pickup'/);
});
