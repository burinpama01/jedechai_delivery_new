let _ctx = null;

function _deps() {
  const supabase = _ctx?.supabase || globalThis.supabase;
  const fmt = _ctx?.fmt || globalThis.fmt;
  const fmtDate = _ctx?.fmtDate || globalThis.fmtDate;
  const statCard = _ctx?.statCard || globalThis.statCard;
  const escapeHtml = _ctx?.escapeHtml || globalThis.escapeHtml;
  const showToast = _ctx?.showToast || globalThis.showToast;
  const callAdminAction = _ctx?.callAdminAction || globalThis.callAdminAction;

  const fetchUserEmails = _ctx?.fetchUserEmails || globalThis.fetchUserEmails;
  const statusBadge = _ctx?.statusBadge || globalThis.statusBadge;
  const onlineBadge = _ctx?.onlineBadge || globalThis.onlineBadge;
  const truthyFlag = _ctx?._truthyFlag || globalThis._truthyFlag;

  const uploadProfileImageField = _ctx?.uploadProfileImageField || globalThis.uploadProfileImageField;
  const patchProfileInLocalCaches = _ctx?._patchProfileInLocalCaches || globalThis._patchProfileInLocalCaches;
  const rerenderCurrentManagementRows = _ctx?._rerenderCurrentManagementRows || globalThis._rerenderCurrentManagementRows;

  return {
    supabase,
    fmt,
    fmtDate,
    statCard,
    escapeHtml,
    showToast,
    callAdminAction,
    fetchUserEmails,
    statusBadge,
    onlineBadge,
    truthyFlag,
    uploadProfileImageField,
    patchProfileInLocalCaches,
    rerenderCurrentManagementRows,
  };
}

export async function setUserOnlineStatus(id, isOnline, role = '', ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml, refreshCurrentPage } = {
    ..._deps(),
    refreshCurrentPage: _ctx?.refreshCurrentPage || globalThis.refreshCurrentPage,
  };

  try {
    await callAdminAction({ action: 'set_online_status', id, is_online: !!isOnline, role });
    showToast(isOnline ? 'ตั้งสถานะออนไลน์แล้ว' : 'ตั้งสถานะออฟไลน์แล้ว', 'success');
    if (typeof refreshCurrentPage === 'function') refreshCurrentPage();
  } catch (e) {
    showToast('อัปเดตสถานะออนไลน์ไม่สำเร็จ: ' + escapeHtml(e.message || JSON.stringify(e)), 'error');
  }
}

export async function suspendUser(id, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml, patchProfileInLocalCaches, rerenderCurrentManagementRows } = _deps();

  const reason = prompt('เหตุผลที่ระงับบัญชี:');
  if (!reason) return;
  try {
    await callAdminAction({ action: 'suspend_user', id, reason });
    const patch = { approval_status: 'suspended', rejection_reason: reason, updated_at: new Date().toISOString() };
    if (typeof patchProfileInLocalCaches === 'function') patchProfileInLocalCaches(id, patch);
    if (typeof rerenderCurrentManagementRows === 'function') rerenderCurrentManagementRows();
    showToast('ระงับบัญชีแล้ว', 'info');
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message), 'error');
  }
}

export async function renderUsersPage(el, ctx) {
  _ctx = ctx || null;
  const { supabase, statCard, fmt, fetchUserEmails } = _deps();

  await Promise.all([
    supabase.from('profiles').select('*').order('created_at', { ascending: false }).limit(200),
    typeof fetchUserEmails === 'function' ? fetchUserEmails() : Promise.resolve(null),
  ]).then(([{ data: users }]) => {
    const counts = { customer: 0, driver: 0, merchant: 0, admin: 0 };
    (users || []).forEach((u) => {
      if (counts[u.role] !== undefined) counts[u.role] += 1;
    });

    el.innerHTML = `
      <div class="fade-in space-y-5">
        <div class="grid grid-cols-2 md:grid-cols-4 gap-5">
          ${statCard('people', 'ทั้งหมด', fmt((users || []).length), 'bg-indigo-500')}
          ${statCard('person', 'ลูกค้า', fmt(counts.customer), 'bg-blue-500')}
          ${statCard('directions_car', 'คนขับ', fmt(counts.driver), 'bg-green-500')}
          ${statCard('store', 'ร้านค้า', fmt(counts.merchant), 'bg-orange-500')}
        </div>
        <div class="glass-card overflow-hidden">
          <div class="px-6 py-4 flex items-center gap-3">
            <span class="material-icons-round text-indigo-400">search</span>
            <input type="text" id="userSearch" placeholder="ค้นหาชื่อ, อีเมล..." class="text-sm border border-gray-200 rounded-xl px-3.5 py-2 flex-1 bg-gray-50/50 transition-all" oninput="filterUsers()">
            <select id="userRoleFilter" onchange="filterUsers()" class="text-sm border border-gray-200 rounded-xl px-3.5 py-2 bg-gray-50/50 transition-all">
              <option value="">ทุกบทบาท</option>
              <option value="customer">ลูกค้า</option>
              <option value="driver">คนขับ</option>
              <option value="merchant">ร้านค้า</option>
              <option value="admin">แอดมิน</option>
            </select>
          </div>
          <div class="overflow-x-auto">
            <table class="w-full text-sm">
              <thead><tr class="bg-gray-50/80">
                <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ชื่อ</th>
                <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">อีเมล</th>
                <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">เบอร์โทร</th>
                <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">บทบาท</th>
                <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">สถานะ</th>
                <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">ออนไลน์</th>
                <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">สมัครเมื่อ</th>
                <th class="px-5 py-3 text-left text-xs font-semibold text-gray-400 uppercase tracking-wider">จัดการ</th>
              </tr></thead>
              <tbody id="usersTableBody" class="divide-y divide-gray-100">
                ${renderUserRows(users || [])}
              </tbody>
            </table>
          </div>
        </div>
      </div>
    `;

    globalThis._allUsers = users || [];
  });

  globalThis.renderUserRows = renderUserRows;
  globalThis.filterUsers = filterUsers;
  globalThis.editUserProfile = editUserProfile;
  globalThis.submitEditUser = submitEditUser;
  globalThis.uploadUserAvatar = uploadUserAvatar;
}

