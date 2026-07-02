import assert from "node:assert/strict";
import { existsSync, readFileSync, readdirSync } from "node:fs";
import { test } from "node:test";

const migrationsDir = new URL("../supabase/migrations/", import.meta.url);

function readLaundryCoreMigration() {
  const fileName = readdirSync(migrationsDir)
    .filter((name) => /laundry.*core.*quote.*booking.*\.sql$/.test(name))
    .sort()
    .at(-1);

  assert.ok(fileName, "laundry core quote/booking migration not found");
  return readFileSync(new URL(fileName, migrationsDir), "utf8");
}

function readLatestMigration(pattern, message) {
  const fileName = readdirSync(migrationsDir)
    .filter((name) => pattern.test(name))
    .sort()
    .at(-1);

  assert.ok(fileName, message);
  return readFileSync(new URL(fileName, migrationsDir), "utf8");
}

test("laundry migration creates quote/order domain and extends bookings for driver legs", () => {
  const migration = readLaundryCoreMigration();

  assert.match(migration, /merchant_service_types/);
  assert.match(migration, /CREATE TABLE IF NOT EXISTS public\.laundry_packages/);
  assert.match(migration, /CREATE TABLE IF NOT EXISTS public\.laundry_orders/);
  assert.match(migration, /laundry_order_id/);
  assert.match(migration, /laundry_leg/);
  assert.match(migration, /pickup_evidence_url/);
  assert.match(migration, /bookings_service_type_check/);
  assert.match(migration, /'laundry'/);
});

test("laundry migration exposes atomic quote and wallet booking RPCs", () => {
  const migration = readLaundryCoreMigration();

  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.create_laundry_quote_request/);
  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.merchant_send_laundry_quote/);
  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.customer_accept_laundry_quote/);
  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.create_laundry_return_booking/);
  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.driver_confirm_laundry_pickup/);
  assert.match(migration, /customer_wallet_pay_booking/);
  assert.match(migration, /wallet_transactions/);
  assert.match(migration, /merchant_net_amount/);
  assert.match(migration, /platform_gp_amount/);
  assert.match(migration, /quote_expires_at/);
});

test("laundry GP separates merchant fee and delivery fee rates", () => {
  const migration = readLatestMigration(
    /laundry.*gp.*delivery.*rate.*\.sql$/,
    "laundry GP delivery rate migration not found",
  );

  assert.match(migration, /laundry_merchant_gp_rate/);
  assert.match(migration, /laundry_delivery_gp_rate/);
  assert.match(migration, /v_merchant_gp_rate/);
  assert.match(migration, /v_delivery_gp_rate/);
  assert.match(migration, /delivery_gp_amount_outbound/);
  assert.match(migration, /delivery_gp_amount_return/);
  assert.match(migration, /delivery_net_amount_outbound/);
  assert.match(migration, /delivery_net_amount_return/);
  assert.match(migration, /v_app_earnings := ROUND\(\(COALESCE\(v_order\.platform_gp_amount, 0\) \+ COALESCE\(v_order\.delivery_gp_amount_outbound, 0\)\)::numeric, 2\)/);
  assert.match(migration, /WHEN v_order\.laundry_delivery_gp_rate IS NULL THEN COALESCE\(v_order\.delivery_fee_outbound, 0\)/);
  assert.match(migration, /ELSE COALESCE\(v_order\.delivery_net_amount_outbound, 0\)/);
  assert.match(migration, /WHEN v_order\.laundry_delivery_gp_rate IS NULL THEN COALESCE\(v_order\.delivery_fee_return, 0\)/);
  assert.match(migration, /ELSE COALESCE\(v_order\.delivery_net_amount_return, 0\)/);
});

test("laundry GP can split merchant GP to driver earnings", () => {
  const migration = readLatestMigration(
    /laundry.*gp.*driver.*split.*\.sql$/,
    "laundry GP driver split migration not found",
  );

  assert.match(migration, /laundry_gp_driver_rate/);
  assert.match(migration, /laundry_gp_driver_rate_default/);
  assert.match(migration, /laundry_driver_gp_amount/);
  assert.match(migration, /laundry_system_gp_amount/);
  assert.match(migration, /v_laundry_driver_gp_amount/);
  assert.match(migration, /v_laundry_system_gp_amount/);
  assert.match(migration, /LEAST\([^)]*v_merchant_gp_rate/);
  assert.match(migration, /platform_gp_amount = v_platform_gp_amount/);
  assert.match(migration, /laundry_driver_gp_amount = v_laundry_driver_gp_amount/);
  assert.match(migration, /laundry_system_gp_amount = v_laundry_system_gp_amount/);
  assert.match(migration, /CASE WHEN v_order\.laundry_gp_driver_rate IS NULL THEN COALESCE\(v_order\.platform_gp_amount, 0\)/);
  assert.match(migration, /ELSE COALESCE\(v_order\.laundry_system_gp_amount, 0\)/);
  assert.match(migration, /COALESCE\(v_order\.laundry_driver_gp_amount, 0\)/);
});

test("laundry pickup evidence migration stores photos and keeps driver status machine compatible", () => {
  const evidenceMigration = readFileSync(
    new URL(
      "../supabase/migrations/20260610212000_laundry_driver_pickup_evidence_fix.sql",
      import.meta.url,
    ),
    "utf8",
  );

  assert.match(evidenceMigration, /laundry-evidence/);
  assert.match(evidenceMigration, /storage\.buckets/);
  assert.match(evidenceMigration, /driver_confirm_laundry_pickup/);
  assert.match(evidenceMigration, /pickup_evidence_required/);
  assert.match(evidenceMigration, /SET status = 'in_transit'/);
  assert.match(evidenceMigration, /booking_status', 'in_transit'/);
});

test("customer laundry quote request requires and uploads photo attachments", () => {
  const migration = readLatestMigration(
    /laundry.*quote.*attachments.*storage.*\.sql$/,
    "laundry quote attachments storage migration not found",
  );
  const service = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/common/services/laundry_service.dart",
      import.meta.url,
    ),
    "utf8",
  );
  const screen = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/apps/customer/screens/services/laundry_service_screen.dart",
      import.meta.url,
    ),
    "utf8",
  );

  assert.match(migration, /laundry-quote-attachments/);
  assert.match(migration, /storage\.buckets/);
  assert.match(migration, /storage\.objects/);
  assert.match(service, /p_attachment_urls/);
  assert.match(screen, /ImagePicker/);
  assert.match(screen, /_attachmentFiles\.isEmpty/);
  assert.match(screen, /กรุณาแนบรูปผ้าก่อนส่งคำขอ/);
  assert.match(screen, /laundry-quote-attachments/);
  assert.match(screen, /uploadBinary/);
  assert.match(screen, /attachmentUrls: attachmentUrls/);
});

