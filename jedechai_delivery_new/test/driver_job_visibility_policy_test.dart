import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/utils/driver_job_visibility_policy.dart';

void main() {
  group('DriverJobVisibilityPolicy', () {
    test('food pending merchant is hidden with waiting merchant reason', () {
      final result = DriverJobVisibilityPolicy.evaluate(
        serviceType: 'food',
        status: 'pending_merchant',
        driverId: null,
        currentDriverId: 'driver-1',
        isOnline: true,
        isWithinRadius: true,
        acceptedServiceTypes: null,
      );

      expect(result.visible, isFalse);
      expect(result.reason, DriverJobHiddenReason.waitingMerchantAccept);
    });

    test('food preparing is hidden with merchant preparing reason', () {
      final result = DriverJobVisibilityPolicy.evaluate(
        serviceType: 'food',
        status: 'preparing',
        driverId: null,
        currentDriverId: 'driver-1',
        isOnline: true,
        isWithinRadius: true,
        acceptedServiceTypes: null,
      );

      expect(result.visible, isFalse);
      expect(result.reason, DriverJobHiddenReason.merchantPreparing);
    });

    test('food ready for pickup is visible when available and in radius', () {
      final result = DriverJobVisibilityPolicy.evaluate(
        serviceType: 'food',
        status: 'ready_for_pickup',
        driverId: null,
        currentDriverId: 'driver-1',
        isOnline: true,
        isWithinRadius: true,
        acceptedServiceTypes: null,
      );

      expect(result.visible, isTrue);
      expect(result.reason, isNull);
    });

    test('missing location hides unassigned available job', () {
      final result = DriverJobVisibilityPolicy.evaluate(
        serviceType: 'ride',
        status: 'pending',
        driverId: null,
        currentDriverId: 'driver-1',
        isOnline: true,
        isWithinRadius: false,
        acceptedServiceTypes: null,
        locationReady: false,
      );

      expect(result.visible, isFalse);
      expect(result.reason, DriverJobHiddenReason.driverLocationMissing);
    });

    test('assigned job remains visible while offline', () {
      final result = DriverJobVisibilityPolicy.evaluate(
        serviceType: 'food',
        status: 'driver_accepted',
        driverId: 'driver-1',
        currentDriverId: 'driver-1',
        isOnline: false,
        isWithinRadius: false,
        acceptedServiceTypes: const ['ride'],
      );

      expect(result.visible, isTrue);
    });

    test('service type filter hides unmatched services', () {
      final result = DriverJobVisibilityPolicy.evaluate(
        serviceType: 'food',
        status: 'ready_for_pickup',
        driverId: null,
        currentDriverId: 'driver-1',
        isOnline: true,
        isWithinRadius: true,
        acceptedServiceTypes: const ['ride'],
      );

      expect(result.visible, isFalse);
      expect(result.reason, DriverJobHiddenReason.serviceTypeNotAccepted);
    });
  });
}
