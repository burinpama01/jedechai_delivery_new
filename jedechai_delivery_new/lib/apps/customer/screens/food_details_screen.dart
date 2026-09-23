import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';
import '../../../common/models/menu_option.dart';
import '../../../common/services/menu_option_service.dart';
import '../../../common/widgets/menu_option_selector.dart';
import '../../../common/models/menu_item.dart';
import '../../../common/widgets/app_network_image.dart';
import '../../../theme/jdc_colors.dart';

class FoodDetailsScreen extends StatefulWidget {
  final MenuItem menuItem;
  final String? restaurantName;

  const FoodDetailsScreen({
    Key? key,
    required this.menuItem,
    this.restaurantName,
  }) : super(key: key);

  @override
  State<FoodDetailsScreen> createState() => _FoodDetailsScreenState();
}

class _FoodDetailsScreenState extends State<FoodDetailsScreen> {
  MenuItemWithOptions? _menuItemWithOptions;
  List<String> _selectedOptionIds = [];
  int _quantity = 1;
  bool _isLoading = true;
  bool _isAddingToCart = false;
  bool _isValid = false;

  @override
  void initState() {
    super.initState();
    _loadMenuItemWithOptions();
  }

  Future<void> _loadMenuItemWithOptions() async {
    try {
      setState(() => _isLoading = true);
      
      debugLog('🔍 Loading menu item with options for: ${widget.menuItem.id}');
      
      final menuItemWithOptions = await MenuOptionService()
          .getMenuItemWithOptions(widget.menuItem.id);
      
      debugLog('📊 Menu item with options loaded: ${menuItemWithOptions != null}');
      if (menuItemWithOptions != null) {
        debugLog('📋 Option groups count: ${menuItemWithOptions.optionGroups.length}');
        for (int i = 0; i < menuItemWithOptions.optionGroups.length; i++) {
          final group = menuItemWithOptions.optionGroups[i];
          debugLog('   └─ Group $i: ${group.name} (${group.options?.length ?? 0} options)');
        }
      }
      
      if (mounted) {
        setState(() {
          _menuItemWithOptions = menuItemWithOptions;
          // ✅✅✅ แทรกโค้ดชุดนี้เข้าไปตรงนี้ครับ ✅✅✅
          // ถ้าโหลดมาแล้วพบว่า "ไม่มีออฟชั่นให้เลือก" (กลุ่มว่างเปล่า)
          // ให้ถือว่าผ่าน (Valid) ทันที เพื่อให้ปุ่ม Add to Cart ทำงาน
          if (_menuItemWithOptions != null && _menuItemWithOptions!.optionGroups.isEmpty) {
            _isValid = true;
          }
          // ✅✅✅ จบส่วนที่แทรก ✅✅✅
          _isLoading = false;
        });
      }
    } catch (e) {
      debugLog('❌ Error loading menu item with options: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _onSelectionChanged(List<String> selectedOptionIds) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _selectedOptionIds = selectedOptionIds;
        });
      }
    });
  }

  void _onValidationChanged(bool isValid) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _isValid = isValid;
        });
      }
    });
  }

  int _calculateTotalPrice() {
    if (_menuItemWithOptions == null) return widget.menuItem.price.round();
    
    int total = widget.menuItem.price.round();
    
    // Add selected options prices
    for (final group in _menuItemWithOptions!.optionGroups) {
      if (group.options != null) {
        for (final option in group.options!) {
          if (option.isSelected) {
            total += option.price;
          }
        }
      }
    }
    
    return total * _quantity;
  }

  void _updateQuantity(int newQuantity) {
    if (newQuantity >= 1 && newQuantity <= 99) {
      setState(() {
        _quantity = newQuantity;
      });
    }
  }

  Future<void> _addToCart() async {
    // ถ้ามีออปชั่นต้องเลือกให้ครบถ้วน แต่ถ้าไม่มีออปชั่นให้ผ่านได้เลย
    if (_menuItemWithOptions != null && !_isValid) return;

    setState(() => _isAddingToCart = true);

    try {
      // Get selected option names for display (ถ้ามีออปชั่น)
      final selectedOptionNames = <String>[];
      if (_menuItemWithOptions != null) {
        for (final groupId in _selectedOptionIds) {
          for (final group in _menuItemWithOptions!.optionGroups) {
            for (final option in group.options ?? []) {
              if (option.id == groupId) {
                selectedOptionNames.add(option.name);
                break;
              }
            }
          }
        }
      }

      // Create cart item data
      final cartItem = {
        'id': widget.menuItem.id,
        'name': widget.menuItem.name,
        'base_price': widget.menuItem.price,
        'price': _calculateTotalPrice().toDouble(),
        'selected_options': selectedOptionNames,
        'options': selectedOptionNames, // เพิ่มฟิลด์ options สำหรับความเข้ากันได้
        'quantity': _quantity,
        'image_url': widget.menuItem.imageUrl,
        'description': widget.menuItem.description,
      };

      debugLog('🛒 Adding to cart:');
      debugLog('   └─ Menu Item: ${widget.menuItem.name}');
      debugLog('   └─ Quantity: $_quantity');
      debugLog('   └─ Base Price: ฿${widget.menuItem.price}');
      debugLog('   └─ Selected Options: $selectedOptionNames');
      debugLog('   └─ Total Price: ฿${_calculateTotalPrice()}');

      // Add to cart (pass back to restaurant detail screen)
      debugLog('🔄 Navigating back with cart item:');
      debugLog('   └─ Cart Item: $cartItem');
      
      // Capture before pop — context becomes invalid after pop
      final messenger = ScaffoldMessenger.of(context);
      final addedMsg = AppLocalizations.of(context)!.foodDetAddedToCart(widget.menuItem.name);
      Navigator.of(context).pop(cartItem);
      messenger.showSnackBar(SnackBar(
        content: Text(addedMsg),
        backgroundColor: JdcColors.of(context).successInk,
        duration: Duration(seconds: 2),
      ));
    } catch (e) {
      debugLog('❌ Error adding to cart: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(AppLocalizations.of(context)!.foodDetAddFailed(e.toString())),
            backgroundColor: JdcColors.of(context).danger,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAddingToCart = false);
      }
    }
  }

  // Override back button behavior to handle navigation properly
  Future<bool> _onWillPop() async {
    // If user is adding to cart, prevent back navigation
    if (_isAddingToCart) {
      return false;
    }
    
    // Allow back navigation without returning data
    Navigator.of(context).pop(null);
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onWillPop();
      },
      child: Scaffold(
        backgroundColor: jdc.paper,
        body: _isLoading
            ? Center(child: CircularProgressIndicator(color: jdc.brand))
            : _buildB1Content(),
        bottomNavigationBar: _buildB1BottomBar(),
      ),
    );
  }

  Widget _buildB1Content() {
    return CustomScrollView(
      slivers: [
        // 150px image header with back button overlay
        SliverToBoxAdapter(child: _buildB1ImageHeader()),
        // Scrollable content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Item name / desc / price
                _buildB1FoodHeader(),
                const SizedBox(height: 16),
                // Options
                if (_menuItemWithOptions != null &&
                    _menuItemWithOptions!.optionGroups.isNotEmpty) ...[
                  _buildOptionsSection(),
                  const SizedBox(height: 16),
                ],
                // Description
                if (widget.menuItem.description?.isNotEmpty == true) ...[
                  _buildDescriptionSection(),
                  const SizedBox(height: 16),
                ],
                // Bottom space
                const SizedBox(height: 100),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildB1ImageHeader() {
    final jdc = JdcColors.of(context);
    return SizedBox(
      height: 150,
      child: Stack(
        fit: StackFit.expand,
        children: [
          // Image or placeholder
          widget.menuItem.imageUrl != null &&
                  widget.menuItem.imageUrl!.isNotEmpty
              ? AppNetworkImage(
                  imageUrl: widget.menuItem.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: 150,
                  backgroundColor: jdc.brandSoft,
                )
              : Container(
                  color: jdc.brandSoft,
                  alignment: Alignment.center,
                  child: Text(
                    widget.menuItem.name.isNotEmpty
                        ? widget.menuItem.name
                            .split(' ')
                            .take(2)
                            .map((w) => w.isNotEmpty ? w[0] : '')
                            .join()
                        : '',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: jdc.brandOnSoft,
                    ),
                  ),
                ),
          // Back button overlay
          Positioned(
            top: 16, left: 16,
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(null),
              child: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: jdc.surface,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: jdc.shadowFloat,
                ),
                child: Icon(Icons.chevron_left,
                    size: 21, color: jdc.text),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildB1FoodHeader() {
    final jdc = JdcColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.menuItem.name,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: jdc.text,
          ),
        ),
        if (widget.menuItem.description?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(
            widget.menuItem.description!,
            style: TextStyle(fontSize: 12, color: jdc.muted),
          ),
        ],
        const SizedBox(height: 6),
        Text(
          '฿${widget.menuItem.price.round()}',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: jdc.link,
          ),
        ),
        if (!widget.menuItem.isAvailable) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: jdc.dangerSoft,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: jdc.dangerLine),
            ),
            child: Text(
              AppLocalizations.of(context)!.foodDetSoldOut,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: jdc.dangerInk),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildOptionsSection() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.foodDetCustomize,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        if (_menuItemWithOptions != null && _menuItemWithOptions!.optionGroups.isNotEmpty)
          MenuOptionSelector(
            optionGroups: _menuItemWithOptions!.optionGroups,
            onSelectionChanged: _onSelectionChanged,
            onValidationChanged: _onValidationChanged,
            showValidationErrors: true,
          )
        else if (_menuItemWithOptions != null && _menuItemWithOptions!.optionGroups.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!.foodDetNoOptions,
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Icon(Icons.refresh, color: colorScheme.onSurfaceVariant),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!.foodDetLoadingOptions,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ),
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(JdcColors.of(context).brand),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildDescriptionSection() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppLocalizations.of(context)!.foodDetDescription,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          widget.menuItem.description ?? '',
          style: TextStyle(
            fontSize: 14,
            color: colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  Widget _buildB1BottomBar() {
    final jdc = JdcColors.of(context);
    final canAdd = (_menuItemWithOptions == null || _isValid) &&
        widget.menuItem.isAvailable &&
        !_isAddingToCart;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: jdc.surface,
        border: Border(top: BorderSide(color: jdc.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            // Quantity counter
            _buildB1QuantityCounter(),
            const SizedBox(width: 12),
            // Add to cart button
            Expanded(
              child: GestureDetector(
                onTap: canAdd ? _addToCart : null,
                child: Container(
                  height: 56,
                  decoration: BoxDecoration(
                    color: canAdd ? jdc.cta : jdc.line,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: canAdd ? jdc.shadowBrand : null,
                  ),
                  alignment: Alignment.center,
                  child: _isAddingToCart
                      ? SizedBox(
                          width: 20, height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: jdc.onCta,
                          ),
                        )
                      : Text(
                          AppLocalizations.of(context)!
                              .foodDetAddToCart(
                                  _calculateTotalPrice().toString()),
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: canAdd ? jdc.onCta : jdc.muted,
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

  Widget _buildB1QuantityCounter() {
    final jdc = JdcColors.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: jdc.line),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            onTap: () => _updateQuantity(_quantity - 1),
            child: Container(
              width: 44, height: 48,
              alignment: Alignment.center,
              child: Icon(Icons.remove, size: 18, color: jdc.text),
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '$_quantity',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: jdc.text),
            ),
          ),
          GestureDetector(
            onTap: () => _updateQuantity(_quantity + 1),
            child: Container(
              width: 44, height: 48,
              alignment: Alignment.center,
              child: Icon(Icons.add, size: 18, color: jdc.text),
            ),
          ),
        ],
      ),
    );
  }

}
