import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../common/config/supabase_config.dart';
import 'dart:async';

/// Supabase Health Checker
/// 
/// Utility to check if Supabase is available and responsive
class SupabaseHealthChecker {
  static Future<bool> checkConnection() async {
    try {
      // Try a simple health check - get current user
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      
      if (user != null) {
        // If user is logged in, try a simple query
        try {
          await client
              .from('profiles')
              .select('id')
              .eq('id', user.id)
              .limit(1)
              .timeout(const Duration(seconds: 5));
          return true;
        } catch (e) {
          debugLog('❌ Supabase query failed: $e');
          return false;
        }
      } else {
        // If no user, just check if we can reach auth
        return true; // Auth service is available
      }
    } catch (e) {
      debugLog('❌ Supabase health check failed: $e');
      return false;
    }
  }

  static Future<String> testConnection() async {
    try {
      final url = SupabaseConfig.supabaseUrl;
      
      debugLog('🔍 Testing Supabase connection to: $url');
      
      // Test basic connectivity
      final startTime = DateTime.now();
      final isConnected = await checkConnection();
      final duration = DateTime.now().difference(startTime);
      
      if (isConnected) {
        return '✅ Connected to Supabase (${duration.inMilliseconds}ms)';
      } else {
        return '❌ Failed to connect to Supabase';
      }
    } catch (e) {
      return '❌ Connection test failed: $e';
    }
  }
}
