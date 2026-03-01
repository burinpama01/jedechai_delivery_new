export function getConfig() {
  const cfg = globalThis?.JEDECHAI_CONFIG || {};
  return {
    SUPABASE_URL: cfg.SUPABASE_URL || "",
    SUPABASE_ANON_KEY: cfg.SUPABASE_ANON_KEY || "",
  };
}

export function validateConfig(config) {
  if (!config?.SUPABASE_URL || !config?.SUPABASE_ANON_KEY) {
    return { ok: false, error: "missing_supabase_config" };
  }
  return { ok: true };
}
