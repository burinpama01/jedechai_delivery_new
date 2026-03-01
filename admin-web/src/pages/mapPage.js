let _ctx = null;

let _mapInstance = null;
let _mapRefreshTimer = null;
let _mapRealtimeChannel = null;
let _mapSidebarTab = 'drivers';
let _mapRefreshDebounce = null;

function _deps() {
  const supabase = _ctx?.supabase || globalThis.supabase;
  const fmt = _ctx?.fmt || globalThis.fmt;
  const statCard = _ctx?.statCard || globalThis.statCard;
  const escapeHtml = _ctx?.escapeHtml || globalThis.escapeHtml;

  return { supabase, fmt, statCard, escapeHtml };
}

function debugLog(...args) {
  try {
    if (window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1') console.log(...args);
  } catch (_) {}
}

async function _getInitialMapCenter() {
  const { supabase } = _deps();
  const fallback = { center: [13.7563, 100.5018], zoom: 12 }; // Bangkok

  const resolveFallbackCenter = async () => {
    try {
      const { data: latestDriverLoc } = await supabase
        .from('driver_locations')
        .select('location_lat, location_lng')
        .not('location_lat', 'is', null)
        .not('location_lng', 'is', null)
        .order('updated_at', { ascending: false })
        .limit(1)
        .maybeSingle();

      if (latestDriverLoc?.location_lat && latestDriverLoc?.location_lng) {
        return { center: [latestDriverLoc.location_lat, latestDriverLoc.location_lng], zoom: 13 };
      }
    } catch (_) {}

    return fallback;
  };

  if (!navigator.geolocation) return resolveFallbackCenter();

  return new Promise((resolve) => {
    navigator.geolocation.getCurrentPosition(
      (pos) => {
        resolve({
          center: [pos.coords.latitude, pos.coords.longitude],
          zoom: 14,
        });
      },
      async () => resolve(await resolveFallbackCenter()),
      { enableHighAccuracy: true, timeout: 8000, maximumAge: 120000 },
    );
  });
}

function _debouncedMapRefresh() {
  if (_mapRefreshDebounce) clearTimeout(_mapRefreshDebounce);
  _mapRefreshDebounce = setTimeout(() => { refreshMapData(); }, 800);
}

async function _setupMapRealtime() {
  const { supabase } = _deps();

  if (_mapRealtimeChannel) {
    try { await supabase.removeChannel(_mapRealtimeChannel); } catch (_) {}
    _mapRealtimeChannel = null;
  }

  _mapRealtimeChannel = supabase.channel('admin-map-realtime')
    .on('postgres_changes', { event: '*', schema: 'public', table: 'bookings' }, (payload) => {
      debugLog('📦 Booking change:', payload.eventType, payload.new?.id?.substring(0, 8));
      _debouncedMapRefresh();
    })
    .on('postgres_changes', { event: '*', schema: 'public', table: 'driver_locations' }, (payload) => {
      debugLog('📍 Driver location change:', payload.new?.driver_id?.substring(0, 8));
      _debouncedMapRefresh();
    })
    .on('postgres_changes', { event: '*', schema: 'public', table: 'profiles' }, (payload) => {
      debugLog('👤 Profile change:', payload.new?.id?.substring(0, 8), 'role:', payload.new?.role, 'online:', payload.new?.is_online);
      _debouncedMapRefresh();
    })
    .subscribe((status) => {
      const dot = document.getElementById('mapRealtimeStatus');
      if (dot) {
        dot.className = status === 'SUBSCRIBED'
          ? 'w-2 h-2 rounded-full bg-green-500 animate-pulse'
          : 'w-2 h-2 rounded-full bg-red-500';
        dot.title = status === 'SUBSCRIBED' ? 'Realtime connected' : 'Realtime: ' + status;
      }
    });
}

function _haversineKm(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat / 2) ** 2 + Math.cos(lat1 * Math.PI / 180) * Math.cos(lat2 * Math.PI / 180) * Math.sin(dLng / 2) ** 2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

async function _fetchOSRMRoute(lat1, lng1, lat2, lng2) {
  globalThis._osrmRouteCache = globalThis._osrmRouteCache || {};
  const cacheKey = `${lat1.toFixed(5)},${lng1.toFixed(5)}_${lat2.toFixed(5)},${lng2.toFixed(5)}`;
  if (globalThis._osrmRouteCache[cacheKey]) return globalThis._osrmRouteCache[cacheKey];

  try {
    const url = `https://router.project-osrm.org/route/v1/driving/${lng1},${lat1};${lng2},${lat2}?overview=full&geometries=geojson`;
    const res = await fetch(url);
    if (!res.ok) return null;
    const data = await res.json();
    if (data.code !== 'Ok' || !data.routes?.length) return null;

    const route = data.routes[0];
    const coords = route.geometry.coordinates.map(c => [c[1], c[0]]);
    const distKm = (route.distance / 1000).toFixed(1);
    const result = { coords, distKm };
    globalThis._osrmRouteCache[cacheKey] = result;

    const keys = Object.keys(globalThis._osrmRouteCache);
    if (keys.length > 50) delete globalThis._osrmRouteCache[keys[0]];

    return result;
  } catch (e) {
    console.error('OSRM route error:', e);
    return null;
  }
}

async function _drawRouteLine(fromLat, fromLng, toLat, toLng, color, weight, opacity, dashArray, tooltipPrefix) {
  if (!_mapInstance) return;

  const route = await _fetchOSRMRoute(fromLat, fromLng, toLat, toLng);
  let line;
  if (route && route.coords.length > 1) {
    line = L.polyline(route.coords, { color, weight, opacity, dashArray: dashArray || null }).addTo(_mapInstance);
    if (tooltipPrefix) line.bindTooltip(`${tooltipPrefix} ${route.distKm} กม.`, { permanent: false, className: 'route-tooltip' });
  } else {
    const dist = _haversineKm(fromLat, fromLng, toLat, toLng).toFixed(1);
    line = L.polyline([[fromLat, fromLng], [toLat, toLng]], { color, weight, opacity, dashArray: dashArray || null }).addTo(_mapInstance);
    if (tooltipPrefix) line.bindTooltip(`${tooltipPrefix} ~${dist} กม.`, { permanent: false, className: 'route-tooltip' });
  }

  globalThis._mapRouteLines = globalThis._mapRouteLines || [];
  globalThis._mapRouteLines.push(line);
}

export async function disposeMapPage(ctx) {
  _ctx = ctx || _ctx;
  const { supabase } = _deps();

  if (_mapRefreshDebounce) {
    try { clearTimeout(_mapRefreshDebounce); } catch (_) {}
    _mapRefreshDebounce = null;
  }
  if (_mapRefreshTimer) {
    try { clearInterval(_mapRefreshTimer); } catch (_) {}
    _mapRefreshTimer = null;
  }
  if (_mapRealtimeChannel) {
    try { await supabase.removeChannel(_mapRealtimeChannel); } catch (_) {}
    _mapRealtimeChannel = null;
  }
  if (_mapInstance) {
    try { _mapInstance.remove(); } catch (_) {}
    _mapInstance = null;
  }
}

export async function renderMapPage(el, ctx) {
  _ctx = ctx || null;
  const { supabase } = _deps();

  await disposeMapPage(ctx);

  el.innerHTML = `
    <div class="fade-in space-y-4">
      <div class="grid grid-cols-2 md:grid-cols-3 lg:grid-cols-5 gap-4" id="mapStats"></div>
      <div class="flex flex-col xl:flex-row gap-4">
        <div class="w-full xl:w-80 xl:flex-shrink-0 glass-card overflow-hidden flex flex-col xl:max-h-[700px]">
          <div class="flex border-b border-gray-100">
            <button onclick="setMapSidebarTab('drivers')" id="mapTabDrivers" class="flex-1 px-3 py-2.5 text-xs font-bold text-white transition-colors" style="background:linear-gradient(135deg,#6366f1,#818cf8);">🏍 คนขับ</button>
            <button onclick="setMapSidebarTab('orders')" id="mapTabOrders" class="flex-1 px-3 py-2.5 text-xs font-bold bg-gray-50 text-gray-600 hover:bg-gray-100 transition-colors">📦 ออเดอร์</button>
          </div>
          <div id="mapDriverPanel">
            <div class="px-4 py-2 border-b border-gray-100">
              <input type="text" id="mapDriverSearch" placeholder="ค้นหาคนขับ..." class="w-full border rounded-lg px-2 py-1.5 text-xs" oninput="filterMapDriverList()" />
              <div class="flex gap-1 mt-2">
                <button onclick="setMapDriverFilter('all')" id="mapFilterAll" class="flex-1 px-2 py-1 rounded-lg text-[10px] font-semibold text-white" style="background:linear-gradient(135deg,#6366f1,#818cf8);">ทั้งหมด</button>
                <button onclick="setMapDriverFilter('online')" id="mapFilterOnline" class="flex-1 px-2 py-1 rounded text-[10px] font-medium bg-gray-100 text-gray-600 hover:bg-gray-200">ออนไลน์</button>
                <button onclick="setMapDriverFilter('available')" id="mapFilterAvailable" class="flex-1 px-2 py-1 rounded text-[10px] font-medium bg-gray-100 text-gray-600 hover:bg-gray-200">ว่าง</button>
                <button onclick="setMapDriverFilter('pending')" id="mapFilterPending" class="flex-1 px-2 py-1 rounded text-[10px] font-medium bg-gray-100 text-gray-600 hover:bg-gray-200">รออนุมัติ</button>
              </div>
            </div>
            <div id="mapDriverList" class="flex-1 overflow-y-auto p-2 space-y-1 max-h-[360px] md:max-h-[460px] xl:max-h-[520px]">
              <p class="text-gray-400 text-xs text-center py-4">กำลังโหลด...</p>
            </div>
          </div>
          <div id="mapOrderPanel" class="hidden">
            <div class="px-4 py-2 border-b border-gray-100">
              <div class="flex gap-1">
                <button onclick="setMapOrderFilter('active')" id="mapOrderFilterActive" class="flex-1 px-2 py-1 rounded text-[10px] font-medium bg-orange-500 text-white">กำลังดำเนินการ</button>
                <button onclick="setMapOrderFilter('pending')" id="mapOrderFilterPending" class="flex-1 px-2 py-1 rounded text-[10px] font-medium bg-gray-100 text-gray-600">รอคนขับ</button>
                <button onclick="setMapOrderFilter('all')" id="mapOrderFilterAll" class="flex-1 px-2 py-1 rounded text-[10px] font-medium bg-gray-100 text-gray-600">ทั้งหมด</button>
              </div>
            </div>
            <div id="mapOrderList" class="flex-1 overflow-y-auto p-2 space-y-1 max-h-[380px] md:max-h-[485px] xl:max-h-[545px]">
              <p class="text-gray-400 text-xs text-center py-4">กำลังโหลด...</p>
            </div>
          </div>
        </div>
        <div class="flex-1 min-w-0 glass-card overflow-hidden">
          <div class="px-6 py-3 border-b border-gray-100 flex items-center justify-between">
            <div class="flex items-center gap-2">
              <span class="font-bold text-gray-800">แผนที่ Realtime</span>
              <span id="mapRealtimeStatus" class="w-2 h-2 rounded-full bg-green-500 animate-pulse" title="Realtime connected"></span>
            </div>
            <div class="flex items-center gap-2 flex-wrap justify-end">
              <span class="flex items-center gap-1 text-xs whitespace-nowrap"><span class="w-3 h-3 rounded-full bg-green-500 inline-block"></span> ออนไลน์</span>
              <span class="flex items-center gap-1 text-xs whitespace-nowrap"><span class="w-3 h-3 rounded-full bg-blue-500 inline-block"></span> มีงาน</span>
              <span class="flex items-center gap-1 text-xs whitespace-nowrap"><span class="w-3 h-3 rounded-full bg-orange-500 inline-block"></span> ร้านค้า</span>
              <span class="flex items-center gap-1 text-xs whitespace-nowrap"><span class="w-3 h-3 rounded-full bg-amber-500 inline-block"></span> รออนุมัติ</span>
              <span class="flex items-center gap-1 text-xs whitespace-nowrap"><span class="w-3 h-3 rounded-full bg-red-500 inline-block border border-red-300"></span> ออเดอร์</span>
              <span class="flex items-center gap-1 text-xs whitespace-nowrap"><span style="width:16px;height:3px;background:#3B82F6;display:inline-block;border-radius:2px;"></span> ไปร้าน</span>
              <span class="flex items-center gap-1 text-xs whitespace-nowrap"><span style="width:16px;height:3px;background:#22C55E;display:inline-block;border-radius:2px;"></span> ส่งลูกค้า</span>
              <button onclick="refreshMapData()" class="px-3 py-1 text-white rounded-lg text-xs font-semibold hover:opacity-90 transition-all" style="background:linear-gradient(135deg,#6366f1,#818cf8);">รีเฟรช</button>
            </div>
          </div>
          <div id="adminMap" class="h-[420px] md:h-[560px] xl:h-[640px] w-full"></div>
        </div>
      </div>
    </div>`;

  setTimeout(async () => {
    if (_mapInstance) { _mapInstance.remove(); _mapInstance = null; }
    const initial = await _getInitialMapCenter();
    _mapInstance = L.map('adminMap').setView(initial.center, initial.zoom);
    L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png', {
      attribution: '© OpenStreetMap'
    }).addTo(_mapInstance);
    refreshMapData();
    await _setupMapRealtime();
  }, 100);

  _mapRefreshTimer = setInterval(refreshMapData, 30000);

  // make legacy onclick work by exposing funcs
  globalThis.setMapSidebarTab = setMapSidebarTab;
  globalThis.setMapDriverFilter = setMapDriverFilter;
  globalThis.filterMapDriverList = filterMapDriverList;
  globalThis.setMapOrderFilter = setMapOrderFilter;
  globalThis.refreshMapData = refreshMapData;
  globalThis.zoomToDriver = zoomToDriver;
  globalThis.zoomToOrder = zoomToOrder;
  globalThis.renderMapOrderList = renderMapOrderList;
}

