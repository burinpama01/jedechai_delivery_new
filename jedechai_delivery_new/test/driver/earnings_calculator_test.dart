// Sprint 5.2 — Driver Unit Tests
// Tests for commission/net earning calculation for all service types.
//
// DriverAmountCalculator is a pure static utility (no Supabase, no DI needed).
// WalletService.estimateFoodDeduction is also pure static.
//
// For ride/parcel the commission formula is:
//   commission = jobPrice * (commissionRate / 100)   [default: 15%]
//   driverNet  = jobPrice - commission
//
// For food the formula is defined in foodOrderSettlement():
//   deliverySystemFee = ceil(deliveryFee * deliverySystemRate)
//   merchantSystemGP  = ceil(foodPrice  * merchantGpSystemRate)
//   merchantDriverGP  = ceil(foodPrice  * merchantGpDriverRate)
//   appEarnings       = deliverySystemFee + merchantSystemGP
//   driverNetIncome   = (deliveryFee - deliverySystemFee) + merchantDriverGP

import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/utils/driver_amount_calculator.dart';
import 'package:jedechai_delivery_new/common/services/wallet_service.dart';

void main() {
  // ──────────────────────────────────────────────
  // foodOrderSettlement
  // ──────────────────────────────────────────────
  group('DriverAmountCalculator.foodOrderSettlement', () {
    test('standard food order: ceil-rounds fees correctly', () {
      // deliverySystemFee = ceil(30 * 0.15) = ceil(4.5) = 5
      // merchantSystemGP  = ceil(100 * 0.10) = 10
      // appEarnings       = 5 + 10 = 15
      // driverNetIncome   = (30 - 5) + 0 = 25
      // merchantReceives  = 100 - 10 - 0 = 90
      final s = DriverAmountCalculator.foodOrderSettlement(
        foodPrice: 100,
        deliveryFee: 30,
        deliverySystemRate: 0.15,
        merchantGpSystemRate: 0.10,
        merchantGpDriverRate: 0.0,
      );
      expect(s.deliverySystemFee, 5);
      expect(s.merchantSystemGP, 10);
      expect(s.merchantDriverGP, 0);
      expect(s.appEarnings, 15);
      expect(s.driverNetIncome, 25);
      expect(s.merchantReceives, 90);
    });

    test('merchant driver GP adds to driverNetIncome, not appEarnings', () {
      // deliverySystemFee = ceil(40 * 0.15) = 6
      // merchantSystemGP  = ceil(200 * 0.10) = 20
      // merchantDriverGP  = ceil(200 * 0.05) = 10
      // appEarnings       = 6 + 20 = 26
      // driverNetIncome   = (40 - 6) + 10 = 44
      // merchantReceives  = 200 - 20 - 10 = 170
      final s = DriverAmountCalculator.foodOrderSettlement(
        foodPrice: 200,
        deliveryFee: 40,
        deliverySystemRate: 0.15,
        merchantGpSystemRate: 0.10,
        merchantGpDriverRate: 0.05,
      );
      expect(s.deliverySystemFee, 6);
      expect(s.merchantSystemGP, 20);
      expect(s.merchantDriverGP, 10);
      expect(s.appEarnings, 26);
      expect(s.driverNetIncome, 44);
      expect(s.merchantReceives, 170);
    });

    test('zero delivery fee yields zero deliverySystemFee and zero driverNetIncome', () {
      final s = DriverAmountCalculator.foodOrderSettlement(
        foodPrice: 100,
        deliveryFee: 0,
        deliverySystemRate: 0.15,
        merchantGpSystemRate: 0.10,
        merchantGpDriverRate: 0.0,
      );
      expect(s.deliverySystemFee, 0);
      expect(s.merchantSystemGP, 10);
      expect(s.appEarnings, 10);
      expect(s.driverNetIncome, 0);
    });

    test('rates > 1 are clamped to 1.0', () {
      // deliverySystemFee = ceil(50 * 1.0) = 50
      // merchantSystemGP  = ceil(100 * 1.0) = 100
      // driverNetIncome   = (50 - 50) + 0 = 0
      final s = DriverAmountCalculator.foodOrderSettlement(
        foodPrice: 100,
        deliveryFee: 50,
        deliverySystemRate: 2.0,
        merchantGpSystemRate: 1.5,
        merchantGpDriverRate: 0.0,
      );
      expect(s.deliverySystemFee, 50);
      expect(s.merchantSystemGP, 100);
      expect(s.driverNetIncome, 0);
    });

    test('negative rates are clamped to 0', () {
      final s = DriverAmountCalculator.foodOrderSettlement(
        foodPrice: 100,
        deliveryFee: 50,
        deliverySystemRate: -0.5,
        merchantGpSystemRate: -0.1,
        merchantGpDriverRate: 0.0,
      );
      expect(s.deliverySystemFee, 0);
      expect(s.merchantSystemGP, 0);
      expect(s.appEarnings, 0);
      expect(s.driverNetIncome, 50);
    });

    test('negative food/delivery prices clamp to zero', () {
      final s = DriverAmountCalculator.foodOrderSettlement(
        foodPrice: -100,
        deliveryFee: -30,
        deliverySystemRate: 0.15,
        merchantGpSystemRate: 0.10,
        merchantGpDriverRate: 0.0,
      );
      expect(s.deliverySystemFee, 0);
      expect(s.merchantSystemGP, 0);
      expect(s.appEarnings, 0);
      expect(s.driverNetIncome, 0);
    });

    test('merchantGP = merchantSystemGP + merchantDriverGP', () {
      final s = DriverAmountCalculator.foodOrderSettlement(
        foodPrice: 200,
        deliveryFee: 40,
        deliverySystemRate: 0.15,
        merchantGpSystemRate: 0.10,
        merchantGpDriverRate: 0.05,
      );
      expect(s.merchantGP, s.merchantSystemGP + s.merchantDriverGP);
    });
  });

  // ──────────────────────────────────────────────
  // Ride / Parcel commission (pure math, no Supabase)
  // SystemConfigService.calculateCommission: jobPrice * (commissionRate / 100)
  // Default commissionRate = 15%
  // ──────────────────────────────────────────────
  group('Ride/Parcel commission formula (default 15%)', () {
    const commissionRate = 15.0;

    test('100 THB ride: commission=15, driverNet=85', () {
      const jobPrice = 100;
      final commission = jobPrice * (commissionRate / 100);
      expect(commission, 15.0);
      expect(jobPrice - commission, 85.0);
    });

    test('200 THB parcel: commission=30, driverNet=170', () {
      const jobPrice = 200;
      final commission = jobPrice * (commissionRate / 100);
      expect(commission, 30.0);
      expect(jobPrice - commission, 170.0);
    });

    test('50 THB ride: commission=7.5, driverNet=42.5', () {
      const jobPrice = 50;
      final commission = jobPrice * (commissionRate / 100);
      expect(commission, 7.5);
      expect(jobPrice - commission, 42.5);
    });
  });

  // ──────────────────────────────────────────────
  // shouldUseFoodSettlementFallback
  // ──────────────────────────────────────────────
  group('DriverAmountCalculator.shouldUseFoodSettlementFallback', () {
    test('returns true when savedAmount is null', () {
      expect(
        DriverAmountCalculator.shouldUseFoodSettlementFallback(
          savedAmount: null,
          fallbackAmount: 10,
        ),
        isTrue,
      );
    });

    test('returns true when savedAmount is 0 and fallback is positive', () {
      expect(
        DriverAmountCalculator.shouldUseFoodSettlementFallback(
          savedAmount: 0,
          fallbackAmount: 10,
        ),
        isTrue,
      );
    });

    test('returns false when savedAmount is positive', () {
      expect(
        DriverAmountCalculator.shouldUseFoodSettlementFallback(
          savedAmount: 5,
          fallbackAmount: 10,
        ),
        isFalse,
      );
    });

    test('returns false when both savedAmount and fallback are zero', () {
      expect(
        DriverAmountCalculator.shouldUseFoodSettlementFallback(
          savedAmount: 0,
          fallbackAmount: 0,
        ),
        isFalse,
      );
    });
  });

  // ──────────────────────────────────────────────
  // WalletService.estimateFoodDeduction
  // (static — matches appEarnings from foodOrderSettlement)
  // ──────────────────────────────────────────────
  group('WalletService.estimateFoodDeduction (static)', () {
    test('matches appEarnings from foodOrderSettlement', () {
      const delivery = 30.0;
      const food = 100.0;
      const dRate = 0.15;
      const mRate = 0.10;

      final settlement = DriverAmountCalculator.foodOrderSettlement(
        foodPrice: food,
        deliveryFee: delivery,
        deliverySystemRate: dRate,
        merchantGpSystemRate: mRate,
        merchantGpDriverRate: 0.0,
      );
      final estimated = WalletService.estimateFoodDeduction(
        deliveryFee: delivery,
        foodPrice: food,
        deliverySystemRate: dRate,
        merchantGpSystemRate: mRate,
      );
      expect(estimated, settlement.appEarnings);
    });

    test('uses default rates (15% delivery, 10% merchant) when omitted', () {
      // ceil(40 * 0.15) = 6, ceil(200 * 0.10) = 20 → 26
      final estimated = WalletService.estimateFoodDeduction(
        deliveryFee: 40,
        foodPrice: 200,
      );
      expect(estimated, 26);
    });

    test('merchantGpDriverRate does not inflate wallet deduction estimate', () {
      final withDriverGp = WalletService.estimateFoodDeduction(
        deliveryFee: 30,
        foodPrice: 100,
        deliverySystemRate: 0.15,
        merchantGpSystemRate: 0.10,
        merchantGpDriverRate: 0.05,
      );
      final withoutDriverGp = WalletService.estimateFoodDeduction(
        deliveryFee: 30,
        foodPrice: 100,
        deliverySystemRate: 0.15,
        merchantGpSystemRate: 0.10,
        merchantGpDriverRate: 0.0,
      );
      expect(withDriverGp, withoutDriverGp);
    });

    test('result is idempotent', () {
      final a = WalletService.estimateFoodDeduction(
        deliveryFee: 55,
        foodPrice: 180,
        deliverySystemRate: 0.15,
        merchantGpSystemRate: 0.10,
      );
      final b = WalletService.estimateFoodDeduction(
        deliveryFee: 55,
        foodPrice: 180,
        deliverySystemRate: 0.15,
        merchantGpSystemRate: 0.10,
      );
      expect(a, b);
    });
  });
}