test("laundry quote attachments are visible to merchant and admin audit", () => {
  const service = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/common/services/laundry_service.dart",
      import.meta.url,
    ),
    "utf8",
  );
  const merchantScreen = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/apps/merchant/screens/merchant_laundry_screen.dart",
      import.meta.url,
    ),
    "utf8",
  );
  const adminPage = readFileSync(
    new URL("../admin-web/src/pages/laundryPage.js", import.meta.url),
    "utf8",
  );

  assert.match(service, /attachment_urls/);
  assert.match(service, /laundry-quote-attachments/);
  assert.match(service, /createSignedUrl/);
  assert.match(service, /catch \(_\)/);
  assert.match(service, /_attachment_signed_urls/);
  assert.match(merchantScreen, /_attachment_signed_urls/);
  assert.match(merchantScreen, /รูปแนบจากลูกค้า/);
  assert.match(merchantScreen, /Image\.network/);
  assert.match(adminPage, /attachment_urls/);
  assert.match(adminPage, /attachment_signed_urls/);
  assert.match(adminPage, /createSignedUrls/);
  assert.match(adminPage, /attachmentCell/);
  assert.match(adminPage, /รูปแนบ/);
});

test("laundry quote chat is available to customer, merchant, and admin audit", () => {
  const migration = readLatestMigration(
    /laundry.*quote.*chat.*threads.*\.sql$/,
    "laundry quote chat migration not found",
  );
  const service = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/common/services/laundry_service.dart",
      import.meta.url,
    ),
    "utf8",
  );
  const customerScreen = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/apps/customer/screens/services/laundry_service_screen.dart",
      import.meta.url,
    ),
    "utf8",
  );
  const merchantScreen = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/apps/merchant/screens/merchant_laundry_screen.dart",
      import.meta.url,
    ),
    "utf8",
  );

  assert.match(migration, /CREATE TABLE IF NOT EXISTS public\.laundry_quote_threads/);
  assert.match(migration, /CREATE TABLE IF NOT EXISTS public\.laundry_quote_messages/);
  assert.match(migration, /send_laundry_quote_message/);
  assert.match(migration, /laundry\.quote_message/);
  assert.match(service, /fetchQuoteMessages/);
  assert.match(service, /sendQuoteMessage/);
  assert.match(customerScreen, /Chat กับร้าน/);
  assert.match(customerScreen, /_QuoteChatSheet/);
  assert.match(merchantScreen, /Chat กับลูกค้า/);
  assert.match(merchantScreen, /_QuoteChatSheet/);
});

test("merchant can configure laundry quote expiry and new-request sound", () => {
  const migration = readLatestMigration(
    /laundry.*quote.*fcm.*sound.*routing.*\.sql$/,
    "laundry quote FCM sound routing migration not found",
  );
  const service = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/common/services/laundry_service.dart",
      import.meta.url,
    ),
    "utf8",
  );
  const merchantScreen = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/apps/merchant/screens/merchant_laundry_screen.dart",
      import.meta.url,
    ),
    "utf8",
  );

  assert.match(migration, /laundry_quote_sound_enabled/);
  assert.match(migration, /laundry_quote_sound_key/);
  assert.match(migration, /merchant_laundry_quote_new/);
  assert.match(migration, /play_sound/);
  assert.match(migration, /sound_key/);
  assert.match(migration, /laundry\.quote_requested/);
  assert.match(service, /fetchMerchantLaundrySettings/);
  assert.match(service, /saveMerchantLaundrySettings/);
  assert.match(service, /laundry_quote_expiry_minutes/);
  assert.match(service, /laundry_quote_sound_enabled/);
  assert.match(merchantScreen, /_LaundrySettingsCard/);
  assert.match(merchantScreen, /ตั้งค่า quote ซักผ้า/);
  assert.match(merchantScreen, /เสียงแจ้งเตือนคำขอใหม่/);
  assert.match(merchantScreen, /_quoteExpiryMinutes\.toString/);
});

test("laundry quotes auto-expire without creating driver bookings", () => {
  const migration = readLatestMigration(
    /laundry.*quote.*expiry.*cron.*\.sql$/,
    "laundry quote expiry cron migration not found",
  );

  assert.match(migration, /expire_laundry_quotes/);
  assert.match(migration, /quote_expired/);
  assert.match(migration, /status = 'quoted'/);
  assert.match(migration, /quote_expires_at <= now\(\)/);
  assert.match(migration, /cron\.schedule/);
  assert.match(migration, /laundry-quote-expire-every-minute/);
  assert.match(migration, /laundry\.quote_expired/);
});

