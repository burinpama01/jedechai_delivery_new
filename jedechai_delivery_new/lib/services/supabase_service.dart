import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/supabase_config.dart';

/// Supabase Service
/// 
/// Centralized service for Supabase operations
/// Initialize Supabase client and provide helper methods
class SupabaseService {
  static SupabaseClient get client => Supabase.instance.client;
  
  /// Initialize Supabase
  /// 
  /// Call this method in main() before runApp()
  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConfig.supabaseUrl,
      anonKey: SupabaseConfig.supabaseAnonKey,
      debug: true, // Set to false in production
    );
  }
  
  /// Get current user
  static User? get currentUser => client.auth.currentUser;
  
  /// Check if user is authenticated
  static bool get isAuthenticated => currentUser != null;
  
  /// Get user ID
  static String? get userId => currentUser?.id;
  
  /// Sign out
  static Future<void> signOut() async {
    await client.auth.signOut();
  }
  
  // Database helpers
  static RealtimeChannel channel(String channelName) {
    return client.channel(channelName);
  }
}
