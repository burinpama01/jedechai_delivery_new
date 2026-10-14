// ทีมแอดมิน: แคตตาล็อก action + กติกาตัดสินสิทธิ์ (supabase/functions/_shared/admin-permissions.ts)
// รัน: node --test test/admin-permissions.test.mjs
import test from "node:test";
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import {
  ACTION_CATALOG,
  bestLevel,
  canDecideApproval,
  decideAccess,
  sanitizeActionOverrides,
  sanitizePageLevels,
  sanitizePageOverrides,
} from "../supabase/functions/_shared/admin-permissions.ts";
import { buildWebModule, TARGET } from "../scripts/sync-admin-permissions-web.mjs";

const adminActionsSource = readFileSync(new URL("../supabase/functions/admin-actions/index.ts", import.meta.url), "utf8");
const switchActions = [...adminActionsSource.matchAll(/case "([a-z_]+)":/g)].map((m) => m[1]);

const su = { tier: "superadmin", active: true };
const asst = (pages, actions = {}) => ({ tier: "assistant", active: true, pages, actions });
const lead = (pages, actions = {}) => ({ tier: "lead", active: true, pages, actions });

test("ทุก action ใน admin-actions อยู่ในแคตตาล็อก (กัน action ใหม่หลุดเป็น deny เงียบ ๆ)", () => {
  const missing = switchActions.filter((a) => !ACTION_CATALOG[a]);
  assert.deepEqual(missing, []);
});

test("action ในแคตตาล็อกที่ไม่ใช่ team/approval ต้องมี case ใน admin-actions", () => {
  const orphan = Object.entries(ACTION_CATALOG)
    .filter(([, e]) => e.kind !== "team" && e.kind !== "approval")
    .map(([a]) => a)
    .filter((a) => !switchActions.includes(a));
  assert.deepEqual(orphan, []);
});

test("admin-web ใช้แคตตาล็อกที่ generate ตรงกับ TS", () => {
  assert.equal(readFileSync(TARGET, "utf8"), buildWebModule(), "รัน node scripts/sync-admin-permissions-web.mjs");
});

test("superadmin และสถานะ active", () => {
  assert.equal(decideAccess(su, "upsert_system_config"), "allow");
  assert.equal(decideAccess(su, "team_update"), "allow");
  assert.equal(decideAccess({ ...su, active: false }, "approve_topup"), "deny");
  assert.equal(decideAccess(null, "approve_topup"), "deny");
  assert.equal(decideAccess({ tier: "bogus", active: true, pages: { orders: "approve" } }, "cancel_order"), "deny");
});

test("ระดับรายหน้า read / write / sensitive", () => {
  assert.equal(decideAccess(asst({ topups: "view" }), "get_topup_slip_url"), "allow");
  assert.equal(decideAccess(asst({ topups: "view" }), "reject_topup"), "deny");
  assert.equal(decideAccess(asst({ topups: "edit" }), "reject_topup"), "allow");
  assert.equal(decideAccess(asst({ topups: "view" }), "approve_topup"), "deny");
  assert.equal(decideAccess(asst({ topups: "edit" }), "approve_topup"), "approval");
  assert.equal(decideAccess(asst({ topups: "approve" }), "approve_topup"), "allow");
  assert.equal(decideAccess(asst({ pending_orders: "edit" }), "assign_order"), "allow");
  assert.equal(decideAccess(asst({ orders: "weird" }), "cancel_order"), "deny");
  assert.equal(bestLevel(asst({ orders: "view", map: "edit" }), ["orders", "pending_orders", "map"]), "edit");
});

test("override ราย action และชนิดพิเศษ", () => {
  assert.equal(decideAccess(asst({ orders: "approve" }), "upsert_system_config"), "deny");
  assert.equal(decideAccess(asst({}, { upsert_system_config: "allow" }), "upsert_system_config"), "allow");
  assert.equal(decideAccess(asst({}, { team_update: "allow" }), "team_update"), "deny");
  assert.equal(decideAccess(asst({ topups: "approve" }, { approve_topup: "deny" }), "approve_topup"), "deny");
  assert.equal(decideAccess(asst({ topups: "edit" }, { reject_topup: "require_approval" }), "reject_topup"), "approval");
  assert.equal(decideAccess(asst({ topups: "view" }, { get_topup_slip_url: "require_approval" }), "get_topup_slip_url"), "deny");
  assert.equal(decideAccess(asst({ orders: "edit" }), "unknown_action_x"), "deny");
  assert.equal(decideAccess(asst({}), "approval_decide"), "allow");
});

test("ผู้พิจารณาคำขอ", () => {
  assert.equal(canDecideApproval(su, ["topups"], "a", "b"), true);
  assert.equal(canDecideApproval(su, ["topups"], "a", "a"), false);
  assert.equal(canDecideApproval(lead({ topups: "approve" }), ["topups"], "a", "b"), true);
  assert.equal(canDecideApproval(lead({ topups: "edit" }), ["topups"], "a", "b"), false);
  assert.equal(canDecideApproval(asst({ topups: "approve" }), ["topups"], "a", "b"), false);
  assert.equal(canDecideApproval({ ...lead({ topups: "approve" }), active: false }, ["topups"], "a", "b"), false);
});

test("ทำความสะอาดข้อมูลสิทธิ์", () => {
  assert.deepEqual(
    sanitizePageLevels({ topups: "edit", settings: "approve", bogus: "view", orders: "none", users: "x" }),
    { topups: "edit" },
  );
  assert.deepEqual(sanitizePageOverrides({ topups: "none", settings: "edit", users: "view", x: "view" }), { topups: "none", users: "view" });
  assert.deepEqual(
    sanitizeActionOverrides({ approve_topup: "allow", team_update: "allow", nope: "deny", reject_topup: "maybe" }),
    { approve_topup: "allow" },
  );
});
