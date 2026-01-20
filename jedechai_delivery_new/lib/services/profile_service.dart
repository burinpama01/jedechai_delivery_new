import 'supabase_service.dart';

/// Profile Service
/// Handles user profile operations
class ProfileService {
  final _client = SupabaseService.client;

  /// Get current user profile
  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final userId = SupabaseService.userId;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      throw Exception('Failed to fetch profile: $e');
    }
  }

  /// Get user's full name
  Future<String?> getUserFullName() async {
    final profile = await getCurrentProfile();
    return profile?['full_name'] as String?;
  }

  /// Get user's role
  Future<String?> getUserRole() async {
    final profile = await getCurrentProfile();
    return profile?['role'] as String?;
  }
}
