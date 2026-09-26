import { mountPageTabs } from "./pageTabs.js";

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
let _storePickerMap = null;
let _storePickerMarker = null;
const GOOGLE_LOOKUP_ENABLED = true;
let _googleMapCenter = [13.7563, 100.5018];
let _googleMapZoom = 13;
let _renderedGoogleMapCenter = null;
let _renderedGoogleMapZoom = null;
let _lookupGeneration = 0;
let _mapGeneration = 0;

export async function callStoreLookup(payload) {
  const { supabase } = _deps();
  const { data, error } = await supabase.functions.invoke("shop-store-lookup", { body: payload });
  if (error) {
    let serverError = data?.error;
    if (!serverError && typeof error.context?.json === "function") {
      try {
        const responseBody = await error.context.json();
        if (typeof responseBody?.error === "string") serverError = responseBody.error;
      } catch { /* Keep the original transport error when the body is not JSON. */ }
    }
    throw new Error(serverError || error.message || "ดึงข้อมูลร้านไม่สำเร็จ");
  }
  if (data?.error) throw new Error(data.error);
  return data;
}

export function applyStoreLookupResult(result) {
  if (!result || !validStoreCoordinates(result.lat, result.lng)) throw new Error("ข้อมูลพิกัดที่ได้รับไม่ถูกต้อง");
  if (result.name) document.getElementById("ss_name").value = result.name;
  else if (result.source === "address") document.getElementById("ss_name").value = "";
  if (result.address) document.getElementById("ss_address").value = result.address;
  document.getElementById("ss_lat").value = result.lat;
  document.getElementById("ss_lng").value = result.lng;
  if (result.is24h === true) {
    document.getElementById("ss_24h").checked = true;
    for (const [day] of DAYS) {
      for (const suffix of ["", "2"]) {
        document.getElementById(`h${suffix}_${day}_o`).value = "";
        document.getElementById(`h${suffix}_${day}_c`).value = "";
      }
    }
  } else if (result.openingHours && typeof result.openingHours === "object") {
    document.getElementById("ss_24h").checked = false;
    for (const [day] of DAYS) {
      const ranges = Array.isArray(result.openingHours[day]) ? result.openingHours[day] : [];
      for (const [index, suffix] of ["", "2"].entries()) {
        document.getElementById(`h${suffix}_${day}_o`).value = ranges[index]?.open || "";
        document.getElementById(`h${suffix}_${day}_c`).value = ranges[index]?.close || "";
      }
    }
  }
  _googleMapCenter = [result.lat, result.lng];
  document.getElementById("ss_lookup_status").textContent = result.source === "address"
    ? "พบที่อยู่จากหมุดแล้ว กรุณากรอกชื่อร้านและตรวจสอบข้อมูลก่อนบันทึก"
    : "เติมข้อมูลร้านแล้ว กรุณาตรวจสอบชื่อ ที่อยู่ และตำแหน่งก่อนบันทึก";
  renderGoogleStoreMap();
}

export async function renderGoogleStoreMap() {
  const image = document.getElementById("ss_google_map");
  if (!image) return;
  const generation = ++_mapGeneration;
  const requestedCenter = [..._googleMapCenter];
  const requestedZoom = _googleMapZoom;
  image.style.pointerEvents = "none";
  image.style.opacity = "0.6";
  try {
    const hasMarker = validStoreCoordinates(Number(document.getElementById("ss_lat")?.value), Number(document.getElementById("ss_lng")?.value));
    const data = await callStoreLookup({ mode: "map", lat: requestedCenter[0], lng: requestedCenter[1], zoom: requestedZoom, marker: hasMarker });
    if (generation === _mapGeneration && image.isConnected) {
      image.onload = () => {
        if (generation !== _mapGeneration || !image.isConnected) return;
        _renderedGoogleMapCenter = requestedCenter;
        _renderedGoogleMapZoom = requestedZoom;
        image.style.pointerEvents = "auto";
        image.style.opacity = "1";
      };
      image.src = data.image;
    }
  } catch (error) {
    if (generation === _mapGeneration && image.isConnected) document.getElementById("ss_lookup_status").textContent = error.message;
  }
}