test("laundry pickup payment rules allow cash only when customer is at pickup", () => {
  const paymentMigration = readLatestMigration(
    /laundry.*pickup.*payment.*methods.*\.sql$/,
    "laundry pickup payment methods migration not found",
  );
  const finalGuardMigration = readFileSync(
    new URL(
      "../supabase/migrations/20260611003000_laundry_pickup_payment_methods_final_guard.sql",
      import.meta.url,
    ),
    "utf8",
  );
  const service = readFileSync(
    new URL("../jedechai_delivery_new/lib/common/services/laundry_service.dart", import.meta.url),
    "utf8",
  );
  const customerScreen = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/apps/customer/screens/services/laundry_service_screen.dart",
      import.meta.url,
    ),
    "utf8",
  );

  assert.match(finalGuardMigration, /ADD COLUMN IF NOT EXISTS pickup_presence/);
  assert.match(paymentMigration, /customer_at_pickup/);
  assert.match(paymentMigration, /remote_pickup/);
  assert.match(finalGuardMigration, /payment_method.*IN \('cash', 'wallet'\)/s);
  assert.match(paymentMigration, /p_pickup_presence text DEFAULT 'remote_pickup'/);
  assert.match(paymentMigration, /invalid_pickup_presence/);
  assert.match(paymentMigration, /pickup_cash_not_allowed/);
  assert.match(paymentMigration, /self_pickup_wallet_not_allowed/);
  assert.match(paymentMigration, /COALESCE\(p_return_mode, 'delivery'\) = 'self_pickup'[\s\S]*COALESCE\(p_return_payment_method, 'cash'\) = 'wallet'/);
  assert.match(paymentMigration, /v_pickup_presence = 'remote_pickup'[\s\S]*v_payment_method <> 'wallet'/);
  assert.match(paymentMigration, /IF v_payment_method = 'wallet' THEN[\s\S]*customer_wallet_pay_booking/);
  assert.match(paymentMigration, /ELSE[\s\S]*v_wallet_result := jsonb_build_object\('success', true, 'skipped', true, 'payment_method', 'cash'\)/);
  assert.match(paymentMigration, /payment_method = v_payment_method/);
  assert.match(paymentMigration, /pickup_presence = v_pickup_presence/);
  assert.match(finalGuardMigration, /driver_confirm_laundry_pickup/);
  assert.match(finalGuardMigration, /v_booking\.driver_id IS DISTINCT FROM v_driver_id/);
  assert.match(finalGuardMigration, /v_booking\.driver_id IS DISTINCT FROM p_driver_id/);
  assert.match(finalGuardMigration, /COALESCE\(v_order\.payment_method, v_booking\.payment_method, 'wallet'\) = 'wallet'/);
  assert.match(finalGuardMigration, /COALESCE\(v_order\.payment_method, v_booking\.payment_method, 'wallet'\) = 'cash'[\s\S]*v_wallet_credit := 0/);

  assert.match(service, /acceptQuote\(/);
  assert.match(service, /String paymentMethod = 'wallet'/);
  assert.match(service, /String pickupPresence = 'remote_pickup'/);
  assert.match(service, /String returnMode = 'delivery'/);
  assert.match(service, /String returnPaymentMethod = 'cash'/);
  assert.match(service, /'p_payment_method': paymentMethod/);
  assert.match(service, /'p_pickup_presence': pickupPresence/);
  assert.match(service, /'p_return_mode': returnMode/);
  assert.match(service, /'p_return_payment_method': returnPaymentMethod/);
  assert.doesNotMatch(service, /Future<Map<String, dynamic>> acceptQuoteWithWallet/);

  assert.match(customerScreen, /paymentMethod/);
  assert.match(customerScreen, /pickupPresence/);
  assert.match(customerScreen, /returnMode/);
  assert.match(customerScreen, /returnPaymentMethod/);
  assert.match(customerScreen, /if \(returnMode == 'self_pickup' &&\s*returnPaymentMethod == 'wallet'\)/);
  assert.match(customerScreen, /returnPaymentMethod = 'cash'/);
  assert.match(customerScreen, /DropdownMenuItem\([\s\S]*value: 'cash'/);
  assert.match(customerScreen, /DropdownMenuItem\([\s\S]*value: 'wallet'/);
  assert.match(customerScreen, /customer_at_pickup/);
  assert.match(customerScreen, /remote_pickup/);
  assert.match(customerScreen, /self_pickup/);
  assert.match(customerScreen, /_laundryService\.acceptQuote\(/);
  assert.match(customerScreen, /returnMode: returnMode/);
  assert.match(customerScreen, /returnPaymentMethod: returnPaymentMethod/);
});

test("old pickup payment migration is a replay-safe no-op before laundry core", () => {
  const earlyMigration = readFileSync(
    new URL(
      "../supabase/migrations/20260610174155_laundry_pickup_payment_methods.sql",
      import.meta.url,
    ),
    "utf8",
  );

  const executableSql = earlyMigration.replace(/\/\*[\s\S]*?\*\//g, "");

  assert.match(earlyMigration, /Superseded by 20260611003000_laundry_pickup_payment_methods_final_guard\.sql/);
  assert.doesNotMatch(executableSql, /ALTER TABLE public\.laundry_orders/);
  assert.doesNotMatch(executableSql, /public\.laundry_orders%ROWTYPE/);
  assert.doesNotMatch(executableSql, /CREATE OR REPLACE FUNCTION public\.customer_accept_laundry_quote/);
});

test("laundry rollback E2E covers pickup payment guard and cash completion", () => {
  const rollbackScript = readFileSync(
    new URL("../scripts/laundry_e2e_rollback.sql", import.meta.url),
    "utf8",
  );

  assert.match(rollbackScript, /pickup_cash_not_allowed/);
  assert.match(rollbackScript, /remote_pickup/);
  assert.match(rollbackScript, /customer_at_pickup/);
  assert.match(rollbackScript, /payment_method = 'cash'/);
  assert.match(rollbackScript, /\(v_result->>'wallet_credit'\)::numeric, -1\) <> 0/);
  assert.match(rollbackScript, /cash pickup accept failed/);
  assert.match(rollbackScript, /remote pickup cash guard failed/);
  assert.match(rollbackScript, /self_pickup_wallet_not_allowed/);
  assert.match(rollbackScript, /self pickup wallet guard failed/);
  assert.match(rollbackScript, /laundry_not_ready_for_return/);
  assert.match(rollbackScript, /early return booking guard failed/);
  assert.match(rollbackScript, /merchant_update_laundry_status/);
  assert.match(rollbackScript, /pre-washing return booking guard failed/);
  assert.match(rollbackScript, /null merchant status guard failed/);
  assert.match(rollbackScript, /decimal return wallet delta mismatch/);
  assert.match(rollbackScript, /decimal return ledger mismatch/);
  assert.match(rollbackScript, /already_created/);
  assert.match(rollbackScript, /duplicate return booking changed id/);
  assert.match(rollbackScript, /WHERE id::uuid = v_outbound_booking_id/);
  assert.match(rollbackScript, /WHERE id::uuid = v_return_booking_id/);
  assert.match(rollbackScript, /pre-evidence completion was allowed/);
  assert.match(rollbackScript, /unauthorized completion was allowed/);
  assert.match(rollbackScript, /unassigned driver confirm was allowed/);
  assert.match(rollbackScript, /unassigned completion was allowed/);
  assert.match(rollbackScript, /duplicate completion changed wallet balance/);
});

test("laundry quote request sends merchant FCM on the audible order channel", () => {
  const fcmFunction = readFileSync(
    new URL("../supabase/functions/send-fcm-notification/index.ts", import.meta.url),
    "utf8",
  );
  const policy = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/common/utils/notification_payload_policy.dart",
      import.meta.url,
    ),
    "utf8",
  );
  const service = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/common/services/laundry_service.dart",
      import.meta.url,
    ),
    "utf8",
  );
  const customerScreen = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/apps/customer/screens/services/laundry_service_screen.dart",
      import.meta.url,
    ),
    "utf8",
  );

  assert.match(fcmFunction, /laundry\.quote_requested/);
  assert.match(fcmFunction, /isAllowedLaundryQuoteParticipantNotification/);
  assert.match(fcmFunction, /laundry_orders/);
  assert.match(fcmFunction, /merchant_new_order_channel_v1/);
  assert.match(policy, /laundryQuoteRequested/);
  assert.match(service, /laundry_quote_sound_enabled/);
  assert.match(customerScreen, /NotificationSender\.sendNotification/);
  assert.match(customerScreen, /persistInApp: false/);
  assert.match(customerScreen, /merchant_laundry_quote_new/);
});

