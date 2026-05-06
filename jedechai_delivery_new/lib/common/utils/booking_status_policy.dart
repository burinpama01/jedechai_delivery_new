enum DriverActionKey {
  arrivedPickup,
  arrivedMerchant,
  waitMerchantReady,
  pickupFood,
  startDelivery,
  complete,
  updateStatus,
}

class BookingStatusPolicy {
  const BookingStatusPolicy._();

  static const Set<String> terminalStatuses = {
    'completed',
    'cancelled',
  };

  static bool canMerchantMarkFoodReady({
    required String serviceType,
    required String currentStatus,
  }) {
    if (serviceType != 'food') return false;
    return currentStatus == 'arrived_at_merchant';
  }

  static bool canMerchantStoreFoodReadyPendingDriver({
    required String serviceType,
    required String currentStatus,
  }) {
    if (serviceType != 'food') return false;
    return const {
      'preparing',
      'matched',
      'driver_accepted',
    }.contains(currentStatus);
  }

  static String? driverNextStatus({
    required String serviceType,
    required String currentStatus,
  }) {
    if (serviceType == 'food') {
      switch (currentStatus) {
        case 'accepted':
        case 'driver_accepted':
          return 'arrived_at_merchant';
        case 'arrived_at_merchant':
          return null;
        case 'ready_for_pickup':
          return 'picking_up_order';
        case 'picking_up_order':
          return 'in_transit';
        case 'in_transit':
          return 'completed';
        default:
          return null;
      }
    }

    switch (currentStatus) {
      case 'accepted':
      case 'driver_accepted':
        return 'arrived';
      case 'arrived':
        return 'in_transit';
      case 'in_transit':
        return 'completed';
      default:
        return null;
    }
  }

  static DriverActionKey driverActionKey({
    required String serviceType,
    required String currentStatus,
  }) {
    if (serviceType == 'food') {
      switch (currentStatus) {
        case 'accepted':
        case 'driver_accepted':
          return DriverActionKey.arrivedMerchant;
        case 'arrived_at_merchant':
          return DriverActionKey.waitMerchantReady;
        case 'ready_for_pickup':
          return DriverActionKey.pickupFood;
        case 'picking_up_order':
          return DriverActionKey.startDelivery;
        case 'in_transit':
          return DriverActionKey.complete;
        default:
          return DriverActionKey.updateStatus;
      }
    }

    switch (currentStatus) {
      case 'accepted':
      case 'driver_accepted':
        return DriverActionKey.arrivedPickup;
      case 'arrived':
        return DriverActionKey.startDelivery;
      case 'in_transit':
        return DriverActionKey.complete;
      default:
        return DriverActionKey.updateStatus;
    }
  }
}
