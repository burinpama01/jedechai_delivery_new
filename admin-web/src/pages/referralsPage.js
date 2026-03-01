let _ctx = null;

function _deps() {
  const supabase = _ctx?.supabase || globalThis.supabase;
  const escapeHtml = _ctx?.escapeHtml || globalThis.escapeHtml;
  const showToast = _ctx?.showToast || globalThis.showToast;
  const refreshCurrentPage = _ctx?.refreshCurrentPage || globalThis.refreshCurrentPage;
  return { supabase, escapeHtml, showToast, refreshCurrentPage };
}

export async function renderReferralsPage(el, ctx) {
  _ctx = ctx || null;
  el.innerHTML = `
    <div class="fade-in space-y-6">
      <div class="glass-card p-5 flex flex-col md:flex-row md:items-center md:justify-between gap-3">
        <div>
          <h1 class="text-2xl md:text-3xl text-gray-800 font-extrabold tracking-tight">ระบบชวนเพื่อน (Referrals) ✨</h1>
          <p class="text-xs text-gray-400 mt-1">ตรวจสอบและจัดการสถานะการชวนเพื่อน</p>
        </div>
        <div class="flex items-center gap-2">
          <button onclick="refreshReferrals()" class="px-4 py-2 rounded-xl text-sm font-semibold text-white shadow-md shadow-indigo-200 hover:opacity-90 transition-all" style="background:linear-gradient(135deg,#6366f1,#818cf8);">
            <span class="material-icons-round text-[18px] align-middle">refresh</span>
            <span class="ml-1">รีเฟรช</span>
          </button>
        </div>
      </div>

      <div class="glass-card p-5">
        <div class="grid grid-cols-1 md:grid-cols-12 gap-3">
          <div class="md:col-span-6">
            <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">ค้นหา</label>
            <input id="referral-search" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50 transition-all" type="text" placeholder="ค้นหา รหัส, ผู้ชวน, ผู้สมัคร..." onkeyup="if(event.key === 'Enter') filterReferrals()">
          </div>
          <div class="md:col-span-4">
            <label class="block text-xs font-semibold text-gray-400 mb-1 uppercase tracking-wider">สถานะ</label>
            <select id="referral-status-filter" class="w-full px-3.5 py-2 border border-gray-200 rounded-xl text-sm bg-gray-50/50 transition-all" onchange="filterReferrals()">
              <option value="">ทุกสถานะ</option>
              <option value="pending">รอการตรวจสอบ</option>
              <option value="qualified">สำเร็จ</option>
              <option value="revoked">เพิกถอน</option>
            </select>
          </div>
          <div class="md:col-span-2 flex items-end">
            <button onclick="filterReferrals()" class="w-full px-4 py-2 rounded-xl text-sm font-semibold bg-white text-gray-600 border border-gray-200 hover:bg-gray-50 transition-colors">ค้นหา</button>
          </div>
        </div>
      </div>

      <div class="glass-card p-0 overflow-hidden">
        <div class="px-5 py-4 border-b border-gray-100 flex items-center justify-between">
          <div class="flex items-center gap-3">
            <div class="w-9 h-9 bg-violet-50 rounded-xl flex items-center justify-center"><span class="material-icons-round text-violet-500 text-lg">list</span></div>
            <h2 class="font-bold text-gray-800">รายการชวนเพื่อนทั้งหมด</h2>
          </div>
          <div class="text-sm text-gray-400 font-semibold"><span id="referrals-count">0</span> รายการ</div>
        </div>

        <div class="overflow-x-auto">
          <table class="table-auto w-full">
            <thead class="text-xs font-semibold uppercase text-gray-500 bg-gray-50 border-t border-b border-gray-200">
              <tr>
                <th class="px-2 first:pl-5 last:pr-5 py-3 whitespace-nowrap"><div class="font-semibold text-left">วันที่</div></th>
                <th class="px-2 first:pl-5 last:pr-5 py-3 whitespace-nowrap"><div class="font-semibold text-left">รหัสชวนเพื่อน</div></th>
                <th class="px-2 first:pl-5 last:pr-5 py-3 whitespace-nowrap"><div class="font-semibold text-left">ผู้ชวน</div></th>
                <th class="px-2 first:pl-5 last:pr-5 py-3 whitespace-nowrap"><div class="font-semibold text-left">ผู้สมัครใหม่</div></th>
                <th class="px-2 first:pl-5 last:pr-5 py-3 whitespace-nowrap"><div class="font-semibold text-center">สถานะ</div></th>
                <th class="px-2 first:pl-5 last:pr-5 py-3 whitespace-nowrap"><div class="font-semibold text-center">การจัดการ</div></th>
              </tr>
            </thead>
            <tbody id="referrals-tbody" class="text-sm divide-y divide-gray-100">
              <tr><td colspan="6" class="px-2 py-4 text-center text-gray-400">กำลังโหลดข้อมูล...</td></tr>
            </tbody>
          </table>
        </div>
      </div>
    </div>
  `;

  await filterReferrals();
}