export function renderUserRows(users, ctx) {
  _ctx = ctx || _ctx;
  const { escapeHtml, statusBadge, onlineBadge, fmtDate, truthyFlag } = _deps();

  if (!users.length) return '<tr><td colspan="8" class="px-4 py-8 text-center text-gray-400">ไม่มีข้อมูล</td></tr>';
  const roleMap = { customer: 'ลูกค้า', driver: 'คนขับ', merchant: 'ร้านค้า', admin: 'แอดมิน' };
  const roleColor = { customer: 'blue', driver: 'green', merchant: 'orange', admin: 'purple' };

  return users
    .map((u) => {
      const isOnline = typeof truthyFlag === 'function' ? truthyFlag(u.is_online) : !!u.is_online;
      return `
        <tr class="table-row border-b border-gray-50">
          <td class="px-4 py-3 font-medium">${escapeHtml(u.full_name) || '-'}</td>
          <td class="px-4 py-3 text-xs text-gray-500">${escapeHtml(globalThis._emailMap?.[u.id]) || '-'}</td>
          <td class="px-4 py-3">${escapeHtml(u.phone_number) || '-'}</td>
          <td class="px-4 py-3"><span class="px-2 py-1 rounded-full text-xs font-semibold bg-${roleColor[u.role] || 'gray'}-100 text-${roleColor[u.role] || 'gray'}-700">${roleMap[u.role] || u.role}</span></td>
          <td class="px-4 py-3">${statusBadge(u.approval_status || 'approved')}</td>
          <td class="px-4 py-3">${onlineBadge(isOnline)}</td>
          <td class="px-4 py-3 text-gray-500 text-xs">${fmtDate(u.created_at)}</td>
          <td class="px-4 py-3">
            ${u.role !== 'admin'
              ? `
                <button onclick="setUserOnlineStatus('${u.id}', ${isOnline ? 'false' : 'true'}, '${u.role || ''}')" class="px-3 py-1 ${isOnline ? 'bg-orange-100 text-orange-700 hover:bg-orange-200' : 'bg-emerald-100 text-emerald-700 hover:bg-emerald-200'} rounded-lg text-xs font-medium mr-1">${isOnline ? 'ออฟไลน์' : 'ออนไลน์'}</button>
                <button onclick="editUserProfile('${u.id}')" class="px-3 py-1 bg-blue-500 text-white rounded-lg text-xs font-medium hover:bg-blue-600 mr-1">แก้ไข</button>
                <button onclick="suspendUser('${u.id}')" class="px-3 py-1 bg-gray-100 text-gray-600 rounded-lg text-xs font-medium hover:bg-gray-200 mr-1">ระงับ</button>
                <button onclick="deleteUser('${u.id}','${escapeHtml((u.full_name || '').replace(/'/g, ''))}')" class="px-3 py-1 bg-red-100 text-red-600 rounded-lg text-xs font-medium hover:bg-red-200">ลบ</button>
              `
              : '<span class="text-gray-300 text-xs">-</span>'}
          </td>
        </tr>
      `;
    })
    .join('');
}

