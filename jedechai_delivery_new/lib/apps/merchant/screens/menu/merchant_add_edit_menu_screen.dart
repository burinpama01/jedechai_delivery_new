import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../common/services/menu_option_service.dart';
import '../../../../common/services/image_picker_service.dart';
import '../../../../common/services/storage_service.dart';
import '../../../../common/models/menu_option.dart';
import '../../../../common/widgets/app_network_image.dart';
import '../../../../l10n/app_localizations.dart';
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
  State<MerchantAddEditMenuScreen> createState() =>
      _MerchantAddEditMenuScreenState();
}

class _MerchantAddEditMenuScreenState extends State<MerchantAddEditMenuScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _prepTimeController = TextEditingController(text: '15');
  String _selectedCategory = 'อาหารตามสั่ง';
  String? _selectedCategoryId;
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
  List<Map<String, dynamic>> _menuCategories = [];
  bool _isLoadingOptionGroups = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _prepTimeController.dispose();
    super.dispose();
  }

  void _initializeData() {
    if (widget.item != null) {
      // Edit mode
      _nameController.text = widget.item!['name'] ?? '';
      _descriptionController.text = widget.item!['description'] ?? '';
      _priceController.text = widget.item!['price']?.toString() ?? '';
      _prepTimeController.text =
          widget.item!['prep_time_minutes']?.toString() ?? '15';
      _imageUrl = widget.item!['image_url'];
      _selectedCategory = widget.item!['category'] ?? 'อาหารตามสั่ง';
      _selectedCategoryId = widget.item!['category_id'] as String?;
      _isAvailable = widget.item!['is_available'] ?? true;

      // Load linked option groups
      _loadLinkedOptionGroups();
    }
    _loadMenuCategories();
  }

  Future<void> _loadMenuCategories() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final rows = await Supabase.instance.client
          .from('menu_categories')
          .select('id, name')
          .eq('merchant_id', userId)
          .eq('is_active', true)
          .order('sort_order');
      if (!mounted) return;
      setState(() {
        _menuCategories = List<Map<String, dynamic>>.from(rows);
        if (_selectedCategoryId == null && _menuCategories.isNotEmpty) {
          final matched = _menuCategories.where(
            (category) => category['name'] == _selectedCategory,
          );
          if (matched.isNotEmpty) {
            _selectedCategoryId = matched.first['id'] as String?;
          }
        }
      });
    } catch (e) {
      debugLog('⚠️ Menu categories unavailable, using static categories: $e');
    }
  }

  Future<void> _loadLinkedOptionGroups() async {
    if (widget.item == null) return;

    setState(() => _isLoadingOptionGroups = true);

    try {
      final menuItemId = widget.item!['id'] as String;
      final optionGroups =
          await MenuOptionService().getOptionGroupsForMenuItem(menuItemId);

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
            content: Text(AppLocalizations.of(context)!
                .menuEditLoadOptionsFailed(e.toString())),
            backgroundColor: JdcColors.of(context).danger,
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
        'category_id': _selectedCategoryId,
        'is_available': _isAvailable,
        'prep_time_minutes':
            int.tryParse(_prepTimeController.text.trim()) ?? 15,
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
              .update({'image_url': uploadedUrl}).eq('id', menuItemId);
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
            content: Text(widget.item == null
                ? AppLocalizations.of(context)!.menuEditAddSuccess
                : AppLocalizations.of(context)!.menuEditUpdateSuccess),
            backgroundColor: JdcColors.of(context).successFill,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $e'),
            backgroundColor: JdcColors.of(context).danger,
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
          content: Text(AppLocalizations.of(context)!
              .menuEditDeleteGroupSuccess(group.name)),
          backgroundColor: JdcColors.of(context).successFill,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!
              .menuEditDeleteGroupFailed(e.toString())),
          backgroundColor: JdcColors.of(context).danger,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.item != null;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              isEditing
                  ? AppLocalizations.of(context)!.menuEditTitleEdit
                  : AppLocalizations.of(context)!.menuEditTitleAdd,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: JdcColors.of(context).text),
            ),
            if (isEditing && (_nameController.text.isNotEmpty))
              Text(
                _nameController.text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12, color: JdcColors.of(context).muted),
              ),
          ],
        ),
        backgroundColor: JdcColors.of(context).surface,
        foregroundColor: JdcColors.of(context).text,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(color: JdcColors.of(context).text),
        iconTheme:
            IconThemeData(color: JdcColors.of(context).text),
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
                color: JdcColors.of(context).surface,
                boxShadow: [
                  BoxShadow(
                    color: JdcColors.of(context).shadowCard.first.color,
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
                      backgroundColor: JdcColors.of(context).cta,
                      foregroundColor: JdcColors.of(context).onCta,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(JdcColors.of(context).onCta),
                            ),
                          )
                        : Text(
                            AppLocalizations.of(context)!.menuEditSaveBtn,
                            style: const TextStyle(
                              fontSize: 15,
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
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Photo row (artboard layout) ───────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            GestureDetector(
              onTap: _isUploadingImage ? null : _pickMenuItemPhoto,
              child: Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  color: jdc.sunken,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: jdc.line),
                ),
                child: _menuItemPhoto != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(fit: StackFit.expand, children: [
                          AppFileImage(file: _menuItemPhoto!),
                          Positioned(
                            top: 4,
                            right: 4,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _menuItemPhoto = null),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle),
                                child: Icon(Icons.close,
                                    color: jdc.surface, size: 14),
                              ),
                            ),
                          ),
                        ]))
                    : (_imageUrl != null && _imageUrl!.isNotEmpty)
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Stack(fit: StackFit.expand, children: [
                              AppNetworkImage(
                                  imageUrl: _imageUrl,
                                  fit: BoxFit.cover,
                                  backgroundColor: jdc.sunken),
                              Positioned(
                                top: 4,
                                right: 4,
                                child: GestureDetector(
                                  onTap: () =>
                                      setState(() => _imageUrl = null),
                                  child: Container(
                                    padding: const EdgeInsets.all(3),
                                    decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle),
                                    child: Icon(Icons.close,
                                        color: jdc.surface, size: 14),
                                  ),
                                ),
                              ),
                            ]))
                        : Icon(Icons.camera_alt_outlined,
                            size: 26, color: jdc.muted),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.menuEditPhotoHint,
                    style: TextStyle(
                        fontSize: 12, color: jdc.muted, height: 1.5),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton(
                    onPressed: _isUploadingImage ? null : _pickMenuItemPhoto,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: jdc.text,
                      side: BorderSide(color: jdc.line),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                      minimumSize: const Size(0, 44),
                      padding:
                          const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    child: Text(l10n.menuEditChangePhoto,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // ── Name ────────────────────────────────────────────────────────
        _FieldLabel(l10n.menuEditNameLabel, jdc: jdc),
        const SizedBox(height: 6),
        TextFormField(
          controller: _nameController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: l10n.menuEditNameLabel,
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: jdc.line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: jdc.cta)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: jdc.danger)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: jdc.danger)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 0),
            filled: false,
            border: InputBorder.none,
          ),
          style: TextStyle(fontSize: 14, color: jdc.text),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return l10n.menuEditNameRequired;
            }
            return null;
          },
        ),
        const SizedBox(height: 12),

        // ── Description ────────────────────────────────────────────────
        _FieldLabel(l10n.menuEditDescLabel, jdc: jdc),
        const SizedBox(height: 6),
        TextFormField(
          controller: _descriptionController,
          maxLines: 2,
          decoration: InputDecoration(
            hintText: l10n.menuEditDescLabel,
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: jdc.line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: jdc.cta)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            filled: false,
            border: InputBorder.none,
          ),
          style: TextStyle(fontSize: 14, color: jdc.text),
        ),
        const SizedBox(height: 12),

        // ── Price + Prep time (2-column) ──────────────────────────────
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel(l10n.menuEditPriceLabel, jdc: jdc),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _priceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: jdc.line)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: jdc.cta)),
                      errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: jdc.danger)),
                      focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: jdc.danger)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 0),
                      filled: false,
                      border: InputBorder.none,
                    ),
                    style: TextStyle(fontSize: 14, color: jdc.text),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return l10n.menuEditPriceRequired;
                      }
                      if (double.tryParse(value) == null ||
                          double.tryParse(value)! < 0) {
                        return l10n.menuEditPriceInvalid;
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _FieldLabel(l10n.menuEditPrepTimeLabelShort, jdc: jdc),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _prepTimeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: jdc.line)),
                      focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: jdc.cta)),
                      errorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: jdc.danger)),
                      focusedErrorBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: jdc.danger)),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 0),
                      filled: false,
                      border: InputBorder.none,
                    ),
                    style: TextStyle(fontSize: 14, color: jdc.text),
                    validator: (value) {
                      final minutes =
                          int.tryParse((value ?? '').trim());
                      if (minutes == null ||
                          minutes < 1 ||
                          minutes > 180) {
                        return 'กรุณาระบุ 1-180 นาที';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // ── Category Dropdown ──────────────────────────────────────────
        _FieldLabel(l10n.menuEditCategoryLabel, jdc: jdc),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: (_menuCategories.any(
                (category) => category['id'] == _selectedCategoryId,
              )
                  ? _selectedCategoryId
                  : null) ??
              (_categoryOptions.contains(_selectedCategory)
                  ? _selectedCategory
                  : 'อื่นๆ'),
          decoration: InputDecoration(
            enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: jdc.line)),
            focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: jdc.cta)),
            errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: jdc.danger)),
            focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: jdc.danger)),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
            filled: false,
            border: InputBorder.none,
          ),
          style: TextStyle(fontSize: 14, color: jdc.text),
          items: [
            ..._menuCategories.map((category) {
              return DropdownMenuItem(
                value: category['id'] as String,
                child: Text(category['name']?.toString() ?? ''),
              );
            }),
            if (_menuCategories.isNotEmpty)
              const DropdownMenuItem<String>(
                enabled: false,
                value: '__divider__',
                child: Text('────────'),
              ),
            ..._categoryOptions.map((cat) {
              return DropdownMenuItem(value: cat, child: Text(cat));
            }),
          ],
          onChanged: (value) {
            if (value != null) {
              final dynamicCategory = _menuCategories.where(
                (category) => category['id'] == value,
              );
              setState(() {
                if (dynamicCategory.isNotEmpty) {
                  _selectedCategoryId = value;
                  _selectedCategory =
                      dynamicCategory.first['name']?.toString() ?? 'อื่นๆ';
                } else {
                  _selectedCategoryId = null;
                  _selectedCategory = value;
                }
              });
            }
          },
          validator: (value) {
            if (value == null || value.isEmpty) {
              return l10n.menuEditCategoryRequired;
            }
            return null;
          },
        ),
        const SizedBox(height: 12),

        // ── Available toggle (artboard style) ────────────────────────
        GestureDetector(
          onTap: () => setState(() => _isAvailable = !_isAvailable),
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: jdc.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: jdc.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.menuEditAvailableToggleTitle,
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: jdc.text)),
                      const SizedBox(height: 2),
                      Text(l10n.menuEditAvailableToggleHint,
                          style:
                              TextStyle(fontSize: 12, color: jdc.muted)),
                    ],
                  ),
                ),
                // artboard-style pill toggle
                AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  width: 50,
                  height: 30,
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    color: _isAvailable ? jdc.successFill : jdc.trackEmpty,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Align(
                    alignment: _isAvailable
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: jdc.surface,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOptionGroupsSection() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.menuEditOptionGroupsSectionTitle,
                style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: jdc.text),
              ),
            ),
            TextButton(
              onPressed: _showOptionGroupSelectionSheet,
              style: TextButton.styleFrom(
                  foregroundColor: jdc.cta,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 4, vertical: 0),
                  minimumSize: const Size(0, 44)),
              child: Text(l10n.menuEditOptionLibraryLink,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
            ),
          ],
        ),
        const SizedBox(height: JdcSpacing.sm),

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
              border: Border.all(color: JdcColors.of(context).line),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(
                  Icons.category_outlined,
                  size: 48,
                  color: JdcColors.of(context).trackEmpty,
                ),
                const SizedBox(height: 12),
                Text(
                  AppLocalizations.of(context)!.menuEditNoOptionGroups,
                  style: TextStyle(
                    fontSize: 16,
                    color: JdcColors.of(context).muted,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.menuEditNoOptionGroupsHint,
                  style: TextStyle(
                    fontSize: 14,
                    color: JdcColors.of(context).dim,
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
              side: BorderSide(color: JdcColors.of(context).cta),
              foregroundColor: JdcColors.of(context).cta,
            ),
          ),
        ),
      ],
    );
  }
}

