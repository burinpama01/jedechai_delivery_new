import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../theme/app_theme.dart';
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
              'id, full_name, phone_number, shop_status, shop_open_time, shop_close_time, shop_open_days, shop_auto_schedule_enabled')
          .eq('role', 'merchant')
          .eq('approval_status', 'approved')
          .order('full_name');

      debugLog('📊 Debug: Found ${response.length} restaurants');

      setState(() {
        _restaurants = List<Map<String, dynamic>>.from(response)
            .where(_isShopOpenNow)
            .toList();
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.foodSvcTitle),
        backgroundColor: AppTheme.accentOrange,
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchRestaurants,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.foodSvcLoadError(_error!),
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchRestaurants,
              child: Text(AppLocalizations.of(context)!.foodSvcRetry),
            ),
          ],
        ),
      );
    }

    if (_restaurants.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.restaurant_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.foodSvcEmpty,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _fetchRestaurants,
              child: Text(AppLocalizations.of(context)!.foodSvcRefresh),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
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
                  merchantName: restaurant['full_name'] ?? AppLocalizations.of(context)!.foodSvcRestaurantFallback,
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
    final l10n = AppLocalizations.of(context)!;
    final name = restaurant['full_name'] ?? l10n.foodSvcRestaurantFallback;
    final phone = restaurant['phone_number'] ?? l10n.foodSvcNotSpecified;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: AppTheme.accentOrange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.restaurant,
                  color: AppTheme.accentOrange,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phone,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        AppLocalizations.of(context)!.foodSvcOpen,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios,
                color: Colors.grey[400],
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
