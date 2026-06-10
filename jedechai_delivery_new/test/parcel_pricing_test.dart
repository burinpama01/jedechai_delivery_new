import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/utils/parcel_pricing.dart';

void main() {
  group('calculateParcelPrice', () {
    test('uses loaded service rates instead of fallback rates', () {
      final price = calculateParcelPrice(
        distanceKm: 7,
        sizeMultiplier: 1.0,
        basePrice: 40,
        pricePerKm: 12,
        baseDistance: 3,
      );

      expect(price, 88);
    });

    test('applies size multiplier after distance fee calculation', () {
      final price = calculateParcelPrice(
        distanceKm: 5,
        sizeMultiplier: 1.6,
        basePrice: 20,
        pricePerKm: 5,
        baseDistance: 2,
      );

      expect(price, 56);
    });
  });
}
