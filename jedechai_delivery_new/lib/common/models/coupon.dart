/// Coupon Model
///
/// Represents a discount coupon/voucher
/// Supports: percentage discount, fixed amount discount, free delivery
class Coupon {
  final String id;
  final String code;
  final String name;
  final String? description;
  final String discountType; // 'percentage', 'fixed', 'free_delivery'
  final double discountValue; // percentage (0-100) or fixed amount (THB)
  final double? minOrderAmount; // Minimum order to use this coupon
  final double? maxDiscountAmount; // Cap for percentage discounts
  final String? serviceType; // null=all, 'food', 'ride', 'parcel'
  final String? merchantId; // null=all merchants, or specific merchant
  final int usageLimit; // Total times this coupon can be used (0=unlimited)
  final int usedCount; // How many times it has been used
  final int perUserLimit; // Times a single user can use it (0=unlimited)
  final bool isActive;
  final String createdByRole; // 'admin' | 'merchant'
  final double merchantGpChargeRate; // default 0.25 for merchant free-delivery coupon
  final double merchantGpSystemRate; // default from system config (commonly 0.10)
  final double merchantGpDriverRate; // default 0.15
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;

  const Coupon({
    required this.id,
    required this.code,
    required this.name,
    this.description,
    required this.discountType,
    required this.discountValue,
    this.minOrderAmount,
    this.maxDiscountAmount,
    this.serviceType,
    this.merchantId,
    this.usageLimit = 0,
    this.usedCount = 0,
    this.perUserLimit = 1,
    this.isActive = true,
    this.createdByRole = 'admin',
    this.merchantGpChargeRate = 0.0,
    this.merchantGpSystemRate = 0.0,
    this.merchantGpDriverRate = 0.0,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
  });

  factory Coupon.fromJson(Map<String, dynamic> json) {
    return Coupon(
      id: json['id'] as String,
      code: json['code'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      discountType: json['discount_type'] as String,
      discountValue: (json['discount_value'] as num).toDouble(),
      minOrderAmount: json['min_order_amount'] != null
          ? (json['min_order_amount'] as num).toDouble()
          : null,
      maxDiscountAmount: json['max_discount_amount'] != null
          ? (json['max_discount_amount'] as num).toDouble()
          : null,
      serviceType: json['service_type'] as String?,
      merchantId: json['merchant_id'] as String?,
      usageLimit: json['usage_limit'] as int? ?? 0,
      usedCount: json['used_count'] as int? ?? 0,
      perUserLimit: json['per_user_limit'] as int? ?? 1,
      isActive: json['is_active'] as bool? ?? true,
      createdByRole: json['created_by_role'] as String? ?? 'admin',
      merchantGpChargeRate: (json['merchant_gp_charge_rate'] as num?)?.toDouble() ?? 0.0,
      merchantGpSystemRate: (json['merchant_gp_system_rate'] as num?)?.toDouble() ?? 0.0,
      merchantGpDriverRate: (json['merchant_gp_driver_rate'] as num?)?.toDouble() ?? 0.0,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'description': description,
      'discount_type': discountType,
      'discount_value': discountValue,
      'min_order_amount': minOrderAmount,
      'max_discount_amount': maxDiscountAmount,
      'service_type': serviceType,
      'merchant_id': merchantId,
      'usage_limit': usageLimit,
      'used_count': usedCount,
      'per_user_limit': perUserLimit,
      'is_active': isActive,
      'created_by_role': createdByRole,
      'merchant_gp_charge_rate': merchantGpChargeRate,
      'merchant_gp_system_rate': merchantGpSystemRate,
      'merchant_gp_driver_rate': merchantGpDriverRate,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Check if coupon is currently valid (active + within date range)
  bool get isValid {
    final now = DateTime.now();
    return isActive &&
        now.isAfter(startDate) &&
        now.isBefore(endDate) &&
        (usageLimit == 0 || usedCount < usageLimit);
  }

  /// Check if coupon has expired
  bool get isExpired => DateTime.now().isAfter(endDate);

  /// Check if coupon has reached its usage limit
  bool get isUsedUp => usageLimit > 0 && usedCount >= usageLimit;

  /// Calculate discount amount for a given order
  double calculateDiscount(double orderAmount, {double deliveryFee = 0}) {
    if (!isValid) return 0;

    // Check minimum order amount
    if (minOrderAmount != null && orderAmount < minOrderAmount!) return 0;

    double discount;
    switch (discountType) {
      case 'percentage':
        discount = orderAmount * (discountValue / 100);
        // Apply max discount cap
        if (maxDiscountAmount != null && discount > maxDiscountAmount!) {
          discount = maxDiscountAmount!;
        }
        break;
      case 'fixed':
        discount = discountValue;
        // Don't exceed order amount
        if (discount > orderAmount) discount = orderAmount;
        break;
      case 'free_delivery':
        discount = deliveryFee;
        break;
      default:
        discount = 0;
    }

    return discount;
  }

  /// Human-readable discount text
  String get discountText {
    switch (discountType) {
      case 'percentage':
        final cap = maxDiscountAmount != null
            ? ' (สูงสุด ฿${maxDiscountAmount!.toStringAsFixed(0)})'
            : '';
        return 'ลด ${discountValue.toStringAsFixed(0)}%$cap';
      case 'fixed':
        return 'ลด ฿${discountValue.toStringAsFixed(0)}';
      case 'free_delivery':
        return 'ส่งฟรี';
      default:
        return 'ส่วนลด';
    }
  }

  @override
  String toString() => 'Coupon(code: $code, $discountText)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Coupon && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
