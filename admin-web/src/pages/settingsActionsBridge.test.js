import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const legacySettingsSource = readFileSync(
  new URL("../../app.legacy.js", import.meta.url),
  "utf8",
);
// renderSettings ย้ายจาก app.legacy.js มาอยู่ settingsPage.js (2026-07-18)
const settingsPageSource = readFileSync(
  new URL("./settingsPage.js", import.meta.url),
  "utf8",
);
const actionsSource = readFileSync(
  new URL("./settingsActionsBridge.js", import.meta.url),
  "utf8",
);

test("settings page exposes a dedicated Telegram admin notification test button", () => {
  assert.match(settingsPageSource, /id="testAdminTelegramButton"/);
  assert.match(settingsPageSource, /data-testid="test-admin-telegram-button"/);
  assert.match(settingsPageSource, /onclick="testAdminTelegram\(\)"/);
  assert.match(settingsPageSource, />\s*ทดสอบ Telegram\s*</);
});

test("Telegram admin notification test invokes send-admin-telegram with admin test payload", () => {
  assert.match(actionsSource, /supabase\.functions\.invoke\('send-admin-telegram'/);
  assert.match(actionsSource, /test:\s*true/);
  assert.match(actionsSource, /event_type:\s*'admin_telegram_test'/);
  assert.match(actionsSource, /chat_id:\s*chatId/);
  assert.match(actionsSource, /source:\s*'admin_web_settings'/);
});

test("legacy Telegram test button delegates to the settings action bridge when available", () => {
  assert.match(legacySettingsSource, /const bridged = window\.__adminWebBridge\?\.testAdminTelegram/);
  assert.match(legacySettingsSource, /return await bridged\(\{ supabase, supabaseAuth, currentUser, callAdminAction, showToast, escapeHtml, fmt, fmtDate, refreshCurrentPage \}\)/);
});

test("settings page exposes app update policy controls", () => {
  assert.match(settingsPageSource, /id="settAppUpdateEnabled"/);
  assert.match(settingsPageSource, /id="settAppUpdateMode"/);
  assert.match(settingsPageSource, /id="settAppUpdateLatestBuild"/);
  assert.match(settingsPageSource, /id="settAppUpdateMinSupportedBuild"/);
  assert.match(settingsPageSource, /onclick="saveAppUpdatePolicySettings\(\)"/);
  assert.match(settingsPageSource, /data-testid="save-app-update-policy-button"/);
});

test("app update policy settings save through system_config app_update_policy", () => {
  assert.match(actionsSource, /export async function saveAppUpdatePolicySettings/);
  assert.match(actionsSource, /app_update_policy/);
  assert.match(actionsSource, /latest_build/);
  assert.match(actionsSource, /min_supported_build/);
  assert.match(actionsSource, /force update ต้องมี Store URL/);
  assert.match(actionsSource, /target_roles:\s*\[\]/);
  assert.match(actionsSource, /globalThis\.__adminWebBridge\.saveAppUpdatePolicySettings = saveAppUpdatePolicySettings/);
});

test("settings page exposes topup mode switch and Beam settings with connection test", () => {
  assert.match(settingsPageSource, /name="settTopupMode" value="admin_approve"/);
  assert.match(settingsPageSource, /name="settTopupMode" value="beam"/);
  assert.match(settingsPageSource, /onchange="setTopupMode\('beam'\)"/);
  assert.match(settingsPageSource, /id="settBeamMerchantId"/);
  assert.match(settingsPageSource, /id="settBeamApiKey"[^>]*type="password"|type="password" id="settBeamApiKey"/);
  assert.match(settingsPageSource, /id="settBeamWebhookKey"/);
  assert.match(settingsPageSource, /onclick="testBeamConnection\(\)"/);
  assert.match(settingsPageSource, /onclick="saveBeamSettings\(\)"/);
});

test("Beam actions go through admin-actions and never write keys to system_config", () => {
  assert.match(actionsSource, /action: 'get_beam_settings'/);
  assert.match(actionsSource, /action: 'save_beam_settings'/);
  assert.match(actionsSource, /action: 'test_beam_connection'/);
  assert.match(actionsSource, /action: 'set_topup_mode', mode/);
  assert.doesNotMatch(actionsSource, /topup_mode: 'admin_approve'/);
  assert.doesNotMatch(legacySettingsSource, /topup_mode: 'admin_approve'/);
});
