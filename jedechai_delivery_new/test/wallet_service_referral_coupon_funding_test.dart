import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/services/wallet_service.dart';

void main() {
  group('WalletService.applyReferralCouponFundingOffsets', () {
    test('non-referral coupon does not change amounts', () {
      final res = WalletService.applyReferralCouponFundingOffsets(
        totalDeduction: 13,
        appEarnings: 13,
        driverNetIncome: 17,
        couponCode: 'SAVE10',
        couponDiscountAmount: 20,
      );

      expect(res['totalDeduction'], 13);
      expect(res['appEarnings'], 13);
      expect(res['driverNetIncome'], 17);
      expect(res['couponSystemOffset'], 0);
      expect(res['couponDriverOffset'], 0);
    });

    test('referral coupon discount less than GP system (totalDeduction)', () {
      final res = WalletService.applyReferralCouponFundingOffsets(
        totalDeduction: 13,
        appEarnings: 13,
        driverNetIncome: 17,
        couponCode: 'WELCOME20',
        couponDiscountAmount: 10,
      );

      expect(res['couponSystemOffset'], 10);
      expect(res['couponDriverOffset'], 0);
      expect(res['totalDeduction'], 3);
      expect(res['appEarnings'], 3);
      expect(res['driverNetIncome'], 17);
    });

    test('referral coupon discount equals GP system (totalDeduction)', () {
      final res = WalletService.applyReferralCouponFundingOffsets(
        totalDeduction: 13,
        appEarnings: 13,
        driverNetIncome: 17,
        couponCode: 'REFERRER20',
        couponDiscountAmount: 13,
      );

      expect(res['couponSystemOffset'], 13);
      expect(res['couponDriverOffset'], 0);
      expect(res['totalDeduction'], 0);
      expect(res['appEarnings'], 0);
      expect(res['driverNetIncome'], 17);
    });

    test('referral coupon discount greater than GP system offsets driver net income', () {
      final res = WalletService.applyReferralCouponFundingOffsets(
        totalDeduction: 13,
        appEarnings: 13,
        driverNetIncome: 17,
        couponCode: 'REFFERER20',
        couponDiscountAmount: 20,
      );

      expect(res['couponSystemOffset'], 13);
      expect(res['couponDriverOffset'], 7);
      expect(res['totalDeduction'], 0);
      expect(res['appEarnings'], 0);
      expect(res['driverNetIncome'], 10);
    });

    test('referral coupon discount exceeding driver net income clamps at zero', () {
      final res = WalletService.applyReferralCouponFundingOffsets(
        totalDeduction: 13,
        appEarnings: 13,
        driverNetIncome: 17,
        couponCode: 'WELCOME20',
        couponDiscountAmount: 100,
      );

      expect(res['couponSystemOffset'], 13);
      expect(res['couponDriverOffset'], 17);
      expect(res['totalDeduction'], 0);
      expect(res['appEarnings'], 0);
      expect(res['driverNetIncome'], 0);
    });

    test('coupon code normalization trims and uppercases', () {
      final res = WalletService.applyReferralCouponFundingOffsets(
        totalDeduction: 13,
        appEarnings: 13,
        driverNetIncome: 17,
        couponCode: '  welcome20  ',
        couponDiscountAmount: 10,
      );

      expect(res['couponSystemOffset'], 10);
      expect(res['totalDeduction'], 3);
    });
  });
}