export async function filterReferrals() {
  const { supabase, escapeHtml } = _deps();

  const search = document.getElementById('referral-search')?.value.toLowerCase() || '';
  const status = document.getElementById('referral-status-filter')?.value || '';
  const tbody = document.getElementById('referrals-tbody');

  if (!tbody) return;
  tbody.innerHTML = '<tr><td colspan="6" class="px-2 py-4 text-center text-slate-500">กำลังโหลดข้อมูล...</td></tr>';

  try {
    let query = supabase
      .from('referrals')
      .select('*')
      .order('created_at', { ascending: false });

    if (status) {
      query = query.eq('status', status);
    }

    const { data, error } = await query;
    if (error) throw error;

    const rows = data || [];
    const profileIds = Array.from(
      new Set(
        rows
          .flatMap((r) => [r.referrer_id, r.referee_id])
          .filter(Boolean)
      )
    );

    let profilesById = {};
    if (profileIds.length > 0) {
      const { data: profiles, error: profilesErr } = await supabase
        .from('profiles')
        .select('id, full_name, phone_number')
        .in('id', profileIds);
      if (profilesErr) throw profilesErr;
      profilesById = Object.fromEntries((profiles || []).map((p) => [p.id, p]));
    }

    let filteredData = rows;
    if (search) {
      filteredData = filteredData.filter((r) => {
        const referrer = profilesById[r.referrer_id];
        const referee = profilesById[r.referee_id];
        return (
          (r.referral_code_used && r.referral_code_used.toLowerCase().includes(search)) ||
          (referrer?.full_name && referrer.full_name.toLowerCase().includes(search)) ||
          (referee?.full_name && referee.full_name.toLowerCase().includes(search)) ||
          (referrer?.phone_number && referrer.phone_number.includes(search))
        );
      });
    }

    const countEl = document.getElementById('referrals-count');
    if (countEl) countEl.textContent = String(filteredData.length);

    if (filteredData.length === 0) {
      tbody.innerHTML = '<tr><td colspan="6" class="px-2 py-4 text-center text-slate-500">ไม่พบข้อมูล</td></tr>';
      return;
    }

    tbody.innerHTML = filteredData.map(r => {
      const dateStr = new Date(r.created_at).toLocaleString('th-TH');
      let statusBadge = '';
      if (r.status === 'pending') statusBadge = '<div class="inline-flex font-medium rounded-full text-center px-2.5 py-0.5 bg-amber-100 text-amber-600">รอตรวจสอบ</div>';
      else if (r.status === 'qualified') statusBadge = '<div class="inline-flex font-medium rounded-full text-center px-2.5 py-0.5 bg-emerald-100 text-emerald-600">สำเร็จ</div>';
      else statusBadge = '<div class="inline-flex font-medium rounded-full text-center px-2.5 py-0.5 bg-rose-100 text-rose-600">เพิกถอน</div>';

      const referrer = profilesById[r.referrer_id];
      const referee = profilesById[r.referee_id];

      return `
        <tr>
          <td class="px-2 first:pl-5 last:pr-5 py-3 whitespace-nowrap"><div class="text-left">${dateStr}</div></td>
          <td class="px-2 first:pl-5 last:pr-5 py-3 whitespace-nowrap"><div class="text-left font-medium text-indigo-500">${escapeHtml(r.referral_code_used)}</div></td>
          <td class="px-2 first:pl-5 last:pr-5 py-3 whitespace-nowrap">
            <div class="text-left">
              <div class="font-medium text-slate-800">${escapeHtml(referrer?.full_name || 'Unknown')}</div>
              <div class="text-xs text-slate-500">${escapeHtml(referrer?.phone_number || '')}</div>
            </div>
          </td>
          <td class="px-2 first:pl-5 last:pr-5 py-3 whitespace-nowrap">
            <div class="text-left">
              <div class="font-medium text-slate-800">${escapeHtml(referee?.full_name || 'Unknown')}</div>
              <div class="text-xs text-slate-500">${escapeHtml(referee?.phone_number || '')}</div>
            </div>
          </td>
          <td class="px-2 first:pl-5 last:pr-5 py-3 whitespace-nowrap"><div class="text-center">${statusBadge}</div></td>
          <td class="px-2 first:pl-5 last:pr-5 py-3 whitespace-nowrap w-px">
            <div class="flex items-center justify-center space-x-2">
              ${r.status === 'pending' ? `
                <button class="text-emerald-500 hover:text-emerald-600 rounded-full" onclick="updateReferralStatus('${r.id}', 'qualified')" title="อนุมัติ">
                  <svg class="w-8 h-8 fill-current" viewBox="0 0 32 32"><path d="M16 32a16 16 0 1 1 16-16 16.019 16.019 0 0 1-16 16Zm0-30a14 14 0 1 0 14 14A14.016 14.016 0 0 0 16 2Zm7.707 9.293-10 10a1 1 0 0 1-1.414 0l-5-5a1 1 0 1 1 1.414-1.414L13 19.586l9.293-9.293a1 1 0 0 1 1.414 1.414Z"/></svg>
                </button>
                <button class="text-rose-500 hover:text-rose-600 rounded-full" onclick="updateReferralStatus('${r.id}', 'revoked')" title="เพิกถอน">
                  <svg class="w-8 h-8 fill-current" viewBox="0 0 32 32"><path d="M16 32a16 16 0 1 1 16-16 16.019 16.019 0 0 1-16 16Zm0-30a14 14 0 1 0 14 14A14.016 14.016 0 0 0 16 2Zm4.707 10.707-3.293 3.293 3.293 3.293-1.414 1.414L16 17.414l-3.293 3.293-1.414-1.414 3.293-3.293-3.293-3.293 1.414-1.414L16 14.586l3.293-3.293z"/></svg>
                </button>
              ` : `
                <button class="text-slate-400 hover:text-slate-500 rounded-full" onclick="alert('แสดงรายละเอียด (Coming soon)')" title="ดูรายละเอียด">
                  <svg class="w-8 h-8 fill-current" viewBox="0 0 32 32"><path d="M16 20c-2.206 0-4-1.794-4-4s1.794-4 4-4 4 1.794 4 4-1.794 4-4 4zm0-6c-1.103 0-2 .897-2 2s.897 2 2 2 2-.897 2-2-.897-2-2-2z"/><path d="M16 24c-5.514 0-10-4.486-10-10s4.486-10 10-10 10 4.486 10 10-4.486 10-10 10zm0-18c-4.411 0-8 3.589-8 8s3.589 8 8 8 8-3.589 8-8-3.589-8-8-8z"/></svg>
                </button>
              `}
            </div>
          </td>
        </tr>
      `;
    }).join('');
  } catch (e) {
    console.error('Error fetching referrals:', e);
    const code = e?.code;
    const rawMsg = e?.message || String(e);
    const msg = code === 'PGRST205'
      ? "ยังไม่มีตาราง 'public.referrals' ในฐานข้อมูล (ต้องรัน migration: supabase/migrations/20260311_referral_and_coupon_wallet.sql)"
      : rawMsg;
    tbody.innerHTML = `<tr><td colspan="6" class="px-2 py-4 text-center text-rose-500">เกิดข้อผิดพลาด: ${escapeHtml(msg)}</td></tr>`;
  }
}

