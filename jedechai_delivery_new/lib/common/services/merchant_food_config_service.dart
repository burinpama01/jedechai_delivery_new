/// Merchant-specific food pricing and finance resolver.
///
/// Centralizes per-merchant overrides for:
/// - Delivery pricing (base fare/base distance/per-km/fixed delivery fee)
/// - Food GP split (system vs driver)
/// - Delivery system fee rate
class MerchantFoodConfig {
  final String modeKey;
  final double merchantGpSystemRate;
  final double merchantGpDriverRate;
  final double deliverySystemRate;
  final double? fixedDeliveryFee;
  final double? baseFare;
  final double? baseDistanceKm;
  final double? perKmCharge;
  final double? merchantGpRateOverride;

  const MerchantFoodConfig({
    required this.modeKey,
    required this.merchantGpSystemRate,
    required this.merchantGpDriverRate,
    required this.deliverySystemRate,
    required this.fixedDeliveryFee,
    required this.baseFare,
    required this.baseDistanceKm,
    required this.perKmCharge,
    required this.merchantGpRateOverride,
  });

  double get merchantGpTotalRate => merchantGpSystemRate + merchantGpDriverRate;

  String get summary =>
      'mode=$modeKey, gpSystem=${(merchantGpSystemRate * 100).toStringAsFixed(0)}%, '
      'gpDriver=${(merchantGpDriverRate * 100).toStringAsFixed(0)}%, '
      'deliverySystem=${(deliverySystemRate * 100).toStringAsFixed(0)}%';

  double calculateDeliveryFee({
    required double distanceKm,
    required double defaultBaseFare,
    required double defaultBaseDistance,
    required double defaultPerKmCharge,
    double minDeliveryFee = 0,
  }) {
    final double safeMinFee = minDeliveryFee < 0 ? 0.0 : minDeliveryFee;

    if (fixedDeliveryFee != null) {
      final fixed = fixedDeliveryFee! < 0 ? 0 : fixedDeliveryFee!;
      final normalized = fixed < safeMinFee ? safeMinFee : fixed;
      return double.parse(normalized.toStringAsFixed(0));
    }

    final double startFare = (baseFare ?? defaultBaseFare) < 0
        ? 0.0
        : (baseFare ?? defaultBaseFare);
    final double startDistance = (baseDistanceKm ?? defaultBaseDistance) < 0
        ? 0.0
        : (baseDistanceKm ?? defaultBaseDistance);
    final double extraPerKm = (perKmCharge ?? defaultPerKmCharge) < 0
        ? 0.0
        : (perKmCharge ?? defaultPerKmCharge);

    final double safeDistance = distanceKm < 0 ? 0.0 : distanceKm;

    double fee;
    if (safeDistance <= startDistance) {
      fee = startFare;
    } else {
      fee = startFare + ((safeDistance - startDistance) * extraPerKm);
    }

    if (fee < safeMinFee) fee = safeMinFee;
    return double.parse(fee.toStringAsFixed(0));
  }
}

class MerchantFoodConfigService {
  static const List<_MerchantFoodPreset> _presets = [
    _MerchantFoodPreset(
      modeKey: 'plan_1',
      matchGpRate: 0.10,
      merchantSystemRate: 0.10,
      merchantDriverRate: 0.00,
      deliverySystemRate: 0.02,
      baseFare: 10,
      baseDistanceKm: 5,
      perKmCharge: 3,
    ),
    _MerchantFoodPreset(
      modeKey: 'plan_2',
      matchGpRate: 0.20,
      merchantSystemRate: 0.10,
      merchantDriverRate: 0.10,
      deliverySystemRate: 0.01,
      baseFare: 5,
      baseDistanceKm: 7,
      perKmCharge: 2,
    ),
    _MerchantFoodPreset(
      modeKey: 'plan_3',
      matchGpRate: 0.25,
      merchantSystemRate: 0.13,
      merchantDriverRate: 0.12,
      deliverySystemRate: 0.00,
      baseFare: 0,
      baseDistanceKm: 10,
      perKmCharge: 1,
    ),
  ];

  static MerchantFoodConfig resolve({
    required Map<String, dynamic>? merchantProfile,
    required double defaultMerchantSystemRate,
    required double defaultMerchantDriverRate,
    required double defaultDeliverySystemRate,
  }) {
    final gpRate = _toDouble(merchantProfile?['gp_rate']);
    final customBaseFare = _toDouble(merchantProfile?['custom_base_fare']);
    final customBaseDistance = _toDouble(merchantProfile?['custom_base_distance']);
    final customPerKm = _toDouble(merchantProfile?['custom_per_km']);
    final customDeliveryFee = _toDouble(merchantProfile?['custom_delivery_fee']);

    _MerchantFoodPreset? preset;
    if (gpRate != null) {
      for (final candidate in _presets) {
        if (_isClose(gpRate, candidate.matchGpRate)) {
          preset = candidate;
          break;
        }
      }
    }

    final resolvedSystemRate = _clampRate(
      preset?.merchantSystemRate ?? gpRate ?? defaultMerchantSystemRate,
    );
    final resolvedDriverRate = _clampRate(
      preset?.merchantDriverRate ?? defaultMerchantDriverRate,
    );
    final resolvedDeliverySystemRate = _clampRate(
      preset?.deliverySystemRate ?? defaultDeliverySystemRate,
    );

    return MerchantFoodConfig(
      modeKey: preset?.modeKey ?? (gpRate != null ? 'merchant_custom' : 'default'),
      merchantGpSystemRate: resolvedSystemRate,
      merchantGpDriverRate: resolvedDriverRate,
      deliverySystemRate: resolvedDeliverySystemRate,
      fixedDeliveryFee: customDeliveryFee,
      baseFare: customBaseFare ?? preset?.baseFare,
      baseDistanceKm: customBaseDistance ?? preset?.baseDistanceKm,
      perKmCharge: customPerKm ?? preset?.perKmCharge,
      merchantGpRateOverride: gpRate,
    );
  }

  static double _clampRate(double value) {
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  static bool _isClose(double a, double b) => (a - b).abs() < 0.0001;

  static double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    if (value is String) {
      final parsed = double.tryParse(value.trim());
      return parsed;
    }
    return null;
  }
}

class _MerchantFoodPreset {
  final String modeKey;
  final double matchGpRate;
  final double merchantSystemRate;
  final double merchantDriverRate;
  final double deliverySystemRate;
  final double baseFare;
  final double baseDistanceKm;
  final double perKmCharge;

  const _MerchantFoodPreset({
    required this.modeKey,
    required this.matchGpRate,
    required this.merchantSystemRate,
    required this.merchantDriverRate,
    required this.deliverySystemRate,
    required this.baseFare,
    required this.baseDistanceKm,
    required this.perKmCharge,
  });
}
