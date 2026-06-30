import { readFileSync, statSync } from "node:fs";
import { resolve } from "node:path";
import { runInNewContext } from "node:vm";

const configPath = resolve(process.cwd(), "config.production.js");
const errors = [];

function fail(message) {
  errors.push(message);
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

let source = "";
try {
  const stat = statSync(configPath);
  if (!stat.isFile() || stat.size === 0) {
    fail("config.production.js is missing or empty");
  } else {
    source = readFileSync(configPath, "utf8");
  }
} catch {
  fail("config.production.js is required before deploying admin-web");
}

if (source) {
  if (/^\s*</.test(source)) {
    fail("config.production.js must be JavaScript, not an HTML fallback");
  }
  if (/your-project\.supabase\.co/.test(source)) {
    fail("config.production.js still contains the placeholder Supabase host");
  }
  if (/SUPABASE_SERVICE_KEY|SERVICE_ROLE|SERVICE_ROLE_KEY|service[_-]?role/i.test(source)) {
    fail("config.production.js contains a server-side key marker");
  }
  if (!/window\.JEDECHAI_CONFIG/.test(source)) {
    fail("config.production.js must assign window.JEDECHAI_CONFIG");
  }

  try {
    const sandbox = { window: {} };
    runInNewContext(source, sandbox, {
      filename: "config.production.js",
      timeout: 1000,
    });

    const config = sandbox.window.JEDECHAI_CONFIG || {};
    const allowedKeys = new Set(["SUPABASE_URL", "SUPABASE_ANON_KEY"]);
    for (const key of Object.keys(config)) {
      if (!allowedKeys.has(key)) {
        fail("config.production.js contains an unsupported config key");
      }
      if (/SERVICE|SERVICE_ROLE|SERVER|SECRET/i.test(key)) {
        fail("config.production.js contains a forbidden server-side config key");
      }
    }
    const supabaseUrl = typeof config.SUPABASE_URL === "string" ? config.SUPABASE_URL.trim() : "";
    const supabaseAnonKey =
      typeof config.SUPABASE_ANON_KEY === "string" ? config.SUPABASE_ANON_KEY.trim() : "";

    if (!supabaseUrl) {
      fail("config.production.js is missing SUPABASE_URL");
    } else {
      try {
        const parsed = new URL(supabaseUrl);
        if (parsed.protocol !== "https:" || parsed.hostname === "your-project.supabase.co") {
          fail("config.production.js has an invalid SUPABASE_URL");
        }
      } catch {
        fail("config.production.js has an invalid SUPABASE_URL");
      }
    }

    if (!supabaseAnonKey) {
      fail("config.production.js is missing SUPABASE_ANON_KEY");
    } else if (/your-anon-key-here|placeholder/i.test(supabaseAnonKey)) {
      fail("config.production.js still contains the placeholder anon key");
    } else if (jwtRole(supabaseAnonKey).toLowerCase() === "service_role") {
      fail("config.production.js must not expose a service-role key");
    }
  } catch {
    fail("config.production.js could not be evaluated as browser config");
  }
}

if (errors.length) {
  for (const error of errors) {
    console.error(`[admin-web config preflight] ${error}`);
  }
  process.exitCode = 1;
} else {
  console.log("[admin-web config preflight] config.production.js is present and deployable");
}