export async function lookupShopStoreFromLink() {
  const input = document.getElementById("ss_maps_url");
  const status = document.getElementById("ss_lookup_status");
  const button = document.getElementById("ss_lookup_button");
  if (!input?.value.trim()) return _deps().showToast?.("กรุณาวางลิงก์ Google Maps", "error");
  const generation = ++_lookupGeneration;
  button.disabled = true;
  status.textContent = "กำลังดึงข้อมูลร้าน…";
  try {
    const data = await callStoreLookup({ mode: "url", url: input.value.trim() });
    if (generation === _lookupGeneration && input.isConnected) {
      if (data.result?.source === "unverified_search" && !globalThis.confirm(`พบ ${data.result.name}\n${data.result.address}\n\nใช่ร้านที่ต้องการหรือไม่?`)) {
        status.textContent = "ยังไม่ได้เติมข้อมูล กรุณาใช้ลิงก์ที่ระบุร้านหรือปักหมุด";
        return;
      }
      applyStoreLookupResult(data.result);
    }
  } catch (error) {
    if (generation === _lookupGeneration && input.isConnected) status.textContent = error.message;
  } finally {
    if (generation === _lookupGeneration && input.isConnected) button.disabled = false;
  }
}

function pointAtGoogleMapClick(event) {
  if (!_renderedGoogleMapCenter || _renderedGoogleMapZoom == null) return null;
  const rect = event.currentTarget.getBoundingClientRect();
  const x = (event.clientX - rect.left) / rect.width - 0.5;
  const y = (event.clientY - rect.top) / rect.height - 0.5;
  const worldSize = 256 * 2 ** _renderedGoogleMapZoom;
  const centerLat = _renderedGoogleMapCenter[0] * Math.PI / 180;
  const centerMercatorY = (1 - Math.log(Math.tan(centerLat) + 1 / Math.cos(centerLat)) / Math.PI) / 2;
  const lng = _renderedGoogleMapCenter[1] + x * 640 / worldSize * 360;
  const mercatorY = centerMercatorY + y * 320 / worldSize;
  const lat = Math.atan(Math.sinh(Math.PI * (1 - 2 * mercatorY))) * 180 / Math.PI;
  return { lat, lng };
}

export async function pinGoogleStoreMap(event) {
  const status = document.getElementById("ss_lookup_status");
  const point = pointAtGoogleMapClick(event);
  if (!point || !validStoreCoordinates(point.lat, point.lng)) return;
  const generation = ++_lookupGeneration;
  const lookupButton = document.getElementById("ss_lookup_button");
  if (lookupButton) lookupButton.disabled = false;
  document.getElementById("ss_lat").value = point.lat.toFixed(6);
  document.getElementById("ss_lng").value = point.lng.toFixed(6);
  _googleMapCenter = [point.lat, point.lng];
  status.textContent = "กำลังค้นหาข้อมูลใกล้หมุด…";
  renderGoogleStoreMap();
  try {
    const data = await callStoreLookup({ mode: "point", lat: point.lat, lng: point.lng });
    if (generation === _lookupGeneration && status.isConnected) {
      if (data.result?.source === "nearby_candidate" && !globalThis.confirm(`พบ ${data.result.name} ห่างจากหมุดประมาณ ${data.result.distanceMeters} เมตร\n${data.result.address}\n\nใช่ร้านที่ต้องการหรือไม่?`)) {
        applyStoreLookupResult({ source: "address", name: "", address: data.result.fallbackAddress || "", lat: point.lat, lng: point.lng });
      } else {
        applyStoreLookupResult(data.result);
      }
    }
  } catch (error) {
    if (generation === _lookupGeneration && status.isConnected) status.textContent = `${error.message} — พิกัดหมุดยังอยู่ในฟอร์ม`;
  }
}

export function zoomGoogleStoreMap(change) {
  _googleMapZoom = Math.max(3, Math.min(19, _googleMapZoom + change));
  renderGoogleStoreMap();
}

export function invalidateStoreLookup() {
  _lookupGeneration++;
  const button = document.getElementById("ss_lookup_button");
  if (button) button.disabled = false;
}

function validStoreCoordinates(lat, lng) {
  return Number.isFinite(lat) && Number.isFinite(lng) && lat >= -90 && lat <= 90 && lng >= -180 && lng <= 180 && !(lat === 0 && lng === 0);
}

function setStorePickerCoordinates(lat, lng) {
  if (!validStoreCoordinates(lat, lng)) return;
  document.getElementById("ss_lat").value = lat.toFixed(6);
  document.getElementById("ss_lng").value = lng.toFixed(6);
  if (_storePickerMap) {
    if (_storePickerMarker) _storePickerMarker.setLatLng([lat, lng]);
    else _storePickerMarker = L.marker([lat, lng], { draggable: true }).addTo(_storePickerMap)
      .on("dragend", (event) => {
        const point = event.target.getLatLng();
        setStorePickerCoordinates(point.lat, point.lng);
      });
    _storePickerMap.panTo([lat, lng]);
  }
}

