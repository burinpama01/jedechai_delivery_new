import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/utils/food_delivery_distance_policy.dart';

void main() {
  group('FoodDeliveryDistancePolicy', () {
    test('warns but still allows order outside configured radius', () {
      final shouldWarn = FoodDeliveryDistancePolicy.shouldWarn(
        distanceKm: 24.5,
        maxDeliveryRadiusKm: 20,
      );

      expect(shouldWarn, isTrue);
    });

    test('allows order without warning inside configured radius', () {
      final shouldWarn = FoodDeliveryDistancePolicy.shouldWarn(
        distanceKm: 12,
        maxDeliveryRadiusKm: 20,
      );

      expect(shouldWarn, isFalse);
    });
  });
}
