import test from 'node:test';
import assert from 'node:assert/strict';
import { reviewProposal, renderProposalHistory } from './merchantGpProposals.js';
import { approveMerchant } from './merchantsPage.js';
test('approval requires explicit valid split before calling RPC', async () => {
  let calls = 0;
  const sb = { rpc: async () => { calls++; return { data: { success: true } }; } };
  await assert.rejects(reviewProposal(sb, { id: 'a', gp_rate: .15 }, 'approved', '', '', '15'));
  await assert.rejects(reviewProposal(sb, { id: 'a', gp_rate: .15 }, 'approved', '', '10', '10'));
  assert.equal(calls, 0);
  await reviewProposal(sb, { id: 'a', gp_rate: .15 }, 'approved', '', '10', '5');
  assert.equal(calls, 1);
});
test('pending proposal prevents merchant approval success and override', async () => {
  globalThis.confirm = () => true;
  let calls = 0, refreshed = false;
  const toasts = [];
  await approveMerchant('m', {
    callAdminAction: async () => { calls++; return { success: false, error: 'gp_proposal_pending' }; },
    showToast: (text, kind) => toasts.push({ text, kind }),
    refreshCurrentPage: () => { refreshed = true; }, escapeHtml: String,
  });
  assert.equal(calls, 1);
  assert.equal(refreshed, false);
  assert.equal(toasts[0].kind, 'error');
});
test('other approval errors never display success', async () => {
  globalThis.confirm = () => true;
  const toasts = [];
  await approveMerchant('m', {
    callAdminAction: async () => ({ success: false, error: 'gp_proposal_returned' }),
    showToast: (text, kind) => toasts.push(kind),
    refreshCurrentPage: () => assert.fail('must not refresh'), escapeHtml: String,
  });
  assert.deepEqual(toasts, ['error']);
});
test('return requires reason and failed RPC never succeeds', async () => {
  const sb = { rpc: async () => ({ data: { success: false, error: 'stale_proposal' } }) };
  await assert.rejects(reviewProposal(sb, { id: 'a' }, 'returned', ' '));
  await assert.rejects(reviewProposal(sb, { id: 'a' }, 'returned', 'แก้ค่าส่ง'), /stale_proposal/);
});
test('history escapes merchant text and displays all revision statuses', () => {
  const html = renderProposalHistory([{ revision: 2, status: 'returned', gp_rate: .15, merchant_note: '<img onerror=x>', rejection_reason: '<script>x</script>' }]);
  assert.ok(html.includes('ตีกลับ'));
  assert.ok(html.includes('&lt;script&gt;'));
  assert.ok(!html.includes('<img'));
});