export async function refreshMapData(ctx) {
  _ctx = ctx || _ctx;
  if (!_mapInstance) return;

  const { supabase, fmt, statCard, escapeHtml } = _deps();

  try {
    const { data: drivers } = await supabase
      .from('profiles')
      .select('id, full_name, phone_number, license_plate, latitude, longitude, is_online, approval_status, updated_at')
      .eq('role', 'driver')
      .eq('approval_status', 'approved');

    const { data: driverLocs } = await supabase.from('driver_locations').select('driver_id, location_lat, location_lng, is_online, is_available, current_booking_id');

    const dLocMap = {};
    (driverLocs || []).forEach(d => { dLocMap[d.driver_id] = d; });

    const activeStatuses = ['pending','pending_merchant','preparing','driver_accepted','matched','arrived','arrived_at_merchant','ready_for_pickup','picking_up_order','in_transit'];
    const { data: activeOrders } = await supabase
      .from('bookings')
      .select('id, driver_id, merchant_id, customer_id, status, service_type, price, delivery_fee, origin_lat, origin_lng, dest_lat, dest_lng, pickup_address, destination_address, created_at')
      .in('status', activeStatuses)
      .order('created_at', { ascending: false });

    const driverIds = [...new Set((activeOrders || []).filter(o => o.driver_id).map(o => o.driver_id))];
    let driverNamesMap = {};
    if (driverIds.length) {
      const { data: dNames } = await supabase.from('profiles').select('id, full_name').in('id', driverIds);
      (dNames || []).forEach(d => { driverNamesMap[d.id] = d.full_name || '-'; });
    }

    const driverOrderCount = {};
    (activeOrders || []).forEach(o => { if (o.driver_id) driverOrderCount[o.driver_id] = (driverOrderCount[o.driver_id] || 0) + 1; });

    const merchantIds = [...new Set((activeOrders || []).filter(o => o.merchant_id).map(o => o.merchant_id))];
    let merchantsMap = {};
    if (merchantIds.length) {
      const { data: mProfiles } = await supabase.from('profiles').select('id, full_name, shop_address, latitude, longitude').in('id', merchantIds);
      (mProfiles || []).forEach(m => { merchantsMap[m.id] = m; });
    }

    const merchantOrderCount = {};
    (activeOrders || []).forEach(o => { if (o.merchant_id) merchantOrderCount[o.merchant_id] = (merchantOrderCount[o.merchant_id] || 0) + 1; });

    globalThis._mapDriverMarkers = globalThis._mapDriverMarkers || [];
    globalThis._mapMerchantMarkers = globalThis._mapMerchantMarkers || [];
    globalThis._mapOrderMarkers = globalThis._mapOrderMarkers || [];
    globalThis._mapRouteLines = globalThis._mapRouteLines || [];

    globalThis._mapDriverMarkers.forEach(m => _mapInstance.removeLayer(m));
    globalThis._mapMerchantMarkers.forEach(m => _mapInstance.removeLayer(m));
    globalThis._mapOrderMarkers.forEach(m => _mapInstance.removeLayer(m));
    globalThis._mapRouteLines.forEach(l => _mapInstance.removeLayer(l));

    globalThis._mapDriverMarkers = [];
    globalThis._mapMerchantMarkers = [];
    globalThis._mapOrderMarkers = [];
    globalThis._mapRouteLines = [];

    let onlineCount = 0;
    let busyCount = 0;
    const pendingOrderStatuses = globalThis.MAP_PENDING_NO_DRIVER_STATUSES || ['pending', 'matched', 'pending_merchant'];
    const pendingDriverCount = (drivers || []).filter(d => d.approval_status === 'pending').length;

    const dispatchableStatuses = globalThis.MAP_DISPATCHABLE_STATUSES || ['pending', 'matched'];
    const pendingOrderCount = (activeOrders || []).filter(o => pendingOrderStatuses.includes(o.status) && !o.driver_id).length;

    const truthyFlag = globalThis._truthyFlag;
    const explicitlyFalseFlag = globalThis._explicitlyFalseFlag;

    (drivers || []).forEach(d => {
      let lat = d.latitude;
      let lng = d.longitude;
      const loc = dLocMap[d.id];
      if (loc && loc.location_lat && loc.location_lng) { lat = loc.location_lat; lng = loc.location_lng; }
      if (!lat || !lng) return;

      const jobCount = driverOrderCount[d.id] || 0;
      const profileOnline = typeof truthyFlag === 'function' ? truthyFlag(d.is_online) : !!d.is_online;
      const locOnline = loc && typeof truthyFlag === 'function' ? truthyFlag(loc.is_online) : !!loc?.is_online;
      const profileExplicitOffline = typeof explicitlyFalseFlag === 'function' ? explicitlyFalseFlag(d.is_online) : false;
      const isOnline = jobCount > 0 ? true : (profileExplicitOffline ? false : (profileOnline || locOnline));
      if (isOnline) onlineCount += 1;
      if (jobCount > 0) busyCount += 1;

      const isPending = d.approval_status === 'pending';
      const color = isPending ? '#F59E0B' : (jobCount > 0 ? '#3B82F6' : (isOnline ? '#22C55E' : '#9CA3AF'));
      const borderColor = isPending ? '#FBBF24' : '#fff';
      const icon = L.divIcon({
        className: '',
        html: `<div style="background:${color};color:#fff;width:32px;height:32px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:700;border:2px solid ${borderColor};box-shadow:0 2px 6px rgba(0,0,0,.3);">${isPending ? '⏳' : (jobCount > 0 ? jobCount : '🏍')}</div>`,
        iconSize: [32, 32],
        iconAnchor: [16, 16],
      });

      let nearestDist = null;
      (activeOrders || []).filter(o => pendingOrderStatuses.includes(o.status) && !o.driver_id && o.origin_lat && o.origin_lng).forEach(o => {
        const d2 = _haversineKm(lat, lng, o.origin_lat, o.origin_lng);
        if (nearestDist === null || d2 < nearestDist) nearestDist = d2;
      });
      const distText = nearestDist !== null ? `📏 ใกล้ออเดอร์: ${nearestDist.toFixed(1)} กม.` : '';

      const marker = L.marker([lat, lng], { icon }).addTo(_mapInstance);
      const pendingBadge = isPending ? '<br/><span style="background:#FEF3C7;color:#92400E;padding:1px 8px;border-radius:8px;font-size:10px;font-weight:600;">⏳ รออนุมัติ</span>' : '';
      marker.bindPopup(`<b>${escapeHtml(d.full_name) || '-'}</b>${pendingBadge}<br/>📞 ${escapeHtml(d.phone_number) || '-'}<br/>🚗 ${escapeHtml(d.license_plate) || '-'}<br/>📦 งาน: ${jobCount}<br/>${isOnline ? '🟢 ออนไลน์' : '🔴 ออฟไลน์'}${distText ? '<br/>' + distText : ''}`);
      globalThis._mapDriverMarkers.push(marker);
    });

    merchantIds.forEach(mId => {
      const m = merchantsMap[mId];
      if (!m) return;
      let lat = m.latitude;
      let lng = m.longitude;
      if (!lat || !lng) {
        const order = (activeOrders || []).find(o => o.merchant_id === mId && o.origin_lat && o.origin_lng);
        if (order) { lat = order.origin_lat; lng = order.origin_lng; }
      }
      if (!lat || !lng) return;

      const oCount = merchantOrderCount[mId] || 0;
      const icon = L.divIcon({
        className: '',
        html: `<div style="background:#F97316;color:#fff;width:32px;height:32px;border-radius:8px;display:flex;align-items:center;justify-content:center;font-size:12px;font-weight:700;border:2px solid #fff;box-shadow:0 2px 6px rgba(0,0,0,.3);">${oCount}</div>`,
        iconSize: [32, 32],
        iconAnchor: [16, 16],
      });

      const marker = L.marker([lat, lng], { icon }).addTo(_mapInstance);
      marker.bindPopup(`<b>🏪 ${escapeHtml(m.full_name) || '-'}</b><br/>📍 ${escapeHtml(m.shop_address) || '-'}<br/>📦 ออเดอร์: ${oCount}`);
      globalThis._mapMerchantMarkers.push(marker);
    });

    (activeOrders || []).forEach(o => {
      const isPending = pendingOrderStatuses.includes(o.status) && !o.driver_id;
      const lat = isPending ? (o.origin_lat || o.dest_lat) : null;
      const lng = isPending ? (o.origin_lng || o.dest_lng) : null;
      if (!lat || !lng) return;

      const canDispatch = dispatchableStatuses.includes(o.status) && !o.driver_id;
      const canAdminAccept = typeof globalThis._canAdminMerchantAccept === 'function' ? globalThis._canAdminMerchantAccept(o) : false;
      const popupAction = canDispatch
        ? `<button onclick="showOrderDispatchModal('${o.id}')" style="background:#3B82F6;color:#fff;padding:4px 12px;border-radius:6px;font-size:11px;margin-top:4px;border:none;cursor:pointer;">โยนงาน</button>`
        : canAdminAccept
          ? `<button onclick="adminMerchantAcceptOrder('${o.id}')" style="background:#10B981;color:#fff;padding:4px 12px;border-radius:6px;font-size:11px;margin-top:4px;border:none;cursor:pointer;">รับแทนร้าน</button>`
          : '';

      const icon = L.divIcon({
        className: '',
        html: `<div style="background:#EF4444;color:#fff;width:28px;height:28px;border-radius:50%;display:flex;align-items:center;justify-content:center;font-size:10px;font-weight:700;border:2px solid #FCA5A5;box-shadow:0 2px 6px rgba(0,0,0,.3);animation:pulse 2s infinite;">📦</div>`,
        iconSize: [28, 28],
        iconAnchor: [14, 14],
      });

      const marker = L.marker([lat, lng], { icon }).addTo(_mapInstance);
      const serviceIcon = globalThis.serviceIcon;
      const getStatusText = globalThis.getStatusText;
      marker.bindPopup(`<b>📦 #${o.id.substring(0,8)}</b><br/>${typeof serviceIcon === 'function' ? serviceIcon(o.service_type) : ''} ${typeof getStatusText === 'function' ? getStatusText(o.status) : o.status}<br/>📍 ${o.pickup_address || '-'}<br/>💰 ฿${fmt(Math.round(o.price||0))}${popupAction ? `<br/>${popupAction}` : ''}`);
      globalThis._mapOrderMarkers.push(marker);
    });

    const routeColors = { toMerchant: '#3B82F6', toCustomer: '#22C55E', preparing: '#A855F7' };
    const driverPosMap = {};
    (drivers || []).forEach(d => {
      let lat = d.latitude;
      let lng = d.longitude;
      const loc = dLocMap[d.id];
      if (loc && loc.location_lat && loc.location_lng) { lat = loc.location_lat; lng = loc.location_lng; }
      if (lat && lng) driverPosMap[d.id] = { lat, lng };
    });

    const routePromises = [];
    (activeOrders || []).forEach(o => {
      if (!o.driver_id || !_mapInstance) return;
      const dPos = driverPosMap[o.driver_id];
      if (!dPos) return;

      const prePickupStatuses = ['driver_accepted','matched','preparing','arrived_at_merchant','ready_for_pickup'];
      const inDeliveryStatuses = ['picking_up_order','in_transit'];

      if (prePickupStatuses.includes(o.status)) {
        if (o.origin_lat && o.origin_lng) {
          routePromises.push(_drawRouteLine(dPos.lat, dPos.lng, o.origin_lat, o.origin_lng, routeColors.toMerchant, 3, 0.7, '8,6', '🏍→🏪'));
        }
        if (o.origin_lat && o.origin_lng && o.dest_lat && o.dest_lng) {
          routePromises.push(_drawRouteLine(o.origin_lat, o.origin_lng, o.dest_lat, o.dest_lng, routeColors.preparing, 2, 0.4, '4,8', null));
        }
      } else if (inDeliveryStatuses.includes(o.status)) {
        if (o.dest_lat && o.dest_lng) {
          routePromises.push(_drawRouteLine(dPos.lat, dPos.lng, o.dest_lat, o.dest_lng, routeColors.toCustomer, 4, 0.8, null, '🏍→📍'));
        }
      }
    });

    Promise.all(routePromises).catch(e => console.error('Route drawing error:', e));

    const statsEl = document.getElementById('mapStats');
    if (statsEl) {
      statsEl.innerHTML = `
        ${statCard('directions_car', 'คนขับออนไลน์', onlineCount, 'bg-green-500')}
        ${statCard('local_shipping', 'คนขับมีงาน', busyCount, 'bg-blue-500')}
        ${statCard('hourglass_top', 'คนขับรออนุมัติ', pendingDriverCount, 'bg-amber-500')}
        ${statCard('store', 'ร้านค้ามีออเดอร์', merchantIds.length, 'bg-orange-500')}
        ${statCard('pending_actions', 'ออเดอร์รอดำเนินการ', pendingOrderCount, 'bg-red-500')}
      `;
    }

    globalThis._mapDriverData = [];
    const pendingOrderLocs = (activeOrders || []).filter(o => pendingOrderStatuses.includes(o.status) && !o.driver_id && o.origin_lat && o.origin_lng);
    (drivers || []).forEach(d => {
      let lat = d.latitude;
      let lng = d.longitude;
      const loc = dLocMap[d.id];
      if (loc && loc.location_lat && loc.location_lng) { lat = loc.location_lat; lng = loc.location_lng; }
      if (!lat || !lng) return;

      const jobCount = driverOrderCount[d.id] || 0;
      const profileOnline = typeof truthyFlag === 'function' ? truthyFlag(d.is_online) : !!d.is_online;
      const locOnline = loc && typeof truthyFlag === 'function' ? truthyFlag(loc.is_online) : !!loc?.is_online;
      const profileExplicitOffline = typeof explicitlyFalseFlag === 'function' ? explicitlyFalseFlag(d.is_online) : false;
      const isOnline = jobCount > 0 ? true : (profileExplicitOffline ? false : (profileOnline || locOnline));

      let nearestDist = null;
      pendingOrderLocs.forEach(o => {
        const d2 = _haversineKm(lat, lng, o.origin_lat, o.origin_lng);
        if (nearestDist === null || d2 < nearestDist) nearestDist = d2;
      });

      globalThis._mapDriverData.push({
        id: d.id,
        name: d.full_name || '-',
        phone: d.phone_number || '',
        plate: d.license_plate || '',
        lat,
        lng,
        jobCount,
        isOnline,
        nearestDist,
        approvalStatus: d.approval_status || 'pending',
      });
    });

    renderMapDriverList();

    globalThis._mapAllOrders = (activeOrders || []).map(o => ({
      ...o,
      driverName: o.driver_id ? (driverNamesMap[o.driver_id] || '-') : null,
      merchantName: o.merchant_id ? (merchantsMap[o.merchant_id]?.full_name || '-') : null,
    }));
    globalThis._mapOrderFilter = globalThis._mapOrderFilter || 'active';
    globalThis._mapPendingOrders = globalThis._mapAllOrders.filter(o => dispatchableStatuses.includes(o.status) && !o.driver_id);

    if (globalThis._autoDispatchIsEligible && globalThis._autoDispatchEnsure && globalThis._autoDispatchCancel) {
      (globalThis._mapAllOrders || []).forEach(o => {
        if (globalThis._autoDispatchIsEligible(o)) globalThis._autoDispatchEnsure(o);
        else if (o?.id) globalThis._autoDispatchCancel(o.id, 'not_eligible');
      });
    }

    renderMapOrderList();

    const ordersTab = document.getElementById('mapTabOrders');
    if (ordersTab) ordersTab.innerHTML = `📦 ออเดอร์ (${(activeOrders || []).length})`;

  } catch (e) {
    console.error('Map refresh error:', e);
  }
}