test("customer laundry quote request invokes a scoped admin external notification function", () => {
  const customerScreen = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/apps/customer/screens/services/laundry_service_screen.dart",
      import.meta.url,
    ),
    "utf8",
  );

  const submitStart = customerScreen.indexOf("Future<void> _submitQuoteRequest()");
  const notifyMerchantStart = customerScreen.indexOf(
    "Future<void> _notifyMerchantQuoteRequested",
    submitStart,
  );
  const submitBody = customerScreen.slice(submitStart, notifyMerchantStart);

  assert.notEqual(submitStart, -1, "_submitQuoteRequest not found");
  assert.notEqual(notifyMerchantStart, -1, "_notifyMerchantQuoteRequested not found");
  assert.doesNotMatch(customerScreen, /AdminLineNotificationService/);
  assert.match(customerScreen, /_notifyAdminsQuoteRequested/);
  assert.match(customerScreen, /notify-laundry-quote-request/);
  assert.match(customerScreen, /'laundry_order_id':\s*laundryOrderId/);
  assert.doesNotMatch(customerScreen, /'merchant_id':\s*merchantId/);
  assert.doesNotMatch(customerScreen, /'pickup':\s*pickupAddress/);
  assert.match(submitBody, /_notifyMerchantQuoteRequested/);
  assert.match(submitBody, /_notifyAdminsQuoteRequested/);
});

test("laundry admin external notification function validates owner and derives payload server-side", () => {
  const functionPath = new URL(
    "../supabase/functions/notify-laundry-quote-request/index.ts",
    import.meta.url,
  );
  const migration = readLatestMigration(
    /laundry.*quote.*admin.*notifications.*\.sql$/,
    "laundry quote admin notification migration not found",
  );

  assert.ok(existsSync(functionPath), "notify-laundry-quote-request function missing");
  const source = readFileSync(functionPath, "utf8");

  assert.match(migration, /admin_external_notified_at timestamptz/);
  assert.match(source, /laundry_order_id/);
  assert.match(source, /auth\.getUser\(token\)/);
  assert.match(source, /\.from\("laundry_orders"\)/);
  assert.match(source, /\.eq\("id", laundryOrderId\)/);
  assert.match(source, /order\.customer_id !== user\.id/);
  assert.match(source, /order_owner_required/);
  assert.match(source, /\.from\("profiles"\)/);
  assert.match(source, /merchantName/);
  assert.match(source, /laundryItemCount/);
  assert.match(source, /pickupAddressSummary/);
  assert.match(source, /sendAdminLineNotification/);
  assert.match(source, /sendAdminTelegramNotification/);
  assert.match(source, /Promise\.allSettled/);
  assert.match(source, /AbortSignal\.timeout\(ADMIN_NOTIFICATION_TIMEOUT_MS\)/);
  assert.match(source, /admin_external_notification_claimed_at/);
  assert.match(source, /admin_external_notified_at/);
  assert.match(source, /\.is\("admin_external_notification_claimed_at", null\)/);
  assert.match(source, /already_claimed/);
  assert.match(source, /no_channels_enabled/);
  assert.doesNotMatch(source, /customer_note/);

  const claimStart = source.indexOf("const { data: claim");
  const sendStart = source.indexOf("const results = await Promise.allSettled");
  assert.notEqual(claimStart, -1, "atomic notification claim not found");
  assert.notEqual(sendStart, -1, "notification send block not found");
  assert.ok(claimStart < sendStart, "idempotency claim must happen before sending");
});

test("laundry completion migration releases wallet payouts without generic commission", () => {
  const completionMigration = readFileSync(
    new URL(
      "../supabase/migrations/20260610213500_laundry_completion_wallet_release.sql",
      import.meta.url,
    ),
    "utf8",
  );

  assert.match(completionMigration, /complete_laundry_booking/);
  assert.match(completionMigration, /merchant_net_amount/);
  assert.match(completionMigration, /delivery_fee_outbound/);
  assert.match(completionMigration, /delivery_fee_return/);
  assert.match(completionMigration, /wallet_topup/);
  assert.match(completionMigration, /'laundry_payout'/);
  assert.match(completionMigration, /'release'/);
});

test("laundry completion accepts in_transit after pickup evidence", () => {
  const migration = readLatestMigration(
    /laundry.*complete.*in.*transit.*\.sql$/,
    "laundry completion in_transit migration not found",
  );

  assert.match(migration, /complete_laundry_booking/);
  assert.match(migration, /v_booking\.status NOT IN \([^)]*'in_transit'/s);
});

test("laundry completion duplicate payout check casts related booking id", () => {
  const migration = readLatestMigration(
    /laundry.*complete.*related.*booking.*cast.*\.sql$/,
    "laundry completion related booking cast migration not found",
  );

  assert.match(migration, /complete_laundry_booking/);
  assert.match(migration, /wt\.related_booking_id = p_booking_id::text/);
});

