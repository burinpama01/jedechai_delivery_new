export function createSupabaseClients({ SUPABASE_URL, SUPABASE_ANON_KEY, storageKey }) {
  if (!SUPABASE_URL || !SUPABASE_ANON_KEY) {
    throw new Error("Missing Supabase config");
  }
  if (typeof globalThis.supabaseClient === "undefined") {
    throw new Error("Supabase library not loaded");
  }
  const authClientOptions = {
    auth: {
      flowType: "implicit",
      detectSessionInUrl: false,
      persistSession: true,
      autoRefreshToken: true,
      storageKey: storageKey || "jedechai_admin_web_auth",
    },
  };
  const supabaseAuth = globalThis.supabaseClient(SUPABASE_URL, SUPABASE_ANON_KEY, authClientOptions);
  const supabase = supabaseAuth;
  return { supabase, supabaseAuth };
}
