import test from "node:test";
import assert from "node:assert/strict";
import { existsSync, readdirSync, readFileSync } from "node:fs";

const migrationsDir = new URL("../supabase/migrations/", import.meta.url);
const provisionFunctionUrl = new URL(
  "../supabase/functions/connect-provision-merchant/index.ts",
  import.meta.url,
);
const upsertMenuFunctionUrl = new URL(
  "../supabase/functions/connect_upsert_menu/index.ts",
  import.meta.url,
);
const setShopStatusFunctionUrl = new URL(
  "../supabase/functions/connect_set_shop_status/index.ts",
  import.meta.url,
);
const updateOrderStatusFunctionUrl = new URL(
  "../supabase/functions/connect_update_order_status/index.ts",
  import.meta.url,
);
const connectAuthUrl = new URL(
  "../supabase/functions/_shared/connect-auth.ts",
  import.meta.url,
);
const supabaseConfigSource = readFileSync(
  new URL("../supabase/config.toml", import.meta.url),
  "utf8",
);
const merchantOrderServiceSource = readFileSync(
  new URL("../jedechai_delivery_new/lib/common/services/merchant_order_service.dart", import.meta.url),
  "utf8",
);
const merchantSettingsScreenSource = readFileSync(
  new URL("../jedechai_delivery_new/lib/apps/merchant/screens/merchant_settings_screen.dart", import.meta.url),
  "utf8",
);
const adminLegacySource = readFileSync(
  new URL("../admin-web/app.legacy.js", import.meta.url),
  "utf8",
);
const adminSettingsActionsSource = readFileSync(
  new URL("../admin-web/src/pages/settingsActionsBridge.js", import.meta.url),
  "utf8",
);

function readStoreosConnectMigration() {
  const file = readdirSync(migrationsDir)
    .filter((name) => name.endsWith(".sql"))
    .find((name) => name.includes("storeos_connect_jdc_keys"));
  assert.ok(file, "missing storeos_connect_jdc_keys migration");
  return readFileSync(new URL(file, migrationsDir), "utf8");
}

function sourceBetween(source, startMarker, endMarker) {
  const start = source.indexOf(startMarker);
  assert.notEqual(start, -1, `Missing start marker: ${startMarker}`);
  const end = source.indexOf(endMarker, start + startMarker.length);
  assert.notEqual(end, -1, `Missing end marker: ${endMarker}`);
  return source.slice(start, end);
}

test("StoreOS Connect migration keeps JDC key and webhook secret server-side", () => {
  const migration = readStoreosConnectMigration();

  assert.match(migration, /CREATE TABLE IF NOT EXISTS public\.pos_connections/i);
  assert.match(migration, /jdc_connection_key text NOT NULL/i);
  assert.match(migration, /webhook_secret text NOT NULL/i);
  assert.match(migration, /menu_managed_by_pos boolean NOT NULL DEFAULT true/i);
  assert.match(migration, /ALTER TABLE public\.pos_connections ENABLE ROW LEVEL SECURITY/i);
  assert.match(migration, /REVOKE ALL ON public\.pos_connections FROM anon, authenticated/i);
  assert.match(migration, /GRANT SELECT, INSERT, UPDATE, DELETE ON public\.pos_connections TO service_role/i);
  assert.doesNotMatch(migration, /jdc_(live|test)_[A-Za-z0-9]+/);
});

