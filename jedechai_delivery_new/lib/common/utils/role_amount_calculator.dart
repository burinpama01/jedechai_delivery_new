class RoleAmountCalculator {
  static double clampNonNegative(double value) => value < 0 ? 0 : value;

  /// จุดปัดเงินเดียวของทั้งแอป (P1): ยอดที่ลูกค้าจ่าย/คนขับเก็บ/ราคา/ค่าส่ง/ส่วนลด
  /// ปัดขึ้นเป็นบาทเต็มเหมือนกันทุกจอ (ลูกค้า คนขับ ร้าน)
  static int ceilBaht(num value) {
    final v = value.toDouble();
    if (v.isNaN || v <= 0) return 0;
    // กันเศษทศนิยมจาก floating point เช่น 20.000000001 → 20
    return (v - 1e-9).ceil();
  }

  /// '฿123' สำหรับยอดเก็บเงิน/ราคา/ค่าส่ง/ส่วนลด (ปัดขึ้น)
  static String formatBahtCeil(num value) => '฿${ceilBaht(value)}';

  /// รายได้/ยอดกระเป๋า (P2): แสดงตรงกับยอดจริงในกระเป๋า
  /// จำนวนเต็มแสดงไม่มีทศนิยม ถ้ามีเศษแสดง 2 ตำแหน่ง
  static String formatMoney(num value) {
    final v = value.toDouble();
    if (v.isNaN) return '0';
    final rounded = (v * 100).roundToDouble() / 100;
    if (rounded == rounded.truncateToDouble()) {
      return rounded.toStringAsFixed(0);
    }
    return rounded.toStringAsFixed(2);
  }

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
