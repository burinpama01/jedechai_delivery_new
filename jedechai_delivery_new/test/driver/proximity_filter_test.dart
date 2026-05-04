// Sprint 5.2 — Driver Unit Tests: Proximity / Fare Surcharge
//
// FareAdjustmentService.calculateRideFarPickupSurcharge is a pure static
// function — no Supabase access, fully testable without any setup.
//
// Methods that require Supabase (getDriverToPickupDistanceKm,
// calculateFoodFarPickupSurcharge, findNearestOnlineDriverDistanceKm) are
// covered by integration test stubs at the bottom.
//
// Vehicle type normalization rules (_normalizeVehicleType):
//   - Contains 'car' or 'รถยนต์' → 'car'  (uses carRatePerKm)
//   - Anything else              → 'motorcycle' (uses motorcycleRatePerKm)
//
// Surcharge formula:
//   if distanceKm <= thresholdKm → 0
//   extra = distanceKm - thresholdKm
//   surcharge = double.parse((extra * ratePerKm).toStringAsFixed(2))

import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/services/fare_adjustment_service.dart';

void main() {
  const defaultConfig = RideFarPickupConfig(
    thresholdKm: 3.0,
    motorcycleRatePerKm: 5.0,
    carRatePerKm: 7.0,
  );

  // ──────────────────────────────────────────────
  // calculateRideFarPickupSurcharge
  // ──────────────────────────────────────────────
  group('FareAdjustmentService.calculateRideFarPickupSurcharge', () {
    test('no surcharge when distance equals threshold exactly', () {
      expect(
        FareAdjustmentService.calculateRideFarPickupSurcharge(
          driverToPickupDistanceKm: 3.0,
          vehicleType: 'motorcycle',
          config: defaultConfig,
        ),
        0,
      );
    });

    test('no surcharge when distance is below threshold', () {
      expect(
        FareAdjustmentService.calculateRideFarPickupSurcharge(
          driverToPickupDistanceKm: 1.5,
          vehicleType: 'motorcycle',
          config: defaultConfig,
        ),
        0,
      );
    });

    test('no surcharge at 0 km', () {
      expect(
        FareAdjustmentService.calculateRideFarPickupSurcharge(
          driverToPickupDistanceKm: 0,
          vehicleType: 'car',
          config: defaultConfig,
        ),
        0,
      );
    });

    test('motorcycle: 1 km over threshold → 5 THB', () {
      // extra = 4.0 - 3.0 = 1.0, rate = 5.0 → 5.00
      expect(
        FareAdjustmentService.calculateRideFarPickupSurcharge(
          driverToPickupDistanceKm: 4.0,
          vehicleType: 'motorcycle',
          config: defaultConfig,
        ),
        5.0,
      );
    });

    test('motorcycle: 3 km over threshold → 15 THB', () {
      // extra = 6.0 - 3.0 = 3.0, rate = 5.0 → 15.00
      expect(
        FareAdjustmentService.calculateRideFarPickupSurcharge(
          driverToPickupDistanceKm: 6.0,
          vehicleType: 'motorcycle',
          config: defaultConfig,
        ),
        15.0,
      );
    });

    test('car: 1 km over threshold → 7 THB', () {
      // extra = 4.0 - 3.0 = 1.0, rate = 7.0 → 7.00
      expect(
        FareAdjustmentService.calculateRideFarPickupSurcharge(
          driverToPickupDistanceKm: 4.0,
          vehicleType: 'car',
          config: defaultConfig,
        ),
        7.0,
      );
    });

    test('car: 2 km over threshold → 14 THB', () {
      // extra = 5.0 - 3.0 = 2.0, rate = 7.0 → 14.00
      expect(
        FareAdjustmentService.calculateRideFarPickupSurcharge(
          driverToPickupDistanceKm: 5.0,
          vehicleType: 'car',
          config: defaultConfig,
        ),
        14.0,
      );
    });

    test('Thai vehicle name "รถยนต์" normalizes to car rate', () {
      expect(
        FareAdjustmentService.calculateRideFarPickupSurcharge(
          driverToPickupDistanceKm: 4.0,
          vehicleType: 'รถยนต์',
          config: defaultConfig,
        ),
        7.0, // car rate
      );
    });

    test('unknown vehicle type defaults to motorcycle rate', () {
      expect(
        FareAdjustmentService.calculateRideFarPickupSurcharge(
          driverToPickupDistanceKm: 4.0,
          vehicleType: 'truck',
          config: defaultConfig,
        ),
        5.0, // motorcycle fallback
      );
    });

    test('null-like vehicle type defaults to motorcycle rate', () {
      expect(
        FareAdjustmentService.calculateRideFarPickupSurcharge(
          driverToPickupDistanceKm: 4.0,
          vehicleType: '',
          config: defaultConfig,
        ),
        5.0,
      );
    });

    test('fractional distance is rounded to 2 decimal places', () {
      // extra = 4.0 - 3.0 = 1.0, but use fractional:
      // distance = 3.7, extra = 0.7, motorcycle rate = 5.0 → 3.50
      expect(
        FareAdjustmentService.calculateRideFarPickupSurcharge(
          driverToPickupDistanceKm: 3.7,
          vehicleType: 'motorcycle',
          config: defaultConfig,
        ),
        closeTo(3.5, 0.005),
      );
    });

    test('custom config: higher threshold and rates', () {
      const customConfig = RideFarPickupConfig(
        thresholdKm: 5.0,
        motorcycleRatePerKm: 10.0,
        carRatePerKm: 15.0,
      );
      // Under new threshold: no surcharge
      expect(
        FareAdjustmentService.calculateRideFarPickupSurcharge(
          driverToPickupDistanceKm: 4.0,
          vehicleType: 'motorcycle',
          config: customConfig,
        ),
        0,
      );
      // Over new threshold: extra = 6.0 - 5.0 = 1.0, rate = 10.0 → 10 THB
      expect(
        FareAdjustmentService.calculateRideFarPickupSurcharge(
          driverToPickupDistanceKm: 6.0,
          vehicleType: 'motorcycle',
          config: customConfig,
        ),
        10.0,
      );
    });
  });

  // ──────────────────────────────────────────────
  // RideFarPickupConfig construction
  // ──────────────────────────────────────────────
  group('RideFarPickupConfig', () {
    test('stores values correctly', () {
      const config = RideFarPickupConfig(
        thresholdKm: 2.0,
        motorcycleRatePerKm: 4.0,
        carRatePerKm: 6.0,
      );
      expect(config.thresholdKm, 2.0);
      expect(config.motorcycleRatePerKm, 4.0);
      expect(config.carRatePerKm, 6.0);
    });
  });

  // ──────────────────────────────────────────────
  // Integration test stubs (require Supabase + driver_locations table)
  // ──────────────────────────────────────────────
  //
  // group('FareAdjustmentService Supabase-dependent methods', () {
  //   test('getDriverToPickupDistanceKm returns null when no location row exists', () async {
  //     final km = await FareAdjustmentService.getDriverToPickupDistanceKm(
  //       driverId: 'no-location-driver',
  //       pickupLat: 13.7,
  //       pickupLng: 100.5,
  //     );
  //     expect(km, isNull);
  //   });
  //
  //   test('findNearestOnlineDriverDistanceKm returns null when no online drivers', () async {
  //     final km = await FareAdjustmentService.findNearestOnlineDriverDistanceKm(
  //       pickupLat: 13.7,
  //       pickupLng: 100.5,
  //       vehicleType: 'motorcycle',
  //     );
  //     expect(km, isNull);
  //   });
  //
  //   test('calculateFoodFarPickupSurcharge returns 0 when driver is within threshold', () async {
  //     // Seed driver_locations with a position close to merchantLat/Lng
  //     final surcharge = await FareAdjustmentService.calculateFoodFarPickupSurcharge(
  //       merchantId: testMerchantId,
  //       driverId: nearbyDriverId,
  //       merchantLat: 13.7,
  //       merchantLng: 100.5,
  //     );
  //     expect(surcharge, 0);
  //   });
  // });
}
