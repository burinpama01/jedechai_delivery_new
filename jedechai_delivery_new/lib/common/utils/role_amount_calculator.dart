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
    final gross =
        customerGrossTotal(foodPrice: foodPrice, deliveryFee: deliveryFee);
    final discount = couponDiscountAmount < 0 ? 0 : couponDiscountAmount;
    final payable = gross - discount;
    return payable < 0 ? 0 : payable;
  }

  static double displayTotalForService({
    required String serviceType,
    required double price,
    double? deliveryFee,
  }) {
    final safePrice = clampNonNegative(price);
    if (serviceType == 'food') {
      return safePrice + clampNonNegative(deliveryFee ?? 0);
    }
    return safePrice;
  }

  static double netDisplayTotalForService({
    required String serviceType,
    required double price,
    double? deliveryFee,
    required double couponDiscountAmount,
  }) {
    final gross = displayTotalForService(
      serviceType: serviceType,
      price: price,
      deliveryFee: deliveryFee,
    );
    final discount = couponDiscountAmount < 0 ? 0 : couponDiscountAmount;
    final net = gross - discount;
    return net < 0 ? 0 : net;
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

  /// ISSUE-121: clamp เรตทั้งสองด้านเหมือน DriverAmountCalculator._clampRate
  /// ถ้าแอดมินกรอก GP เป็น 30 (ตั้งใจหมายถึง 30%) แทน 0.3 ร้านจะถูกหักเกิน
  /// ยอดขายทั้งก้อนและ merchantReceives กลายเป็น 0
  static double clampRate(double value) {
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  static double merchantGpAmount({
    required double merchantGrossSales,
    required double merchantGpRate,
  }) {
    final rate = clampRate(merchantGpRate);
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
