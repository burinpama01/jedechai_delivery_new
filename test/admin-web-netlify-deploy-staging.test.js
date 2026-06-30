import test from "node:test";
import assert from "node:assert/strict";
import { existsSync, mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const prepareScriptPath = fileURLToPath(
  new URL("../scripts/prepare-admin-web-netlify-deploy.mjs", import.meta.url),
);
const preflightScriptPath = fileURLToPath(
  new URL("../scripts/verify-admin-web-production-config.mjs", import.meta.url),
);

test("admin-web Netlify deploy staging writes a public-only production config", () => {
  const dir = mkdtempSync(join(tmpdir(), "admin-web-deploy-source-"));
  const sourceDir = join(dir, "admin-web");
  const outDir = join(dir, "deploy");

  try {
    mkdirSync(sourceDir, { recursive: true });
    writeFileSync(join(sourceDir, "index.html"), '<script src="config.production.js"></script>', "utf8");
    writeFileSync(join(sourceDir, ".netlifyignore"), "config.production.js\n*.log\n", "utf8");
    writeFileSync(join(sourceDir, "app.js"), "console.log('app');\n", "utf8");
    writeFileSync(
      join(sourceDir, "config.production.js"),
      [
        "window.JEDECHAI_CONFIG = {",
        "  SUPABASE_URL: 'https://project.supabase.co',",
        "  SUPABASE_ANON_KEY: 'public-anon-key',",
        "  SUPABASE_SERVICE_KEY: 'server-side-key',",
        "};",
        "",
      ].join("\n"),
      "utf8",
    );

    const result = spawnSync(process.execPath, [
      prepareScriptPath,
      "--source",
      sourceDir,
      "--out",
      outDir,
    ], {
      encoding: "utf8",
    });

    assert.equal(result.status, 0, result.stderr);
    assert.equal(existsSync(join(outDir, "config.production.js")), true);

    const deployConfig = readFileSync(join(outDir, "config.production.js"), "utf8");
    assert.match(deployConfig, /SUPABASE_URL/);
    assert.match(deployConfig, /SUPABASE_ANON_KEY/);
    assert.doesNotMatch(deployConfig, /SUPABASE_SERVICE_KEY/);
    assert.doesNotMatch(deployConfig, /server-side-key/);

    const deployIgnore = readFileSync(join(outDir, ".netlifyignore"), "utf8");
    assert.doesNotMatch(deployIgnore, /^config\.production\.js$/m);

    const preflight = spawnSync(process.execPath, [preflightScriptPath], {
      cwd: outDir,
      encoding: "utf8",
    });
    assert.equal(preflight.status, 0, preflight.stderr);
    assert.doesNotMatch(`${result.stdout}\n${result.stderr}`, /server-side-key/);
  } finally {
    rmSync(dir, { recursive: true, force: true });
  }
});
