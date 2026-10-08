// ทดสอบเฉพาะ container fixture แยกที่ session นี้สร้าง ไม่แตะ Supabase จริง
import assert from 'node:assert/strict';
import { spawn } from 'node:child_process';
const container = 'jdc-gp-proposal-fixture';
const database = 'gp_review';
function sql(statement) {
  return new Promise((resolve, reject) => {
    const child = spawn('docker', ['exec', '-i', container, 'psql', '-h', '/tmp', '-U', 'postgres', '-d', database, '-v', 'ON_ERROR_STOP=1', '-qAt']);
    let out = '', err = '';
    child.stdout.on('data', (chunk) => { out += chunk; });
    child.stderr.on('data', (chunk) => { err += chunk; });
    child.on('error', reject);
    child.on('close', (code) => resolve({ code, out, err }));
    child.stdin.end(statement);
  });
}
const merchant = '00000000-0000-0000-0000-000000000005';
const admin = '00000000-0000-0000-0000-000000000003';
const auth = (id) => `SET ROLE authenticated; SELECT set_config('request.jwt.claim.sub','${id}',false);`;
assert.equal((await sql(`INSERT INTO profiles(id,role,merchant_service_types) VALUES ('${merchant}','merchant',ARRAY['food']);`)).code, 0);
const submit = `BEGIN; ${auth(merchant)} SELECT merchant_submit_gp_proposal(0.15,10,5,3,'concurrent fixture'); SELECT pg_sleep(1); COMMIT;`;
const submitted = await Promise.all([sql(submit), sql(submit)]);
assert.equal(submitted.filter((r) => r.code === 0).length, 1);
assert.ok(submitted.some((r) => r.err.includes('gp_proposal_already_submitted')));
const count = await sql(`SELECT count(*) FROM merchant_gp_proposals WHERE merchant_id='${merchant}';`);
assert.equal(count.out.trim(), '1');
const review = `BEGIN; ${auth(admin)} SELECT admin_review_gp_proposal((SELECT gp_proposal_id FROM profiles WHERE id='${merchant}'),'approved','',0.082,0.068); SELECT pg_sleep(1); COMMIT;`;
const reviewed = await Promise.all([sql(review), sql(review)]);
assert.equal(reviewed.filter((r) => r.code === 0).length, 1);
assert.ok(reviewed.some((r) => r.err.includes('gp_proposal_stale')));
const state = await sql(`SELECT gp_proposal_status || ':' || approval_status FROM profiles WHERE id='${merchant}';`);
assert.equal(state.out.trim(), 'approved:pending');
console.log('Concurrency passed: two submit connections -> one proposal; two reviews -> one approval; store remains pending.');
