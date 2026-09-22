// หน้าจัดการร้านฝากซื้อ/ฝากหิ้ว
//
// ตำแหน่งร้าน ชื่อ และเวลาเปิด-ปิด แอดมินเป็นคนตั้งเท่านั้น (ลูกค้า/คนขับ SELECT อย่างเดียว)
// การเขียนถูกคุมด้วย RLS shop_stores_admin_* -> ถ้าไม่ใช่แอดมินจะเขียนไม่ผ่านตั้งแต่ DB

const DAYS = [
  ["mon", "จันทร์"],
  ["tue", "อังคาร"],
  ["wed", "พุธ"],
  ["thu", "พฤหัสบดี"],
  ["fri", "ศุกร์"],
  ["sat", "เสาร์"],
  ["sun", "อาทิตย์"],
];

const CATEGORIES = [
  ["grocery", "ร้านของชำ", "storefront"],
  ["mall", "ห้างสรรพสินค้า", "local_mall"],
  ["market", "ตลาดสด", "shopping_basket"],
  ["convenience", "ร้านสะดวกซื้อ", "local_convenience_store"],
  ["pharmacy", "ร้านขายยา", "medical_services"],
];

let _ctx = null;

function _deps() {
  return {
    supabase: _ctx?.supabase || globalThis.supabase,
    escapeHtml: _ctx?.escapeHtml || globalThis.escapeHtml,
    fmtDate: _ctx?.fmtDate || globalThis.fmtDate,
    showToast: _ctx?.showToast || globalThis.showToast,
    refreshCurrentPage: _ctx?.refreshCurrentPage || globalThis.refreshCurrentPage,
  };
}

function categoryLabel(key) {
  const found = CATEGORIES.find((c) => c[0] === key);
  return found ? found[1] : key;
}

function categoryIcon(key) {
  const found = CATEGORIES.find((c) => c[0] === key);
  return found ? found[2] : "storefront";
}

// สรุปเวลาเปิด-ปิดให้อ่านง่ายในตาราง
function summarizeHours(store) {
  if (store.is_24h) return "เปิด 24 ชม.";
  const hours = store.opening_hours || {};
  const open = DAYS.filter(([k]) => Array.isArray(hours[k]) && hours[k].length > 0);
  if (open.length === 0) return "ยังไม่ได้ตั้งเวลา";
  if (open.length === 7) {
    const first = JSON.stringify(hours.mon);
    const same = DAYS.every(([k]) => JSON.stringify(hours[k]) === first);
    if (same) {
      return hours.mon.map((r) => `${r.open}-${r.close}`).join(", ") + " ทุกวัน";
    }
  }
  return `เปิด ${open.length} วัน/สัปดาห์`;
}

// สถานะเปิด/ปิด "ตอนนี้" — คำนวณคร่าว ๆ ฝั่งหน้าเว็บเพื่อแสดงผลเท่านั้น
// แหล่งความจริงคือ shop_store_is_open_at() ฝั่ง server (แอปลูกค้าอ่านจากตรงนั้น)
function isOpenNowApprox(store) {
  if (!store.is_active) return false;
  if (store.manual_closed_until && new Date(store.manual_closed_until) > new Date()) return false;
  if (store.is_24h) return true;

  const now = new Date();
  const bkk = new Date(now.toLocaleString("en-US", { timeZone: "Asia/Bangkok" }));
  const key = DAYS[(bkk.getDay() + 6) % 7][0];
  const minutes = bkk.getHours() * 60 + bkk.getMinutes();
  const ranges = (store.opening_hours || {})[key];
  if (!Array.isArray(ranges)) return false;

  const toMin = (s) => {
    const p = String(s || "").split(":");
    return p.length >= 2 ? Number(p[0]) * 60 + Number(p[1]) : null;
  };

  // c <= o = ข้ามเที่ยงคืน: เปิดตั้งแต่ o ถึงสิ้นวัน และต่อจากเที่ยงคืนถึง c
  return ranges.some((r) => {
    const o = toMin(r.open);
    const c = toMin(r.close);
    if (o === null || c === null) return false;
    return c > o ? minutes >= o && minutes < c : minutes >= o || minutes < c;
  });
}