/// Small label widget ใช้ซ้ำใน _buildBasicInfoSection
class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text, {required this.jdc});
  final String text;
  final JdcColors jdc;

  @override
  Widget build(BuildContext context) => Text(
        text,
        style: TextStyle(
            fontSize: 12, fontWeight: FontWeight.w600, color: jdc.muted),
      );
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
                color: JdcColors.of(context).brandSoft,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getGroupIcon(),
                color: JdcColors.of(context).cta,
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
                      color: JdcColors.of(context).muted,
                    ),
                  ),
                  if (optionCount > 0)
                    Text(
                      AppLocalizations.of(context)!
                          .menuEditOptionCount(optionCount.toString()),
                      style: TextStyle(
                        fontSize: 12,
                        color: JdcColors.of(context).cta,
                      ),
                    ),
                ],
              ),
            ),

            // Remove Button
            IconButton(
              icon: Icon(Icons.remove_circle, color: JdcColors.of(context).dangerInk),
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
    if (name.contains('เผ็ด') || name.contains('spicy'))
      return Icons.local_fire_department;
    if (name.contains('ท็อปปิ้ง') || name.contains('topping'))
      return Icons.add_circle;
    if (name.contains('ขนาด') || name.contains('size')) return Icons.straighten;
    if (name.contains('เนื้อ') || name.contains('meat'))
      return Icons.lunch_dining;
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
  State<OptionGroupSelectionSheet> createState() =>
      _OptionGroupSelectionSheetState();
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

      final groups = await MenuOptionService()
          .getOptionGroupsForMerchant(widget.merchantId);

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
          decoration: BoxDecoration(
            color: JdcColors.of(context).surface,
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
                  color: JdcColors.of(context).muted,
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
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: JdcColors.of(context).cta,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${_selectedGroups.length}',
                          style: TextStyle(
                            color: JdcColors.of(context).onCta,
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
                  color: JdcColors.of(context).surface,
                  boxShadow: [
                    BoxShadow(
                      color: JdcColors.of(context).shadowCard.first.color,
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
                        backgroundColor: JdcColors.of(context).cta,
                        foregroundColor: JdcColors.of(context).onCta,
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
              color: JdcColors.of(context).trackEmpty,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 16,
                color: JdcColors.of(context).muted,
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
              color: JdcColors.of(context).trackEmpty,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.menuEditSheetNoGroups,
              style: TextStyle(
                fontSize: 16,
                color: JdcColors.of(context).muted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.menuEditSheetNoGroupsHint,
              style: TextStyle(
                fontSize: 14,
                color: JdcColors.of(context).dim,
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
                activeColor: JdcColors.of(context).cta,
              ),

              // Icon
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: JdcColors.of(context).brandSoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _getGroupIcon(),
                  color: JdcColors.of(context).cta,
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
                        color: JdcColors.of(context).muted,
                      ),
                    ),
                    if (optionCount > 0)
                      Text(
                        AppLocalizations.of(context)!
                            .menuEditOptionCount(optionCount.toString()),
                        style: TextStyle(
                          fontSize: 12,
                          color: JdcColors.of(context).cta,
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
    if (name.contains('เผ็ด') || name.contains('spicy'))
      return Icons.local_fire_department;
    if (name.contains('ท็อปปิ้ง') || name.contains('topping'))
      return Icons.add_circle;
    if (name.contains('ขนาด') || name.contains('size')) return Icons.straighten;
    if (name.contains('เนื้อ') || name.contains('meat'))
      return Icons.lunch_dining;
    return Icons.category;
  }
}
