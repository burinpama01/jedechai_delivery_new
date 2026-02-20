import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/menu_option.dart';

/// Menu Option Service
/// 
/// Handles all menu option-related database operations
class MenuOptionService {
  SupabaseClient get _client {
    return Supabase.instance.client;
  }

  /// Get all option groups for a menu item
  Future<List<MenuOptionGroup>> getOptionGroupsForMenuItem(String menuItemId) async {
    try {
      debugLog('🔍 Getting option groups for menu item: $menuItemId');
      
      final response = await _client
          .from('menu_item_option_links')
          .select('*, menu_option_groups(*, menu_options(*))')
          .eq('menu_item_id', menuItemId)
          .order('sort_order');

      debugLog('📊 Found ${response.length} option group links');
      
      final groups = <MenuOptionGroup>[];
      for (final link in response) {
        final groupData = link['menu_option_groups'];
        if (groupData != null && groupData is Map<String, dynamic> && groupData.isNotEmpty) {
          groups.add(MenuOptionGroup.fromJson(groupData));
        }
      }
      
      return groups;
    } catch (e) {
      debugLog('❌ Error getting option groups: $e');
      return [];
    }
  }

  /// Get all options for a specific group
  Future<List<MenuOption>> getOptionsForGroup(String groupId) async {
    try {
      debugLog('🔍 Getting options for group: $groupId');
      
      final response = await _client
          .from('menu_options')
          .select('*')
          .eq('group_id', groupId)
          .eq('is_available', true)
          .order('name');

      debugLog('📊 Found ${response.length} options');
      
      return (response as List)
          .map((option) => MenuOption.fromJson(option))
          .toList();
    } catch (e) {
      debugLog('❌ Error getting options: $e');
      return [];
    }
  }

  /// Create a new option group
  Future<MenuOptionGroup?> createOptionGroup({
    required String merchantId,
    required String name,
    required int minSelection,
    required int maxSelection,
  }) async {
    try {
      debugLog('🔧 Creating option group: $name for merchant: $merchantId');
      
      final response = await _client
          .from('menu_option_groups')
          .insert({
            'merchant_id': merchantId,
            'name': name,
            'min_selection': minSelection,
            'max_selection': maxSelection,
          })
          .select()
          .single();

      debugLog('✅ Option group created: ${response['id']}');
      
      return MenuOptionGroup.fromJson(response);
    } catch (e) {
      debugLog('❌ Error creating option group: $e');
      return null;
    }
  }

  /// Update an option group
  Future<bool> updateOptionGroup({
    required String groupId,
    String? name,
    int? minSelection,
    int? maxSelection,
  }) async {
    try {
      debugLog('🔧 Updating option group: $groupId');
      
      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (minSelection != null) updateData['min_selection'] = minSelection;
      if (maxSelection != null) updateData['max_selection'] = maxSelection;

      await _client
          .from('menu_option_groups')
          .update(updateData)
          .eq('id', groupId);

      debugLog('✅ Option group updated: $groupId');
      return true;
    } catch (e) {
      debugLog('❌ Error updating option group: $e');
      return false;
    }
  }

  /// Link an option group to a menu item
  Future<bool> linkOptionGroupToMenu({
    required String menuItemId,
    required String groupId,
    int sortOrder = 0,
  }) async {
    try {
      debugLog('🔗 Linking option group $groupId to menu item $menuItemId');
      
      await _client
          .from('menu_item_option_links')
          .insert({
            'menu_item_id': menuItemId,
            'option_group_id': groupId,
            'sort_order': sortOrder,
          });

      debugLog('✅ Option group linked successfully');
      return true;
    } catch (e) {
      debugLog('❌ Error linking option group to menu: $e');
      return false;
    }
  }

