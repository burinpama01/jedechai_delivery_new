import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const source = readFileSync(
  new URL("./notificationDeliveriesPage.js", import.meta.url),
  "utf8",
);

test("notification delivery page reads delivery log without mutating rows", () => {
  assert.match(source, /\.from\("notification_deliveries"\)/);
  assert.match(source, /\.select\("id, notification_id, user_id, channel, status, provider_message_id, error, created_at"\)/);
  assert.doesNotMatch(source, /\.insert\(/);
  assert.doesNotMatch(source, /\.update\(/);
  assert.doesNotMatch(source, /\.delete\(/);
});

test("notification delivery page exposes status filters and summary buckets", () => {
  assert.match(source, /option value="sent"/);
  assert.match(source, /option value="failed"/);
  assert.match(source, /option value="skipped"/);
  assert.match(source, /\["sent", "failed", "skipped", "unknown"\]/);
});
