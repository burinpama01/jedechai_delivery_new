enum MerchantMainNavFeature {
  orders,
  laundry,
  menu,
  report,
  notifications,
  account,
}

List<MerchantMainNavFeature> merchantMainNavFeaturesForServiceType(
  String? serviceType,
) {
  final normalized = serviceType?.trim().toLowerCase();
  final features = <MerchantMainNavFeature>[
    MerchantMainNavFeature.orders,
  ];

  if (normalized == 'laundry') {
    features.add(MerchantMainNavFeature.laundry);
  } else if (normalized == 'food') {
    features.add(MerchantMainNavFeature.menu);
  }

  features.addAll(const [
    MerchantMainNavFeature.report,
    MerchantMainNavFeature.notifications,
    MerchantMainNavFeature.account,
  ]);
  return features;
}
