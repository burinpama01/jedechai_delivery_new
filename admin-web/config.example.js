// ============================================
// Jedechai Admin Web App - Example Config
// ============================================
// Copy this file to:
// - config.js (development)
// - config.production.js (production, keep gitignored)

window.JEDECHAI_CONFIG = {
  SUPABASE_URL: 'https://your-project.supabase.co',
  SUPABASE_ANON_KEY: 'your-anon-key-here',
  // NOTE: Service role key is NO LONGER needed in the browser.
  // All privileged admin operations go through the admin-actions Edge Function.
};
