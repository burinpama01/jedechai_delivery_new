import test from "node:test";
import assert from "node:assert/strict";
import { mkdtempSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const scriptPath = fileURLToPath(
  new URL("../scripts/verify-admin-web-production-config.mjs", import.meta.url),
);

function fakeJwt(payload) {
  const header = Buffer.from(JSON.stringify({ alg: "none", typ: "JWT" })).toString("base64url");
  const body = Buffer.from(JSON.stringify(payload)).toString("base64url");
  return `${header}.${body}.signature`;
}

function runPreflight(source) {
  const dir = mkdtempSync(join(tmpdir(), "admin-web-config-"));
  try {
    if (source !== null) {
      writeFileSync(join(dir, "config.production.js"), source, "utf8");
    }
    return spawnSync(process.execPath, [scriptPath], {
      cwd: dir,
      encoding: "utf8",
    });
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
}

test("admin-web production config preflight rejects missing or malformed config", () => {
  const cases = [
    { name: "missing file", source: null },
    { name: "html fallback", source: "<!doctype html><html></html>" },
    {
      name: "missing window config",
      source: "const SUPABASE_URL = 'https://project.supabase.co'; const SUPABASE_ANON_KEY = 'anon-key';",
    },
    {
      name: "missing supabase url",
      source: "window.JEDECHAI_CONFIG = { SUPABASE_ANON_KEY: 'anon-key' };",
    },
    {
      name: "missing anon key",
      source: "window.JEDECHAI_CONFIG = { SUPABASE_URL: 'https://project.supabase.co' };",
    },
    {
      name: "empty values",
      source: "window.JEDECHAI_CONFIG = { SUPABASE_URL: '', SUPABASE_ANON_KEY: '' };",
    },
    {
      name: "placeholder url",
      source: "window.JEDECHAI_CONFIG = { SUPABASE_URL: 'https://your-project.supabase.co', SUPABASE_ANON_KEY: 'anon-key' };",
    },
    {
      name: "placeholder anon key",
      source: "window.JEDECHAI_CONFIG = { SUPABASE_URL: 'https://project.supabase.co', SUPABASE_ANON_KEY: 'your-anon-key-here' };",
    },
    {
      name: "server-side service key",
      source:
        "window.JEDECHAI_CONFIG = { SUPABASE_URL: 'https://project.supabase.co', SUPABASE_ANON_KEY: 'valid-anon-key', SUPABASE_SERVICE_KEY: 'server-side-key' };",
    },
    {
      name: "nested server-side key",
      source:
        "window.JEDECHAI_CONFIG = { SUPABASE_URL: 'https://project.supabase.co', SUPABASE_ANON_KEY: 'valid-anon-key', EXTRA: { SERVER_KEY: 'server-side-key' } };",
    },
    {
      name: "service role jwt as anon key",
      source: `window.JEDECHAI_CONFIG = { SUPABASE_URL: 'https://project.supabase.co', SUPABASE_ANON_KEY: '${fakeJwt({ role: "service_role" })}' };`,
    },
  ];

  for (const item of cases) {
    const result = runPreflight(item.source);
    assert.notEqual(result.status, 0, `${item.name} should fail preflight`);
  }
});

test("admin-web production config preflight accepts complete config without echoing values", () => {
  const source = "window.JEDECHAI_CONFIG = { SUPABASE_URL: 'https://project.supabase.co', SUPABASE_ANON_KEY: 'valid-anon-key' };";
  const result = runPreflight(source);

  assert.equal(result.status, 0);
  assert.doesNotMatch(`${result.stdout}\n${result.stderr}`, /valid-anon-key/);
  assert.doesNotMatch(`${result.stdout}\n${result.stderr}`, /project\.supabase\.co/);
});
