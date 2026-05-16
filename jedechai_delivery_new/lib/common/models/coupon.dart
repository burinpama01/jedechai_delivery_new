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
  final String? discountBase; // 'subtotal' | 'delivery_fee'
  final String? stackingGroup;
  final String? fundingSource; // platform, merchant, driver, split
  final String? distributionType; // code_only, claimable, auto_grant
  final int? claimLimit;
  final int? claimLimitPerUser;
  final int? currentClaims;
  final int usageLimit; // Total times this coupon can be used (0=unlimited)
  final int usedCount; // How many times it has been used
  final int perUserLimit; // Times a single user can use it (0=unlimited)
  final bool isActive;
  final bool isSystemCoupon; // true for system-issued coupons (WELCOME20, REFERRER20, etc.)
  final String createdByRole; // 'admin' | 'merchant'
  final double merchantGpChargeRate; // default 0.25 for merchant free-delivery coupon
  final double merchantGpSystemRate; // default from system config (commonly 0.10)
  final double merchantGpDriverRate; // default 0.15
  final DateTime? startDate;
  final DateTime? endDate;
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
    this.discountBase,
    this.stackingGroup,
    this.fundingSource,
    this.distributionType,
    this.claimLimit,
    this.claimLimitPerUser,
    this.currentClaims,
    this.usageLimit = 0,
    this.usedCount = 0,
    this.perUserLimit = 1,
    this.isActive = true,
    this.isSystemCoupon = false,
    this.createdByRole = 'admin',
    this.merchantGpChargeRate = 0.0,
    this.merchantGpSystemRate = 0.0,
    this.merchantGpDriverRate = 0.0,
    this.startDate,
    this.endDate,
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
      discountBase: json['discount_base'] as String?,
      stackingGroup: json['stacking_group'] as String?,
      fundingSource: json['funding_source'] as String?,
      distributionType: json['distribution_type'] as String?,
      claimLimit: json['claim_limit'] as int?,
      claimLimitPerUser: json['claim_limit_per_user'] as int?,
      currentClaims: json['current_claims'] as int?,
      usageLimit: json['usage_limit'] as int? ?? 0,
      usedCount: json['used_count'] as int? ?? 0,
      perUserLimit: json['per_user_limit'] as int? ?? 1,
      isActive: json['is_active'] as bool? ?? true,
      isSystemCoupon: json['is_system_coupon'] as bool? ?? false,
      createdByRole: json['created_by_role'] as String? ?? 'admin',
      merchantGpChargeRate: (json['merchant_gp_charge_rate'] as num?)?.toDouble() ?? 0.0,
      merchantGpSystemRate: (json['merchant_gp_system_rate'] as num?)?.toDouble() ?? 0.0,
      merchantGpDriverRate: (json['merchant_gp_driver_rate'] as num?)?.toDouble() ?? 0.0,
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date'] as String) : null,
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date'] as String) : null,
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
      'discount_base': discountBase,
      'stacking_group': stackingGroup,
      'funding_source': fundingSource,
      'distribution_type': distributionType,
      'claim_limit': claimLimit,
      'claim_limit_per_user': claimLimitPerUser,
      'current_claims': currentClaims,
      'usage_limit': usageLimit,
      'used_count': usedCount,
      'per_user_limit': perUserLimit,
      'is_active': isActive,
      'is_system_coupon': isSystemCoupon,
      'created_by_role': createdByRole,
      'merchant_gp_charge_rate': merchantGpChargeRate,
      'merchant_gp_system_rate': merchantGpSystemRate,
      'merchant_gp_driver_rate': merchantGpDriverRate,
      'start_date': startDate?.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }

  static const _systemCouponCodes = {'WELCOME20', 'REFERRER20'};

  static bool isSystemCouponCode(String? code) =>
      _systemCouponCodes.contains(code?.trim().toUpperCase());

  /// Bangkok time (UTC+7) for server-aligned date validation.
  static DateTime _bangkokNow() =>
      DateTime.now().toUtc().add(const Duration(hours: 7));

  /// Check if coupon is currently valid (active + within date range).
  /// Uses Bangkok time to match server-side schedule.
  bool get isValid {
    final now = _bangkokNow();
    return isActive &&
        (startDate == null || now.isAfter(startDate!)) &&
        (endDate == null || now.isBefore(endDate!)) &&
        (usageLimit == 0 || usedCount < usageLimit);
  }

  /// Check if coupon has expired (Bangkok time). Returns false if no end date set.
  bool get isExpired => endDate != null && _bangkokNow().isAfter(endDate!);

  /// Check if coupon has reached its usage limit
  bool get isUsedUp => usageLimit > 0 && usedCount >= usageLimit;

  /// Calculate discount amount for a given order.
  /// Respects [discountBase]: 'delivery_fee' applies percentage/fixed to
  /// delivery fee instead of order subtotal.
  double calculateDiscount(double orderAmount, {double deliveryFee = 0}) {
    if (!isValid) return 0;

    // Check minimum order amount
    if (minOrderAmount != null && orderAmount < minOrderAmount!) return 0;

    final base = discountBase == 'delivery_fee' ? deliveryFee : orderAmount;

    double discount;
    switch (discountType) {
      case 'percentage':
        discount = base * (discountValue / 100);
        if (maxDiscountAmount != null && discount > maxDiscountAmount!) {
          discount = maxDiscountAmount!;
        }
        break;
      case 'fixed':
        discount = discountValue;
        if (discount > base) discount = base;
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