test("latest laundry completion RPC is replay-safe and enforces auth plus evidence", () => {
  const finalGuard = new URL(
    "../supabase/migrations/20260611003000_laundry_pickup_payment_methods_final_guard.sql",
    import.meta.url,
  );
  assert.ok(existsSync(finalGuard), "latest laundry pickup/payment final guard migration not found");

  const migration = readFileSync(
    finalGuard,
    "utf8",
  );

  assert.match(migration, /customer_accept_laundry_quote/);
  assert.match(migration, /driver_confirm_laundry_pickup/);
  assert.match(migration, /v_booking\.driver_id IS DISTINCT FROM v_driver_id/);
  assert.match(migration, /complete_laundry_booking/);
  assert.match(migration, /auth\.uid\(\)/);
  assert.match(migration, /auth\.role\(\)/);
  assert.match(migration, /v_actor_id IS DISTINCT FROM p_driver_id/);
  assert.match(migration, /v_booking\.driver_id IS DISTINCT FROM p_driver_id/);
  assert.match(migration, /v_booking\.status <> 'in_transit'/);
  assert.match(migration, /pickup_evidence_url IS NULL/);
  assert.match(migration, /pickup_evidence_uploaded_at IS NULL/);
  assert.match(migration, /wt\.related_booking_id = p_booking_id::text/);
  assert.match(migration, /v_wallet_credit := 0/);
  assert.match(migration, /wallet_topup/);
});

test("driver navigation requires laundry pickup evidence before starting delivery", () => {
  const driverNavigation = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/apps/driver/screens/driver_navigation_screen.dart",
      import.meta.url,
    ),
    "utf8",
  );

  assert.match(driverNavigation, /LaundryService/);
  assert.match(driverNavigation, /ImagePicker/);
  assert.match(driverNavigation, /laundry-evidence/);
  assert.match(driverNavigation, /confirmPickupWithEvidence/);
  assert.match(driverNavigation, /ถ่ายรูปและรับผ้า/);
});

test("booking service routes laundry completion to the laundry settlement RPC", () => {
  const bookingService = readFileSync(
    new URL("../jedechai_delivery_new/lib/common/services/booking_service.dart", import.meta.url),
    "utf8",
  );

  assert.match(bookingService, /booking\.serviceType == 'laundry'/);
  assert.match(bookingService, /complete_laundry_booking/);
  assert.match(bookingService, /completeLaundryBooking RPC สำเร็จ/);
});

test("laundry driver discovery includes outbound and return jobs", () => {
  const migration = readLaundryCoreMigration();

  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.get_nearby_bookings/);
  assert.match(migration, /service_type = 'laundry'/);
  assert.match(migration, /laundry_leg IN \('outbound', 'return'\)/);
  assert.match(migration, /status IN \('pending', 'ready_for_pickup', 'preparing'\)/);
});

test("laundry frontend service contract exists for customer, merchant, and driver flows", () => {
  const servicePath = new URL(
    "../jedechai_delivery_new/lib/common/services/laundry_service.dart",
    import.meta.url,
  );

  assert.ok(existsSync(servicePath), "LaundryService is missing");
  const service = readFileSync(servicePath, "utf8");

  assert.match(service, /class LaundryService/);
  assert.match(service, /fetchLaundryMerchants/);
  assert.match(service, /\.eq\('approval_status', 'approved'\)/);
  assert.match(service, /createQuoteRequest/);
  assert.match(service, /sendMerchantQuote/);
  assert.match(service, /acceptQuote\(/);
  assert.match(service, /createReturnBooking/);
  assert.match(service, /confirmPickupWithEvidence/);
});

test("admin web exposes a Laundry inspection page", () => {
  const adminIndex = readFileSync(
    new URL("../admin-web/src/pages/index.js", import.meta.url),
    "utf8",
  );
  const adminNav = readFileSync(new URL("../admin-web/index.html", import.meta.url), "utf8");
  const wrapperPath = new URL("../admin-web/src/pages/laundry.js", import.meta.url);
  const pagePath = new URL("../admin-web/src/pages/laundryPage.js", import.meta.url);
  const merchantsPage = readFileSync(
    new URL("../admin-web/src/pages/merchantsPage.js", import.meta.url),
    "utf8",
  );

  assert.ok(existsSync(wrapperPath), "admin laundry wrapper is missing");
  assert.ok(existsSync(pagePath), "admin laundry page is missing");
  assert.match(adminIndex, /registerLaundryPage/);
  assert.match(adminNav, /data-page="laundry"/);

  const page = readFileSync(pagePath, "utf8");
  assert.match(page, /renderLaundryPage/);
  assert.match(page, /laundry_orders/);
  assert.match(page, /outbound_booking/);
  assert.match(page, /return_booking/);
  assert.match(page, /platform_gp_amount/);
  assert.match(page, /merchant_net_amount/);
  assert.match(page, /payment_method/);
  assert.match(page, /pickup_presence/);
  assert.match(page, /paymentLabel/);
  assert.match(page, /pickupPresenceLabel/);
  assert.match(page, /\\u0e27\\u0e34\\u0e18\\u0e35\\u0e0a\\u0e33\\u0e23\\u0e30/);
  assert.match(page, /\\u0e08\\u0e38\\u0e14\\u0e23\\u0e31\\u0e1a\\u0e1c\\u0e49\\u0e32/);
  assert.match(page, /remote_pickup/);
  assert.match(page, /customer_at_pickup/);
  assert.match(page, /loadLaundryDrivers/);
  assert.match(page, /assignLaundryBookingDriver/);
  assert.match(page, /laundryAssignDriverSelect/);
  assert.match(page, /assign_order/);
  assert.match(page, /driver_id/);

  assert.match(merchantsPage, /merchant_service_types/);
  assert.doesNotMatch(merchantsPage, /toggleMerchantServiceType/);
  assert.match(merchantsPage, /editMrcServiceType/);
  assert.match(merchantsPage, /merchant_service_types:\s*\[serviceType\]/);
  assert.match(merchantsPage, /Food/);
  assert.match(merchantsPage, /Laundry/);
});

test("admin web separates Food and Laundry GP controls", () => {
  const merchantsPage = readFileSync(
    new URL("../admin-web/src/pages/merchantsPage.js", import.meta.url),
    "utf8",
  );
  const settingsBridge = readFileSync(
    new URL("../admin-web/src/pages/settingsActionsBridge.js", import.meta.url),
    "utf8",
  );
  const legacyApp = readFileSync(new URL("../admin-web/app.legacy.js", import.meta.url), "utf8");
  const adminActions = readFileSync(
    new URL("../supabase/functions/admin-actions/index.ts", import.meta.url),
    "utf8",
  );

  assert.match(merchantsPage, /syncMerchantServiceTypeFields/);
  assert.match(merchantsPage, /onchange="syncMerchantServiceTypeFields\(\)"/);
  assert.match(merchantsPage, /data-merchant-service-panel="food"/);
  assert.match(merchantsPage, /data-merchant-service-panel="laundry"/);
  assert.match(merchantsPage, /editMrcLaundryGpDriverRate/);
  assert.match(merchantsPage, /laundry_gp_driver_rate:/);
  assert.match(merchantsPage, /Laundry GP ให้คนขับ/);

  assert.match(settingsBridge, /settLaundryGpDriverRate/);
  assert.match(settingsBridge, /laundry_gp_driver_rate_default/);
  assert.match(legacyApp, /settLaundryGpDriverRate/);
  assert.match(legacyApp, /laundry_gp_driver_rate_default/);
  assert.match(adminActions, /"laundry_gp_driver_rate"/);
});

test("customer food and laundry screens isolate merchant service types", () => {
  const laundryService = readFileSync(
    new URL("../jedechai_delivery_new/lib/common/services/laundry_service.dart", import.meta.url),
    "utf8",
  );
  const foodServiceScreen = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/apps/customer/screens/services/food_service_screen.dart",
      import.meta.url,
    ),
    "utf8",
  );
  const foodHomeScreen = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/apps/customer/screens/services/food_home_screen.dart",
      import.meta.url,
    ),
    "utf8",
  );

  assert.match(laundryService, /\.contains\('merchant_service_types', \['laundry'\]\)/);
  assert.match(foodServiceScreen, /\.contains\('merchant_service_types', \['food'\]\)/);
  assert.match(foodHomeScreen, /\.contains\('merchant_service_types', \['food'\]\)/);
});

