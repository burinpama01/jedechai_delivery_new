import 'env_config.dart';

/// Supabase Configuration
///
/// All credentials are loaded from .env file via EnvConfig
/// See .env file for actual values (not committed to git)
///
/// ISSUE-102: ไม่มี service role key ที่นี่โดยเจตนา — .env ถูก bundle เป็น
/// Flutter asset จึงถูกแตกจาก APK/IPA ได้ งานที่ต้องใช้สิทธิ์ service role
/// ต้องเรียกผ่าน Supabase Edge Function เท่านั้น
class SupabaseConfig {
  static String get supabaseUrl => EnvConfig.supabaseUrl;
  static String get supabaseAnonKey => EnvConfig.supabaseAnonKey;

  // Check if Supabase is properly configured
  static bool get isConfigured => EnvConfig.isSupabaseConfigured;
}
