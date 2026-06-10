import test from "node:test";
import assert from "node:assert/strict";
import { existsSync, readFileSync } from "node:fs";

const topupScreen = readFileSync(
  new URL("../jedechai_delivery_new/lib/apps/driver/screens/wallet_topup_screen.dart", import.meta.url),
  "utf8",
);

const adminLegacy = readFileSync(
  new URL("../admin-web/app.legacy.js", import.meta.url),
  "utf8",
);

const adminTopupsPage = readFileSync(
  new URL("../admin-web/src/pages/topupsPage.js", import.meta.url),
  "utf8",
);

const adminSettingsActions = readFileSync(
  new URL("../admin-web/src/pages/settingsActionsBridge.js", import.meta.url),
  "utf8",
);

const adminActionsFunction = readFileSync(
  new URL("../supabase/functions/admin-actions/index.ts", import.meta.url),
  "utf8",
);

const adminService = readFileSync(
  new URL("../jedechai_delivery_new/lib/common/services/admin_service.dart", import.meta.url),
  "utf8",
);

const walletService = readFileSync(
  new URL("../jedechai_delivery_new/lib/common/services/wallet_service.dart", import.meta.url),
  "utf8",
);

const verifyTopupSlipUrl = new URL(
  "../supabase/functions/verify-topup-slip/index.ts",
  import.meta.url,
);

const migrationUrl = new URL(
  "../supabase/migrations/20260609000100_topup_slip2go_auto_manual.sql",
  import.meta.url,
);

const maskedReceiverMigrationUrl = new URL(
  "../supabase/migrations/20260609193542_add_masked_topup_receiver_override.sql",
  import.meta.url,
);

function functionBody(source, name) {
  const start = source.indexOf(`async function ${name}`);
  assert.notEqual(start, -1, `${name} not found`);
  const next = source.indexOf("\nasync function ", start + 1);
  return source.slice(start, next === -1 ? source.length : next);
}

test("driver topup screen no longer exposes Omise mode", () => {
  assert.doesNotMatch(topupScreen, /OmiseService|omise_service|_useOmise|_generateOmiseQR|topup_mode=omise/);
  assert.match(topupScreen, /verify-topup-slip/);
});

