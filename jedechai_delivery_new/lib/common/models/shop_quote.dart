/// ผลการคำนวณราคาจาก server (RPC `shop_quote`)
///
/// **แอปห้ามคำนวณราคาเอง** ทุกบรรทัดที่ลูกค้าเห็นต้องมาจากที่นี่
/// ตอนกดยืนยันจริง `create_shop_booking` จะคำนวณซ้ำอีกครั้ง
/// ถ้าต่างจากนี้ต้องแสดงราคาใหม่ให้ลูกค้ายืนยันอีกครั้ง
class ShopQuote {
  final bool ok;

  /// error code จาก server เมื่อ ok = false
  /// shop_disabled | store_not_found | store_closed | budget_below_min |
  /// budget_above_max | no_driver_available
  final String? error;
  final DateTime? nextOpenAt;
  final double? minBudget;
  final double? maxBudget;

  final double budgetCap;
  final double distanceKm;
  final double deliveryFee;
  final double serviceFee;
  final double farPickupFee;
  final double totalFees;
  final double holdAmount;

  final double walletBalance;
  final bool sufficient;
  final double shortfall;

  /// ค่าปรับถ้ายกเลิกหลังคนขับถึงร้านแล้ว — แสดงเป็นจำนวนเงินจริงในคำเตือน
  final double cancelFeeIfShopping;

  final bool hasDriver;
  final double? nearestDriverKm;
  final int driverCountInRadius;
  final bool driverOutsideRadius;

  final DateTime? quotedAt;
  final int quoteTtlSec;

  const ShopQuote({
    required this.ok,
    this.error,
    this.nextOpenAt,
    this.minBudget,
    this.maxBudget,
    this.budgetCap = 0,
    this.distanceKm = 0,
    this.deliveryFee = 0,
    this.serviceFee = 0,
    this.farPickupFee = 0,
    this.totalFees = 0,
    this.holdAmount = 0,
    this.walletBalance = 0,
    this.sufficient = false,
    this.shortfall = 0,
    this.cancelFeeIfShopping = 0,
    this.hasDriver = false,
    this.nearestDriverKm,
    this.driverCountInRadius = 0,
    this.driverOutsideRadius = false,
    this.quotedAt,
    this.quoteTtlSec = 120,
  });

  /// ราคาหมดอายุหรือยัง — หมดแล้วต้องขอใหม่ก่อนยืนยัน
  bool get isExpired {
    final at = quotedAt;
    if (at == null) return false;
    return DateTime.now().difference(at).inSeconds > quoteTtlSec;
  }

  factory ShopQuote.fromJson(Map<String, dynamic> json) {
    final ok = json['ok'] == true;
    if (!ok) {
      return ShopQuote(
        ok: false,
        error: json['error'] as String?,
        nextOpenAt: _toDate(json['next_open_at']),
        minBudget: _toDouble(json['min_budget']),
        maxBudget: _toDouble(json['max_budget']),
      );
    }

    final driver = (json['driver'] as Map?)?.cast<String, dynamic>() ?? const {};

    return ShopQuote(
      ok: true,
      budgetCap: _toDouble(json['budget_cap']) ?? 0,
      distanceKm: _toDouble(json['distance_km']) ?? 0,
      deliveryFee: _toDouble(json['delivery_fee']) ?? 0,
      serviceFee: _toDouble(json['service_fee']) ?? 0,
      farPickupFee: _toDouble(json['far_pickup_fee']) ?? 0,
      totalFees: _toDouble(json['total_fees']) ?? 0,
      holdAmount: _toDouble(json['hold_amount']) ?? 0,
      walletBalance: _toDouble(json['wallet_balance']) ?? 0,
      sufficient: json['sufficient'] == true,
      shortfall: _toDouble(json['shortfall']) ?? 0,
      cancelFeeIfShopping: _toDouble(json['cancel_fee_if_shopping']) ?? 0,
      hasDriver: driver['has_driver'] == true,
      nearestDriverKm: _toDouble(driver['nearest_km']),
      driverCountInRadius:
          (_toDouble(driver['driver_count_in_radius']) ?? 0).round(),
      driverOutsideRadius: driver['is_outside_radius'] == true,
      quotedAt: _toDate(json['quoted_at']) ?? DateTime.now(),
      quoteTtlSec: (_toDouble(json['quote_ttl_sec']) ?? 120).round(),
    );
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static DateTime? _toDate(dynamic v) {
    if (v == null) return null;
    return DateTime.tryParse(v.toString())?.toLocal();
  }
}