globalThis._mapDriverFilter = globalThis._mapDriverFilter || 'all';

export function setMapDriverFilter(filter) {
  globalThis._mapDriverFilter = filter;
  ['all', 'online', 'available', 'pending'].forEach(f => {
    const btn = document.getElementById('mapFilter' + f.charAt(0).toUpperCase() + f.slice(1));
    if (btn) {
      btn.className = f === filter
        ? 'flex-1 px-2 py-1 rounded-lg text-[10px] font-semibold text-white'
        : 'flex-1 px-2 py-1 rounded-lg text-[10px] font-semibold bg-gray-100 text-gray-600 hover:bg-gray-200';
      btn.style.background = f === filter ? 'linear-gradient(135deg,#6366f1,#818cf8)' : '';
    }
  });
  renderMapDriverList();
}

export function renderMapDriverList() {
  const { escapeHtml } = _deps();

  const driverListEl = document.getElementById('mapDriverList');
  if (!driverListEl) return;

  const q = (document.getElementById('mapDriverSearch')?.value || '').toLowerCase();
  let items = globalThis._mapDriverData || [];
  if (globalThis._mapDriverFilter === 'online') items = items.filter(d => d.isOnline);
  if (globalThis._mapDriverFilter === 'available') items = items.filter(d => d.isOnline && d.jobCount === 0);
  if (globalThis._mapDriverFilter === 'pending') items = items.filter(d => d.approvalStatus === 'pending');
  if (q) items = items.filter(d => d.name.toLowerCase().includes(q));

  if (!items.length) {
    driverListEl.innerHTML = '<p class="text-gray-400 text-xs text-center py-4">ไม่พบคนขับ</p>';
    return;
  }

  driverListEl.innerHTML = items.map(d => {
    const isPending = d.approvalStatus === 'pending';
    const color = isPending ? 'amber' : (d.jobCount > 0 ? 'blue' : (d.isOnline ? 'green' : 'gray'));
    const dotColor = isPending ? 'bg-amber-500' : (color === 'blue' ? 'bg-blue-500' : (color === 'green' ? 'bg-green-500' : 'bg-gray-400'));
    const canDispatch = !isPending && d.isOnline && d.jobCount === 0 && (globalThis._mapPendingOrders || []).length > 0;
    const distLabel = d.nearestDist !== null && d.nearestDist !== undefined ? `📏 ${d.nearestDist.toFixed(1)} กม.` : '';
    const pendingBadge = isPending ? '<span class="text-[9px] bg-amber-100 text-amber-700 px-1 rounded font-semibold">รออนุมัติ</span> ' : '';
    const borderClass = isPending ? 'border-amber-200 bg-amber-50/30' : (d.isOnline ? (d.jobCount > 0 ? 'border-blue-200 bg-blue-50/30' : 'border-green-200 bg-green-50/30') : 'border-gray-100 bg-gray-50/30');
    const safeName = String(d.name || '').replace(/'/g, '');

    return `
      <div class="map-driver-item flex items-center gap-2 px-3 py-2 rounded-lg hover:bg-blue-50 cursor-pointer transition-colors border ${borderClass}" data-name="${(d.name || '').toLowerCase()}" data-online="${d.isOnline}" data-jobs="${d.jobCount}">
        <span class="w-2.5 h-2.5 rounded-full ${dotColor} flex-shrink-0 ${d.isOnline && d.jobCount === 0 && !isPending ? 'animate-pulse' : ''}"></span>
        <div class="flex-1 min-w-0" onclick="zoomToDriver(${d.lat},${d.lng},'${safeName}')">
          <p class="text-xs font-medium truncate">${pendingBadge}${escapeHtml(d.name) || '-'}</p>
          <p class="text-[10px] text-gray-400">${escapeHtml(d.plate) || ''} ${isPending ? '• <span class=text-amber-600>รอการอนุมัติ</span>' : d.jobCount > 0 ? '• <span class=text-blue-600>งาน '+d.jobCount+'</span>' : d.isOnline ? '• <span class=text-green-600>ว่าง</span>' : '• <span class=text-gray-500>ออฟไลน์</span>'} ${distLabel ? '• ' + distLabel : ''}</p>
        </div>
        ${canDispatch ? `<button onclick="showMapDispatchModal('${d.id}','${safeName}')" class="px-1.5 py-0.5 bg-orange-500 text-white rounded text-[10px] font-medium hover:bg-orange-600 flex-shrink-0" title="โยนงาน">โยนงาน</button>` : `<span class="material-icons-round text-gray-300 text-sm flex-shrink-0 cursor-pointer" onclick="zoomToDriver(${d.lat},${d.lng},'${safeName}')">my_location</span>`}
      </div>`;
  }).join('');
}

export function zoomToDriver(lat, lng) {
  if (!_mapInstance) return;
  _mapInstance.setView([lat, lng], 16, { animate: true });

  (globalThis._mapDriverMarkers || []).forEach(m => {
    const pos = m.getLatLng();
    if (Math.abs(pos.lat - lat) < 0.0001 && Math.abs(pos.lng - lng) < 0.0001) m.openPopup();
  });
}

export function filterMapDriverList() {
  renderMapDriverList();
}

export function setMapSidebarTab(tab) {
  _mapSidebarTab = tab;

  const driversTab = document.getElementById('mapTabDrivers');
  const ordersTab = document.getElementById('mapTabOrders');
  const driverPanel = document.getElementById('mapDriverPanel');
  const orderPanel = document.getElementById('mapOrderPanel');

  if (tab === 'drivers') {
    if (driversTab) { driversTab.className = 'flex-1 px-3 py-2.5 text-xs font-bold text-white transition-colors'; driversTab.style.background = 'linear-gradient(135deg,#6366f1,#818cf8)'; }
    if (ordersTab) { ordersTab.className = 'flex-1 px-3 py-2.5 text-xs font-bold bg-gray-50 text-gray-600 hover:bg-gray-100 transition-colors'; ordersTab.style.background = ''; }
    if (driverPanel) driverPanel.classList.remove('hidden');
    if (orderPanel) orderPanel.classList.add('hidden');
  } else {
    if (driversTab) { driversTab.className = 'flex-1 px-3 py-2.5 text-xs font-bold bg-gray-50 text-gray-600 hover:bg-gray-100 transition-colors'; driversTab.style.background = ''; }
    if (ordersTab) { ordersTab.className = 'flex-1 px-3 py-2.5 text-xs font-bold text-white transition-colors'; ordersTab.style.background = 'linear-gradient(135deg,#6366f1,#818cf8)'; }
    if (driverPanel) driverPanel.classList.add('hidden');
    if (orderPanel) orderPanel.classList.remove('hidden');
    renderMapOrderList();
  }
}

export function setMapOrderFilter(filter) {
  globalThis._mapOrderFilter = filter;

  ['active', 'pending', 'all'].forEach(f => {
    const btn = document.getElementById('mapOrderFilter' + f.charAt(0).toUpperCase() + f.slice(1));
    if (btn) {
      btn.className = f === filter
        ? 'flex-1 px-2 py-1 rounded text-[10px] font-medium bg-orange-500 text-white'
        : 'flex-1 px-2 py-1 rounded text-[10px] font-medium bg-gray-100 text-gray-600 hover:bg-gray-200';
    }
  });

  renderMapOrderList();
}

function _timeAgo(dateStr) {
  if (!dateStr) return '';
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return 'เมื่อสักครู่';
  if (mins < 60) return `${mins} นาทีที่แล้ว`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return `${hrs} ชั่วโมงที่แล้ว`;
  return `${Math.floor(hrs / 24)} วันที่แล้ว`;
}

export function renderMapOrderList() {
  const { fmt } = _deps();

  const listEl = document.getElementById('mapOrderList');
  if (!listEl) return;

  let orders = globalThis._mapAllOrders || [];
  const filter = globalThis._mapOrderFilter || 'active';
  const pendingOrderStatuses = globalThis.MAP_PENDING_NO_DRIVER_STATUSES || ['pending', 'matched', 'pending_merchant'];
  const dispatchableStatuses = globalThis.MAP_DISPATCHABLE_STATUSES || ['pending', 'matched'];

  if (filter === 'pending') {
    orders = orders.filter(o => pendingOrderStatuses.includes(o.status) && !o.driver_id);
  } else if (filter === 'active') {
    orders = orders.filter(o => !pendingOrderStatuses.includes(o.status) || o.driver_id);
  }

  if (!orders.length) {
    listEl.innerHTML = '<p class="text-gray-400 text-xs text-center py-4">ไม่มีออเดอร์</p>';
    return;
  }

  const serviceIcon = globalThis.serviceIcon;
  const getStatusText = globalThis.getStatusText;
  const getStatusStyle = globalThis.getStatusStyle;

  listEl.innerHTML = orders.map(o => {
    const isPending = pendingOrderStatuses.includes(o.status) && !o.driver_id;
    const isDispatchable = dispatchableStatuses.includes(o.status) && !o.driver_id;
    const canAdminAccept = typeof globalThis._canAdminMerchantAccept === 'function' ? globalThis._canAdminMerchantAccept(o) : false;
    const canAdminReady = typeof globalThis._canAdminMarkFoodReady === 'function' ? globalThis._canAdminMarkFoodReady(o) : false;
    const hasLoc = o.origin_lat && o.origin_lng;
    const timeDiff = _timeAgo(o.created_at);

    const isAuto = typeof globalThis._autoDispatchIsEligible === 'function' ? globalThis._autoDispatchIsEligible(o) : false;
    const left = isAuto && typeof globalThis._autoDispatchSecondsLeft === 'function' ? globalThis._autoDispatchSecondsLeft(o.id) : null;
    const countdownBadge = isAuto && left !== null
      ? `<span class="px-1.5 py-0.5 rounded text-[9px] font-bold bg-purple-100 text-purple-700">⏳ ${left}s</span>`
      : '';

    return `
      <div class="flex flex-col gap-1 px-3 py-2 rounded-lg border ${isPending ? 'border-red-200 bg-red-50' : 'border-gray-100 bg-white'} hover:shadow-sm transition-shadow">
        <div class="flex items-center justify-between">
          <div class="flex items-center gap-1.5">
            <span class="text-xs">${typeof serviceIcon === 'function' ? serviceIcon(o.service_type) : ''}</span>
            <span class="text-xs font-bold text-gray-800">#${o.id.substring(0,8)}</span>
            <span class="px-1.5 py-0.5 rounded text-[9px] font-medium ${typeof getStatusStyle === 'function' ? getStatusStyle(o.status) : ''}">${typeof getStatusText === 'function' ? getStatusText(o.status) : o.status}</span>
            ${countdownBadge}
          </div>
          <span class="text-[10px] font-bold text-green-600">฿${fmt(Math.round(o.price||0))}</span>
        </div>
        <div class="flex items-center justify-between">
          <div class="flex-1 min-w-0">
            <p class="text-[10px] text-gray-500 truncate">📍 ${o.pickup_address || '-'}</p>
            ${o.driverName ? `<p class=\"text-[10px] text-blue-600\">🏍 ${o.driverName}</p>` : ''}
            ${o.merchantName ? `<p class=\"text-[10px] text-orange-600\">🏪 ${o.merchantName}</p>` : ''}
            <p class="text-[9px] text-gray-400">${timeDiff}</p>
          </div>
          <div class="flex items-center gap-1 flex-shrink-0 flex-wrap justify-end">
            ${hasLoc ? `<button onclick=\"zoomToOrder(${o.origin_lat},${o.origin_lng},'${o.id.substring(0,8)}')\" class=\"p-1 text-gray-400 hover:text-blue-500\" title=\"ดูบนแผนที่\"><span class=\"material-icons-round text-sm\">my_location</span></button>` : ''}
            ${isDispatchable ? `<button onclick=\"showOrderDispatchModal('${o.id}')\" class=\"px-2 py-0.5 bg-blue-500 text-white rounded text-[10px] font-medium hover:bg-blue-600\">โยนงาน</button>` : (o.driver_id ? `<button onclick=\"showReassignDriverModal('${o.id}')\" class=\"px-2 py-0.5 bg-amber-500 text-white rounded text-[10px] font-medium hover:bg-amber-600\" title=\"ย้ายคนขับ\">ย้าย</button>` : '')}
            ${canAdminAccept ? `<button onclick=\"adminMerchantAcceptOrder('${o.id}')\" class=\"px-2 py-0.5 bg-emerald-500 text-white rounded text-[10px] font-medium hover:bg-emerald-600\">รับแทนร้าน</button>` : ''}
            ${canAdminReady ? `<button onclick=\"adminMarkFoodReady('${o.id}')\" class=\"px-2 py-0.5 bg-teal-500 text-white rounded text-[10px] font-medium hover:bg-teal-600\">อาหารพร้อม</button>` : ''}
          </div>
        </div>
      </div>`;
  }).join('');
}

export function zoomToOrder(lat, lng) {
  if (!_mapInstance) return;
  _mapInstance.setView([lat, lng], 16, { animate: true });

  (globalThis._mapOrderMarkers || []).forEach(m => {
    const pos = m.getLatLng();
    if (Math.abs(pos.lat - lat) < 0.001 && Math.abs(pos.lng - lng) < 0.001) m.openPopup();
  });
}

export async function showOrderDispatchModal(orderId) {
  return globalThis.showOrderDispatchModal?.(orderId);
}

export async function showMapDispatchModal(driverId, driverName) {
  return globalThis.showMapDispatchModal?.(driverId, driverName);
}

export async function dispatchOrderToDriver(orderId, driverId, driverName) {
  return globalThis.dispatchOrderToDriver?.(orderId, driverId, driverName);
}

export async function showReassignDriverModal(orderId) {
  return globalThis.showReassignDriverModal?.(orderId);
}

export async function reassignOrderToDriver(orderId, newDriverId, newDriverName) {
  return globalThis.reassignOrderToDriver?.(orderId, newDriverId, newDriverName);
}

export function wireMapBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  globalThis.__adminWebBridge.renderMapPage = renderMapPage;
  globalThis.__adminWebBridge.refreshMapData = refreshMapData;
  globalThis.__adminWebBridge.setMapSidebarTab = setMapSidebarTab;
  globalThis.__adminWebBridge.setMapDriverFilter = setMapDriverFilter;
  globalThis.__adminWebBridge.renderMapDriverList = renderMapDriverList;
  globalThis.__adminWebBridge.filterMapDriverList = filterMapDriverList;
  globalThis.__adminWebBridge.setMapOrderFilter = setMapOrderFilter;
  globalThis.__adminWebBridge.renderMapOrderList = renderMapOrderList;
  globalThis.__adminWebBridge.zoomToDriver = zoomToDriver;
  globalThis.__adminWebBridge.zoomToOrder = zoomToOrder;
  globalThis.__adminWebBridge.disposeMapPage = disposeMapPage;
  globalThis.__adminWebBridge.showOrderDispatchModal = showOrderDispatchModal;
  globalThis.__adminWebBridge.showMapDispatchModal = showMapDispatchModal;
  globalThis.__adminWebBridge.dispatchOrderToDriver = dispatchOrderToDriver;
  globalThis.__adminWebBridge.showReassignDriverModal = showReassignDriverModal;
  globalThis.__adminWebBridge.reassignOrderToDriver = reassignOrderToDriver;
}
