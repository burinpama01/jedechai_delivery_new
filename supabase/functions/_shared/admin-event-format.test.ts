import { assert, assertEquals } from "https://deno.land/std@0.177.0/testing/asserts.ts";
import {
  adminPageLink,
  EMAIL_EVENT_TYPES,
  formatChatText,
  formatEmail,
  parseEmailList,
} from "./admin-event-format.ts";

const applicant = {
  title: "ร้านค้าสมัครใหม่รออนุมัติ 🏪",
  body: "ร้าน <ป้าน้อย> รอการตรวจสอบเอกสาร",
  event_type: "admin.applicant_pending",
  data: { role: "merchant", admin_page: "merchants" },
};

Deno.test("adminPageLink: สร้าง ?page= จาก data.admin_page", () => {
  assertEquals(adminPageLink(applicant), "https://jdc-delivery.vercel.app/admin?page=merchants");
  assertEquals(adminPageLink(applicant, "https://x.test/admin/?a=1"), "https://x.test/admin?page=merchants");
});

Deno.test("adminPageLink: ไม่มี/รูปแบบผิด → ไม่แนบลิงก์", () => {
  assertEquals(adminPageLink({ ...applicant, data: null }), null);
  assertEquals(adminPageLink({ ...applicant, data: { admin_page: "x&y=1" } }), null);
  assertEquals(adminPageLink({ ...applicant, data: { admin_page: "javascript:alert(1)" } }), null);
});

Deno.test("formatChatText แนบลิงก์ท้ายข้อความ", () => {
  const text = formatChatText(applicant, "https://a.test/admin?page=merchants");
  assertEquals(text.split("\n").length, 3);
  assert(text.endsWith("https://a.test/admin?page=merchants"));
  assertEquals(formatChatText(applicant, null).split("\n").length, 2);
});

Deno.test("formatEmail escape ข้อความและมีปุ่มลิงก์", () => {
  const { subject, html } = formatEmail(applicant, "https://a.test/admin?page=merchants");
  assert(subject.startsWith("[JDC Admin]"));
  assert(html.includes("&lt;ป้าน้อย&gt;"));
  assert(!html.includes("<ป้าน้อย>"));
  assert(html.includes('href="https://a.test/admin?page=merchants"'));
});

Deno.test("parseEmailList รวมหลัก + CC ตัดซ้ำและรูปแบบผิด", () => {
  assertEquals(parseEmailList("Admin@x.com", "b@y.com; admin@x.com, bad-mail"), ["admin@x.com", "b@y.com"]);
  assertEquals(parseEmailList(null, undefined, ""), []);
});

Deno.test("อีเมลส่งเฉพาะเรื่องสมาชิกใหม่", () => {
  assert(EMAIL_EVENT_TYPES.has("admin.applicant_pending"));
  assert(EMAIL_EVENT_TYPES.has("admin.daily_signup_summary"));
  assert(!EMAIL_EVENT_TYPES.has("admin.stale_order"));
});