test("customer laundry flow uses store cards, package list, then request form", () => {
  const screen = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/apps/customer/screens/services/laundry_service_screen.dart",
      import.meta.url,
    ),
    "utf8",
  );

  assert.match(screen, /_selectedMerchantId = null/);
  assert.match(screen, /_selectedPackageId = null/);
  assert.match(screen, /_buildMerchantCards/);
  assert.match(screen, /_buildMerchantCard/);
  assert.match(screen, /_buildPackageList/);
  assert.match(screen, /_buildPackageCard/);
  assert.match(screen, /เลือกร้านซักผ้า/);
  assert.match(screen, /เลือกแพ็กเกจ/);
  assert.match(screen, /if \(_selectedMerchantId == null\) \.\.\.\[/);
  assert.match(screen, /if \(_selectedMerchantId != null &&[\s\S]*?_selectedPackageId == null\) \.\.\.\[/);
  assert.match(screen, /if \(_selectedPackageId != null\) \.\.\.\[/);
  assert.match(screen, /_buildPickupForm\(\)/);
  assert.match(screen, /ส่งคำขอประเมินราคา/);
  assert.doesNotMatch(screen, /Widget _buildMerchantSelector\(\)[\s\S]*?DropdownButtonFormField<String>/);
  assert.doesNotMatch(screen, /Widget _buildPackageSelector\(\)[\s\S]*?DropdownButtonFormField<String>/);
});

test("admin web can manage laundry packages for merchant stores", () => {
  const page = readFileSync(
    new URL("../admin-web/src/pages/laundryPage.js", import.meta.url),
    "utf8",
  );
  const adminActions = readFileSync(
    new URL("../supabase/functions/admin-actions/index.ts", import.meta.url),
    "utf8",
  );

  assert.match(page, /loadLaundryPackageMerchants/);
  assert.match(page, /loadLaundryPackages/);
  assert.match(page, /renderLaundryPackageManager/);
  assert.match(page, /openLaundryPackageDialog/);
  assert.match(page, /saveLaundryPackage/);
  assert.match(page, /deleteLaundryPackage/);
  assert.match(page, /manage_laundry_package/);
  assert.match(page, /delete_laundry_package/);
  assert.match(page, /base_price/);
  assert.match(page, /แพ็กเกจซักผ้า/);

  assert.match(adminActions, /case "manage_laundry_package"/);
  assert.match(adminActions, /case "delete_laundry_package"/);
  assert.match(adminActions, /handleManageLaundryPackage/);
  assert.match(adminActions, /handleDeleteLaundryPackage/);
  assert.match(adminActions, /from\("laundry_packages"\)\.insert/);
  assert.match(adminActions, /from\("laundry_packages"\)\.update/);
  assert.match(adminActions, /base_price/);
  assert.match(adminActions, /is_active: false/);
});

test("admin assign order syncs laundry order status by leg", () => {
  const adminActions = readFileSync(
    new URL("../supabase/functions/admin-actions/index.ts", import.meta.url),
    "utf8",
  );

  assert.match(adminActions, /handleAssignOrder/);
  assert.match(adminActions, /laundry_order_id/);
  assert.match(adminActions, /laundry_leg/);
  assert.match(adminActions, /outbound_assigned/);
  assert.match(adminActions, /return_assigned/);
  assert.match(adminActions, /UPDATE public\.laundry_orders|from\("laundry_orders"\)/);
});

test("driver service type settings can opt into laundry jobs", () => {
  const driverSettings = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/apps/driver/screens/driver_service_type_settings.dart",
      import.meta.url,
    ),
    "utf8",
  );

  assert.match(driverSettings, /'laundry'/);
  assert.match(driverSettings, /local_laundry_service_rounded|Laundry|ซัก/);
});

test("driver dashboard accepts and labels laundry jobs", () => {
  const driverDashboard = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/apps/driver/screens/driver_dashboard_screen.dart",
      import.meta.url,
    ),
    "utf8",
  );

  assert.match(driverDashboard, /case 'laundry'/);
  assert.match(driverDashboard, /ซักผ้า/);
  assert.match(driverDashboard, /job\.serviceType != 'laundry'/);
});

