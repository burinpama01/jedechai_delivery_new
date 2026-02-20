import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'mock_auth_service.dart';
import 'auth_service.dart';

/// Profile Service
/// Handles user profile operations
class ProfileService {
  SupabaseClient get _client {
    if (MockAuthService.useMockMode) {
      throw Exception('Mock mode active - Profile operations not available');
    }
    return Supabase.instance.client;
  }

  /// Get current user profile
  Future<Map<String, dynamic>?> getCurrentProfile() async {
    final userId = AuthService.userId;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      debugLog('📋 Profile fetched: $response');
      return response;
    } catch (e) {
      debugLog('❌ Failed to fetch profile: $e');
      // If profile doesn't exist, return null instead of throwing
      if (e.toString().contains('No rows')) {
        debugLog('ℹ️ Profile not found for user: $userId');
        return null;
      }
      throw Exception('Failed to fetch profile: $e');
    }
  }

  /// Get user profile by ID
  Future<Map<String, dynamic>?> getProfileById(String userId) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('id', userId)
          .maybeSingle();

      debugLog('📋 Profile fetched for $userId: $response');
      return response;
    } catch (e) {
      debugLog('❌ Failed to fetch profile for $userId: $e');
      // If profile doesn't exist, return null instead of throwing
      if (e.toString().contains('No rows')) {
        debugLog('ℹ️ Profile not found for user: $userId');
        return null;
      }
      throw Exception('Failed to fetch profile: $e');
    }
  }

  /// Check if column exists in profiles table
  Future<bool> _columnExists(String columnName) async {
    try {
      await _client
          .from('profiles')
          .select(columnName)
          .limit(1)
          .maybeSingle();
      return true;
    } catch (e) {
      // Only return false if it's a column-not-found error
      if (e.toString().contains('column') || e.toString().contains('does not exist') || e.toString().contains('undefined column')) {
        debugLog('⚠️ Column $columnName does not exist: $e');
        return false;
      }
      // For other errors (RLS, network, etc.), assume column exists
      debugLog('⚠️ Column check for $columnName had error (assuming exists): $e');
      return true;
    }
  }

  /// Safe field addition - only add if column exists
  Future<void> _addFieldIfExists(
    Map<String, dynamic> data, 
    String fieldName, 
    String? value
  ) async {
    if (value != null && value.isNotEmpty) {
      final exists = await _columnExists(fieldName);
      if (exists) {
        data[fieldName] = value;
        debugLog('✅ Added field $fieldName: $value');
      } else {
        debugLog('⚠️ Skipped field $fieldName (column does not exist)');
      }
    }
  }

  /// Create or update user profile
  Future<Map<String, dynamic>> createOrUpdateProfile({
    required String userId,
    required String email,
    required String role,
    String? fullName,
    String? phone,
    String? vehicleType,
    String? licensePlate,
    String? avatarUrl,
    String? shopName,
    String? shopAddress,
    String? shopPhone,
  }) async {
    try {
      // ใช้เฉพาะ column ที่มีอยู่จริงใน profiles table
      // หมายเหตุ: ไม่มี column email, shop_name, shop_phone
      final profileData = {
        'id': userId,
        'role': role,
        'full_name': fullName ?? email.split('@')[0],
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Add only fields that exist in the actual schema
      await _addFieldIfExists(profileData, 'phone_number', phone);
      await _addFieldIfExists(profileData, 'vehicle_type', vehicleType);
      await _addFieldIfExists(profileData, 'license_plate', licensePlate);
      await _addFieldIfExists(profileData, 'avatar_url', avatarUrl);
      await _addFieldIfExists(profileData, 'shop_address', shopAddress);

      // Check if profile exists
      final existingProfile = await getProfileById(userId);
      
      Map<String, dynamic> response;
      if (existingProfile != null) {
        // Update existing profile
        response = await _client
            .from('profiles')
            .update(profileData)
            .eq('id', userId)
            .select()
            .single();
        debugLog('✅ Profile updated: $response');
      } else {
        // Create new profile
        profileData['created_at'] = DateTime.now().toIso8601String();
        response = await _client
            .from('profiles')
            .insert(profileData)
            .select()
            .single();
        debugLog('✅ Profile created: $response');
      }

      return response;
    } catch (e) {
      debugLog('❌ Failed to create/update profile: $e');
      throw Exception('Failed to create/update profile: $e');
    }
  }

  /// Direct upsert profile - bypasses column checking for signup flow
  /// This is more reliable when session may not be fully established
  Future<void> upsertProfileDirect({
    required String userId,
    required String email,
    required String role,
    String? fullName,
    String? phone,
    String? vehicleType,
    String? licensePlate,
    String? shopName,
    String? shopAddress,
    String? shopPhone,
  }) async {
    // profiles table columns (จาก schema จริง):
    // id, full_name, phone_number, role, created_at, updated_at,
    // vehicle_model, license_plate, is_online, shop_status, address,
    // latitude, longitude, avatar_url, fcm_token, approval_status,
    // approved_at, approved_by, rejection_reason, driver_license_url,
    // vehicle_registration_url, vehicle_type, vehicle_plate,
    // shop_license_url, shop_photo_url, shop_address,
    // bank_name, bank_account_number, bank_account_name,
    // admin_permissions, admin_level
    // หมายเหตุ: ไม่มี column email, shop_name, shop_phone
    final profileData = <String, dynamic>{
      'id': userId,
      'role': role,
      'full_name': fullName ?? email.split('@')[0],
      'updated_at': DateTime.now().toIso8601String(),
      'created_at': DateTime.now().toIso8601String(),
    };

    // Add only fields that exist in the actual schema
    if (phone != null && phone.isNotEmpty) profileData['phone_number'] = phone;
    if (vehicleType != null && vehicleType.isNotEmpty) profileData['vehicle_type'] = vehicleType;
    if (licensePlate != null && licensePlate.isNotEmpty) profileData['license_plate'] = licensePlate;
    if (shopAddress != null && shopAddress.isNotEmpty) profileData['shop_address'] = shopAddress;

    // Set approval_status based on role
    if (role == 'driver' || role == 'merchant') {
      profileData['approval_status'] = 'pending';
    } else {
      profileData['approval_status'] = 'approved';
    }

    debugLog('═══ [ProfileService.upsertProfileDirect] ═══');
    debugLog('📝 userId: $userId');
    debugLog('📝 role: $role');
    debugLog('📝 approval_status: ${profileData['approval_status']}');
    debugLog('📝 profileData keys: ${profileData.keys.toList()}');
    debugLog('📝 profileData: $profileData');
    
    // ตรวจสอบ session ปัจจุบัน
    try {
      final currentSession = Supabase.instance.client.auth.currentSession;
      final currentUser = Supabase.instance.client.auth.currentUser;
      debugLog('🔑 Current session: ${currentSession != null ? "มี" : "ไม่มี"}');
      debugLog('🔑 Current user: ${currentUser?.id ?? "null"}');
      debugLog('🔑 auth.uid จะเป็น: ${currentUser?.id ?? "null (RLS อาจบล็อก!)"}');
    } catch (sessionErr) {
      debugLog('⚠️ ไม่สามารถตรวจสอบ session: $sessionErr');
    }

    try {
      await _client
          .from('profiles')
          .upsert(profileData, onConflict: 'id');
      debugLog('✅ Profile upserted สำเร็จสำหรับ $userId (role: $role)');
    } catch (upsertError) {
      debugLog('❌ Profile upsert ล้มเหลว!');
      debugLog('   Error: $upsertError');
      debugLog('   Type: ${upsertError.runtimeType}');
      rethrow;
    }
    debugLog('═══ [ProfileService.upsertProfileDirect] จบ ═══');
  }

  /// Update specific profile fields
  Future<Map<String, dynamic>> updateProfile({
    required String userId,
    String? fullName,
    String? phone,
    String? vehicleType,
    String? licensePlate,
    String? avatarUrl,
    String? shopName,
    String? shopAddress,
    String? shopPhone,
  }) async {
    try {
      final updateData = {
        'updated_at': DateTime.now().toIso8601String(),
      };

      // Safely add fields only if columns exist
      if (fullName != null && fullName.isNotEmpty) {
        updateData['full_name'] = fullName;
      }
      await _addFieldIfExists(updateData, 'phone_number', phone);
      await _addFieldIfExists(updateData, 'vehicle_type', vehicleType);
      await _addFieldIfExists(updateData, 'license_plate', licensePlate);
      await _addFieldIfExists(updateData, 'avatar_url', avatarUrl);
      await _addFieldIfExists(updateData, 'shop_address', shopAddress);

      final response = await _client
          .from('profiles')
          .update(updateData)
          .eq('id', userId)
          .select()
          .single();

      debugLog('✅ Profile updated: $response');
      return response;
    } catch (e) {
      debugLog('❌ Failed to update profile: $e');
      throw Exception('Failed to update profile: $e');
    }
  }

  /// Delete user profile
  Future<void> deleteProfile(String userId) async {
    try {
      await _client
          .from('profiles')
          .delete()
          .eq('id', userId);

      debugLog('✅ Profile deleted: $userId');
    } catch (e) {
      debugLog('❌ Failed to delete profile: $e');
      throw Exception('Failed to delete profile: $e');
    }
  }

  /// Get all profiles by role
  Future<List<Map<String, dynamic>>> getProfilesByRole(String role) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('role', role)
          .order('created_at', ascending: false);

      debugLog('📋 Profiles fetched for role $role: ${response.length} items');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugLog('❌ Failed to fetch profiles by role: $e');
      throw Exception('Failed to fetch profiles by role: $e');
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

  /// Get user's phone
  Future<String?> getUserPhone() async {
    final profile = await getCurrentProfile();
    return profile?['phone_number'] as String?;
  }

  /// Get user's vehicle type
  Future<String?> getUserVehicleType() async {
    final profile = await getCurrentProfile();
    return profile?['vehicle_type'] as String?;
  }

  /// Get user's license plate
  Future<String?> getUserLicensePlate() async {
    final profile = await getCurrentProfile();
    return profile?['license_plate'] as String?;
  }

  /// Search profiles by name or email
  Future<List<Map<String, dynamic>>> searchProfiles(String query) async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .or('full_name.ilike.%$query%,email.ilike.%$query%')
          .order('full_name');

      debugLog('📋 Search results for "$query": ${response.length} items');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugLog('❌ Failed to search profiles: $e');
      throw Exception('Failed to search profiles: $e');
    }
  }
}