  /// Unlink an option group from a menu item
  Future<bool> unlinkOptionGroupFromMenu({
    required String menuItemId,
    required String groupId,
  }) async {
    try {
      debugLog('🔓 Unlinking option group $groupId from menu item $menuItemId');
      
      await _client
          .from('menu_item_option_links')
          .delete()
          .eq('menu_item_id', menuItemId)
          .eq('option_group_id', groupId);

      debugLog('✅ Option group unlinked successfully');
      return true;
    } catch (e) {
      debugLog('❌ Error unlinking option group from menu: $e');
      return false;
    }
  }

  /// Update sort order of option groups for a menu item
  Future<bool> updateOptionGroupSortOrder({
    required String menuItemId,
    required List<Map<String, dynamic>> sortOrderUpdates,
  }) async {
    try {
      debugLog('🔄 Updating sort order for ${sortOrderUpdates.length} option groups');
      
      for (final update in sortOrderUpdates) {
        await _client
            .from('menu_item_option_links')
            .update({'sort_order': update['sort_order']})
            .eq('menu_item_id', menuItemId)
            .eq('option_group_id', update['group_id']);
      }

      debugLog('✅ Sort order updated successfully');
      return true;
    } catch (e) {
      debugLog('❌ Error updating sort order: $e');
      return false;
    }
  }

  /// Delete an option group (cascade will handle options and links)
  Future<void> deleteOptionGroup(String groupId) async {
    try {
      debugLog('🗑️ Deleting option group: $groupId');
      
      await _client
          .from('menu_option_groups')
          .delete()
          .eq('id', groupId);

      debugLog('✅ Option group deleted: $groupId (cascade handled options and links)');
    } catch (e) {
      debugLog('❌ Error deleting option group: $e');
      throw Exception('Failed to delete option group: $e');
    }
  }

  /// Create a new menu option
  Future<MenuOption?> createOption({
    required String groupId,
    required String name,
    required int price,
    bool isAvailable = true,
  }) async {
    try {
      debugLog('🔧 Creating menu option: $name');
      
      final response = await _client
          .from('menu_options')
          .insert({
            'group_id': groupId,
            'name': name,
            'price': price,
            'is_available': isAvailable,
          })
          .select()
          .single();

      debugLog('✅ Menu option created: ${response['id']}');
      
      return MenuOption.fromJson(response);
    } catch (e) {
      debugLog('❌ Error creating menu option: $e');
      return null;
    }
  }

  /// Update a menu option
  Future<bool> updateOption({
    required String optionId,
    String? name,
    int? price,
    bool? isAvailable,
  }) async {
    try {
      debugLog('🔧 Updating menu option: $optionId');
      
      final updateData = <String, dynamic>{};
      if (name != null) updateData['name'] = name;
      if (price != null) updateData['price'] = price;
      if (isAvailable != null) updateData['is_available'] = isAvailable;

      await _client
          .from('menu_options')
          .update(updateData)
          .eq('id', optionId);

      debugLog('✅ Menu option updated: $optionId');
      return true;
    } catch (e) {
      debugLog('❌ Error updating menu option: $e');
      return false;
    }
  }

  /// Delete a menu option
  Future<bool> deleteOption(String optionId) async {
    try {
      debugLog('🗑️ Deleting menu option: $optionId');
      
      await _client
          .from('menu_options')
          .delete()
          .eq('id', optionId);

      debugLog('✅ Menu option deleted: $optionId');
      return true;
    } catch (e) {
      debugLog('❌ Error deleting menu option: $e');
      return false;
    }
  }

  /// Toggle option availability
  Future<bool> toggleOptionAvailability(String optionId) async {
    try {
      debugLog('🔄 Toggling option availability: $optionId');
      
      final response = await _client
          .from('menu_options')
          .select('is_available')
          .eq('id', optionId)
          .single();

      final currentAvailability = response['is_available'] as bool;
      
      await _client
          .from('menu_options')
          .update({'is_available': !currentAvailability})
          .eq('id', optionId);

      debugLog('✅ Option availability toggled: $optionId -> ${!currentAvailability}');
      return true;
    } catch (e) {
      debugLog('❌ Error toggling option availability: $e');
      return false;
    }
  }