test("customer home exposes laundry quote request flow", () => {
  const customerHome = readFileSync(
    new URL("../jedechai_delivery_new/lib/apps/customer/screens/customer_home_screen.dart", import.meta.url),
    "utf8",
  );
  const screenPath = new URL(
    "../jedechai_delivery_new/lib/apps/customer/screens/services/laundry_service_screen.dart",
    import.meta.url,
  );

  assert.ok(existsSync(screenPath), "customer laundry service screen is missing");
  assert.match(customerHome, /LaundryServiceScreen/);
  assert.match(customerHome, /local_laundry_service/);

  const screen = readFileSync(screenPath, "utf8");
  assert.match(screen, /LaundryService/);
  assert.match(screen, /fetchLaundryMerchants/);
  assert.match(screen, /fetchLaundryDeliveryRate/);
  assert.match(screen, /fetchMerchantPackages/);
  assert.match(screen, /createQuoteRequest/);
  assert.match(screen, /fetchMyLaundryOrders/);
  assert.match(screen, /acceptQuote\(/);
  assert.match(screen, /_sortMerchantsByPickup/);
  assert.match(screen, /_estimated_delivery_fee/);
  assert.match(screen, /_distance_km/);
  assert.match(screen, /เลือกวิธีชำระ/);
  assert.match(screen, /paymentMethod/);
  assert.match(screen, /pickupPresence/);
  assert.match(screen, /return_payment_method/);
  assert.match(screen, /Geolocator/);

  const service = readFileSync(
    new URL("../jedechai_delivery_new/lib/common/services/laundry_service.dart", import.meta.url),
    "utf8",
  );
  assert.match(service, /fetchLaundryDeliveryRate/);
  assert.match(service, /service_rates/);
});

test("merchant app exposes laundry quote management flow", () => {
  const merchantMain = readFileSync(
    new URL("../jedechai_delivery_new/lib/apps/merchant/screens/merchant_main_screen.dart", import.meta.url),
    "utf8",
  );
  const screenPath = new URL(
    "../jedechai_delivery_new/lib/apps/merchant/screens/merchant_laundry_screen.dart",
    import.meta.url,
  );

  assert.ok(existsSync(screenPath), "merchant laundry screen is missing");
  assert.match(merchantMain, /MerchantLaundryScreen/);
  assert.match(merchantMain, /local_laundry_service/);

  const screen = readFileSync(screenPath, "utf8");
  assert.match(screen, /fetchMerchantLaundryOrders/);
  assert.match(screen, /fetchMyMerchantPackages/);
  assert.match(screen, /saveMerchantPackage/);
  assert.match(screen, /disableMerchantPackage/);
  assert.match(screen, /sendMerchantQuote/);
  assert.match(screen, /createReturnBooking/);
  assert.match(screen, /แพ็กเกจซักผ้า/);
  assert.match(screen, /เพิ่มแพ็กเกจซักผ้า/);
  assert.match(screen, /ปิดใช้งานแพ็กเกจ/);
  assert.match(screen, /ซักเสร็จ \/ สร้างงานขากลับ/);
  assert.match(screen, /laundry_amount/);
  assert.match(screen, /delivery_fee_outbound/);
  assert.match(screen, /delivery_fee_return/);
  assert.match(screen, /package\?\['base_price'\]/);
  assert.match(screen, /package\['base_price'\]/);
  assert.doesNotMatch(screen, /starting_price/);

  const service = readFileSync(
    new URL("../jedechai_delivery_new/lib/common/services/laundry_service.dart", import.meta.url),
    "utf8",
  );
  assert.match(service, /fetchMyMerchantPackages/);
  assert.match(service, /saveMerchantPackage/);
  assert.match(service, /disableMerchantPackage/);
  assert.match(service, /fetchMerchantLaundrySettings/);
  assert.match(service, /saveMerchantLaundrySettings/);
  assert.match(service, /from\('laundry_packages'\)\.insert/);
  assert.match(service, /from\('laundry_packages'\)[\s\S]*\.update/);
});

test("merchant can create laundry return booking only after cloth reaches merchant", () => {
  const guardMigration = readLatestMigration(
    /laundry.*(?:return.*booking.*ready.*status.*guard|merchant.*washing.*status).*\.sql$/,
    "laundry return booking ready status guard migration not found",
  );
  const screen = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/apps/merchant/screens/merchant_laundry_screen.dart",
      import.meta.url,
    ),
    "utf8",
  );

  assert.match(guardMigration, /CREATE OR REPLACE FUNCTION public\.create_laundry_return_booking/);
  assert.match(guardMigration, /laundry_not_ready_for_return/);
  assert.match(guardMigration, /v_order\.status NOT IN \('washing', 'ready_for_return'\)/);
  assert.doesNotMatch(guardMigration, /v_order\.status NOT IN \([^)]*'at_merchant'/);
  assert.doesNotMatch(guardMigration, /v_order\.status NOT IN \([^)]*'outbound_picked_up'/);
  assert.match(screen, /final canCreateReturn =[\s\S]*const \{\s*'washing',\s*'ready_for_return',\s*\}\.contains\(status\);/);
  assert.doesNotMatch(screen, /final canCreateReturn =[\s\S]*const \{\s*'at_merchant'[\s\S]*\}\.contains\(status\);/);
  assert.doesNotMatch(screen, /final canCreateReturn =[\s\S]*const \{\s*'outbound_picked_up'[\s\S]*\}\.contains\(status\);/);
});

test("merchant can explicitly start washing before creating laundry return booking", () => {
  const stageMigration = readLatestMigration(
    /laundry.*merchant.*washing.*status.*\.sql$/,
    "laundry merchant washing status migration not found",
  );
  const service = readFileSync(
    new URL("../jedechai_delivery_new/lib/common/services/laundry_service.dart", import.meta.url),
    "utf8",
  );
  const screen = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/apps/merchant/screens/merchant_laundry_screen.dart",
      import.meta.url,
    ),
    "utf8",
  );

  assert.match(stageMigration, /CREATE OR REPLACE FUNCTION public\.merchant_update_laundry_status/);
  assert.match(stageMigration, /p_status text/);
  assert.match(stageMigration, /invalid_laundry_stage/);
  assert.match(stageMigration, /COALESCE\(p_status, ''\) NOT IN \('washing'\)/);
  assert.match(stageMigration, /p_status = 'washing'[\s\S]*v_order\.status <> 'at_merchant'/);
  assert.match(stageMigration, /v_delivery_fee_return := ROUND\(COALESCE\(p_delivery_fee_return, 0\)::numeric, 2\)/);
  assert.match(stageMigration, /v_old_balance < v_delivery_fee_return/);
  assert.match(stageMigration, /v_new_balance := v_old_balance - v_delivery_fee_return/);
  assert.doesNotMatch(stageMigration, /v_old_balance < p_delivery_fee_return/);
  assert.doesNotMatch(stageMigration, /v_new_balance := v_old_balance - p_delivery_fee_return/);
  assert.match(stageMigration, /UPDATE public\.laundry_orders[\s\S]*status = p_status/);
  assert.match(service, /updateMerchantLaundryStatus/);
  assert.match(service, /'merchant_update_laundry_status'/);
  assert.match(service, /'p_status': status/);
  assert.match(screen, /_startWashing/);
  assert.match(screen, /updateMerchantLaundryStatus/);
  assert.match(screen, /status == 'at_merchant'/);
  assert.match(screen, /เริ่มซัก/);
});

