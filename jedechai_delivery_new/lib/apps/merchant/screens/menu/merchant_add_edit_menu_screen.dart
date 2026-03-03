import 'dart:io';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../common/services/menu_option_service.dart';
import '../../../../common/services/image_picker_service.dart';
import '../../../../common/services/storage_service.dart';
import '../../../../common/models/menu_option.dart';
import '../../../../common/widgets/app_network_image.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_theme.dart';
import '../../../../utils/debug_logger.dart';

/// Merchant Add/Edit Menu Screen
/// 
/// Enhanced version with option groups linking functionality
/// Features: Add/Edit menu items, Link/Unlink option groups
class MerchantAddEditMenuScreen extends StatefulWidget {
  final Map<String, dynamic>? item;

  const MerchantAddEditMenuScreen({
    Key? key,
    this.item,
  }) : super(key: key);

  @override
  State<MerchantAddEditMenuScreen> createState() => _MerchantAddEditMenuScreenState();
}

class _MerchantAddEditMenuScreenState extends State<MerchantAddEditMenuScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  String _selectedCategory = 'อาหารตามสั่ง';
  bool _isAvailable = true;
  File? _menuItemPhoto;
  String? _imageUrl;
  bool _isUploadingImage = false;

  static const List<String> _categoryOptions = [
    'อาหารตามสั่ง',
    'ก๋วยเตี๋ยว',
    'เครื่องดื่ม',
    'ของหวาน',
    'ฟาสต์ฟู้ด',
    'อาหารเช้า',
    'อาหารญี่ปุ่น',
    'อาหารอีสาน',
    'ของทานเล่น',
    'อื่นๆ',
  ];
  
  List<MenuOptionGroup> _linkedOptionGroups = [];
  bool _isLoadingOptionGroups = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  void _initializeData() {
    if (widget.item != null) {
      // Edit mode
      _nameController.text = widget.item!['name'] ?? '';
      _descriptionController.text = widget.item!['description'] ?? '';
      _priceController.text = widget.item!['price']?.toString() ?? '';
      _imageUrl = widget.item!['image_url'];
      _selectedCategory = widget.item!['category'] ?? 'อาหารตามสั่ง';
      _isAvailable = widget.item!['is_available'] ?? true;
      
      // Load linked option groups
      _loadLinkedOptionGroups();
    }
  }

  Future<void> _loadLinkedOptionGroups() async {
    if (widget.item == null) return;

    setState(() => _isLoadingOptionGroups = true);

    try {
      final menuItemId = widget.item!['id'] as String;
      final optionGroups = await MenuOptionService().getOptionGroupsForMenuItem(menuItemId);
      
      if (mounted) {
        setState(() {
          _linkedOptionGroups = optionGroups;
          _isLoadingOptionGroups = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingOptionGroups = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.menuEditLoadOptionsFailed(e.toString())),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _pickMenuItemPhoto() async {
    final file = await ImagePickerService.showImageSourceDialog(context);
    if (file != null && mounted) {
      setState(() => _menuItemPhoto = file);
    }
  }

  Widget _buildImagePlaceholder() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.add_a_photo, size: 48, color: Colors.grey[400]),
        const SizedBox(height: 8),
        Text(AppLocalizations.of(context)!.menuEditTapToPhoto, style: TextStyle(color: Colors.grey[500], fontSize: 14)),
      ],
    );
  }

  Future<void> _saveMenuItem() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw Exception(AppLocalizations.of(context)!.menuMgmtUserNotFound);
      }

      final menuItemData = {
        'merchant_id': userId,
        'name': _nameController.text.trim(),
        'description': _descriptionController.text.trim(),
        'price': double.parse(_priceController.text),
        'image_url': _imageUrl ?? '',
        'category': _selectedCategory,
        'is_available': _isAvailable,
      };

      String? menuItemId;

      if (widget.item == null) {
        // Create new menu item
        final response = await Supabase.instance.client
            .from('menu_items')
            .insert(menuItemData)
            .select()
            .single();
        menuItemId = response['id'] as String;
      } else {
        // Update existing menu item
        await Supabase.instance.client
            .from('menu_items')
            .update(menuItemData)
            .eq('id', widget.item!['id']);
        menuItemId = widget.item!['id'] as String;
      }

      // Upload image if a new photo was selected
      // ignore: unnecessary_null_comparison
      if (_menuItemPhoto != null && menuItemId != null) {
        final uploadUserId = Supabase.instance.client.auth.currentUser!.id;
        final uploadedUrl = await StorageService.uploadMenuItemImage(
          imageFile: _menuItemPhoto!,
          merchantId: uploadUserId,
          menuItemId: menuItemId,
        );
        if (uploadedUrl != null) {
          _imageUrl = uploadedUrl;
          await Supabase.instance.client
              .from('menu_items')
              .update({'image_url': uploadedUrl})
              .eq('id', menuItemId);
          debugLog('📷 Menu item image uploaded: $uploadedUrl');
        }
      }

      // Sync option group links for both new and existing items
      // ignore: unnecessary_null_comparison
      if (menuItemId != null) {
        // Delete all existing links first
        try {
          await Supabase.instance.client
              .from('menu_item_option_links')
              .delete()
              .eq('menu_item_id', menuItemId);
        } catch (_) {}
        // Re-link all currently selected groups
          for (int i = 0; i < _linkedOptionGroups.length; i++) {
            await MenuOptionService().linkOptionGroupToMenu(
              menuItemId: menuItemId,
              groupId: _linkedOptionGroups[i].id,
              sortOrder: i,
            );
          }
        }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.item == null ? AppLocalizations.of(context)!.menuEditAddSuccess : AppLocalizations.of(context)!.menuEditUpdateSuccess),
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

  void _showOptionGroupSelectionSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => OptionGroupSelectionSheet(
        merchantId: Supabase.instance.client.auth.currentUser!.id,
        currentlyLinkedGroups: _linkedOptionGroups,
        onGroupsSelected: (selectedGroups) {
          setState(() {
            _linkedOptionGroups = selectedGroups;
          });
        },
      ),
    );
  }

  Future<void> _unlinkOptionGroup(MenuOptionGroup group) async {
    if (widget.item == null) {
      // For new items, just remove from local list
      setState(() {
        _linkedOptionGroups.removeWhere((g) => g.id == group.id);
      });
      return;
    }

    try {
      final menuItemId = widget.item!['id'] as String;
      await MenuOptionService().unlinkOptionGroupFromMenu(
        menuItemId: menuItemId,
        groupId: group.id,
      );

      setState(() {
        _linkedOptionGroups.removeWhere((g) => g.id == group.id);
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.menuEditDeleteGroupSuccess(group.name)),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.menuEditDeleteGroupFailed(e.toString())),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? AppLocalizations.of(context)!.menuEditTitleEdit : AppLocalizations.of(context)!.menuEditTitleAdd),
        backgroundColor: AppTheme.accentOrange,
        foregroundColor: Colors.white,
        elevation: 0,
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
                    // Basic Information
                    _buildBasicInfoSection(),
                    const SizedBox(height: 24),

                    // Option Groups Section
                    _buildOptionGroupsSection(),
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
                    onPressed: _isSaving ? null : _saveMenuItem,
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
                            isEditing ? AppLocalizations.of(context)!.menuEditBtnUpdate : AppLocalizations.of(context)!.menuEditBtnAdd,
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

  Widget _buildBasicInfoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.menuEditInfoTitle,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.menuEditNameLabel,
            border: const OutlineInputBorder(),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return AppLocalizations.of(context)!.menuEditNameRequired;
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _descriptionController,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.menuEditDescLabel,
            border: const OutlineInputBorder(),
          ),
          maxLines: 3,
        ),
        const SizedBox(height: 16),
        
        TextFormField(
          controller: _priceController,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.menuEditPriceLabel,
            border: const OutlineInputBorder(),
            prefixText: '฿ ',
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return AppLocalizations.of(context)!.menuEditPriceRequired;
            }
            if (double.tryParse(value) == null || double.tryParse(value)! < 0) {
              return AppLocalizations.of(context)!.menuEditPriceInvalid;
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        // Image Upload Section
        Text(AppLocalizations.of(context)!.menuEditPhotoLabel, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _isUploadingImage ? null : _pickMenuItemPhoto,
          child: Container(
            width: double.infinity,
            height: 180,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!, style: BorderStyle.solid),
            ),
            child: _menuItemPhoto != null
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AppFileImage(file: _menuItemPhoto!),
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => setState(() {
                              _menuItemPhoto = null;
                            }),
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.close, color: Colors.white, size: 18),
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : (_imageUrl != null && _imageUrl!.isNotEmpty)
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            AppNetworkImage(
                              imageUrl: _imageUrl,
                              fit: BoxFit.cover,
                              backgroundColor: Colors.grey[100],
                            ),
                            Positioned(
                              top: 8,
                              right: 8,
                              child: GestureDetector(
                                onTap: () => setState(() => _imageUrl = null),
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    : _buildImagePlaceholder(),
          ),
        ),
        const SizedBox(height: 16),

        // Category Dropdown
        DropdownButtonFormField<String>(
          initialValue: _categoryOptions.contains(_selectedCategory) ? _selectedCategory : 'อื่นๆ',
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.menuEditCategoryLabel,
            border: const OutlineInputBorder(),
            prefixIcon: const Icon(Icons.category),
          ),
          items: _categoryOptions.map((cat) {
            return DropdownMenuItem(value: cat, child: Text(cat));
          }).toList(),
          onChanged: (value) {
            if (value != null) {
              setState(() => _selectedCategory = value);
            }
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return AppLocalizations.of(context)!.menuEditCategoryRequired;
            }
            return null;
          },
        ),
        const SizedBox(height: 16),
        
        SwitchListTile(
          title: Text(AppLocalizations.of(context)!.menuEditAvailable),
          value: _isAvailable,
          onChanged: (value) {
            setState(() {
              _isAvailable = value;
            });
          },
          activeThumbColor: AppTheme.accentOrange,
        ),
      ],
    );
  }

  Widget _buildOptionGroupsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              AppLocalizations.of(context)!.menuEditOptionGroupsTitle,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const Spacer(),
            if (_linkedOptionGroups.isNotEmpty)
              Text(
                AppLocalizations.of(context)!.menuEditGroupCount(_linkedOptionGroups.length.toString()),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Linked Groups List
        if (_isLoadingOptionGroups)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: CircularProgressIndicator(),
            ),
          )
        else if (_linkedOptionGroups.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade300),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 48,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.menuEditNoOptionGroups,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.menuEditNoOptionGroupsHint,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          )
        else
          ..._linkedOptionGroups.asMap().entries.map((entry) {
            // final index = entry.key;
            final group = entry.value;
            return LinkedOptionGroupCard(
              group: group,
              onRemove: () => _unlinkOptionGroup(group),
            );
          }),
        
        const SizedBox(height: 16),
        
        // Add Option Group Button
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _showOptionGroupSelectionSheet,
            icon: const Icon(Icons.add),
            label: Text(AppLocalizations.of(context)!.menuEditAddOptionGroup),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 12),
              side: BorderSide(color: AppTheme.accentOrange),
              foregroundColor: AppTheme.accentOrange,
            ),
          ),
        ),
      ],
    );
  }
}

