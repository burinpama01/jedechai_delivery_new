import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/models/booking_status.dart';

void main() {
  group('BookingStatus.fromString', () {
    test('converts all known status strings correctly', () {
      expect(BookingStatus.fromString('pending'), BookingStatus.pending);
      expect(BookingStatus.fromString('pending_merchant'), BookingStatus.pendingMerchant);
      expect(BookingStatus.fromString('preparing'), BookingStatus.preparing);
      expect(BookingStatus.fromString('matched'), BookingStatus.matched);
      expect(BookingStatus.fromString('ready_for_pickup'), BookingStatus.readyForPickup);
      expect(BookingStatus.fromString('accepted'), BookingStatus.accepted);
      expect(BookingStatus.fromString('driver_accepted'), BookingStatus.driverAccepted);
      expect(BookingStatus.fromString('arrived'), BookingStatus.arrived);
      expect(BookingStatus.fromString('arrived_at_merchant'), BookingStatus.arrivedAtMerchant);
      expect(BookingStatus.fromString('picking_up_order'), BookingStatus.pickingUpOrder);
      expect(BookingStatus.fromString('in_transit'), BookingStatus.inTransit);
      expect(BookingStatus.fromString('completed'), BookingStatus.completed);
      expect(BookingStatus.fromString('cancelled'), BookingStatus.cancelled);
    });

    test('returns pending for unknown status', () {
      expect(BookingStatus.fromString('unknown'), BookingStatus.pending);
      expect(BookingStatus.fromString(null), BookingStatus.pending);
      expect(BookingStatus.fromString(''), BookingStatus.pending);
    });
  });

  group('BookingStatus.toDbString', () {
    test('converts all enum values to correct db strings', () {
      expect(BookingStatus.pending.toDbString(), 'pending');
      expect(BookingStatus.pendingMerchant.toDbString(), 'pending_merchant');
      expect(BookingStatus.preparing.toDbString(), 'preparing');
      expect(BookingStatus.matched.toDbString(), 'matched');
      expect(BookingStatus.readyForPickup.toDbString(), 'ready_for_pickup');
      expect(BookingStatus.accepted.toDbString(), 'accepted');
      expect(BookingStatus.driverAccepted.toDbString(), 'driver_accepted');
      expect(BookingStatus.arrived.toDbString(), 'arrived');
      expect(BookingStatus.arrivedAtMerchant.toDbString(), 'arrived_at_merchant');
      expect(BookingStatus.pickingUpOrder.toDbString(), 'picking_up_order');
      expect(BookingStatus.inTransit.toDbString(), 'in_transit');
      expect(BookingStatus.completed.toDbString(), 'completed');
      expect(BookingStatus.cancelled.toDbString(), 'cancelled');
    });

    test('roundtrip: fromString(toDbString()) returns same value', () {
      for (final status in BookingStatus.values) {
        expect(BookingStatus.fromString(status.toDbString()), status);
      }
    });
  });

  group('BookingStatus text getters', () {
    test('customerText returns non-empty string for all statuses', () {
      for (final status in BookingStatus.values) {
        expect(status.customerText.isNotEmpty, true,
            reason: '${status.name} customerText should not be empty');
      }
    });

    test('driverText returns non-empty string for all statuses', () {
      for (final status in BookingStatus.values) {
        expect(status.driverText.isNotEmpty, true,
            reason: '${status.name} driverText should not be empty');
      }
    });

    test('merchantText returns non-empty string for all statuses', () {
      for (final status in BookingStatus.values) {
        expect(status.merchantText.isNotEmpty, true,
            reason: '${status.name} merchantText should not be empty');
      }
    });
  });

  group('BookingStatus color and icon', () {
    test('every status has a color', () {
      for (final status in BookingStatus.values) {
        expect(status.color, isA<Color>(),
            reason: '${status.name} should have a color');
      }
    });

    test('every status has an icon', () {
      for (final status in BookingStatus.values) {
        expect(status.icon, isA<IconData>(),
            reason: '${status.name} should have an icon');
      }
    });
  });

  group('BookingStatus boolean helpers', () {
    test('isActive is false for completed and cancelled', () {
      expect(BookingStatus.completed.isActive, false);
      expect(BookingStatus.cancelled.isActive, false);
    });

    test('isActive is true for all other statuses', () {
      final activeStatuses = BookingStatus.values
          .where((s) => s != BookingStatus.completed && s != BookingStatus.cancelled);
      for (final status in activeStatuses) {
        expect(status.isActive, true, reason: '${status.name} should be active');
      }
    });

    test('hasDriver is true for driver-assigned statuses', () {
      expect(BookingStatus.accepted.hasDriver, true);
      expect(BookingStatus.driverAccepted.hasDriver, true);
      expect(BookingStatus.arrived.hasDriver, true);
      expect(BookingStatus.arrivedAtMerchant.hasDriver, true);
      expect(BookingStatus.pickingUpOrder.hasDriver, true);
      expect(BookingStatus.inTransit.hasDriver, true);
    });

    test('hasDriver is false for pre-driver statuses', () {
      expect(BookingStatus.pending.hasDriver, false);
      expect(BookingStatus.pendingMerchant.hasDriver, false);
      expect(BookingStatus.preparing.hasDriver, false);
    });

    test('isFoodPreparation is true for food prep statuses', () {
      expect(BookingStatus.pendingMerchant.isFoodPreparation, true);
      expect(BookingStatus.preparing.isFoodPreparation, true);
      expect(BookingStatus.readyForPickup.isFoodPreparation, true);
    });

    test('isFoodPreparation is false for non-food statuses', () {
      expect(BookingStatus.pending.isFoodPreparation, false);
      expect(BookingStatus.accepted.isFoodPreparation, false);
      expect(BookingStatus.inTransit.isFoodPreparation, false);
      expect(BookingStatus.completed.isFoodPreparation, false);
    });
  });
}
