let _ctx = null;

function _deps() {
  const supabase = _ctx?.supabase || globalThis.supabase;
  const callAdminAction = _ctx?.callAdminAction || globalThis.callAdminAction;
  const showToast = _ctx?.showToast || globalThis.showToast;
  const refreshCurrentPage = _ctx?.refreshCurrentPage || globalThis.refreshCurrentPage;
  const fmt = _ctx?.fmt || globalThis.fmt;
  const escapeHtml = _ctx?.escapeHtml || globalThis.escapeHtml;

  return {
    supabase,
    callAdminAction,
    showToast,
    refreshCurrentPage,
    fmt,
    escapeHtml,
  };
}

const MENU_CATEGORIES = [
  'อาหารตามสั่ง',
  'ก๋วยเตี๋ยว',
  'เครื่องดื่ม',
  'ของหวาน',
  'ฟาสต์ฟู้ด',
  'อาหารเช้า',
  'อาหารญี่ปุ่น',
  'อาหารอีสาน',
  'ของทานเล่น',
  'อื่นๆ',
];

function categoryDropdownHtml(id, selected) {
  return `<select id="${id}" class="w-full border rounded-lg px-3 py-2 text-sm">${MENU_CATEGORIES.map((c) => `<option value="${c}" ${c === selected ? 'selected' : ''}>${c}</option>`).join('')}</select>`;
}

export async function renderMenusPage(el, ctx) {
  _ctx = ctx || null;
  const { supabase, escapeHtml } = _deps();

  const { data: merchants } = await supabase
    .from('profiles')
    .select('id, full_name, shop_address')
    .eq('role', 'merchant')
    .eq('approval_status', 'approved')
    .order('full_name');

  const preselected = globalThis._selectedMerchantId || '';
  el.innerHTML = `
    <div class="fade-in space-y-5">
      <div class="glass-card p-4 flex flex-wrap gap-3 items-center">
        <span class="material-icons-round text-indigo-400 text-lg">store</span>
        <select id="menuMerchantSelect" onchange="loadMerchantMenus()" class="border border-gray-200 rounded-xl px-3.5 py-2 text-sm flex-1 max-w-md bg-gray-50/50 transition-all">
          <option value="">-- เลือกร้านค้า --</option>
          ${(merchants || [])
            .map(
              (m) =>
                `<option value="${m.id}" ${m.id === preselected ? 'selected' : ''}>${escapeHtml(m.full_name)}${m.shop_address ? ' — ' + escapeHtml(m.shop_address) : ''}</option>`,
            )
            .join('')}
        </select>
        <div class="relative min-w-[260px]">
          <span class="material-icons-round text-gray-400 text-sm absolute left-3 top-1/2 -translate-y-1/2">search</span>
          <input type="text" id="menuSearch" placeholder="ค้นหาเมนู, หมวดหมู่" class="w-full pl-9 pr-3 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50" oninput="filterMerchantMenus()">
        </div>
        <button onclick="showAddMenuForm()" class="px-5 py-2 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200 flex items-center gap-1.5" style="background:linear-gradient(135deg,#6366f1,#818cf8);"><span class="material-icons-round text-sm">add</span> เพิ่มเมนู</button>
      </div>
      <div id="menuFormContainer"></div>
      <div id="menuListContainer"><p class="text-gray-400 text-center py-10">กรุณาเลือกร้านค้า</p></div>
    </div>
  `;

  globalThis._selectedMerchantId = '';
  globalThis._allMerchantMenus = [];

  globalThis.loadMerchantMenus = loadMerchantMenus;
  globalThis.renderMenuRows = renderMenuRows;
  globalThis.filterMerchantMenus = filterMerchantMenus;
  globalThis.showAddMenuForm = showAddMenuForm;
  globalThis.showAddMenuOptionGroupPicker = showAddMenuOptionGroupPicker;
  globalThis.createOptionGroupForAddMenu = createOptionGroupForAddMenu;
  globalThis.toggleAddMenuGroup = toggleAddMenuGroup;
  globalThis.renderAddMenuOptionGroups = renderAddMenuOptionGroups;
  globalThis.previewMenuImage = previewMenuImage;
  globalThis.submitAddMenu = submitAddMenu;
  globalThis.editMenuItem = editMenuItem;
  globalThis.submitEditMenu = submitEditMenu;
  globalThis.unlinkOptionGroupFromMenu = unlinkOptionGroupFromMenu;
  globalThis.showLinkOptionGroupModal = showLinkOptionGroupModal;
  globalThis.createOptionGroupAndLink = createOptionGroupAndLink;
  globalThis.toggleLinkGroup = toggleLinkGroup;
  globalThis.showManageOptionsModal = showManageOptionsModal;
  globalThis.addMenuOption = addMenuOption;
  globalThis.toggleOptionAvail = toggleOptionAvail;
  globalThis.deleteMenuOption = deleteMenuOption;
  globalThis.deleteMenuItem = deleteMenuItem;
  globalThis.showManageOptionsModalStandalone = showManageOptionsModalStandalone;
  globalThis.addMenuOptionStandalone = addMenuOptionStandalone;
  globalThis.toggleOptSA = toggleOptSA;
  globalThis.deleteOptSA = deleteOptSA;
  globalThis.deleteOptionGroup = deleteOptionGroup;

  globalThis._addMenuSelectedGroups = [];

  if (preselected) {
    const sel = document.getElementById('menuMerchantSelect');
    if (sel) sel.value = preselected;
    await loadMerchantMenus();
  }
}