function initStorePickerMap() {
  if (GOOGLE_LOOKUP_ENABLED) {
    const lat = Number(document.getElementById("ss_lat")?.value);
    const lng = Number(document.getElementById("ss_lng")?.value);
    _googleMapCenter = validStoreCoordinates(lat, lng) ? [lat, lng] : [13.7563, 100.5018];
    _googleMapZoom = validStoreCoordinates(lat, lng) ? 16 : 13;
    renderGoogleStoreMap();
    return;
  }
  const mapElement = document.getElementById("ss_map");
  if (!mapElement || !globalThis.L) return;
  const lat = Number(document.getElementById("ss_lat")?.value);
  const lng = Number(document.getElementById("ss_lng")?.value);
  const hasPoint = validStoreCoordinates(lat, lng);
  _storePickerMap = L.map(mapElement).setView(hasPoint ? [lat, lng] : [13.7563, 100.5018], hasPoint ? 16 : 11);
  L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
    maxZoom: 19,
    attribution: '&copy; <a href="https://www.openstreetmap.org/copyright">OpenStreetMap</a>',
  }).addTo(_storePickerMap);
  _storePickerMap.on("click", (event) => setStorePickerCoordinates(event.latlng.lat, event.latlng.lng));
  if (hasPoint) {
    _storePickerMarker = L.marker([lat, lng], { draggable: true }).addTo(_storePickerMap)
      .on("dragend", (event) => {
        const point = event.target.getLatLng();
        setStorePickerCoordinates(point.lat, point.lng);
      });
  }
  setTimeout(() => _storePickerMap?.invalidateSize(), 0);
}

export function syncStorePickerFromInputs() {
  const latRaw = document.getElementById("ss_lat")?.value;
  const lngRaw = document.getElementById("ss_lng")?.value;
  if (!latRaw || !lngRaw) return;
  const lat = Number(latRaw);
  const lng = Number(lngRaw);
  if (GOOGLE_LOOKUP_ENABLED && validStoreCoordinates(lat, lng)) {
    _googleMapCenter = [lat, lng];
    renderGoogleStoreMap();
    return;
  }
  if (validStoreCoordinates(lat, lng)) setStorePickerCoordinates(lat, lng);
}

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
  const requests = await loadPendingStoreRequests(supabase);
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
          ? `<div data-tab="list" class="glass-card p-4 border-l-4 border-amber-400 bg-amber-50/50">
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

      <div data-tab="requests">${renderStoreRequestsCard(requests, escapeHtml) || '<div class="glass-card p-8 text-center text-sm text-gray-400">ไม่มีคำขอเพิ่มร้านที่รอตรวจ</div>'}</div>

      <div data-tab="overview" class="grid grid-cols-1 md:grid-cols-3 gap-4">
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

      <div data-tab="list" class="glass-card p-4 flex flex-wrap gap-3 items-center justify-between">
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

      <div data-tab="*" id="shopStoreDialog"></div>
    </div>`;

  mountPageTabs(el.querySelector('.fade-in'), {
    key: 'adminShopStoresTab',
    tabs: [
      { id: 'list', label: 'รายการร้าน', icon: 'storefront' },
      { id: 'requests', label: 'คำขอเพิ่มร้าน', icon: 'add_business', badge: requests.length },
      { id: 'overview', label: 'ภาพรวม', icon: 'bar_chart' },
    ],
  });

  globalThis._allShopStores = list;
  globalThis.editShopStore = editShopStore;
  globalThis.saveShopStore = saveShopStore;
  globalThis.closeShopStoreDialog = closeShopStoreDialog;
  globalThis.toggleShopStoreClosed = toggleShopStoreClosed;
  globalThis.copyMondayHoursToAll = copyMondayHoursToAll;
  globalThis.syncStorePickerFromInputs = syncStorePickerFromInputs;
  globalThis.lookupShopStoreFromLink = lookupShopStoreFromLink;
  globalThis.pinGoogleStoreMap = pinGoogleStoreMap;
  globalThis.zoomGoogleStoreMap = zoomGoogleStoreMap;
  globalThis.renderGoogleStoreMap = renderGoogleStoreMap;
  globalThis.invalidateStoreLookup = invalidateStoreLookup;
  globalThis.reviewShopStoreRequest = reviewShopStoreRequest;
}

