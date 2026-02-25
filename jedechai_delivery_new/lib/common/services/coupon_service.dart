import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/debug_logger.dart';
import '../models/coupon.dart';
import 'auth_service.dart';

/// Coupon Service
///
/// Handles coupon validation, redemption, and management
/// Tables: coupons, coupon_usages
class CouponService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Validate a coupon code for a specific order
  ///
  /// Returns the Coupon if valid, or throws an Exception with a Thai error message
  Future<Coupon> validateCoupon({
    required String code,
    required String serviceType,
    required double orderAmount,
    String? merchantId,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) throw Exception('กรุณาเข้าสู่ระบบ');

    // Phase 6: Validate coupon code format before querying DB
    final trimmedCode = code.trim().toUpperCase();
    if (trimmedCode.isEmpty || trimmedCode.length > 20) {
      throw Exception('รหัสโค้ดส่วนลดไม่ถูกต้อง (ต้องไม่เกิน 20 ตัวอักษร)');
    }
    if (!RegExp(r'^[A-Z0-9_-]+$').hasMatch(trimmedCode)) {
      throw Exception('รหัสโค้ดส่วนลดต้องเป็นตัวอักษรภาษาอังกฤษหรือตัวเลขเท่านั้น');
    }

    try {
      // Find coupon by code
      final response = await _client
          .from('coupons')
          .select()
          .eq('code', trimmedCode)
          .eq('is_active', true)
          .maybeSingle();

      if (response == null) {
        throw Exception('ไม่พบโค้ดส่วนลดนี้');
      }

      final coupon = Coupon.fromJson(response);

      // Check if expired
      if (coupon.isExpired) {
        throw Exception('โค้ดส่วนลดนี้หมดอายุแล้ว');
      }

      // Check if used up
      if (coupon.isUsedUp) {
        throw Exception('โค้ดส่วนลดนี้ถูกใช้ครบจำนวนแล้ว');
      }

      // Check date range
      if (!coupon.isValid) {
        throw Exception('โค้ดส่วนลดนี้ยังไม่สามารถใช้ได้ในขณะนี้');
      }

      // Check service type
      if (coupon.serviceType != null && coupon.serviceType != serviceType) {
        final serviceLabel = _serviceLabel(coupon.serviceType!);
        throw Exception('โค้ดนี้ใช้ได้เฉพาะบริการ$serviceLabel');
      }

      // Check merchant — Phase 5A fix: if coupon is merchant-specific,
      // the merchantId parameter MUST match (null merchantId = reject)
      if (coupon.merchantId != null) {
        if (merchantId == null || coupon.merchantId != merchantId) {
          throw Exception('โค้ดนี้ใช้ได้เฉพาะร้านค้าที่กำหนดเท่านั้น');
        }
      }

      // Check minimum order
      if (coupon.minOrderAmount != null && orderAmount < coupon.minOrderAmount!) {
        throw Exception(
          'ยอดสั่งซื้อขั้นต่ำ ฿${coupon.minOrderAmount!.toStringAsFixed(0)}',
        );
      }

      // Check per-user limit
      if (coupon.perUserLimit > 0) {
        final usageCount = await _getUserUsageCount(coupon.id, userId);
        if (usageCount >= coupon.perUserLimit) {
          throw Exception('คุณใช้โค้ดนี้ครบจำนวนที่กำหนดแล้ว');
        }
      }

      debugLog('✅ Coupon validated: ${coupon.code} → ${coupon.discountText}');
      return coupon;
    } on Exception {
      rethrow;
    } catch (e) {
      debugLog('❌ Error validating coupon: $e');
      throw Exception('เกิดข้อผิดพลาดในการตรวจสอบโค้ด');
    }
  }

  /// Record coupon usage after successful booking
  Future<void> recordUsage({
    required String couponId,
    required String bookingId,
    required double discountAmount,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) return;

    try {
      // Insert usage record
      await _client.from('coupon_usages').insert({
        'coupon_id': couponId,
        'user_id': userId,
        'booking_id': bookingId,
        'discount_amount': discountAmount,
      });

      // Increment used_count on coupon
      await _client.rpc('increment_coupon_usage', params: {
        'coupon_id_param': couponId,
      });

      debugLog('✅ Recorded coupon usage: $couponId for booking: $bookingId');
    } catch (e) {
      debugLog('❌ Error recording coupon usage: $e');
      // Phase 5A fix: Make this CRITICAL — if usage recording fails,
      // the coupon can be reused beyond its limit.
      rethrow;
    }
  }

  /// Get user's usage count for a specific coupon
  Future<int> _getUserUsageCount(String couponId, String userId) async {
    try {
      final response = await _client
          .from('coupon_usages')
          .select()
          .eq('coupon_id', couponId)
          .eq('user_id', userId);

      return (response as List).length;
    } catch (e) {
      // Phase 5A fix: throw on error instead of returning 0,
      // which would bypass per-user limit checks
      debugLog('❌ Error fetching coupon usage count: $e');
      throw Exception('ไม่สามารถตรวจสอบการใช้งานโค้ดส่วนลดได้ กรุณาลองใหม่');
    }
  }

  /// Get available coupons for a user (for coupon list screen)
  Future<List<Coupon>> getAvailableCoupons({
    String? serviceType,
    String? merchantId,
  }) async {
    try {
      var query = _client
          .from('coupons')
          .select()
          .eq('is_active', true)
          .lte('start_date', DateTime.now().toIso8601String())
          .gte('end_date', DateTime.now().toIso8601String());

      final response = await query.order('created_at', ascending: false);

      final coupons = (response as List)
          .map((json) => Coupon.fromJson(json))
          .where((c) => c.isValid)
          .where((c) =>
              serviceType == null ||
              c.serviceType == null ||
              c.serviceType == serviceType)
          .where((c) =>
              merchantId == null ||
              c.merchantId == null ||
              c.merchantId == merchantId)
          .toList();

      return coupons;
    } catch (e) {
      debugLog('❌ Error fetching available coupons: $e');
      return [];
    }
  }

  // ── Admin Methods ──

  /// Create a new coupon (admin only)
  Future<Coupon?> createCoupon({
    required String code,
    required String name,
    String? description,
    required String discountType,
    required double discountValue,
    double? minOrderAmount,
    double? maxDiscountAmount,
    String? serviceType,
    String? merchantId,
    int usageLimit = 0,
    int perUserLimit = 1,
    String createdByRole = 'admin',
    double merchantGpChargeRate = 0,
    double merchantGpSystemRate = 0,
    double merchantGpDriverRate = 0,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final response = await _client
          .from('coupons')
          .insert({
            'code': code.trim().toUpperCase(),
            'name': name,
            'description': description,
            'discount_type': discountType,
            'discount_value': discountValue,
            'min_order_amount': minOrderAmount,
            'max_discount_amount': maxDiscountAmount,
            'service_type': serviceType,
            'merchant_id': merchantId,
            'usage_limit': usageLimit,
            'per_user_limit': perUserLimit,
            'created_by_role': createdByRole,
            'merchant_gp_charge_rate': merchantGpChargeRate,
            'merchant_gp_system_rate': merchantGpSystemRate,
            'merchant_gp_driver_rate': merchantGpDriverRate,
            'start_date': startDate.toIso8601String(),
            'end_date': endDate.toIso8601String(),
            'is_active': true,
          })
          .select()
          .single();

      debugLog('✅ Created coupon: $code');
      return Coupon.fromJson(response);
    } catch (e) {
      debugLog('❌ Error creating coupon: $e');
      return null;
    }
  }

  /// Get all coupons (admin)
  Future<List<Coupon>> getAllCoupons() async {
    try {
      final response = await _client
          .from('coupons')
          .select()
          .order('created_at', ascending: false);

      return (response as List)
          .map((json) => Coupon.fromJson(json))
          .toList();
    } catch (e) {
      debugLog('❌ Error fetching all coupons: $e');
      return [];
    }
  }

  /// Toggle coupon active status (admin)
  Future<bool> toggleCouponActive(String couponId, bool isActive) async {
    try {
      await _client
          .from('coupons')
          .update({'is_active': isActive})
          .eq('id', couponId);
      return true;
    } catch (e) {
      debugLog('❌ Error toggling coupon: $e');
      return false;
    }
  }

  // ── Merchant Methods ──

  Future<List<Coupon>> getMerchantCoupons(String merchantId) async {
    try {
      final response = await _client
          .from('coupons')
          .select()
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false);

      return (response as List).map((json) => Coupon.fromJson(json)).toList();
    } catch (e) {
      debugLog('❌ Error fetching merchant coupons: $e');
      return [];
    }
  }

  Future<Coupon?> createMerchantCoupon({
    required String merchantId,
    required String code,
    required String name,
    String? description,
    required String discountType,
    required double discountValue,
    double? minOrderAmount,
    double? maxDiscountAmount,
    int usageLimit = 0,
    int perUserLimit = 1,
    required DateTime startDate,
    required DateTime endDate,
    double merchantGpChargeRate = 0.25,
    double merchantGpSystemRate = 0.10,
    double merchantGpDriverRate = 0.15,
  }) async {
    return createCoupon(
      code: code,
      name: name,
      description: description,
      discountType: discountType,
      discountValue: discountType == 'free_delivery' ? 0 : discountValue,
      minOrderAmount: minOrderAmount,
      maxDiscountAmount: discountType == 'percentage' ? maxDiscountAmount : null,
      serviceType: 'food',
      merchantId: merchantId,
      usageLimit: usageLimit,
      perUserLimit: perUserLimit,
      createdByRole: 'merchant',
      merchantGpChargeRate: discountType == 'free_delivery' ? merchantGpChargeRate : 0,
      merchantGpSystemRate: discountType == 'free_delivery' ? merchantGpSystemRate : 0,
      merchantGpDriverRate: discountType == 'free_delivery' ? merchantGpDriverRate : 0,
      startDate: startDate,
      endDate: endDate,
    );
  }

  String _serviceLabel(String serviceType) {
    switch (serviceType) {
      case 'food':
        return 'สั่งอาหาร';
      case 'ride':
        return 'เรียกรถ';
      case 'parcel':
        return 'ส่งพัสดุ';
      default:
        return serviceType;
    }
  }
}
