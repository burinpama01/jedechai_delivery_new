// ============================================
// Jedechai Admin Web App - Configuration
// ============================================
// วิธีตั้งค่า:
// 1. สำหรับ development: แก้ไขค่าด้านล่างโดยตรง
// 2. สำหรับ production (hosting):
//    - ใช้ไฟล์ config.production.js แทน
//    - หรือ set ค่าผ่าน environment variables ของ hosting provider
//
// ⚠️ ข้อควรระวัง:
// - ห้าม commit SUPABASE_SERVICE_KEY ลง git repository
// - ใช้ .gitignore เพื่อซ่อน config.production.js

window.JEDECHAI_CONFIG = window.JEDECHAI_CONFIG || {
  SUPABASE_URL: 'https://your-project.supabase.co',
  SUPABASE_ANON_KEY: 'your-anon-key-here',
  // IMPORTANT: Keep SUPABASE_SERVICE_KEY in config.production.js only (gitignored)
  // SUPABASE_SERVICE_KEY: 'your-service-role-key-here',
};
