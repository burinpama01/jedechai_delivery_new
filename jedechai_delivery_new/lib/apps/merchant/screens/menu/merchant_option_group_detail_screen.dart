import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../common/services/menu_option_service.dart';
import '../../../../common/models/menu_option.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_layout.dart';

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
  State<MerchantOptionGroupDetailScreen> createState() =>
      _MerchantOptionGroupDetailScreenState();
}

class _MerchantOptionGroupDetailScreenState
    extends State<MerchantOptionGroupDetailScreen> {
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
      debugLog(
          '📋 Existing options count: ${widget.group!.options?.length ?? 0}');

      _options = List<MenuOption>.of(widget.group!.options ?? const []);

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
        throw Exception(AppLocalizations.of(context)!.optGroupMinMaxError);
      }

      if (minSelection > maxSelection) {
        throw Exception(AppLocalizations.of(context)!.optGroupMinGtMaxError);
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
        throw Exception(AppLocalizations.of(context)!.optGroupSaveError);
      }

      // Save options
      await _saveOptions(savedGroup.id);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.group == null
                ? AppLocalizations.of(context)!.optGroupCreateSuccess
                : AppLocalizations.of(context)!.optGroupUpdateSuccess),
            backgroundColor: JdcColors.of(context).successFill,
          ),
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ $e',
                style: TextStyle(color: JdcColors.of(context).paper)),
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
        SnackBar(
          content: Text(
              AppLocalizations.of(context)!.optGroupOptionNameRequired,
              style: TextStyle(color: JdcColors.of(context).paper)),
          backgroundColor: JdcColors.of(context).danger,
        ),
      );
      return;
    }

    final price = int.tryParse(priceText) ?? 0;
    if (price < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              AppLocalizations.of(context)!.optGroupOptionPriceNegative,
              style: TextStyle(color: JdcColors.of(context).paper)),
          backgroundColor: JdcColors.of(context).danger,
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

  void _updateOptionPrice(int index, int price) {
    setState(() {
      _options[index] = _options[index].copyWith(price: price);
    });
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.group != null;

    return Scaffold(
      backgroundColor: JdcColors.of(context).paper,
      appBar: AppBar(
        title: Text(
            isEditing
                ? AppLocalizations.of(context)!.optGroupEditTitle
                : AppLocalizations.of(context)!.optGroupCreateTitle,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
        backgroundColor: JdcColors.of(context).surface,
        foregroundColor: JdcColors.of(context).text,
        iconTheme: IconThemeData(color: JdcColors.of(context).text),
        titleTextStyle: Theme.of(context)
            .textTheme
            .titleLarge
            ?.copyWith(color: JdcColors.of(context).text),
        elevation: 0,
        shape: Border(bottom: BorderSide(color: JdcColors.of(context).line)),
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
                padding: const EdgeInsets.fromLTRB(
                    JdcSpacing.xl, JdcSpacing.md, JdcSpacing.xl, JdcSpacing.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Group Information
                    _buildGroupInfoSection(),
                    const SizedBox(height: 24),

                    // Options List
                    _buildOptionsList(),
                    const SizedBox(height: 24),

                    // Keep the existing add controls below saved options so
                    // merchants can review the group before adding another.
                    _buildAddOptionSection(),
                    const SizedBox(height: JdcSpacing.xl),
                  ],
                ),
              ),
            ),

            // Save Button
            Container(
              padding: const EdgeInsets.fromLTRB(
                  JdcSpacing.xl, JdcSpacing.md, JdcSpacing.xl, JdcSpacing.lg),
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
                top: false,
                child: SizedBox(
                  width: double.infinity,
                  height: JdcTouch.button,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : _saveGroup,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: JdcColors.of(context).cta,
                      foregroundColor: JdcColors.of(context).onCta,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(JdcRadius.card),
                      ),
                    ),
                    child: _isSaving
                        ? SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                  JdcColors.of(context).onCta),
                            ),
                          )
                        : Text(
                            isEditing
                                ? AppLocalizations.of(context)!
                                    .optGroupBtnUpdate
                                : AppLocalizations.of(context)!
                                    .optGroupBtnCreate,
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
        Text(
          AppLocalizations.of(context)!.optGroupInfoTitle,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),

        // Group Name
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: AppLocalizations.of(context)!.optGroupNameLabel,
            hintText: AppLocalizations.of(context)!.optGroupNameHint,
            filled: true,
            fillColor: JdcColors.of(context).surface,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(JdcRadius.field)),
          ),
          validator: (value) {
            if (value == null || value.trim().isEmpty) {
              return AppLocalizations.of(context)!.optGroupNameRequired;
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
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.optGroupMinLabel,
                  hintText: '0',
                  filled: true,
                  fillColor: JdcColors.of(context).surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(JdcRadius.field)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.of(context)!.optGroupMinRequired;
                  }
                  final num = int.tryParse(value);
                  if (num == null || num < 0) {
                    return AppLocalizations.of(context)!.optGroupMinInvalid;
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
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)!.optGroupMaxLabel,
                  hintText: '1',
                  filled: true,
                  fillColor: JdcColors.of(context).surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(JdcRadius.field)),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return AppLocalizations.of(context)!.optGroupMaxRequired;
                  }
                  final num = int.tryParse(value);
                  if (num == null || num < 1) {
                    return AppLocalizations.of(context)!.optGroupMaxInvalid;
                  }
                  return null;
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          AppLocalizations.of(context)!.optGroupSelectionHint,
          style: TextStyle(
            fontSize: 12,
            color: JdcColors.of(context).muted,
          ),
        ),
      ],
    );
  }

  Widget _buildAddOptionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.optGroupAddOptionTitle,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        LayoutBuilder(
            builder: (context, constraints) => Flex(
                  direction: constraints.maxWidth < 370
                      ? Axis.vertical
                      : Axis.horizontal,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Option Name
                    SizedBox(
                      width: constraints.maxWidth < 370
                          ? constraints.maxWidth
                          : constraints.maxWidth - 196,
                      child: TextFormField(
                        controller: _optionNameController,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!
                              .optGroupOptionNameLabel,
                          hintText: AppLocalizations.of(context)!
                              .optGroupOptionNameHint,
                          filled: true,
                          fillColor: JdcColors.of(context).surface,
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(JdcRadius.field)),
                        ),
                      ),
                    ),
                    SizedBox(
                        width: constraints.maxWidth < 370 ? 0 : 12,
                        height: constraints.maxWidth < 370 ? 8 : 0),

                    // Option Price
                    SizedBox(
                      width: constraints.maxWidth < 370 ? double.infinity : 100,
                      child: TextFormField(
                        controller: _optionPriceController,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: AppLocalizations.of(context)!
                              .optGroupOptionPriceLabel,
                          hintText: '0',
                          prefixText: '฿',
                          filled: true,
                          fillColor: JdcColors.of(context).surface,
                          border: OutlineInputBorder(
                              borderRadius:
                                  BorderRadius.circular(JdcRadius.field)),
                        ),
                      ),
                    ),
                    SizedBox(
                        width: constraints.maxWidth < 370 ? 0 : 12,
                        height: constraints.maxWidth < 370 ? 8 : 0),

                    // Add Button
                    ElevatedButton(
                      onPressed: _addOption,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: JdcColors.of(context).cta,
                        foregroundColor: JdcColors.of(context).onCta,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 16),
                      ),
                      child: const Icon(Icons.add),
                    ),
                  ],
                )),
      ],
    );
  }

  Widget _buildOptionsList() {
    if (_options.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          border: Border.all(color: JdcColors.of(context).line),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(
              Icons.list_alt,
              size: 48,
              color: JdcColors.of(context).trackEmpty,
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.optGroupNoOptions,
              style: TextStyle(
                fontSize: 16,
                color: JdcColors.of(context).muted,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.optGroupNoOptionsHint,
              style: TextStyle(
                fontSize: 14,
                color: JdcColors.of(context).dim,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: JdcSpacing.sm,
          runSpacing: JdcSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              AppLocalizations.of(context)!.optGroupAllOptionsTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              AppLocalizations.of(context)!
                  .optGroupItemCount(_options.length.toString()),
              style: TextStyle(
                fontSize: 14,
                color: JdcColors.of(context).muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ..._options.asMap().entries.map((entry) {
          final index = entry.key;
          final option = entry.value;
          return OptionCard(
            key: ValueKey(option.id.isNotEmpty
                ? option.id
                : option.createdAt.microsecondsSinceEpoch),
            option: option,
            onRemove: () => _removeOption(index),
            onToggleAvailability: () => _toggleOptionAvailability(index),
            onPriceChanged: (price) => _updateOptionPrice(index, price),
          );
        }),
      ],
    );
  }

  Future<void> _deleteGroup() async {
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(AppLocalizations.of(context)!.optLibDeleteConfirmTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(AppLocalizations.of(context)!
                    .optLibDeleteConfirmBody(widget.group!.name)),
                const SizedBox(height: 8),
                Text(
                  AppLocalizations.of(context)!.optLibDeleteNote(
                      (widget.group!.options?.length ?? 0).toString()),
                  style: TextStyle(
                    color: JdcColors.of(context).brandOnSoft,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(AppLocalizations.of(context)!.optLibCancel),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: ElevatedButton.styleFrom(
                  backgroundColor: JdcColors.of(context).danger,
                  foregroundColor: JdcColors.of(context).paper,
                ),
                child: Text(AppLocalizations.of(context)!.optLibDeleteBtn),
              ),
            ],
          ),
        ) ??
        false;

    if (confirmed) {
      try {
        await MenuOptionService().deleteOptionGroup(widget.group!.id);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(AppLocalizations.of(context)!
                  .optLibDeleteSuccess(widget.group!.name)),
              backgroundColor: JdcColors.of(context).successFill,
            ),
          );
          Navigator.of(context).pop(true);
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                  AppLocalizations.of(context)!
                      .optLibDeleteFailed(e.toString()),
                  style: TextStyle(color: JdcColors.of(context).paper)),
              backgroundColor: JdcColors.of(context).danger,
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
  final ValueChanged<int> onPriceChanged;

  const OptionCard({
    Key? key,
    required this.option,
    required this.onRemove,
    required this.onToggleAvailability,
    required this.onPriceChanged,
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
                  color: option.isAvailable
                      ? JdcColors.of(context).successInk
                      : JdcColors.of(context).muted,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  option.isAvailable ? Icons.check : Icons.close,
                  color: JdcColors.of(context).surface,
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
                      color: option.isAvailable
                          ? JdcColors.of(context).text
                          : JdcColors.of(context).muted,
                    ),
                  ),
                ],
              ),
            ),

            SizedBox(
              width: 74,
              child: TextFormField(
                initialValue: option.price.toString(),
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                decoration: InputDecoration(
                  prefixText: '฿',
                  isDense: true,
                  filled: true,
                  fillColor: JdcColors.of(context).surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(JdcRadius.field),
                  ),
                ),
                validator: (value) {
                  final price = int.tryParse(value ?? '');
                  if (price == null || price < 0) {
                    return AppLocalizations.of(context)!
                        .optGroupOptionPriceNegative;
                  }
                  return null;
                },
                onChanged: (value) {
                  final price = int.tryParse(value);
                  if (price != null && price >= 0) onPriceChanged(price);
                },
              ),
            ),
            const SizedBox(width: JdcSpacing.sm),

            // Remove Button
            IconButton(
              icon: Icon(Icons.remove_circle,
                  color: JdcColors.of(context).dangerInk),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}
