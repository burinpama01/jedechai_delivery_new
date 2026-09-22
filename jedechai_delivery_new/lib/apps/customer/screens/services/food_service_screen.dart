import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../common/utils/shop_schedule.dart';
import '../../../../common/services/system_config_service.dart';
import '../../../../theme/jdc_colors.dart';
import '../../../../theme/jdc_layout.dart';
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

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    return Scaffold(
      backgroundColor: jdc.paper,
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.foodSvcTitle),
        backgroundColor: jdc.panel,
        foregroundColor: jdc.onPanel,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchRestaurants,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    final jdc = JdcColors.of(context);
    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: jdc.brand),
      );
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
              Text(
                AppLocalizations.of(context)!.foodSvcLoadError(_error!),
                style: TextStyle(fontSize: 16, color: jdc.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: JdcSpacing.lg),
              ElevatedButton(
                onPressed: _fetchRestaurants,
                child: Text(AppLocalizations.of(context)!.foodSvcRetry),
              ),
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
            Text(
              AppLocalizations.of(context)!.foodSvcEmpty,
              style: TextStyle(fontSize: 16, color: jdc.muted),
            ),
            const SizedBox(height: JdcSpacing.lg),
            ElevatedButton(
              onPressed: _fetchRestaurants,
              child: Text(AppLocalizations.of(context)!.foodSvcRefresh),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(JdcSpacing.lg),
      itemCount: _restaurants.length,
      itemBuilder: (context, index) {
        final restaurant = _restaurants[index];
        return RestaurantCard(
          restaurant: restaurant,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (context) => RestaurantDetailScreen(
                  merchantId: restaurant['id'],
                  merchantName: restaurant['full_name'] ??
                      AppLocalizations.of(context)!.foodSvcRestaurantFallback,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class RestaurantCard extends StatelessWidget {
  final Map<String, dynamic> restaurant;
  final VoidCallback onTap;

  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final name = restaurant['full_name'] ?? l10n.foodSvcRestaurantFallback;
    final phone = restaurant['phone_number'] ?? l10n.foodSvcNotSpecified;

    return Card(
      margin: const EdgeInsets.only(bottom: JdcSpacing.lg),
      elevation: 2,
      color: jdc.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(JdcRadius.card),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        child: Padding(
          padding: const EdgeInsets.all(JdcSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: jdc.brandSoft,
                  borderRadius: BorderRadius.circular(JdcRadius.small),
                ),
                child: Icon(
                  Icons.restaurant,
                  color: jdc.brandOnSoft,
                  size: 30,
                ),
              ),
              const SizedBox(width: JdcSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: jdc.text,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: JdcSpacing.xs),
                    Text(
                      phone,
                      style: TextStyle(fontSize: 14, color: jdc.muted),
                    ),
                    const SizedBox(height: JdcSpacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: JdcSpacing.sm,
                        vertical: JdcSpacing.xs,
                      ),
                      decoration: BoxDecoration(
                        color: jdc.successSoft,
                        borderRadius: BorderRadius.circular(JdcRadius.chip),
                      ),
                      child: Text(
                        l10n.foodSvcOpen,
                        style: TextStyle(
                          fontSize: 12,
                          color: jdc.successInk,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: jdc.dim,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
