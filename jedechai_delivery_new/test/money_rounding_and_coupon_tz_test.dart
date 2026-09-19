import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/models/coupon.dart';
import 'package:jedechai_delivery_new/common/utils/role_amount_calculator.dart';

void main() {
  group('RoleAmountCalculator rounding (P1/P2)', () {
    test('ceilBaht rounds money up to whole baht', () {
      expect(RoleAmountCalculator.ceilBaht(5.49), 6);
      expect(RoleAmountCalculator.ceilBaht(20), 20);
      expect(RoleAmountCalculator.ceilBaht(20.000000001), 20);
      expect(RoleAmountCalculator.ceilBaht(0), 0);
      expect(RoleAmountCalculator.ceilBaht(-3), 0);
    });

    test('customer total and driver collect show the same baht', () {
      const food = 110.0, fee = 5.49, discount = 0.0;
      final customer = RoleAmountCalculator.customerPayableTotal(
          foodPrice: food, deliveryFee: fee, couponDiscountAmount: discount);
      final driver = RoleAmountCalculator.driverCashToCollect(
          foodPrice: food, deliveryFee: fee, couponDiscountAmount: discount);
      expect(RoleAmountCalculator.formatBahtCeil(customer),
          RoleAmountCalculator.formatBahtCeil(driver));
      expect(RoleAmountCalculator.formatBahtCeil(customer), '฿116');
    });

    test('formatMoney matches wallet balance (no silent rounding)', () {
      expect(RoleAmountCalculator.formatMoney(16), '16');
      expect(RoleAmountCalculator.formatMoney(15.5), '15.50');
      expect(RoleAmountCalculator.formatMoney(9.999), '10');
    });

    test('order screens do not round money ad-hoc (regression guard)', () {
      const files = [
        'lib/apps/driver/screens/driver_dashboard_screen.dart',
        'lib/apps/customer/screens/services/customer_order_detail_screen.dart',
        'lib/apps/customer/screens/activity_screen.dart',
        'lib/apps/merchant/screens/order_detail_screen.dart',
      ];
      final moneyFixed0 = RegExp(
          r'(Collect|Price|Fee|Discount|Amount|Earnings|price|fee|discount|amount|earnings|total|Total)\w*\)?\.toStringAsFixed\(0\)');
      final rawCeil = RegExp(r"\$\{[A-Za-z_][\w.!]*(\([\w]*\))?\.ceil\(\)\}");
      // ยอดเงินที่คำนวณแบบ (…)*(…) แล้วปัดเอง เช่น item price × quantity
      final exprFixed0 = RegExp(r"\)\)\.toStringAsFixed\(0\)\}");
      for (final path in files) {
        final src = File(path).readAsStringSync();
        expect(moneyFixed0.hasMatch(src), isFalse, reason: path);
        expect(rawCeil.hasMatch(src), isFalse, reason: path);
        expect(exprFixed0.hasMatch(src), isFalse, reason: path);
      }
    });
  });

  group('Coupon validity uses real instants (C4)', () {
    Coupon build(DateTime start, DateTime end) => Coupon.fromJson({
          'id': 'c1',
          'code': 'T',
          'name': 'T',
          'discount_type': 'fixed',
          'discount_value': 10,
          'is_active': true,
          'created_at': '2026-01-01T00:00:00Z',
          'start_date': start.toUtc().toIso8601String(),
          'end_date': end.toUtc().toIso8601String(),
        });

    test('coupon started 1 hour ago is valid (was invalid for 7h before)', () {
      final now = DateTime.now().toUtc();
      final c = build(now.subtract(const Duration(hours: 1)),
          now.add(const Duration(days: 1)));
      expect(c.isValid, isTrue);
    });

    test('coupon ended 1 hour ago is expired (was still valid for 7h)', () {
      final now = DateTime.now().toUtc();
      final c = build(now.subtract(const Duration(days: 1)),
          now.subtract(const Duration(hours: 1)));
      expect(c.isValid, isFalse);
      expect(c.isExpired, isTrue);
    });
  });
}