// ── คำขอเพิ่มร้านจากลูกค้า ───────────────────────────────────
// ลูกค้าส่งได้แค่ "คำขอ" — ร้านจริงสร้างเมื่อแอดมินกดอนุมัติเท่านั้น
// และร้านที่ได้จะปิดใช้งานไว้ก่อน เพราะคำขอไม่มีเวลาเปิด-ปิด

async function loadPendingStoreRequests(supabase) {
  const { data, error } = await supabase
    .from("shop_store_requests")
    .select("*, requester:profiles!shop_store_requests_requester_id_fkey(full_name)")
    .eq("status", "pending")
    .order("created_at", { ascending: true })
    .limit(50);
  if (error) {
    // ยังไม่ได้ migrate ตาราง -> ไม่ให้ทั้งหน้าร้านพังตาม
    console.warn("shop_store_requests:", error.message);
    return [];
  }
  return data || [];
}

function safeHttpUrl(raw) {
  try {
    const u = new URL(String(raw || ""));
    return u.protocol === "https:" || u.protocol === "http:" ? u.href : null;
  } catch {
    return null;
  }
}

export function renderStoreRequestsCard(requests, escapeHtml) {
  if (!requests || requests.length === 0) return "";
  const { fmtDate } = _deps();

  const items = requests
    .map((r) => {
      const lat = Number(r.lat);
      const lng = Number(r.lng);
      const pin = `https://www.google.com/maps?q=${lat},${lng}`;
      const link = safeHttpUrl(r.maps_url);
      const who = r.requester?.full_name || "ลูกค้า";
      return `
      <div class="border border-gray-100 rounded-xl p-3 flex flex-wrap gap-3 items-start justify-between">
        <div class="min-w-0 flex-1">
          <div class="flex items-center gap-2">
            <span class="material-icons-round text-violet-500 text-lg">${categoryIcon(r.category)}</span>
            <span class="font-semibold text-gray-800">${escapeHtml(r.name)}</span>
            <span class="text-xs text-gray-400">${categoryLabel(r.category)}${r.is_24h ? " · เปิด 24 ชม." : ""}</span>
          </div>
          <div class="text-xs text-gray-500 mt-1">${escapeHtml(r.address || "-")}</div>
          <div class="text-xs mt-1 flex flex-wrap gap-3">
            <a href="${pin}" target="_blank" rel="noopener noreferrer" class="text-blue-600 hover:underline">${lat.toFixed(5)}, ${lng.toFixed(5)}</a>
            ${link ? `<a href="${escapeHtml(link)}" target="_blank" rel="noopener noreferrer" class="text-blue-600 hover:underline">ลิงก์ Google Maps จากลูกค้า</a>` : ""}
          </div>
          ${r.note ? `<div class="text-xs text-gray-600 mt-1">หมายเหตุ: ${escapeHtml(r.note)}</div>` : ""}
          <div class="text-[11px] text-gray-400 mt-1">โดย ${escapeHtml(who)} · ${escapeHtml(fmtDate ? fmtDate(r.created_at) : r.created_at)}</div>
        </div>
        <div class="flex gap-1 shrink-0">
          <button onclick="reviewShopStoreRequest('${escapeHtml(r.id)}', true)" class="px-3 py-1.5 rounded-lg text-xs font-semibold bg-emerald-50 text-emerald-700 border border-emerald-200 hover:bg-emerald-100">อนุมัติ</button>
          <button onclick="reviewShopStoreRequest('${escapeHtml(r.id)}', false)" class="px-3 py-1.5 rounded-lg text-xs font-semibold bg-red-50 text-red-600 border border-red-200 hover:bg-red-100">ไม่อนุมัติ</button>
        </div>
      </div>`;
    })
    .join("");

  return `
    <div class="glass-card p-4 border-l-4 border-violet-400">
      <div class="flex items-center gap-2 mb-3">
        <span class="material-icons-round text-violet-500">add_location_alt</span>
        <div class="font-semibold text-gray-800">คำขอเพิ่มร้านจากลูกค้า (${requests.length})</div>
      </div>
      <div class="text-xs text-gray-500 mb-3">
        อนุมัติแล้วระบบจะสร้างร้านแบบ <b>ปิดใช้งาน</b> ให้ — ตรวจพิกัด ตั้งเวลาเปิด-ปิด แล้วค่อยเปิดใช้งาน
      </div>
      <div class="space-y-2">${items}</div>
    </div>`;
}

