import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../common/services/system_config_service.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../common/models/coupon.dart';
import '../../../../common/models/menu_item.dart';
import '../../../../common/services/coupon_service.dart';
import '../../../../common/services/customer_favorite_service.dart';
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
  final double? distanceKm;

  const RestaurantDetailScreen({
    super.key,
    required this.merchantId,
    required this.merchantName,
    this.distanceKm,
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
  double _minOrderAmount = 0;
  bool _isFavorite = false;
  final CouponService _couponService = CouponService();
  final CustomerFavoriteService _favoriteService =
      const CustomerFavoriteService();
  List<Coupon> _merchantCoupons = [];
  int? _estimatedDeliveryFee;

  TabController? _tabController;

  @override
  void initState() {
    super.initState();
    _fetchData();
    _loadFavoriteState();
    _loadPromoConfig();
    if (widget.distanceKm != null) _computeEstimatedFee(widget.distanceKm!);
  }

  Future<void> _computeEstimatedFee(double distanceKm) async {
    try {
      final fee = await SystemConfigService().calculateDeliveryFee(
        serviceType: 'food',
        distanceKm: distanceKm,
      );
      if (mounted) setState(() => _estimatedDeliveryFee = fee);
    } catch (_) {}
  }

  Future<void> _loadFavoriteState() async {
    try {
      final isFavorite = await _favoriteService.isFavorite(widget.merchantId);
      if (!mounted) return;
      setState(() => _isFavorite = isFavorite);
    } catch (e) {
      debugLog('⚠️ โหลดสถานะร้านโปรดไม่สำเร็จ: $e');
    }
  }

  Future<void> _toggleFavorite() async {
    final nextValue = !_isFavorite;
    setState(() => _isFavorite = nextValue);
    try {
      await _favoriteService.setFavorite(
        merchantId: widget.merchantId,
        favorite: nextValue,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isFavorite = !nextValue);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update favorite: $e')),
      );
    }
  }

  Future<void> _loadPromoConfig() async {
    try {
      final config = await SupabaseService.client
          .from('system_config')
          .select('promo_text, promo_enabled')
          .eq('id', 1)
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
            .select('shop_photo_url, shop_address, phone_number, min_order_amount')
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
      final rawMinOrder = profile?['min_order_amount'];
      _minOrderAmount = rawMinOrder is num
          ? rawMinOrder.toDouble()
          : (rawMinOrder is String ? double.tryParse(rawMinOrder) ?? 0 : 0);

      _menuItems = List<Map<String, dynamic>>.from(menuResponse);

      final coupons = await _couponService.getAvailableCoupons(
        serviceType: 'food',
        merchantId: widget.merchantId,
      );
      _merchantCoupons =
          coupons.where((c) => c.merchantId == widget.merchantId).toList();

      // Batch-fetch option links for all menu items in a single query
      _menuItemsWithRequiredOptions = {};
      try {
        final menuItemIds =
            _menuItems.map((item) => item['id'] as String).toList();
        if (menuItemIds.isNotEmpty) {
          final allLinks = await Supabase.instance.client
              .from('menu_item_option_links')
              .select('menu_item_id, menu_option_groups!inner(min_selection)')
              .inFilter('menu_item_id', menuItemIds);
          for (final link in allLinks) {
            final group = link['menu_option_groups'] as Map<String, dynamic>?;
            final minSel = (group?['min_selection'] as num?)?.toInt() ?? 0;
            if (minSel > 0) {
              final id = link['menu_item_id'] as String?;
              if (id != null) _menuItemsWithRequiredOptions.add(id);
            }
          }
        }
        debugLog(
            '📊 เมนูที่มีตัวเลือกบังคับ: ${_menuItemsWithRequiredOptions.length} รายการ');
      } catch (e) {
        debugLog('⚠️ โหลด option links ไม่ได้: $e');
      }

      // Group by category
      _menuByCategory = {};
      for (final item in _menuItems) {
        final cat = (item['category'] as String?) ??
            AppLocalizations.of(context)!.restCategoryOther;
        _menuByCategory.putIfAbsent(cat, () => []).add(item);
      }
      _categories = _menuByCategory.keys.toList();

      // Setup tab controller
      _tabController?.dispose();
      if (_categories.isNotEmpty) {
        _tabController = TabController(length: _categories.length, vsync: this);
      }

      debugLog(
          '📊 ร้าน ${widget.merchantName}: ${_menuItems.length} เมนู, ${_categories.length} หมวด');

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
    final jdc = JdcColors.of(context);
    return Scaffold(
      backgroundColor: jdc.paper,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: jdc.brand))
          : _error != null
              ? _buildErrorState()
              : _buildB1Content(),
      bottomNavigationBar: _buildB1CartBar(),
    );
  }

  Widget _buildB1Content() {
    return NestedScrollView(
      headerSliverBuilder: (context, _) {
        return [
          SliverToBoxAdapter(child: _buildB1HeroAndCard()),
          SliverToBoxAdapter(child: _buildB1CategoryTabs()),
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

  Widget _buildB1HeroAndCard() {
    final jdc = JdcColors.of(context);
    return SizedBox(
      height: 274,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Hero3 gradient header (168px)
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              height: 168,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
              decoration: BoxDecoration(
                gradient: jdc.hero3,
                // รูปหน้าร้านจริงเป็นพื้นหลังจาง ๆ ใต้เกรเดียนต์ (ของเดิมเป็นรูปปก)
                image: (_shopPhotoUrl ?? '').isNotEmpty
                    ? DecorationImage(
                        image: NetworkImage(_shopPhotoUrl!),
                        fit: BoxFit.cover,
                        opacity: 0.35,
                      )
                    : null,
              ),
              child: SafeArea(
                bottom: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Back button
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: jdc.panelSoft2,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: jdc.panelLine),
                            ),
                            child: Icon(Icons.chevron_left,
                                size: 20, color: jdc.onPanel),
                          ),
                        ),
                        const Spacer(),
                        // Favorite button
                        GestureDetector(
                          onTap: _toggleFavorite,
                          child: Container(
                            width: 44, height: 44,
                            decoration: BoxDecoration(
                              color: jdc.panelSoft2,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: jdc.panelLine),
                            ),
                            child: Icon(
                              _isFavorite
                                  ? Icons.favorite
                                  : Icons.favorite_border,
                              size: 20,
                              color: _isFavorite
                                  ? jdc.brand
                                  : jdc.onPanel,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Overlapping info card (-34px)
          Positioned(
            top: 134,
            left: 20, right: 20,
            child: _buildB1InfoCard(),
          ),
        ],
      ),
    );
  }

  Widget _buildB1InfoCard() {
    final jdc = JdcColors.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: jdc.line),
        boxShadow: jdc.shadowRaise,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.merchantName,
            style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w700, color: jdc.text),
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              if (widget.distanceKm != null) ...[
                Icon(Icons.storefront_outlined,
                    size: 13, color: jdc.muted),
                const SizedBox(width: 3),
                Text(
                  '${widget.distanceKm!.toStringAsFixed(1)} กม.',
                  style: TextStyle(fontSize: 12, color: jdc.muted),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                AppLocalizations.of(context)!.restDeliveryTime,
                style: TextStyle(fontSize: 12, color: jdc.muted),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              // Rating badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: jdc.brandSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star, size: 13, color: jdc.brandOnSoft),
                    const SizedBox(width: 4),
                    Text('4.8',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: jdc.brandOnSoft)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Delivery fee badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: jdc.successSoft,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _estimatedDeliveryFee != null
                      ? 'ค่าส่ง ฿$_estimatedDeliveryFee'
                      : AppLocalizations.of(context)!.restDeliveryFee,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: jdc.successInk,
                  ),
                ),
              ),
            ],
          ),
          // ข้อมูลติดต่อร้าน (ของเดิม artboard ไม่มี แต่เป็นข้อมูลที่ลูกค้าใช้จริง)
          if ((_shopAddress ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.place_outlined, size: 15, color: jdc.muted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    _shopAddress!,
                    style: TextStyle(fontSize: 12, color: jdc.muted),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
          if ((_phoneNumber ?? '').isNotEmpty) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: _callShop,
              child: Row(
                children: [
                  Icon(Icons.phone_outlined, size: 15, color: jdc.brand),
                  const SizedBox(width: 6),
                  Text(
                    _phoneNumber!,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: jdc.brand),
                  ),
                ],
              ),
            ),
          ],
          // คูปองของร้าน
          if (_merchantCoupons.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 30,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _merchantCoupons.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (_, i) => Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: jdc.brandSoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: jdc.brandLine),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.confirmation_num_outlined,
                          size: 13, color: jdc.brandOnSoft),
                      const SizedBox(width: 4),
                      Text(
                        _merchantCoupons[i].code,
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: jdc.brandOnSoft),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          // Promo tag
          if (_promoEnabled && _promoText != null && _promoText!.isNotEmpty)
            ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: jdc.dangerSoft,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: jdc.dangerLine),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.local_offer,
                      size: 13, color: jdc.dangerInk),
                  const SizedBox(width: 4),
                  Text(_promoText!,
                      style: TextStyle(
                          fontSize: 12,
                          color: jdc.dangerInk,
                          fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildB1CategoryTabs() {
    if (_categories.isEmpty) return const SizedBox.shrink();
    final jdc = JdcColors.of(context);
    return Container(
      color: jdc.paper,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _categories.asMap().entries.map((entry) {
            final i = entry.key;
            final cat = entry.value;
            final isActive = _tabController?.index == i;
            return Padding(
              padding: EdgeInsets.only(right: i < _categories.length - 1 ? 8 : 0),
              child: GestureDetector(
                onTap: () {
                  _tabController?.animateTo(i);
                  setState(() {});
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: isActive ? jdc.panel : jdc.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: isActive
                        ? null
                        : Border.all(color: jdc.line),
                  ),
                  child: Text(
                    cat,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: isActive ? jdc.onPanel : jdc.muted,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  /// โทรหาร้าน (ฟีเจอร์เดิมของหน้าร้าน)
  Future<void> _callShop() async {
    final phone = (_phoneNumber ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
    if (phone.isEmpty) return;
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
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
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.restaurant_menu,
              size: 64, color: colorScheme.outlineVariant),
          SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.restNoMenu,
            style: TextStyle(fontSize: 16, color: colorScheme.onSurfaceVariant),
          ),
          SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _fetchData,
            icon: Icon(Icons.refresh),
            label: Text(AppLocalizations.of(context)!.restRefresh),
            style: ElevatedButton.styleFrom(
              backgroundColor: JdcColors.of(context).brand,
              foregroundColor: JdcColors.of(context).surface,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.restCannotLoadMenu,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.restTryAgain,
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _fetchData,
              icon: Icon(Icons.refresh),
              label: Text(AppLocalizations.of(context)!.restRetry),
              style: ElevatedButton.styleFrom(
                backgroundColor: JdcColors.of(context).brand,
                foregroundColor: JdcColors.of(context).surface,
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
          title: Text(AppLocalizations.of(context)!.restSwitchRestaurant),
          content: Text(AppLocalizations.of(context)!
              .restSwitchRestaurantBody(cart.merchantName ?? '')),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(AppLocalizations.of(context)!.restCancel),
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
                backgroundColor: JdcColors.of(context).brand,
                foregroundColor: JdcColors.of(context).surface,
              ),
              child: Text(AppLocalizations.of(context)!.restClearAndAdd),
            ),
          ],
        ),
      );
    } else {
      _showAddedSnackBar(cartItem.name);
    }
  }

  void _showAddedSnackBar(String name) {
    final colorScheme = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.restAddedToCart(name)),
        backgroundColor: colorScheme.tertiary,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      ),
    );
  }

  Widget _buildB1CartBar() {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final jdc = JdcColors.of(context);
        if (cart.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          decoration: BoxDecoration(
            color: jdc.surface,
            border: Border(top: BorderSide(color: jdc.line)),
          ),
          child: SafeArea(
            top: false,
            child: GestureDetector(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => _buildCartSheet(),
                );
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 56),
                padding: const EdgeInsets.symmetric(
                    horizontal: 18, vertical: 0),
                decoration: BoxDecoration(
                  color: jdc.cta,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: jdc.shadowBrand,
                ),
                child: Row(
                  children: [
                    // Item count badge
                    Container(
                      constraints: const BoxConstraints(
                          minWidth: 26, minHeight: 26),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: jdc.panelSoft3,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '${cart.totalItems}',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: jdc.onPanel),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        AppLocalizations.of(context)!.restViewCart,
                        style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: jdc.onCta),
                      ),
                    ),
                    Text(
                      '฿${cart.subtotal.ceil()}',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: jdc.onCta),
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
        final colorScheme = Theme.of(context).colorScheme;
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.3,
          maxChildSize: 0.85,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle
                  Container(
                    margin: EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 16, 12, 8),
                    child: Row(
                      children: [
                        Icon(Icons.shopping_bag,
                            color: JdcColors.of(context).brand),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              AppLocalizations.of(context)!.restYourCart,
                              style: const TextStyle(
                                  fontSize: 18, fontWeight: FontWeight.bold)),
                        ),
                        TextButton(
                          onPressed: () {
                            cart.clearCart();
                            Navigator.of(context).pop();
                          },
                          child: Text(AppLocalizations.of(context)!.restClear,
                              style: TextStyle(color: colorScheme.error)),
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
                                color: colorScheme.surfaceContainerHighest,
                                child: item.imageUrl != null
                                    ? AppNetworkImage(
                                        imageUrl: item.imageUrl,
                                        fit: BoxFit.cover,
                                        backgroundColor:
                                            colorScheme.surfaceContainerHighest,
                                      )
                                    : const GrayscaleLogoPlaceholder(
                                        fit: BoxFit.contain),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item.name,
                                      style: TextStyle(
                                          fontWeight: FontWeight.w600)),
                                  if (item.selectedOptions.isNotEmpty)
                                    Text(item.selectedOptions.join(', '),
                                        style: TextStyle(
                                            fontSize: 12,
                                            color:
                                                colorScheme.onSurfaceVariant)),
                                  SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text('฿${item.totalPrice.ceil()}',
                                          style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              color: JdcColors.of(context).brand)),
                                      Spacer(),
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
                    padding: EdgeInsets.fromLTRB(20, 12, 20, 12),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainer,
                      boxShadow: [
                        BoxShadow(
                            color: JdcColors.of(context).text.withValues(alpha: 0.06),
                            blurRadius: 8,
                            offset: const Offset(0, -2))
                      ],
                    ),
                    child: SafeArea(
                      child: Builder(
                        builder: (context) {
                          final belowMin = _minOrderAmount > 0 &&
                              cart.subtotal < _minOrderAmount;
                          final shortfall =
                              (_minOrderAmount - cart.subtotal).ceil();
                          return Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(AppLocalizations.of(context)!.restTotal,
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 16)),
                                  Text('฿${cart.subtotal.ceil()}',
                                      style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                          color: JdcColors.of(context).brand)),
                                ],
                              ),
                              if (belowMin) ...[
                                const SizedBox(height: 10),
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 12, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: colorScheme.errorContainer
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          size: 18,
                                          color: colorScheme.error),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'สั่งขั้นต่ำ ฿${_minOrderAmount.ceil()} • เพิ่มอีก ฿$shortfall',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: colorScheme.error,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                              SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  onPressed: belowMin
                                      ? null
                                      : () {
                                          Navigator.of(context)
                                              .pop(); // close sheet
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (context) =>
                                                  FoodCheckoutScreen(),
                                            ),
                                          );
                                        },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: JdcColors.of(context).brand,
                                    foregroundColor: JdcColors.of(context).surface,
                                    disabledBackgroundColor:
                                        colorScheme.surfaceContainerHighest,
                                    disabledForegroundColor:
                                        colorScheme.onSurfaceVariant,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                        borderRadius:
                                            BorderRadius.circular(14)),
                                    elevation: 0,
                                  ),
                                  child: Text(
                                      belowMin
                                          ? 'สั่งขั้นต่ำ ฿${_minOrderAmount.ceil()}'
                                          : AppLocalizations.of(context)!
                                              .restGoToCheckout(cart.subtotal
                                                  .ceil()
                                                  .toString()),
                                      style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ),
                            ],
                          );
                        },
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
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            onTap: () => cart.updateQuantity(index, item.quantity - 1),
            child: Padding(
              padding: EdgeInsets.all(4),
              child: Icon(
                item.quantity > 1 ? Icons.remove : Icons.delete_outline,
                size: 18,
                color: item.quantity > 1
                    ? colorScheme.onSurfaceVariant
                    : JdcColors.of(context).danger,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text('${item.quantity}',
                style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          InkWell(
            onTap: () => cart.updateQuantity(index, item.quantity + 1),
            child: Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.add, size: 18, color: JdcColors.of(context).brand),
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
    final colorScheme = Theme.of(context).colorScheme;
    final name = item['name'] ?? AppLocalizations.of(context)!.restItemNoName;
    final description = item['description'] ?? '';
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final imageUrl = item['image_url'] as String?;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
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
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: colorScheme.onSurface,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      SizedBox(height: 4),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: 13,
                          color: colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    SizedBox(height: 8),
                    Text(
                      '฿${price.ceil()}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: JdcColors.of(context).brand,
                      ),
                    ),
                    if (hasRequiredOptions) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                              color: colorScheme.secondary
                                  .withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          AppLocalizations.of(context)!.restMustSelectOption,
                          style: TextStyle(
                            fontSize: 10,
                            color: colorScheme.onSecondaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
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
                  color: colorScheme.surfaceContainerHighest,
                  child: imageUrl != null
                      ? AppNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          backgroundColor: colorScheme.surfaceContainerHighest,
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
      padding: EdgeInsets.all(10),
    );
  }

  void _navigateToDetails(BuildContext context) async {
    final name = item['name'] ?? AppLocalizations.of(context)!.restItemNoName;
    final description = item['description'] ?? '';
    final price = (item['price'] as num?)?.toDouble() ?? 0.0;
    final prepTime = (item['prep_time_minutes'] as num?)?.toInt() ?? 15;
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
        prepTimeMinutes: prepTime,
        selectedOptions: (result['selected_options'] as List<String>?) ?? [],
        quantity: result['quantity'] as int? ?? 1,
      ));
    }
  }
}
