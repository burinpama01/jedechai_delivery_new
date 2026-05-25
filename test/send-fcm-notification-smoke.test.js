import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const source = readFileSync(
  new URL("../supabase/functions/send-fcm-notification/index.ts", import.meta.url),
  "utf8",
);

test("send-fcm-notification keeps Firebase credentials server-side only", () => {
  assert.match(source, /FIREBASE_SERVICE_ACCOUNT_JSON/);
  assert.match(source, /Deno\.env\.get\("FIREBASE_PROJECT_ID"\)/);
  assert.doesNotMatch(source, /googleapis_auth/);
});

test("send-fcm-notification persists delivery outcomes", () => {
  assert.match(source, /\.from\("notification_deliveries"\)/);
  assert.match(source, /status:\s*result\.success\s*\?\s*"sent"\s*:\s*"failed"/);
  assert.match(source, /status:\s*"skipped"/);
});

test("send-fcm-notification allows persisted driver candidate notifications", () => {
  assert.match(source, /isAllowedDriverCandidateNotification/);
  assert.match(source, /\.from\("notifications"\)/);
  assert.match(source, /\.select\("id, user_id, type, data"\)/);
  assert.match(source, /\.eq\("type",\s*"driver\.job\.available"\)/);
});

test("send-fcm-notification does not allow ordinary callers to target admins directly", () => {
  assert.doesNotMatch(source, /if \(targetProfile\?\.role === "admin"\) return true;/);
});