const REVIEW_ERRORS = {
  not_authorized: "ไม่มีสิทธิ์ตรวจคำขอ",
  request_not_found: "ไม่พบคำขอนี้",
  already_reviewed: "คำขอนี้ถูกตรวจไปแล้ว",
  store_exists: "มีร้านชื่อนี้ที่พิกัดเดียวกันอยู่แล้ว",
};

let _reviewing = false;

export async function reviewShopStoreRequest(id, approve) {
  if (_reviewing) return;
  const { supabase, showToast, refreshCurrentPage } = _deps();

  let note = null;
  if (!approve) {
    note = globalThis.prompt?.("เหตุผลที่ไม่อนุมัติ (ลูกค้าจะเห็นข้อความนี้)", "");
    if (note === null || note === undefined) return;
  } else if (globalThis.confirm && !globalThis.confirm("อนุมัติและสร้างร้าน (ปิดใช้งานไว้ก่อน)?")) {
    return;
  }

  _reviewing = true;
  try {
    const { data, error } = await supabase.rpc("shop_review_store_request", {
      p_request_id: id,
      p_approve: approve,
      p_admin_note: note,
    });
    if (error) return showToast?.(`ทำรายการไม่สำเร็จ: ${error.message}`, "error");
    if (!data?.success) {
      return showToast?.(REVIEW_ERRORS[data?.error] || `ทำรายการไม่สำเร็จ (${data?.error || "unknown"})`, "error");
    }

    showToast?.(approve ? "อนุมัติแล้ว — ตั้งเวลาเปิด-ปิดแล้วเปิดใช้งานร้าน" : "ปฏิเสธคำขอแล้ว", "success");
    await refreshCurrentPage?.();
    // เปิดฟอร์มร้านที่เพิ่งสร้างให้เลย จะได้ตั้งเวลาต่อทันที
    if (approve && data.store_id) editShopStore(data.store_id);
  } finally {
    _reviewing = false;
  }
}

