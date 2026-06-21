class FoodDeliveryDistancePolicy {
  const FoodDeliveryDistancePolicy._();

  static bool shouldWarn({
    required double distanceKm,
    required double maxDeliveryRadiusKm,
  }) {
    return distanceKm > maxDeliveryRadiusKm;
  }
}
