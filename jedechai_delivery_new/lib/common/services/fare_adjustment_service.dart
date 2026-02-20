import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';

class RideFarPickupConfig {
  final double thresholdKm;
  final double motorcycleRatePerKm;
  final double carRatePerKm;

  const RideFarPickupConfig({
    required this.thresholdKm,
    required this.motorcycleRatePerKm,
    required this.carRatePerKm,
  });
}

class FareAdjustmentService {
  static final SupabaseClient _client = Supabase.instance.client;

  static const double _defaultRideThresholdKm = 3.0;
  static const double _defaultRideMotorcycleRatePerKm = 5.0;
  static const double _defaultRideCarRatePerKm = 7.0;

  static const double _defaultFoodThresholdKm = 3.0;
  static const double _defaultFoodRatePerKm = 5.0;

  static Future<RideFarPickupConfig> loadRideFarPickupConfig() async {
    final rows = await _client
        .from('system_config')
        .select('key, value')
        .inFilter('key', [
          'ride_far_pickup_threshold_km',
          'ride_far_pickup_rate_per_km_motorcycle',
          'ride_far_pickup_rate_per_km_car',
        ]);

    final map = <String, String>{};
    for (final row in rows) {
      final key = row['key'] as String?;
      final value = row['value'] as String?;
      if (key != null && value != null) {
        map[key] = value;
      }
    }

    return RideFarPickupConfig(
      thresholdKm: _parseDouble(
        map['ride_far_pickup_threshold_km'],
        _defaultRideThresholdKm,
      ),
      motorcycleRatePerKm: _parseDouble(
        map['ride_far_pickup_rate_per_km_motorcycle'],
        _defaultRideMotorcycleRatePerKm,
      ),
      carRatePerKm: _parseDouble(
        map['ride_far_pickup_rate_per_km_car'],
        _defaultRideCarRatePerKm,
      ),
    );
  }

  static Future<double?> findNearestOnlineDriverDistanceKm({
    required double pickupLat,
    required double pickupLng,
    required String vehicleType,
  }) async {
    final normalizedType = _normalizeVehicleType(vehicleType);

    final locationRows = await _client
        .from('driver_locations')
        .select('driver_id, location_lat, location_lng')
        .eq('is_online', true)
        .eq('is_available', true);

    if (locationRows.isEmpty) return null;

    final driverIds = <String>[];
    final locationMap = <String, Map<String, double>>{};

    for (final row in locationRows) {
      final driverId = row['driver_id'] as String?;
      final lat = (row['location_lat'] as num?)?.toDouble();
      final lng = (row['location_lng'] as num?)?.toDouble();
      if (driverId == null || lat == null || lng == null) continue;
      driverIds.add(driverId);
      locationMap[driverId] = {'lat': lat, 'lng': lng};
    }

    if (driverIds.isEmpty) return null;

    final profiles = await _client
        .from('profiles')
        .select('id, vehicle_type')
        .inFilter('id', driverIds)
        .eq('is_online', true)
        .eq('approval_status', 'approved');

    double? nearest;
    for (final profile in profiles) {
      final driverId = profile['id'] as String?;
      final profileType = _normalizeVehicleType(profile['vehicle_type'] as String?);
      if (driverId == null || profileType != normalizedType) continue;
      final loc = locationMap[driverId];
      if (loc == null) continue;

      final km = Geolocator.distanceBetween(
            loc['lat']!,
            loc['lng']!,
            pickupLat,
            pickupLng,
          ) /
          1000;

      if (nearest == null || km < nearest) {
        nearest = km;
      }
    }

    return nearest;
  }

  static Future<double?> getDriverToPickupDistanceKm({
    required String driverId,
    required double pickupLat,
    required double pickupLng,
  }) async {
    final row = await _client
        .from('driver_locations')
        .select('location_lat, location_lng')
        .eq('driver_id', driverId)
        .maybeSingle();

    if (row == null) return null;

    final lat = (row['location_lat'] as num?)?.toDouble();
    final lng = (row['location_lng'] as num?)?.toDouble();
    if (lat == null || lng == null) return null;

    return Geolocator.distanceBetween(lat, lng, pickupLat, pickupLng) / 1000;
  }

  static double calculateRideFarPickupSurcharge({
    required double driverToPickupDistanceKm,
    required String vehicleType,
    required RideFarPickupConfig config,
  }) {
    if (driverToPickupDistanceKm <= config.thresholdKm) return 0;

    final extraDistanceKm = driverToPickupDistanceKm - config.thresholdKm;
    final normalized = _normalizeVehicleType(vehicleType);
    final ratePerKm = normalized == 'car'
        ? config.carRatePerKm
        : config.motorcycleRatePerKm;

    final surcharge = extraDistanceKm * ratePerKm;
    return double.parse(surcharge.toStringAsFixed(2));
  }

  static Future<double> calculateFoodFarPickupSurcharge({
    required String merchantId,
    required String driverId,
    required double merchantLat,
    required double merchantLng,
  }) async {
    final distanceKm = await getDriverToPickupDistanceKm(
      driverId: driverId,
      pickupLat: merchantLat,
      pickupLng: merchantLng,
    );
    if (distanceKm == null) return 0;

    final profile = await _client
        .from('profiles')
        .select('custom_base_distance, custom_per_km')
        .eq('id', merchantId)
        .maybeSingle();

    final threshold = _toDouble(profile?['custom_base_distance']) ??
        await _loadFoodDefaultThresholdKm();
    final ratePerKm = _toDouble(profile?['custom_per_km']) ??
        await _loadFoodDefaultRatePerKm();

    if (distanceKm <= threshold) return 0;

    final extraDistance = distanceKm - threshold;
    final surcharge = extraDistance * ratePerKm;
    return double.parse(surcharge.toStringAsFixed(2));
  }

  static Future<double> _loadFoodDefaultThresholdKm() async {
    final row = await _client
        .from('system_config')
        .select('value')
        .eq('key', 'food_far_pickup_threshold_km_default')
        .maybeSingle();

    return _parseDouble(row?['value'] as String?, _defaultFoodThresholdKm);
  }

  static Future<double> _loadFoodDefaultRatePerKm() async {
    final row = await _client
        .from('system_config')
        .select('value')
        .eq('key', 'food_far_pickup_rate_per_km_default')
        .maybeSingle();

    return _parseDouble(row?['value'] as String?, _defaultFoodRatePerKm);
  }

  static double _parseDouble(String? raw, double fallback) {
    final parsed = double.tryParse((raw ?? '').trim());
    if (parsed == null || parsed < 0) return fallback;
    return parsed;
  }

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value.trim());
    return null;
  }

  static String _normalizeVehicleType(String? vehicleType) {
    final value = (vehicleType ?? '').trim().toLowerCase();
    if (value.contains('car') || value.contains('รถยนต์')) return 'car';
    return 'motorcycle';
  }
}
