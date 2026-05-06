import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/utils/booking_status_policy.dart';

void main() {
  group('BookingStatusPolicy food flow', () {
    test('merchant cannot mark food ready before driver arrived at merchant',
        () {
      expect(
        BookingStatusPolicy.canMerchantMarkFoodReady(
          serviceType: 'food',
          currentStatus: 'preparing',
        ),
        isFalse,
      );
      expect(
        BookingStatusPolicy.canMerchantMarkFoodReady(
          serviceType: 'food',
          currentStatus: 'matched',
        ),
        isFalse,
      );
    });

    test('merchant can mark food ready after driver arrived at merchant', () {
      expect(
        BookingStatusPolicy.canMerchantMarkFoodReady(
          serviceType: 'food',
          currentStatus: 'arrived_at_merchant',
        ),
        isTrue,
      );
    });

    test('driver next status keeps arrived_at_merchant waiting for merchant',
        () {
      expect(
        BookingStatusPolicy.driverNextStatus(
          serviceType: 'food',
          currentStatus: 'driver_accepted',
        ),
        'arrived_at_merchant',
      );
      expect(
        BookingStatusPolicy.driverNextStatus(
          serviceType: 'food',
          currentStatus: 'arrived_at_merchant',
        ),
        isNull,
      );
      expect(
        BookingStatusPolicy.driverNextStatus(
          serviceType: 'food',
          currentStatus: 'ready_for_pickup',
        ),
        'picking_up_order',
      );
    });

    test('ready_for_pickup button is pickup food but arrived_at_merchant waits',
        () {
      expect(
        BookingStatusPolicy.driverActionKey(
          serviceType: 'food',
          currentStatus: 'arrived_at_merchant',
        ),
        DriverActionKey.waitMerchantReady,
      );
      expect(
        BookingStatusPolicy.driverActionKey(
          serviceType: 'food',
          currentStatus: 'ready_for_pickup',
        ),
        DriverActionKey.pickupFood,
      );
    });
  });
}