export async function renderShopStoresPage(el, ctx) {
  _ctx = ctx || null;
  const { supabase, escapeHtml } = _deps();

  const { data: stores, error } = await supabase
    .from("shop_stores")
    .select("*")
    .order("is_active", { ascending: false })
    .order("name", { ascending: true });

  if (error) {
    el.innerHTML = `<p class="text-red-500">Error: ${escapeHtml(error.message)}</p>`;
    return;
  }

  const list = stores || [];
  const active = list.filter((s) => s.is_active);
  const openNow = active.filter(isOpenNowApprox);
  const noHours = active.filter((s) => !s.is_24h && summarizeHours(s) === "ยังไม่ได้ตั้งเวลา");

  const rows = list
    .map((s) => {
      const open = isOpenNowApprox(s);
      const statusChip = !s.is_active
        ? `<span class="inline-flex px-2.5 py-0.5 rounded-lg text-xs font-semibold bg-gray-100 text-gray-500 border border-gray-200">ปิดใช้งาน</span>`
        : open
          ? `<span class="inline-flex px-2.5 py-0.5 rounded-lg text-xs font-semibold bg-emerald-50 text-emerald-600 border border-emerald-200">เปิดอยู่</span>`
          : `<span class="inline-flex px-2.5 py-0.5 rounded-lg text-xs font-semibold bg-amber-50 text-amber-600 border border-amber-200">ปิดอยู่</span>`;

      const receiptChip = s.issues_receipt
        ? `<span class="text-xs text-gray-500">มีใบเสร็จ</span>`
        : `<span class="text-xs text-orange-600 font-semibold">ไม่มีใบเสร็จ</span>`;

      return `
      <tr class="border-b border-gray-100 hover:bg-gray-50">
        <td class="px-3 py-3">
          <div class="flex items-center gap-2.5">
            <div class="w-9 h-9 rounded-xl bg-violet-50 flex items-center justify-center shrink-0">
              <span class="material-icons-round text-violet-500 text-lg">${categoryIcon(s.category)}</span>
            </div>
            <div class="min-w-0">
              <div class="font-semibold text-gray-800 truncate">${escapeHtml(s.name)}</div>
              <div class="text-xs text-gray-400 truncate">${escapeHtml(s.address || "-")}</div>
            </div>
          </div>
        </td>
        <td class="px-3 py-3 text-sm text-gray-600">${categoryLabel(s.category)}</td>
        <td class="px-3 py-3 text-xs text-gray-500 whitespace-nowrap">${Number(s.lat).toFixed(5)}, ${Number(s.lng).toFixed(5)}</td>
        <td class="px-3 py-3 text-sm text-gray-600">${escapeHtml(summarizeHours(s))}</td>
        <td class="px-3 py-3">${receiptChip}</td>
        <td class="px-3 py-3 text-sm text-gray-600">${s.service_radius_km ? `${s.service_radius_km} กม.` : "ใช้ค่ากลาง"}</td>
        <td class="px-3 py-3">${statusChip}</td>
        <td class="px-3 py-3 text-right whitespace-nowrap">
          <button onclick="editShopStore('${s.id}')" class="px-3 py-1.5 rounded-lg text-xs font-semibold bg-blue-50 text-blue-600 border border-blue-200 hover:bg-blue-100">แก้ไข</button>
          <button onclick="toggleShopStoreClosed('${s.id}')" class="px-3 py-1.5 rounded-lg text-xs font-semibold bg-amber-50 text-amber-700 border border-amber-200 hover:bg-amber-100 ml-1">
            ${s.manual_closed_until && new Date(s.manual_closed_until) > new Date() ? "เปิดร้าน" : "ปิดชั่วคราว"}
          </button>
        </td>
      </tr>`;
    })
    .join("");

  el.innerHTML = `
    <div class="fade-in space-y-5">
      ${
        noHours.length
          ? `<div class="glass-card p-4 border-l-4 border-amber-400 bg-amber-50/50">
               <div class="flex items-start gap-2">
                 <span class="material-icons-round text-amber-500">warning</span>
                 <div class="text-sm text-amber-800">
                   มีร้านที่เปิดใช้งานแต่ <b>ยังไม่ได้ตั้งเวลาเปิด-ปิด ${noHours.length} ร้าน</b>
                   — ร้านเหล่านี้จะถูกนับว่า "ปิดตลอดเวลา" และลูกค้าจะกดเลือกไม่ได้
                 </div>
               </div>
             </div>`
          : ""
      }

      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div class="glass-card p-4">
          <div class="text-xs text-gray-400 mb-1">ร้านที่เปิดใช้งาน</div>
          <div class="text-2xl font-bold text-gray-800">${active.length}</div>
        </div>
        <div class="glass-card p-4">
          <div class="text-xs text-gray-400 mb-1">เปิดอยู่ตอนนี้</div>
          <div class="text-2xl font-bold text-emerald-600">${openNow.length}</div>
        </div>
        <div class="glass-card p-4">
          <div class="text-xs text-gray-400 mb-1">ร้านทั้งหมด</div>
          <div class="text-2xl font-bold text-gray-800">${list.length}</div>
        </div>
      </div>

      <div class="glass-card p-4 flex flex-wrap gap-3 items-center justify-between">
        <div class="text-sm text-gray-500">
          ตำแหน่งและเวลาเปิด-ปิดของร้าน แอดมินเป็นผู้ตั้งเท่านั้น
        </div>
        <button onclick="editShopStore(null)" class="px-4 py-2 rounded-xl text-sm font-semibold text-white shadow-md shadow-violet-200" style="background:linear-gradient(135deg,#8b5cf6,#6366f1);">
          <span class="material-icons-round text-sm align-middle">add</span> เพิ่มร้าน
        </button>
      </div>

      <div class="glass-card overflow-x-auto">
        <table class="w-full text-left">
          <thead>
            <tr class="text-xs text-gray-400 uppercase border-b border-gray-100">
              <th class="px-3 py-3 font-semibold">ร้าน</th>
              <th class="px-3 py-3 font-semibold">หมวด</th>
              <th class="px-3 py-3 font-semibold">พิกัด</th>
              <th class="px-3 py-3 font-semibold">เวลาเปิด-ปิด</th>
              <th class="px-3 py-3 font-semibold">ใบเสร็จ</th>
              <th class="px-3 py-3 font-semibold">รัศมี</th>
              <th class="px-3 py-3 font-semibold">สถานะ</th>
              <th class="px-3 py-3"></th>
            </tr>
          </thead>
          <tbody>
            ${
              rows ||
              `<tr><td colspan="8" class="px-3 py-10 text-center text-gray-400">
                 ยังไม่มีร้าน — ต้องเพิ่มร้านอย่างน้อย 1 ร้านก่อนเปิดใช้บริการฝากซื้อ
               </td></tr>`
            }
          </tbody>
        </table>
      </div>

      <div id="shopStoreDialog"></div>
    </div>`;

  globalThis._allShopStores = list;
  globalThis.editShopStore = editShopStore;
  globalThis.saveShopStore = saveShopStore;
  globalThis.closeShopStoreDialog = closeShopStoreDialog;
  globalThis.toggleShopStoreClosed = toggleShopStoreClosed;
  globalThis.copyMondayHoursToAll = copyMondayHoursToAll;
}

