const Map<String, double> kParcelSizeMultipliers = {
  'small': 1.0,
  'medium': 1.3,
  'large': 1.6,
  'xlarge': 2.0,
};

double calculateParcelPrice({
  required double distanceKm,
  required double sizeMultiplier,
  required double basePrice,
  required double pricePerKm,
  required double baseDistance,
}) {
  if (distanceKm <= 0) return 0;

  final roundedDistance = distanceKm.round();
  final roundedBaseDistance = baseDistance.round();
  final fee = roundedDistance <= roundedBaseDistance
      ? basePrice
      : basePrice + ((roundedDistance - roundedBaseDistance) * pricePerKm);

  return (fee * sizeMultiplier).roundToDouble();
}
