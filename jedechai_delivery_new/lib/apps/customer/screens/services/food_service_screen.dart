import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../common/utils/shop_schedule.dart';
import '../../../../common/services/system_config_service.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
import '../../../../common/widgets/app_network_image.dart';
import 'restaurant_detail_screen.dart';

/// Food Service Screen
///
/// Displays list of restaurants (merchants) for food ordering
class FoodServiceScreen extends StatefulWidget {
  const FoodServiceScreen({super.key});

  @override
  State<FoodServiceScreen> createState() => _FoodServiceScreenState();
}

class _FoodServiceScreenState extends State<FoodServiceScreen> {
  List<Map<String, dynamic>> _restaurants = [];
  bool _isLoading = true;
  String? _error;
  Position? _currentPosition;
  double _radiusKm = 30.0;

  // Wave 1.5 filter state
  String _b1ActiveFilter = 'nearby';

  @override
  void initState() {
    super.initState();
    _fetchRestaurants();
  }

  Future<void> _fetchRestaurants() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Load radius config and customer position in parallel
      await Future.wait([_loadRadiusConfig(), _loadCurrentPosition()]);

      final response = await Supabase.instance.client
          .from('profiles')
          .select(
              'id, full_name, phone_number, latitude, longitude, shop_status, shop_open_time, shop_close_time, shop_open_days, shop_auto_schedule_enabled')
          .eq('role', 'merchant')
          .eq('approval_status', 'approved')
          .contains('merchant_service_types', ['food'])
          .order('full_name');

      debugLog('📊 Debug: Found ${response.length} restaurants');

      final all = List<Map<String, dynamic>>.from(response);
      final filtered = _currentPosition == null
          ? all // no location known — show all (degrade gracefully)
          : all.where((r) {
              final lat = (r['latitude'] as num?)?.toDouble();
              final lng = (r['longitude'] as num?)?.toDouble();
              if (lat == null || lng == null) return true;
              final km = Geolocator.distanceBetween(
                      _currentPosition!.latitude, _currentPosition!.longitude, lat, lng) /
                  1000;
              return km <= _radiusKm;
            }).toList();

      setState(() {
        _restaurants = filtered.where(isShopOpenNow).toList();
        _isLoading = false;
      });
    } catch (e) {
      debugLog('❌ Debug: Error fetching restaurants: $e');
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _loadRadiusConfig() async {
    try {
      final configService = SystemConfigService();
      await configService.fetchSettings();
      _radiusKm = configService.maxDeliveryRadius;
    } catch (_) {}
  }

  Future<void> _loadCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return;
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) return;
      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.low,
      );
    } catch (_) {}
  }

  // Wave 1.5 b1food: artboard Customer-FoodService layout
  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      backgroundColor: jdc.paper,
      body: Column(
        children: [
          // Header
          Container(
            color: jdc.surface,
            child: SafeArea(
              bottom: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(10, 16, 20, 0),
                    child: Row(
                      children: [
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.chevron_left_rounded, color: jdc.text, size: 21),
                          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                          padding: EdgeInsets.zero,
                        ),
                        Expanded(
                          child: Text(
                            l10n.foodSvcTitle,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: jdc.text),
                          ),
                        ),
                        if (!_isLoading)
                          Text(
                            l10n.foodSvcShopCount(_restaurants.length.toString()),
                            style: TextStyle(fontSize: 12, color: jdc.muted),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Filter chips
                  SizedBox(
                    height: 50,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.fromLTRB(20, 5, 20, 5),
                      children: [
                        _b1FilterChip(l10n.foodSvcFilterSort, 'sort', icon: Icons.tune_rounded),
                        const SizedBox(width: 8),
                        _b1FilterChip(l10n.foodSvcFilterNearby, 'nearby'),
                        const SizedBox(width: 8),
                        _b1FilterChip(l10n.foodSvcFilterRating, 'rating'),
                        const SizedBox(width: 8),
                        _b1FilterChip(l10n.foodSvcFilterFreeDelivery, 'free'),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: jdc.line),
                ],
              ),
            ),
          ),
          // List
          Expanded(
            child: RefreshIndicator(
              color: jdc.brand,
              onRefresh: _fetchRestaurants,
              child: _buildB1Body(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _b1FilterChip(String label, String id, {IconData? icon}) {
    final jdc = JdcColors.of(context);
    final isActive = _b1ActiveFilter == id;
    return GestureDetector(
      onTap: () => setState(() => _b1ActiveFilter = id),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13),
        height: 40,
        decoration: BoxDecoration(
          color: isActive ? jdc.panel : jdc.surface,
          border: Border.all(color: isActive ? Colors.transparent : jdc.line),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 15, color: isActive ? jdc.onPanel : jdc.text),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w600,
                color: isActive ? jdc.onPanel : jdc.text,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildB1Body(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: jdc.brand));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: JdcSpacing.xl),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: jdc.dim),
              const SizedBox(height: JdcSpacing.lg),
              Text(l10n.foodSvcLoadError(_error!), style: TextStyle(fontSize: 16, color: jdc.muted), textAlign: TextAlign.center),
              const SizedBox(height: JdcSpacing.lg),
              ElevatedButton(onPressed: _fetchRestaurants, child: Text(l10n.foodSvcRetry)),
            ],
          ),
        ),
      );
    }
    if (_restaurants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.restaurant_outlined, size: 64, color: jdc.dim),
            const SizedBox(height: JdcSpacing.lg),
            Text(l10n.foodSvcEmpty, style: TextStyle(fontSize: 16, color: jdc.muted)),
            const SizedBox(height: JdcSpacing.lg),
            ElevatedButton(onPressed: _fetchRestaurants, child: Text(l10n.foodSvcRefresh)),
          ],
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      itemCount: _restaurants.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final r = _restaurants[index];
        return _B1RestaurantCard(
          restaurant: r,
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => RestaurantDetailScreen(
              merchantId: r['id'],
              merchantName: r['full_name'] ?? l10n.foodSvcRestaurantFallback,
            ),
          )),
        );
      },
    );
  }
}

