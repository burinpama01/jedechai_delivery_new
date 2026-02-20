import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../theme/app_theme.dart';
import '../../../../common/models/coupon.dart';
import '../../../../common/models/menu_item.dart';
import '../../../../common/services/coupon_service.dart';
import '../../../../common/services/menu_option_service.dart';
import '../../../../common/services/supabase_service.dart';
import '../../../../common/widgets/app_network_image.dart';
import '../../providers/cart_provider.dart';
import '../food_details_screen.dart';
import 'food_checkout_screen.dart';

/// Restaurant Detail Screen — หน้ารายละเอียดร้านอาหาร (แบบ GrabFood / LINE MAN)
///
/// แสดง cover image, ข้อมูลร้าน, เมนูแบ่งตาม category, floating cart bar
class RestaurantDetailScreen extends StatefulWidget {
  final String merchantId;
  final String merchantName;

  const RestaurantDetailScreen({
    super.key,
    required this.merchantId,
    required this.merchantName,
  });

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen>
    with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _menuItems = [];
  Map<String, List<Map<String, dynamic>>> _menuByCategory = {};
  List<String> _categories = [];
  Set<String> _menuItemsWithRequiredOptions = {};
  bool _isLoading = true;
  String? _error;
  String? _shopPhotoUrl;
  String? _shopAddress;
  String? _phoneNumber;
  String? _promoText;
  bool _promoEnabled = false;
  final CouponService _couponService = CouponService();
  List<Coupon> _merchantCoupons = [];

  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _loadPromoConfig();
  }

  Future<void> _loadPromoConfig() async {
    try {
      final config = await SupabaseService.client
          .from('system_config')
          .select('promo_text, promo_enabled')
          .maybeSingle();
      if (mounted && config != null) {
        setState(() {
          _promoText = config['promo_text'] as String?;
          _promoEnabled = config['promo_enabled'] == true;
        });
      }
    } catch (e) {
      debugLog('⚠️ Error loading promo config: $e');
    }
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Fetch merchant profile + menu items in parallel
      final futures = await Future.wait([
        Supabase.instance.client
            .from('profiles')
            .select('shop_photo_url, shop_address, phone_number')
            .eq('id', widget.merchantId)
            .maybeSingle(),
        Supabase.instance.client
            .from('menu_items')
            .select('*')
            .eq('merchant_id', widget.merchantId)
            .eq('is_available', true)
            .order('name'),
      ]);

      final profile = futures[0] as Map<String, dynamic>?;
      final menuResponse = futures[1] as List<dynamic>;

      _shopPhotoUrl = profile?['shop_photo_url'] as String?;
      _shopAddress = profile?['shop_address'] as String?;
      _phoneNumber = profile?['phone_number'] as String?;

      _menuItems = List<Map<String, dynamic>>.from(menuResponse);

      final coupons = await _couponService.getAvailableCoupons(
        serviceType: 'food',
        merchantId: widget.merchantId,
      );
      _merchantCoupons = coupons.where((c) => c.merchantId == widget.merchantId).toList();

      // Fetch option links to determine which items have required options
      _menuItemsWithRequiredOptions = {};
      try {
        for (final item in _menuItems) {
          final menuItemId = item['id'] as String;
          final optionGroups = await MenuOptionService().getOptionGroupsForMenuItem(menuItemId);
          final hasRequired = optionGroups.any((g) => g.isRequired);
          if (hasRequired) {
            _menuItemsWithRequiredOptions.add(menuItemId);
          }
        }
        debugLog('📊 เมนูที่มีตัวเลือกบังคับ: ${_menuItemsWithRequiredOptions.length} รายการ');
      } catch (e) {
        debugLog('⚠️ โหลด option links ไม่ได้: $e');
      }

      // Group by category
      _menuByCategory = {};
      for (final item in _menuItems) {
        final cat = (item['category'] as String?) ?? 'อื่นๆ';
        _menuByCategory.putIfAbsent(cat, () => []).add(item);
      }
      _categories = _menuByCategory.keys.toList();

      // Setup tab controller
      _tabController?.dispose();
      if (_categories.isNotEmpty) {
        _tabController = TabController(length: _categories.length, vsync: this);
      }

      debugLog('📊 ร้าน ${widget.merchantName}: ${_menuItems.length} เมนู, ${_categories.length} หมวด');

      setState(() => _isLoading = false);
    } catch (e) {
      debugLog('❌ โหลดเมนูล้มเหลว: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accentOrange))
          : _error != null
              ? _buildErrorState()
              : _buildContent(),
      bottomNavigationBar: _buildCartBar(),
    );
  }

  Widget _buildContent() {
    return NestedScrollView(
      headerSliverBuilder: (context, innerBoxIsScrolled) {
        return [
          // Cover Image + Back button
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppTheme.accentOrange,
            foregroundColor: Colors.white,
            title: innerBoxIsScrolled ? Text(widget.merchantName) : null,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildCoverImage(),
            ),
          ),
          // Restaurant Info
          SliverToBoxAdapter(child: _buildRestaurantInfo()),
          // Category Tabs
          if (_categories.isNotEmpty && _tabController != null)
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabBarDelegate(
                TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  labelColor: AppTheme.accentOrange,
                  unselectedLabelColor: Colors.grey[500],
                  indicatorColor: AppTheme.accentOrange,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  tabs: _categories.map((c) => Tab(text: c)).toList(),
                ),
              ),
            ),
        ];
      },
      body: _categories.isEmpty
          ? _buildEmptyMenu()
          : TabBarView(
              controller: _tabController,
              children: _categories.map((cat) {
                final items = _menuByCategory[cat] ?? [];
                return _buildMenuList(items);
              }).toList(),
            ),
    );
  }

  Widget _buildCoverImage() {
    return Stack(
      fit: StackFit.expand,
      children: [
        _shopPhotoUrl != null && _shopPhotoUrl!.isNotEmpty
            ? AppNetworkImage(
                imageUrl: _shopPhotoUrl,
                fit: BoxFit.cover,
                backgroundColor: Colors.grey[200],
              )
            : _buildCoverPlaceholder(),
        // Gradient overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Colors.black.withValues(alpha: 0.6),
              ],
            ),
          ),
        ),
        // Restaurant name at bottom
        Positioned(
          left: 16,
          bottom: 16,
          right: 16,
          child: Text(
            widget.merchantName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCoverPlaceholder() {
    return const GrayscaleLogoPlaceholder(
      fit: BoxFit.contain,
      backgroundColor: Colors.white,
      padding: EdgeInsets.all(24),
    );
  }

  Widget _buildRestaurantInfo() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Rating + Delivery info
          Row(
            children: [
              Icon(Icons.star, size: 18, color: Colors.amber[600]),
              const SizedBox(width: 4),
              Text('4.5', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey[800])),
              Text(' (100+)', style: TextStyle(color: Colors.grey[400], fontSize: 13)),
              const SizedBox(width: 16),
              Icon(Icons.access_time, size: 16, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text('20-30 นาที', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
              const SizedBox(width: 16),
              Icon(Icons.delivery_dining, size: 16, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text('ค่าส่ง ฿15', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            ],
          ),
          if (_shopAddress != null && _shopAddress!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    _shopAddress!,
                    style: TextStyle(color: Colors.grey[500], fontSize: 13),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if (_phoneNumber != null && _phoneNumber!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.phone_outlined, size: 16, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text(_phoneNumber!, style: TextStyle(color: Colors.grey[500], fontSize: 13)),
              ],
            ),
          ],
          const SizedBox(height: 12),
          // Promo tag (admin-configurable)
          if (_promoEnabled && _promoText != null && _promoText!.isNotEmpty)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red[100]!),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_offer, size: 14, color: Colors.red[400]),
                  const SizedBox(width: 4),
                  Text(
                    _promoText!,
                    style: TextStyle(fontSize: 12, color: Colors.red[600], fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
          if (_merchantCoupons.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _merchantCoupons.map((coupon) {
                return InkWell(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: coupon.code));
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('คัดลอกโค้ด ${coupon.code} แล้ว')),
                    );
                  },
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.green.withValues(alpha: 0.25)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.local_offer_outlined, size: 14, color: Colors.green),
                        const SizedBox(width: 6),
                        Text(
                          '${coupon.code} • ${coupon.discountText}',
                          style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 4),
            Text(
              'แตะเพื่อคัดลอกโค้ดไปใช้ตอนชำระเงิน',
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMenuList(List<Map<String, dynamic>> items) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final menuItemId = item['id'] as String;
        final hasRequired = _menuItemsWithRequiredOptions.contains(menuItemId);
        return _MenuItemCard(
          item: item,
          merchantId: widget.merchantId,
          merchantName: widget.merchantName,
          hasRequiredOptions: hasRequired,
          onAddToCart: (cartItem) => _addToCart(cartItem),
        );
      },
    );
  }

  Widget _buildEmptyMenu() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text('ไม่มีเมนูในขณะนี้', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchData,
            icon: const Icon(Icons.refresh),
            label: const Text('รีเฟรช'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentOrange,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            const Text('ไม่สามารถโหลดเมนูได้', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('กรุณาลองใหม่อีกครั้ง', style: TextStyle(color: Colors.grey[500])),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchData,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentOrange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _addToCart(CartItem cartItem) {
    final cart = context.read<CartProvider>();
    final added = cart.addItem(
      merchantId: widget.merchantId,
      merchantName: widget.merchantName,
      item: cartItem,
    );

    if (!added) {
      // Different restaurant — ask to clear
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('เปลี่ยนร้านอาหาร?'),
          content: Text('ตะกร้ามีอาหารจาก "${cart.merchantName}" อยู่\nต้องการล้างตะกร้าและสั่งจากร้านนี้แทนหรือไม่?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                cart.forceAddItem(
                  merchantId: widget.merchantId,
                  merchantName: widget.merchantName,
                  item: cartItem,
                );
                Navigator.of(ctx).pop();
                _showAddedSnackBar(cartItem.name);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentOrange,
                foregroundColor: Colors.white,
              ),
              child: const Text('ล้างและเพิ่ม'),
            ),
          ],
        ),
      );
    } else {
      _showAddedSnackBar(cartItem.name);
    }
  }

  void _showAddedSnackBar(String name) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('✅ เพิ่ม $name ลงตะกร้าแล้ว'),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      ),
    );
  }

  Widget _buildCartBar() {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        if (cart.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: GestureDetector(
              onTap: () {
                // Show cart bottom sheet
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _buildCartSheet(),
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.accentOrange.withValues(alpha: 0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${cart.totalItems}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'ดูตะกร้า',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15),
                      ),
                    ),
                    Text(
                      '฿${cart.subtotal.ceil()}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCartSheet() {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.85,
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
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(2)),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_bag, color: AppTheme.accentOrange),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text('ตะกร้าของคุณ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        TextButton(
                          onPressed: () {
                            cart.clearCart();
                            Navigator.of(context).pop();
                          },
                          child: const Text('ล้าง', style: TextStyle(color: Colors.red)),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Items
                  Expanded(
                    child: ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.all(16),
                      itemCount: cart.items.length,
                      separatorBuilder: (_, __) => const Divider(height: 20),
                      itemBuilder: (context, index) {
                        final item = cart.items[index];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Image
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Container(
                                width: 50,
                                height: 50,
                                color: Colors.grey[100],
                                child: item.imageUrl != null
                                    ? AppNetworkImage(
                                        imageUrl: item.imageUrl,
                                        fit: BoxFit.cover,
                                        backgroundColor: Colors.grey[100],
                                      )
                                    : const GrayscaleLogoPlaceholder(fit: BoxFit.contain),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                                  if (item.selectedOptions.isNotEmpty)
                                    Text(item.selectedOptions.join(', '),
                                        style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text('฿${item.totalPrice.ceil()}',
                                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentOrange)),
                                      const Spacer(),
                                      _buildQtyControl(cart, index, item),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                  // Bottom
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -2))],
                    ),
                    child: SafeArea(
                      child: Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('รวม', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('฿${cart.subtotal.ceil()}',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.accentOrange)),
                            ],
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.of(context).pop(); // close sheet
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (context) => const FoodCheckoutScreen(),
                                  ),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppTheme.accentOrange,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: Text('ไปชำระเงิน — ฿${cart.subtotal.ceil()}',
                                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildQtyControl(CartProvider cart, int index, CartItem item) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey[300]!),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => cart.updateQuantity(index, item.quantity - 1),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(
                item.quantity > 1 ? Icons.remove : Icons.delete_outline,
                size: 18,
                color: item.quantity > 1 ? Colors.grey[700] : Colors.red,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text('${item.quantity}', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
          InkWell(
            onTap: () => cart.updateQuantity(index, item.quantity + 1),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(Icons.add, size: 18, color: AppTheme.accentOrange),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// Menu Item Card — แสดงเมนูแต่ละรายการ
// ============================================================
class _MenuItemCard extends StatelessWidget {
  final Map<String, dynamic> item;
  final String merchantId;
  final String merchantName;
  final bool hasRequiredOptions;
  final void Function(CartItem) onAddToCart;

  const _MenuItemCard({
    required this.item,
    required this.merchantId,
    required this.merchantName,
    this.hasRequiredOptions = false,
    required this.onAddToCart,
  });

  @override
  Widget build(BuildContext context) {
    final name = item['name'] ?? 'ไม่ระบุชื่อ';
    final description = item['description'] ?? '';
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final imageUrl = item['image_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: InkWell(
        onTap: () => _navigateToDetails(context),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      '฿${price.ceil()}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentOrange,
                      ),
                    ),
                    if (hasRequiredOptions) ...[                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Text(
                          'ต้องเลือกตัวเลือก',
                          style: TextStyle(fontSize: 10, color: Colors.orange.shade700, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Image only (tap card to view details)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 90,
                  height: 90,
                  color: Colors.grey[100],
                  child: imageUrl != null
                      ? AppNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          backgroundColor: Colors.grey[100],
                        )
                      : _placeholder(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder() {
    return const GrayscaleLogoPlaceholder(
      fit: BoxFit.contain,
      backgroundColor: Colors.white,
      padding: EdgeInsets.all(10),
    );
  }

  // ignore: unused_element
  void _quickAdd() {
    // ถ้ามี required options ต้องไปหน้ารายละเอียดเพื่อเลือกก่อน
    if (hasRequiredOptions) {
      // ใช้ Builder เพื่อเข้าถึง context ที่ถูกต้อง
      return;
    }
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    onAddToCart(CartItem(
      menuItemId: item['id'] as String,
      name: item['name'] ?? 'ไม่ระบุ',
      description: item['description'] as String?,
      imageUrl: item['image_url'] as String?,
      basePrice: price,
    ));
  }

  void _navigateToDetails(BuildContext context) async {
    final name = item['name'] ?? 'ไม่ระบุชื่อ';
    final description = item['description'] ?? '';
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final imageUrl = item['image_url'] as String?;

    final menuItem = MenuItem(
      id: item['id'] as String,
      name: name,
      description: description,
      price: price,
      category: item['category'] as String? ?? '',
      imageUrl: imageUrl,
      isAvailable: item['is_available'] as bool? ?? true,
      merchantId: item['merchant_id'] as String,
      createdAt: DateTime.parse(item['created_at'] as String),
      updatedAt: DateTime.parse(item['updated_at'] as String),
    );

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => FoodDetailsScreen(
          menuItem: menuItem,
          restaurantName: merchantName,
        ),
      ),
    );

    if (result != null && result is Map<String, dynamic>) {
      onAddToCart(CartItem(
        menuItemId: item['id'] as String,
        name: result['name'] ?? name,
        description: item['description'] as String?,
        imageUrl: item['image_url'] as String?,
        basePrice: (item['price'] as num?)?.toDouble() ?? 0.0,
        optionsPrice: ((result['price'] as double?) ?? price) - price,
        selectedOptions: (result['selected_options'] as List<String>?) ?? [],
        quantity: result['quantity'] as int? ?? 1,
      ));
    }
  }
}

// ============================================================
// Tab Bar Delegate for pinned tabs
// ============================================================
class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final TabBar tabBar;
  _TabBarDelegate(this.tabBar);

  @override
  double get minExtent => tabBar.preferredSize.height;
  @override
  double get maxExtent => tabBar.preferredSize.height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return Container(
      color: Colors.white,
      child: tabBar,
    );
  }

  @override
  bool shouldRebuild(covariant _TabBarDelegate oldDelegate) => false;
}
