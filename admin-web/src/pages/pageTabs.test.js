import test from "node:test";
import assert from "node:assert/strict";
import { ALL_TABS, resolveTabs } from "./pageTabs.js";

const ids = ["list", "create", "overview"];

test("resolveTabs: ไม่ระบุ = ตามการ์ดก่อนหน้า, ตัวแรกไม่ระบุ = default", () => {
  assert.deepEqual(
    resolveTabs([{ tab: null }, { tab: "overview" }, { tab: null }, { tab: "create" }], ids, "list"),
    ["list", "overview", "overview", "create"],
  );
});

test("resolveTabs: * แสดงทุกแท็บและไม่เปลี่ยนแท็บของการ์ดถัดไป", () => {
  assert.deepEqual(
    resolveTabs([{ tab: "create" }, { tab: ALL_TABS }, { tab: null }], ids, "list"),
    ["create", ALL_TABS, "create"],
  );
});

test("resolveTabs: id ที่ไม่รู้จักไปแท็บ default ไม่หายจากหน้า", () => {
  assert.deepEqual(resolveTabs([{ tab: "typo" }, { tab: null }], ids, "list"), ["list", "list"]);
});