/// Wave 1.5 b1food restaurant card (Customer-FoodService artboard style)
class _B1RestaurantCard extends StatelessWidget {
  final Map<String, dynamic> restaurant;
  final VoidCallback onTap;
  const _B1RestaurantCard({required this.restaurant, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final name = restaurant['full_name'] as String? ?? l10n.foodSvcRestaurantFallback;
    final imageUrl = restaurant['profile_image_url'] as String?;
    final isOpen = isShopOpenNow(restaurant);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: jdc.surface,
          border: Border.all(color: jdc.line),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Logo
            ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: SizedBox(
                width: 58,
                height: 58,
                child: imageUrl != null && imageUrl.isNotEmpty
                    ? AppNetworkImage(
                        imageUrl: imageUrl,
                        width: 58,
                        height: 58,
                        fit: BoxFit.cover,
                        backgroundColor: jdc.brandSoft,
                      )
                    : GrayscaleLogoPlaceholder(
                        width: 58,
                        height: 58,
                        backgroundColor: jdc.brandSoft,
                        padding: const EdgeInsets.all(10),
                      ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isOpen ? jdc.text : jdc.dim,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'ตามสั่ง · ก๋วยเตี๋ยว',
                    style: TextStyle(fontSize: 12, color: jdc.muted),
                  ),
                  const SizedBox(height: 3),
                  if (isOpen)
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: 13, color: jdc.brandOnSoft),
                        const SizedBox(width: 4),
                        Text('4.5', style: TextStyle(fontSize: 12, color: jdc.brandOnSoft, fontWeight: FontWeight.w700)),
                        const SizedBox(width: 10),
                        Text('15–25 นาที', style: TextStyle(fontSize: 12, color: jdc.muted)),
                        const SizedBox(width: 10),
                        Text('ค่าส่ง ฿15', style: TextStyle(fontSize: 12, color: jdc.muted)),
                      ],
                    )
                  else
                    Text(
                      'ปิดอยู่',
                      style: TextStyle(fontSize: 12, color: jdc.dangerInk, fontWeight: FontWeight.w600),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Legacy RestaurantCard kept for backward compatibility
class RestaurantCard extends StatelessWidget {
  final Map<String, dynamic> restaurant;
  final VoidCallback onTap;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => _B1RestaurantCard(restaurant: restaurant, onTap: onTap);
}
