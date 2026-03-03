import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/services/coupon_service.dart';

void main() {
  group('CouponService.groupWalletCouponRows', () {
    test('groups multiple user_coupons rows into quantity per coupon id (order preserved)', () {
      final rows = <Map<String, dynamic>>[
        {
          'id': 'uc1',
          'coupon': {
            'id': 'c1',
            'code': 'REFERRER20',
            'name': 'Referrer',
            'description': 'Referral reward',
            'discount_type': 'fixed',
            'discount_value': 20,
            'min_order_amount': null,
            'max_discount_amount': null,
            'service_type': 'food',
            'merchant_id': null,
            'discount_base': 'subtotal',
            'stacking_group': null,
            'funding_source': 'platform',
            'distribution_type': 'auto_grant',
            'claim_limit': null,
            'claim_limit_per_user': 10,
            'current_claims': null,
            'usage_limit': 0,
            'used_count': 0,
            'per_user_limit': 1,
            'is_active': true,
            'created_by_role': 'admin',
            'merchant_gp_charge_rate': 0,
            'merchant_gp_system_rate': 0,
            'merchant_gp_driver_rate': 0,
            'start_date': '2026-01-01T00:00:00.000Z',
            'end_date': '2030-01-01T00:00:00.000Z',
            'created_at': '2026-01-01T00:00:00.000Z',
          },
        },
        {
          'id': 'uc2',
          'coupon': {
            'id': 'c1',
            'code': 'REFERRER20',
            'name': 'Referrer',
            'description': 'Referral reward',
            'discount_type': 'fixed',
            'discount_value': 20,
            'min_order_amount': null,
            'max_discount_amount': null,
            'service_type': 'food',
            'merchant_id': null,
            'discount_base': 'subtotal',
            'stacking_group': null,
            'funding_source': 'platform',
            'distribution_type': 'auto_grant',
            'claim_limit': null,
            'claim_limit_per_user': 10,
            'current_claims': null,
            'usage_limit': 0,
            'used_count': 0,
            'per_user_limit': 1,
            'is_active': true,
            'created_by_role': 'admin',
            'merchant_gp_charge_rate': 0,
            'merchant_gp_system_rate': 0,
            'merchant_gp_driver_rate': 0,
            'start_date': '2026-01-01T00:00:00.000Z',
            'end_date': '2030-01-01T00:00:00.000Z',
            'created_at': '2026-01-01T00:00:00.000Z',
          },
        },
        {
          'id': 'uc3',
          'coupon': {
            'id': 'c2',
            'code': 'WELCOME20',
            'name': 'Welcome',
            'description': 'Welcome reward',
            'discount_type': 'fixed',
            'discount_value': 20,
            'min_order_amount': null,
            'max_discount_amount': null,
            'service_type': 'food',
            'merchant_id': null,
            'discount_base': 'subtotal',
            'stacking_group': null,
            'funding_source': 'platform',
            'distribution_type': 'auto_grant',
            'claim_limit': null,
            'claim_limit_per_user': 10,
            'current_claims': null,
            'usage_limit': 0,
            'used_count': 0,
            'per_user_limit': 1,
            'is_active': true,
            'created_by_role': 'admin',
            'merchant_gp_charge_rate': 0,
            'merchant_gp_system_rate': 0,
            'merchant_gp_driver_rate': 0,
            'start_date': '2026-01-01T00:00:00.000Z',
            'end_date': '2030-01-01T00:00:00.000Z',
            'created_at': '2026-01-01T00:00:00.000Z',
          },
        },
      ];

      final grouped = CouponService.groupWalletCouponRows(rows);

      expect(grouped.length, 2);
      expect(grouped[0].coupon.id, 'c1');
      expect(grouped[0].quantity, 2);
      expect(grouped[1].coupon.id, 'c2');
      expect(grouped[1].quantity, 1);
    });

    test('filters by serviceType/merchantId consistent with wallet list', () {
      final rows = <Map<String, dynamic>>[
        {
          'id': 'uc1',
          'coupon': {
            'id': 'c1',
            'code': 'FOOD10',
            'name': 'Food',
            'description': null,
            'discount_type': 'fixed',
            'discount_value': 10,
            'min_order_amount': null,
            'max_discount_amount': null,
            'service_type': 'food',
            'merchant_id': null,
            'discount_base': 'subtotal',
            'stacking_group': null,
            'funding_source': 'platform',
            'distribution_type': 'code_only',
            'claim_limit': null,
            'claim_limit_per_user': 10,
            'current_claims': null,
            'usage_limit': 0,
            'used_count': 0,
            'per_user_limit': 1,
            'is_active': true,
            'created_by_role': 'admin',
            'merchant_gp_charge_rate': 0,
            'merchant_gp_system_rate': 0,
            'merchant_gp_driver_rate': 0,
            'start_date': '2026-01-01T00:00:00.000Z',
            'end_date': '2030-01-01T00:00:00.000Z',
            'created_at': '2026-01-01T00:00:00.000Z',
          },
        },
        {
          'id': 'uc2',
          'coupon': {
            'id': 'c2',
            'code': 'RIDE10',
            'name': 'Ride',
            'description': null,
            'discount_type': 'fixed',
            'discount_value': 10,
            'min_order_amount': null,
            'max_discount_amount': null,
            'service_type': 'ride',
            'merchant_id': null,
            'discount_base': 'subtotal',
            'stacking_group': null,
            'funding_source': 'platform',
            'distribution_type': 'code_only',
            'claim_limit': null,
            'claim_limit_per_user': 10,
            'current_claims': null,
            'usage_limit': 0,
            'used_count': 0,
            'per_user_limit': 1,
            'is_active': true,
            'created_by_role': 'admin',
            'merchant_gp_charge_rate': 0,
            'merchant_gp_system_rate': 0,
            'merchant_gp_driver_rate': 0,
            'start_date': '2026-01-01T00:00:00.000Z',
            'end_date': '2030-01-01T00:00:00.000Z',
            'created_at': '2026-01-01T00:00:00.000Z',
          },
        },
      ];

      final groupedFood = CouponService.groupWalletCouponRows(rows, serviceType: 'food');
      expect(groupedFood.length, 1);
      expect(groupedFood[0].coupon.code, 'FOOD10');

      final groupedRide = CouponService.groupWalletCouponRows(rows, serviceType: 'ride');
      expect(groupedRide.length, 1);
      expect(groupedRide[0].coupon.code, 'RIDE10');
    });
  });
}
