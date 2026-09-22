import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import '../../providers/cart_provider.dart';
import 'package:geolocator/geolocator.dart';
import '../../../../common/services/supabase_service.dart';
import '../../../../common/services/system_config_service.dart';
import '../../../../common/services/customer_favorite_service.dart';
import '../../../../common/widgets/app_network_image.dart';
import '../../../../common/widgets/location_disclosure_dialog.dart';
import '../../../../common/utils/shop_schedule.dart';
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
  Timer? _scheduleRefreshTimer;
  List<Map<String, dynamic>> _allRadiusRestaurants = [];
  List<Map<String, dynamic>> _topSellingItems = [];
  bool _isLoadingTopSelling = true;
  Position? _currentPosition;
  double _restaurantRadiusKm = 30.0;
  bool _isOutOfRestaurantCoverage = false;
  bool _isLocationUnavailable = false;
  final CustomerFavoriteService _favoriteService =
      const CustomerFavoriteService();
  Set<String> _favoriteMerchantIds = {};
  bool _showAllShops = false;
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _shopSectionKey = GlobalKey();

  /// คีย์หมวด = ค่าที่ร้านกรอกใน menu_items.category — "อื่นๆ" คือร้านที่มีหมวดนอก 5 หมวดนี้
  static const String _otherCategoryKey = 'อื่นๆ';
  static const List<String> _knownCategoryKeys = [
    'อาหารตามสั่ง',
    'ก๋วยเตี๋ยว',
    'เครื่องดื่ม',
    'ของหวาน',
    'ฟาสต์ฟู้ด',
  ];

  List<_FoodCategory> _getCategories(AppLocalizations l10n) => [
        _FoodCategory('อาหารตามสั่ง', l10n.foodCategoryMadeToOrder,
            Icons.restaurant_rounded),
        _FoodCategory(
            'ก๋วยเตี๋ยว', l10n.foodCategoryNoodles, Icons.ramen_dining_rounded),
        _FoodCategory(
            'เครื่องดื่ม', l10n.foodCategoryDrinks, Icons.local_cafe_rounded),
        _FoodCategory(
            'ของหวาน', l10n.foodCategoryDesserts, Icons.icecream_rounded),
        _FoodCategory(
            'ฟาสต์ฟู้ด', l10n.foodCategoryFastFood, Icons.lunch_dining_rounded),
        _FoodCategory(_otherCategoryKey, l10n.foodCategoryOther,
            Icons.more_horiz_rounded),
      ];

  /// ไม่ใช้ key.contains(menuCategory) เพราะหมวดสั้น ๆ อย่าง "อาหาร" จะหลุดเข้าทุกหมวด
  static bool _categoryMatches(String menuCategory, String key) =>
      menuCategory.trim() == key || menuCategory.contains(key);

  @override
  void initState() {
    super.initState();
    _initializeContextAndLoadRestaurants();
    _loadFoodBanners();
  }

  Future<void> _initializeContextAndLoadRestaurants() async {
    await _loadRestaurantRadius();
    await _resolveCurrentLocation();
    await _fetchRestaurants();
    await _fetchFavorites();
    await _fetchTopSellingItems();
  }

  Future<void> _fetchFavorites() async {
    try {
      final favoriteIds = await _favoriteService.getFavoriteMerchantIds();
      if (!mounted) return;
      setState(() => _favoriteMerchantIds = favoriteIds);
    } catch (e) {
      debugLog('⚠️ โหลดร้านโปรดไม่สำเร็จ: $e');
    }
  }

  Future<void> _toggleFavorite(String merchantId) async {
    final nextValue = !_favoriteMerchantIds.contains(merchantId);
    setState(() {
      if (nextValue) {
        _favoriteMerchantIds.add(merchantId);
      } else {
        _favoriteMerchantIds.remove(merchantId);
      }
    });

    try {
      await _favoriteService.setFavorite(
        merchantId: merchantId,
        favorite: nextValue,
      );
    } catch (e) {
      debugLog('⚠️ อัปเดตร้านโปรดไม่สำเร็จ: $e');
      if (!mounted) return;
      setState(() {
        if (nextValue) {
          _favoriteMerchantIds.remove(merchantId);
        } else {
          _favoriteMerchantIds.add(merchantId);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(AppLocalizations.of(context)!.foodHomeFavoriteError)),
      );
    }
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
    _scheduleRefreshTimer?.cancel();
    _bannerController.dispose();
    _scrollController.dispose();
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
      if (_restaurants.isEmpty) {
        if (mounted) {
          setState(() {
            _topSellingItems = [];
            _isLoadingTopSelling = false;
          });
        }
        return;
      }

      final visibleMerchantIds =
          _restaurants.map((r) => r['id'] as String).toSet();

      // ดึง booking_items จาก completed bookings (จำกัด 90 วัน เพื่อป้องกัน unbounded query)
      final cutoff = DateTime.now()
          .subtract(const Duration(days: 90))
          .toUtc()
          .toIso8601String();
      final bookingItemsResponse = await Supabase.instance.client
          .from('booking_items')
          .select('menu_item_id, quantity, bookings!inner(status, created_at)')
          .eq('bookings.status', 'completed')
          .gte('bookings.created_at', cutoff)
          .limit(2000);

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
      final visibleMenuResponse = menuResponse
          .where(
              (m) => visibleMerchantIds.contains(m['merchant_id'] as String?))
          .toList();

      // ดึงข้อมูล merchant (ชื่อร้าน + รูป + สถานะ)
      final merchantIds = visibleMenuResponse
          .map((m) => m['merchant_id'] as String)
          .toSet()
          .toList();
      if (merchantIds.isEmpty) {
        if (mounted) {
          setState(() {
            _topSellingItems = [];
            _isLoadingTopSelling = false;
          });
        }
        return;
      }
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
        final item = visibleMenuResponse.firstWhere(
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

      final response = await Supabase.instance.client
          .from('profiles')
          .select(
              'id, full_name, phone_number, shop_status, shop_address, shop_photo_url, latitude, longitude, shop_open_time, shop_close_time, shop_open_days, shop_auto_schedule_enabled')
          .eq('role', 'merchant')
          .eq('approval_status', 'approved')
          .contains('merchant_service_types', ['food']).order('full_name');

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

      final allFetched = List<Map<String, dynamic>>.from(response);
      final radiusFiltered = <Map<String, dynamic>>[];

      _isLocationUnavailable = _currentPosition == null;

      for (final restaurant in allFetched) {
        if (_currentPosition == null) {
          // No location — skip rather than show all (enforce radius policy)
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
          radiusFiltered.add({...restaurant, 'distance_km': distanceKm});
        }
      }

      _allRadiusRestaurants = radiusFiltered;
      _scheduleRefreshTimer?.cancel();
      _scheduleRefreshTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        if (!mounted) return;
        setState(() {
          _restaurants = _allRadiusRestaurants.where(isShopOpenNow).toList();
          _applyFilters();
        });
      });

      final openRestaurants = radiusFiltered.where(isShopOpenNow).toList();
      setState(() {
        _restaurants = openRestaurants;
        // ไม่มีร้านเข้าร่วมในรัศมีเลย (ต่างจาก "มีร้านแต่ปิดหมด" ซึ่งใช้ข้อความ foodHomeEmptyNoneOpen)
        // เดิมเงื่อนไขกลับด้าน: มีร้านแต่ปิด → ขึ้น "ไม่มีร้านในพื้นที่" / ไม่มีร้าน → ขึ้น "ไม่มีร้านเปิด"
        _isOutOfRestaurantCoverage =
            radiusFiltered.isEmpty && !_isLocationUnavailable;
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
        matchCategory = _selectedCategory == _otherCategoryKey
            ? cats.any(
                (c) => !_knownCategoryKeys.any((k) => _categoryMatches(c, k)))
            : cats.any((c) => _categoryMatches(c, _selectedCategory));
      }

      return matchSearch && matchCategory;
    }).toList()
      // ใกล้สุดขึ้นก่อน — หน้าแรกโชว์แค่ [_homeShopLimit] ร้านแรก
      ..sort((a, b) {
        final da = (a['distance_km'] as num?)?.toDouble() ?? double.infinity;
        final db = (b['distance_km'] as num?)?.toDouble() ?? double.infinity;
        return da.compareTo(db);
      });
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

  /// จำนวนร้านที่โชว์บนหน้าแรกก่อนกด "ดูทั้งหมด" (ตาม artboard Customer-FoodHome)
  static const int _homeShopLimit = 5;

  /// มีร้านเปิดอยู่ แต่ไม่มีร้านไหนตรงหมวดที่เลือก
  bool get _isCategoryEmpty =>
      _selectedCategory != 'all' && _restaurants.isNotEmpty;

  bool get _isFiltering =>
      _searchQuery.isNotEmpty || _selectedCategory != 'all';

  /// Noto Sans Thai เป็น variable font ต้องส่งแกน wght คู่กับ fontWeight เสมอ
  TextStyle _weight(TextStyle base, FontWeight weight) => base.copyWith(
        fontWeight: weight,
        fontVariations: [FontVariation('wght', weight.value.toDouble())],
      );

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final categories = _getCategories(l10n);
    // จอเตี้ย (แนวนอน/คีย์บอร์ดเด้ง): ถ้าตรึงหัวไว้จะเหลือที่ให้รายการร้านไม่ถึง 100px
    // จึงให้หัวเลื่อนออกไปพร้อมเนื้อหาแทน
    final pinHeader = !context.isShort;
    return Scaffold(
      backgroundColor: jdc.paper,
      body: Column(
        children: [
          if (pinHeader) _buildHeader(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                await _fetchRestaurants();
                await _fetchFavorites();
                await _fetchTopSellingItems();
              },
              color: jdc.cta,
              child: CustomScrollView(
                controller: _scrollController,
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  if (!pinHeader) SliverToBoxAdapter(child: _buildHeader()),
                  SliverToBoxAdapter(
                    child: JdcContentFrame(
                      child: Padding(
                        padding: const EdgeInsets.only(top: JdcSpacing.lg),
                        child: _buildCategoryGrid(categories),
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildPromoBanner()),
                  SliverToBoxAdapter(
                    child: KeyedSubtree(
                      key: _shopSectionKey,
                      child: _buildSectionTitle(),
                    ),
                  ),
                  _buildRestaurantList(),
                  SliverToBoxAdapter(child: _buildTopSellingSection()),
                  const SliverToBoxAdapter(
                    child: SizedBox(height: JdcSpacing.xl),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildCartBar(),
    );
  }

  /// ปุ่ม "ดูร้านทั้งหมด" ที่หัวหน้า — ขยายรายการแล้วเลื่อนลงไปหา
  void _showAllShopsAndScroll() {
    setState(() => _showAllShops = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _shopSectionKey.currentContext;
      if (target == null || !mounted) return;
      Scrollable.ensureVisible(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    });
  }

  Widget _buildHeader() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final tt = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(gradient: jdc.hero3),
      child: SafeArea(
        bottom: false,
        child: JdcContentFrame(
          child: Padding(
            // ตาม artboard: บน 18 ล่าง 16
            padding: const EdgeInsets.only(top: 18, bottom: JdcSpacing.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Transform.translate(
                      offset: const Offset(-10, 0),
                      child: SizedBox(
                        width: JdcTouch.minTarget,
                        height: JdcTouch.minTarget,
                        child: IconButton(
                          tooltip: MaterialLocalizations.of(context)
                              .backButtonTooltip,
                          icon: Icon(Icons.chevron_left_rounded,
                              color: jdc.onPanel, size: 28),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        l10n.foodHomeTitle,
                        style: tt.headlineSmall!
                            .copyWith(fontSize: 19, color: jdc.onPanel),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Tooltip(
                      message: l10n.foodHomeAllShopsTooltip,
                      child: Material(
                        color: jdc.panelSoft2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(JdcRadius.field),
                          side: BorderSide(color: jdc.panelLine),
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: InkWell(
                          onTap: _showAllShopsAndScroll,
                          child: SizedBox(
                            width: JdcTouch.minTarget,
                            height: JdcTouch.minTarget,
                            child: Icon(Icons.sort_rounded,
                                color: jdc.onPanel, size: 20),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Container(
                  height: 46,
                  padding: const EdgeInsets.only(left: JdcSpacing.lg),
                  decoration: BoxDecoration(
                    color: jdc.surface,
                    borderRadius: BorderRadius.circular(JdcRadius.chip),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search_rounded, color: jdc.muted, size: 18),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          textInputAction: TextInputAction.search,
                          style: tt.bodyMedium,
                          decoration: InputDecoration(
                            isCollapsed: true,
                            filled: false,
                            hintText: l10n.foodHomeSearchHint,
                            hintStyle:
                                tt.bodyMedium!.copyWith(color: jdc.muted),
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                          ),
                        ),
                      ),
                      if (_searchQuery.isNotEmpty)
                        IconButton(
                          tooltip: MaterialLocalizations.of(context)
                              .deleteButtonTooltip,
                          icon: Icon(Icons.close_rounded,
                              color: jdc.muted, size: 18),
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                        )
                      else
                        const SizedBox(width: JdcSpacing.lg),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// กริดหมวด 6 ช่อง — มือถือ 3 คอลัมน์ (2 แถว) จอกว้าง 6 คอลัมน์ (แถวเดียว)
  Widget _buildCategoryGrid(List<_FoodCategory> categories) {
    final jdc = JdcColors.of(context);
    final tt = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 10.0;
        final columns = constraints.maxWidth >= 520 ? 6 : 3;
        final tileWidth =
            (constraints.maxWidth - gap * (columns - 1)) / columns;
        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (final cat in categories)
              SizedBox(
                width: tileWidth,
                child: Semantics(
                  button: true,
                  selected: _selectedCategory == cat.key,
                  child: Material(
                    color: _selectedCategory == cat.key
                        ? jdc.brandSoft2
                        : jdc.surface,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(JdcRadius.field),
                      side: _selectedCategory == cat.key
                          ? BorderSide(color: jdc.brand, width: 1.5)
                          : BorderSide(color: jdc.line),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => _onCategorySelected(
                          _selectedCategory == cat.key ? 'all' : cat.key),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: JdcSpacing.md),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 34,
                              height: 34,
                              decoration: BoxDecoration(
                                color: jdc.brandSoft,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: Icon(cat.icon,
                                  size: 18, color: jdc.brandOnSoft),
                            ),
                            const SizedBox(height: 7),
                            Text(
                              cat.label,
                              style: _weight(tt.labelMedium!, FontWeight.w600)
                                  .copyWith(color: jdc.text, height: 1.3),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildPromoBanner() {
    if (_foodBanners.isEmpty) return const SizedBox.shrink();

    return JdcContentFrame(
      child: Padding(
        padding: const EdgeInsets.only(top: JdcSpacing.lg),
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
                                  JdcColors.of(context).brand,
                                  JdcColors.of(context)
                                      .brand
                                      .withValues(alpha: 0.72),
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
                          : GrayscaleLogoPlaceholder(
                              width: double.infinity,
                              height: 120,
                              fit: BoxFit.contain,
                              backgroundColor: JdcColors.of(context).surface,
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
                            ? JdcColors.of(context).brand
                            : JdcColors.of(context).line,
                        borderRadius: BorderRadius.circular(3),
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

  Widget _buildTopSellingSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final jdc = JdcColors.of(context);
    final tt = Theme.of(context).textTheme;
    final l10n = AppLocalizations.of(context)!;
    if (_isLoadingTopSelling) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: JdcColors.of(context).brand),
          ),
        ),
      );
    }
    if (_topSellingItems.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        JdcContentFrame(
          child: Padding(
            padding: const EdgeInsets.only(top: 24, bottom: 10),
            child: Row(
              children: [
                Icon(Icons.local_fire_department_rounded,
                    color: jdc.danger, size: 20),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    l10n.foodHomeTopSelling,
                    style: tt.titleMedium!.copyWith(fontSize: 16),
                  ),
                ),
                Text(
                  l10n.foodHomeTopCount(_topSellingItems.length.toString()),
                  style: tt.bodySmall,
                ),
              ],
            ),
          ),
        ),
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: context.gutter - 4),
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
                      ), // distanceKm not available from popular items list
                    ),
                  );
                },
                child: Container(
                  width: 150,
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: jdc.surface,
                    borderRadius: BorderRadius.circular(JdcRadius.field),
                    border: Border.all(color: jdc.line),
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
                                  backgroundColor:
                                      colorScheme.surfaceContainerHighest,
                                )
                              else
                                GrayscaleLogoPlaceholder(fit: BoxFit.contain),
                              // Badge อันดับ
                              Positioned(
                                top: 6,
                                left: 6,
                                child: Container(
                                  padding: EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(colors: [
                                      JdcColors.of(context).brand,
                                      JdcColors.of(context)
                                          .brand
                                          .withValues(alpha: 0.75)
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
                                    color: colorScheme.scrim
                                        .withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(Icons.shopping_bag,
                                          size: 10,
                                          color: colorScheme.onPrimary),
                                      const SizedBox(width: 2),
                                      Text(
                                        l10n.foodHomeSoldCount(
                                            salesCount.toString()),
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
                            SizedBox(height: 2),
                            Text(
                              merchantName,
                              style: TextStyle(
                                  fontSize: 11,
                                  color: colorScheme.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(height: 4),
                            Text(
                              '฿${price.toStringAsFixed(0)}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: jdc.link,
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
                color: JdcColors.of(context).brand, size: 28),
            const SizedBox(width: 8),
            Expanded(
                child: Text(AppLocalizations.of(context)!.foodPromoCodeTitle,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold))),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null && title.isNotEmpty)
              Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text(title,
                    style: TextStyle(
                      fontSize: 14,
                      color: colorScheme.onSurfaceVariant,
                    )),
              ),
            Container(
              width: double.infinity,
              padding: EdgeInsets.symmetric(vertical: 16, horizontal: 20),
              decoration: BoxDecoration(
                color: JdcColors.of(context).brand.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: JdcColors.of(context).brand.withValues(alpha: 0.3)),
              ),
              child: Text(
                code,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: JdcColors.of(context).brand,
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
                  content: Text(
                      AppLocalizations.of(context)!.foodPromoCodeCopied(code)),
                  backgroundColor: JdcColors.of(context).brand,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            icon: Icon(Icons.copy, size: 16),
            label: Text(AppLocalizations.of(context)!.foodPromoCodeCopy),
            style: ElevatedButton.styleFrom(
              backgroundColor: JdcColors.of(context).brand,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  /// ร้านที่โชว์จริง — ถ้าไม่ได้ค้นหา/กรองหมวด จะโชว์แค่ร้านที่ใกล้ที่สุดก่อน
  List<Map<String, dynamic>> get _visibleRestaurants {
    if (_isFiltering || _showAllShops) return _filteredRestaurants;
    return _filteredRestaurants.take(_homeShopLimit).toList();
  }

  Widget _buildSectionTitle() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final tt = Theme.of(context).textTheme;
    final hiddenCount =
        _filteredRestaurants.length - _visibleRestaurants.length;
    return JdcContentFrame(
      child: Padding(
        padding: const EdgeInsets.only(top: JdcSpacing.sm),
        child: Row(
          // ความสูงคงที่ 44 ทุกสถานะ (มีปุ่ม "ดูทั้งหมด" / จำนวนร้าน / ไม่มีอะไร) หัวข้อจะได้ไม่ขยับ
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: JdcTouch.minTarget),
            Expanded(
              child: Text(
                l10n.foodHomeOpenNowTitle,
                style: tt.titleMedium!.copyWith(fontSize: 16),
              ),
            ),
            if (!_isLoading && _isFiltering)
              Text(
                l10n.foodHomeRestaurantCount(
                    _filteredRestaurants.length.toString()),
                style: tt.bodySmall,
              )
            else if (!_isLoading && hiddenCount > 0)
              TextButton(
                onPressed: () => setState(() => _showAllShops = true),
                style: TextButton.styleFrom(
                  foregroundColor: jdc.link,
                  minimumSize:
                      const Size(JdcTouch.minTarget, JdcTouch.minTarget),
                  padding:
                      const EdgeInsets.symmetric(horizontal: JdcSpacing.sm),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  l10n.foodHomeSeeAll,
                  style: _weight(tt.labelMedium!, FontWeight.w700)
                      .copyWith(color: jdc.link),
                ),
              )
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantList() {
    final jdc = JdcColors.of(context);
    if (_isLoading) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Center(
            child: Column(
              children: [
                CircularProgressIndicator(color: jdc.cta),
                const SizedBox(height: JdcSpacing.lg),
                Text(AppLocalizations.of(context)!.foodHomeLoading,
                    style: TextStyle(color: jdc.muted)),
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

    final shops = _visibleRestaurants;
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          final shop = shops[index];
          final id = shop['id'] as String;
          return JdcContentFrame(
            child: _RestaurantRow(
              restaurant: shop,
              categories: _restaurantCategories[id] ?? const {},
              isFavorite: _favoriteMerchantIds.contains(id),
              onFavoriteTap: () => _toggleFavorite(id),
              onTap: () => _navigateToRestaurant(shop),
            ),
          );
        },
        childCount: shops.length,
      ),
    );
  }

  Widget _buildErrorState() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(JdcSpacing.xl),
            decoration: BoxDecoration(
              color: jdc.dangerSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.wifi_off_rounded, size: 40, color: jdc.danger),
          ),
          const SizedBox(height: JdcSpacing.lg),
          Text(l10n.foodHomeErrorTitle,
              style: tt.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: JdcSpacing.sm),
          Text(l10n.foodHomeErrorSubtitle,
              style: tt.bodyMedium!.copyWith(color: jdc.muted),
              textAlign: TextAlign.center),
          const SizedBox(height: JdcSpacing.xl),
          FilledButton.icon(
            onPressed: _fetchRestaurants,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.foodHomeRetry),
            style: FilledButton.styleFrom(
              backgroundColor: jdc.cta,
              foregroundColor: jdc.onCta,
              minimumSize: const Size(0, JdcTouch.field),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(JdcRadius.field)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(JdcSpacing.xl),
            decoration: BoxDecoration(
              color: jdc.brandSoft,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.restaurant_outlined,
                size: 40, color: jdc.brandOnSoft),
          ),
          const SizedBox(height: JdcSpacing.lg),
          Text(
            _searchQuery.isNotEmpty
                ? l10n.foodHomeEmptySearch
                : (_isLocationUnavailable
                    ? l10n.foodHomeEmptyNoLocation
                    : (_isOutOfRestaurantCoverage
                        ? l10n.foodHomeEmptyNoArea
                        : (_isCategoryEmpty
                            ? l10n.foodHomeEmptyCategory
                            : l10n.foodHomeEmptyNoneOpen))),
            style: tt.titleMedium,
            textAlign: TextAlign.center,
          ),
          // ไม่มีตำแหน่ง: หัวข้อบอกให้เปิดตำแหน่งแล้ว ไม่ต้องมีข้อความ "ลองใหม่ภายหลัง" ซ้อน
          if (_searchQuery.isNotEmpty || !_isLocationUnavailable) ...[
            const SizedBox(height: JdcSpacing.sm),
            Text(
              _searchQuery.isNotEmpty
                  ? l10n.foodHomeEmptySearchHint
                  : (_isOutOfRestaurantCoverage
                      ? l10n.foodHomeEmptyNoAreaHint(
                          _restaurantRadiusKm.toStringAsFixed(0))
                      : (_isCategoryEmpty
                          ? l10n.foodHomeEmptyCategoryHint
                          : l10n.foodHomeEmptyTryLater)),
              style: tt.bodyMedium!.copyWith(color: jdc.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCartBar() {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        if (cart.isEmpty) return const SizedBox.shrink();
        final jdc = JdcColors.of(context);
        final l10n = AppLocalizations.of(context)!;
        final tt = Theme.of(context).textTheme;
        final merchant = cart.merchantName ?? '';

        return DecoratedBox(
          decoration: BoxDecoration(
            color: jdc.surface,
            border: Border(top: BorderSide(color: jdc.line)),
          ),
          child: SafeArea(
            top: false,
            child: _BarFrame(
              child: Padding(
                padding: EdgeInsets.only(
                    top: JdcSpacing.md,
                    bottom: context.isShort ? JdcSpacing.md : JdcSpacing.xl),
                child: Material(
                  color: jdc.cta,
                  borderRadius: BorderRadius.circular(16),
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    onTap: _showCartSheet,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        child: Row(
                          children: [
                            Container(
                              constraints: const BoxConstraints(
                                  minWidth: 26, minHeight: 26),
                              padding:
                                  const EdgeInsets.symmetric(horizontal: 7),
                              decoration: BoxDecoration(
                                color: jdc.panelSoft3,
                                borderRadius:
                                    BorderRadius.circular(JdcRadius.chip),
                              ),
                              // ห้ามใช้ Container.alignment ตรงนี้ — จะยืดเต็มความสูงที่ Row ได้รับ
                              child: Center(
                                widthFactor: 1,
                                heightFactor: 1,
                                child: Text(
                                  '${cart.totalItems}',
                                  style: _weight(
                                          tt.labelLarge!, FontWeight.w700)
                                      .copyWith(fontSize: 13, color: jdc.onCta),
                                ),
                              ),
                            ),
                            const SizedBox(width: JdcSpacing.md),
                            Expanded(
                              child: Text(
                                merchant.isEmpty
                                    ? l10n.foodCartViewCart
                                    : '${l10n.foodCartViewCart} · $merchant',
                                style: _weight(tt.bodyLarge!, FontWeight.w700)
                                    .copyWith(color: jdc.onCta),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: JdcSpacing.md),
                            Text(
                              '฿${cart.subtotal.ceil()}',
                              style: tt.titleMedium!
                                  .copyWith(fontSize: 16, color: jdc.onCta),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _navigateToRestaurant(Map<String, dynamic> restaurant) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => RestaurantDetailScreen(
          merchantId: restaurant['id'],
          merchantName: restaurant['full_name'] ??
              AppLocalizations.of(context)!.foodHomeRestaurantDefault,
          distanceKm: (restaurant['distance_km'] as num?)?.toDouble(),
        ),
      ),
    );
    if (mounted) await _fetchFavorites();
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

/// แบบเดียวกับ [JdcContentFrame] แต่สูงเท่าเนื้อหา — ใช้ใน bottomNavigationBar
/// (JdcContentFrame ใช้ Center ซึ่งยืดเต็มความสูงที่ Scaffold ให้ ทำให้แถบตะกร้าเต็มจอ)
class _BarFrame extends StatelessWidget {
  const _BarFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: context.gutter),
      child: Center(
        heightFactor: 1,
        child: ConstrainedBox(
          constraints:
              const BoxConstraints(maxWidth: JdcBreakpoints.readableMaxWidth),
          child: child,
        ),
      ),
    );
  }
}

// ============================================================
// Restaurant Row — แถวร้านแบบ artboard Customer-FoodHome
// ============================================================
class _RestaurantRow extends StatelessWidget {
  final Map<String, dynamic> restaurant;
  final Set<String> categories;
  final VoidCallback onTap;
  final bool isFavorite;
  final VoidCallback onFavoriteTap;

  const _RestaurantRow({
    required this.restaurant,
    required this.categories,
    required this.onTap,
    required this.isFavorite,
    required this.onFavoriteTap,
  });

  /// "21:00:00" → "21:00"
  static String? _shortTime(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    return value.length >= 5 ? value.substring(0, 5) : value;
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final tt = Theme.of(context).textTheme;
    final name = (restaurant['full_name'] as String?)?.trim().isNotEmpty == true
        ? (restaurant['full_name'] as String).trim()
        : l10n.foodHomeRestaurantDefault;
    final photoUrl = restaurant['shop_photo_url'] as String?;
    final distanceKm = (restaurant['distance_km'] as num?)?.toDouble();
    final closeTime = _shortTime(restaurant['shop_close_time'] as String?);

    final meta = <String>[
      distanceKm != null
          ? l10n.foodHomeDistanceKm(distanceKm.toStringAsFixed(1))
          : l10n.foodHomeEstTime,
      if (closeTime != null) l10n.foodHomeOpenUntil(closeTime),
    ].join(' · ');
    final categoryLine = (categories.toList()..sort()).take(2).join(' · ');

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Material(
        color: jdc.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: jdc.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(10, 10, 2, 10),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(13),
                  child: SizedBox(
                    width: 60,
                    height: 60,
                    child: photoUrl != null && photoUrl.isNotEmpty
                        ? AppNetworkImage(
                            imageUrl: photoUrl,
                            fit: BoxFit.cover,
                            width: 60,
                            height: 60,
                            backgroundColor: jdc.sunken,
                          )
                        // ไม่มีรูป: ใช้โลโก้ระบบสีเทา (มาตรฐานทุกช่องรูป ห้ามใช้ตัวย่อ)
                        : GrayscaleLogoPlaceholder(
                            width: 60,
                            height: 60,
                            padding: const EdgeInsets.all(6),
                            backgroundColor: jdc.sunken,
                          ),
                  ),
                ),
                const SizedBox(width: JdcSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: tt.titleSmall!.copyWith(
                          fontWeight: FontWeight.w700,
                          fontVariations: const [FontVariation('wght', 700)],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (categoryLine.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          categoryLine,
                          style: tt.bodySmall,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 3),
                      Text(
                        meta,
                        style: tt.bodySmall,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: isFavorite
                      ? l10n.foodHomeFavoriteRemove
                      : l10n.foodHomeFavoriteAdd,
                  onPressed: onFavoriteTap,
                  icon: Icon(
                    isFavorite
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    size: 20,
                    color: isFavorite ? jdc.danger : jdc.dim,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
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
                    padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                    child: Row(
                      children: [
                        Icon(Icons.shopping_bag,
                            color: JdcColors.of(context).brand, size: 24),
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
                            child: Text(
                                AppLocalizations.of(context)!.foodCartClear,
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
                                Text(
                                    AppLocalizations.of(context)!.foodCartEmpty,
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
                                Text(
                                    AppLocalizations.of(context)!
                                        .foodCartFoodCost,
                                    style: TextStyle(
                                        color: colorScheme.onSurfaceVariant)),
                                Text('฿${cart.subtotal.ceil()}'),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    AppLocalizations.of(context)!
                                        .foodCartDeliveryFee,
                                    style: TextStyle(
                                        color: colorScheme.onSurfaceVariant)),
                                Text(
                                  cart.deliveryFee > 0
                                      ? '฿${cart.deliveryFee.ceil()}'
                                      : AppLocalizations.of(context)!
                                          .foodCartDeliveryCalcLater,
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
                            Divider(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                    AppLocalizations.of(context)!.foodCartTotal,
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                Text(
                                  '฿${cart.subtotal.ceil()}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                    color: JdcColors.of(context).brand,
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: 12),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton(
                                onPressed: () {
                                  Navigator.of(context).pop();
                                  // Navigate to checkout
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => FoodCheckoutScreen(),
                                    ),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: JdcColors.of(context).brand,
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
                : _placeholder(context),
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
                  padding: EdgeInsets.only(top: 2),
                  child: Text(
                    item.selectedOptions.join(', '),
                    style: TextStyle(
                        fontSize: 12, color: colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    '฿${item.totalPrice.ceil()}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: JdcColors.of(context).brand,
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
                          padding: EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            '${item.quantity}',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        InkWell(
                          onTap: onIncrease,
                          child: Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(Icons.add,
                                size: 18, color: JdcColors.of(context).brand),
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

  Widget _placeholder(BuildContext context) {
    return GrayscaleLogoPlaceholder(
      fit: BoxFit.contain,
      backgroundColor: JdcColors.of(context).paper,
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
  const _FoodCategory(this.key, this.label, this.icon);
}