class LinkedOptionGroupCard extends StatelessWidget {
  final MenuOptionGroup group;
  final VoidCallback onRemove;

  const LinkedOptionGroupCard({
    Key? key,
    required this.group,
    required this.onRemove,
  }) : super(key: key);

  String _getSelectionText(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final min = group.minSelection;
    final max = group.maxSelection;
    
    if (min == 0 && max == 1) {
      return l10n.optLibSelectMax1;
    } else if (min == 0 && max > 1) {
      return l10n.optLibSelectMaxN(max.toString());
    } else if (min == max) {
      return l10n.optLibSelectExact(min.toString());
    } else {
      return l10n.optLibSelectRange(min.toString(), max.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final optionCount = group.options?.length ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Icon
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getGroupIcon(),
                color: AppTheme.accentOrange,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            
            // Group Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    group.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _getSelectionText(context),
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (optionCount > 0)
                    Text(
                      AppLocalizations.of(context)!.menuEditOptionCount(optionCount.toString()),
                      style: TextStyle(
                        fontSize: 12,
                        color: AppTheme.accentOrange,
                      ),
                    ),
                ],
              ),
            ),
            
            // Remove Button
            IconButton(
              icon: const Icon(Icons.remove_circle, color: Colors.red),
              onPressed: onRemove,
              tooltip: AppLocalizations.of(context)!.menuEditRemoveGroupTooltip,
            ),
          ],
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

