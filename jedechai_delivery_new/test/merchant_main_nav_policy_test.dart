import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/apps/merchant/utils/merchant_main_nav_policy.dart';

void main() {
  group('merchantMainNavFeaturesForServiceType', () {
    test('shows menu and hides laundry for food merchants', () {
      final features = merchantMainNavFeaturesForServiceType('food');

      expect(features, contains(MerchantMainNavFeature.menu));
      expect(features, isNot(contains(MerchantMainNavFeature.laundry)));
    });

    test('shows laundry and hides menu for laundry merchants', () {
      final features = merchantMainNavFeaturesForServiceType('laundry');

      expect(features, contains(MerchantMainNavFeature.laundry));
      expect(features, isNot(contains(MerchantMainNavFeature.menu)));
    });

    test('keeps shared merchant tabs for every valid service type', () {
      for (final serviceType in ['food', 'laundry']) {
        final features = merchantMainNavFeaturesForServiceType(serviceType);

        expect(features.first, MerchantMainNavFeature.orders);
        expect(features, contains(MerchantMainNavFeature.report));
        expect(features, contains(MerchantMainNavFeature.notifications));
        expect(features.last, MerchantMainNavFeature.account);
      }
    });
  });
}
