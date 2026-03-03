import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import '../../../l10n/app_localizations.dart';
import 'menu/merchant_add_edit_menu_screen.dart';
import 'menu/merchant_option_library_screen.dart';
import '../../../common/widgets/app_network_image.dart';

/// Menu Management Screen
/// 
/// Allows merchants to manage their food menu items
/// Features: Add, Edit, Delete menu items
class MenuManagementScreen extends StatefulWidget {
  const MenuManagementScreen({super.key});

  @override
  State<MenuManagementScreen> createState() => _MenuManagementScreenState();
}

class _MenuManagementScreenState extends State<MenuManagementScreen> {
  List<Map<String, dynamic>> _menuItems = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchMenuItems();
  }

  Future<void> _fetchMenuItems() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception(AppLocalizations.of(context)!.menuMgmtUserNotFound);
      }

      final response = await Supabase.instance.client
          .from('menu_items')
          .select('*')
          .eq('merchant_id', userId)
          .order('created_at', ascending: false);

      if (mounted) {
        setState(() {
          _menuItems = List<Map<String, dynamic>>.from(response);
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _showMenuItemDialog({Map<String, dynamic>? item}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MerchantAddEditMenuScreen(item: item),
      ),
    ).then((result) {
      if (result == true) {
        _fetchMenuItems();
      }
    });
  }

  Future<void> _deleteMenuItem(String itemId, String itemName) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context)!.menuMgmtDeleteConfirmTitle),
        content: Text(AppLocalizations.of(context)!.menuMgmtDeleteConfirmBody(itemName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(AppLocalizations.of(context)!.menuMgmtNo),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(AppLocalizations.of(context)!.menuMgmtYes),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await Supabase.instance.client
            .from('menu_items')
            .delete()
            .eq('id', itemId);

        _fetchMenuItems();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!.menuMgmtDeleteSuccess),
              backgroundColor: Theme.of(context).colorScheme.primary,
            ),
          );
        }
      } catch (e) {
        // FK constraint: menu item has been ordered → offer to hide instead
        final errStr = e.toString();
        if (errStr.contains('violates foreign key') || errStr.contains('RESTRICT') || errStr.contains('referenced') || errStr.contains('23503')) {
          if (mounted) {
            final hideInstead = await showDialog<bool>(
              context: context,
              builder: (ctx) => AlertDialog(
                title: Text(AppLocalizations.of(context)!.menuMgmtCannotDeleteTitle),
                content: Text(
                  AppLocalizations.of(context)!.menuMgmtCannotDeleteBody,
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(AppLocalizations.of(context)!.menuMgmtCancel)),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: Text(AppLocalizations.of(context)!.menuMgmtHideMenu, style: const TextStyle(color: AppTheme.accentOrange)),
                  ),
                ],
              ),
            );
            if (hideInstead == true) {
              await Supabase.instance.client
                  .from('menu_items')
                  .update({'is_available': false})
                  .eq('id', itemId);
              _fetchMenuItems();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(AppLocalizations.of(context)!.menuMgmtHideSuccess),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                  ),
                );
              }
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(AppLocalizations.of(context)!.menuMgmtDeleteFailed(e.toString())),
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
            );
          }
        }
      }
    }
  }

  Future<void> _toggleMenuAvailability(String itemId, bool currentValue) async {
    final newValue = !currentValue;
    try {
      // Optimistic UI update
      setState(() {
        final index = _menuItems.indexWhere((m) => m['id'] == itemId);
        if (index != -1) {
          _menuItems[index]['is_available'] = newValue;
        }
      });

      await Supabase.instance.client
          .from('menu_items')
          .update({'is_available': newValue})
          .eq('id', itemId);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue ? AppLocalizations.of(context)!.menuMgmtToggleOn : AppLocalizations.of(context)!.menuMgmtToggleOff),
            backgroundColor:
                newValue ? Theme.of(context).colorScheme.primary : Colors.grey,
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } catch (e) {
      // Revert on error
      setState(() {
        final index = _menuItems.indexWhere((m) => m['id'] == itemId);
        if (index != -1) {
          _menuItems[index]['is_available'] = currentValue;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.menuMgmtToggleFailed(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }

  String _formatPrice(double price) {
    return '฿${price.ceil()}';
  }

  void _navigateToOptionLibrary() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.menuMgmtUserNotFound),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MerchantOptionLibraryScreen(merchantId: userId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.menuMgmtTitle),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: _navigateToOptionLibrary,
            tooltip: AppLocalizations.of(context)!.menuMgmtOptionTooltip,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchMenuItems,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchMenuItems,
        child: _buildBody(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showMenuItemDialog(),
        backgroundColor: AppTheme.accentOrange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentOrange),
        ),
      );
    }

    if (_error != null) {
      final colorScheme = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.menuMgmtError,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchMenuItems,
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.primary,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: Text(AppLocalizations.of(context)!.menuMgmtRetry),
            ),
          ],
        ),
      );
    }

    if (_menuItems.isEmpty) {
      final colorScheme = Theme.of(context).colorScheme;
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 64,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.menuMgmtEmpty,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.menuMgmtEmptyHint,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _menuItems.length,
      itemBuilder: (context, index) {
        final item = _menuItems[index];
        return _buildMenuItemCard(item);
      },
    );
  }

  Widget _buildMenuItemCard(Map<String, dynamic> item) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Menu item image
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                color: colorScheme.surfaceContainerHighest,
              ),
              child: item['image_url'] != null && item['image_url'].isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AppNetworkImage(
                        imageUrl: item['image_url']?.toString(),
                        fit: BoxFit.cover,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      ),
                    )
                  : const GrayscaleLogoPlaceholder(
                      fit: BoxFit.contain,
                    ),
            ),
            const SizedBox(width: 16),
            
            // Menu item details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          item['name'] ?? AppLocalizations.of(context)!.menuMgmtNoName,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: colorScheme.onSurface,
                          ),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => _toggleMenuAvailability(
                          item['id'],
                          item['is_available'] == true,
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: item['is_available'] == true
                                ? AppTheme.accentOrange.withValues(alpha: 0.1)
                                : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                item['is_available'] == true
                                    ? Icons.toggle_on
                                    : Icons.toggle_off,
                                size: 20,
                                color: item['is_available'] == true
                                    ? AppTheme.accentOrange
                                    : Colors.grey,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                item['is_available'] == true ? AppLocalizations.of(context)!.menuMgmtAvailable : AppLocalizations.of(context)!.menuMgmtSoldOut,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: item['is_available'] == true
                                      ? AppTheme.accentOrange
                                      : Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  if (item['description'] != null && item['description'].isNotEmpty)
                    Text(
                      item['description'],
                      style: TextStyle(
                        fontSize: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        _formatPrice(item['price']?.toDouble() ?? 0.0),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.accentOrange,
                        ),
                      ),
                      if (item['category'] != null && item['category'].toString().isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: colorScheme.secondaryContainer,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item['category'],
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSecondaryContainer,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            
            // Action buttons
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _showMenuItemDialog(item: item);
                } else if (value == 'delete') {
                  _deleteMenuItem(item['id'], item['name'] ?? AppLocalizations.of(context)!.menuMgmtNoName);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      const Icon(Icons.edit, size: 18),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context)!.menuMgmtEdit),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      const Icon(Icons.delete, size: 18, color: Colors.red),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context)!.menuMgmtDelete, style: const TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