// ── ฟอร์มเพิ่ม/แก้ไข ────────────────────────────────────────
export function editShopStore(id) {
  const { escapeHtml } = _deps();
  const store = id ? (globalThis._allShopStores || []).find((s) => s.id === id) : null;
  const hours = store?.opening_hours || {};

  const dayRows = DAYS.map(([key, label]) => {
    const range = Array.isArray(hours[key]) && hours[key].length ? hours[key][0] : null;
    const range2 = Array.isArray(hours[key]) && hours[key].length > 1 ? hours[key][1] : null;
    return `
      <tr>
        <td class="py-1.5 pr-3 text-sm text-gray-600 whitespace-nowrap">${label}</td>
        <td class="py-1.5 pr-2"><input type="time" id="h_${key}_o" value="${range?.open || ""}" class="border border-gray-200 rounded-lg px-2 py-1 text-sm"></td>
        <td class="py-1.5 pr-2 text-gray-400 text-sm">ถึง</td>
        <td class="py-1.5 pr-3"><input type="time" id="h_${key}_c" value="${range?.close || ""}" class="border border-gray-200 rounded-lg px-2 py-1 text-sm"></td>
        <td class="py-1.5 pr-2 text-gray-400 text-xs">ช่วงที่ 2</td>
        <td class="py-1.5 pr-2"><input type="time" id="h2_${key}_o" value="${range2?.open || ""}" class="border border-gray-200 rounded-lg px-2 py-1 text-sm"></td>
        <td class="py-1.5 pr-2 text-gray-400 text-sm">ถึง</td>
        <td class="py-1.5"><input type="time" id="h2_${key}_c" value="${range2?.close || ""}" class="border border-gray-200 rounded-lg px-2 py-1 text-sm"></td>
      </tr>`;
  }).join("");

  const host = document.getElementById("shopStoreDialog");
  if (!host) return;

  host.innerHTML = `
    <div class="fixed inset-0 bg-black/40 flex items-start justify-center z-50 overflow-y-auto py-8" onclick="if(event.target===this)closeShopStoreDialog()">
      <div class="bg-white rounded-2xl p-6 w-full max-w-3xl mx-4 shadow-2xl">
        <div class="flex items-center justify-between mb-4">
          <h3 class="text-lg font-bold text-gray-800">${store ? "แก้ไขร้าน" : "เพิ่มร้านใหม่"}</h3>
          <button onclick="closeShopStoreDialog()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
        </div>

        <input type="hidden" id="ss_id" value="${store?.id || ""}">

        <div class="grid grid-cols-1 md:grid-cols-2 gap-4 mb-4">
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1">ชื่อร้าน *</label>
            <input id="ss_name" value="${escapeHtml(store?.name || "")}" class="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1">หมวด *</label>
            <select id="ss_category" class="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm">
              ${CATEGORIES.map(([k, l]) => `<option value="${k}" ${store?.category === k ? "selected" : ""}>${l}</option>`).join("")}
            </select>
          </div>
          <div class="md:col-span-2">
            <label class="block text-xs font-semibold text-gray-500 mb-1">ที่อยู่ (ให้คนขับนำทาง)</label>
            <input id="ss_address" value="${escapeHtml(store?.address || "")}" class="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1">Latitude *</label>
            <input id="ss_lat" type="number" step="any" value="${store?.lat ?? ""}" class="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1">Longitude *</label>
            <input id="ss_lng" type="number" step="any" value="${store?.lng ?? ""}" class="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1">รัศมีเฉพาะร้าน (กม.)</label>
            <input id="ss_radius" type="number" step="0.1" value="${store?.service_radius_km ?? ""}" placeholder="เว้นว่าง = ใช้ค่ากลาง" class="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1">หมายเหตุให้คนขับ</label>
            <input id="ss_note" value="${escapeHtml(store?.note || "")}" placeholder="เช่น จอดรถหลังร้าน" class="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm">
          </div>
        </div>

        <div class="flex flex-wrap gap-5 mb-4 text-sm">
          <label class="flex items-center gap-2">
            <input type="checkbox" id="ss_active" ${store?.is_active !== false ? "checked" : ""}> เปิดใช้งานร้านนี้
          </label>
          <label class="flex items-center gap-2">
            <input type="checkbox" id="ss_24h" ${store?.is_24h ? "checked" : ""}> เปิด 24 ชั่วโมง
          </label>
          <label class="flex items-center gap-2">
            <input type="checkbox" id="ss_receipt" ${store?.issues_receipt !== false ? "checked" : ""}> ร้านออกใบเสร็จ
          </label>
        </div>

        <div class="bg-orange-50 border border-orange-100 rounded-xl p-3 mb-4 text-xs text-orange-700">
          <b>ร้านออกใบเสร็จ</b> = คนขับถ่ายใบเสร็จ ระบบอ่านยอดให้อัตโนมัติ ·
          <b>ไม่ออกใบเสร็จ</b> = คนขับถ่ายรูปสินค้าแล้วลูกค้าต้องกดยืนยันก่อนถึงจะส่งของต่อได้
        </div>

        <div class="border-t border-gray-100 pt-4">
          <div class="flex items-center justify-between mb-2">
            <div class="font-semibold text-gray-700 text-sm">เวลาเปิด-ปิด (เวลาไทย)</div>
            <button onclick="copyMondayHoursToAll()" class="text-xs px-3 py-1.5 rounded-lg bg-gray-100 text-gray-600 hover:bg-gray-200">คัดลอกวันจันทร์ไปทุกวัน</button>
          </div>
          <div class="text-xs text-gray-400 mb-2">
            เว้นว่างทั้งคู่ = ปิดทั้งวัน · เวลาปิดน้อยกว่าเวลาเปิด = ข้ามเที่ยงคืน (เช่น 18:00 ถึง 02:00)
          </div>
          <div class="overflow-x-auto">
            <table><tbody>${dayRows}</tbody></table>
          </div>
        </div>

        <div class="flex gap-3 mt-6">
          <button onclick="closeShopStoreDialog()" class="flex-1 px-4 py-2.5 border border-gray-200 text-gray-600 rounded-xl text-sm font-semibold hover:bg-gray-50">ยกเลิก</button>
          <button onclick="saveShopStore()" class="flex-1 px-4 py-2.5 text-white rounded-xl text-sm font-semibold shadow-md shadow-violet-200" style="background:linear-gradient(135deg,#8b5cf6,#6366f1);">บันทึก</button>
        </div>
      </div>
    </div>`;
}

