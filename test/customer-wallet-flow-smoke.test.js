import test from "node:test";
import assert from "node:assert/strict";
import { existsSync, readdirSync, readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";

const repoRoot = fileURLToPath(new URL("../", import.meta.url));
const migrationsDir = join(repoRoot, "supabase", "migrations");
const withdrawalServiceUrl = new URL(
  "../jedechai_delivery_new/lib/common/services/withdrawal_service.dart",
  import.meta.url,
);
const paymentServiceUrl = new URL(
  "../jedechai_delivery_new/lib/common/services/payment_service.dart",
  import.meta.url,
);
const foodCheckoutUrl = new URL(
  "../jedechai_delivery_new/lib/apps/customer/screens/services/food_checkout_screen.dart",
  import.meta.url,
);
const paymentScreenUrl = new URL(
  "../jedechai_delivery_new/lib/apps/customer/screens/services/payment_screen.dart",
  import.meta.url,
);

const customerWalletScreenUrl = new URL(
  "../jedechai_delivery_new/lib/apps/customer/screens/customer_wallet_screen.dart",
  import.meta.url,
);

const customerAccountScreenUrl = new URL(
  "../jedechai_delivery_new/lib/apps/customer/screens/account_screen.dart",
  import.meta.url,
);
const customerHomeScreenUrl = new URL(
  "../jedechai_delivery_new/lib/apps/customer/screens/customer_home_screen.dart",
  import.meta.url,
);

const adminTopupsPageUrl = new URL("../admin-web/src/pages/topupsPage.js", import.meta.url);
const adminWithdrawalsPageUrl = new URL("../admin-web/src/pages/withdrawalsPage.js", import.meta.url);
const adminCustomerWalletsPageUrl = new URL("../admin-web/src/pages/customerWalletsPage.js", import.meta.url);
const adminPagesIndexUrl = new URL("../admin-web/src/pages/index.js", import.meta.url);
const adminMainUrl = new URL("../admin-web/src/main.js", import.meta.url);
const adminIndexHtmlUrl = new URL("../admin-web/index.html", import.meta.url);
const adminRouterMetaUrl = new URL("../admin-web/src/router/meta.js", import.meta.url);
const adminLegacyUrl = new URL("../admin-web/app.legacy.js", import.meta.url);
const adminActionsUrl = new URL("../supabase/functions/admin-actions/index.ts", import.meta.url);

function readCustomerWalletMigration() {
  const fileName = readdirSync(migrationsDir)
    .filter((name) => /customer_wallet.*payment.*refund.*withdrawal.*\.sql$/.test(name))
    .sort()
    .at(-1);
  assert.ok(fileName, "customer wallet payment/refund/withdrawal migration not found");
  const filePath = join(migrationsDir, fileName);
  assert.ok(existsSync(filePath), `migration missing: ${fileName}`);
  return readFileSync(filePath, "utf8");
}

function readCustomerWalletCancelMigration() {
  const fileName = readdirSync(migrationsDir)
    .filter((name) => /customer_wallet_cancel_refund\.sql$/.test(name))
    .sort()
    .at(-1);
  assert.ok(fileName, "customer wallet cancel/refund migration not found");
  const filePath = join(migrationsDir, fileName);
  assert.ok(existsSync(filePath), `migration missing: ${fileName}`);
  return readFileSync(filePath, "utf8");
}

function readCustomerWalletHardeningMigration() {
  const fileName = readdirSync(migrationsDir)
    .filter((name) => /customer_wallet.*hardening.*\.sql$/.test(name))
    .sort()
    .at(-1);
  assert.ok(fileName, "customer wallet hardening migration not found");
  const filePath = join(migrationsDir, fileName);
  assert.ok(existsSync(filePath), `migration missing: ${fileName}`);
  return readFileSync(filePath, "utf8");
}

function readCustomerWalletPayableGuardMigration() {
  const fileName = readdirSync(migrationsDir)
    .filter((name) => /customer_wallet.*payable.*guard.*\.sql$/.test(name))
    .sort()
    .at(-1);
  assert.ok(fileName, "customer wallet payable guard migration not found");
  const filePath = join(migrationsDir, fileName);
  assert.ok(existsSync(filePath), `migration missing: ${fileName}`);
  return readFileSync(filePath, "utf8");
}

function readCustomerWalletRefundLedgerOnlyMigration() {
  const fileName = readdirSync(migrationsDir)
    .filter((name) => /customer_wallet.*refund.*ledger.*only.*\.sql$/.test(name))
    .sort()
    .at(-1);
  assert.ok(fileName, "customer wallet refund ledger-only migration not found");
  const filePath = join(migrationsDir, fileName);
  assert.ok(existsSync(filePath), `migration missing: ${fileName}`);
  return readFileSync(filePath, "utf8");
}

function readCustomerWalletInvalidRefundCleanupMigration() {
  const fileName = readdirSync(migrationsDir)
    .filter((name) => /customer_wallet.*invalid.*refund.*cleanup.*\.sql$/.test(name))
    .sort()
    .at(-1);
  assert.ok(fileName, "customer wallet invalid refund cleanup migration not found");
  const filePath = join(migrationsDir, fileName);
  assert.ok(existsSync(filePath), `migration missing: ${fileName}`);
  return readFileSync(filePath, "utf8");
}

test("customer wallet migration adds atomic pay, refund, and withdrawal RPCs", () => {
  const migration = readCustomerWalletMigration();

  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.customer_wallet_pay_booking/);
  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.create_wallet_withdrawal_request/);
  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.refund_booking_to_customer_wallet/);
  assert.match(migration, /SECURITY DEFINER/);
  assert.match(migration, /SET search_path = public/);
});