// ── ฟอร์มเพิ่ม/แก้ไข ────────────────────────────────────────
export function editShopStore(id) {
  _lookupGeneration++;
  _mapGeneration++;
  _renderedGoogleMapCenter = null;
  _renderedGoogleMapZoom = null;
  _storePickerMap?.remove();
  _storePickerMap = null;
  _storePickerMarker = null;
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
            <input id="ss_name" value="${escapeHtml(store?.name || "")}" oninput="invalidateStoreLookup()" class="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1">หมวด *</label>
            <select id="ss_category" class="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm">
              ${CATEGORIES.map(([k, l]) => `<option value="${k}" ${store?.category === k ? "selected" : ""}>${l}</option>`).join("")}
            </select>
          </div>
          <div class="md:col-span-2">
            <label class="block text-xs font-semibold text-gray-500 mb-1">ที่อยู่ (ให้คนขับนำทาง)</label>
            <input id="ss_address" value="${escapeHtml(store?.address || "")}" oninput="invalidateStoreLookup()" class="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm">
          </div>
          <div class="md:col-span-2">
            <label class="block text-xs font-semibold text-gray-500 mb-1">ลิงก์ Google Maps</label>
            <div class="flex gap-2">
              <input id="ss_maps_url" type="url" ${GOOGLE_LOOKUP_ENABLED ? "" : "disabled"} oninput="invalidateStoreLookup()" onpaste="setTimeout(() => lookupShopStoreFromLink(), 0)" onkeydown="if(event.key==='Enter'){event.preventDefault();lookupShopStoreFromLink()}" placeholder="วางลิงก์ Google Maps" class="flex-1 min-w-0 border border-gray-200 rounded-xl px-3 py-2 text-sm ${GOOGLE_LOOKUP_ENABLED ? "" : "bg-gray-50 text-gray-400"}">
              <button id="ss_lookup_button" type="button" onclick="lookupShopStoreFromLink()" ${GOOGLE_LOOKUP_ENABLED ? "" : "disabled"} class="px-3 py-2 rounded-xl text-sm ${GOOGLE_LOOKUP_ENABLED ? "bg-indigo-600 text-white" : "bg-gray-100 text-gray-400 cursor-not-allowed"}">ดึงข้อมูล</button>
            </div>
            <p id="ss_lookup_status" class="text-xs text-amber-700 mt-1">${GOOGLE_LOOKUP_ENABLED ? "วางลิงก์แล้วกดดึงข้อมูล หรือคลิกแผนที่เพื่อเลือกตำแหน่ง" : "ฟีเจอร์ดึงชื่อ ที่อยู่ และพิกัดจากลิงก์ยังไม่เปิดใช้งานระหว่างรอตั้งค่า API บน server"}</p>
          </div>
          <div class="md:col-span-2">
            <label class="block text-xs font-semibold text-gray-500 mb-1">เลือกตำแหน่งร้านจากหมุด</label>
            ${GOOGLE_LOOKUP_ENABLED ? `<div class="relative"><img id="ss_google_map" onclick="pinGoogleStoreMap(event)" alt="แผนที่ Google สำหรับเลือกตำแหน่งร้าน" class="w-full aspect-[2/1] border border-gray-200 rounded-xl cursor-crosshair object-fill"><div class="absolute top-2 right-2 flex flex-col gap-1"><button type="button" onclick="zoomGoogleStoreMap(1)" class="bg-white rounded shadow px-2">+</button><button type="button" onclick="zoomGoogleStoreMap(-1)" class="bg-white rounded shadow px-2">−</button><button type="button" onclick="renderGoogleStoreMap()" aria-label="โหลดแผนที่อีกครั้ง" class="bg-white rounded shadow px-2">↻</button></div></div>` : `<div id="ss_map" class="h-64 rounded-xl border border-gray-200" aria-label="แผนที่เลือกตำแหน่งร้าน"></div>`}
            <p class="text-xs text-gray-500 mt-1">${GOOGLE_LOOKUP_ENABLED ? "คลิกแผนที่เพื่อปักหมุด ระบบจะค้นหาข้อมูลร้านใกล้หมุดให้" : "คลิกแผนที่เพื่อวางหมุด หรือเลื่อนหมุดเพื่อปรับตำแหน่ง"}</p>
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1">Latitude *</label>
            <input id="ss_lat" type="number" step="any" value="${store?.lat ?? ""}" oninput="invalidateStoreLookup()" onchange="syncStorePickerFromInputs()" class="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm">
          </div>
          <div>
            <label class="block text-xs font-semibold text-gray-500 mb-1">Longitude *</label>
            <input id="ss_lng" type="number" step="any" value="${store?.lng ?? ""}" oninput="invalidateStoreLookup()" onchange="syncStorePickerFromInputs()" class="w-full border border-gray-200 rounded-xl px-3 py-2 text-sm">
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
          <button id="ss_save_button" onclick="saveShopStore()" class="flex-1 px-4 py-2.5 text-white rounded-xl text-sm font-semibold shadow-md shadow-violet-200 disabled:opacity-60 disabled:cursor-not-allowed" style="background:linear-gradient(135deg,#8b5cf6,#6366f1);">บันทึก</button>
        </div>
      </div>
    </div>`;
  initStorePickerMap();
}

export function closeShopStoreDialog() {
  _lookupGeneration++;
  _mapGeneration++;
  _renderedGoogleMapCenter = null;
  _renderedGoogleMapZoom = null;
  _storePickerMap?.remove();
  _storePickerMap = null;
  _storePickerMarker = null;
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

// กันกดบันทึกซ้ำระหว่างที่ request แรกยังไม่เสร็จ
// (เคยทำให้เกิดร้านซ้ำบน production — คลิกเดียวแต่ INSERT 2 แถว)
let _savingStore = false;

export async function saveShopStore() {
  const { supabase, showToast, refreshCurrentPage } = _deps();

  if (_savingStore) return;

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

  const saveButton = document.getElementById("ss_save_button");
  _savingStore = true;
  if (saveButton) {
    saveButton.disabled = true;
    saveButton.textContent = "กำลังบันทึก…";
  }

  let error;
  try {
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
  } finally {
    _savingStore = false;
    if (saveButton?.isConnected) {
      saveButton.disabled = false;
      saveButton.textContent = "บันทึก";
    }
  }

  if (error) {
    // 23505 = ชนกับ unique index shop_stores_name_coord_unique
    const duplicate =
      error.code === "23505" || /duplicate key|unique constraint/i.test(error.message || "");
    return showToast?.(
      duplicate
        ? "มีร้านชื่อนี้ที่พิกัดเดียวกันอยู่แล้ว"
        : `บันทึกไม่สำเร็จ: ${error.message}`,
      "error",
    );
  }

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
