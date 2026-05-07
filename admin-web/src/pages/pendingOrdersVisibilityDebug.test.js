import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

const source = readFileSync(
  new URL("./pendingOrdersPage.js", import.meta.url),
  "utf8",
);

test("pending orders page exposes driver notification debug RPC", () => {
  assert.match(source, /showDriverNotificationDebug/);
  assert.match(source, /get_booking_driver_notification_debug/);
  assert.match(source, /visible_to_driver/);
  assert.match(source, /hidden_reason/);
  assert.match(source, /delivery_status/);
});
