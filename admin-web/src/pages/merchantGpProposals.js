const labels = { pending: 'รออนุมัติข้อเสนอ', approved: 'อนุมัติข้อเสนอแล้ว', returned: 'ตีกลับ', superseded: 'แทนที่ด้วยข้อเสนอใหม่' };
const esc = (value) => String(value ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
export function proposalStatusLabel(status) { return labels[status] || 'ไม่ทราบสถานะข้อเสนอ'; }
export function renderProposalHistory(rows) {
  return rows.map((p) => `<article class="border rounded-xl p-3 mb-3"><strong>รอบ ${esc(p.revision)} · ${esc(proposalStatusLabel(p.status))}</strong>
    <p>GP ${esc(Number(p.gp_rate) * 100)}% · ค่าส่งเริ่มต้น ${esc(p.base_delivery_fee)} บาท / ${esc(p.base_distance_km)} กม. · ระยะเกิน ${esc(p.per_km_charge)} บาท/กม.</p>
    <p class="whitespace-pre-wrap">เงื่อนไขจากร้าน: ${esc(p.merchant_note || '-')}</p>
    ${p.rejection_reason ? `<p class="text-red-600 whitespace-pre-wrap">เหตุผลตีกลับ: ${esc(p.rejection_reason)}</p>` : ''}
    <small>เสนอเมื่อ ${esc(p.created_at || '-')} ${p.reviewed_at ? `· พิจารณาเมื่อ ${esc(p.reviewed_at)}` : ''}</small></article>`).join('');
}
export async function reviewProposal(sb, proposal, decision, reason, systemPercent, driverPercent) {
  if (!['approved', 'returned'].includes(decision)) throw new Error('สถานะไม่ถูกต้อง');
  const args = { p_proposal_id: proposal.id, p_decision: decision, p_reason: String(reason || '').trim() };
  if (decision === 'returned' && !args.p_reason) throw new Error('กรุณาระบุเหตุผลตีกลับ');
  if (decision === 'approved') {
    const values = [systemPercent, driverPercent];
    if (values.some((v) => String(v ?? '').trim() === '' || !Number.isFinite(Number(v)) || Number(v) < 0)) throw new Error('กรุณาระบุส่วนแบ่งระบบและคนขับ');
    args.p_gp_system_rate = Number(systemPercent) / 100;
    args.p_gp_driver_rate = Number(driverPercent) / 100;
    if (Math.abs(args.p_gp_system_rate + args.p_gp_driver_rate - Number(proposal.gp_rate)) > 0.000001) throw new Error('ส่วนแบ่งระบบและคนขับต้องรวมเท่ากับ GP ที่ร้านเสนอ');
  }
  const { data, error } = await sb.rpc('admin_review_gp_proposal', args);
  if (error || data?.success !== true) throw new Error(error?.message || data?.error || 'ไม่สามารถบันทึกผลพิจารณาได้');
  return data;
}
export function bindProposalActions(el, deps) {
  el.addEventListener('click', (event) => {
    const button = event.target.closest('[data-gp-proposal-merchant]');
    if (button && el.contains(button)) openProposalDialog(button.dataset.gpProposalMerchant, deps);
  });
}
async function openProposalDialog(merchantId, deps) {
  const dialog = document.createElement('dialog');
  dialog.className = 'rounded-2xl p-5 w-full max-w-2xl shadow-xl';
  Object.assign(dialog.style, { width: 'min(92vw, 42rem)', boxSizing: 'border-box', maxHeight: '85vh', overflow: 'auto' });
  dialog.innerHTML = '<div class="flex justify-between"><h2 class="font-bold text-lg">ข้อเสนอ GP และค่าส่ง</h2><button type="button" data-close>ปิด</button></div><p data-content>กำลังโหลดข้อเสนอ…</p>';
  document.body.appendChild(dialog);
  dialog.querySelector('[data-close]').onclick = () => dialog.close();
  dialog.addEventListener('close', () => dialog.remove());
  dialog.showModal();
  try {
    const { data, error } = await deps.supabase.from('merchant_gp_proposals').select('*').eq('merchant_id', merchantId).order('revision', { ascending: false });
    if (error) throw error;
    if (!dialog.isConnected) return;
    const content = dialog.querySelector('[data-content]');
    content.innerHTML = data?.length ? renderProposalHistory(data) : 'ร้านยังไม่มีข้อเสนอ';
    const latest = data?.[0];
    if (latest?.status !== 'pending') return;
    const form = document.createElement('form');
    form.innerHTML = '<p class="mb-2">พิจารณารอบล่าสุดเท่านั้น การอนุมัติข้อเสนอแยกจากการอนุมัติบัญชีร้าน</p><label>ส่วนแบ่งระบบ (%)<input name="system" type="number" min="0" max="100" step="0.01" class="border rounded p-2 w-full"></label><label>ส่วนแบ่งคนขับ (%)<input name="driver" type="number" min="0" max="100" step="0.01" class="border rounded p-2 w-full"></label><label>เหตุผลตีกลับ<textarea name="reason" class="border rounded p-2 w-full"></textarea></label><p data-error class="text-red-600" role="alert"></p><button type="submit" value="approved" class="bg-green-600 text-white rounded p-2 mr-2">อนุมัติข้อเสนอ</button><button type="submit" value="returned" class="bg-red-600 text-white rounded p-2">ตีกลับ</button>';
    content.appendChild(form);
    form.onsubmit = async (event) => {
      event.preventDefault();
      const decision = event.submitter?.value;
      const buttons = form.querySelectorAll('button');
      buttons.forEach((b) => { b.disabled = true; });
      form.querySelector('[data-error]').textContent = '';
      try {
        await reviewProposal(deps.supabase, latest, decision, form.elements.reason.value, form.elements.system.value, form.elements.driver.value);
        deps.showToast('บันทึกผลพิจารณาสำเร็จ', 'success');
        dialog.close();
        deps.refreshCurrentPage();
      } catch (e) {
        form.querySelector('[data-error]').textContent = e.message || 'เกิดข้อผิดพลาด กรุณาโหลดข้อเสนอใหม่';
        buttons.forEach((b) => { b.disabled = false; });
      }
    };
  } catch (e) {
    if (dialog.isConnected) dialog.querySelector('[data-content]').textContent = `โหลดข้อเสนอไม่ได้: ${e.message || e}`;
  }
}