test("customer wallet payment blocks insufficient balance and records booking payment", () => {
  const migration = readCustomerWalletMigration();

  assert.match(migration, /FOR UPDATE/);
  assert.match(migration, /insufficient_balance/);
  assert.match(migration, /v_old_balance\s*<\s*p_amount/);
  assert.match(migration, /wallet_transactions[\s\S]*-p_amount[\s\S]*'payment'/);
  assert.match(migration, /related_booking_id[\s\S]*p_booking_id/);
});

test("customer wallet payment validates client amount against server payable total", () => {
  const migration = readCustomerWalletHardeningMigration();

  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.customer_wallet_pay_booking/);
  assert.match(migration, /discount_amount/);
  assert.match(migration, /coupon_usages/);
  assert.match(migration, /v_expected_amount/);
  assert.match(migration, /amount_mismatch/);
  assert.match(migration, /ABS\(p_amount - v_expected_amount\) > 0\.01/);
  assert.match(migration, /v_old_balance < v_expected_amount[\s\S]*v_new_balance := v_old_balance - v_expected_amount/);
  assert.doesNotMatch(migration, /v_old_balance < p_amount[\s\S]*v_new_balance := v_old_balance - p_amount/);
});

test("customer wallet payment rejects non-payable or non-wallet bookings", () => {
  const migration = readCustomerWalletPayableGuardMigration();

  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.customer_wallet_pay_booking/);
  assert.match(migration, /status/);
  assert.match(migration, /booking_not_payable/);
  assert.match(migration, /cancelled/);
  assert.match(migration, /completed/);
  assert.match(migration, /payment_method_mismatch/);
  assert.match(migration, /lower\(COALESCE\(v_booking\.payment_method, ''\)\) NOT IN \('', 'wallet'\)/);
});

test("customer withdrawal request has minimum 100 and deducts wallet while pending", () => {
  const migration = readCustomerWalletMigration();

  assert.match(migration, /p_amount\s*<\s*100/);
  assert.match(migration, /minimum_withdrawal_amount/);
  assert.match(migration, /withdrawal_requests[\s\S]*status[\s\S]*'pending'/);
  assert.match(migration, /wallet_transactions[\s\S]*-p_amount[\s\S]*'withdrawal_pending'/);
});

test("customer refund is idempotent per booking and credits wallet", () => {
  const migration = readCustomerWalletMigration();

  assert.match(migration, /already_refunded/);
  assert.match(migration, /wallet_transactions[\s\S]*type\s*=\s*'refund'[\s\S]*related_booking_id\s*=\s*p_booking_id/);
  assert.match(migration, /wallet_transactions[\s\S]*p_amount[\s\S]*'refund'/);
});

test("customer wallet RPC permissions match client and admin usage", () => {
  const migration = readCustomerWalletMigration();

  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.customer_wallet_pay_booking\(uuid, uuid, numeric, text\) TO authenticated, service_role/);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.create_wallet_withdrawal_request\(uuid, numeric, text, text, text\) TO authenticated, service_role/);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.refund_booking_to_customer_wallet\(uuid, numeric, text\) TO service_role/);
});

