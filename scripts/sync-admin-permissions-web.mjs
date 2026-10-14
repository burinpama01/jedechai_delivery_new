// สร้าง admin-web/src/services/adminPermissions.js จาก supabase/functions/_shared/admin-permissions.ts
// (แคตตาล็อก/กติกาสิทธิ์ชุดเดียวกับ server) — รันทุกครั้งที่แก้ไฟล์ TS:
//   node scripts/sync-admin-permissions-web.mjs
// test/admin-permissions.test.mjs ตรวจว่าไฟล์ที่ generate ตรงกับ TS เสมอ
import { readFileSync, writeFileSync } from "node:fs";
import { stripTypeScriptTypes } from "node:module";

const ROOT = new URL("..", import.meta.url);
export const SOURCE = new URL("supabase/functions/_shared/admin-permissions.ts", ROOT);
export const TARGET = new URL("admin-web/src/services/adminPermissions.js", ROOT);

export function buildWebModule() {
  const ts = readFileSync(SOURCE, "utf8");
  const js = stripTypeScriptTypes(ts, { mode: "strip" });
  return "// GENERATED จาก supabase/functions/_shared/admin-permissions.ts — ห้ามแก้ตรงนี้\n" +
    "// แก้ที่ไฟล์ TS แล้วรัน: node scripts/sync-admin-permissions-web.mjs\n" + js;
}

if (import.meta.main) {
  writeFileSync(TARGET, buildWebModule());
  console.log("wrote", TARGET.pathname);
}
