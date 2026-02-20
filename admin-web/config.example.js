// ============================================
// Jedechai Admin Web App - Example Config
// ============================================
// Copy this file to:
// - config.js (development)
// - config.production.js (production, keep gitignored)

window.JEDECHAI_CONFIG = {
  SUPABASE_URL: 'https://your-project.supabase.co',
  SUPABASE_ANON_KEY: 'your-anon-key-here',
  // ⚠️ Service role key is required for current admin-web architecture.
  // Do NOT commit this key to git.
  SUPABASE_SERVICE_KEY: 'your-service-role-key-here',
};
