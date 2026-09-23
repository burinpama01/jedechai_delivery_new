// หน้าออเดอร์ฝากซื้อ/ฝากหิ้ว (S8)
//
// แท็บ "ต้องตรวจสอบ" = ออเดอร์ที่ server ยกธง needs_admin_review ไว้
// แท็บ "ทั้งหมด"     = ออเดอร์ล่าสุด
// แท็บ "คนขับ"       = รายงานคนขับ (หาคนที่ถูกยกเลิกตอนซื้อของบ่อยผิดปกติ) + ตั้ง trusted
//
// ทุกปุ่มเรียก RPC ที่ตรวจสิทธิ์แอดมินและคำนวณเงินเองที่ server — หน้านี้ไม่คิดเงิน

let _ctx = null;
let _tab = "review";
let _busy = false;

const STATUS_LABELS = {
  pending: ["รอคนขับ", "bg-amber-50 text-amber-700 border-amber-200"],
  accepted: ["คนขับกำลังไปร้าน", "bg-blue-50 text-blue-700 border-blue-200"],
  shopping: ["กำลังซื้อของ", "bg-violet-50 text-violet-700 border-violet-200"],
  receipt_review: ["รอลูกค้ายืนยันรูป", "bg-orange-50 text-orange-700 border-orange-200"],
  purchased: ["ซื้อแล้ว", "bg-teal-50 text-teal-700 border-teal-200"],
  delivering: ["กำลังนำส่ง", "bg-teal-50 text-teal-700 border-teal-200"],
  in_transit: ["กำลังนำส่ง", "bg-teal-50 text-teal-700 border-teal-200"],
  completed: ["สำเร็จ", "bg-emerald-50 text-emerald-700 border-emerald-200"],
  cancelled: ["ยกเลิก", "bg-gray-100 text-gray-500 border-gray-200"],
};

const REASON_LABELS = {
  amount_variance: "ยอดจริงต่างจากวงเงินมากผิดปกติ",
  arrival_self_reported: "คนขับยืนยันถึงร้านเอง (GPS ไม่ผ่าน)",
  cancelled_after_purchase: "ยกเลิกหลังซื้อของแล้ว — ของอยู่กับใคร?",
  customer_no_confirm: "ลูกค้าไม่ยืนยันรูปสินค้าเกินเวลา",
  expire_wallet_missing: "คืนเงินอัตโนมัติไม่สำเร็จ (ไม่พบ Wallet ลูกค้า)",
};

const RPC_ERRORS = {
  not_authorized: "ไม่มีสิทธิ์แอดมิน",
  invalid_status: "สถานะออเดอร์เปลี่ยนไปแล้ว — รีเฟรชหน้า",
  already_completed: "ออเดอร์ปิดงานไปแล้ว",
  hold_already_released: "คืนเงิน/ปิดยอดไปแล้ว",
  not_settled_yet: "คนขับยังไม่ได้ยืนยันยอดซื้อ",
  nothing_to_resolve: "ออเดอร์นี้ไม่ได้อยู่ในคิวตรวจสอบแล้ว",
  driver_not_found: "ไม่พบคนขับ",
  refund_would_be_negative: "คำนวณยอดคืนติดลบ — ตรวจออเดอร์ด้วยมือ",
  customer_wallet_not_found: "ไม่พบ Wallet ลูกค้า",
  driver_wallet_not_found: "ไม่พบ Wallet คนขับ",
};

function _deps() {
  return {
    supabase: _ctx?.supabase || globalThis.supabase,
    escapeHtml: _ctx?.escapeHtml || globalThis.escapeHtml,
    fmtDate: _ctx?.fmtDate || globalThis.fmtDate,
    showToast: _ctx?.showToast || globalThis.showToast,
    refreshCurrentPage: _ctx?.refreshCurrentPage || globalThis.refreshCurrentPage,
  };
}