  /// Calculate total price with selected options
  Future<int> calculateTotalPrice({
    required String menuItemId,
    required List<String> selectedOptionIds,
  }) async {
    try {
      debugLog('💰 Calculating total price for menu item: $menuItemId');
      debugLog('   └─ Selected options: ${selectedOptionIds.length}');
      
      final response = await _client
          .rpc('calculate_menu_item_price', params: {
            'p_menu_item_id': menuItemId,
            'p_selected_option_ids': selectedOptionIds.isEmpty ? null : selectedOptionIds,
          });

      final totalPrice = response as int;
      debugLog('   └─ Total price: ฿$totalPrice');
      
      return totalPrice;
    } catch (e) {
      debugLog('❌ Error calculating total price: $e');
      return 0;
    }
  }

  /// Validate option selections
  Future<bool> validateOptionSelections({
    required String menuItemId,
    required List<String> selectedOptionIds,
  }) async {
    try {
      debugLog('🔍 Validating option selections for menu item: $menuItemId');
      debugLog('   └─ Selected options: ${selectedOptionIds.length}');
      
      final response = await _client
          .rpc('validate_option_selections', params: {
            'p_menu_item_id': menuItemId,
            'p_selected_option_ids': selectedOptionIds.isEmpty ? null : selectedOptionIds,
          });

      final isValid = response as bool;
      debugLog('   └─ Validation result: ${isValid ? 'Valid' : 'Invalid'}');
      
      return isValid;
    } catch (e) {
      debugLog('❌ Error validating option selections: $e');
      return false;
    }
  }

  /// Get menu item with all options (using menu_item_option_links)
  Future<MenuItemWithOptions?> getMenuItemWithOptions(String menuItemId) async {
    try {
      debugLog('🔍 Getting menu item with options: $menuItemId');
      
      // Get menu item details
      final menuItemResponse = await _client
          .from('menu_items')
          .select('*')
          .eq('id', menuItemId)
          .single();

      // Get option groups with options from menu_item_option_links
      final response = await _client
          .from('menu_item_option_links')
          .select('''
            *,
            menu_option_groups!inner(
              *,
              menu_options(*)
            )
          ''')
          .eq('menu_item_id', menuItemId)
          .order('sort_order')
          .order('menu_option_groups(name)');

      debugLog('📊 Found ${response.length} option group links');
      
      // Debug: Print the actual response structure
      for (int i = 0; i < response.length; i++) {
        final link = response[i];
        debugLog('📋 Link $i: ${link.keys.toList()}');
        if (link['menu_option_groups'] != null) {
          final group = link['menu_option_groups'] as Map<String, dynamic>;
          debugLog('   └─ Group: ${group.keys.toList()}');
          if (group['menu_options'] != null) {
            final options = group['menu_options'] as List;
            debugLog('   └─ Options count: ${options.length}');
            for (int j = 0; j < options.length; j++) {
              final option = options[j];
              debugLog('      └─ Option $j: ${option['name']} (฿${option['price']})');
            }
          } else {
            debugLog('   └─ No options field found');
          }
        } else {
          debugLog('   └─ No menu_option_groups field found');
        }
      }
      
      // Create MenuItemWithOptions with the new structure
      final menuItemWithOptions = MenuItemWithOptions.fromJson(menuItemResponse, response);

      debugLog('✅ Menu item with options loaded');
      return menuItemWithOptions;
    } catch (e) {
      debugLog('❌ Error getting menu item with options: $e');
      return null;
    }
  }

