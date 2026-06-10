import 'package:jedechai_delivery_new/common/models/app_update_policy.dart';
import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppUpdatePolicyService {
  AppUpdatePolicyService({
    SupabaseClient? client,
    this.timeout = const Duration(seconds: 4),
  }) : _client = client;

  final SupabaseClient? _client;
  final Duration timeout;

  SupabaseClient get _supabase => _client ?? Supabase.instance.client;

  Future<AppUpdatePolicy> fetchPolicy() async {
    try {
      final row = await _supabase
          .from('system_config')
          .select('app_update_policy')
          .eq('id', 1)
          .maybeSingle()
          .timeout(timeout);

      return AppUpdatePolicy.fromJson(row?['app_update_policy']);
    } catch (error) {
      debugLog('Version policy fetch failed (fail-open): $error');
      return AppUpdatePolicy.disabled;
    }
  }

  Future<String?> fetchCurrentUserRole() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return null;

      final row = await _supabase
          .from('profiles')
          .select('role')
          .eq('id', user.id)
          .maybeSingle()
          .timeout(timeout);
      return row?['role']?.toString().trim();
    } catch (error) {
      debugLog('Version policy role fetch failed (fail-open): $error');
      return null;
    }
  }
}