export async function loadMerchantMenus(ctx) {
  _ctx = ctx || _ctx;
  const { supabase } = _deps();

  const merchantId = document.getElementById('menuMerchantSelect')?.value;
  const mc = document.getElementById('menuListContainer');
  if (!merchantId || !mc) {
    if (mc) mc.innerHTML = '<p class="text-gray-400 text-center py-10">กรุณาเลือกร้านค้า</p>';
    return;
  }

  mc.innerHTML = '<div class="flex justify-center py-10"><div class="loader"></div></div>';
  const { data: menus } = await supabase
    .from('menu_items')
    .select('*')
    .eq('merchant_id', merchantId)
    .order('category')
    .order('name');

  globalThis._allMerchantMenus = menus || [];

  mc.innerHTML = `
    <div class="glass-card overflow-hidden">
      <div class="px-6 py-4 flex items-center gap-3">
        <div class="w-8 h-8 bg-orange-50 rounded-lg flex items-center justify-center"><span class="material-icons-round text-orange-500 text-sm">restaurant_menu</span></div>
        <span class="font-bold text-gray-800">เมนูทั้งหมด (${(menus || []).length})</span>
      </div>
      <div class="overflow-x-auto">
        <table class="w-full text-sm">
          <thead><tr class="bg-gray-50/80">
            <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">รูป</th>
            <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ชื่อเมนู</th>
            <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">หมวดหมู่</th>
            <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ราคา</th>
            <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">สถานะ</th>
            <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">จัดการ</th>
          </tr></thead>
          <tbody id="menuTableBody">
            ${renderMenuRows(globalThis._allMerchantMenus)}
          </tbody>
        </table>
      </div>
    </div>`;

  filterMerchantMenus();
}

export function renderMenuRows(menus, ctx) {
  _ctx = ctx || _ctx;
  const { fmt } = _deps();

  if (!(menus || []).length) {
    return '<tr><td colspan="6" class="px-4 py-8 text-center text-gray-400">ไม่มีเมนู</td></tr>';
  }

  return (menus || [])
    .map(
      (m) => `
    <tr class="table-row border-b border-gray-50">
      <td class="px-4 py-3">${m.image_url ? `<img src="${m.image_url}" class="w-10 h-10 rounded-lg object-cover" />` : '<div class="w-10 h-10 bg-gray-100 rounded-lg flex items-center justify-center"><span class="material-icons-round text-gray-400 text-sm">image</span></div>'}</td>
      <td class="px-4 py-3 font-medium">${m.name || '-'}</td>
      <td class="px-4 py-3 text-gray-500">${m.category || '-'}</td>
      <td class="px-4 py-3 font-semibold">฿${fmt(m.price)}</td>
      <td class="px-4 py-3">${m.is_available !== false ? '<span class="text-green-600 text-xs font-semibold">พร้อมขาย</span>' : '<span class="text-gray-400 text-xs">ปิดขาย</span>'}</td>
      <td class="px-4 py-3 whitespace-nowrap">
        <button onclick="editMenuItem('${m.id}')" class="px-3 py-1 bg-blue-500 text-white rounded-lg text-xs font-medium hover:bg-blue-600 mr-1">แก้ไข</button>
        <button onclick="deleteMenuItem('${m.id}','${(m.name || '').replace(/'/g, '')}')" class="px-3 py-1 bg-red-100 text-red-600 rounded-lg text-xs font-medium hover:bg-red-200">ลบ</button>
      </td>
    </tr>
  `,
    )
    .join('');
}

export function filterMerchantMenus(ctx) {
  _ctx = ctx || _ctx;
  const body = document.getElementById('menuTableBody');
  if (!body) return;

  const search = (document.getElementById('menuSearch')?.value || '').toLowerCase();
  let filtered = globalThis._allMerchantMenus || [];
  if (search) {
    filtered = filtered.filter(
      (m) =>
        (m.name || '').toLowerCase().includes(search) ||
        (m.category || '').toLowerCase().includes(search) ||
        (m.description || '').toLowerCase().includes(search),
    );
  }
  body.innerHTML = renderMenuRows(filtered);
}

export async function showAddMenuForm(ctx) {
  _ctx = ctx || _ctx;
  const merchantId = document.getElementById('menuMerchantSelect')?.value;
  if (!merchantId) return alert('กรุณาเลือกร้านค้าก่อน');
  globalThis._addMenuSelectedGroups = [];
  const c = document.getElementById('menuFormContainer');
  if (!c) return;
  c.innerHTML = `
    <div class="glass-card p-6">
      <h4 class="font-bold text-gray-800 mb-4">เพิ่มเมนูใหม่</h4>
      <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
        <div><label class="block text-sm font-medium mb-1">ชื่อเมนู</label><input id="addMenuName" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
        <div><label class="block text-sm font-medium mb-1">หมวดหมู่</label>${categoryDropdownHtml('addMenuCat', 'อาหารตามสั่ง')}</div>
        <div><label class="block text-sm font-medium mb-1">ราคา (฿)</label><input id="addMenuPrice" type="number" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
        <div class="md:col-span-2"><label class="block text-sm font-medium mb-1">รายละเอียด</label><input id="addMenuDesc" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
        <div><label class="block text-sm font-medium mb-1">URL รูปภาพ</label><input id="addMenuImg" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="วาง URL หรืออัพโหลดไฟล์ด้านล่าง" /></div>
        <div>
          <label class="block text-sm font-medium mb-1">อัพโหลดรูปภาพ</label>
          <input type="file" id="addMenuFile" accept="image/*" class="w-full border rounded-lg px-3 py-1.5 text-sm file:mr-2 file:py-1 file:px-3 file:rounded-lg file:border-0 file:text-sm file:bg-indigo-100 file:text-indigo-700 hover:file:bg-indigo-200" onchange="previewMenuImage(this,'addMenuPreview')" />
          <div id="addMenuPreview" class="mt-2"></div>
        </div>
      </div>

      <div class="mt-4 border rounded-xl p-4">
        <div class="flex items-center justify-between mb-3">
          <h5 class="font-bold text-gray-700 text-sm flex items-center gap-2"><span class="material-icons-round text-sm">tune</span> ตัวเลือกเมนู</h5>
          <button onclick="showAddMenuOptionGroupPicker('${merchantId}')" class="px-3 py-1 bg-green-500 text-white rounded-lg text-xs font-medium hover:bg-green-600 flex items-center gap-1"><span class="material-icons-round text-xs">add</span> เพิ่มตัวเลือก</button>
        </div>
        <div id="addMenuOptionGroupsList"><p class="text-gray-400 text-sm py-2">ยังไม่มีตัวเลือก</p></div>
      </div>

      <div class="mt-4 flex gap-2">
        <button onclick="submitAddMenu('${merchantId}')" class="px-5 py-2 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">บันทึก</button>
        <button onclick="document.getElementById('menuFormContainer').innerHTML=''" class="px-4 py-2 bg-gray-100 text-gray-600 rounded-lg text-sm font-medium hover:bg-gray-200">ยกเลิก</button>
      </div>
    </div>`;
}