// ── helper ที่ทดสอบได้ (ไม่แตะ DOM/Supabase) ─────────────────────────

/** แปลงเหตุผลธง "a | b" เป็นข้อความไทยทีละข้อ */
export function reviewReasonLabels(reason) {
  if (!reason) return [];
  return String(reason)
    .split("|")
    .map((r) => r.trim())
    .filter(Boolean)
    .map((r) => REASON_LABELS[r] || r);
}

/**
 * ปุ่มที่แอดมินกดได้ตามสถานะ — ต้องตรงกับที่ RPC ฝั่ง server ยอม
 * (confirm_proof = receipt_review · complete = purchased/delivering · cancel = ยังไม่ปิด)
 */
export function shopOrderActions(status, needsReview, holdReleased) {
  const actions = [];
  if (status === "receipt_review") actions.push("confirm_proof");
  if ((status === "purchased" || status === "delivering") && !holdReleased) actions.push("complete");
  if (status !== "completed" && status !== "cancelled" && !holdReleased) actions.push("cancel");
  if (needsReview) actions.push("resolve");
  return actions;
}

export function rpcErrorText(code) {
  return RPC_ERRORS[code] || `ทำรายการไม่สำเร็จ (${code || "unknown"})`;
}

const money = (v) =>
  v === null || v === undefined || v === ""
    ? "-"
    : `฿${Number(v).toLocaleString("th-TH", { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;

function statusChip(status) {
  const escapeHtml = _deps().escapeHtml || String;
  const [label, cls] = STATUS_LABELS[status] || [status || "-", "bg-gray-100 text-gray-500 border-gray-200"];
  return `<span class="inline-flex px-2.5 py-0.5 rounded-lg text-xs font-semibold border ${cls}">${escapeHtml(label)}</span>`;
}

// ── data ─────────────────────────────────────────────────────────────

async function loadOrders(supabase, reviewOnly) {
  let q = supabase
    .from("shop_orders")
    .select(
      "id, booking_id, store_name, budget_cap, hold_amount, total_amount, refund_amount, cancel_fee, " +
        "needs_admin_review, admin_review_reason, admin_review_note, admin_reviewed_at, hold_released, " +
        "budget_increase_status, budget_increase_amount, proof_mode, created_at, " +
        "booking:bookings(status, customer_id, driver_id, destination_address, notes)",
    )
    .order("created_at", { ascending: false })
    .limit(100);
  if (reviewOnly) q = q.eq("needs_admin_review", true);
  const { data, error } = await q;
  if (error) throw error;
  const rows = data || [];

  const ids = [...new Set(rows.flatMap((r) => [r.booking?.customer_id, r.booking?.driver_id]).filter(Boolean))];
  const names = {};
  if (ids.length) {
    const { data: people } = await supabase.from("profiles").select("id, full_name, phone_number").in("id", ids);
    for (const p of people || []) names[p.id] = p;
  }
  return { rows, names };
}

// ── render ───────────────────────────────────────────────────────────

export async function renderShopOrdersPage(el, ctx) {
  _ctx = ctx || null;
  const { supabase, escapeHtml } = _deps();

  const reviewCount = await supabase
    .from("shop_orders")
    .select("id", { count: "exact", head: true })
    .eq("needs_admin_review", true);
  const nReview = reviewCount.count || 0;

  const tabBtn = (key, label, badge) => `
    <button onclick="setShopOrdersTab('${key}')"
      class="px-4 py-2 rounded-xl text-sm font-semibold border ${
        _tab === key ? "bg-violet-600 text-white border-violet-600" : "bg-white text-gray-600 border-gray-200 hover:bg-gray-50"
      }">
      ${label}${badge ? ` <span class="ml-1 inline-flex px-2 rounded-full text-xs ${_tab === key ? "bg-white/25" : "bg-red-100 text-red-600"}">${badge}</span>` : ""}
    </button>`;

  let body = "";
  try {
    body = _tab === "drivers" ? await renderDriversTab(supabase, escapeHtml) : await renderOrdersTab(supabase, escapeHtml, _tab === "review");
  } catch (e) {
    body = `<div class="glass-card p-6 text-red-500">โหลดข้อมูลไม่สำเร็จ: ${escapeHtml(e.message || String(e))}</div>`;
  }

  el.innerHTML = `
    <div class="fade-in space-y-5">
      <div class="flex flex-wrap gap-2">
        ${tabBtn("review", "ต้องตรวจสอบ", nReview)}
        ${tabBtn("all", "ออเดอร์ทั้งหมด", 0)}
        ${tabBtn("drivers", "คนขับ", 0)}
      </div>
      ${body}
      <div id="shopOrderDialog"></div>
    </div>`;

  globalThis.setShopOrdersTab = setShopOrdersTab;
  globalThis.openShopOrder = openShopOrder;
  globalThis.closeShopOrderDialog = closeShopOrderDialog;
  globalThis.shopOrderAction = shopOrderAction;
  globalThis.toggleShopTrusted = toggleShopTrusted;
}

async function renderOrdersTab(supabase, escapeHtml, reviewOnly) {
  const { rows, names } = await loadOrders(supabase, reviewOnly);
  globalThis._shopOrdersCache = { rows, names };
  const who = (id) => (id && names[id]?.full_name) || (id ? id.slice(0, 8) : "-");

  const tr = rows
    .map((o) => {
      const reasons = reviewReasonLabels(o.admin_review_reason);
      return `
      <tr class="border-b border-gray-100 hover:bg-gray-50 cursor-pointer" onclick="openShopOrder('${escapeHtml(o.booking_id)}')">
        <td class="px-3 py-3 text-xs text-gray-500 whitespace-nowrap">#${escapeHtml(o.booking_id.slice(0, 8))}</td>
        <td class="px-3 py-3 text-sm font-semibold text-gray-800">${escapeHtml(o.store_name)}</td>
        <td class="px-3 py-3 text-sm text-gray-600">${escapeHtml(who(o.booking?.customer_id))}</td>
        <td class="px-3 py-3 text-sm text-gray-600">${escapeHtml(who(o.booking?.driver_id))}</td>
        <td class="px-3 py-3 text-sm text-gray-700 whitespace-nowrap">${money(o.hold_amount)}</td>
        <td class="px-3 py-3">${statusChip(o.booking?.status)}</td>
        <td class="px-3 py-3 text-xs ${o.needs_admin_review ? "text-red-600 font-semibold" : "text-gray-400"}">
          ${reasons.length ? reasons.map((r) => escapeHtml(r)).join("<br>") : "-"}
        </td>
      </tr>`;
    })
    .join("");

  return `
    <div class="glass-card overflow-x-auto">
      <table class="w-full text-left">
        <thead>
          <tr class="text-xs text-gray-400 uppercase border-b border-gray-100">
            <th class="px-3 py-3 font-semibold">ออเดอร์</th>
            <th class="px-3 py-3 font-semibold">ร้าน</th>
            <th class="px-3 py-3 font-semibold">ลูกค้า</th>
            <th class="px-3 py-3 font-semibold">คนขับ</th>
            <th class="px-3 py-3 font-semibold">กันวงเงิน</th>
            <th class="px-3 py-3 font-semibold">สถานะ</th>
            <th class="px-3 py-3 font-semibold">ต้องตรวจสอบเพราะ</th>
          </tr>
        </thead>
        <tbody>
          ${tr || `<tr><td colspan="7" class="px-3 py-10 text-center text-gray-400">${reviewOnly ? "ไม่มีออเดอร์ที่ต้องตรวจสอบ" : "ยังไม่มีออเดอร์ฝากซื้อ"}</td></tr>`}
        </tbody>
      </table>
    </div>`;
}

async function renderDriversTab(supabase, escapeHtml) {
  const { data, error } = await supabase.rpc("shop_admin_driver_stats", { p_days: 30 });
  if (error) throw error;
  const rows = (data || []).sort(
    (a, b) => Number(b.fee_cancel_rate) - Number(a.fee_cancel_rate) || Number(b.total_jobs) - Number(a.total_jobs),
  );

  const tr = rows
    .map((d) => {
      const rate = Number(d.fee_cancel_rate || 0);
      // ยังไม่มีเกณฑ์จากข้อมูลจริง -> ไฮไลต์เมื่อ >= 3 งานและอัตรายกเลิกมีค่าปรับ >= 30%
      const suspicious = Number(d.total_jobs) >= 3 && rate >= 30;
      return `
      <tr class="border-b border-gray-100 ${suspicious ? "bg-red-50/60" : "hover:bg-gray-50"}">
        <td class="px-3 py-3">
          <div class="font-semibold text-gray-800">${escapeHtml(d.full_name || d.driver_id.slice(0, 8))}</div>
          <div class="text-xs text-gray-400">${escapeHtml(d.phone_number || "")}</div>
        </td>
        <td class="px-3 py-3 text-sm text-gray-700">${d.total_jobs}</td>
        <td class="px-3 py-3 text-sm text-emerald-700">${d.completed_jobs}</td>
        <td class="px-3 py-3 text-sm text-gray-600">${d.cancelled_jobs}</td>
        <td class="px-3 py-3 text-sm ${suspicious ? "text-red-600 font-bold" : "text-gray-700"}">${d.cancelled_with_fee} (${rate}%)</td>
        <td class="px-3 py-3 text-sm text-gray-700 whitespace-nowrap">${money(d.cancel_fee_total)}</td>
        <td class="px-3 py-3 text-sm text-gray-600">${d.self_reported_arrivals}</td>
        <td class="px-3 py-3 text-right">
          <button onclick="toggleShopTrusted('${escapeHtml(d.driver_id)}', ${d.trusted ? "false" : "true"})"
            class="px-3 py-1.5 rounded-lg text-xs font-semibold border ${
              d.trusted ? "bg-emerald-50 text-emerald-700 border-emerald-200 hover:bg-emerald-100" : "bg-white text-gray-600 border-gray-200 hover:bg-gray-50"
            }">
            ${d.trusted ? "Trusted ✓ (กดเพื่อถอน)" : "ตั้งเป็น Trusted"}
          </button>
        </td>
      </tr>`;
    })
    .join("");

  return `
    <div class="glass-card p-4 text-sm text-gray-600">
      ย้อนหลัง 30 วัน · <b>Trusted</b> = รับงานวงเงินเกินเพดานคนขับใหม่ได้ทันที (วันแรกที่เปิดบริการทุกคนยังเป็นคนขับใหม่ ต้องตั้งอย่างน้อย 1 คน)
      · แถวสีแดง = ถูกยกเลิกตอนซื้อของ (มีค่าปรับ) ตั้งแต่ 30% ขึ้นไป ควรตรวจว่ามีการสมคบแบ่งค่าปรับหรือไม่
    </div>
    <div class="glass-card overflow-x-auto">
      <table class="w-full text-left">
        <thead>
          <tr class="text-xs text-gray-400 uppercase border-b border-gray-100">
            <th class="px-3 py-3 font-semibold">คนขับ</th>
            <th class="px-3 py-3 font-semibold">งานฝากซื้อ</th>
            <th class="px-3 py-3 font-semibold">สำเร็จ</th>
            <th class="px-3 py-3 font-semibold">ยกเลิก</th>
            <th class="px-3 py-3 font-semibold">ยกเลิกมีค่าปรับ</th>
            <th class="px-3 py-3 font-semibold">ค่าปรับรวม</th>
            <th class="px-3 py-3 font-semibold">ยืนยันถึงร้านเอง</th>
            <th class="px-3 py-3"></th>
          </tr>
        </thead>
        <tbody>
          ${tr || `<tr><td colspan="8" class="px-3 py-10 text-center text-gray-400">ยังไม่มีคนขับ</td></tr>`}
        </tbody>
      </table>
    </div>`;
}

export async function setShopOrdersTab(tab) {
  _tab = tab;
  await _deps().refreshCurrentPage?.();
}

// ── รายละเอียดออเดอร์ ─────────────────────────────────────────────────

export async function openShopOrder(bookingId) {
  const { supabase, escapeHtml, fmtDate } = _deps();
  const host = document.getElementById("shopOrderDialog");
  if (!host) return;

  const cache = globalThis._shopOrdersCache || { rows: [], names: {} };
  const o = cache.rows.find((r) => r.booking_id === bookingId);
  if (!o) return;

  const { data: full } = await supabase.from("shop_orders").select("id, proof_urls").eq("booking_id", bookingId).maybeSingle();
  const { data: items } = await supabase
    .from("shop_order_items")
    .select("line_no, name_text, quantity_text, note, status, actual_price, substitute_name, ref_image_path")
    .eq("shop_order_id", full?.id || o.id)
    .order("line_no");

  // bucket ส่วนตัว -> signed URL อายุสั้น (แอดมินอ่านได้ตาม policy shop receipts party read)
  const paths = [...(full?.proof_urls || []), ...(items || []).map((i) => i.ref_image_path).filter(Boolean)];
  const signed = {};
  if (paths.length) {
    const { data: urls } = await supabase.storage.from("shop-receipts").createSignedUrls(paths, 600);
    for (const u of urls || []) if (u?.signedUrl) signed[u.path] = u.signedUrl;
  }

  const who = (id) => {
    const p = id && cache.names[id];
    return p ? `${escapeHtml(p.full_name || "-")} <span class="text-gray-400">${escapeHtml(p.phone_number || "")}</span>` : "-";
  };
  const itemStatus = { pending: "ยังไม่ติ๊ก", bought: "ซื้อแล้ว", unavailable: "ของหมด", substituted: "ของทดแทน" };
  const itemRows = (items || [])
    .map(
      (i) => `
      <tr class="border-b border-gray-100">
        <td class="py-2 pr-2 text-xs text-gray-400">${i.line_no}</td>
        <td class="py-2 pr-2 text-sm text-gray-800">
          ${escapeHtml(i.name_text)} ${i.quantity_text ? `<span class="text-gray-400">· ${escapeHtml(i.quantity_text)}</span>` : ""}
          ${i.substitute_name ? `<div class="text-xs text-orange-600">แทนด้วย: ${escapeHtml(i.substitute_name)}</div>` : ""}
          ${i.note ? `<div class="text-xs text-gray-400">${escapeHtml(i.note)}</div>` : ""}
          ${i.ref_image_path && signed[i.ref_image_path] ? `<a href="${escapeHtml(signed[i.ref_image_path])}" target="_blank" rel="noopener" class="text-xs text-blue-600 underline">รูปตัวอย่างจากลูกค้า</a>` : ""}
        </td>
        <td class="py-2 pr-2 text-xs text-gray-600 whitespace-nowrap">${itemStatus[i.status] || escapeHtml(i.status)}</td>
        <td class="py-2 text-sm text-gray-700 text-right whitespace-nowrap">${money(i.actual_price)}</td>
      </tr>`,
    )
    .join("");

  const proofs = (full?.proof_urls || [])
    .map((p) => (signed[p] ? `<a href="${escapeHtml(signed[p])}" target="_blank" rel="noopener"><img src="${escapeHtml(signed[p])}" class="w-24 h-24 object-cover rounded-lg border border-gray-200"></a>` : ""))
    .join("");

  const status = o.booking?.status;
  const actions = shopOrderActions(status, o.needs_admin_review, o.hold_released);
  const btn = (key, label, cls) =>
    actions.includes(key)
      ? `<button onclick="shopOrderAction('${escapeHtml(bookingId)}', '${key}')" class="px-3 py-2 rounded-lg text-sm font-semibold border ${cls}">${label}</button>`
      : "";
  const reasons = reviewReasonLabels(o.admin_review_reason);

  host.innerHTML = `
    <div class="fixed inset-0 z-50 bg-black/40 flex items-start justify-center overflow-y-auto p-4" onclick="if(event.target===this) closeShopOrderDialog()">
      <div class="bg-white rounded-2xl shadow-xl w-full max-w-2xl mt-8 mb-8">
        <div class="flex items-center justify-between px-5 py-4 border-b border-gray-100">
          <div>
            <div class="font-bold text-gray-800">${escapeHtml(o.store_name)} · #${escapeHtml(bookingId.slice(0, 8))}</div>
            <div class="text-xs text-gray-400">${fmtDate ? escapeHtml(fmtDate(o.created_at)) : ""}</div>
          </div>
          <div class="flex items-center gap-2">${statusChip(status)}
            <button onclick="closeShopOrderDialog()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
          </div>
        </div>
        <div class="px-5 py-4 space-y-4">
          ${
            reasons.length
              ? `<div class="p-3 rounded-xl bg-red-50 border border-red-200 text-sm text-red-700">
                   <b>ต้องตรวจสอบ:</b><br>${reasons.map((r) => escapeHtml(r)).join("<br>")}
                 </div>`
              : ""
          }
          ${o.admin_review_note ? `<div class="text-xs text-gray-500">บันทึกแอดมินล่าสุด: ${escapeHtml(o.admin_review_note)}</div>` : ""}
          <div class="grid grid-cols-2 gap-3 text-sm">
            <div><div class="text-xs text-gray-400">ลูกค้า</div>${who(o.booking?.customer_id)}</div>
            <div><div class="text-xs text-gray-400">คนขับ</div>${who(o.booking?.driver_id)}</div>
            <div class="col-span-2"><div class="text-xs text-gray-400">ส่งที่</div>${escapeHtml(o.booking?.destination_address || "-")}</div>
          </div>
          <div class="grid grid-cols-2 md:grid-cols-4 gap-3 text-sm">
            <div><div class="text-xs text-gray-400">วงเงินสินค้า</div>${money(o.budget_cap)}</div>
            <div><div class="text-xs text-gray-400">กันไว้จาก Wallet</div>${money(o.hold_amount)}</div>
            <div><div class="text-xs text-gray-400">ยอดจริง</div>${money(o.total_amount)}</div>
            <div><div class="text-xs text-gray-400">คืนลูกค้า / ค่าปรับ</div>${money(o.refund_amount)} / ${money(o.cancel_fee)}</div>
          </div>
          ${
            o.budget_increase_status
              ? `<div class="text-xs text-gray-500">คำขอเพิ่มวงเงิน: ${escapeHtml(o.budget_increase_status)} · ${money(o.budget_increase_amount)}</div>`
              : ""
          }
          <table class="w-full text-left">${itemRows || `<tr><td class="text-gray-400 text-sm">ไม่มีรายการ</td></tr>`}</table>
          ${proofs ? `<div><div class="text-xs text-gray-400 mb-1">หลักฐานจากคนขับ</div><div class="flex flex-wrap gap-2">${proofs}</div></div>` : ""}
          ${o.booking?.notes ? `<div class="text-xs text-gray-400">หมายเหตุ: ${escapeHtml(o.booking.notes)}</div>` : ""}
        </div>
        <div class="px-5 py-4 border-t border-gray-100 flex flex-wrap gap-2 justify-end">
          ${btn("confirm_proof", "ยืนยันรูปแทนลูกค้า", "bg-orange-50 text-orange-700 border-orange-200 hover:bg-orange-100")}
          ${btn("complete", "ปิดงาน + คืนส่วนต่าง", "bg-emerald-50 text-emerald-700 border-emerald-200 hover:bg-emerald-100")}
          ${btn("cancel", "ยกเลิก + คืนเงิน", "bg-red-50 text-red-600 border-red-200 hover:bg-red-100")}
          ${btn("resolve", "ทำเครื่องหมายตรวจแล้ว", "bg-violet-600 text-white border-violet-600 hover:bg-violet-700")}
        </div>
      </div>
    </div>`;
}

export function closeShopOrderDialog() {
  const host = document.getElementById("shopOrderDialog");
  if (host) host.innerHTML = "";
}

const CONFIRM_TEXT = {
  confirm_proof: "ยืนยันรูปสินค้าแทนลูกค้า? (ควรติดต่อลูกค้าแล้ว)",
  complete: "ปิดงาน: คืนส่วนต่างให้ลูกค้าและจ่ายคนขับตามยอดจริง?",
};

export async function shopOrderAction(bookingId, action) {
  if (_busy) return;
  const { supabase, showToast, refreshCurrentPage } = _deps();

  let rpc;
  let params;
  if (action === "cancel") {
    const reason = globalThis.prompt?.(
      "เหตุผลที่ยกเลิก (ถ้าคนขับซื้อของไปแล้ว ระบบจะกันค่าสินค้าคืนคนขับก่อน แล้วคืนส่วนที่เหลือให้ลูกค้า)",
      "",
    );
    if (reason === null || reason === undefined) return;
    rpc = "cancel_shop_booking";
    params = { p_booking_id: bookingId, p_reason: reason ? `แอดมิน: ${reason}` : "แอดมินยกเลิก" };
  } else if (action === "resolve") {
    const note = globalThis.prompt?.("บันทึกสิ่งที่ตรวจ/ดำเนินการ", "");
    if (note === null || note === undefined) return;
    rpc = "shop_admin_resolve_review";
    params = { p_booking_id: bookingId, p_note: note };
  } else if (action === "confirm_proof" || action === "complete") {
    if (globalThis.confirm && !globalThis.confirm(CONFIRM_TEXT[action])) return;
    rpc = action === "confirm_proof" ? "shop_customer_confirm_proof" : "complete_shop_booking";
    params = { p_booking_id: bookingId };
  } else {
    return;
  }

  _busy = true;
  try {
    const { data, error } = await supabase.rpc(rpc, params);
    if (error) return showToast?.(`ทำรายการไม่สำเร็จ: ${error.message}`, "error");
    if (!data?.success) return showToast?.(rpcErrorText(data?.error), "error");
    showToast?.("ทำรายการแล้ว", "success");
    closeShopOrderDialog();
    await refreshCurrentPage?.();
  } finally {
    _busy = false;
  }
}

export async function toggleShopTrusted(driverId, trusted) {
  if (_busy) return;
  const { supabase, showToast, refreshCurrentPage } = _deps();
  const msg = trusted
    ? "ตั้งคนขับนี้เป็น Trusted? จะรับงานวงเงินเกินเพดานคนขับใหม่ได้ทันที"
    : "ถอน Trusted? คนขับจะกลับไปใช้เพดานคนขับใหม่จนกว่าจะทำงานครบเกณฑ์";
  if (globalThis.confirm && !globalThis.confirm(msg)) return;

  _busy = true;
  try {
    const { data, error } = await supabase.rpc("shop_admin_set_trusted", {
      p_driver_id: driverId,
      p_trusted: trusted,
      p_note: null,
    });
    if (error) return showToast?.(`ทำรายการไม่สำเร็จ: ${error.message}`, "error");
    if (!data?.success) return showToast?.(rpcErrorText(data?.error), "error");
    showToast?.(trusted ? "ตั้งเป็น Trusted แล้ว" : "ถอน Trusted แล้ว", "success");
    await refreshCurrentPage?.();
  } finally {
    _busy = false;
  }
}