class OptionGroupSelectionSheet extends StatefulWidget {
  final String merchantId;
  final List<MenuOptionGroup> currentlyLinkedGroups;
  final Function(List<MenuOptionGroup>) onGroupsSelected;

  const OptionGroupSelectionSheet({
    Key? key,
    required this.merchantId,
    required this.currentlyLinkedGroups,
    required this.onGroupsSelected,
  }) : super(key: key);

  @override
  State<OptionGroupSelectionSheet> createState() => _OptionGroupSelectionSheetState();
}

class _OptionGroupSelectionSheetState extends State<OptionGroupSelectionSheet> {
  List<MenuOptionGroup> _availableGroups = [];
  List<MenuOptionGroup> _selectedGroups = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadAvailableGroups();
    _selectedGroups = List.from(widget.currentlyLinkedGroups);
  }

  Future<void> _loadAvailableGroups() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final groups = await MenuOptionService().getOptionGroupsForMerchant(widget.merchantId);
      
      if (mounted) {
        setState(() {
          _availableGroups = groups;
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

  void _toggleGroupSelection(MenuOptionGroup group) {
    setState(() {
      if (_selectedGroups.any((g) => g.id == group.id)) {
        _selectedGroups.removeWhere((g) => g.id == group.id);
      } else {
        _selectedGroups.add(group);
      }
    });
  }

  void _saveSelection() {
    widget.onGroupsSelected(_selectedGroups);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Text(
                      AppLocalizations.of(context)!.menuEditSelectOptionGroups,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    if (_selectedGroups.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accentOrange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_selectedGroups.length}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Content
              Expanded(
                child: _buildContent(scrollController),
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
                      onPressed: _saveSelection,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentOrange,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.menuEditSaveSelection,
                        style: TextStyle(
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
        );
      },
    );
  }

  Widget _buildContent(ScrollController scrollController) {
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
              onPressed: _loadAvailableGroups,
              child: Text(AppLocalizations.of(context)!.menuEditSheetRetry),
            ),
          ],
        ),
      );
    }

    if (_availableGroups.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.category_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.menuEditSheetNoGroups,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.menuEditSheetNoGroupsHint,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _availableGroups.length,
      itemBuilder: (context, index) {
        final group = _availableGroups[index];
        final isSelected = _selectedGroups.any((g) => g.id == group.id);
        
        return OptionGroupSelectionCard(
          group: group,
          isSelected: isSelected,
          onTap: () => _toggleGroupSelection(group),
        );
      },
    );
  }
}