export async function editUserProfile(id, ctx) {
  _ctx = ctx || _ctx;
  const { supabase, escapeHtml, truthyFlag } = _deps();

  const { data: u } = await supabase.from('profiles').select('*').eq('id', id).single();
  if (!u) return;

  document.getElementById('editUserModal')?.remove();
  const modal = document.createElement('div');
  modal.id = 'editUserModal';
  modal.className = 'fixed inset-0 bg-black/50 flex items-center justify-center z-50';
  modal.innerHTML = `
    <div class="bg-white rounded-2xl shadow-2xl w-full max-w-lg mx-4 fade-in max-h-[90vh] flex flex-col">
      <div class="px-6 py-4 border-b border-gray-100 flex items-center justify-between">
        <div>
          <h3 class="font-bold text-gray-800 text-lg">แก้ไขข้อมูลผู้ใช้</h3>
          <p class="text-xs text-gray-500">${escapeHtml(u.full_name) || '-'} • ${escapeHtml(u.role) || '-'}</p>
        </div>
        <button onclick="document.getElementById('editUserModal')?.remove()" class="text-gray-400 hover:text-gray-600"><span class="material-icons-round">close</span></button>
      </div>
      <div class="p-6 overflow-y-auto flex-1 space-y-4">
        <div class="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div><label class="block text-sm font-medium mb-1">ชื่อ-นามสกุล</label><input id="editUsrName" value="${(u.full_name || '').replace(/"/g, '&quot;')}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div><label class="block text-sm font-medium mb-1">เบอร์โทร</label><input id="editUsrPhone" value="${escapeHtml(u.phone_number)}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div><label class="block text-sm font-medium mb-1">ประเภทผู้ใช้</label>
            <select id="editUsrRole" class="w-full border rounded-lg px-3 py-2 text-sm" ${u.role === 'admin' ? 'disabled' : ''}>
              <option value="customer" ${u.role === 'customer' ? 'selected' : ''}>ลูกค้า</option>
              <option value="driver" ${u.role === 'driver' ? 'selected' : ''}>คนขับ</option>
              <option value="merchant" ${u.role === 'merchant' ? 'selected' : ''}>ร้านค้า</option>
              ${u.role === 'admin' ? '<option value="admin" selected>แอดมิน</option>' : ''}
            </select>
            <input type="hidden" id="editUsrOriginalRole" value="${u.role || ''}">
          </div>
          <div><label class="block text-sm font-medium mb-1">สถานะบัญชี</label>
            <select id="editUsrStatus" class="w-full border rounded-lg px-3 py-2 text-sm">
              <option value="approved" ${u.approval_status === 'approved' ? 'selected' : ''}>อนุมัติ</option>
              <option value="pending" ${u.approval_status === 'pending' ? 'selected' : ''}>รอ</option>
              <option value="suspended" ${u.approval_status === 'suspended' ? 'selected' : ''}>ระงับ</option>
              <option value="rejected" ${u.approval_status === 'rejected' ? 'selected' : ''}>ปฏิเสธ</option>
            </select>
          </div>
          <div><label class="block text-sm font-medium mb-1">ออนไลน์</label>
            <select id="editUsrOnline" class="w-full border rounded-lg px-3 py-2 text-sm">
              <option value="1" ${(typeof truthyFlag === 'function' ? truthyFlag(u.is_online) : !!u.is_online) ? 'selected' : ''}>ออนไลน์</option>
              <option value="0" ${(typeof truthyFlag === 'function' ? truthyFlag(u.is_online) : !!u.is_online) ? '' : 'selected'}>ออฟไลน์</option>
            </select>
          </div>
          <div class="md:col-span-2"><label class="block text-sm font-medium mb-1">ที่อยู่ร้าน (สำหรับร้านค้า)</label><input id="editUsrShopAddr" value="${(u.shop_address || '').replace(/"/g, '&quot;')}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div><label class="block text-sm font-medium mb-1">ทะเบียนรถ (สำหรับคนขับ)</label><input id="editUsrPlate" value="${(u.license_plate || '').replace(/"/g, '&quot;')}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
          <div><label class="block text-sm font-medium mb-1">ประเภทรถ (สำหรับคนขับ)</label><input id="editUsrVehicle" value="${(u.vehicle_type || '').replace(/"/g, '&quot;')}" class="w-full border rounded-lg px-3 py-2 text-sm" /></div>
        </div>

        <div class="border-t pt-4">
          <p class="text-sm font-bold mb-2">รูปโปรไฟล์</p>
          <div class="flex items-center gap-3">
            ${u.avatar_url ? `<img src="${u.avatar_url}" class="w-12 h-12 rounded-lg object-cover border" onerror="this.style.display='none'" />` : '<div class="w-12 h-12 rounded-lg bg-gray-200 flex items-center justify-center"><span class="material-icons-round text-gray-400 text-sm">person</span></div>'}
            <label class="px-2.5 py-1.5 bg-blue-500 text-white rounded text-xs cursor-pointer hover:bg-blue-600">
              อัปโหลด<input type="file" accept="image/*" class="hidden" onchange="uploadUserAvatar('${id}',this)" />
            </label>
          </div>
        </div>
      </div>
      <div class="px-6 py-4 border-t border-gray-100 flex gap-2 justify-end">
        <button onclick="document.getElementById('editUserModal')?.remove()" class="px-4 py-2 bg-gray-100 text-gray-600 rounded-lg text-sm font-medium hover:bg-gray-200">ยกเลิก</button>
        <button onclick="submitEditUser('${id}')" class="px-5 py-2 text-white rounded-xl text-sm font-semibold hover:opacity-90 transition-all shadow-md shadow-indigo-200" style="background:linear-gradient(135deg,#6366f1,#818cf8);">บันทึก</button>
      </div>
    </div>`;

  document.body.appendChild(modal);
  modal.addEventListener('click', (e) => {
    if (e.target === modal) modal.remove();
  });
}

