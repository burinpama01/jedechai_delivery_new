import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
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
        throw Exception('ไม่พบข้อมูลผู้ใช้');
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
        title: const Text('ยืนยันการลบ'),
        content: Text('คุณต้องการลบเมนู "$itemName" ใช่หรือไม่?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ไม่'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('ใช่'),
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
            const SnackBar(
              content: Text('ลบเมนูสำเร็จ'),
              backgroundColor: AppTheme.accentOrange,
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
                title: const Text('ไม่สามารถลบเมนูได้'),
                content: const Text(
                  'เมนูนี้มีออเดอร์ที่เกี่ยวข้องอยู่จึงไม่สามารถลบได้\n\nต้องการซ่อนเมนูนี้แทนหรือไม่? (เปลี่ยนสถานะเป็น "หมด")',
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('ยกเลิก')),
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(true),
                    child: const Text('ซ่อนเมนู', style: TextStyle(color: AppTheme.accentOrange)),
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
                  const SnackBar(content: Text('ซ่อนเมนูสำเร็จ (เปลี่ยนเป็น "หมด")'), backgroundColor: AppTheme.accentOrange),
                );
              }
            }
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('ไม่สามารถลบเมนู: $e'), backgroundColor: Colors.red),
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
            content: Text(newValue ? 'เปิดการขายเมนูแล้ว' : 'ปิดการขายเมนูแล้ว'),
            backgroundColor: newValue ? AppTheme.accentOrange : Colors.grey,
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
          SnackBar(content: Text('เปลี่ยนสถานะไม่สำเร็จ: $e'), backgroundColor: Colors.red),
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
        const SnackBar(
          content: Text('ไม่พบข้อมูลผู้ใช้'),
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
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('จัดการเมนู'),
        backgroundColor: Colors.white,
        elevation: 0,
        foregroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.category),
            onPressed: _navigateToOptionLibrary,
            tooltip: 'จัดการตัวเลือก',
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
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              'เกิดข้อผิดพลาด',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchMenuItems,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentOrange,
                foregroundColor: Colors.white,
              ),
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    if (_menuItems.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_menu,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'ยังไม่มีเมนู',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w500,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'กดปุ่ม + เพื่อเพิ่มเมนูแรกของคุณ',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
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
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
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
                color: Colors.grey[200],
              ),
              child: item['image_url'] != null && item['image_url'].isNotEmpty
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: AppNetworkImage(
                        imageUrl: item['image_url']?.toString(),
                        fit: BoxFit.cover,
                        backgroundColor: Colors.grey[200],
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
                          item['name'] ?? 'ไม่มีชื่อ',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
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
                                item['is_available'] == true ? 'วางขาย' : 'หมด',
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
                        color: Colors.grey[600],
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
                            color: Colors.blue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            item['category'],
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.blue,
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
                  _deleteMenuItem(item['id'], item['name'] ?? 'เมนูนี้');
                }
              },
              itemBuilder: (context) => [
                const PopupMenuItem(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 18),
                      SizedBox(width: 8),
                      Text('แก้ไข'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text('ลบ', style: TextStyle(color: Colors.red)),
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