test("laundry cancel/refund and stage fixes cover hold refund, self-pickup completion, and re-quote", () => {
  const migration = readLatestMigration(
    /laundry.*cancel.*refund.*stage.*fixes.*\.sql$/,
    "laundry cancel refund stage fixes migration not found",
  );
  const service = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/common/services/laundry_service.dart",
      import.meta.url,
    ),
    "utf8",
  );
  const customerScreen = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/apps/customer/screens/services/laundry_service_screen.dart",
      import.meta.url,
    ),
    "utf8",
  );
  const merchantScreen = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/apps/merchant/screens/merchant_laundry_screen.dart",
      import.meta.url,
    ),
    "utf8",
  );
  const fcmFunction = readFileSync(
    new URL("../supabase/functions/send-fcm-notification/index.ts", import.meta.url),
    "utf8",
  );

  // Admin force cancel: text cast fix, hold refund, laundry order sync.
  assert.match(migration, /admin_force_cancel_booking_with_wallet_refund/);
  assert.match(migration, /refund_booking_to_customer_wallet/);
  assert.match(migration, /related_booking_id = p_booking_id::text/);
  assert.match(migration, /wt\.type = 'hold'/);
  assert.match(migration, /hold_already_released/);
  assert.match(migration, /laundry_leg = 'outbound'/);
  assert.match(migration, /laundry_leg = 'return'/);
  assert.match(migration, /return_booking_id = NULL/);
  assert.match(migration, /return_wallet_hold_transaction_id = NULL/);

  // Ledger-only refund hardening is preserved (now accepting hold rows) and
  // the customer self-cancel path gets the same ::text cast fix.
  assert.match(migration, /wallet_refund_amount_mismatch/);
  assert.match(migration, /refund_reconciliation_required/);
  assert.match(migration, /v_ledger_amount/);
  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.cancel_wallet_booking_with_refund/);
  assert.match(migration, /wt\.related_booking_id = p_booking_id::text\s+AND wt\.type = 'payment'/);

  // Self-pickup orders can now be completed by the merchant.
  assert.match(migration, /merchant_update_laundry_status/);
  assert.match(migration, /NOT IN \('washing', 'completed'\)/);
  assert.match(migration, /v_order\.return_mode = 'self_pickup' AND v_order\.status = 'ready_for_return'/);
  assert.match(migration, /laundry\.completed/);
  assert.match(merchantScreen, /_completeSelfPickup/);
  assert.match(merchantScreen, /ลูกค้ารับผ้าแล้ว \/ ปิดงาน/);

  // Expired quotes can be re-sent.
  assert.match(migration, /NOT IN \('quote_requested', 'quoted', 'quote_expired'\)/);
  assert.match(merchantScreen, /status == 'quote_expired'/);
  assert.match(merchantScreen, /ส่ง quote ใหม่/);

  // Order queries are scoped to the signed-in owner instead of RLS alone.
  assert.match(service, /\.eq\('customer_id', customerId\)/);
  assert.match(service, /\.eq\('merchant_id', merchantId\)/);
  assert.match(service, /phone_number/);

  // Sound toggle mutes the alert channel without dropping the push, on both
  // the FCM server channel and the app's local notification paths.
  const payloadPolicy = readFileSync(
    new URL(
      "../jedechai_delivery_new/lib/common/utils/notification_payload_policy.dart",
      import.meta.url,
    ),
    "utf8",
  );
  assert.match(customerScreen, /'play_sound': soundEnabled \? 'true' : 'false'/);
  assert.doesNotMatch(customerScreen, /if \(!soundEnabled\) return;/);
  assert.match(fcmFunction, /String\(data\?\.play_sound \?\? ""\)\.toLowerCase\(\) === "false"/);
  assert.match(payloadPolicy, /static bool isSoundMuted\(Map<String, dynamic> data\)/);
  assert.match(payloadPolicy, /if \(isSoundMuted\(data\)\) return false;/);

  // Failed quote requests clean up already-uploaded attachments.
  assert.match(customerScreen, /_removeUploadedQuoteAttachments/);

  // Cash completions settle platform GP from the driver wallet like food.
  const rollbackScript = readFileSync(
    new URL("../scripts/laundry_e2e_rollback.sql", import.meta.url),
    "utf8",
  );
  assert.match(migration, /wallet_deduct/);
  assert.match(migration, /v_cash_commission := v_app_earnings;/);
  assert.match(migration, /commission_deduct_failed/);
  assert.match(migration, /wt\.type = 'commission'/);
  assert.match(rollbackScript, /cash_commission/);
});

test("runtime profile lookups avoid PostgREST relationship embeds that can PGRST200", () => {
  const riskyFiles = [
    "../jedechai_delivery_new/lib/common/services/admin_service.dart",
    "../jedechai_delivery_new/lib/common/services/realtime_service.dart",
    "../jedechai_delivery_new/lib/common/services/ticket_service.dart",
  ];
  const riskyRelationshipPattern =
    /profiles!(inner|user_id|driver_id)|\b(customer_id|merchant_id|driver_id)\s*\(/;

  for (const file of riskyFiles) {
    const source = readFileSync(new URL(file, import.meta.url), "utf8");
    assert.doesNotMatch(
      source,
      riskyRelationshipPattern,
      `${file} must not rely on PostgREST relationship embeds for profile ids`,
    );
  }
});
