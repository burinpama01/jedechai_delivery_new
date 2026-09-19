// Deploy admin-web ขึ้น Vercel production ด้วย token (แทน Netlify flow เดิม)
//
// การใช้งาน:
//   node scripts/deploy-admin-web-vercel.mjs
//
// ต้องมี VERCEL_TOKEN อย่างใดอย่างหนึ่ง:
//   1) environment variable VERCEL_TOKEN หรือ
//   2) บรรทัด VERCEL_TOKEN=... ใน jedechai_delivery_new/.env
//
// ขั้นตอน (ต่อยอดจาก prepare-admin-web-netlify-deploy.mjs เดิม):
//   1. เตรียม artifact ใน .codex-tmp (sanitize config เหลือ SUPABASE_URL + ANON_KEY,
//      ตัด service key, stamp cache-bust ?v=<version>-<timestamp>)
//   2. vercel link --project jedechai-delivery
//   3. vercel deploy --prod
//
// ห้าม log ค่า token และห้ามเขียน token ลงไฟล์อื่นนอกจาก .env ที่ผู้ใช้จัดการเอง

import { execFileSync } from "node:child_process";
import { existsSync, readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { join } from "node:path";

const REPO_ROOT = fileURLToPath(new URL("..", import.meta.url));
const PROJECT_NAME = "jedechai-delivery";
const TOKEN_ENV_FILES = [
  join(REPO_ROOT, "jedechai_delivery_new", ".env"),
];

function readToken() {
  if (process.env.VERCEL_TOKEN && process.env.VERCEL_TOKEN.trim()) {
    return process.env.VERCEL_TOKEN.trim();
  }
  for (const path of TOKEN_ENV_FILES) {
    if (!existsSync(path)) continue;
    const line = readFileSync(path, "utf8")
      .split(/\r?\n/)
      .find((l) => /^VERCEL_TOKEN=/.test(l));
    const value = line ? line.slice("VERCEL_TOKEN=".length).trim().replace(/^["']|["']$/g, "") : "";
    if (value) return value;
  }
  throw new Error("ไม่พบ VERCEL_TOKEN — ตั้ง env VERCEL_TOKEN หรือเพิ่มใน jedechai_delivery_new/.env");
}

const IS_WIN = process.platform === "win32";
const VERCEL_CMD = IS_WIN ? "vercel.cmd" : "vercel";

function run(args, opts = {}) {
  return execFileSync(VERCEL_CMD, args, {
    // Node >=18.20 บังคับให้ spawn .cmd ผ่าน shell; args ของเราไม่มี space/อักขระพิเศษ
    // และ token ส่งทาง env ไม่ใช่ argv จึงไม่หลุดไป command line
    ...(IS_WIN ? { shell: true } : {}),
    encoding: "utf8",
    stdio: ["ignore", "pipe", "pipe"],
    env: { ...process.env, VERCEL_TOKEN: token },
    ...opts,
  });
}

const token = readToken();
const outDir = join(REPO_ROOT, ".codex-tmp", `admin-web-vercel-${Date.now()}`);
if (existsSync(outDir)) {
  throw new Error(`Deploy output already exists: ${outDir}`);
}

const prepareOut = execFileSync("node", [
  join(REPO_ROOT, "scripts", "prepare-admin-web-netlify-deploy.mjs"),
  "--out", outDir,
], { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
const prepared = JSON.parse(prepareOut.slice(prepareOut.indexOf("{")));

run(["link", "--yes", "--project", PROJECT_NAME], { cwd: prepared.deployDir });
const deployOut = run(["deploy", "--prod", "--yes"], { cwd: prepared.deployDir });

const urls = deployOut.match(/https:\/\/[^\s]+\.vercel\.app/g) || [];

console.log(JSON.stringify({
  projectName: PROJECT_NAME,
  deployDir: prepared.deployDir,
  copiedFiles: prepared.copiedFiles,
  assetVersion: prepared.assetVersion,
  sanitizedConfig: true,
  productionUrls: [...new Set(urls)],
  note: "อย่างน้อยหนึ่ง URL ด้านบนคือ production alias — ตรวจด้วย curl <url>/admin",
}, null, 2));
