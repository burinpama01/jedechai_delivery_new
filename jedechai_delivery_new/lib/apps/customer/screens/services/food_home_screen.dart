import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import '../../../../theme/app_theme.dart';
import '../../providers/cart_provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../common/services/geocoding_service.dart';
import '../../../../common/services/notification_sender.dart';
import '../../../../common/services/supabase_service.dart';
import '../../../../common/services/merchant_food_config_service.dart';
import '../../../../common/services/system_config_service.dart';
import '../../../../common/widgets/app_network_image.dart';
import '../../../../common/widgets/location_disclosure_dialog.dart';
import '../../../../l10n/app_localizations.dart';
import 'restaurant_detail_screen.dart';
import 'food_checkout_screen.dart';

/// Food Home Screen — หน้าหลักสั่งอาหาร (แบบ GrabFood / LINE MAN)
class FoodHomeScreen extends StatefulWidget {
  const FoodHomeScreen({super.key});

  @override
  State<FoodHomeScreen> createState() => _FoodHomeScreenState();
}

class _FoodHomeScreenState extends State<FoodHomeScreen> {
  List<Map<String, dynamic>> _restaurants = [];
  List<Map<String, dynamic>> _filteredRestaurants = [];
  bool _isLoading = true;
  String? _error;
  String _searchQuery = '';
  String _selectedCategory = 'all';
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _foodBanners = [];
  int _currentBannerIndex = 0;
  final PageController _bannerController = PageController();
  Timer? _bannerTimer;
  List<Map<String, dynamic>> _topSellingItems = [];
  bool _isLoadingTopSelling = true;
  Position? _currentPosition;
  double _restaurantRadiusKm = 30.0;
  bool _isOutOfRestaurantCoverage = false;

  List<_FoodCategory> _getCategories(AppLocalizations l10n) => [
    _FoodCategory('all', l10n.foodCategoryAll, Icons.apps, const Color(0xFFFF6B35)),
    _FoodCategory('อาหารตามสั่ง', l10n.foodCategoryMadeToOrder, Icons.restaurant, const Color(0xFFEF4444)),
    _FoodCategory('ก๋วยเตี๋ยว', l10n.foodCategoryNoodles, Icons.ramen_dining, const Color(0xFFF59E0B)),
    _FoodCategory('เครื่องดื่ม', l10n.foodCategoryDrinks, Icons.local_cafe, const Color(0xFF8B5CF6)),
    _FoodCategory('ของหวาน', l10n.foodCategoryDesserts, Icons.cake, const Color(0xFFEC4899)),
    _FoodCategory('ฟาสต์ฟู้ด', l10n.foodCategoryFastFood, Icons.fastfood, const Color(0xFF10B981)),
  ];

  @override
  void initState() {
    super.initState();
    _initializeContextAndLoadRestaurants();
    _loadFoodBanners();
    _fetchTopSellingItems();
  }

  Future<void> _initializeContextAndLoadRestaurants() async {
    await _loadRestaurantRadius();
    await _resolveCurrentLocation();
    await _fetchRestaurants();
  }

  Future<void> _loadRestaurantRadius() async {
    try {
      final configService = SystemConfigService();
      await configService.fetchSettings();
      _restaurantRadiusKm = configService.customerToMerchantRadiusKm;
      debugLog(
          '🍽️ Restaurant radius = ${_restaurantRadiusKm.toStringAsFixed(1)} km');
    } catch (e) {
      _restaurantRadiusKm = 30.0;
      debugLog(
          '⚠️ ใช้รัศมีร้านอาหารเริ่มต้น 30 กม. เนื่องจากโหลด config ไม่สำเร็จ: $e');
    }
  }

