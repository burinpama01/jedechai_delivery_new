import {
  copyFileSync,
  existsSync,
  mkdirSync,
  readdirSync,
  readFileSync,
  statSync,
  writeFileSync,
} from "node:fs";
import { tmpdir } from "node:os";
import { basename, join, resolve } from "node:path";
import { runInNewContext } from "node:vm";

function parseArgs(argv) {
  const args = {};
  for (let i = 0; i < argv.length; i += 1) {
    if (argv[i] === "--source") args.source = argv[++i];
    else if (argv[i] === "--out") args.out = argv[++i];
    else throw new Error(`Unknown argument: ${argv[i]}`);
  }
  return args;
}

function jwtRole(value) {
  const parts = String(value || "").split(".");
  if (parts.length < 2) return "";
  try {
    const payload = JSON.parse(Buffer.from(parts[1], "base64url").toString("utf8"));
    return typeof payload.role === "string" ? payload.role : "";
  } catch {
    return "";
  }
}

function readPublicConfig(sourceDir) {
  const source = readFileSync(join(sourceDir, "config.production.js"), "utf8");
  const sandbox = { window: {} };
  runInNewContext(source, sandbox, {
    filename: "config.production.js",
    timeout: 1000,
  });

  const config = sandbox.window.JEDECHAI_CONFIG || {};
  const supabaseUrl = typeof config.SUPABASE_URL === "string" ? config.SUPABASE_URL.trim() : "";
  const supabaseAnonKey =
    typeof config.SUPABASE_ANON_KEY === "string" ? config.SUPABASE_ANON_KEY.trim() : "";

  if (!supabaseUrl || !supabaseAnonKey) {
    throw new Error("Missing public Supabase config");
  }

  const parsedUrl = new URL(supabaseUrl);
  if (parsedUrl.protocol !== "https:" || parsedUrl.hostname === "your-project.supabase.co") {
    throw new Error("Invalid public Supabase URL");
  }
  if (/your-anon-key-here|placeholder/i.test(supabaseAnonKey)) {
    throw new Error("Invalid public Supabase anon key");
  }
  if (jwtRole(supabaseAnonKey).toLowerCase() === "service_role") {
    throw new Error("Public Supabase anon key must not be service-role");
  }

  return { supabaseUrl, supabaseAnonKey };
}

const skipNames = new Set([".netlify", ".npm-cache", "node_modules", "config.production.js"]);

function copyAdminWeb(sourceDir, outDir) {
  let copiedFiles = 0;

  function copyDir(from, to) {
    mkdirSync(to, { recursive: true });
    for (const entry of readdirSync(from, { withFileTypes: true })) {
      if (skipNames.has(entry.name) || entry.name.endsWith(".log")) continue;

      const source = join(from, entry.name);
      const dest = join(to, entry.name);
      if (entry.isDirectory()) {
        copyDir(source, dest);
      } else if (entry.isFile()) {
        copyFileSync(source, dest);
        copiedFiles += 1;
      }
    }
  }

  copyDir(sourceDir, outDir);
  return copiedFiles;
}

function allowSanitizedConfigInStaging(outDir) {
  const ignorePath = join(outDir, ".netlifyignore");
  if (!existsSync(ignorePath)) return;

  const next = readFileSync(ignorePath, "utf8")
    .split(/\r?\n/)
    .filter((line) => line.trim() !== "config.production.js")
    .join("\n")
    .replace(/\n*$/, "\n");
  writeFileSync(ignorePath, next, "utf8");
}

const args = parseArgs(process.argv.slice(2));
const sourceDir = resolve(args.source || join(process.cwd(), "admin-web"));
const outDir = resolve(
  args.out || join(tmpdir(), `jedechai-admin-web-netlify-${Date.now()}`),
);

if (!statSync(sourceDir).isDirectory()) {
  throw new Error(`Admin web source directory not found: ${sourceDir}`);
}
if (existsSync(outDir)) {
  throw new Error(`Deploy output already exists: ${outDir}`);
}

const publicConfig = readPublicConfig(sourceDir);
const copiedFiles = copyAdminWeb(sourceDir, outDir);
allowSanitizedConfigInStaging(outDir);

writeFileSync(
  join(outDir, "config.production.js"),
  [
    "window.JEDECHAI_CONFIG = {",
    `  SUPABASE_URL: ${JSON.stringify(publicConfig.supabaseUrl)},`,
    `  SUPABASE_ANON_KEY: ${JSON.stringify(publicConfig.supabaseAnonKey)},`,
    "};",
    "",
  ].join("\n"),
  "utf8",
);

console.log(JSON.stringify({
  deployDir: outDir,
  copiedFiles,
  source: basename(sourceDir),
  sanitizedConfig: true,
  rawConfigExcluded: true,
}, null, 2));
