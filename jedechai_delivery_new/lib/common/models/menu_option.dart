import 'menu_item.dart';

/// Menu Option Group Model
/// Represents a reusable group of options for menu items (e.g., "Spiciness Level", "Add-ons")
class MenuOptionGroup {
  final String id;
  final String? merchantId; // Nullable for backward compatibility
  final String name;
  final int minSelection;
  final int maxSelection;
  final DateTime createdAt;
  final DateTime updatedAt;
  List<MenuOption>? options;

  MenuOptionGroup({
    required this.id,
    this.merchantId,
    required this.name,
    required this.minSelection,
    required this.maxSelection,
    required this.createdAt,
    required this.updatedAt,
    this.options,
  });

  factory MenuOptionGroup.fromJson(Map<String, dynamic> json) {
    return MenuOptionGroup(
      id: json['id'] as String,
      merchantId: json['merchant_id'] as String?, // Handle nullable merchant_id
      name: json['name'] as String? ?? '', // Handle null name
      minSelection: (json['min_selection'] as int?) ?? 0, // Handle null min_selection
      maxSelection: (json['max_selection'] as int?) ?? 1, // Handle null max_selection
      createdAt: DateTime.parse(json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updated_at'] as String? ?? DateTime.now().toIso8601String()),
      options: json['menu_options'] != null
          ? (json['menu_options'] as List)
              .map((option) => MenuOption.fromJson(option))
              .toList()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (merchantId != null) 'merchant_id': merchantId,
      'name': name,
      'min_selection': minSelection,
      'max_selection': maxSelection,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      if (options != null) 'options': options!.map((o) => o.toJson()).toList(),
    };
  }

  /// Check if this group is required (min_selection > 0)
  bool get isRequired => minSelection > 0;

  /// Check if this group allows multiple selections (max_selection > 1)
  bool get isMultiSelect => maxSelection > 1;

  /// Get selection type description
  String get selectionType {
    if (isRequired && isMultiSelect) {
      return 'จำเป็น (เลือก $minSelection-$maxSelection รายการ)';
    } else if (isRequired) {
      return 'จำเป็น (เลือก 1 รายการ)';
    } else if (isMultiSelect) {
      return 'ไม่บังคับ (เลือกได้สูงสุด $maxSelection รายการ)';
    } else {
      return 'ไม่บังคับ (เลือกได้ 1 รายการ)';
    }
  }

  /// Validate selected options count
  bool validateSelection(int selectedCount) {
    return selectedCount >= minSelection && selectedCount <= maxSelection;
  }

  /// Get validation error message
  String? getValidationError(int selectedCount) {
    if (selectedCount < minSelection) {
      return 'กรุณาเลือกอย่างน้อย $minSelection รายการ';
    } else if (selectedCount > maxSelection) {
      return 'เลือกได้ไม่เกิน $maxSelection รายการ';
    }
    return null;
  }

  MenuOptionGroup copyWith({
    String? id,
    String? merchantId,
    String? name,
    int? minSelection,
    int? maxSelection,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<MenuOption>? options,
  }) {
    return MenuOptionGroup(
      id: id ?? this.id,
      merchantId: merchantId ?? this.merchantId,
      name: name ?? this.name,
      minSelection: minSelection ?? this.minSelection,
      maxSelection: maxSelection ?? this.maxSelection,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      options: options ?? this.options,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MenuOptionGroup &&
        other.id == id &&
        other.merchantId == merchantId &&
        other.name == name &&
        other.minSelection == minSelection &&
        other.maxSelection == maxSelection;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        merchantId.hashCode ^
        name.hashCode ^
        minSelection.hashCode ^
        maxSelection.hashCode;
  }

  @override
  String toString() {
    return 'MenuOptionGroup(id: $id, name: $name, minSelection: $minSelection, maxSelection: $maxSelection)';
  }
}

/// Menu Option Model
/// Represents an individual option within a group (e.g., "Not Spicy", "Extra Pork")
class MenuOption {
  final String id;
  final String groupId;
  final String name;
  final int price;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime updatedAt;
  bool isSelected;

  MenuOption({
    required this.id,
    required this.groupId,
    required this.name,
    required this.price,
    required this.isAvailable,
    required this.createdAt,
    required this.updatedAt,
    this.isSelected = false,
  });

  factory MenuOption.fromJson(Map<String, dynamic> json) {
    return MenuOption(
      id: json['id'] as String,
      groupId: json['group_id'] as String,
      name: json['name'] as String,
      price: json['price'] as int,
      isAvailable: json['is_available'] as bool,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'group_id': groupId,
      'name': name,
      'price': price,
      'is_available': isAvailable,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  /// Get formatted price with currency
  String get formattedPrice {
    if (price == 0) return '';
    return '+฿$price';
  }

  /// Get display name with price
  String get displayName {
    if (price == 0) return name;
    return '$name $formattedPrice';
  }

  /// Check if this option can be selected
  bool get canSelect => isAvailable;

  MenuOption copyWith({
    String? id,
    String? groupId,
    String? name,
    int? price,
    bool? isAvailable,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isSelected,
  }) {
    return MenuOption(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      name: name ?? this.name,
      price: price ?? this.price,
      isAvailable: isAvailable ?? this.isAvailable,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isSelected: isSelected ?? this.isSelected,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is MenuOption &&
        other.id == id &&
        other.groupId == groupId &&
        other.name == name &&
        other.price == price &&
        other.isAvailable == isAvailable;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        groupId.hashCode ^
        name.hashCode ^
        price.hashCode ^
        isAvailable.hashCode;
  }

  @override
  String toString() {
    return 'MenuOption(id: $id, name: $name, price: $price, isAvailable: $isAvailable)';
  }
}

/// Menu Item with Options Model
/// Combines menu item with its option groups and individual options
class MenuItemWithOptions {
  final MenuItem menuItem;
  final List<MenuOptionGroup> optionGroups;

  MenuItemWithOptions({
    required this.menuItem,
    required this.optionGroups,
  });

  factory MenuItemWithOptions.fromJson(Map<String, dynamic> json, List<dynamic> linksJson) {
    // Map the 'linksJson' (which comes from menu_item_option_links)
    // extracting the nested 'menu_option_groups' from each link.
    final groups = linksJson.map((link) {
      final groupJson = link['menu_option_groups'];
      return MenuOptionGroup.fromJson(groupJson);
    }).toList();
    
    return MenuItemWithOptions(
      menuItem: MenuItem.fromJson(json),
      optionGroups: groups,
    );
  }

  // Convenience getters
  String get id => menuItem.id;
  String get name => menuItem.name;
  String? get description => menuItem.description;
  double get basePrice => menuItem.price;
  String? get category => menuItem.category;
  bool get isAvailable => menuItem.isAvailable;
  String? get imageUrl => menuItem.imageUrl;

  /// Calculate total price including selected options
  double get totalPrice {
    double total = basePrice;
    for (final group in optionGroups) {
      if (group.options != null) {
        for (final option in group.options!) {
          if (option.isSelected) {
            total += option.price.toDouble();
          }
        }
      }
    }
    return total;
  }

  /// Get formatted total price
  String get formattedTotalPrice => '฿${totalPrice.ceil()}';

  /// Get list of selected option IDs
  List<String> get selectedOptionIds {
    final List<String> selectedIds = [];
    for (final group in optionGroups) {
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

  /// Validate all option groups
  bool validateSelections() {
    for (final group in optionGroups) {
      if (group.options != null) {
        final selectedCount = group.options!.where((o) => o.isSelected).length;
        if (!group.validateSelection(selectedCount)) {
          return false;
        }
      }
    }
    return true;
  }

  /// Get validation errors for all groups
  Map<String, String> getValidationErrors() {
    final Map<String, String> errors = {};
    for (final group in optionGroups) {
      if (group.options != null) {
        final selectedCount = group.options!.where((o) => o.isSelected).length;
        final error = group.getValidationError(selectedCount);
        if (error != null) {
          errors[group.id] = error;
        }
      }
    }
    return errors;
  }

  /// Reset all selections
  void resetSelections() {
    for (final group in optionGroups) {
      if (group.options != null) {
        for (final option in group.options!) {
          option.isSelected = false;
        }
      }
    }
  }

  /// Get selected options as readable text
  String get selectedOptionsText {
    final List<String> selections = [];
    for (final group in optionGroups) {
      if (group.options != null) {
        final selectedOptions = group.options!.where((o) => o.isSelected);
        if (selectedOptions.isNotEmpty) {
          selections.add('${group.name}: ${selectedOptions.map((o) => o.name).join(', ')}');
        }
      }
    }
    return selections.join('\n');
  }
}
