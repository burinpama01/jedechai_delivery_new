import '../models/booking.dart';

class DriverAmountCalculator {
  static double _clampNonNegative(double v) => v < 0 ? 0 : v;

  static double grossCollect(Booking booking) {
    return booking.serviceType == 'food'
        ? _clampNonNegative(booking.price) + _clampNonNegative(booking.deliveryFee ?? 0)
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
}
