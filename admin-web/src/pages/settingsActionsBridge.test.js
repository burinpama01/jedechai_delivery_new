import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const legacySettingsSource = readFileSync(
  new URL("../../app.legacy.js", import.meta.url),
  "utf8",
);
const actionsSource = readFileSync(
  new URL("./settingsActionsBridge.js", import.meta.url),
  "utf8",
);

test("settings page exposes a dedicated Telegram admin notification test button", () => {
  assert.match(legacySettingsSource, /id="testAdminTelegramButton"/);
  assert.match(legacySettingsSource, /data-testid="test-admin-telegram-button"/);
  assert.match(legacySettingsSource, /onclick="testAdminTelegram\(\)"/);
  assert.match(legacySettingsSource, />\s*ทดสอบ Telegram\s*</);
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
  assert.match(legacySettingsSource, /id="settAppUpdateEnabled"/);
  assert.match(legacySettingsSource, /id="settAppUpdateMode"/);
  assert.match(legacySettingsSource, /id="settAppUpdateLatestBuild"/);
  assert.match(legacySettingsSource, /id="settAppUpdateMinSupportedBuild"/);
  assert.match(legacySettingsSource, /onclick="saveAppUpdatePolicySettings\(\)"/);
  assert.match(legacySettingsSource, /data-testid="save-app-update-policy-button"/);
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
