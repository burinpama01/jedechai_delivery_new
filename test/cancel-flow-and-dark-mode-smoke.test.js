import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";

// บัคยกเลิกออเดอร์ไม่ได้ (ISSUE-20260919-002): RPC cancel_wallet_booking_with_refund
// pin search_path='public' → trigger StoreOS เรียก hmac() หาไม่เจอ (อยู่ schema extensions)
// → 42883 → ธุรกรรม rollback ทั้งหมด
// Fix: ALTER FUNCTION trigger ให้ SET search_path = public, extensions
//
// บัค UI โหมดมืดหน้ายกเลิก (ISSUE-20260919-003): cancellation_screen.dart
// hardcode พื้นการ์ด Colors.white แต่สีตัวอักษรบางจุดมาจากธีม → โหมดมืดขาวบนขาวอ่านไม่ออก
// Fix: ใช้ colorScheme สำหรับพื้นการ์ด/แถบปุ่ม/สีรอง

const migrationSource = readFileSync(
  new URL("../supabase/migrations/20260919231000_fix_storeos_trigger_hmac_search_path.sql", import.meta.url),
  "utf8",
);

const cancellationScreenSource = readFileSync(
  new URL("../jedechai_delivery_new/lib/apps/customer/screens/services/cancellation_screen.dart", import.meta.url),
  "utf8",
);

test("migration pins search_path on both StoreOS trigger functions", () => {
  assert.match(migrationSource, /ALTER FUNCTION public\.notify_storeos_order\(\)\s+SET search_path/i);
  assert.match(migrationSource, /ALTER FUNCTION public\.notify_storeos_order_created\(\)\s+SET search_path/i);
  assert.match(migrationSource, /public,\s*extensions/);
});

test("cancellation screen has no hardcoded white card/button surfaces", () => {
  // พื้นการ์ด/แถบปุ่มที่ hardcode ขาวคือสาเหตุตัวอักษรขาวบนขาวใน dark mode
  // (ปุ่มแดง foregroundColor: Colors.white และ spinner บนปุ่มแดงยังถูกต้อง)
  const hardcodedSurfaces = cancellationScreenSource.match(/^ *color: Colors\.white, *$/gm) ?? [];
  assert.equal(hardcodedSurfaces.length, 0, `found ${hardcodedSurfaces.length} standalone Colors.white color(s)`);
  assert.doesNotMatch(cancellationScreenSource, /BoxDecoration\([\s\S]{0,80}?color: Colors\.white/);
});

test("cancellation screen uses theme-aware surfaces and secondary colors", () => {
  assert.match(cancellationScreenSource, /colorScheme\.surfaceContainer/);
  assert.match(cancellationScreenSource, /colorScheme\.surface\b/);
  assert.match(cancellationScreenSource, /colorScheme\.onSurfaceVariant/);
  assert.match(cancellationScreenSource, /colorScheme\.onSurface\b/);
});