export async function uploadUserAvatar(userId, input, ctx) {
  _ctx = ctx || _ctx;
  const { uploadProfileImageField, showToast } = _deps();

  try {
    await uploadProfileImageField(userId, 'avatar_url', input, 'profiles');
    showToast('อัปโหลดรูปโปรไฟล์สำเร็จ!', 'success');
    await editUserProfile(userId);
  } catch (e) {
    showToast('อัปโหลดรูปไม่สำเร็จ: ' + (e.message || JSON.stringify(e)), 'error');
  }
}

export async function submitEditUser(id, ctx) {
  _ctx = ctx || _ctx;
  const { callAdminAction, showToast, escapeHtml, patchProfileInLocalCaches, rerenderCurrentManagementRows } = _deps();

  try {
    const originalRole = document.getElementById('editUsrOriginalRole')?.value || 'customer';
    const nextRole = document.getElementById('editUsrRole')?.value || originalRole;
    const updateData = {
      full_name: document.getElementById('editUsrName')?.value || '',
      phone_number: document.getElementById('editUsrPhone')?.value || '',
      approval_status: document.getElementById('editUsrStatus')?.value || 'approved',
      is_online: document.getElementById('editUsrOnline')?.value === '1',
      role: nextRole,
      updated_at: new Date().toISOString(),
    };

    if (nextRole === 'merchant') {
      updateData.shop_address = document.getElementById('editUsrShopAddr')?.value || '';
    } else {
      updateData.shop_address = null;
    }

    if (nextRole === 'driver') {
      updateData.license_plate = document.getElementById('editUsrPlate')?.value || '';
      updateData.vehicle_type = document.getElementById('editUsrVehicle')?.value || '';
    } else {
      updateData.license_plate = null;
      updateData.vehicle_type = null;
    }

    await callAdminAction({ action: 'edit_user', id, update_data: updateData, original_role: originalRole });

    if (typeof patchProfileInLocalCaches === 'function') patchProfileInLocalCaches(id, updateData);
    if (typeof rerenderCurrentManagementRows === 'function') rerenderCurrentManagementRows();

    document.getElementById('editUserModal')?.remove();
    showToast('บันทึกข้อมูลผู้ใช้สำเร็จ!', 'success');
  } catch (e) {
    showToast('เกิดข้อผิดพลาด: ' + escapeHtml(e.message || JSON.stringify(e)), 'error');
  }
}

export function filterUsers(ctx) {
  _ctx = ctx || _ctx;
  const search = (document.getElementById('userSearch')?.value || '').toLowerCase();
  const role = document.getElementById('userRoleFilter')?.value || '';
  let filtered = globalThis._allUsers || [];
  if (role) filtered = filtered.filter((u) => u.role === role);
  if (search) {
    filtered = filtered.filter(
      (u) =>
        (u.full_name || '').toLowerCase().includes(search) ||
        (u.phone_number || '').includes(search) ||
        (globalThis._emailMap?.[u.id] || '').toLowerCase().includes(search),
    );
  }
  const body = document.getElementById('usersTableBody');
  if (body) body.innerHTML = renderUserRows(filtered);
}

export function wireUsersBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  globalThis.__adminWebBridge.renderUsersPage = renderUsersPage;
  globalThis.__adminWebBridge.renderUserRows = renderUserRows;
  globalThis.__adminWebBridge.filterUsers = filterUsers;
  globalThis.__adminWebBridge.editUserProfile = editUserProfile;
  globalThis.__adminWebBridge.submitEditUser = submitEditUser;
  globalThis.__adminWebBridge.uploadUserAvatar = uploadUserAvatar;
  globalThis.__adminWebBridge.setUserOnlineStatus = setUserOnlineStatus;
  globalThis.__adminWebBridge.suspendUser = suspendUser;
}