class OptionGroupSelectionCard extends StatelessWidget {
  final MenuOptionGroup group;
  final bool isSelected;
  final VoidCallback onTap;

  const OptionGroupSelectionCard({
    Key? key,
    required this.group,
    required this.isSelected,
    required this.onTap,
  }) : super(key: key);

  String _getSelectionText(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final min = group.minSelection;
    final max = group.maxSelection;
    
    if (min == 0 && max == 1) {
      return l10n.optLibSelectMax1;
    } else if (min == 0 && max > 1) {
      return l10n.optLibSelectMaxN(max.toString());
    } else if (min == max) {
      return l10n.optLibSelectExact(min.toString());
    } else {
      return l10n.optLibSelectRange(min.toString(), max.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final optionCount = group.options?.length ?? 0;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Checkbox
              Checkbox(
                value: isSelected,
                onChanged: (value) => onTap(),
                activeColor: AppTheme.accentOrange,
              ),
              
              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getGroupIcon(),
                  color: AppTheme.accentOrange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              
              // Group Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      group.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getSelectionText(context),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (optionCount > 0)
                      Text(
                        AppLocalizations.of(context)!.menuEditOptionCount(optionCount.toString()),
                        style: TextStyle(
                          fontSize: 12,
                          color: AppTheme.accentOrange,
                        ),
                      ),
                  ],
                ),
              ),
            ],
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