test("customer wallet cancellation uses owner-guarded RPC and refunds wallet payment", () => {
  const migration = readCustomerWalletCancelMigration();
  const bookingService = readFileSync(
    new URL("../jedechai_delivery_new/lib/common/services/booking_service.dart", import.meta.url),
    "utf8",
  );

  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.cancel_wallet_booking_with_refund/);
  assert.match(migration, /auth\.uid\(\)/);
  assert.match(migration, /customer_id\s*<>\s*v_auth_uid/);
  assert.match(migration, /ARRAY\['pending', 'pending_merchant', 'preparing'\]/);
  assert.match(migration, /payment_method\s*=\s*'wallet'/);
  assert.match(migration, /refund_booking_to_customer_wallet/);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.cancel_wallet_booking_with_refund\(uuid, text\) TO authenticated/);
  assert.match(bookingService, /cancel_wallet_booking_with_refund/);
  assert.doesNotMatch(bookingService, /from\('bookings'\)\.update\(\{[\s\S]*'status': 'cancelled'[\s\S]*\}\)\.eq\('id', bookingId\)/);
});

test("customer wallet refunds are based only on the original wallet payment ledger", () => {
  const migration = readCustomerWalletRefundLedgerOnlyMigration();

  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.refund_booking_to_customer_wallet/);
  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.cancel_wallet_booking_with_refund/);
  assert.match(migration, /v_existing_refund_amount/);
  assert.match(migration, /SUM\(ABS\(wt\.amount\)\)/);
  assert.match(migration, /wallet_payment_not_found/);
  assert.match(migration, /refund_reconciliation_required/);
  assert.match(migration, /wallet_refund_amount_mismatch/);
  assert.match(migration, /type\s*=\s*'payment'/);
  assert.match(migration, /amount\s*<\s*0/);
  assert.match(migration, /related_booking_id\s*=\s*p_booking_id/);
  assert.match(migration, /wallet_id\s*=\s*v_wallet_id/);
  assert.match(migration, /ABS\(v_existing_refund_amount - v_wallet_payment_amount\) > 0\.01/);
  assert.match(migration, /ABS\(p_amount - v_wallet_payment_amount\) > 0\.01/);
  assert.doesNotMatch(migration, /ORDER BY wt\.created_at ASC[\s\S]*LIMIT 1/);
  assert.doesNotMatch(migration, /v_booking\.price \+ v_booking\.delivery_fee/);
  assert.doesNotMatch(migration, /ELSE v_booking\.price/);
});

test("invalid legacy customer refund rows are reversed and hidden from wallet history", () => {
  const migration = readCustomerWalletInvalidRefundCleanupMigration();
  const walletService = readFileSync(
    new URL("../jedechai_delivery_new/lib/common/services/wallet_service.dart", import.meta.url),
    "utf8",
  );
  const adminCustomerWallets = readFileSync(adminCustomerWalletsPageUrl, "utf8");

  assert.match(migration, /CREATE TEMP TABLE tmp_invalid_customer_refunds/);
  assert.match(migration, /wt\.type = 'refund'/);
  assert.match(migration, /wt\.related_booking_id IS NULL/);
  assert.match(migration, /NOT EXISTS[\s\S]*type = 'invalid_refund_reversal'/);
  assert.match(migration, /'invalid_refund_reversal'/);
  assert.match(migration, /SET[\s\S]*type = 'invalid_refund'/);
  assert.match(migration, /UPDATE public\.wallets w[\s\S]*balance = w\.balance - r\.total_amount/);
  assert.match(walletService, /_isDisplayableWalletTransaction/);
  assert.match(walletService, /invalid_refund/);
  assert.match(walletService, /invalid_refund_reversal/);
  assert.match(adminCustomerWallets, /isDisplayableWalletTransaction/);
  assert.match(adminCustomerWallets, /invalid_refund/);
  assert.match(adminCustomerWallets, /invalid_refund_reversal/);
});