test("admin topup UI no longer offers Omise switching", () => {
  for (const source of [adminLegacy, adminTopupsPage, adminSettingsActions]) {
    assert.doesNotMatch(source, /Omise|\bomise\b|topup_mode:\s*["']omise["']/);
    assert.match(source, /slip2go_receiver_account|Slip2Go Auto \+ Manual|settSlip2goReceiverAccount/);
  }
});

test("verify-topup-slip function keeps Slip2Go credentials server-side", () => {
  assert.equal(existsSync(verifyTopupSlipUrl), true);
  const source = readFileSync(verifyTopupSlipUrl, "utf8");

  assert.match(source, /Deno\.env\.get\("SLIP2GO_API_KEY"\)/);
  assert.match(source, /https:\/\/connect\.slip2go\.com\/api\/verify-slip\/qr-image\/info/);
  assert.match(source, /form\.set\(\s*"file"/);
  assert.match(source, /complete_topup_request/);
  assert.doesNotMatch(source, /\.rpc\(\s*"wallet_topup"/);
  assert.match(source, /slip2go_trans_ref/);
});

test("verify-topup-slip reads receiver PromptPay proxy account from Slip2Go", () => {
  const source = readFileSync(verifyTopupSlipUrl, "utf8");

  assert.match(source, /const receiverProxy\s*=\s*\(receiverAccount\.proxy/);
  assert.match(source, /receiverProxy\.account/);
  assert.match(source, /normalizeDigits\(parsed\.receiverAccount\)/);
});

test("verify-topup-slip prefers PromptPay proxy receiver account over generic account fields", () => {
  const source = readFileSync(verifyTopupSlipUrl, "utf8");
  const receiverAccountStart = source.indexOf("receiverAccount: pickString(");
  const transRefStart = source.indexOf("transRef:", receiverAccountStart);
  const receiverAccountBlock = source.slice(receiverAccountStart, transRefStart);

  assert.notEqual(receiverAccountStart, -1, "receiverAccount parser not found");
  assert.notEqual(transRefStart, -1, "transRef parser not found");
  assert.ok(
    receiverAccountBlock.indexOf("receiverProxy.account") <
      receiverAccountBlock.indexOf("receiverAccount.account"),
    "PromptPay proxy account must be parsed before generic receiver account fields",
  );
});

test("verify-topup-slip does not auto-credit from masked or short receiver accounts", () => {
  const source = readFileSync(verifyTopupSlipUrl, "utf8");
  const trustCheck = source.indexOf("isTrustedReceiverAccount(parsed.receiverAccount)");
  const receiverMatch = source.indexOf("receiverMatches(parsed.receiverAccount");

  assert.match(source, /const MIN_TRUSTED_RECEIVER_DIGITS\s*=/);
  assert.match(source, /const MASKED_ACCOUNT_PATTERN\s*=/);
  assert.match(source, /function isTrustedReceiverAccount/);
  assert.match(source, /receiverAccountUntrusted/);
  assert.notEqual(trustCheck, -1, "receiver account trust check not found");
  assert.notEqual(receiverMatch, -1, "receiver match check not found");
  assert.ok(
    trustCheck < receiverMatch,
    "untrusted masked or short receiver accounts must be sent to manual review before receiver match",
  );
});

test("admin settings can enable temporary masked PromptPay receiver override", () => {
  const migration = readFileSync(maskedReceiverMigrationUrl, "utf8");

  assert.match(migration, /slip2go_allow_masked_receiver_account boolean NOT NULL DEFAULT false/);
  assert.match(migration, /admin_telegram_enabled boolean DEFAULT false/);
  assert.match(migration, /admin_telegram_chat_id text/);
  assert.match(adminLegacy, /id="settSlip2goAllowMaskedReceiver"/);
  assert.match(adminLegacy, /acceptMaskedSlip2goReceiverAccount/);
  assert.match(adminLegacy, /async function acceptMaskedSlip2goReceiverAccount/);
  assert.match(adminLegacy, /await saveTopupModeSettings\(\)/);
  assert.match(adminLegacy, /slip2go_allow_masked_receiver_account:/);
  assert.match(adminSettingsActions, /slip2go_allow_masked_receiver_account:/);
  assert.match(adminSettingsActions, /settSlip2goAllowMaskedReceiver/);
});

test("verify-topup-slip only accepts masked receiver when temporary override is enabled", () => {
  const source = readFileSync(verifyTopupSlipUrl, "utf8");
  const configSelect = source.indexOf("slip2go_allow_masked_receiver_account");
  const overrideHelper = source.indexOf("function receiverMatchesTemporaryMaskedOverride");
  const parsedTrustCheck = source.indexOf("isTrustedReceiverAccount(parsed.receiverAccount)");
  const autoBlock = source.indexOf("complete_topup_request", parsedTrustCheck);

  assert.notEqual(configSelect, -1, "masked receiver config select not found");
  assert.notEqual(overrideHelper, -1, "masked receiver override helper not found");
  assert.notEqual(parsedTrustCheck, -1, "parsed receiver trust check not found");
  assert.notEqual(autoBlock, -1, "auto-credit block not found");
  assert.match(source, /allowMaskedReceiver/);
  assert.match(source, /receiverMatchesTemporaryMaskedOverride\(parsed\.receiverAccount,\s*expectedReceiver,\s*allowMaskedReceiver\)/);
  assert.ok(
    parsedTrustCheck < autoBlock,
    "masked receiver override must be checked before auto-credit",
  );
});

test("verify-topup-slip function validates amount and duplicate slip reference", () => {
  assert.equal(existsSync(verifyTopupSlipUrl), true);
  const source = readFileSync(verifyTopupSlipUrl, "utf8");

  assert.match(source, /amountMismatch|Amount mismatch|ยอดเงิน/);
  assert.match(source, /duplicateSlip|Duplicate slip|สลิปซ้ำ/);
  assert.match(source, /verified_amount/);
  assert.match(source, /verified_at/);
});

test("verify-topup-slip does not auto-credit without a reliable Slip2Go transRef", () => {
  const source = readFileSync(verifyTopupSlipUrl, "utf8");

  assert.match(source, /missingTransRef|transRefMissing|manualReview/);
  assert.match(source, /createManualReviewRequest/);
});

test("verify-topup-slip does not auto-credit when receiver config is missing", () => {
  const source = readFileSync(verifyTopupSlipUrl, "utf8");

  assert.match(source, /receiverConfigMissing/);
  assert.match(source, /normalizeDigits\(expectedReceiver\)/);
  assert.match(source, /pending_manual_review/);
});

test("verify-topup-slip records attempts and keeps slip evidence private", () => {
  const source = readFileSync(verifyTopupSlipUrl, "utf8");
  const migration = readFileSync(migrationUrl, "utf8");

  assert.match(migration, /CREATE TABLE IF NOT EXISTS public\.topup_verification_attempts/);
  assert.match(source, /topup_verification_attempts/);
  assert.match(source, /createVerificationAttempt/);
  assert.match(source, /updateVerificationAttempt/);
  assert.match(source, /const MANUAL_REVIEW_BUCKET = "topup-slips"/);
  assert.doesNotMatch(source, /admin-uploads|getPublicUrl|slip_image_url/);
  assert.doesNotMatch(migration, /slip_image_url/);
  assert.match(migration, /VALUES \('topup-slips', 'topup-slips', false/);
});

test("topup approval uses atomic completion instead of client-side wallet updates", () => {
  const approveBody = functionBody(adminActionsFunction, "handleApproveTopup");
  const serviceApproveStart = adminService.indexOf("Future<bool> approveTopUp");
  const serviceApproveEnd = adminService.indexOf("Future<bool> rejectTopUp", serviceApproveStart);
  const serviceApproveBody = adminService.slice(serviceApproveStart, serviceApproveEnd);

  assert.match(readFileSync(migrationUrl, "utf8"), /CREATE OR REPLACE FUNCTION public\.complete_topup_request/);
  assert.match(readFileSync(migrationUrl, "utf8"), /FOR UPDATE/);
  assert.match(readFileSync(migrationUrl, "utf8"), /REVOKE EXECUTE ON FUNCTION public\.complete_topup_request/);
  assert.match(readFileSync(migrationUrl, "utf8"), /REVOKE EXECUTE ON FUNCTION public\.approve_topup_request/);
  assert.match(readFileSync(migrationUrl, "utf8"), /REVOKE EXECUTE ON FUNCTION public\.wallet_topup\(uuid, numeric, text, text, uuid\) FROM authenticated/);
  assert.match(readFileSync(migrationUrl, "utf8"), /GRANT EXECUTE ON FUNCTION public\.wallet_topup\(uuid, numeric, text, text, uuid\) TO service_role/);
  assert.match(approveBody, /complete_topup_request/);
  assert.doesNotMatch(approveBody, /\.from\("wallets"\)|wallet_transactions/);
  assert.match(serviceApproveBody, /functions\.invoke\(\s*'admin-actions'/);
  assert.doesNotMatch(serviceApproveBody, /\.from\('wallets'\)|wallet_transactions/);
  assert.doesNotMatch(walletService, /rpc\(\s*'wallet_topup'/);
  assert.match(walletService, /topUpWallet ถูกปิด/);
});

test("admin topup slip evidence uses signed URLs instead of public URLs", () => {
  assert.match(adminActionsFunction, /case "get_topup_slip_url"/);
  assert.match(adminActionsFunction, /\.from\("topup-slips"\)\s*\.\s*createSignedUrl/);
  assert.match(adminTopupsPage, /viewTopupSlip/);
  assert.match(adminTopupsPage, /get_topup_slip_url/);
  assert.doesNotMatch(adminTopupsPage, /slip_image_url|getPublicUrl/);
  assert.match(adminLegacy, /viewTopupSlip/);
  assert.doesNotMatch(adminLegacy, /slip_image_url/);
});

test("admin topup slip evidence opens in an in-page dialog", () => {
  const sourceViewStart = adminTopupsPage.indexOf("export async function viewTopupSlip");
  const sourceViewEnd = adminTopupsPage.indexOf("export async function quickSwitchTopupMode", sourceViewStart);
  const legacyViewStart = adminLegacy.indexOf("async function viewTopupSlip");
  const legacyViewEnd = adminLegacy.indexOf("async function quickSwitchTopupMode", legacyViewStart);

  assert.notEqual(sourceViewStart, -1, "source viewTopupSlip not found");
  assert.notEqual(sourceViewEnd, -1, "source quickSwitchTopupMode not found");
  assert.notEqual(legacyViewStart, -1, "legacy viewTopupSlip not found");
  assert.notEqual(legacyViewEnd, -1, "legacy quickSwitchTopupMode not found");

  for (const viewBody of [
    adminTopupsPage.slice(sourceViewStart, sourceViewEnd),
    adminLegacy.slice(legacyViewStart, legacyViewEnd),
  ]) {
    assert.match(viewBody, /topupSlipModal/);
    assert.match(viewBody, /<img[^>]+src="\$\{escapeHtml\(result\.signed_url\)\}"/);
    assert.doesNotMatch(viewBody, /window\.open/);
  }
});

test("driver completed auto topup state does not show pending request card", () => {
  assert.match(topupScreen, /_autoTopupCompleted/);
  assert.match(topupScreen, /_buildAutoTopupCompletedCard/);
  assert.match(topupScreen, /if \(_autoTopupCompleted\)/);
});

test("driver topup formats rejected function errors before showing dialog", () => {
  assert.match(topupScreen, /_formatTopupVerificationError/);
  assert.match(topupScreen, /error is FunctionException/);
  assert.match(topupScreen, /slip2go_failed/);
  assert.match(topupScreen, /fraud/);
  assert.doesNotMatch(
    topupScreen,
    /_showErrorDialog\([^)]*\$\{e\.toString\(\)\}/s,
  );
});

test("driver topup treats pending FunctionException as a submitted request", () => {
  assert.match(topupScreen, /_pendingTopupVerificationResultFromError/);
  assert.match(topupScreen, /_handlePendingTopupVerificationResult/);
  assert.match(topupScreen, /status'\]\?\.toString\(\)\s*==\s*'pending'/);
  assert.match(topupScreen, /_requestSent\s*=\s*true/);
});

test("driver topup never shows raw Slip2Go provider text for slip2go_failed", () => {
  const formatterStart = topupScreen.indexOf("String _formatTopupVerificationResult");
  const formatterEnd = topupScreen.indexOf("String? _humanizeSlipVerificationMessage", formatterStart);
  const formatterBody = topupScreen.slice(formatterStart, formatterEnd);
  const slip2goCaseStart = formatterBody.indexOf("case 'slip2go_failed':");
  const slip2goCaseEnd = formatterBody.indexOf("case 'amountMismatch':", slip2goCaseStart);
  const slip2goCaseBody = formatterBody.slice(slip2goCaseStart, slip2goCaseEnd);

  assert.match(formatterBody, /case 'slip2go_failed':\s*return 'สลิปนี้ไม่ผ่านการตรวจสอบอัตโนมัติ/);
  assert.doesNotMatch(slip2goCaseBody, /_humanizeSlipVerificationMessage\(message\)/);
});

test("verify-topup-slip API does not return raw provider error text to users", () => {
  const source = readFileSync(verifyTopupSlipUrl, "utf8");
  const failedStart = source.indexOf('reason: "slip2go_failed"');
  const parsedStart = source.indexOf("const parsed = slip.parsed", failedStart);
  const failedBlock = source.slice(failedStart, parsedStart);

  assert.notEqual(failedStart, -1, "slip2go_failed branch not found");
  assert.notEqual(parsedStart, -1, "parsed block not found after slip2go_failed branch");
  assert.doesNotMatch(failedBlock, /message:\s*slip\.error/);
  assert.match(failedBlock, /สลิปนี้ไม่ผ่านการตรวจสอบอัตโนมัติ/);
});

test("verify-topup-slip sends non-blocking admin notifications for auto and manual review", () => {
  const source = readFileSync(verifyTopupSlipUrl, "utf8");
  const helperStart = source.indexOf("async function notifyTopupVerificationEvent");
  const helperEnd = source.indexOf("\nserve(async", helperStart);
  const helperBlock = source.slice(helperStart, helperEnd);
  const manualNotifyCount = (source.match(/eventType:\s*"topup_manual_review"/g) || []).length;
  const autoNotify = source.indexOf('eventType: "topup_auto_credit"');
  const autoReturn = source.indexOf("return jsonResponse({", autoNotify);

  assert.notEqual(helperStart, -1, "notification helper not found");
  assert.notEqual(helperEnd, -1, "serve block not found after notification helper");
  assert.match(source, /AbortSignal\.timeout\(ADMIN_NOTIFICATION_TIMEOUT_MS\)/);
  assert.match(helperBlock, /sendAdminLineNotification/);
  assert.match(helperBlock, /sendAdminTelegramNotification/);
  assert.match(helperBlock, /catch \(error\)/);
  assert.doesNotMatch(helperBlock, /throw error|throw new Error/);
  assert.ok(manualNotifyCount >= 5, "manual-review branches must notify admin");
  assert.notEqual(autoNotify, -1, "auto-credit notification not found");
  assert.ok(autoNotify < autoReturn, "auto-credit notification must run before success response");
});

test("driver topup user-facing copy does not expose the slip verification provider name", () => {
  assert.doesNotMatch(topupScreen, /ตรวจสอบจาก Slip2Go|ตรวจผ่าน Slip2Go|ผ่าน Slip2Go/);
});

test("driver topup receiver mismatch copy refers to the system account", () => {
  assert.doesNotMatch(topupScreen, /บัญชีของร้าน|ร้านค้า/);
  assert.match(topupScreen, /บัญชีปลายทางของระบบ|บัญชีระบบ/);
});

test("verify-topup-slip sends missing receiver account to manual review instead of rejecting", () => {
  const source = readFileSync(verifyTopupSlipUrl, "utf8");

  assert.match(source, /receiverAccountMissing/);
  assert.match(source, /normalizeDigits\(parsed\.receiverAccount/);
  assert.match(source, /reason:\s*"receiverAccountMissing"/);
  assert.match(source, /status:\s*"pending"/);
});

test("verify-topup-slip checks duplicate slip refs before receiver-account manual review", () => {
  const source = readFileSync(verifyTopupSlipUrl, "utf8");
  const duplicateCheck = source.indexOf("duplicateLookupError");
  const receiverAccountMissing = source.indexOf('reason: "receiverAccountMissing"');

  assert.notEqual(duplicateCheck, -1, "duplicate slip check not found");
  assert.notEqual(receiverAccountMissing, -1, "receiverAccountMissing branch not found");
  assert.ok(
    duplicateCheck < receiverAccountMissing,
    "duplicate slip check must run before receiverAccountMissing manual review",
  );
});

test("verify-topup-slip checks duplicate slip refs before amount mismatch rejection", () => {
  const source = readFileSync(verifyTopupSlipUrl, "utf8");
  const duplicateCheck = source.indexOf("duplicateLookupError");
  const amountMismatch = source.indexOf("const amountMismatch");

  assert.notEqual(duplicateCheck, -1, "duplicate slip check not found");
  assert.notEqual(amountMismatch, -1, "amount mismatch check not found");
  assert.ok(
    duplicateCheck < amountMismatch,
    "duplicate slip check must run before amount mismatch rejection",
  );
});

test("verify-topup-slip fails closed when duplicate slip lookup is inconclusive", () => {
  const source = readFileSync(verifyTopupSlipUrl, "utf8");
  const duplicateLookupStart = source.indexOf("const { data: duplicateSlip");
  const receiverAccountMissing = source.indexOf('reason: "receiverAccountMissing"');
  const duplicateBlock = source.slice(duplicateLookupStart, receiverAccountMissing);

  assert.match(duplicateBlock, /error:\s*duplicateLookupError/);
  assert.match(duplicateBlock, /duplicateLookupFailed/);
  assert.match(duplicateBlock, /return errorResponse\(/);
});

test("verify-topup-slip maps duplicate manual-review inserts to duplicateSlip", () => {
  const source = readFileSync(verifyTopupSlipUrl, "utf8");

  assert.match(source, /error\?\.code\s*===\s*"23505"/);
  assert.match(source, /reason:\s*"duplicateSlip"/);
  assert.match(source, /409/);
});

test("verify-topup-slip stores slip evidence for rejected verification requests", () => {
  const source = readFileSync(verifyTopupSlipUrl, "utf8");
  const amountStart = source.indexOf("if (amountMismatch)");
  const configStart = source.indexOf('const { data: config }', amountStart);
  const receiverStart = source.indexOf("receiverMatches(parsed.receiverAccount");
  const transRefStart = source.indexOf("if (!parsed.transRef)", receiverStart);

  assert.notEqual(amountStart, -1, "amount mismatch branch not found");
  assert.notEqual(configStart, -1, "receiver config branch not found");
  assert.notEqual(receiverStart, -1, "receiver mismatch branch not found");
  assert.notEqual(transRefStart, -1, "missing transRef branch not found");

  const amountBlock = source.slice(amountStart, configStart);
  const receiverBlock = source.slice(receiverStart, transRefStart);

  assert.match(amountBlock, /createRejectedSlipRequest/);
  assert.match(amountBlock, /slip_image_path:\s*rejectedRequest\.evidence\.path/);
  assert.match(receiverBlock, /createRejectedSlipRequest/);
  assert.match(receiverBlock, /slip_image_path:\s*rejectedRequest\.evidence\.path/);
});

test("verify-topup-slip stores slip evidence for auto-completed requests", () => {
  const source = readFileSync(verifyTopupSlipUrl, "utf8");
  const requestStart = source.indexOf('admin_note: "Slip2Go verified; wallet credit pending"');
  const completionStart = source.indexOf("complete_topup_request", requestStart);

  assert.notEqual(requestStart, -1, "auto-completed request insert not found");
  assert.notEqual(completionStart, -1, "completion RPC not found");

  const autoRequestBlock = source.slice(Math.max(0, requestStart - 700), completionStart);
  assert.match(autoRequestBlock, /uploadSlipEvidence/);
  assert.match(autoRequestBlock, /slip_image_path:\s*autoEvidence\.path/);
});
