// Sprint 5.2 — Driver Unit Tests: WalletService
//
// WalletService has two static methods that are fully testable without Supabase:
//   - estimateFoodDeduction()          → tested here
//   - applyReferralCouponFundingOffsets() → tested in wallet_service_referral_coupon_funding_test.dart
//
// Instance methods (deductCommission, topUpWallet, canAcceptJob, getDriverWallet)
// all access Supabase.instance.client directly and require a live Supabase
// instance. Integration test stubs are included below for documentation.

import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/services/wallet_service.dart';

void main() {
  // ──────────────────────────────────────────────
  // estimateFoodDeduction (static, no Supabase)
  // ──────────────────────────────────────────────
  group('WalletService.estimateFoodDeduction', () {
    test('standard rates: ceil(delivery*0.15) + ceil(food*0.10)', () {
      // ceil(30 * 0.15) = ceil(4.5) = 5
      // ceil(100 * 0.10) = 10
      // total = 15
      expect(
        WalletService.estimateFoodDeduction(
          deliveryFee: 30,
          foodPrice: 100,
          deliverySystemRate: 0.15,
          merchantGpSystemRate: 0.10,
        ),
        15,
      );
    });

    test('falls back to platformFeeRate / merchantGpRate when specific rates omitted', () {
      // Same math using the legacy parameter names
      expect(
        WalletService.estimateFoodDeduction(
          deliveryFee: 30,
          foodPrice: 100,
          platformFeeRate: 0.15,
          merchantGpRate: 0.10,
        ),
        15,
      );
    });

    test('uses hardcoded defaults (15%/10%) when no rates provided', () {
      // ceil(40 * 0.15) = 6, ceil(200 * 0.10) = 20 → 26
      expect(
        WalletService.estimateFoodDeduction(
          deliveryFee: 40,
          foodPrice: 200,
        ),
        26,
      );
    });

    test('zero food price yields only delivery system fee', () {
      // ceil(40 * 0.15) = 6
      expect(
        WalletService.estimateFoodDeduction(
          deliveryFee: 40,
          foodPrice: 0,
          deliverySystemRate: 0.15,
          merchantGpSystemRate: 0.10,
        ),
        6,
      );
    });

    test('zero delivery fee yields only merchant system GP', () {
      // ceil(100 * 0.10) = 10
      expect(
        WalletService.estimateFoodDeduction(
          deliveryFee: 0,
          foodPrice: 100,
          deliverySystemRate: 0.15,
          merchantGpSystemRate: 0.10,
        ),
        10,
      );
    });

    test('merchantGpDriverRate does NOT affect wallet deduction estimate', () {
      // appEarnings = deliverySystemFee + merchantSystemGP only
      // merchantDriverGP is paid to driver, not deducted from wallet
      final with0 = WalletService.estimateFoodDeduction(
        deliveryFee: 30,
        foodPrice: 100,
        deliverySystemRate: 0.15,
        merchantGpSystemRate: 0.10,
        merchantGpDriverRate: 0.0,
      );
      final with5pct = WalletService.estimateFoodDeduction(
        deliveryFee: 30,
        foodPrice: 100,
        deliverySystemRate: 0.15,
        merchantGpSystemRate: 0.10,
        merchantGpDriverRate: 0.05,
      );
      expect(with0, with5pct);
    });

    test('result is idempotent — same inputs always produce same output', () {
      const fee = 55.0;
      const food = 180.0;

      final a = WalletService.estimateFoodDeduction(
        deliveryFee: fee,
        foodPrice: food,
        deliverySystemRate: 0.15,
        merchantGpSystemRate: 0.10,
      );
      final b = WalletService.estimateFoodDeduction(
        deliveryFee: fee,
        foodPrice: food,
        deliverySystemRate: 0.15,
        merchantGpSystemRate: 0.10,
      );
      expect(a, b);
    });

    test('ceil ensures driver is never under-charged for fractional amounts', () {
      // 33 * 0.15 = 4.95 → ceil = 5
      // 99 * 0.10 = 9.9  → ceil = 10
      // total = 15
      expect(
        WalletService.estimateFoodDeduction(
          deliveryFee: 33,
          foodPrice: 99,
          deliverySystemRate: 0.15,
          merchantGpSystemRate: 0.10,
        ),
        15,
      );
    });
  });

  // ──────────────────────────────────────────────
  // Referral coupon funding offsets (cross-reference)
  // Full coverage in test/wallet_service_referral_coupon_funding_test.dart
  // ──────────────────────────────────────────────
  group('WalletService.applyReferralCouponFundingOffsets (spot checks)', () {
    test('outputs remain non-negative after large coupon', () {
      final result = WalletService.applyReferralCouponFundingOffsets(
        totalDeduction: 5,
        appEarnings: 5,
        driverNetIncome: 10,
        couponCode: 'WELCOME20',
        couponDiscountAmount: 1000,
      );
      expect(result['totalDeduction']! >= 0, isTrue);
      expect(result['appEarnings']! >= 0, isTrue);
      expect(result['driverNetIncome']! >= 0, isTrue);
    });

    test('non-referral coupon leaves all values unchanged', () {
      final result = WalletService.applyReferralCouponFundingOffsets(
        totalDeduction: 15,
        appEarnings: 15,
        driverNetIncome: 25,
        couponCode: 'DISCOUNT10',
        couponDiscountAmount: 10,
      );
      expect(result['totalDeduction'], 15);
      expect(result['appEarnings'], 15);
      expect(result['driverNetIncome'], 25);
    });
  });

  // ──────────────────────────────────────────────
  // Integration test stubs (require live Supabase)
  // ──────────────────────────────────────────────
  //
  // These cannot be run without a test Supabase project because WalletService
  // initializes _supabase = Supabase.instance.client in the constructor.
  //
  // To enable:
  //   1. Extract Supabase client as a constructor parameter (dependency injection)
  //   2. Use a mock or test Supabase instance
  //
  // group('WalletService integration (requires Supabase)', () {
  //   late WalletService service;
  //
  //   setUp(() async {
  //     await Supabase.initialize(url: testUrl, anonKey: testAnonKey);
  //     service = WalletService();
  //   });
  //
  //   test('deductCommission reduces wallet balance by commission', () async {
  //     const driverId = 'test-driver-id';
  //     const jobPrice = 100;
  //     final before = await service.getBalance(driverId);
  //     await service.deductCommission(driverId: driverId, jobPrice: jobPrice, bookingId: 'test-booking');
  //     final after = await service.getBalance(driverId);
  //     expect(after, before - 15); // 15% default commission
  //   });
  //
  //   test('topUpWallet increases wallet balance', () async {
  //     const driverId = 'test-driver-id';
  //     const topUpAmount = 100.0;
  //     final before = await service.getBalance(driverId);
  //     final success = await service.topUpWallet(driverId: driverId, amount: topUpAmount);
  //     expect(success, isTrue);
  //     final after = await service.getBalance(driverId);
  //     expect(after, before + topUpAmount);
  //   });
  //
  //   test('wallet_deduct RPC is idempotent for same booking_id', () async {
  //     // Calling deductCommission twice with the same bookingId should only
  //     // deduct once (DB-level idempotency via wallet_deduct RPC).
  //     const driverId = 'test-driver-id';
  //     const bookingId = 'idempotency-test-booking';
  //     final before = await service.getBalance(driverId);
  //     await service.deductCommission(driverId: driverId, jobPrice: 100, bookingId: bookingId);
  //     await service.deductCommission(driverId: driverId, jobPrice: 100, bookingId: bookingId);
  //     final after = await service.getBalance(driverId);
  //     expect(after, before - 15); // deducted only once
  //   });
  // });
}
