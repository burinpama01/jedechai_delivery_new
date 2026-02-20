import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/debug_logger.dart';
import '../models/saved_address.dart';
import 'auth_service.dart';

/// Address Service
///
/// CRUD operations for saved addresses (home, work, other)
/// Table: saved_addresses
class AddressService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Get all saved addresses for current user
  Future<List<SavedAddress>> getAddresses() async {
    final userId = AuthService.userId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('saved_addresses')
          .select()
          .eq('user_id', userId)
          .order('label', ascending: true);

      return (response as List)
          .map((json) => SavedAddress.fromJson(json))
          .toList();
    } catch (e) {
      debugLog('❌ Error fetching saved addresses: $e');
      return [];
    }
  }

  /// Get address by label (e.g. 'home', 'work')
  Future<SavedAddress?> getAddressByLabel(String label) async {
    final userId = AuthService.userId;
    if (userId == null) return null;

    try {
      final response = await _client
          .from('saved_addresses')
          .select()
          .eq('user_id', userId)
          .eq('label', label)
          .maybeSingle();

      if (response == null) return null;
      return SavedAddress.fromJson(response);
    } catch (e) {
      debugLog('❌ Error fetching address by label: $e');
      return null;
    }
  }

  /// Save or update an address
  /// If an address with the same label already exists, it will be updated
  Future<SavedAddress?> saveAddress({
    required String label,
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    String? note,
    String? iconName,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) return null;

    try {
      // Check if address with this label already exists
      final existing = await getAddressByLabel(label);

      if (existing != null) {
        // Update existing
        final response = await _client
            .from('saved_addresses')
            .update({
              'name': name,
              'address': address,
              'latitude': latitude,
              'longitude': longitude,
              'note': note,
              'icon_name': iconName,
            })
            .eq('id', existing.id)
            .select()
            .single();

        debugLog('✅ Updated saved address: $label');
        return SavedAddress.fromJson(response);
      } else {
        // Insert new
        final response = await _client
            .from('saved_addresses')
            .insert({
              'user_id': userId,
              'label': label,
              'name': name,
              'address': address,
              'latitude': latitude,
              'longitude': longitude,
              'note': note,
              'icon_name': iconName,
            })
            .select()
            .single();

        debugLog('✅ Created saved address: $label');
        return SavedAddress.fromJson(response);
      }
    } catch (e) {
      debugLog('❌ Error saving address: $e');
      return null;
    }
  }

  /// Delete a saved address
  Future<bool> deleteAddress(String addressId) async {
    try {
      await _client
          .from('saved_addresses')
          .delete()
          .eq('id', addressId);

      debugLog('✅ Deleted saved address: $addressId');
      return true;
    } catch (e) {
      debugLog('❌ Error deleting address: $e');
      return false;
    }
  }
}
