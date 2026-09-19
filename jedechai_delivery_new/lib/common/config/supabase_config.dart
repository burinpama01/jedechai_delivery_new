import 'env_config.dart';

/// Supabase Configuration
/// 
/// Public credentials are loaded from .env.client via EnvConfig
/// See .env.client for actual values (not committed to git)
class SupabaseConfig {
  static String get supabaseUrl => EnvConfig.supabaseUrl;
  static String get supabaseAnonKey => EnvConfig.supabaseAnonKey;
  
  // Check if Supabase is properly configured
  static bool get isConfigured => EnvConfig.isSupabaseConfigured;
}