export function closeShopStoreDialog() {
  const host = document.getElementById("shopStoreDialog");
  if (host) host.innerHTML = "";
}

export function copyMondayHoursToAll() {
  const o = document.getElementById("h_mon_o")?.value || "";
  const c = document.getElementById("h_mon_c")?.value || "";
  const o2 = document.getElementById("h2_mon_o")?.value || "";
  const c2 = document.getElementById("h2_mon_c")?.value || "";
  for (const [key] of DAYS) {
    if (key === "mon") continue;
    const eo = document.getElementById(`h_${key}_o`);
    const ec = document.getElementById(`h_${key}_c`);
    const eo2 = document.getElementById(`h2_${key}_o`);
    const ec2 = document.getElementById(`h2_${key}_c`);
    if (eo) eo.value = o;
    if (ec) ec.value = c;
    if (eo2) eo2.value = o2;
    if (ec2) ec2.value = c2;
  }
}

function collectHours() {
  const hours = {};
  for (const [key] of DAYS) {
    const ranges = [];
    const o = document.getElementById(`h_${key}_o`)?.value;
    const c = document.getElementById(`h_${key}_c`)?.value;
    if (o && c) ranges.push({ open: o, close: c });
    const o2 = document.getElementById(`h2_${key}_o`)?.value;
    const c2 = document.getElementById(`h2_${key}_c`)?.value;
    if (o2 && c2) ranges.push({ open: o2, close: c2 });
    hours[key] = ranges;
  }
  return hours;
}