test("Connect auth helper verifies StoreOS webhooks with raw-body HMAC", () => {
  assert.equal(existsSync(connectAuthUrl), true);
  const source = readFileSync(connectAuthUrl, "utf8");

  assert.match(source, /X-JDC-Connection-Key/i);
  assert.match(source, /X-Connect-Signature/i);
  assert.match(source, /X-Connect-Timestamp/i);
  assert.match(source, /MAX_WEBHOOK_CLOCK_SKEW_MS/);
  assert.match(source, /crypto\.subtle\.importKey/);
  assert.match(source, /HMAC/);
  assert.match(source, /SHA-256/);
  assert.match(source, /constantTimeEqual/);
  assert.doesNotMatch(source, /Deno\.env\.get\(["']WEBHOOK_SECRET["']\)/);
});

test("Connect provisioning function creates and rotates JDC keys without hardcoding secrets", () => {
  assert.equal(existsSync(provisionFunctionUrl), true);
  const source = readFileSync(provisionFunctionUrl, "utf8");

  assert.match(source, /verifyAdmin/);
  assert.match(source, /generateConnectionKey/);
  assert.match(source, /generateWebhookSecret/);
  assert.match(source, /\.from\(["']pos_connections["']\)/);
  assert.match(source, /rotate_secret/);
  assert.match(source, /secret_preview/);
  assert.match(source, /jdc_connection_key/);
  assert.match(source, /webhook_secret/);
  assert.doesNotMatch(source, /jdc_(live|test)_[A-Za-z0-9]+/);
});

test("Connect provisioning function opts out of platform JWT verification for custom admin auth", () => {
  assert.match(supabaseConfigSource, /\[functions\.connect-provision-merchant\]/);
  assert.match(
    supabaseConfigSource,
    /\[functions\.connect-provision-merchant\]\s+verify_jwt = false/s,
  );
});

test("StoreOS incoming functions authenticate with JDC connection key and webhook secret", () => {
  for (const functionUrl of [
    upsertMenuFunctionUrl,
    setShopStatusFunctionUrl,
    updateOrderStatusFunctionUrl,
  ]) {
    assert.equal(existsSync(functionUrl), true);
    const source = readFileSync(functionUrl, "utf8");

    assert.match(source, /authenticateConnectRequest/);
  }

  const helper = readFileSync(connectAuthUrl, "utf8");
  assert.match(helper, /readConnectHeaders/);
  assert.match(helper, /verifyConnectSignature/);
  assert.match(helper, /\.from\(["']pos_connections["']\)/);
  assert.match(helper, /\.eq\(["']jdc_connection_key["']/);
  assert.match(helper, /\.eq\(["']status["'],\s*["']active["']\)/);
  assert.match(helper, /webhook_secret/);
});

test("StoreOS menu sync upserts StoreOS-owned menu items by external_ref", () => {
  const source = readFileSync(upsertMenuFunctionUrl, "utf8");

  assert.match(source, /\.from\(["']menu_items["']\)/);
  assert.match(source, /external_ref/);
  assert.match(source, /source:\s*["']storeos["']/);
  assert.match(source, /onConflict:\s*["']merchant_id,external_ref["']/);
  assert.match(source, /full_sync/);
  assert.match(source, /prep_time_minutes/);
  assert.doesNotMatch(source, /preparation_time:/);
});

test("StoreOS shop status and order status updates stay scoped to connected merchant", () => {
  const shopStatusSource = readFileSync(setShopStatusFunctionUrl, "utf8");
  const orderStatusSource = readFileSync(updateOrderStatusFunctionUrl, "utf8");

  assert.match(shopStatusSource, /\.from\(["']profiles["']\)/);
  assert.match(shopStatusSource, /\.eq\(["']id["'],\s*connection\.merchant_id\)/);
  assert.match(shopStatusSource, /shop_status/);
  assert.match(shopStatusSource, /is_online/);

  assert.match(orderStatusSource, /\.from\(["']bookings["']\)/);
  assert.match(orderStatusSource, /\.eq\(["']merchant_id["'],\s*connection\.merchant_id\)/);
  assert.match(orderStatusSource, /service_type["']?,\s*["']food["']|\.eq\(["']service_type["'],\s*["']food["']\)/);
  assert.match(orderStatusSource, /status_origin:\s*["']storeos["']/);
  assert.match(orderStatusSource, /ready_for_pickup/);
  assert.match(orderStatusSource, /merchant_food_ready_at/);
  assert.match(orderStatusSource, /notify_driver_visible_job/);
  assert.match(orderStatusSource, /409/);
});

test("StoreOS incoming functions are configured for custom HMAC verification", () => {
  for (const name of [
    "connect_upsert_menu",
    "connect_set_shop_status",
    "connect_update_order_status",
  ]) {
    assert.match(supabaseConfigSource, new RegExp(`\\[functions\\.${name}\\]`));
    assert.match(
      supabaseConfigSource,
      new RegExp(`\\[functions\\.${name}\\]\\s+verify_jwt = false`, "s"),
    );
  }
});

test("JDC merchant status changes mark status_origin before outbound StoreOS trigger", () => {
  const migration = readStoreosConnectMigration();

  assert.match(merchantOrderServiceSource, /'status_origin': 'jdc'/);
  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.mark_food_ready_guarded/);
  assert.match(migration, /status_origin = 'jdc'/);
  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.update_booking_status_driver_guarded/);
  assert.match(
    migration,
    /SET status = p_new_status,\s+status_origin = 'jdc',\s+updated_at = now\(\)/,
  );
  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.accept_booking/);
  assert.match(
    migration,
    /SET driver_id = p_driver_id,\s+status = 'driver_accepted',\s+status_origin = 'jdc'/,
  );
  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.complete_booking/);
  assert.match(
    migration,
    /SET status = 'completed',\s+status_origin = 'jdc',\s+completed_at = now\(\)/,
  );
});

test("JDC outbound webhook trigger signs order events and skips StoreOS-origin loops", () => {
  const migration = readStoreosConnectMigration();

  assert.match(migration, /CREATE EXTENSION IF NOT EXISTS pg_net/i);
  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.notify_storeos_order/);
  assert.match(migration, /new\.status_origin = 'storeos'/i);
  assert.match(migration, /net\.http_post/);
  assert.match(migration, /X-Connect-Signature/);
  assert.match(migration, /webhook_secret/);
  assert.match(migration, /CREATE TRIGGER trg_notify_storeos_order/);
});

test("StoreOS status update does not directly cancel JDC orders", () => {
  const source = readFileSync(updateOrderStatusFunctionUrl, "utf8");
  const allowedStatusBlock = sourceBetween(
    source,
    "const STOREOS_ALLOWED_STATUSES",
    "const ALLOWED_TRANSITIONS",
  );

  assert.doesNotMatch(allowedStatusBlock, /cancelled/);
  assert.match(source, /Status is not allowed for StoreOS/);
});

test("StoreOS Connect rejects replayed webhook events by event id", () => {
  const migration = readStoreosConnectMigration();
  const helper = readFileSync(connectAuthUrl, "utf8");

  assert.match(migration, /CREATE TABLE IF NOT EXISTS public\.pos_webhook_events/);
  assert.match(migration, /UNIQUE \(connection_id, event_id\)/);
  assert.match(helper, /X-Connect-Event-Id/i);
  assert.match(helper, /\.from\(["']pos_webhook_events["']\)/);
  assert.match(helper, /Duplicate webhook event/);
});

test("Merchant settings exposes merchant_id for StoreOS setup with copy action", () => {
  assert.match(merchantSettingsScreenSource, /StoreOS Connect/);
  assert.match(merchantSettingsScreenSource, /merchant_id/);
  assert.match(merchantSettingsScreenSource, /final merchantId = AuthService\.userId \?\? ['"]['"]/);
  assert.match(merchantSettingsScreenSource, /SelectableText\(\s*merchantId/s);
  assert.match(
    merchantSettingsScreenSource,
    /Clipboard\.setData\(\s*ClipboardData\(text:\s*merchantId\)/s,
  );
});

test("Admin web settings provisions StoreOS JDC key and webhook secret", () => {
  assert.match(adminLegacySource, /StoreOS Connect/);
  assert.match(adminLegacySource, /settStoreOsMerchantId/);
  assert.match(adminLegacySource, /settStoreOsWebhookUrl/);
  assert.match(adminLegacySource, /settStoreOsShopId/);
  assert.match(adminLegacySource, /provisionStoreOsConnection\(\)/);
  assert.match(adminLegacySource, /copyStoreOsCredential\(["']settStoreOsJdcKey["']\)/);
  assert.match(adminLegacySource, /copyStoreOsCredential\(["']settStoreOsWebhookSecret["']\)/);

  assert.match(adminSettingsActionsSource, /connect-provision-merchant/);
  assert.match(
    adminSettingsActionsSource,
    /supabase\.functions\.invoke\(["']connect-provision-merchant["']/,
  );
  assert.match(adminSettingsActionsSource, /merchant_id:\s*merchantId/);
  assert.match(adminSettingsActionsSource, /storeos_webhook_url:\s*storeosWebhookUrl/);
  assert.match(adminSettingsActionsSource, /storeos_shop_id:\s*storeosShopId/);
  assert.match(adminSettingsActionsSource, /rotate_secret:\s*rotateSecret/);
  assert.match(adminSettingsActionsSource, /connection\.jdc_connection_key/);
  assert.match(adminSettingsActionsSource, /webhook_secret/);
  assert.match(adminSettingsActionsSource, /secret_returned/);
  assert.doesNotMatch(adminSettingsActionsSource, /service_role|SUPABASE_SERVICE_ROLE/i);
});
