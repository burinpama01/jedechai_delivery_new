import '../models/booking.dart';

class FoodOrderSettlement {
  final double deliverySystemFee;
  final double merchantSystemGP;
  final double merchantDriverGP;
  final double merchantGP;
  final double appEarnings;
  final double driverNetIncome;
  final double merchantReceives;

  const FoodOrderSettlement({
    required this.deliverySystemFee,
    required this.merchantSystemGP,
    required this.merchantDriverGP,
    required this.merchantGP,
    required this.appEarnings,
    required this.driverNetIncome,
    required this.merchantReceives,
  });
}

class DriverAmountCalculator {
  static double _clampNonNegative(double v) => v < 0 ? 0 : v;
  static double _clampRate(double v) {
    if (v < 0) return 0;
    if (v > 1) return 1;
    return v;
  }

  static double _ceilMoney(double v) => v <= 0 ? 0 : v.ceilToDouble();

  static double grossCollect(Booking booking) {
    return booking.serviceType == 'food'
        ? _clampNonNegative(booking.price) +
            _clampNonNegative(booking.deliveryFee ?? 0)
        : _clampNonNegative(booking.price);
  }

  static double netCollect({
    required Booking booking,
    required double couponDiscountAmount,
  }) {
    final gross = grossCollect(booking);
    final discount = couponDiscountAmount < 0 ? 0 : couponDiscountAmount;
    final total = gross - discount;
    return total < 0 ? 0 : total;
  }

  static double appFee({
    required Booking booking,
    required double netCollectAmount,
  }) {
    final app = booking.appEarnings;
    if (app != null) return _clampNonNegative(app);

    final driver = booking.driverEarnings;
    if (driver != null) {
      final fee = netCollectAmount - driver;
      return fee < 0 ? 0 : fee;
    }

    return 0;
  }

  static double netEarnings({
    required Booking booking,
    required double netCollectAmount,
    required double appFeeAmount,
  }) {
    final net = booking.driverEarnings;
    if (net != null) return _clampNonNegative(net);

    final earn = netCollectAmount - appFeeAmount;
    return earn < 0 ? 0 : earn;
  }

  static bool shouldUseFoodSettlementFallback({
    required double? savedAmount,
    required double fallbackAmount,
  }) {
    return savedAmount == null || (savedAmount <= 0 && fallbackAmount > 0);
  }

  static double appFeeWithFoodFallback({
    required Booking booking,
    required double netCollectAmount,
    FoodOrderSettlement? foodSettlement,
  }) {
    if (booking.serviceType == 'food' &&
        foodSettlement != null &&
        shouldUseFoodSettlementFallback(
          savedAmount: booking.appEarnings,
          fallbackAmount: foodSettlement.appEarnings,
        )) {
      return foodSettlement.appEarnings;
    }

    return appFee(booking: booking, netCollectAmount: netCollectAmount);
  }

  static double netEarningsWithFoodFallback({
    required Booking booking,
    required double netCollectAmount,
    required double appFeeAmount,
    FoodOrderSettlement? foodSettlement,
  }) {
    if (booking.serviceType == 'food' &&
        foodSettlement != null &&
        shouldUseFoodSettlementFallback(
          savedAmount: booking.driverEarnings,
          fallbackAmount: foodSettlement.driverNetIncome,
        )) {
      return foodSettlement.driverNetIncome;
    }

    return netEarnings(
      booking: booking,
      netCollectAmount: netCollectAmount,
      appFeeAmount: appFeeAmount,
    );
  }

  static FoodOrderSettlement foodOrderSettlement({
    required double foodPrice,
    required double deliveryFee,
    required double deliverySystemRate,
    required double merchantGpSystemRate,
    required double merchantGpDriverRate,
  }) {
    final safeFoodPrice = _clampNonNegative(foodPrice);
    final safeDeliveryFee = _clampNonNegative(deliveryFee);
    final safeDeliveryRate = _clampRate(deliverySystemRate);
    final safeMerchantSystemRate = _clampRate(merchantGpSystemRate);
    final safeMerchantDriverRate = _clampRate(merchantGpDriverRate);

    final deliverySystemFee = _ceilMoney(safeDeliveryFee * safeDeliveryRate);
    final merchantSystemGP = _ceilMoney(
      safeFoodPrice * safeMerchantSystemRate,
    );
    final merchantDriverGP = _ceilMoney(
      safeFoodPrice * safeMerchantDriverRate,
    );
    final merchantGP = merchantSystemGP + merchantDriverGP;
    final appEarnings = deliverySystemFee + merchantSystemGP;
    final driverNetIncome = _clampNonNegative(
      (safeDeliveryFee - deliverySystemFee) + merchantDriverGP,
    );
    final merchantReceives = _clampNonNegative(safeFoodPrice - merchantGP);

    return FoodOrderSettlement(
      deliverySystemFee: deliverySystemFee,
      merchantSystemGP: merchantSystemGP,
      merchantDriverGP: merchantDriverGP,
      merchantGP: merchantGP,
      appEarnings: appEarnings,
      driverNetIncome: driverNetIncome,
      merchantReceives: merchantReceives,
    );
  }
}