export async function saveShopStore() {
  const { supabase, showToast, refreshCurrentPage } = _deps();

  const id = document.getElementById("ss_id")?.value || null;
  const name = (document.getElementById("ss_name")?.value || "").trim();
  const lat = Number(document.getElementById("ss_lat")?.value);
  const lng = Number(document.getElementById("ss_lng")?.value);

  if (!name) return showToast?.("กรุณากรอกชื่อร้าน", "error");
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return showToast?.("พิกัดไม่ถูกต้อง", "error");
  }
  if (lat === 0 && lng === 0) {
    return showToast?.("พิกัด (0,0) ใช้ไม่ได้ กรุณาระบุตำแหน่งจริง", "error");
  }
  if (lat < -90 || lat > 90 || lng < -180 || lng > 180) {
    return showToast?.("พิกัดอยู่นอกช่วงที่เป็นไปได้", "error");
  }

  const is24h = !!document.getElementById("ss_24h")?.checked;
  const hours = collectHours();
  const hasAnyHours = DAYS.some(([k]) => hours[k].length > 0);

  if (!is24h && !hasAnyHours) {
    return showToast?.("ยังไม่ได้ตั้งเวลาเปิด-ปิด ร้านจะถูกนับว่าปิดตลอด", "error");
  }

  const radiusRaw = document.getElementById("ss_radius")?.value;
  const payload = {
    name,
    category: document.getElementById("ss_category")?.value || "grocery",
    address: (document.getElementById("ss_address")?.value || "").trim() || null,
    lat,
    lng,
    opening_hours: hours,
    is_24h: is24h,
    issues_receipt: !!document.getElementById("ss_receipt")?.checked,
    is_active: !!document.getElementById("ss_active")?.checked,
    service_radius_km: radiusRaw ? Number(radiusRaw) : null,
    note: (document.getElementById("ss_note")?.value || "").trim() || null,
  };

  let error;
  if (id) {
    ({ error } = await supabase.from("shop_stores").update(payload).eq("id", id));
  } else {
    // audit trail: บันทึกว่าแอดมินคนไหนเป็นคนเพิ่มร้าน
    const { data: auth } = (await supabase.auth?.getUser?.()) || { data: null };
    const createdBy = auth?.user?.id || null;
    ({ error } = await supabase
      .from("shop_stores")
      .insert(createdBy ? { ...payload, created_by: createdBy } : payload));
  }

  if (error) return showToast?.(`บันทึกไม่สำเร็จ: ${error.message}`, "error");

  closeShopStoreDialog();
  showToast?.(id ? "แก้ไขร้านแล้ว" : "เพิ่มร้านแล้ว", "success");
  await refreshCurrentPage?.();
}

