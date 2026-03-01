import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/utils/role_amount_calculator.dart';

void main() {
  group('RoleAmountCalculator - customer', () {
    test('customerGrossTotal = foodPrice + deliveryFee', () {
      expect(
        RoleAmountCalculator.customerGrossTotal(foodPrice: 100, deliveryFee: 20),
        120,
      );
    });

    test('customerPayableTotal subtracts coupon discount and clamps at 0', () {
      expect(
        RoleAmountCalculator.customerPayableTotal(
          foodPrice: 100,
          deliveryFee: 20,
          couponDiscountAmount: 10,
        ),
        110,
      );

      expect(
        RoleAmountCalculator.customerPayableTotal(
          foodPrice: 100,
          deliveryFee: 20,
          couponDiscountAmount: 999,
        ),
        0,
      );
    });

    test('negative couponDiscountAmount is treated as 0', () {
      expect(
        RoleAmountCalculator.customerPayableTotal(
          foodPrice: 100,
          deliveryFee: 20,
          couponDiscountAmount: -10,
        ),
        120,
      );
    });
  });

  group('RoleAmountCalculator - driver', () {
    test('driverCashToCollect equals customerPayableTotal', () {
      final customerPays = RoleAmountCalculator.customerPayableTotal(
        foodPrice: 100,
        deliveryFee: 20,
        couponDiscountAmount: 10,
      );
      final driverCollects = RoleAmountCalculator.driverCashToCollect(
        foodPrice: 100,
        deliveryFee: 20,
        couponDiscountAmount: 10,
      );

      expect(driverCollects, customerPays);
      expect(driverCollects, 110);
    });
  });

  group('RoleAmountCalculator - merchant', () {
    test('merchantGrossSales ignores delivery fee (merchant should not see delivery fee)', () {
      // Delivery fee is intentionally not part of merchant gross sales.
      expect(
        RoleAmountCalculator.merchantGrossSales(
          foodPrice: 100,
          couponDiscountAmount: 20,
          applyMerchantCreatedDiscount: false,
        ),
        100,
      );
    });

    test('merchantGrossSales applies discount only when coupon is merchant-created', () {
      // Not merchant-created discount: merchant sees full food price
      expect(
        RoleAmountCalculator.merchantGrossSales(
          foodPrice: 100,
          couponDiscountAmount: 20,
          applyMerchantCreatedDiscount: false,
        ),
        100,
      );

      // Merchant-created discount: merchant net sales reduced
      expect(
        RoleAmountCalculator.merchantGrossSales(
          foodPrice: 100,
          couponDiscountAmount: 20,
          applyMerchantCreatedDiscount: true,
        ),
        80,
      );
    });

    test('merchantReceives deducts GP from merchant net sales and clamps at 0', () {
      // foodPrice 100, merchant discount 20 => netSales 80
      // GP rate 10% => GP 8
      // receives = 72
      expect(
        RoleAmountCalculator.merchantReceives(
          foodPrice: 100,
          merchantGpRate: 0.10,
          couponDiscountAmount: 20,
          applyMerchantCreatedDiscount: true,
        ),
        closeTo(72, 0.0001),
      );

      // If discount is huge, clamp to 0
      expect(
        RoleAmountCalculator.merchantReceives(
          foodPrice: 100,
          merchantGpRate: 0.10,
          couponDiscountAmount: 999,
          applyMerchantCreatedDiscount: true,
        ),
        0,
      );
    });
  });
}