  Future<void> _resolveCurrentLocation() async {
    try {
      final locationEnabled = await Geolocator.isLocationServiceEnabled();
      if (!locationEnabled) return;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          final accepted = await LocationDisclosureHelper.showIfNeeded(context);
          if (!accepted) return;
        }
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _currentPosition = position;
    } catch (e) {
      debugLog('⚠️ ไม่สามารถดึงตำแหน่งปัจจุบันสำหรับคัดกรองร้านอาหารได้: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _bannerTimer?.cancel();
    _bannerController.dispose();
    super.dispose();
  }

  Future<void> _loadFoodBanners() async {
    try {
      final response = await SupabaseService.client
          .from('banners')
          .select('*')
          .eq('is_active', true)
          .eq('page', 'food')
          .order('sort_order');
      if (mounted) {
        setState(() {
          _foodBanners = List<Map<String, dynamic>>.from(response);
        });
        _bannerTimer?.cancel();
        if (_foodBanners.length > 1) {
          _bannerTimer = Timer.periodic(const Duration(seconds: 5), (_) {
            if (!mounted || _foodBanners.isEmpty) return;
            final next = (_currentBannerIndex + 1) % _foodBanners.length;
            _bannerController.animateToPage(next,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeInOut);
          });
        }
      }
    } catch (e) {
      debugLog('⚠️ Error loading food banners: $e');
    }
  }

  Future<void> _fetchTopSellingItems() async {
    try {
      // ดึง booking_items ทั้งหมดจาก completed bookings
      final bookingItemsResponse = await Supabase.instance.client
          .from('booking_items')
          .select('menu_item_id, quantity, bookings!inner(status)')
          .eq('bookings.status', 'completed');

      // Aggregate ยอดขายต่อ menu_item_id
      final Map<String, int> salesMap = {};
      for (final bi in bookingItemsResponse) {
        final menuItemId = bi['menu_item_id'] as String?;
        if (menuItemId == null) continue;
        final qty = (bi['quantity'] as num?)?.toInt() ?? 1;
        salesMap[menuItemId] = (salesMap[menuItemId] ?? 0) + qty;
      }

      if (salesMap.isEmpty) {
        if (mounted) setState(() => _isLoadingTopSelling = false);
        return;
      }

      // เรียงตามยอดขายจากมากไปน้อย แล้วเอา top 5
      final sortedIds = salesMap.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));
      final topIds = sortedIds.take(5).map((e) => e.key).toList();

      // ดึงข้อมูล menu_items ที่เป็น top selling
      final menuResponse = await Supabase.instance.client
          .from('menu_items')
          .select(
              'id, name, price, image_url, category, merchant_id, is_available')
          .inFilter('id', topIds)
          .eq('is_available', true);

      // ดึงข้อมูล merchant (ชื่อร้าน + รูป + สถานะ)
      final merchantIds =
          menuResponse.map((m) => m['merchant_id'] as String).toSet().toList();
      final merchantResponse = await Supabase.instance.client
          .from('profiles')
          .select('id, full_name, shop_photo_url, shop_status')
          .inFilter('id', merchantIds);
      final merchantMap = {
        for (final m in merchantResponse) m['id'] as String: m
      };

      // รวมข้อมูลแล้วเรียง top
      final List<Map<String, dynamic>> topItems = [];
      for (final id in topIds) {
        final item = menuResponse.firstWhere(
          (m) => m['id'] == id,
          orElse: () => <String, dynamic>{},
        );
        if (item.isEmpty) continue;
        final merchant = merchantMap[item['merchant_id']];
        if (merchant == null) continue;
        // ข้ามร้านที่ปิดอยู่
        if (merchant['shop_status'] != true) continue;
        topItems.add({
          ...item,
          'sales_count': salesMap[id] ?? 0,
          'merchant_name': merchant['full_name'] ?? '',
          'shop_photo_url': merchant['shop_photo_url'],
        });
      }

      if (mounted) {
        setState(() {
          _topSellingItems = topItems;
          _isLoadingTopSelling = false;
        });
      }
      debugLog('🔥 Top selling items loaded: ${topItems.length}');
    } catch (e) {
      debugLog('⚠️ Error loading top selling items: $e');
      if (mounted) setState(() => _isLoadingTopSelling = false);
    }
  }

  // Map of merchantId → Set of categories from their menu items
  Map<String, Set<String>> _restaurantCategories = {};

  Future<void> _fetchRestaurants() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      bool _isShopOpenNow(Map<String, dynamic> merchant) {
        final autoEnabled = merchant['shop_auto_schedule_enabled'] == true;
        final rawStatus = merchant['shop_status'];
        final bool statusOpen = rawStatus == true || rawStatus == 1 || rawStatus == 'true';

        if (!autoEnabled) {
          return statusOpen;
        }

        final openStr = (merchant['shop_open_time'] as String?)?.trim();
        final closeStr = (merchant['shop_close_time'] as String?)?.trim();
        if (openStr == null || closeStr == null) {
          return statusOpen;
        }

        final openParts = openStr.split(':');
        final closeParts = closeStr.split(':');
        if (openParts.length < 2 || closeParts.length < 2) {
          return statusOpen;
        }

        final openHour = int.tryParse(openParts[0]);
        final openMinute = int.tryParse(openParts[1]);
        final closeHour = int.tryParse(closeParts[0]);
        final closeMinute = int.tryParse(closeParts[1]);
        if (openHour == null || openMinute == null || closeHour == null || closeMinute == null) {
          return statusOpen;
        }

        final now = TimeOfDay.now();
        final nowMinutes = now.hour * 60 + now.minute;
        final openMinutes = openHour * 60 + openMinute;
        final closeMinutes = closeHour * 60 + closeMinute;

        bool withinHours;
        if (openMinutes <= closeMinutes) {
          withinHours = nowMinutes >= openMinutes && nowMinutes < closeMinutes;
        } else {
          withinHours = nowMinutes >= openMinutes || nowMinutes < closeMinutes;
        }

        final rawDays = merchant['shop_open_days'];
        if (rawDays is List && rawDays.isNotEmpty) {
          const weekdayKeys = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];
          final todayKey = weekdayKeys[DateTime.now().weekday - 1];
          final allowedDays = rawDays
              .map((e) => e.toString().toLowerCase().trim())
              .where((e) => weekdayKeys.contains(e))
              .toSet();
          if (allowedDays.isNotEmpty && !allowedDays.contains(todayKey)) {
            return false;
          }
        }

        return withinHours;
      }

      final response = await Supabase.instance.client
          .from('profiles')
          .select(
              'id, full_name, phone_number, shop_status, shop_address, shop_photo_url, latitude, longitude, shop_open_time, shop_close_time, shop_open_days, shop_auto_schedule_enabled')
          .eq('role', 'merchant')
          .eq('approval_status', 'approved')
          .order('full_name');

      debugLog('📊 พบ ${response.length} ร้านอาหาร');

      // Fetch menu categories for each restaurant
      final merchantIds = response.map((r) => r['id'] as String).toList();
      if (merchantIds.isNotEmpty) {
        try {
          final menuItems = await Supabase.instance.client
              .from('menu_items')
              .select('merchant_id, category')
              .inFilter('merchant_id', merchantIds)
              .eq('is_available', true);

          _restaurantCategories = {};
          for (final item in menuItems) {
            final mid = item['merchant_id'] as String;
            final cat = item['category'] as String? ?? 'อื่นๆ';
            _restaurantCategories.putIfAbsent(mid, () => {}).add(cat);
          }
          debugLog(
              '🍽️ โหลดหมวดหมู่เมนู: ${_restaurantCategories.length} ร้าน');
        } catch (e) {
          debugLog('⚠️ โหลดหมวดหมู่ไม่ได้: $e');
        }
      }

      final allRestaurants = List<Map<String, dynamic>>.from(response)
          .where(_isShopOpenNow)
          .toList();
      final filteredByRadius = <Map<String, dynamic>>[];

      for (final restaurant in allRestaurants) {
        if (_currentPosition == null) {
          filteredByRadius.add(restaurant);
          continue;
        }

        final lat = (restaurant['latitude'] as num?)?.toDouble();
        final lng = (restaurant['longitude'] as num?)?.toDouble();
        if (lat == null || lng == null) continue;

        final distanceKm = Geolocator.distanceBetween(
              _currentPosition!.latitude,
              _currentPosition!.longitude,
              lat,
              lng,
            ) /
            1000;

        if (distanceKm <= _restaurantRadiusKm) {
          filteredByRadius.add({...restaurant, 'distance_km': distanceKm});
        }
      }

      setState(() {
        _restaurants = filteredByRadius;
        _isOutOfRestaurantCoverage = _searchQuery.isEmpty &&
            allRestaurants.isNotEmpty &&
            filteredByRadius.isEmpty;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      debugLog('❌ โหลดร้านอาหารล้มเหลว: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    _filteredRestaurants = _restaurants.where((r) {
      final name = (r['full_name'] ?? '').toString().toLowerCase();
      final matchSearch =
          _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());

      // Category filter
      bool matchCategory = true;
      if (_selectedCategory != 'all') {
        final merchantId = r['id'] as String;
        final cats = _restaurantCategories[merchantId] ?? {};
        matchCategory = cats.any((c) =>
            c.contains(_selectedCategory) || _selectedCategory.contains(c));
      }

      return matchSearch && matchCategory;
    }).toList();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
      _applyFilters();
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final categories = _getCategories(l10n);
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            await Future.wait([_fetchRestaurants(), _fetchTopSellingItems()]);
          },
          color: AppTheme.accentOrange,
          child: CustomScrollView(
            slivers: [
              // Header + Search
              _buildHeader(),
              // Categories
              SliverPersistentHeader(
                pinned: true,
                delegate: _FixedHeightSliverHeaderDelegate(
                  height: 122,
                  child: _buildCategories(categories),
                ),
              ),
              // Promo Banner
              SliverToBoxAdapter(child: _buildPromoBanner()),
              // Top Selling Items
              SliverToBoxAdapter(child: _buildTopSellingSection()),
              // Section Title
              SliverToBoxAdapter(child: _buildSectionTitle()),
              // Restaurant List or States
              _buildRestaurantList(),
              // Bottom padding for cart bar
              SliverToBoxAdapter(child: SizedBox(height: 80)),
            ],
          ),
        ),
      ),
      // Floating Cart Bar
      bottomNavigationBar: _buildCartBar(),
    );
  }

  Widget _buildHeader() {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    return SliverAppBar(
      pinned: true,
      floating: false,
      snap: false,
      elevation: 0,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      toolbarHeight: 140,
      collapsedHeight: 140,
      expandedHeight: 140,
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.pin,
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.accentOrange,
                AppTheme.accentOrange.withValues(alpha: 0.75),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Column(
            children: [
              // Top bar with back button and title
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 8, 16, 0),
                child: Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.arrow_back, color: colorScheme.onPrimary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        l10n.foodHomeTitle,
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // Cart icon with badge
                    Consumer<CartProvider>(
                      builder: (context, cart, _) {
                        return Stack(
                          children: [
                            IconButton(
                              icon: Icon(
                                Icons.shopping_bag_outlined,
                                color: colorScheme.onPrimary,
                                size: 28,
                              ),
                              onPressed: () => _showCartSheet(),
                            ),
                            if (cart.totalItems > 0)
                              Positioned(
                                right: 4,
                                top: 4,
                                child: Container(
                                  padding: const EdgeInsets.all(4),
                                  decoration: BoxDecoration(
                                    color: colorScheme.error,
                                    shape: BoxShape.circle,
                                  ),
                                  constraints: const BoxConstraints(
                                      minWidth: 20, minHeight: 20),
                                  child: Text(
                                    '${cart.totalItems}',
                                    style: TextStyle(
                                        color: colorScheme.onError,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: _onSearchChanged,
                    decoration: InputDecoration(
                      hintText: l10n.foodHomeSearchHint,
                      hintStyle: TextStyle(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 15,
                      ),
                      prefixIcon:
                          Icon(Icons.search, color: colorScheme.onSurfaceVariant),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategories(List<_FoodCategory> categories) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surfaceContainer,
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: SizedBox(
        height: 90,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: categories.length,
          itemBuilder: (context, index) {
            final cat = categories[index];
            final isSelected = _selectedCategory == cat.key;
            return GestureDetector(
              onTap: () => _onCategorySelected(cat.key),
              child: Container(
                width: 72,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? cat.color.withValues(alpha: 0.15)
                            : colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(16),
                        border: isSelected
                            ? Border.all(color: cat.color, width: 2)
                            : null,
                      ),
                      child: Icon(
                        cat.icon,
                        color:
                            isSelected ? cat.color : colorScheme.onSurfaceVariant,
                        size: 28,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      cat.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w500,
                        color: isSelected
                            ? cat.color
                            : colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildPromoBanner() {
    if (_foodBanners.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          SizedBox(
            height: 120,
            child: PageView.builder(
              controller: _bannerController,
              itemCount: _foodBanners.length,
              onPageChanged: (i) => setState(() => _currentBannerIndex = i),
              itemBuilder: (_, i) {
                final b = _foodBanners[i];
                final imageUrl = b['image_url'] as String?;
                final couponCode = b['coupon_code'] as String?;
                return GestureDetector(
                  onTap: couponCode != null && couponCode.isNotEmpty
                      ? () => _showBannerPromoCode(
                          couponCode, b['title'] as String?)
                      : null,
                  child: Container(
                    margin: const EdgeInsets.only(right: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: imageUrl == null
                          ? LinearGradient(
                              colors: [
                                AppTheme.accentOrange,
                                AppTheme.accentOrange.withValues(alpha: 0.72),
                              ],
                            )
                          : null,
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: imageUrl != null
                        ? AppNetworkImage(
                            imageUrl: imageUrl,
                            fit: BoxFit.cover,
                            width: double.infinity,
                            height: 120,
                            backgroundColor: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                          )
                        : const GrayscaleLogoPlaceholder(
                            width: double.infinity,
                            height: 120,
                            fit: BoxFit.contain,
                            backgroundColor: AppTheme.backgroundWhite,
                          ),
                  ),
                );
              },
            ),
          ),
          if (_foodBanners.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _foodBanners.length,
                  (i) => AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    width: i == _currentBannerIndex ? 16 : 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: i == _currentBannerIndex
                          ? AppTheme.accentOrange
                          : Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTopSellingSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    if (_isLoadingTopSelling) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.accentOrange),
          ),
        ),
      );
    }
    if (_topSellingItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
          child: Row(
            children: [
              Icon(Icons.local_fire_department,
                  color: colorScheme.error, size: 22),
              const SizedBox(width: 6),
              Text(
                l10n.foodHomeTopSelling,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                l10n.foodHomeTopCount(_topSellingItems.length.toString()),
                style: TextStyle(
                    fontSize: 13,
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: _topSellingItems.length,
            itemBuilder: (context, index) {
              final item = _topSellingItems[index];
              final name = item['name'] as String? ?? '';
              final price = (item['price'] as num?)?.toDouble() ?? 0;
              final imageUrl = item['image_url'] as String?;
              final merchantName = item['merchant_name'] as String? ?? '';
              final salesCount = item['sales_count'] as int? ?? 0;
              final merchantId = item['merchant_id'] as String? ?? '';

              return GestureDetector(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => RestaurantDetailScreen(
                        merchantId: merchantId,
                        merchantName: merchantName,
                      ),
                    ),
                  );
                },
                child: Container(
                  width: 150,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // รูปสินค้า
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(14)),
                        child: Container(
                          height: 100,
                          width: double.infinity,
                          color: colorScheme.surfaceContainerHighest,
                          child: Stack(
                            children: [
                              if (imageUrl != null && imageUrl.isNotEmpty)
                                AppNetworkImage(
                                  imageUrl: imageUrl,
                                  fit: BoxFit.cover,
                                  width: double.infinity,
                                  height: 100,
                                  backgroundColor: colorScheme.surfaceContainerHighest,
                                )
                              else
                                const GrayscaleLogoPlaceholder(
                                    fit: BoxFit.contain),
                              // Badge อันดับ
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [
                                      AppTheme.accentOrange,
                                      AppTheme.accentOrange.withValues(alpha: 0.75)
                                    ]),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '#${index + 1}',
                                    style: TextStyle(
                                        color: colorScheme.onPrimary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold),
                                  ),
                                ),
                              ),
                              // Badge ยอดขาย
                              Positioned(
                                top: 6,
                                right: 6,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: colorScheme.scrim.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.shopping_bag,
                                          size: 10, color: colorScheme.onPrimary),
                                      const SizedBox(width: 2),
                                      Text(
                                        l10n.foodHomeSoldCount(salesCount.toString()),
                                        style: TextStyle(
                                            color: colorScheme.onPrimary,
                                            fontSize: 9,
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      // ข้อมูลสินค้า
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 8, 8, 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              merchantName,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '฿${price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showBannerPromoCode(String code, String? title) {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.confirmation_number,
                color: AppTheme.accentOrange, size: 28),
            const SizedBox(width: 8),
            Expanded(
                child: Text(AppLocalizations.of(context)!.foodPromoCodeTitle,
                    style:
                        const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null && title.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(title,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    )),
              ),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: AppTheme.accentOrange.withValues(alpha: 0.3)),
              ),
              child: Text(
                code,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.accentOrange,
                  letterSpacing: 2,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(AppLocalizations.of(context)!.foodPromoCodeHint,
                style: TextStyle(
                  fontSize: 12,
                  color: colorScheme.onSurfaceVariant,
                )),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppLocalizations.of(context)!.foodPromoCodeClose),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(AppLocalizations.of(context)!.foodPromoCodeCopied(code)),
                  backgroundColor: AppTheme.accentOrange,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: Text(AppLocalizations.of(context)!.foodPromoCodeCopy),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentOrange,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        children: [
          Text(
            AppLocalizations.of(context)!.foodHomeNearbyTitle,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const Spacer(),
          if (!_isLoading)
            Text(
              AppLocalizations.of(context)!.foodHomeRestaurantCount(_filteredRestaurants.length.toString()),
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRestaurantList() {
    final colorScheme = Theme.of(context).colorScheme;
    if (_isLoading) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                const CircularProgressIndicator(color: AppTheme.accentOrange),
                const SizedBox(height: 16),
                Text(AppLocalizations.of(context)!.foodHomeLoading,
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      );
    }

    if (_error != null) {
      return SliverToBoxAdapter(
        child: _buildErrorState(),
      );
    }

    if (_filteredRestaurants.isEmpty) {
      return SliverToBoxAdapter(
        child: _buildEmptyState(),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return _RestaurantCard(
              restaurant: _filteredRestaurants[index],
              onTap: () => _navigateToRestaurant(_filteredRestaurants[index]),
            );
          },
          childCount: _filteredRestaurants.length,
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.errorContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.wifi_off_rounded,
              size: 48,
              color: colorScheme.error,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.foodHomeErrorTitle,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.foodHomeErrorSubtitle,
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _fetchRestaurants,
            icon: const Icon(Icons.refresh),
            label: Text(AppLocalizations.of(context)!.foodHomeRetry),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentOrange,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.restaurant_outlined,
              size: 48,
              color: colorScheme.tertiary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? AppLocalizations.of(context)!.foodHomeEmptySearch
                : (_isOutOfRestaurantCoverage
                    ? AppLocalizations.of(context)!.foodHomeEmptyNoArea
                    : AppLocalizations.of(context)!.foodHomeEmptyNoneOpen),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty
                ? AppLocalizations.of(context)!.foodHomeEmptySearchHint
                : (_isOutOfRestaurantCoverage
                    ? AppLocalizations.of(context)!.foodHomeEmptyNoAreaHint(_restaurantRadiusKm.toStringAsFixed(0))
                    : AppLocalizations.of(context)!.foodHomeEmptyTryLater),
            style: TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCartBar() {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final colorScheme = Theme.of(context).colorScheme;
        if (cart.isEmpty) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainer,
            boxShadow: [
              BoxShadow(
                color: colorScheme.shadow.withValues(alpha: 0.12),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: GestureDetector(
              onTap: () => _showCartSheet(),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: colorScheme.onPrimary.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        '${cart.totalItems}',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${AppLocalizations.of(context)!.foodCartViewCart} — ${cart.merchantName ?? ""}',
                        style: TextStyle(
                          color: colorScheme.onPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Text(
                      '฿${cart.subtotal.ceil()}',
                      style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
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

  void _navigateToRestaurant(Map<String, dynamic> restaurant) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RestaurantDetailScreen(
          merchantId: restaurant['id'],
          merchantName: restaurant['full_name'] ?? AppLocalizations.of(context)!.foodHomeRestaurantDefault,
        ),
      ),
    );
  }

  void _showCartSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const _CartBottomSheet(),
    );
  }
}

class _FixedHeightSliverHeaderDelegate extends SliverPersistentHeaderDelegate {
  final double height;
  final Widget child;

  _FixedHeightSliverHeaderDelegate({
    required this.height,
    required this.child,
  });

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return child;
  }

  @override
  bool shouldRebuild(covariant _FixedHeightSliverHeaderDelegate oldDelegate) {
    return oldDelegate.height != height || oldDelegate.child != child;
  }
}

// ============================================================
// Restaurant Card Widget
// ============================================================
class _RestaurantCard extends StatelessWidget {
  final Map<String, dynamic> restaurant;
  final VoidCallback onTap;

  const _RestaurantCard({required this.restaurant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final name = restaurant['full_name'] ?? l10n.foodHomeRestaurantDefault;
    // final phone = restaurant['phone_number'] ?? '';
    final address = restaurant['shop_address'] ?? '';
    final photoUrl = restaurant['shop_photo_url'] as String?;
    final distanceKm = (restaurant['distance_km'] as num?)?.toDouble();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Restaurant Image
            ClipRRect(
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(16)),
              child: Container(
                height: 140,
                width: double.infinity,
                color: colorScheme.surfaceContainerHighest,
                child: photoUrl != null && photoUrl.isNotEmpty
                    ? AppNetworkImage(
                        imageUrl: photoUrl,
                        fit: BoxFit.cover,
                        backgroundColor: colorScheme.surfaceContainerHighest,
                      )
                    : _buildPlaceholderImage(),
              ),
            ),
            // Restaurant Info
            Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: colorScheme.secondary,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Text(
                              l10n.foodHomeOpenBadge,
                              style: TextStyle(
                                fontSize: 12,
                                color: colorScheme.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Rating + Distance row
                  Row(
                    children: [
                      Icon(Icons.star, size: 16, color: colorScheme.tertiary),
                      const SizedBox(width: 2),
                      Text(
                        '4.5',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: colorScheme.onSurface),
                      ),
                      const SizedBox(width: 4),
                      Text('(100+)',
                          style:
                              TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                      const SizedBox(width: 12),
                      if (distanceKm != null) ...[
                        Icon(Icons.near_me, size: 14, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Text(l10n.foodHomeDistanceKm(distanceKm.toStringAsFixed(1)),
                            style: TextStyle(
                                fontSize: 12, color: colorScheme.onSurfaceVariant)),
                      ] else ...[
                        Icon(Icons.access_time,
                            size: 14, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Text(l10n.foodHomeEstTime,
                            style: TextStyle(
                                fontSize: 12, color: colorScheme.onSurfaceVariant)),
                      ],
                      const SizedBox(width: 12),
                      Icon(Icons.delivery_dining,
                          size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 2),
                      Text('฿15',
                          style:
                              TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                    ],
                  ),
                  if (address.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on_outlined,
                            size: 14, color: colorScheme.onSurfaceVariant),
                        const SizedBox(width: 2),
                        Expanded(
                          child: Text(
                            address,
                            style: TextStyle(
                                fontSize: 12, color: colorScheme.onSurfaceVariant),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage() {
    return const GrayscaleLogoPlaceholder(
      fit: BoxFit.contain,
      backgroundColor: AppTheme.backgroundLight,
    );
  }
}

// ============================================================
// Cart Bottom Sheet
// ============================================================
class _CartBottomSheet extends StatelessWidget {
  const _CartBottomSheet();

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final colorScheme = Theme.of(context).colorScheme;
        return DraggableScrollableSheet(
          initialChildSize: 0.65,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return Container(
              decoration: BoxDecoration(
                color: colorScheme.surface,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  // Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        const Icon(Icons.shopping_bag,
                            color: AppTheme.accentOrange, size: 24),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppLocalizations.of(context)!.foodCartTitle,
                                style: const TextStyle(
                                    fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              if (cart.merchantName != null)
                                Text(
                                  cart.merchantName!,
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: colorScheme.onSurfaceVariant),
                                ),
                            ],
                          ),
                        ),
                        if (cart.isNotEmpty)
                          TextButton(
                            onPressed: () {
                              cart.clearCart();
                              Navigator.of(context).pop();
                            },
                            child: Text(AppLocalizations.of(context)!.foodCartClear,
                                style: TextStyle(color: colorScheme.error)),
                          ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  // Cart Items
                  Expanded(
                    child: cart.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.shopping_bag_outlined,
                                    size: 64,
                                    color: colorScheme.outlineVariant),
                                const SizedBox(height: 12),
                                Text(AppLocalizations.of(context)!.foodCartEmpty,
                                    style: TextStyle(
                                        fontSize: 16,
                                        color: colorScheme.onSurfaceVariant)),
                              ],
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.all(16),
                            itemCount: cart.items.length,
                            separatorBuilder: (_, __) =>
                                const Divider(height: 24),
                            itemBuilder: (context, index) {
                              final item = cart.items[index];
                              return _CartItemRow(
                                item: item,
                                onIncrease: () => cart.updateQuantity(
                                    index, item.quantity + 1),
                                onDecrease: () => cart.updateQuantity(
                                    index, item.quantity - 1),
                                onRemove: () => cart.removeItem(index),
                              );
                            },
                          ),
                  ),
                  // Bottom Summary
                  if (cart.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
                      decoration: BoxDecoration(
                        color: colorScheme.surface,
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.shadow.withValues(alpha: 0.12),
                            blurRadius: 8,
                            offset: const Offset(0, -2),
                          ),
                        ],
                      ),
                      child: SafeArea(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(AppLocalizations.of(context)!.foodCartFoodCost,
                                    style: TextStyle(
                                        color: colorScheme.onSurfaceVariant)),
                                Text('฿${cart.subtotal.ceil()}'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(AppLocalizations.of(context)!.foodCartDeliveryFee,
                                    style: TextStyle(
                                        color: colorScheme.onSurfaceVariant)),
                                Text(
                                  cart.deliveryFee > 0
                                      ? '฿${cart.deliveryFee.ceil()}'
                                      : AppLocalizations.of(context)!.foodCartDeliveryCalcLater,
                                  style: TextStyle(
                                    color: cart.deliveryFee > 0
                                        ? null
                                        : colorScheme.onSurfaceVariant,
                                    fontStyle: cart.deliveryFee > 0
                                        ? null
                                        : FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(AppLocalizations.of(context)!.foodCartTotal,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                Text(
                                  '฿${cart.subtotal.ceil()}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: AppTheme.accentOrange,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  // Navigate to checkout
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const FoodCheckoutScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppTheme.accentOrange,
                                  foregroundColor: colorScheme.onPrimary,
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14)),
                                  elevation: 0,
                                ),
                                child: Text(
                                  '${AppLocalizations.of(context)!.foodCartOrderButton} — ฿${cart.subtotal.ceil()}',
                                  style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold),
                                ),
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
}

// ============================================================
// Cart Item Row
// ============================================================
class _CartItemRow extends StatelessWidget {
  final CartItem item;
  final VoidCallback onIncrease;
  final VoidCallback onDecrease;
  final VoidCallback onRemove;

  const _CartItemRow({
    required this.item,
    required this.onIncrease,
    required this.onDecrease,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Image
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            width: 60,
            height: 60,
            color: colorScheme.surfaceContainerHighest,
            child: item.imageUrl != null
                ? AppNetworkImage(
                    imageUrl: item.imageUrl,
                    fit: BoxFit.cover,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                  )
                : _placeholder(),
          ),
        ),
        const SizedBox(width: 12),
        // Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(item.name,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600, fontSize: 15)),
              if (item.selectedOptions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    item.selectedOptions.join(', '),
                    style: TextStyle(
                        fontSize: 12, color: colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '฿${item.totalPrice.ceil()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppTheme.accentOrange,
                      fontSize: 15,
                    ),
                  ),
                  const Spacer(),
                  // Quantity controls
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: colorScheme.outlineVariant),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        InkWell(
                          onTap: item.quantity > 1 ? onDecrease : onRemove,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(
                              item.quantity > 1
                                  ? Icons.remove
                                  : Icons.delete_outline,
                              size: 18,
                              color: item.quantity > 1
                                  ? colorScheme.onSurface
                                  : colorScheme.error,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '${item.quantity}',
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        InkWell(
                          onTap: onIncrease,
                          child: Padding(
                            padding: const EdgeInsets.all(6),
                            child: Icon(Icons.add,
                                size: 18, color: AppTheme.accentOrange),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _placeholder() {
    return const GrayscaleLogoPlaceholder(
      fit: BoxFit.contain,
      backgroundColor: AppTheme.backgroundLight,
      padding: EdgeInsets.all(8),
    );
  }
}

// ============================================================
// Food Category Model
// ============================================================
class _FoodCategory {
  final String key;
  final String label;
  final IconData icon;
  final Color color;
  const _FoodCategory(this.key, this.label, this.icon, this.color);
}

// ============================================================
// Food Checkout Screen (placeholder — จะถูกย้ายไปไฟล์แยกถ้าต้องการ)
// ============================================================
class _FoodCheckoutScreen extends StatefulWidget {
  const _FoodCheckoutScreen();

  @override
  State<_FoodCheckoutScreen> createState() => _FoodCheckoutScreenState();
}

class _FoodCheckoutScreenState extends State<_FoodCheckoutScreen> {
  bool _isPlacingOrder = false;
  String _paymentMethod = 'cash';
  final TextEditingController _noteController = TextEditingController();
  static const double _fallbackLat = 13.7563;
  static const double _fallbackLng = 100.5018;

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final colorScheme = Theme.of(context).colorScheme;
        return Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)!.foodCheckoutTitle),
            backgroundColor: AppTheme.accentOrange,
            foregroundColor: colorScheme.onPrimary,
            elevation: 0,
          ),
          body: cart.isEmpty
              ? Center(child: Text(AppLocalizations.of(context)!.foodCartEmpty))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Restaurant info
                      _buildSection(
                        icon: Icons.store,
                        title: AppLocalizations.of(context)!.foodCheckoutRestaurant,
                        child: Text(cart.merchantName ?? '',
                            style: const TextStyle(fontSize: 15)),
                      ),
                      // Delivery address
                      _buildSection(
                        icon: Icons.location_on,
                        title: AppLocalizations.of(context)!.foodCheckoutDeliveryAddress,
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                AppLocalizations.of(context)!.foodCheckoutCurrentLocation,
                                style: TextStyle(
                                    fontSize: 15,
                                    color: colorScheme.onSurface),
                              ),
                            ),
                            Icon(Icons.my_location,
                                size: 20, color: AppTheme.accentOrange),
                          ],
                        ),
                      ),
                      // Order items
                      _buildSection(
                        icon: Icons.receipt_long,
                        title: AppLocalizations.of(context)!.foodCheckoutItemsTitle(cart.totalItems.toString()),
                        child: Column(
                          children: cart.items.map((item) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Text('${item.quantity}x',
                                      style: TextStyle(
                                          color: AppTheme.accentOrange,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(item.name,
                                            style:
                                                const TextStyle(fontSize: 14)),
                                        if (item.selectedOptions.isNotEmpty)
                                          Text(
                                            item.selectedOptions.join(', '),
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: colorScheme
                                                    .onSurfaceVariant),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text('฿${item.totalPrice.ceil()}'),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      // Note
                      _buildSection(
                        icon: Icons.note_alt_outlined,
                        title: AppLocalizations.of(context)!.foodCheckoutNoteTitle,
                        child: TextField(
                          controller: _noteController,
                          decoration: InputDecoration(
                            hintText: AppLocalizations.of(context)!.foodCheckoutNoteHint,
                            hintStyle: TextStyle(
                                color: colorScheme.onSurfaceVariant),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          maxLines: 2,
                        ),
                      ),
                      // Payment method
                      _buildSection(
                        icon: Icons.payment,
                        title: AppLocalizations.of(context)!.foodCheckoutPaymentTitle,
                        child: Column(
                          children: [
                            _buildPaymentOption('cash', AppLocalizations.of(context)!.foodCheckoutPayCash, Icons.money),
                            _buildPaymentOption(
                                'transfer', AppLocalizations.of(context)!.foodCheckoutPayTransfer, Icons.account_balance),
                          ],
                        ),
                      ),
                      // Price summary
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: colorScheme.surfaceContainer,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          children: [
                            _buildPriceRow(
                                AppLocalizations.of(context)!.foodCartFoodCost, '฿${cart.subtotal.ceil()}'),
                            const SizedBox(height: 8),
                            _buildPriceRow(AppLocalizations.of(context)!.foodCheckoutDeliveryEstimate, '฿30'),
                            const Divider(height: 20),
                            _buildPriceRow(
                              AppLocalizations.of(context)!.foodCartTotal,
                              '฿${(cart.subtotal + 30).ceil()}',
                              isBold: true,
                              isOrange: true,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
          bottomNavigationBar: cart.isEmpty
              ? null
              : Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: colorScheme.shadow.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isPlacingOrder
                            ? null
                            : () => _placeOrder(context, cart),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentOrange,
                          foregroundColor: colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _isPlacingOrder
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: colorScheme.onPrimary),
                              )
                            : Text(
                                AppLocalizations.of(context)!.foodCheckoutConfirmButton,
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildSection(
      {required IconData icon, required String title, required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.accentOrange),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String value, String label, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return RadioListTile<String>(
      value: value,
      groupValue: _paymentMethod,
      onChanged: (v) => setState(() => _paymentMethod = v!),
      title: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
      activeColor: AppTheme.accentOrange,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildPriceRow(String label, String price,
      {bool isBold = false, bool isOrange = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
              color: isBold ? null : colorScheme.onSurfaceVariant,
            )),
        Text(price,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 14,
              color: isOrange ? AppTheme.accentOrange : null,
            )),
      ],
    );
  }

  Future<Map<String, dynamic>> _resolveCustomerLocationForOrder() async {
    var lat = _fallbackLat;
    var lng = _fallbackLng;

    try {
      final locationEnabled = await Geolocator.isLocationServiceEnabled();
      if (locationEnabled) {
        var permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) {
          if (mounted) {
            final accepted =
                await LocationDisclosureHelper.showIfNeeded(context);
            if (!accepted)
              return {'lat': lat, 'lng': lng, 'address': AppLocalizations.of(context)!.foodCheckoutCurrentLocation};
          }
          permission = await Geolocator.requestPermission();
        }

        if (permission != LocationPermission.denied &&
            permission != LocationPermission.deniedForever) {
          final position = await Geolocator.getCurrentPosition(
            desiredAccuracy: LocationAccuracy.high,
            timeLimit: const Duration(seconds: 10),
          );
          lat = position.latitude;
          lng = position.longitude;
        }
      }
    } catch (e) {
      debugLog('⚠️ Unable to fetch current customer location: $e');
    }

    var address = AppLocalizations.of(context)!.foodCheckoutCurrentLocation;
    try {
      final resolved =
          await GeocodingService.getAddressFromCoordinates(lat, lng);
      if (resolved != null && resolved.trim().isNotEmpty) {
        address = resolved.trim();
      }
    } catch (e) {
      debugLog('⚠️ Unable to reverse-geocode customer location: $e');
    }

    return {
      'lat': lat,
      'lng': lng,
      'address': address,
    };
  }

  Future<void> _placeOrder(BuildContext context, CartProvider cart) async {
    setState(() => _isPlacingOrder = true);
    final l10n = AppLocalizations.of(context)!;

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception(l10n.foodCheckoutLoginRequired);

      // Import needed services dynamically
      final bookingService = _BookingServiceHelper();

      final note = _noteController.text.trim();
      if (note.isNotEmpty) {
        cart.setNote(note);
      }

      final customerLocation = await _resolveCustomerLocationForOrder();

      final booking = await bookingService.createFoodOrder(
        userId: userId,
        merchantId: cart.merchantId!,
        merchantName: cart.merchantName!,
        cartItems: cart.toCartList(),
        subtotal: cart.subtotal,
        customerLat: customerLocation['lat'] as double,
        customerLng: customerLocation['lng'] as double,
        customerAddress: customerLocation['address'] as String,
        paymentMethod: _paymentMethod,
        note: cart.note,
      );

      if (booking == null) throw Exception(l10n.foodCheckoutCreateFailed);

      // Send notification to merchant about new order
      try {
        final merchantId = cart.merchantId;
        if (merchantId != null && merchantId.isNotEmpty) {
          debugLog(
              '📤 Sending new order notification to merchant: $merchantId');
          await NotificationSender.sendToUser(
            userId: merchantId,
            title: l10n.foodCheckoutNotifTitle,
            body:
                l10n.foodCheckoutNotifBody(cart.subtotal.ceil().toString()),
            data: {
              'type': 'merchant_new_order',
              'booking_id': booking['id']?.toString() ?? '',
            },
          );
        }
      } catch (e) {
        debugLog('⚠️ Failed to send merchant notification: $e');
      }

      cart.clearCart();

      if (mounted) {
        // Show success and navigate
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ ${l10n.foodCheckoutSuccess}'),
            backgroundColor: Theme.of(context).colorScheme.secondary,
          ),
        );
        // Pop back to home
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugLog('❌ สั่งอาหารล้มเหลว: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.foodCheckoutOrderFailed(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }
}

// ============================================================
// Booking Service Helper (bridges to existing BookingService)
// ============================================================
class _BookingServiceHelper {
  Future<String> _reverseGeocodeOrDefault(double lat, double lng) async {
    try {
      final addr = await GeocodingService.getAddressFromCoordinates(lat, lng);
      if (addr != null && addr.isNotEmpty) return addr;
    } catch (_) {}
    return 'Current location';
  }

  Future<Map<String, dynamic>?> createFoodOrder({
    required String userId,
    required String merchantId,
    required String merchantName,
    required List<Map<String, dynamic>> cartItems,
    required double subtotal,
    required double customerLat,
    required double customerLng,
    required String customerAddress,
    required String paymentMethod,
    required String note,
  }) async {
    try {
      final client = Supabase.instance.client;

      // Get merchant location + custom fee settings
      Map<String, dynamic>? merchantProfile;
      try {
        merchantProfile = await client
            .from('profiles')
            .select(
                'latitude, longitude, gp_rate, merchant_gp_system_rate, merchant_gp_driver_rate, custom_base_fare, custom_base_distance, custom_per_km, custom_delivery_fee')
            .eq('id', merchantId)
            .maybeSingle();
      } catch (_) {}

      final merchantLat = (merchantProfile?['latitude'] as num?)?.toDouble();
      final merchantLng = (merchantProfile?['longitude'] as num?)?.toDouble();
      if (merchantLat == null || merchantLng == null) {
        throw Exception('ไม่พบตำแหน่งร้านค้า กรุณาให้ร้านค้าตั้งค่าตำแหน่งร้านก่อนรับออเดอร์');
      }

      // Calculate distance (straight-line fallback)
      double distanceKm = 3.0;
      try {
        final dist = Geolocator.distanceBetween(
          merchantLat,
          merchantLng,
          customerLat,
          customerLng,
        );
        distanceKm = dist / 1000.0;
        if (distanceKm < 0.5) distanceKm = 0.5;
      } catch (_) {}

      // Calculate delivery fee using rates (global → merchant override)
      double baseFare = 15.0;
      double baseDistance = 2.0;
      double perKm = 10.0;
      MerchantFoodConfig? merchantFoodConfig;
      try {
        final configService = SystemConfigService();
        await configService.fetchSettings();
        final rate = configService.getServiceRate('food');
        if (rate != null) {
          baseFare = rate.basePrice.toDouble();
          baseDistance = rate.baseDistance.toDouble();
          perKm = rate.pricePerKm.toDouble();
        }

        merchantFoodConfig = MerchantFoodConfigService.resolve(
          merchantProfile: merchantProfile,
          defaultMerchantSystemRate: configService.merchantGpRate,
          defaultMerchantDriverRate: 0.0,
          defaultDeliverySystemRate: configService.platformFeeRate,
        );
      } catch (_) {}

      // Apply merchant overrides / presets
      if (merchantFoodConfig?.baseFare != null) {
        baseFare = merchantFoodConfig!.baseFare!;
      }
      if (merchantFoodConfig?.baseDistanceKm != null) {
        baseDistance = merchantFoodConfig!.baseDistanceKm!;
      }
      if (merchantFoodConfig?.perKmCharge != null) {
        perKm = merchantFoodConfig!.perKmCharge!;
      }

      double deliveryFee;
      if (merchantFoodConfig?.fixedDeliveryFee != null) {
        deliveryFee = merchantFoodConfig!.fixedDeliveryFee!;
      } else if (distanceKm <= baseDistance) {
        deliveryFee = baseFare;
      } else {
        deliveryFee = baseFare + ((distanceKm - baseDistance) * perKm);
      }
      deliveryFee = double.parse(deliveryFee.toStringAsFixed(0));
      final normalizedCustomerAddress = customerAddress.trim().isNotEmpty
          ? customerAddress.trim()
          : await _reverseGeocodeOrDefault(customerLat, customerLng);

      // Create booking
      final response = await client
          .from('bookings')
          .insert({
            'customer_id': userId,
            'service_type': 'food',
            'merchant_id': merchantId,
            'origin_lat': merchantLat,
            'origin_lng': merchantLng,
            'dest_lat': customerLat,
            'dest_lng': customerLng,
            'pickup_address': merchantName,
            'destination_address': normalizedCustomerAddress,
            'distance_km': distanceKm,
            'price': subtotal,
            'delivery_fee': deliveryFee,
            'notes': note.isNotEmpty ? note : 'Food order from $merchantName',
            'status': 'pending_merchant',
            'payment_method': paymentMethod,
          })
          .select()
          .single();

      final bookingId = response['id'] as String;

      // Insert booking items (DB columns: booking_id, menu_item_id, quantity, price, name)
      final items = cartItems.map((item) {
        final qty = item['quantity'] ?? 1;
        final basePrice = (item['base_price'] ?? item['price']) as num;
        return {
          'booking_id': bookingId,
          'menu_item_id': item['id'],
          'name': item['name'] ?? '',
          'price': basePrice,
          'quantity': qty,
        };
      }).toList();

      if (items.isNotEmpty) {
        await client.from('booking_items').insert(items);
      }

      debugLog('✅ Food order created: $bookingId');
      return response;
    } catch (e) {
      debugLog('❌ Error creating food order: $e');
      return null;
    }
  }
}