  /// Get all option groups for a merchant
  Future<List<MenuOptionGroup>> getMerchantOptionGroups(String merchantId) async {
    try {
      debugLog('🔍 Getting option groups for merchant: $merchantId');
      
      final response = await _client
          .from('menu_option_groups')
          .select('''
            *,
            menu_options(*)
          ''')
          .eq('merchant_id', merchantId)
          .order('name');

      debugLog('📊 Found ${response.length} option groups for merchant');
      
      // Debug: Print the actual response structure
      for (int i = 0; i < response.length; i++) {
        final group = response[i];
        debugLog('📋 Group $i: ${group.keys.toList()}');
        if (group['menu_options'] != null) {
          final options = group['menu_options'] as List;
          debugLog('   └─ Options count: ${options.length}');
          for (int j = 0; j < options.length; j++) {
            final option = options[j];
            debugLog('      └─ Option $j: ${option['name']} (฿${option['price']})');
          }
        } else {
          debugLog('   └─ No menu_options field found');
        }
      }
      
      return (response as List)
          .map((group) => MenuOptionGroup.fromJson(group))
          .toList();
    } catch (e) {
      debugLog('❌ Error getting merchant option groups: $e');
      return [];
    }
  }

  /// Get option groups for a merchant (alias for getMerchantOptionGroups)
  Future<List<MenuOptionGroup>> getOptionGroupsForMerchant(String merchantId) async {
    return getMerchantOptionGroups(merchantId);
  }

  /// Bulk update option group order
  Future<bool> updateOptionGroupOrder(List<Map<String, dynamic>> groupUpdates) async {
    try {
      debugLog('🔧 Updating option group order for ${groupUpdates.length} groups');
      
      for (final update in groupUpdates) {
        await _client
            .from('menu_option_groups')
            .update({'updated_at': DateTime.now().toIso8601String()})
            .eq('id', update['id']);
      }

      debugLog('✅ Option group order updated');
      return true;
    } catch (e) {
      debugLog('❌ Error updating option group order: $e');
      return false;
    }
  }

  /// Clone option groups from one menu item to another
  Future<bool> cloneOptionGroups(String fromMenuItemId, String toMenuItemId) async {
    try {
      debugLog('🔄 Cloning option groups from $fromMenuItemId to $toMenuItemId');
      
      final originalGroups = await getOptionGroupsForMenuItem(fromMenuItemId);
      
      for (final group in originalGroups) {
        // Link existing group to the new menu item
        await linkOptionGroupToMenu(
          menuItemId: toMenuItemId,
          groupId: group.id,
          sortOrder: 0, // You might want to preserve original sort order
        );
      }

      debugLog('✅ Option groups cloned successfully');
      return true;
    } catch (e) {
      debugLog('❌ Error cloning option groups: $e');
      return false;
    }
  }

  /// Get menu items that use a specific option group
  Future<List<Map<String, dynamic>>> getMenuItemsForOptionGroup(String groupId) async {
    try {
      debugLog('🔍 Getting menu items for option group: $groupId');
      
      final response = await _client
          .from('menu_item_option_links')
          .select('''
            menu_item_id,
            sort_order,
            menu_items!inner(*)
          ''')
          .eq('option_group_id', groupId)
          .order('sort_order');

      debugLog('📊 Found ${response.length} menu items using this option group');
      
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugLog('❌ Error getting menu items for option group: $e');
      return [];
    }
  }

  /// Search options by name
  Future<List<MenuOption>> searchOptions(String query, {String? groupId}) async {
    try {
      debugLog('🔍 Searching options: $query');
      
      var queryBuilder = _client
          .from('menu_options')
          .select('*')
          .ilike('name', '%$query%')
          .eq('is_available', true);

      if (groupId != null) {
        queryBuilder = queryBuilder.eq('group_id', groupId);
      }

      final response = await queryBuilder.order('name').limit(50);

      debugLog('📊 Found ${response.length} matching options');
      
      return (response as List)
          .map((option) => MenuOption.fromJson(option))
          .toList();
    } catch (e) {
      debugLog('❌ Error searching options: $e');
      return [];
    }
  }
}
