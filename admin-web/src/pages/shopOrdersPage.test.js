import test from "node:test";
import assert from "node:assert/strict";
import { reviewReasonLabels, rpcErrorText, shopOrderActions } from "./shopOrdersPage.js";

test("แปลงเหตุผลธงหลายข้อเป็นข้อความไทย และคงรหัสที่ไม่รู้จักไว้", () => {
  assert.deepEqual(reviewReasonLabels(null), []);
  assert.deepEqual(reviewReasonLabels(""), []);
  assert.deepEqual(reviewReasonLabels("amount_variance | customer_no_confirm"), [
    "ยอดจริงต่างจากวงเงินมากผิดปกติ",
    "ลูกค้าไม่ยืนยันรูปสินค้าเกินเวลา",
  ]);
  assert.deepEqual(reviewReasonLabels("something_new"), ["something_new"]);
});

test("ปุ่มตามสถานะตรงกับที่ RPC ฝั่ง server ยอม", () => {
  assert.deepEqual(shopOrderActions("pending", false, false), ["cancel"]);
  assert.deepEqual(shopOrderActions("shopping", true, false), ["cancel", "resolve"]);
  assert.deepEqual(shopOrderActions("receipt_review", true, false), ["confirm_proof", "cancel", "resolve"]);
  assert.deepEqual(shopOrderActions("purchased", false, false), ["complete", "cancel"]);
  assert.deepEqual(shopOrderActions("delivering", false, false), ["complete", "cancel"]);
});

test("ออเดอร์ที่ปิดยอดแล้วเหลือแค่ปุ่มปิดธง", () => {
  assert.deepEqual(shopOrderActions("completed", false, true), []);
  assert.deepEqual(shopOrderActions("cancelled", true, true), ["resolve"]);
  // คืน hold แล้วแต่สถานะยังค้าง (ไม่ควรเกิด) — ห้ามให้กดปิดงาน/ยกเลิกซ้ำ
  assert.deepEqual(shopOrderActions("purchased", false, true), []);
});

test("ข้อความ error จาก RPC", () => {
  assert.equal(rpcErrorText("not_authorized"), "ไม่มีสิทธิ์แอดมิน");
  assert.match(rpcErrorText("weird_code"), /weird_code/);
  assert.match(rpcErrorText(undefined), /unknown/);
});
