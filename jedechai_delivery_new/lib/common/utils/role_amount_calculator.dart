class RoleAmountCalculator {
  static double clampNonNegative(double value) => value < 0 ? 0 : value;

  static double customerGrossTotal({
    required double foodPrice,
    required double deliveryFee,
  }) {
    return clampNonNegative(foodPrice) + clampNonNegative(deliveryFee);
  }

  static double customerPayableTotal({
    required double foodPrice,
    required double deliveryFee,
    required double couponDiscountAmount,
  }) {
    final gross = customerGrossTotal(foodPrice: foodPrice, deliveryFee: deliveryFee);
    final discount = couponDiscountAmount < 0 ? 0 : couponDiscountAmount;
    final payable = gross - discount;
    return payable < 0 ? 0 : payable;
  }

  static double driverCashToCollect({
    required double foodPrice,
    required double deliveryFee,
    required double couponDiscountAmount,
  }) {
    // In cash orders, driver should collect what customer actually pays.
    return customerPayableTotal(
      foodPrice: foodPrice,
      deliveryFee: deliveryFee,
      couponDiscountAmount: couponDiscountAmount,
    );
  }

  static double merchantGrossSales({
    required double foodPrice,
    double? couponDiscountAmount,
    bool applyMerchantCreatedDiscount = false,
  }) {
    final gross = clampNonNegative(foodPrice);
    if (!applyMerchantCreatedDiscount) return gross;

    final discount = (couponDiscountAmount ?? 0);
    final safeDiscount = discount < 0 ? 0 : discount;
    final net = gross - safeDiscount;
    return net < 0 ? 0 : net;
  }

  static double merchantGpAmount({
    required double merchantGrossSales,
    required double merchantGpRate,
  }) {
    final rate = merchantGpRate < 0 ? 0 : merchantGpRate;
    final gp = clampNonNegative(merchantGrossSales) * rate;
    return gp < 0 ? 0 : gp;
  }

  static double merchantReceives({
    required double foodPrice,
    required double merchantGpRate,
    double? couponDiscountAmount,
    bool applyMerchantCreatedDiscount = false,
  }) {
    final netSales = merchantGrossSales(
      foodPrice: foodPrice,
      couponDiscountAmount: couponDiscountAmount,
      applyMerchantCreatedDiscount: applyMerchantCreatedDiscount,
    );
    final gp = merchantGpAmount(
      merchantGrossSales: netSales,
      merchantGpRate: merchantGpRate,
    );
    final receives = netSales - gp;
    return receives < 0 ? 0 : receives;
  }
}
