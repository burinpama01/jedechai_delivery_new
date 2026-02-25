import 'package:flutter/material.dart';
import '../models/menu_option.dart';

/// Menu Option Selector Widget
/// 
/// Provides UI for selecting menu options with support for:
/// - Single selection (radio buttons)
/// - Multiple selection (checkboxes)
/// - Required/optional groups
/// - Price display
/// - Validation
class MenuOptionSelector extends StatefulWidget {
  final List<MenuOptionGroup> optionGroups;
  final Function(List<String>)? onSelectionChanged;
  final Function(bool)? onValidationChanged;
  final bool showValidationErrors;
  final EdgeInsets? padding;

  const MenuOptionSelector({
    Key? key,
    required this.optionGroups,
    this.onSelectionChanged,
    this.onValidationChanged,
    this.showValidationErrors = true,
    this.padding,
  }) : super(key: key);

  @override
  State<MenuOptionSelector> createState() => _MenuOptionSelectorState();
}

class _MenuOptionSelectorState extends State<MenuOptionSelector> {
  late List<MenuOptionGroup> _optionGroups;
  Map<String, String> _validationErrors = {};

  @override
  void initState() {
    super.initState();
    _optionGroups = widget.optionGroups;
    _validateAllGroups();
  }

  @override
  void didUpdateWidget(MenuOptionSelector oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.optionGroups != widget.optionGroups) {
      _optionGroups = widget.optionGroups;
      _validateAllGroups();
    }
  }

  void _validateAllGroups() {
    final newErrors = <String, String>{};
    bool allValid = true;

    for (final group in _optionGroups) {
      if (group.options != null) {
        final selectedCount = group.options!.where((o) => o.isSelected).length;
        final error = group.getValidationError(selectedCount);
        if (error != null) {
          newErrors[group.id] = error;
          allValid = false;
        }
      }
    }

    setState(() {
      _validationErrors = newErrors;
    });

    widget.onValidationChanged?.call(allValid);
  }

  void _onOptionChanged(MenuOptionGroup group, MenuOption option, bool? isSelected) {
    setState(() {
      // Handle single selection
      if (!group.isMultiSelect) {
        // Deselect all other options in this group
        for (final opt in group.options!) {
          opt.isSelected = false;
        }
        option.isSelected = isSelected ?? false;
      } else {
        // Handle multiple selection
        option.isSelected = isSelected ?? false;
      }
    });

    _validateAllGroups();
    widget.onSelectionChanged?.call(_getSelectedOptionIds());
  }

  List<String> _getSelectedOptionIds() {
    final selectedIds = <String>[];
    for (final group in _optionGroups) {
      if (group.options != null) {
        for (final option in group.options!) {
          if (option.isSelected) {
            selectedIds.add(option.id);
          }
        }
      }
    }
    return selectedIds;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: widget.padding ?? const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Text(
            'ปรับแต่งออเดอร์',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          
          // Option Groups
          ..._optionGroups.map((group) => _buildOptionGroup(group)),
          
          // Validation Summary
          if (widget.showValidationErrors && _validationErrors.isNotEmpty)
            _buildValidationSummary(),
        ],
      ),
    );
  }

  Widget _buildOptionGroup(MenuOptionGroup group) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasError = _validationErrors.containsKey(group.id);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24.0),
      decoration: BoxDecoration(
        border: Border.all(
          color: hasError ? colorScheme.error : colorScheme.outlineVariant,
          width: hasError ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(8),
        color: hasError ? colorScheme.errorContainer : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Group Header
          _buildGroupHeader(group, hasError),
          
          // Options
          if (group.options != null && group.options!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: group.options!.map((option) => _buildOption(group, option)).toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildGroupHeader(MenuOptionGroup group, bool hasError) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: hasError
            ? colorScheme.errorContainer
            : colorScheme.surfaceContainerHighest,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(8),
          topRight: Radius.circular(8),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  group.name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: hasError ? colorScheme.onErrorContainer : colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  group.selectionType,
                  style: TextStyle(
                    fontSize: 12,
                    color: hasError
                        ? colorScheme.onErrorContainer.withValues(alpha: 0.85)
                        : colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (group.isRequired)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: hasError ? colorScheme.error : colorScheme.secondary,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text(
                'จำเป็น',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildOption(MenuOptionGroup group, MenuOption option) {
    if (!group.isMultiSelect) {
      return _buildRadioOption(group, option);
    } else {
      return _buildCheckboxOption(group, option);
    }
  }

  Widget _buildRadioOption(MenuOptionGroup group, MenuOption option) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _onOptionChanged(group, option, true),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Radio<String>(
              value: option.id,
              groupValue: group.options?.firstWhere((o) => o.isSelected, orElse: () => MenuOption(id: '', groupId: '', name: '', price: 0, isAvailable: true, createdAt: DateTime.now(), updatedAt: DateTime.now())).id,
              onChanged: (value) => _onOptionChanged(group, option, value != null),
              activeColor: colorScheme.primary,
            ),
            Expanded(
              child: Text(
                option.displayName,
                style: TextStyle(
                  fontSize: 14,
                  color: option.canSelect ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                  decoration: option.canSelect ? null : TextDecoration.lineThrough,
                ),
              ),
            ),
            if (option.price > 0)
              Text(
                '+฿${option.price}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCheckboxOption(MenuOptionGroup group, MenuOption option) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () => _onOptionChanged(group, option, !option.isSelected),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Row(
          children: [
            Checkbox(
              value: option.isSelected,
              onChanged: (value) => _onOptionChanged(group, option, value),
              activeColor: colorScheme.primary,
            ),
            Expanded(
              child: Text(
                option.displayName,
                style: TextStyle(
                  fontSize: 14,
                  color: option.canSelect ? colorScheme.onSurface : colorScheme.onSurfaceVariant,
                  decoration: option.canSelect ? null : TextDecoration.lineThrough,
                ),
              ),
            ),
            if (option.price > 0)
              Text(
                '+฿${option.price}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildValidationSummary() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 16.0),
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.35)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.error_outline, color: colorScheme.onErrorContainer, size: 20),
              const SizedBox(width: 8),
              Text(
                'กรุณาเลือกตัวเลือกที่จำเป็นให้ครบ',
                style: TextStyle(
                  color: colorScheme.onErrorContainer,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ..._validationErrors.entries.map((entry) => Padding(
            padding: const EdgeInsets.only(top: 4.0),
            child: Text(
              '• ${entry.value}',
              style: TextStyle(
                color: colorScheme.onErrorContainer.withValues(alpha: 0.9),
                fontSize: 14,
              ),
            ),
          )),
        ],
      ),
    );
  }

  /// Reset all selections
  void resetSelections() {
    setState(() {
      for (final group in _optionGroups) {
        if (group.options != null) {
          for (final option in group.options!) {
            option.isSelected = false;
          }
        }
      }
    });
    _validateAllGroups();
    widget.onSelectionChanged?.call([]);
  }

  /// Get selected option IDs
  List<String> get selectedOptionIds => _getSelectedOptionIds();

  /// Check if all selections are valid
  bool get isValid => _validationErrors.isEmpty;

  /// Get validation errors
  Map<String, String> get validationErrors => _validationErrors;
}

/// Menu Option Summary Widget
/// 
/// Displays a summary of selected options with prices
class MenuOptionSummary extends StatelessWidget {
  final List<MenuOptionGroup> optionGroups;
  final int basePrice;
  final TextStyle? textStyle;

  const MenuOptionSummary({
    Key? key,
    required this.optionGroups,
    required this.basePrice,
    this.textStyle,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final selectedOptions = <MenuOption>[];
    int optionsTotal = 0;

    for (final group in optionGroups) {
      if (group.options != null) {
        for (final option in group.options!) {
          if (option.isSelected) {
            selectedOptions.add(option);
            optionsTotal += option.price;
          }
        }
      }
    }

    if (selectedOptions.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ตัวเลือกที่เลือก',
            style: (textStyle ?? const TextStyle(fontSize: 14)).copyWith(
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          ...selectedOptions.map((option) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    option.name,
                    style: textStyle ?? const TextStyle(fontSize: 14),
                  ),
                ),
                if (option.price > 0)
                  Text(
                    '+฿${option.price}',
                    style: (textStyle ?? const TextStyle(fontSize: 14)).copyWith(
                      fontWeight: FontWeight.bold,
                      color: colorScheme.primary,
                    ),
                  ),
              ],
            ),
          )),
          if (optionsTotal > 0) ...[
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'รวมตัวเลือกเพิ่ม',
                  style: (textStyle ?? const TextStyle(fontSize: 14)).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '+฿$optionsTotal',
                  style: (textStyle ?? const TextStyle(fontSize: 14)).copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'รวมทั้งหมด',
                  style: (textStyle ?? const TextStyle(fontSize: 16)).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '฿${basePrice + optionsTotal}',
                  style: (textStyle ?? const TextStyle(fontSize: 16)).copyWith(
                    fontWeight: FontWeight.bold,
                    color: colorScheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
