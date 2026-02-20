import 'env_config.dart';

/// Supabase Configuration
/// 
/// All credentials are loaded from .env file via EnvConfig
/// See .env file for actual values (not committed to git)
class SupabaseConfig {
  static String get supabaseUrl => EnvConfig.supabaseUrl;
  static String get supabaseAnonKey => EnvConfig.supabaseAnonKey;
  static String get supabaseServiceKey => EnvConfig.supabaseServiceKey;
  
  // Check if Supabase is properly configured
  static bool get isConfigured => EnvConfig.isSupabaseConfigured;
      
  // Check if Service Role Key is configured
  static bool get isServiceKeyConfigured => EnvConfig.isServiceKeyConfigured;
}