export async function showAddMenuOptionGroupPicker(merchantId, ctx) {
  _ctx = ctx || _ctx;
  const { supabase } = _deps();

  const { data: groups } = await supabase
    .from('menu_option_groups')
    .select('*, menu_options(*)')
    .eq('merchant_id', merchantId)
    .order('name');
  const selectedIds = new Set((globalThis._addMenuSelectedGroups || []).map((g) => g.id));

  let groupsHtml = '';
  if (!groups || groups.length === 0) {
    groupsHtml = '<p class="text-gray-400 text-sm">ยังไม่มีกลุ่มตัวเลือก</p>';
  } else {
    groupsHtml = groups
      .map((g) => {
        const isSel = selectedIds.has(g.id);
        const safeName = (g.name || '').replace(/'/g, '');
        const optionsHtml =
          (g.menu_options || []).length > 0
            ? '<div class="mt-1 flex flex-wrap gap-1">' +
              (g.menu_options || [])
                .map((o) => '<span class="px-1.5 py-0.5 bg-gray-100 rounded text-xs">' + o.name + (o.price > 0 ? ' +฿' + o.price : '') + '</span>')
                .join('') +
              '</div>'
            : '';
        const toggleBtn = isSel
          ? '<button onclick="toggleAddMenuGroup(\'' + g.id + '\',false,\'' + merchantId + '\')" class="px-3 py-1 bg-red-100 text-red-600 rounded-lg text-xs font-medium hover:bg-red-200">เอาออก</button>'
          : '<button onclick="toggleAddMenuGroup(\'' + g.id + '\',true,\'' + merchantId + '\')" class="px-3 py-1 bg-green-500 text-white rounded-lg text-xs font-medium hover:bg-green-600">เพิ่ม</button>';
        return (
          '<div class="border rounded-lg p-3 mb-2 ' +
          (isSel ? 'bg-green-50 border-green-200' : '') +
          '">' +
          '<div class="flex items-center justify-between"><div>' +
          '<span class="font-medium text-sm">' +
          g.name +
          '</span>' +
          '<span class="text-xs text-gray-500 ml-2">(' +
          g.min_selection +
          '-' +
          g.max_selection +
          ')</span>' +
          optionsHtml +
          '</div><div class="flex items-center gap-2">' +
          '<button onclick="showManageOptionsModalStandalone(\'' +
          g.id +
          '\',\'' +
          safeName +
          '\',\'' +
          merchantId +
          '\')" class="px-2 py-1 bg-gray-100 text-gray-600 rounded text-xs hover:bg-gray-200">จัดการตัวเลือก</button>' +
          '<button onclick="deleteOptionGroup(\'' +
          g.id +
          '\',\'' +
          merchantId +
          '\')" class="px-2 py-1 bg-red-100 text-red-600 rounded text-xs hover:bg-red-200">ลบกลุ่ม</button>' +
          toggleBtn +
          '</div></div></div>'
        );
      })
      .join('');
  }

  const modal = document.createElement('div');
  modal.id = 'addMenuOptionGroupPickerModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-2xl mx-4 fade-in max-h-[80vh] flex flex-col">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <h3 class="font-bold text-gray-800 text-lg">เลือกกลุ่มตัวเลือก</h3>
        <button onclick="document.getElementById('addMenuOptionGroupPickerModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-6 overflow-y-auto flex-1">
        <div class="bg-blue-50 rounded-xl p-4 mb-4">
          <h4 class="font-bold text-sm text-blue-800 mb-3">สร้างกลุ่มตัวเลือกใหม่</h4>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
            <div><input id="newAddGroupName" placeholder="ชื่อกลุ่ม เช่น ระดับความเผ็ด" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
            <div class="flex gap-2">
              <input id="newAddGroupMin" type="number" value="0" min="0" placeholder="ขั้นต่ำ" class="w-full border rounded-lg px-3 py-2 text-sm" />
              <input id="newAddGroupMax" type="number" value="1" min="1" placeholder="สูงสุด" class="w-full border rounded-lg px-3 py-2 text-sm" />
            </div>
            <div><button onclick="createOptionGroupForAddMenu('${merchantId}')" class="w-full px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">สร้าง</button></div>
          </div>
        </div>
        <h4 class="font-bold text-sm text-gray-700 mb-2">กลุ่มตัวเลือกที่มีอยู่</h4>
        ${groupsHtml}
      </div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => {
    if (e.target === modal) modal.remove();
  });
}