export async function refreshReferrals() {
  return filterReferrals();
}

export async function updateReferralStatus(referralId, newStatus) {
  const { supabase, escapeHtml, showToast } = _deps();
  const actionName = newStatus === 'qualified' ? 'อนุมัติ' : 'เพิกถอน';
  if (!confirm(`คุณต้องการ ${actionName} รายการชวนเพื่อนนี้ใช่หรือไม่?`)) return;

  try {
    const { error } = await supabase
      .from('referrals')
      .update({
        status: newStatus,
        qualified_at: newStatus === 'qualified' ? new Date().toISOString() : null,
      })
      .eq('id', referralId);

    if (error) throw error;

    if (typeof showToast === 'function') showToast(`ดำเนินการ ${actionName} สำเร็จ`, 'success');
    else alert(`ดำเนินการ ${actionName} สำเร็จ`);

    await refreshReferrals();
  } catch (e) {
    const msg = e?.message || String(e);
    if (typeof showToast === 'function') showToast('เกิดข้อผิดพลาด: ' + escapeHtml(msg), 'error');
    else alert('เกิดข้อผิดพลาด: ' + msg);
  }
}

export function wireReferralsBridge() {
  globalThis.__adminWebBridge = globalThis.__adminWebBridge || {};
  globalThis.__adminWebBridge.renderReferralsPage = renderReferralsPage;
  globalThis.__adminWebBridge.filterReferrals = filterReferrals;
  globalThis.__adminWebBridge.refreshReferrals = refreshReferrals;
  globalThis.__adminWebBridge.updateReferralStatus = updateReferralStatus;
}
