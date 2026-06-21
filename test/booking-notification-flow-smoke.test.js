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

const foodReadyLegacyStatusMigrationSource = readFileSync(
  new URL("../supabase/migrations/20260616094500_allow_food_ready_legacy_driver_statuses.sql", import.meta.url),
  "utf8",
);

const adminMainSource = readFileSync(
  new URL("../admin-web/src/main.js", import.meta.url),
  "utf8",
);

const adminOrdersActionsSource = readFileSync(
  new URL("../admin-web/src/pages/ordersActions.js", import.meta.url),
  "utf8",
);

const adminActionsFunctionSource = readFileSync(
  new URL("../supabase/functions/admin-actions/index.ts", import.meta.url),
  "utf8",
);

function sourceBetween(source, startMarker, endMarker) {
  const start = source.indexOf(startMarker);
  assert.notEqual(start, -1, `Missing start marker: ${startMarker}`);
  const end = source.indexOf(endMarker, start + startMarker.length);
  assert.notEqual(end, -1, `Missing end marker: ${endMarker}`);
  return source.slice(start, end);
}

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

test("admin web food-ready flow routes through admin-actions instead of browser merchant RPC", () => {
  const adminReadyFlow = sourceBetween(
    adminOrdersActionsSource,
    "async function _adminActAsMerchantOrder",
    "async function _applyAdminOrderReassign",
  );
  assert.match(adminReadyFlow, /const \{\s*supabase,\s*callAdminAction,\s*showToast\s*\} = _deps\(\)/);
  assert.match(adminReadyFlow, /action:\s*['"]mark_food_ready_as_merchant['"]/);
  assert.doesNotMatch(adminReadyFlow, /supabase\.rpc\(['"]mark_food_ready_guarded['"]/);
  assert.match(adminActionsFunctionSource, /case "mark_food_ready_as_merchant"/);
  assert.match(adminActionsFunctionSource, /handleMarkFoodReadyAsMerchant\(supabaseAdmin, body, adminId\)/);
  assert.match(adminActionsFunctionSource, /\.rpc\("mark_food_ready_guarded"/);
  assert.match(adminActionsFunctionSource, /p_merchant_id:\s*booking\.merchant_id/);
  assert.match(adminActionsFunctionSource, /\.rpc\("notify_driver_visible_job"/);
  assert.match(adminActionsFunctionSource, /rpcResult\.status === "ready_for_pickup"[\s\S]*!booking\.driver_id/);
});

test("admin food-ready status allowlist is covered by guarded RPC legacy aliases", () => {
  assert.match(adminMainSource, /ADMIN_MERCHANT_READY_STATUSES = \['preparing', 'driver_accepted', 'arrived_at_merchant', 'matched', 'accepted', 'arrived'\]/);
  assert.match(foodReadyLegacyStatusMigrationSource, /v_booking\.status IN \('arrived_at_merchant', 'arrived'\)/);
  assert.match(foodReadyLegacyStatusMigrationSource, /v_booking\.status IN \('preparing', 'matched', 'driver_accepted', 'accepted'\)/);
});