export async function createOptionGroupForAddMenu(merchantId, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml } = _deps();

  const name = document.getElementById('newAddGroupName')?.value?.trim();
  const min = parseInt(document.getElementById('newAddGroupMin')?.value) || 0;
  const max = parseInt(document.getElementById('newAddGroupMax')?.value) || 1;
  if (!name) return alert('กรุณากรอกชื่อกลุ่ม');
  try {
    const result = await callAdminAction({ action: 'create_menu_option_group', merchant_id: merchantId, name, min_selection: min, max_selection: max });
    if (result?.group) globalThis._addMenuSelectedGroups.push(result.group);
    document.getElementById('addMenuOptionGroupPickerModal')?.remove();
    await showAddMenuOptionGroupPicker(merchantId);
    renderAddMenuOptionGroups();
    showToast('สร้างกลุ่มตัวเลือกสำเร็จ!', 'success');
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export function toggleAddMenuGroup(groupId, add, merchantId, ctx) {
  _ctx = ctx || _ctx;

  if (add) {
    if (!globalThis._addMenuSelectedGroups.find((g) => g.id === groupId)) {
      globalThis._addMenuSelectedGroups.push({ id: groupId });
    }
  } else {
    globalThis._addMenuSelectedGroups = globalThis._addMenuSelectedGroups.filter((g) => g.id !== groupId);
  }
  document.getElementById('addMenuOptionGroupPickerModal')?.remove();
  showAddMenuOptionGroupPicker(merchantId);
  renderAddMenuOptionGroups();
}

export function renderAddMenuOptionGroups(ctx) {
  _ctx = ctx || _ctx;
  const el = document.getElementById('addMenuOptionGroupsList');
  if (!el) return;
  if ((globalThis._addMenuSelectedGroups || []).length === 0) {
    el.innerHTML = '<p class="text-gray-400 text-sm py-2">ยังไม่มีตัวเลือก</p>';
    return;
  }
  el.innerHTML = globalThis._addMenuSelectedGroups
    .map(
      (g) => `
    <div class="border rounded-lg p-2 mb-1 flex items-center justify-between bg-green-50 border-green-200">
      <span class="text-sm font-medium">${g.name || g.id.substring(0, 8)}</span>
      <button onclick="window._addMenuSelectedGroups=window._addMenuSelectedGroups.filter(x=>x.id!=='${g.id}');renderAddMenuOptionGroups();" class="text-xs text-red-500 hover:underline">ลบออก</button>
    </div>`,
    )
    .join('');
}

export async function showManageOptionsModalStandalone(groupId, groupName, merchantId, ctx) {
  _ctx = ctx || _ctx;
  const { supabase } = _deps();

  const { data: options } = await supabase.from('menu_options').select('*').eq('group_id', groupId).order('name');

  let optionsHtml = '';
  if (!options || options.length === 0) {
    optionsHtml = '<p class="text-gray-400 text-sm">ยังไม่มีตัวเลือก</p>';
  } else {
    optionsHtml = options
      .map((o) => {
        const priceHtml = o.price > 0 ? '<span class="text-xs text-green-600 font-semibold">+฿' + o.price + '</span>' : '';
        return (
          '<div class="flex items-center justify-between py-2 border-b border-gray-50">' +
          '<div class="flex items-center gap-3">' +
          '<span class="text-sm font-medium ' +
          (o.is_available ? '' : 'line-through text-gray-400') +
          '">' +
          o.name +
          '</span>' +
          priceHtml +
          '</div>' +
          '<div class="flex items-center gap-2">' +
          '<button onclick="toggleOptSA(\'' +
          o.id +
          '\',' +
          !o.is_available +
          ',\'' +
          groupId +
          '\',\'' +
          groupName +
          '\',\'' +
          merchantId +
          '\')" class="text-xs ' +
          (o.is_available ? 'text-orange-500' : 'text-green-500') +
          ' hover:underline">' +
          (o.is_available ? 'ปิด' : 'เปิด') +
          '</button>' +
          '<button onclick="deleteOptSA(\'' +
          o.id +
          '\',\'' +
          groupId +
          '\',\'' +
          groupName +
          '\',\'' +
          merchantId +
          '\')" class="text-xs text-red-500 hover:underline">ลบ</button>' +
          '</div></div>'
        );
      })
      .join('');
  }

  const modal = document.createElement('div');
  modal.id = 'manageOptionsStandaloneModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-[60]';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 fade-in">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <h3 class="font-bold text-gray-800">ตัวเลือกใน "${groupName}"</h3>
        <button onclick="document.getElementById('manageOptionsStandaloneModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-6">
        <div class="flex gap-2 mb-4">
          <input id="newOptNameSA" placeholder="ชื่อตัวเลือก" class="flex-1 border rounded-lg px-3 py-2 text-sm" />
          <input id="newOptPriceSA" type="number" value="0" placeholder="ราคาเพิ่ม" class="w-24 border rounded-lg px-3 py-2 text-sm" />
          <button onclick="addMenuOptionStandalone('${groupId}','${groupName}','${merchantId}')" class="px-4 py-2 bg-green-500 text-white rounded-lg text-sm font-medium hover:bg-green-600">เพิ่ม</button>
        </div>
        <div>${optionsHtml}</div>
      </div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => {
    if (e.target === modal) modal.remove();
  });
}