test("admin force-cancel refunds customer wallet through idempotent refund RPC", () => {
  const source = readFileSync(adminActionsUrl, "utf8");
  const migration = readCustomerWalletHardeningMigration();
  const start = source.indexOf("async function handleForceCancelOrder");
  assert.notEqual(start, -1, "handleForceCancelOrder not found");
  const end = source.indexOf("\nasync function", start + 1);
  const block = source.slice(start, end === -1 ? source.length : end);

  assert.match(migration, /CREATE OR REPLACE FUNCTION public\.admin_force_cancel_booking_with_wallet_refund/);
  assert.match(migration, /FOR UPDATE/);
  assert.match(migration, /payment_method[\s\S]*wallet/);
  assert.match(migration, /wallet_transactions[\s\S]*type\s*=\s*'payment'[\s\S]*related_booking_id\s*=\s*p_booking_id/);
  assert.match(migration, /refund_booking_to_customer_wallet/);
  assert.match(migration, /GRANT EXECUTE ON FUNCTION public\.admin_force_cancel_booking_with_wallet_refund\(uuid, text, boolean\) TO service_role/);
  assert.match(block, /rpc\("admin_force_cancel_booking_with_wallet_refund"/);
  assert.match(block, /p_booking_id: order_id/);
  assert.match(block, /p_reason:/);
  assert.match(block, /p_do_refund: Boolean\(do_refund\)/);
  assert.match(block, /return jsonResponse\(payload\)/);
  assert.doesNotMatch(block, /price/);
  assert.doesNotMatch(block, /p_amount/);
  assert.doesNotMatch(block, /p_description/);
  assert.doesNotMatch(block, /already_refunded/);
  assert.doesNotMatch(block, /\.from\("wallets"\)[\s\S]*\.update/);
  assert.doesNotMatch(block, /\.from\("wallet_transactions"\)\.insert/);
});

test("withdrawal service creates customer or driver withdrawal through atomic RPC", () => {
  const source = readFileSync(withdrawalServiceUrl, "utf8");

  assert.match(source, /rpc\('create_wallet_withdrawal_request'/);
  assert.doesNotMatch(source, /from\('withdrawal_requests'\)\.insert/);
  assert.doesNotMatch(source, /rpc\('wallet_deduct'/);
});

test("customer payment surfaces use wallet RPC for food, ride, and parcel bookings", () => {
  const paymentService = readFileSync(paymentServiceUrl, "utf8");
  const foodCheckout = readFileSync(foodCheckoutUrl, "utf8");
  const paymentScreen = readFileSync(paymentScreenUrl, "utf8");

  assert.match(paymentService, /payBookingWithWallet/);
  assert.match(paymentService, /rpc\('customer_wallet_pay_booking'/);
  assert.match(foodCheckout, /'wallet'/);
  assert.match(foodCheckout, /payBookingWithWallet/);
  assert.match(paymentScreen, /'id': 'wallet'/);
  assert.match(paymentScreen, /payBookingWithWallet/);
});

test("customer app exposes a wallet screen with topup, withdrawal, and ledger history", () => {
  assert.equal(existsSync(customerWalletScreenUrl), true);
  const walletScreen = readFileSync(customerWalletScreenUrl, "utf8");
  const accountScreen = readFileSync(customerAccountScreenUrl, "utf8");

  assert.match(accountScreen, /CustomerWalletScreen/);
  assert.match(walletScreen, /class CustomerWalletScreen/);
  assert.match(walletScreen, /WalletService/);
  assert.match(walletScreen, /WithdrawalService/);
  assert.match(walletScreen, /getBalance/);
  assert.match(walletScreen, /getTransactions/);
  assert.match(walletScreen, /WalletTopUpScreen/);
  assert.match(walletScreen, /WalletWithdrawalScreen/);
  assert.match(walletScreen, /100/);
});

test("customer home exposes wallet balance and direct wallet access", () => {
  const homeScreen = readFileSync(customerHomeScreenUrl, "utf8");

  assert.match(homeScreen, /customer_wallet_screen\.dart/);
  assert.match(homeScreen, /WalletService/);
  assert.match(homeScreen, /_loadWalletSummary/);
  assert.match(homeScreen, /_buildWalletSummaryCard/);
  assert.match(homeScreen, /CustomerWalletScreen/);
  assert.match(homeScreen, /ยอดเงินใน Wallet/);
});

test("admin web topup page supports customer wallet topups", () => {
  const topupsPage = readFileSync(adminTopupsPageUrl, "utf8");
  const legacy = readFileSync(adminLegacyUrl, "utf8");

  for (const source of [topupsPage, legacy]) {
    assert.match(source, /select\('id, full_name, role'\)/);
    assert.match(source, /บทบาท/);
    assert.match(source, /roleFilter/);
    assert.match(source, /\.in\('role', \['driver', 'customer'\]\)/);
    assert.match(source, /ลูกค้า/);
    assert.match(source, /คนขับ/);
  }
});

test("admin manual topup dialog has role label available outside renderTopupsPage", () => {
  const topupsPage = readFileSync(adminTopupsPageUrl, "utf8");

  const renderStart = topupsPage.indexOf("export async function renderTopupsPage");
  const manualStart = topupsPage.indexOf("async function showManualTopup");
  const moduleHelper = topupsPage.indexOf("function topupRoleLabel");
  const localRoleLabel = topupsPage.indexOf("const roleLabel");

  assert.notEqual(renderStart, -1, "renderTopupsPage not found");
  assert.notEqual(manualStart, -1, "showManualTopup not found");
  assert.notEqual(moduleHelper, -1, "module-scope topupRoleLabel helper missing");
  assert.ok(moduleHelper < renderStart, "topupRoleLabel must be module-scoped");
  assert.ok(localRoleLabel === -1 || localRoleLabel > manualStart, "showManualTopup must not depend on render-local roleLabel");
  assert.match(topupsPage, /topupRoleLabel\(u\.role\)/);
});

test("admin web has customer wallet management page registered and linked", () => {
  assert.equal(existsSync(adminCustomerWalletsPageUrl), true);
  const page = readFileSync(adminCustomerWalletsPageUrl, "utf8");
  const pagesIndex = readFileSync(adminPagesIndexUrl, "utf8");
  const main = readFileSync(adminMainUrl, "utf8");
  const indexHtml = readFileSync(adminIndexHtmlUrl, "utf8");
  const meta = readFileSync(adminRouterMetaUrl, "utf8");

  assert.match(page, /renderCustomerWalletsPage/);
  assert.match(page, /\.from\('wallets'\)/);
  assert.match(page, /\.from\('profiles'\)/);
  assert.match(page, /\.eq\('role', 'customer'\)/);
  assert.match(page, /wallet_transactions/);
  assert.match(page, /manual_topup/);
  assert.match(page, /Customer Wallet/);
  assert.match(pagesIndex, /registerCustomerWalletsPage/);
  assert.match(main, /wireCustomerWalletsBridge/);
  assert.match(indexHtml, /data-page="customer_wallets"/);
  assert.match(meta, /customer_wallets/);
});

test("admin customer wallet topup button opens a real modal and submits manual_topup", () => {
  const page = readFileSync(adminCustomerWalletsPageUrl, "utf8");
  const topupStart = page.indexOf("export async function showCustomerWalletManualTopup");
  const bridgeStart = page.indexOf("export function wireCustomerWalletsBridge");
  const topupFunction = page.slice(topupStart, bridgeStart);

  assert.ok(topupStart >= 0, "showCustomerWalletManualTopup must exist");
  assert.match(page, /onclick="showCustomerWalletManualTopup\('/);
  assert.match(page, /onclick="showCustomerWalletManualTopup\(\)"/);
  assert.match(page, /globalThis\.showCustomerWalletManualTopup = showCustomerWalletManualTopup/);
  assert.match(topupFunction, /customerWalletManualTopupModal/);
  assert.match(topupFunction, /customerWalletManualTopupForm/);
  assert.match(topupFunction, /customerWalletManualTopupUserId/);
  assert.match(topupFunction, /customerWalletManualTopupAmount/);
  assert.match(topupFunction, /customerWalletManualTopupDescription/);
  assert.match(topupFunction, /callAdminAction\(\{\s*action: 'manual_topup'/s);
  assert.doesNotMatch(topupFunction, /prompt\(/);
});

test("admin web withdrawal page supports customer wallet withdrawals", () => {
  const withdrawalsPage = readFileSync(adminWithdrawalsPageUrl, "utf8");

  assert.match(withdrawalsPage, /\.from\('withdrawal_requests'\)/);
  assert.match(withdrawalsPage, /select\('id, full_name, role'\)\.in\('id', userIds\)/);
  assert.match(withdrawalsPage, /บทบาท/);
  assert.match(withdrawalsPage, /approveWithdrawal/);
  assert.match(withdrawalsPage, /rejectWithdrawal/);
  assert.doesNotMatch(withdrawalsPage, /\.eq\('role', 'driver'\)/);
  assert.doesNotMatch(withdrawalsPage, /\.eq\("role", "driver"\)/);
});
