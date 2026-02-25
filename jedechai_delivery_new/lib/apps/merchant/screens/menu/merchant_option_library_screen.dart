import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import '../../../../common/services/menu_option_service.dart';
import '../../../../common/models/menu_option.dart';
import 'merchant_option_group_detail_screen.dart';
import '../../../../theme/app_theme.dart';

/// Merchant Option Library Screen
/// 
/// Allows merchants to manage their reusable option groups
/// Features: List, Create, Edit, Delete option groups
class MerchantOptionLibraryScreen extends StatefulWidget {
  final String merchantId;

  const MerchantOptionLibraryScreen({
    Key? key,
    required this.merchantId,
  }) : super(key: key);

  @override
  State<MerchantOptionLibraryScreen> createState() => _MerchantOptionLibraryScreenState();
}

class _MerchantOptionLibraryScreenState extends State<MerchantOptionLibraryScreen> {
  List<MenuOptionGroup> _optionGroups = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadOptionGroups();
  }

  Future<void> _loadOptionGroups() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final groups = await MenuOptionService().getOptionGroupsForMerchant(widget.merchantId);
      
      if (mounted) {
        setState(() {
          _optionGroups = groups;
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

  Future<void> _deleteOptionGroup(MenuOptionGroup group) async {
    final confirmed = await _showDeleteConfirmation(group);
    if (!confirmed) return;

    try {
      await MenuOptionService().deleteOptionGroup(group.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ลบกลุ่ม "${group.name}" เรียบร้อย'),
            backgroundColor: Colors.green,
          ),
        );
        _loadOptionGroups();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ ลบกลุ่มไม่สำเร็จ: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<bool> _showDeleteConfirmation(MenuOptionGroup group) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('คุณต้องการลบกลุ่ม "${group.name}" ใช่หรือไม่?'),
            const SizedBox(height: 8),
            if (group.options != null && group.options!.isNotEmpty)
              Text(
                'หมายเหตุ: การลบกลุ่มนี้จะลบตัวเลือกทั้งหมด ${group.options!.length} รายการ',
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: 12,
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('ลบ'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _navigateToDetailScreen({MenuOptionGroup? group}) {
    debugLog('🔍 Navigating to detail screen:');
    if (group != null) {
      debugLog('📋 Edit mode - Group: ${group.name}');
      debugLog('📊 Options count: ${group.options?.length ?? 0}');
      if (group.options != null) {
        for (int i = 0; i < group.options!.length; i++) {
          final option = group.options![i];
          debugLog('   └─ Option $i: ${option.name} (฿${option.price})');
        }
      }
    } else {
      debugLog('➕ Create mode - New group');
    }
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => MerchantOptionGroupDetailScreen(
          merchantId: widget.merchantId,
          group: group,
        ),
      ),
    ).then((_) => _loadOptionGroups());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('จัดการตัวเลือกอาหาร'),
        backgroundColor: AppTheme.accentOrange,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _navigateToDetailScreen(),
        backgroundColor: AppTheme.accentOrange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
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
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadOptionGroups,
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    if (_optionGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'ยังไม่มีกลุ่มตัวเลือก',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'สร้างกลุ่มตัวเลือกเพื่อนำไปใช้กับเมนูอาหารของคุณ',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: () => _navigateToDetailScreen(),
              icon: const Icon(Icons.add),
              label: const Text('สร้างกลุ่มใหม่'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentOrange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOptionGroups,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _optionGroups.length,
        itemBuilder: (context, index) {
          final group = _optionGroups[index];
          return OptionGroupCard(
            group: group,
            onTap: () => _navigateToDetailScreen(group: group),
            onDelete: () => _deleteOptionGroup(group),
          );
        },
      ),
    );
  }
}

class OptionGroupCard extends StatelessWidget {
  final MenuOptionGroup group;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  const OptionGroupCard({
    Key? key,
    required this.group,
    required this.onTap,
    required this.onDelete,
  }) : super(key: key);

  String _getSelectionText() {
    final min = group.minSelection;
    final max = group.maxSelection;
    
    if (min == 0 && max == 1) {
      return 'เลือกได้ 1 รายการ';
    } else if (min == 0 && max > 1) {
      return 'เลือกได้สูงสุด $max รายการ';
    } else if (min == max) {
      return 'เลือก $min รายการ';
    } else {
      return 'เลือก $min-$max รายการ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final optionCount = group.options?.length ?? 0;
    
    return Card(
      elevation: 4,
      margin: const EdgeInsets.only(bottom: 16),
      child: Dismissible(
        key: Key(group.id),
        direction: DismissDirection.endToStart,
        background: Container(
          color: Colors.red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(
            Icons.delete,
            color: Colors.white,
            size: 24,
          ),
        ),
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            onDelete();
            return false; // We handle deletion ourselves
          }
          return false;
        },
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    // Icon
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppTheme.accentOrange.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getGroupIcon(),
                        color: AppTheme.accentOrange,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    
                    // Group info
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            group.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _getSelectionText(),
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Arrow
                    Icon(
                      Icons.arrow_forward_ios,
                      size: 16,
                      color: Colors.grey[400],
                    ),
                  ],
                ),
                
                // Options preview
                if (optionCount > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'ตัวเลือก $optionCount รายการ',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                            const Spacer(),
                            if (optionCount > 3)
                              Text(
                                'แสดง 3 รายการแรก',
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey[500],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...group.options!.take(3).map((option) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Container(
                                width: 4,
                                height: 4,
                                decoration: BoxDecoration(
                                  color: AppTheme.accentOrange,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  option.name,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              if (option.price > 0)
                                Text(
                                  '+฿${option.price}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: AppTheme.accentOrange,
                                  ),
                                ),
                            ],
                          ),
                        )),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  IconData _getGroupIcon() {
    final name = group.name.toLowerCase();
    if (name.contains('หวาน') || name.contains('sweet')) return Icons.cake;
    if (name.contains('เผ็ด') || name.contains('spicy')) return Icons.local_fire_department;
    if (name.contains('ท็อปปิ้ง') || name.contains('topping')) return Icons.add_circle;
    if (name.contains('ขนาด') || name.contains('size')) return Icons.straighten;
    if (name.contains('เนื้อ') || name.contains('meat')) return Icons.lunch_dining;
    return Icons.category;
  }
}