export async function addMenuOptionStandalone(groupId, groupName, merchantId, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml } = _deps();

  const name = document.getElementById('newOptNameSA')?.value?.trim();
  const price = parseInt(document.getElementById('newOptPriceSA')?.value) || 0;
  if (!name) return alert('กรุณากรอกชื่อตัวเลือก');
  try {
    await callAdminAction({ action: 'create_menu_option', group_id: groupId, name, price, is_available: true });
    document.getElementById('manageOptionsStandaloneModal')?.remove();
    showManageOptionsModalStandalone(groupId, groupName, merchantId);
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function toggleOptSA(optionId, newState, groupId, groupName, merchantId, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml } = _deps();

  try {
    await callAdminAction({ action: 'update_menu_option', id: optionId, update_data: { is_available: newState } });
    document.getElementById('manageOptionsStandaloneModal')?.remove();
    showManageOptionsModalStandalone(groupId, groupName, merchantId);
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function deleteOptSA(optionId, groupId, groupName, merchantId, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml } = _deps();

  if (!confirm('ลบตัวเลือกนี้?')) return;
  try {
    await callAdminAction({ action: 'delete_menu_option', id: optionId });
    document.getElementById('manageOptionsStandaloneModal')?.remove();
    showManageOptionsModalStandalone(groupId, groupName, merchantId);
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function deleteOptionGroup(groupId, merchantId, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast } = _deps();

  if (!confirm('ลบกลุ่มตัวเลือกนี้ทั้งหมด? (รวมตัวเลือกทั้งหมดในกลุ่ม)')) return;
  try {
    await callAdminAction({ action: 'delete_option_group', id: groupId });
    globalThis._addMenuSelectedGroups = globalThis._addMenuSelectedGroups.filter((g) => g.id !== groupId);
    renderAddMenuOptionGroups();
    document.getElementById('addMenuOptionGroupPickerModal')?.remove();
    showAddMenuOptionGroupPicker(merchantId);
    showToast('ลบกลุ่มตัวเลือกสำเร็จ', 'success');
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + e.message, 'error');
  }
}

export function previewMenuImage(input, previewId, ctx) {
  _ctx = ctx || _ctx;

  const preview = document.getElementById(previewId);
  if (!preview) return;
  if (input.files && input.files[0]) {
    const reader = new FileReader();
    reader.onload = (e) => {
      preview.innerHTML = `<img src="${e.target.result}" class="w-16 h-16 rounded-lg object-cover border" />`;
    };
    reader.readAsDataURL(input.files[0]);
  } else {
    preview.innerHTML = '';
  }
}

export async function uploadMenuImage(file, merchantId, ctx) {
  _ctx = ctx || _ctx;
  const { supabase } = _deps();

  const ext = file.name.split('.').pop();
  const fileName = `menu_${merchantId}_${Date.now()}.${ext}`;

  const buckets = ['menu-images', 'admin-uploads'];

  for (const bucket of buckets) {
    const filePath = bucket === 'menu-images' ? fileName : `menu-images/${fileName}`;
    const { error } = await supabase.storage.from(bucket).upload(filePath, file, { cacheControl: '3600', upsert: true });
    if (!error) {
      const { data: urlData } = supabase.storage.from(bucket).getPublicUrl(filePath);
      return urlData.publicUrl;
    }
  }

  try {
    await supabase.storage.createBucket('menu-images', {
      public: true,
      fileSizeLimit: 5242880,
      allowedMimeTypes: ['image/jpeg', 'image/png', 'image/webp', 'image/gif'],
    });
    const { error } = await supabase.storage.from('menu-images').upload(fileName, file, { cacheControl: '3600', upsert: true });
    if (error) throw error;
    const { data: urlData } = supabase.storage.from('menu-images').getPublicUrl(fileName);
    return urlData.publicUrl;
  } catch (e) {
    throw new Error('อัพโหลดรูปไม่สำเร็จ — กรุณาสร้าง Storage Bucket "menu-images" ใน Supabase Dashboard > Storage ก่อน (ตั้งเป็น Public)');
  }
}

export async function submitAddMenu(merchantId, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml } = _deps();

  try {
    let imageUrl = document.getElementById('addMenuImg').value;
    const fileInput = document.getElementById('addMenuFile');
    if (fileInput?.files?.length) {
      imageUrl = await uploadMenuImage(fileInput.files[0], merchantId);
    }
    const optionGroupIds = (globalThis._addMenuSelectedGroups || []).map((g) => g.id);
    await callAdminAction({
      action: 'create_menu_item',
      merchant_id: merchantId,
      item_data: {
        name: document.getElementById('addMenuName').value,
        category: document.getElementById('addMenuCat').value,
        price: parseFloat(document.getElementById('addMenuPrice').value) || 0,
        description: document.getElementById('addMenuDesc').value,
        image_url: imageUrl,
        is_available: true,
      },
      option_group_ids: optionGroupIds,
    });

    document.getElementById('menuFormContainer').innerHTML = '';
    showToast('เพิ่มเมนูสำเร็จ!', 'success');
    loadMerchantMenus();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function editMenuItem(id, ctx) {
  _ctx = ctx || _ctx;
  const { supabase } = _deps();

  const { data: m } = await supabase.from('menu_items').select('*').eq('id', id).single();
  if (!m) return;

  let linkedGroups = [];
  try {
    const { data: links } = await supabase
      .from('menu_item_option_links')
      .select('option_group_id, sort_order, menu_option_groups(id, name, min_selection, max_selection, menu_options(id, name, price, is_available))')
      .eq('menu_item_id', id)
      .order('sort_order');
    linkedGroups = (links || []).map((l) => l.menu_option_groups).filter(Boolean);
  } catch (_) {}

  document.getElementById('editMenuModal')?.remove();

  const modal = document.createElement('div');
  modal.id = 'editMenuModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-2xl mx-4 fade-in max-h-[90vh] flex flex-col">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <div>
          <h3 class="font-bold text-gray-800 text-lg">แก้ไขเมนู</h3>
          <p class="text-xs text-gray-500 mt-0.5">${m.name || 'ไม่มีชื่อ'}</p>
        </div>
        <button onclick="document.getElementById('editMenuModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-6 overflow-y-auto flex-1 space-y-4">
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div><label class="block text-sm font-medium mb-1">ชื่อเมนู</label><input id="editMenuName" value="${(m.name || '').replace(/"/g, '&quot;')}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div><label class="block text-sm font-medium mb-1">หมวดหมู่</label>${categoryDropdownHtml('editMenuCat', m.category || 'อาหารตามสั่ง')}</div>
          <div><label class="block text-sm font-medium mb-1">ราคา (฿)</label><input id="editMenuPrice" type="number" value="${m.price || 0}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div class="md:col-span-2"><label class="block text-sm font-medium mb-1">รายละเอียด</label><input id="editMenuDesc" value="${(m.description || '').replace(/"/g, '&quot;')}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div><label class="flex items-center gap-2 text-sm mt-6"><input type="checkbox" id="editMenuAvail" ${m.is_available !== false ? 'checked' : ''} class="w-4 h-4 rounded" /> พร้อมขาย</label></div>
        </div>

        <div class="border rounded-xl p-4 bg-gray-50">
          <label class="block text-sm font-bold mb-2">รูปภาพเมนู</label>
          <div class="flex items-start gap-4">
            <div id="editMenuPreview" class="flex-shrink-0">${m.image_url ? `<img src="${m.image_url}" class="w-20 h-20 rounded-lg object-cover border" />` : '<div class="w-20 h-20 bg-gray-200 rounded-lg flex items-center justify-center"><span class="material-icons-round text-gray-400">image</span></div>'}</div>
            <div class="flex-1 space-y-2">
              <input id="editMenuImg" value="${m.image_url || ''}" class="w-full border rounded-lg px-3 py-2 text-sm" placeholder="วาง URL รูปภาพ" />
              <input type="file" id="editMenuFile" accept="image/*" class="w-full border rounded-lg px-3 py-1.5 text-sm file:mr-2 file:py-1 file:px-3 file:rounded-lg file:border-0 file:text-sm file:bg-indigo-100 file:text-indigo-700 hover:file:bg-indigo-200" onchange="previewMenuImage(this,'editMenuPreview')" />
            </div>
          </div>
        </div>

        <div class="border rounded-xl p-4">
          <div class="flex items-center justify-between mb-3">
            <h5 class="font-bold text-gray-700 text-sm flex items-center gap-2"><span class="material-icons-round text-sm">tune</span> ตัวเลือกเมนู</h5>
            <button onclick="showLinkOptionGroupModal('${id}','${m.merchant_id}')" class="px-3 py-1 bg-green-500 text-white rounded-lg text-xs font-medium hover:bg-green-600 flex items-center gap-1"><span class="material-icons-round text-xs">add</span> เพิ่มตัวเลือก</button>
          </div>
          <div id="menuOptionGroupsList">
            ${linkedGroups.length === 0 ? '<p class="text-gray-400 text-sm py-2">ยังไม่มีตัวเลือก</p>' : linkedGroups
              .map(
                (g) => `
                <div class="border rounded-lg p-3 mb-2">
                  <div class="flex items-center justify-between">
                    <div>
                      <span class="font-medium text-sm">${g.name}</span>
                      <span class="text-xs text-gray-500 ml-2">(เลือก ${g.min_selection}-${g.max_selection} รายการ)</span>
                    </div>
                    <button onclick="unlinkOptionGroupFromMenu('${id}','${g.id}')" class="text-red-500 hover:text-red-700 text-xs">ลบออก</button>
                  </div>
                  ${(g.menu_options || []).length > 0 ? `<div class="mt-2 flex flex-wrap gap-2">${(g.menu_options || []).map((o) => `<span class="px-2 py-1 bg-gray-100 rounded text-xs ${o.is_available ? '' : 'line-through text-gray-400'}">${o.name}${o.price > 0 ? ' +฿' + o.price : ''}</span>`).join('')}</div>` : ''}
                </div>
              `,
              )
              .join('')}
          </div>
        </div>
      </div>
      <div class="px-6 py-4 border-t border-gray-100 flex gap-2 justify-end">
        <button onclick="document.getElementById('editMenuModal')?.remove()" class="px-4 py-2 bg-gray-100 text-gray-600 rounded-lg text-sm font-medium hover:bg-gray-200">ยกเลิก</button>
        <button onclick="submitEditMenu('${id}','${m.merchant_id}')" class="px-5 py-2 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">บันทึก</button>
      </div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => {
    if (e.target === modal) modal.remove();
  });
}

export async function submitEditMenu(id, merchantId, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml } = _deps();

  try {
    let imageUrl = document.getElementById('editMenuImg').value;
    const fileInput = document.getElementById('editMenuFile');
    if (fileInput?.files?.length) {
      imageUrl = await uploadMenuImage(fileInput.files[0], merchantId || 'unknown');
    }
    await callAdminAction({
      action: 'update_menu_item',
      id,
      update_data: {
        name: document.getElementById('editMenuName').value,
        category: document.getElementById('editMenuCat').value,
        price: parseFloat(document.getElementById('editMenuPrice').value) || 0,
        description: document.getElementById('editMenuDesc').value,
        image_url: imageUrl,
        is_available: document.getElementById('editMenuAvail').checked,
      },
    });
    document.getElementById('editMenuModal')?.remove();
    showToast('บันทึกเมนูสำเร็จ!', 'success');
    loadMerchantMenus();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function unlinkOptionGroupFromMenu(menuItemId, groupId, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml } = _deps();

  if (!confirm('ลบกลุ่มตัวเลือกนี้ออกจากเมนู?')) return;
  try {
    await callAdminAction({ action: 'unlink_option_group', menu_item_id: menuItemId, option_group_id: groupId });
    editMenuItem(menuItemId);
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function showLinkOptionGroupModal(menuItemId, merchantId, ctx) {
  _ctx = ctx || _ctx;
  const { supabase } = _deps();

  const { data: groups } = await supabase
    .from('menu_option_groups')
    .select('*, menu_options(*)')
    .eq('merchant_id', merchantId)
    .order('name');
  const { data: links } = await supabase.from('menu_item_option_links').select('option_group_id').eq('menu_item_id', menuItemId);
  const linkedIds = new Set((links || []).map((l) => l.option_group_id));

  const modal = document.createElement('div');
  modal.id = 'optionGroupModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-2xl mx-4 fade-in max-h-[80vh] flex flex-col">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <h3 class="font-bold text-gray-800 text-lg">จัดการกลุ่มตัวเลือก</h3>
        <button onclick="document.getElementById('optionGroupModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-6 overflow-y-auto flex-1">
        <div class="bg-blue-50 rounded-xl p-4 mb-4">
          <h4 class="font-bold text-sm text-blue-800 mb-3">สร้างกลุ่มตัวเลือกใหม่</h4>
          <div class="grid grid-cols-1 md:grid-cols-3 gap-3">
            <div><input id="newGroupName" placeholder="ชื่อกลุ่ม เช่น ระดับความเผ็ด" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
            <div class="flex gap-2">
              <input id="newGroupMin" type="number" value="0" min="0" placeholder="เลือกขั้นต่ำ" class="w-full border rounded-lg px-3 py-2 text-sm" />
              <input id="newGroupMax" type="number" value="1" min="1" placeholder="เลือกสูงสุด" class="w-full border rounded-lg px-3 py-2 text-sm" />
            </div>
            <div><button onclick="createOptionGroupAndLink('${menuItemId}','${merchantId}')" class="w-full px-4 py-2 bg-blue-600 text-white rounded-lg text-sm font-medium hover:bg-blue-700">สร้างและเพิ่ม</button></div>
          </div>
        </div>

        <h4 class="font-bold text-sm text-gray-700 mb-2">กลุ่มตัวเลือกที่มีอยู่ (คลิกเพื่อเพิ่ม/เอาออก)</h4>
        ${!groups || groups.length === 0 ? '<p class="text-gray-400 text-sm">ยังไม่มีกลุ่มตัวเลือก</p>' : groups
          .map((g) => {
            const isLinked = linkedIds.has(g.id);
            return `
            <div class="border rounded-lg p-3 mb-2 ${isLinked ? 'bg-green-50 border-green-200' : ''}">
              <div class="flex items-center justify-between">
                <div>
                  <span class="font-medium text-sm">${g.name}</span>
                  <span class="text-xs text-gray-500 ml-2">(${g.min_selection}-${g.max_selection})</span>
                  ${(g.menu_options || []).length > 0 ? `<div class="mt-1 flex flex-wrap gap-1">${(g.menu_options || []).map((o) => `<span class="px-1.5 py-0.5 bg-gray-100 rounded text-xs">${o.name}${o.price > 0 ? ' +฿' + o.price : ''}</span>`).join('')}</div>` : ''}
                </div>
                <div class="flex items-center gap-2">
                  <button onclick="showManageOptionsModal('${g.id}','${g.name}','${merchantId}','${menuItemId}')" class="px-2 py-1 bg-gray-100 text-gray-600 rounded text-xs hover:bg-gray-200">แก้ไขตัวเลือก</button>
                  ${isLinked ? `<button onclick=\"toggleLinkGroup('${menuItemId}','${g.id}',false)\" class=\"px-3 py-1 bg-red-100 text-red-600 rounded-lg text-xs font-medium hover:bg-red-200\">เอาออก</button>` : `<button onclick=\"toggleLinkGroup('${menuItemId}','${g.id}',true)\" class=\"px-3 py-1 bg-green-500 text-white rounded-lg text-xs font-medium hover:bg-green-600\">เพิ่ม</button>`}
                </div>
              </div>
            </div>`;
          })
          .join('')}
      </div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => {
    if (e.target === modal) modal.remove();
  });
}

export async function createOptionGroupAndLink(menuItemId, merchantId, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml } = _deps();

  const name = document.getElementById('newGroupName')?.value?.trim();
  const min = parseInt(document.getElementById('newGroupMin')?.value) || 0;
  const max = parseInt(document.getElementById('newGroupMax')?.value) || 1;
  if (!name) return alert('กรุณากรอกชื่อกลุ่ม');
  try {
    await callAdminAction({ action: 'create_option_group_and_link', merchant_id: merchantId, menu_item_id: menuItemId, name, min_selection: min, max_selection: max });
    document.getElementById('optionGroupModal')?.remove();
    editMenuItem(menuItemId);
    showToast('สร้างกลุ่มตัวเลือกสำเร็จ!', 'success');
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function toggleLinkGroup(menuItemId, groupId, link, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml } = _deps();

  try {
    await callAdminAction({ action: 'toggle_link_group', menu_item_id: menuItemId, option_group_id: groupId, link });
    document.getElementById('optionGroupModal')?.remove();
    showLinkOptionGroupModal(menuItemId, document.getElementById('menuMerchantSelect')?.value || '');
    editMenuItem(menuItemId);
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function showManageOptionsModal(groupId, groupName, merchantId, menuItemId, ctx) {
  _ctx = ctx || _ctx;
  const { supabase } = _deps();

  const { data: options } = await supabase.from('menu_options').select('*').eq('group_id', groupId).order('name');

  const modal = document.createElement('div');
  modal.id = 'manageOptionsModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-[60]';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 fade-in">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <h3 class="font-bold text-gray-800">ตัวเลือกใน "${groupName}"</h3>
        <button onclick="document.getElementById('manageOptionsModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-6">
        <div class="flex gap-2 mb-4">
          <input id="newOptName" placeholder="ชื่อตัวเลือก" class="flex-1 border rounded-lg px-3 py-2 text-sm" />
          <input id="newOptPrice" type="number" value="0" placeholder="ราคาเพิ่ม" class="w-24 border rounded-lg px-3 py-2 text-sm" />
          <button onclick="addMenuOption('${groupId}','${groupName}','${merchantId}','${menuItemId}')" class="px-4 py-2 bg-green-500 text-white rounded-lg text-sm font-medium hover:bg-green-600">เพิ่ม</button>
        </div>
        <div id="optionsList">
          ${(options || []).length === 0 ? '<p class="text-gray-400 text-sm">ยังไม่มีตัวเลือก</p>' : (options || []).map((o) => `
              <div class="flex items-center justify-between py-2 border-b border-gray-50">
                <div class="flex items-center gap-3">
                  <span class="text-sm font-medium ${o.is_available ? '' : 'line-through text-gray-400'}">${o.name}</span>
                  ${o.price > 0 ? `<span class="text-xs text-green-600 font-semibold">+฿${o.price}</span>` : ''}
                </div>
                <div class="flex items-center gap-2">
                  <button onclick="toggleOptionAvail('${o.id}',${!o.is_available},'${groupId}','${groupName}','${merchantId}','${menuItemId}')" class="text-xs ${o.is_available ? 'text-orange-500' : 'text-green-500'} hover:underline">${o.is_available ? 'ปิด' : 'เปิด'}</button>
                  <button onclick="deleteMenuOption('${o.id}','${groupId}','${groupName}','${merchantId}','${menuItemId}')" class="text-xs text-red-500 hover:underline">ลบ</button>
                </div>
              </div>
            `).join('')}
        </div>
      </div>
    </div>`;
  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => {
    if (e.target === modal) modal.remove();
  });
}

export async function addMenuOption(groupId, groupName, merchantId, menuItemId, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml } = _deps();

  const name = document.getElementById('newOptName')?.value?.trim();
  const price = parseInt(document.getElementById('newOptPrice')?.value) || 0;
  if (!name) return alert('กรุณากรอกชื่อตัวเลือก');
  try {
    await callAdminAction({ action: 'create_menu_option', group_id: groupId, name, price, is_available: true });
    document.getElementById('manageOptionsModal')?.remove();
    showManageOptionsModal(groupId, groupName, merchantId, menuItemId);
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function toggleOptionAvail(optionId, newState, groupId, groupName, merchantId, menuItemId, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml } = _deps();

  try {
    await callAdminAction({ action: 'update_menu_option', id: optionId, update_data: { is_available: newState } });
    document.getElementById('manageOptionsModal')?.remove();
    showManageOptionsModal(groupId, groupName, merchantId, menuItemId);
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function deleteMenuOption(optionId, groupId, groupName, merchantId, menuItemId, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml } = _deps();

  if (!confirm('ลบตัวเลือกนี้?')) return;
  try {
    await callAdminAction({ action: 'delete_menu_option', id: optionId });
    document.getElementById('manageOptionsModal')?.remove();
    showManageOptionsModal(groupId, groupName, merchantId, menuItemId);
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function deleteMenuItem(id, name, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml } = _deps();

  if (!confirm(`ลบเมนู "${escapeHtml(name)}" ?`)) return;
  try {
    await callAdminAction({ action: 'delete_menu_item', id });
    showToast('ลบสำเร็จ!', 'success');
    loadMerchantMenus();
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export function wireMenusBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  globalThis.__adminWebBridge.renderMenusPage = renderMenusPage;
  globalThis.__adminWebBridge.loadMerchantMenus = loadMerchantMenus;
  globalThis.__adminWebBridge.renderMenuRows = renderMenuRows;
  globalThis.__adminWebBridge.filterMerchantMenus = filterMerchantMenus;
  globalThis.__adminWebBridge.showAddMenuForm = showAddMenuForm;
  globalThis.__adminWebBridge.showAddMenuOptionGroupPicker = showAddMenuOptionGroupPicker;
  globalThis.__adminWebBridge.createOptionGroupForAddMenu = createOptionGroupForAddMenu;
  globalThis.__adminWebBridge.toggleAddMenuGroup = toggleAddMenuGroup;
  globalThis.__adminWebBridge.renderAddMenuOptionGroups = renderAddMenuOptionGroups;
  globalThis.__adminWebBridge.showManageOptionsModalStandalone = showManageOptionsModalStandalone;
  globalThis.__adminWebBridge.addMenuOptionStandalone = addMenuOptionStandalone;
  globalThis.__adminWebBridge.toggleOptSA = toggleOptSA;
  globalThis.__adminWebBridge.deleteOptSA = deleteOptSA;
  globalThis.__adminWebBridge.deleteOptionGroup = deleteOptionGroup;
  globalThis.__adminWebBridge.previewMenuImage = previewMenuImage;
  globalThis.__adminWebBridge.uploadMenuImage = uploadMenuImage;
  globalThis.__adminWebBridge.submitAddMenu = submitAddMenu;
  globalThis.__adminWebBridge.editMenuItem = editMenuItem;
  globalThis.__adminWebBridge.submitEditMenu = submitEditMenu;
  globalThis.__adminWebBridge.unlinkOptionGroupFromMenu = unlinkOptionGroupFromMenu;
  globalThis.__adminWebBridge.showLinkOptionGroupModal = showLinkOptionGroupModal;
  globalThis.__adminWebBridge.createOptionGroupAndLink = createOptionGroupAndLink;
  globalThis.__adminWebBridge.toggleLinkGroup = toggleLinkGroup;
  globalThis.__adminWebBridge.showManageOptionsModal = showManageOptionsModal;
  globalThis.__adminWebBridge.addMenuOption = addMenuOption;
  globalThis.__adminWebBridge.toggleOptionAvail = toggleOptionAvail;
  globalThis.__adminWebBridge.deleteMenuOption = deleteMenuOption;
  globalThis.__adminWebBridge.deleteMenuItem = deleteMenuItem;
}