// ปิดร้านชั่วคราว (เช่น ร้านปิดกะทันหัน) — กดซ้ำเพื่อเปิดกลับ
export async function toggleShopStoreClosed(id) {
  const { supabase, showToast, refreshCurrentPage } = _deps();
  const store = (globalThis._allShopStores || []).find((s) => s.id === id);
  if (!store) return;

  const closed = store.manual_closed_until && new Date(store.manual_closed_until) > new Date();

  let until = null;
  if (!closed) {
    const raw = globalThis.prompt?.("ปิดร้านชั่วคราวกี่ชั่วโมง?", "3");
    if (raw === null) return;
    const hoursNum = Number(raw);
    if (!Number.isFinite(hoursNum) || hoursNum <= 0) {
      return showToast?.("จำนวนชั่วโมงไม่ถูกต้อง", "error");
    }
    until = new Date(Date.now() + hoursNum * 3600 * 1000).toISOString();
  }

  const { error } = await supabase
    .from("shop_stores")
    .update({ manual_closed_until: until })
    .eq("id", id);

  if (error) return showToast?.(`ทำรายการไม่สำเร็จ: ${error.message}`, "error");

  showToast?.(closed ? "เปิดร้านกลับแล้ว" : "ปิดร้านชั่วคราวแล้ว", "success");
  await refreshCurrentPage?.();
}
