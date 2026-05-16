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
