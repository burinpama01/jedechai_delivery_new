import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import '../../../common/models/menu_option.dart';
import '../../../common/services/menu_option_service.dart';
import '../../../common/widgets/menu_option_selector.dart';
import '../../../common/models/menu_item.dart';
import '../../../common/widgets/app_network_image.dart';
import '../../../theme/app_theme.dart';

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
      
      // Pop first with the cart item data
      Navigator.of(context).pop(cartItem);
      
      // Then show success message (after pop)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ เพิ่ม ${widget.menuItem.name} ลงตะกร้าแล้ว'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugLog('❌ Error adding to cart: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('❌ เพิ่มลงตะกร้าไม่สำเร็จ: $e'),
            backgroundColor: Colors.red,
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
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onWillPop();
      },
      child: Scaffold(
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(),
        bottomNavigationBar: _buildBottomBar(),
      ),
    );
  }

  Widget _buildContent() {
    return CustomScrollView(
      slivers: [
        // App Bar with Image Background
        SliverAppBar(
          expandedHeight: 250,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: _buildFoodImage(),
          ),
          actions: [
            // Favorite Button (Optional)
            IconButton(
              icon: const Icon(Icons.favorite_border),
              onPressed: () {
                // TODO: Add to favorites
              },
            ),
          ],
        ),

        // Content
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Food Header
                _buildFoodHeader(),
                const SizedBox(height: 24),

                // Options Section
                if (_menuItemWithOptions != null &&
                    _menuItemWithOptions!.optionGroups.isNotEmpty) ...[
                  _buildOptionsSection(),
                  const SizedBox(height: 24),
                ],

                // Description
                if (widget.menuItem.description?.isNotEmpty == true) ...[
                  _buildDescriptionSection(),
                  const SizedBox(height: 24),
                ],

                // Restaurant Info
                if (widget.restaurantName != null) ...[
                  _buildRestaurantSection(),
                  const SizedBox(height: 100), // Space for bottom bar
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFoodImage() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      height: 250,
      color: colorScheme.surfaceContainerHighest,
      child: AppNetworkImage(
        imageUrl: widget.menuItem.imageUrl,
        fit: BoxFit.cover,
        width: double.infinity,
        height: 250,
        backgroundColor: colorScheme.surfaceContainerHighest,
      ),
    );
  }

  Widget _buildFoodHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    final availabilityColor =
        widget.menuItem.isAvailable ? colorScheme.tertiary : colorScheme.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Food Name
        Text(
          widget.menuItem.name,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),

        // Price and Category
        Row(
          children: [
            Text(
              '฿${widget.menuItem.price}',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            if (widget.menuItem.category?.isNotEmpty == true)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  widget.menuItem.category!,
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // Availability Status
        Row(
          children: [
            Icon(
              widget.menuItem.isAvailable ? Icons.check_circle : Icons.cancel,
              size: 16,
              color: availabilityColor,
            ),
            const SizedBox(width: 4),
            Text(
              widget.menuItem.isAvailable ? 'พร้อมจำหน่าย' : 'หมด',
              style: TextStyle(
                fontSize: 14,
                color: availabilityColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildOptionsSection() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ปรับแต่งออเดอร์',
          style: TextStyle(
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
                  'ไม่มีตัวเลือกเพิ่มเติมสำหรับเมนูนี้',
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
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'กำลังโหลดตัวเลือก...',
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentOrange),
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
        const Text(
          'รายละเอียด',
          style: TextStyle(
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

  Widget _buildRestaurantSection() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'ร้านอาหาร',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.store, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  widget.restaurantName ?? 'ร้านอาหาร',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Quantity Counter
            _buildQuantityCounter(),
            const SizedBox(width: 16),

            // Add to Cart Button
            Expanded(
              child: ElevatedButton(
                onPressed: ((_menuItemWithOptions == null || _isValid) && widget.menuItem.isAvailable && !_isAddingToCart)
                    ? _addToCart
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.primary,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isAddingToCart
                    ? SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(colorScheme.onPrimary),
                        ),
                      )
                    : Text(
                        'เพิ่มลงตะกร้า — ฿${_calculateTotalPrice()}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuantityCounter() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Decrease Button
          InkWell(
            onTap: () => _updateQuantity(_quantity - 1),
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(8),
              bottomLeft: Radius.circular(8),
            ),
            child: Container(
              width: 40,
              height: 48,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(8),
                  bottomLeft: Radius.circular(8),
                ),
              ),
              child: const Icon(Icons.remove),
            ),
          ),

          // Quantity Display
          Container(
            width: 50,
            height: 48,
            alignment: Alignment.center,
            child: Text(
              '$_quantity',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // Increase Button
          InkWell(
            onTap: () => _updateQuantity(_quantity + 1),
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(8),
              bottomRight: Radius.circular(8),
            ),
            child: Container(
              width: 40,
              height: 48,
              decoration: const BoxDecoration(
                borderRadius: BorderRadius.only(
                  topRight: Radius.circular(8),
                  bottomRight: Radius.circular(8),
                ),
              ),
              child: const Icon(Icons.add),
            ),
          ),
        ],
      ),
    );
  }
}
