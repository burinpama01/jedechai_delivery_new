import 'booking_status_policy.dart';

enum DriverJobHiddenReason {
  driverOffline,
  driverLocationMissing,
  outsideRadius,
  serviceTypeNotAccepted,
  vehicleTypeMismatch,
  waitingMerchantAccept,
  merchantPreparing,
  waitingDriverArrival,
  alreadyAssignedToOtherDriver,
  terminalStatus,
  unsupportedStatus,
}

class DriverJobVisibilityResult {
  const DriverJobVisibilityResult.visible()
      : visible = true,
        reason = null;

  const DriverJobVisibilityResult.hidden(this.reason) : visible = false;

  final bool visible;
  final DriverJobHiddenReason? reason;
}

class DriverJobVisibilityPolicy {
  const DriverJobVisibilityPolicy._();

  static DriverJobVisibilityResult evaluate({
    required String? serviceType,
    required String? status,
    required String? driverId,
    required String? currentDriverId,
    required bool isOnline,
    required bool isWithinRadius,
    List<String>? acceptedServiceTypes,
    bool locationReady = true,
    String? jobVehicleType,
    String? driverVehicleType,
  }) {
    final normalizedStatus = (status ?? '').trim();
    final normalizedServiceType = (serviceType ?? '').trim();
    final normalizedDriverId = driverId?.trim();
    final normalizedCurrentDriverId = currentDriverId?.trim();
    final isAssignedToThisDriver = normalizedDriverId != null &&
        normalizedDriverId.isNotEmpty &&
        normalizedCurrentDriverId != null &&
        normalizedCurrentDriverId.isNotEmpty &&
        normalizedDriverId == normalizedCurrentDriverId;

    if (BookingStatusPolicy.terminalStatuses.contains(normalizedStatus)) {
      return const DriverJobVisibilityResult.hidden(
        DriverJobHiddenReason.terminalStatus,
      );
    }

    if (normalizedDriverId != null &&
        normalizedDriverId.isNotEmpty &&
        !isAssignedToThisDriver) {
      return const DriverJobVisibilityResult.hidden(
        DriverJobHiddenReason.alreadyAssignedToOtherDriver,
      );
    }

    if (isAssignedToThisDriver) {
      return const DriverJobVisibilityResult.visible();
    }

    if (!isOnline) {
      return const DriverJobVisibilityResult.hidden(
        DriverJobHiddenReason.driverOffline,
      );
    }

    if (!_serviceTypeAccepted(normalizedServiceType, acceptedServiceTypes)) {
      return const DriverJobVisibilityResult.hidden(
        DriverJobHiddenReason.serviceTypeNotAccepted,
      );
    }

    final statusReason = _availableStatusReason(
      serviceType: normalizedServiceType,
      status: normalizedStatus,
    );
    if (statusReason != null) {
      return DriverJobVisibilityResult.hidden(statusReason);
    }

    if (!locationReady) {
      return const DriverJobVisibilityResult.hidden(
        DriverJobHiddenReason.driverLocationMissing,
      );
    }

    if (!_vehicleTypeMatches(
      serviceType: normalizedServiceType,
      jobVehicleType: jobVehicleType,
      driverVehicleType: driverVehicleType,
    )) {
      return const DriverJobVisibilityResult.hidden(
        DriverJobHiddenReason.vehicleTypeMismatch,
      );
    }

    if (!isWithinRadius) {
      return const DriverJobVisibilityResult.hidden(
        DriverJobHiddenReason.outsideRadius,
      );
    }

    return const DriverJobVisibilityResult.visible();
  }

  static DriverJobHiddenReason? _availableStatusReason({
    required String serviceType,
    required String status,
  }) {
    if (serviceType == 'ride' || serviceType == 'parcel') {
      return status == 'pending'
          ? null
          : DriverJobHiddenReason.unsupportedStatus;
    }

    if (serviceType == 'food') {
      switch (status) {
        case 'ready_for_pickup':
          return null;
        case 'pending_merchant':
          return DriverJobHiddenReason.waitingMerchantAccept;
        case 'preparing':
          return DriverJobHiddenReason.merchantPreparing;
        case 'matched':
        case 'driver_accepted':
        case 'arrived_at_merchant':
          return DriverJobHiddenReason.waitingDriverArrival;
        default:
          return DriverJobHiddenReason.unsupportedStatus;
      }
    }

    return DriverJobHiddenReason.unsupportedStatus;
  }

  static bool _serviceTypeAccepted(
    String serviceType,
    List<String>? acceptedServiceTypes,
  ) {
    if (acceptedServiceTypes == null || acceptedServiceTypes.isEmpty) {
      return true;
    }
    return acceptedServiceTypes.contains(serviceType);
  }

  static bool _vehicleTypeMatches({
    required String serviceType,
    required String? jobVehicleType,
    required String? driverVehicleType,
  }) {
    if (serviceType != 'ride') return true;

    final job = jobVehicleType?.trim();
    final driver = driverVehicleType?.trim();
    if (job == null || job.isEmpty || driver == null || driver.isEmpty) {
      return true;
    }
    return job == driver;
  }
}
