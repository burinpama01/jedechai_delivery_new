import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import '../../../../common/services/menu_option_service.dart';
import '../../../../common/models/menu_option.dart';
import '../../../../theme/app_theme.dart';

/// Merchant Option Group Detail Screen
/// 
/// Allows merchants to create or edit option groups and their options
/// Features: Create/Update group, Add/Remove options, Price management
class MerchantOptionGroupDetailScreen extends StatefulWidget {
  final String merchantId;
  final MenuOptionGroup? group;

  const MerchantOptionGroupDetailScreen({
    Key? key,
    required this.merchantId,
    this.group,
  }) : super(key: key);

  @override
  State<MerchantOptionGroupDetailScreen> createState() => _MerchantOptionGroupDetailScreenState();
}

class _MerchantOptionGroupDetailScreenState extends State<MerchantOptionGroupDetailScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _minSelectionController = TextEditingController(text: '0');
  final _maxSelectionController = TextEditingController(text: '1');
  
  final _optionNameController = TextEditingController();
  final _optionPriceController = TextEditingController(text: '0');
  
  List<MenuOption> _options = [];
  // ignore: unused_field
  bool _isLoading = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    if (widget.group != null) {
      // Edit mode
      _nameController.text = widget.group!.name;
      _minSelectionController.text = widget.group!.minSelection.toString();
      _maxSelectionController.text = widget.group!.maxSelection.toString();
      
      debugLog('🔍 Loading existing group: ${widget.group!.name}');
      debugLog('📋 Existing options count: ${widget.group!.options?.length ?? 0}');
      
      _options = widget.group!.options ?? [];
      
      debugLog('📊 Loaded options for editing:');
      for (int i = 0; i < _options.length; i++) {
        final option = _options[i];
        debugLog('   └─ Option $i: ${option.name} (฿${option.price})');
      }
    }
  }

  Future<void> _saveGroup() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final minSelection = int.parse(_minSelectionController.text);
      final maxSelection = int.parse(_maxSelectionController.text);

      // Validate min/max selection
      if (minSelection < 0 || maxSelection < 1) {
        throw Exception('ค่าต่ำสุดต้องไม่ต่ำกว่า 0 และค่าสูงสุดต้องไม่ต่ำกว่า 1');
      }

      if (minSelection > maxSelection) {
        throw Exception('ค่าต่ำสุดต้องไม่มากกว่าค่าสูงสุด');
      }

      MenuOptionGroup? savedGroup;

      if (widget.group == null) {
        // Create new group
        savedGroup = await MenuOptionService().createOptionGroup(
          merchantId: widget.merchantId,
          name: name,
          minSelection: minSelection,
          maxSelection: maxSelection,
        );
      } else {
        // Update existing group
        await MenuOptionService().updateOptionGroup(
          groupId: widget.group!.id,
          name: name,
          minSelection: minSelection,
          maxSelection: maxSelection,
        );
        savedGroup = widget.group!;
      }

      if (savedGroup == null) {
        throw Exception('ไม่สามารถบันทึกกลุ่มตัวเลือกได้');
      }

      // Save options
      await _saveOptions(savedGroup.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.group == null 
                ? '✅ สร้างกลุ่มตัวเลือกเรียบร้อย'
                : '✅ อัปเดตกลุ่มตัวเลือกเรียบร้อย'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  Future<void> _saveOptions(String groupId) async {
    // Delete existing options (if editing)
    if (widget.group != null) {
      for (final option in widget.group!.options ?? []) {
        await MenuOptionService().deleteOption(option.id);
      }
    }

    // Create new options
    for (final option in _options) {
      await MenuOptionService().createOption(
        groupId: groupId,
        name: option.name,
        price: option.price,
        isAvailable: option.isAvailable,
      );
    }
  }

  void _addOption() {
    final name = _optionNameController.text.trim();
    final priceText = _optionPriceController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ กรุณากรอกชื่อตัวเลือก'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    final price = int.tryParse(priceText) ?? 0;
    if (price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('❌ ราคาต้องไม่ติดลบ'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _options.add(MenuOption(
        id: '', // Will be set by database
        groupId: '', // Will be set by database
        name: name,
        price: price,
        isAvailable: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    });

    // Clear input fields
    _optionNameController.clear();
    _optionPriceController.text = '0';
  }

  void _removeOption(int index) {
    setState(() {
      _options.removeAt(index);
    });
  }

  void _toggleOptionAvailability(int index) {
    setState(() {
      _options[index] = _options[index].copyWith(
        isAvailable: !_options[index].isAvailable,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.group != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'แก้ไขกลุ่มตัวเลือก' : 'สร้างกลุ่มตัวเลือก'),
        backgroundColor: AppTheme.accentOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: _deleteGroup,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Group Information
                    _buildGroupInfoSection(),
                    const SizedBox(height: 24),

                    // Add Option Section
                    _buildAddOptionSection(),
                    const SizedBox(height: 24),

                    // Options List
                    _buildOptionsList(),
                    const SizedBox(height: 100), // Space for save button
                  ],
                ),
              ),
            ),

            // Save Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveGroup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentOrange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            isEditing ? 'อัปเดตกลุ่มตัวเลือก' : 'สร้างกลุ่มตัวเลือก',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ข้อมูลกลุ่มตัวเลือก',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        // Group Name
        TextFormField(
          controller: _nameController,
          decoration: const InputDecoration(
            labelText: 'ชื่อกลุ่มตัวเลือก',
            hintText: 'เช่น ระดับความเผ็ด, ท็อปปิ้ง',
            border: OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return 'กรุณากรอกชื่อกลุ่มตัวเลือก';
            }
            return null;
          },
        ),
        const SizedBox(height: 16),

        // Selection Constraints
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _minSelectionController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'เลือกขั้นต่ำ',
                  hintText: '0',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณากรอกจำนวนขั้นต่ำ';
                  }
                  final num = int.tryParse(value);
                  if (num == null || num < 0) {
                    return 'กรุณากรอกจำนวนที่ถูกต้อง';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _maxSelectionController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'เลือกสูงสุด',
                  hintText: '1',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'กรุณากรอกจำนวนสูงสุด';
                  }
                  final num = int.tryParse(value);
                  if (num == null || num < 1) {
                    return 'กรุณากรอกจำนวนที่ถูกต้อง (อย่างน้อย 1)';
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'คำแนะนำ: 0=ไม่จำเป็นต้องเลือก, 1=ต้องเลือก 1 รายการ',
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

  Widget _buildAddOptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'เพิ่มตัวเลือก',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        Row(
          children: [
            // Option Name
            Expanded(
              flex: 2,
              child: TextFormField(
                controller: _optionNameController,
                decoration: const InputDecoration(
                  labelText: 'ชื่อตัวเลือก',
                  hintText: 'เช่น ไม่เผ็ด, เผ็ดมาก',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Option Price
            SizedBox(
              width: 100,
              child: TextFormField(
                controller: _optionPriceController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'ราคาเพิ่ม',
                  hintText: '0',
                  prefixText: '฿',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 12),
            
            // Add Button
            ElevatedButton(
              onPressed: _addOption,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentOrange,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              ),
              child: const Icon(Icons.add),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOptionsList() {
    if (_options.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade300),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.list_alt,
              size: 48,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'ยังไม่มีตัวเลือก',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'เพิ่มตัวเลือกเพื่อให้ลูกค้าเลือกจากกลุ่มนี้',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'ตัวเลือกทั้งหมด',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            Text(
              '${_options.length} รายการ',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        
        ..._options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          return OptionCard(
            option: option,
            onRemove: () => _removeOption(index),
            onToggleAvailability: () => _toggleOptionAvailability(index),
          );
        }),
      ],
    );
  }

  Future<void> _deleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ยืนยันการลบ'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('คุณต้องการลบกลุ่ม "${widget.group!.name}" ใช่หรือไม่?'),
            const SizedBox(height: 8),
            Text(
              'หมายเหตุ: การลบกลุ่มนี้จะลบตัวเลือกทั้งหมดและลบออกจากเมนูที่ใช้งานอยู่',
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

    if (confirmed) {
      try {
        await MenuOptionService().deleteOptionGroup(widget.group!.id);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('✅ ลบกลุ่ม "${widget.group!.name}" เรียบร้อย'),
              backgroundColor: Colors.green,
            ),
          );
          Navigator.of(context).pop(true);
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
  }
}

class OptionCard extends StatelessWidget {
  final MenuOption option;
  final VoidCallback onRemove;
  final VoidCallback onToggleAvailability;

  const OptionCard({
    Key? key,
    required this.option,
    required this.onRemove,
    required this.onToggleAvailability,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Availability Toggle
            GestureDetector(
              onTap: onToggleAvailability,
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: option.isAvailable ? Colors.green : Colors.grey,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  option.isAvailable ? Icons.check : Icons.close,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            const SizedBox(width: 16),
            
            // Option Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    option.name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: option.isAvailable ? Colors.black : Colors.grey,
                    ),
                  ),
                  if (option.price > 0)
                    Text(
                      '+฿${option.price}',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppTheme.accentOrange,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                ],
              ),
            ),
            
            // Remove Button
            IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
