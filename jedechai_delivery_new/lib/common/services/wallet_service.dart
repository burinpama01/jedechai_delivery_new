import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'system_config_service.dart';
import '../utils/driver_amount_calculator.dart';
import '../utils/order_code_formatter.dart';

/// WalletService - Service สำหรับจัดการกระเป๋าเงินคนขับ
/// 
/// ฟีเจอร์หลัก:
/// - ตรวจสอบยอดเงินคงเหลือ
/// - หักเงินค่าบริการระบบ
/// - บันทึกประวัติการทำรายการ
/// - ตรวจสอบว่าคนขับมีเงินพอรับงานหรือไม่
///
/// Fee Structure (Food Delivery):
/// - Platform Fee: 15% of Delivery Fee
/// - Merchant GP: 10% of Food Price (menu items total)
class WalletService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final SystemConfigService _configService = SystemConfigService();

  // ── Food Delivery Fee Settings ──
  static const double minimumDeductionThreshold = 50.0; // THB
  
  // Dynamic rates from SystemConfigService
  double get platformFeeRate => _configService.platformFeeRate;
  double get merchantGpRate => _configService.merchantGpRate;

  /// ดึงข้อมูล wallet ของคนขับ
  Future<DriverWallet?> getDriverWallet(String driverId) async {
    try {
      final response = await _supabase
          .from('wallets')
          .select('id, user_id, balance, updated_at')
          .eq('user_id', driverId)
          .maybeSingle();

      if (response == null) {
        debugLog('⚠️ ไม่พบกระเป๋าเงิน — สร้างใหม่อัตโนมัติ: $driverId');
        return await _createWallet(driverId);
      }

      return DriverWallet.fromJson(response);
    } catch (e) {
      debugLog('❌ Error fetching driver wallet: $e');
      rethrow;
    }
  }

  /// สร้างกระเป๋าเงินใหม่สำหรับคนขับ
  Future<DriverWallet?> _createWallet(String userId) async {
    try {
      final response = await _supabase
          .from('wallets')
          .insert({
            'user_id': userId,
            'balance': 0,
          })
          .select('id, user_id, balance, updated_at')
          .single();

      debugLog('✅ สร้างกระเป๋าเงินสำเร็จสำหรับ: $userId');
      return DriverWallet.fromJson(response);
    } catch (e) {
      debugLog('❌ Error creating wallet: $e');
      return null;
    }
  }

  /// ตรวจสอบว่าคนขับมีเงินพอรับงานหรือไม่ (generic — ใช้ minimum threshold)
  Future<bool> canAcceptJob(String driverId) async {
    try {
      final wallet = await getDriverWallet(driverId);
      
      if (wallet == null) {
        debugLog('❌ ไม่พบกระเป๋าเงิน - ไม่สามารถรับงานได้');
        return false;
      }

      final minWallet = _configService.driverMinWallet;
      final canAccept = wallet.balance >= minWallet;

      if (canAccept) {
        debugLog('✅ ยอดเงินเพียงพอ: ${wallet.balance} บาท (ขั้นต่ำ: $minWallet บาท)');
      } else {
        debugLog('❌ ยอดเงินไม่เพียงพอ: ${wallet.balance} บาท (ต้องการอย่างน้อย: $minWallet บาท)');
      }

      return canAccept;
    } catch (e) {
      debugLog('❌ Error checking wallet balance: $e');
      return false;
    }
  }

  /// คำนวณค่าหักโดยประมาณสำหรับ food order
  ///
  /// ระบบใหม่รองรับการแยก GP ที่เป็นส่วนของคนขับ (merchantGpDriverRate)
  /// ออกจากยอดที่ต้องหักเข้าระบบจริง เพื่อไม่ให้บล็อกการรับงานเกินจำเป็น
  ///
  /// - deliverySystemFee = deliveryFee * deliverySystemRate
  /// - merchantSystemGP  = foodPrice * merchantGpSystemRate
  /// - estimated deduction = deliverySystemFee + merchantSystemGP
  static double estimateFoodDeduction({
    required double deliveryFee,
    required double foodPrice,
    double? platformFeeRate,
    double? merchantGpRate,
    double? deliverySystemRate,
    double? merchantGpSystemRate,
    double? merchantGpDriverRate,
  }) {
    final deliveryRate = deliverySystemRate ?? platformFeeRate ?? 0.15;
    final merchantSystemRate = merchantGpSystemRate ?? merchantGpRate ?? 0.10;
    final settlement = DriverAmountCalculator.foodOrderSettlement(
      foodPrice: foodPrice,
      deliveryFee: deliveryFee,
      deliverySystemRate: deliveryRate,
      merchantGpSystemRate: merchantSystemRate,
      merchantGpDriverRate: merchantGpDriverRate ?? 0.0,
    );
    return settlement.appEarnings;
  }

  /// ตรวจสอบว่าคนขับมีเงินพอรับงาน food หรือไม่ (per-job check)
  ///
  /// คำนวณ estimated deduction จาก deliveryFee + foodPrice
  /// ถ้า wallet_balance < estimated_deduction (หรือ < 50 THB) → block
  Future<bool> canAcceptFoodJob({
    required String driverId,
    required double deliveryFee,
    required double foodPrice,
    double extraEstimatedDeduction = 0,
    double? deliverySystemRateOverride,
    double? merchantGpSystemRateOverride,
  }) async {
    try {
      final wallet = await getDriverWallet(driverId);
      if (wallet == null) {
        debugLog('❌ ไม่พบกระเป๋าเงิน - ไม่สามารถรับงานได้');
        return false;
      }

      // ตรวจสอบให้แน่ใจว่ามีข้อมูล config
      await _configService.fetchSettings();

      final deliveryRate =
          deliverySystemRateOverride ?? _configService.platformFeeRate;
      final merchantSystemRate =
          merchantGpSystemRateOverride ??
          _configService.merchantGpSystemRateDefault;
      
      final estimatedDeduction = estimateFoodDeduction(
        deliveryFee: deliveryFee,
        foodPrice: foodPrice,
        deliverySystemRate: deliveryRate,
        merchantGpSystemRate: merchantSystemRate,
      ) + extraEstimatedDeduction;
      final requiredBalance = estimatedDeduction < minimumDeductionThreshold
          ? minimumDeductionThreshold
          : estimatedDeduction;

      final canAccept = wallet.balance >= requiredBalance;

      debugLog('💰 Food job wallet check:');
      debugLog('   └─ Delivery Fee: $deliveryFee, Food Price: $foodPrice');
      debugLog('   └─ Delivery System Rate (${(deliveryRate * 100).toStringAsFixed(0)}%): ${(deliveryFee * deliveryRate).toStringAsFixed(2)}');
      debugLog('   └─ Merchant GP System (${(merchantSystemRate * 100).toStringAsFixed(0)}%): ${(foodPrice * merchantSystemRate).toStringAsFixed(2)}');
      debugLog('   └─ Estimated Deduction: $estimatedDeduction');
      debugLog('   └─ Required Balance: $requiredBalance');
      debugLog('   └─ Current Balance: ${wallet.balance}');
      debugLog('   └─ Can Accept: $canAccept');

      return canAccept;
    } catch (e) {
      debugLog('❌ Error checking food job wallet: $e');
      return false;
    }
  }

  static Map<String, double> applyReferralCouponFundingOffsets({
    required double totalDeduction,
    required double appEarnings,
    required double driverNetIncome,
    String? couponCode,
    required double couponDiscountAmount,
  }) {
    final normalizedCouponCode = couponCode?.trim().toUpperCase();
    final isReferralTwoSidedCoupon = normalizedCouponCode == 'WELCOME20' ||
        normalizedCouponCode == 'REFERRER20' ||
        normalizedCouponCode == 'REFFERER20';

    var updatedTotalDeduction = totalDeduction;
    var updatedAppEarnings = appEarnings;
    var updatedDriverNetIncome = driverNetIncome;
    var couponSystemOffset = 0.0;
    var couponDriverOffset = 0.0;

    final effectiveCouponDiscount =
        isReferralTwoSidedCoupon ? couponDiscountAmount : 0.0;
    if (effectiveCouponDiscount > 0) {
      couponSystemOffset = effectiveCouponDiscount > updatedTotalDeduction
          ? updatedTotalDeduction
          : effectiveCouponDiscount;
      updatedTotalDeduction -= couponSystemOffset;
      updatedAppEarnings -= couponSystemOffset;

      final remaining = effectiveCouponDiscount - couponSystemOffset;
      if (remaining > 0) {
        couponDriverOffset = remaining > updatedDriverNetIncome
            ? updatedDriverNetIncome
            : remaining;
        updatedDriverNetIncome -= couponDriverOffset;
      }
    }

    if (updatedTotalDeduction < 0) updatedTotalDeduction = 0;
    if (updatedAppEarnings < 0) updatedAppEarnings = 0;
    if (updatedDriverNetIncome < 0) updatedDriverNetIncome = 0;

    return {
      'totalDeduction': updatedTotalDeduction,
      'appEarnings': updatedAppEarnings,
      'driverNetIncome': updatedDriverNetIncome,
      'couponSystemOffset': couponSystemOffset,
      'couponDriverOffset': couponDriverOffset,
    };
  }

  /// หักเงินค่าบริการระบบสำหรับ food order (Platform Fee + Merchant GP)
  ///
  /// platformFee = deliveryFee * 15%
  /// merchantGP  = foodPrice * 10%
  /// totalDeduction = platformFee + merchantGP
  /// driverNetIncome = deliveryFee - platformFee
  ///
  /// Returns: Map with 'platformFee', 'merchantGP', 'totalDeduction', 'driverNetIncome'
  ///          or null if failed
  Future<Map<String, double>?> deductFoodCommission({
    required String driverId,
    required double deliveryFee,
    required double foodPrice,
    required String bookingId,
    String? couponCode,
    double couponDiscountAmount = 0,
    double? deliverySystemRateOverride,
    double? merchantGpSystemRateOverride,
    double? merchantGpDriverRateOverride,
    bool applyMerchantFreeDeliveryAdjustment = false,
    double merchantFreeDeliveryChargeRate = 0.25,
    double merchantFreeDeliverySystemRate = 0.10,
    double merchantFreeDeliveryDriverRate = 0.15,
  }) async {
    debugLog('💰 กำลังหักค่าบริการระบบ Food Order...');
    debugLog('   └─ คนขับ: $driverId');
    debugLog('   └─ Delivery Fee: $deliveryFee');
    debugLog('   └─ Food Price: $foodPrice');
    debugLog('   └─ Booking: $bookingId');

    try {
      final wallet = await getDriverWallet(driverId);
      if (wallet == null) {
        throw Exception('ไม่พบกระเป๋าเงินของคนขับ');
      }

      // ตรวจสอบให้แน่ใจว่ามีข้อมูล config
      await _configService.fetchSettings();

      final deliverySystemRate =
          deliverySystemRateOverride ?? _configService.platformFeeRate;
      final merchantGpSystemRate =
          merchantGpSystemRateOverride ??
          _configService.merchantGpSystemRateDefault;
      final merchantGpDriverRate =
          merchantGpDriverRateOverride ??
          _configService.merchantGpDriverRateDefault;

      // คำนวณค่าธรรมเนียมจากค่าที่ตั้งค่าในระบบ/ร้านค้า
      final settlement = DriverAmountCalculator.foodOrderSettlement(
        foodPrice: foodPrice,
        deliveryFee: deliveryFee,
        deliverySystemRate: deliverySystemRate,
        merchantGpSystemRate: merchantGpSystemRate,
        merchantGpDriverRate: merchantGpDriverRate,
      );
      final deliverySystemFee = settlement.deliverySystemFee;
      final merchantSystemGP = settlement.merchantSystemGP;
      final merchantDriverGP = settlement.merchantDriverGP;

      var totalDeduction = deliverySystemFee + merchantSystemGP;
      var appEarnings = deliverySystemFee + merchantSystemGP;
      var driverNetIncome = settlement.driverNetIncome;
      var extraSystemCharge = 0.0;
      var extraDriverSupport = 0.0;
      var couponSystemOffset = 0.0;
      var couponDriverOffset = 0.0;

      if (applyMerchantFreeDeliveryAdjustment) {
        // Additional GP from merchant coupon budget
        extraSystemCharge =
            (foodPrice * merchantFreeDeliverySystemRate).ceilToDouble();
        extraDriverSupport =
            (foodPrice * merchantFreeDeliveryDriverRate).ceilToDouble();

        // หักเข้าระบบเฉพาะส่วน system rate
        totalDeduction += extraSystemCharge;
        appEarnings += extraSystemCharge;
        driverNetIncome += extraDriverSupport;

        // Keep for trace/debug only
        // ignore: unused_local_variable
        final extraTotal =
            (foodPrice * merchantFreeDeliveryChargeRate).ceilToDouble();
      }

      final funding = applyReferralCouponFundingOffsets(
        totalDeduction: totalDeduction,
        appEarnings: appEarnings,
        driverNetIncome: driverNetIncome,
        couponCode: couponCode,
        couponDiscountAmount: couponDiscountAmount,
      );
      totalDeduction = funding['totalDeduction'] ?? totalDeduction;
      appEarnings = funding['appEarnings'] ?? appEarnings;
      driverNetIncome = funding['driverNetIncome'] ?? driverNetIncome;
      couponSystemOffset = funding['couponSystemOffset'] ?? 0.0;
      couponDriverOffset = funding['couponDriverOffset'] ?? 0.0;

      debugLog(
        '   └─ Delivery System Fee (${(deliverySystemRate * 100).toStringAsFixed(0)}% of $deliveryFee): $deliverySystemFee',
      );
      debugLog(
        '   └─ Merchant GP System (${(merchantGpSystemRate * 100).toStringAsFixed(0)}% of $foodPrice): $merchantSystemGP',
      );
      debugLog(
        '   └─ Merchant GP Driver (${(merchantGpDriverRate * 100).toStringAsFixed(0)}% of $foodPrice): $merchantDriverGP',
      );
      if (applyMerchantFreeDeliveryAdjustment) {
        debugLog('   └─ Extra Coupon GP System (${(merchantFreeDeliverySystemRate * 100).toStringAsFixed(0)}%): $extraSystemCharge');
        debugLog('   └─ Extra Coupon GP Driver (${(merchantFreeDeliveryDriverRate * 100).toStringAsFixed(0)}%): $extraDriverSupport');
      }
      debugLog('   └─ Total Deduction: $totalDeduction');
      debugLog('   └─ Driver Net Income: $driverNetIncome');

      final newBalance = wallet.balance - totalDeduction;
      debugLog('   └─ ยอดเงินเดิม: ${wallet.balance} บาท');
      debugLog('   └─ ยอดเงินใหม่: $newBalance บาท');

      if (totalDeduction > 0) {
        // Atomic deduction via RPC (Phase 2)
        final shortId = OrderCodeFormatter.format(bookingId);
        final rpcResult = await _supabase.rpc('wallet_deduct', params: {
          'p_user_id': driverId,
          'p_amount': totalDeduction,
          'p_description': 'หักค่าบริการระบบ ออเดอร์ $shortId',
          'p_type': 'commission',
          'p_related_booking_id': bookingId,
        });
        if (rpcResult is Map && rpcResult['success'] != true) {
          throw Exception(rpcResult['error'] ?? 'wallet_deduct failed');
        }
      } else {
        debugLog('ℹ️ Skip wallet_deduct เพราะยอดหักเข้าระบบ = 0');
      }

      debugLog('✅ หักค่าบริการระบบ Food Order สำเร็จ');

      return {
        'platformFee': deliverySystemFee,
        'deliverySystemFee': deliverySystemFee,
        'merchantGP': merchantSystemGP + merchantDriverGP,
        'merchantSystemGP': merchantSystemGP,
        'merchantDriverGP': merchantDriverGP,
        'extraSystemCharge': extraSystemCharge,
        'extraDriverSupport': extraDriverSupport,
        'couponSystemOffset': couponSystemOffset,
        'couponDriverOffset': couponDriverOffset,
        'appEarnings': appEarnings,
        'totalDeduction': totalDeduction,
        'driverNetIncome': driverNetIncome,
      };
    } catch (e) {
      debugLog('❌ Error deducting food commission: $e');
      return null;
    }
  }

  /// หักเงินค่าบริการระบบจากกระเป๋าคนขับ
  /// 
  /// [driverId] - ID ของคนขับ
  /// [jobPrice] - ราคางาน (บาท)
  /// [bookingId] - ID ของการจอง
  /// 
  /// Returns: true ถ้าหักเงินสำเร็จ
  Future<bool> deductCommission({
    required String driverId,
    required int jobPrice,
    required String bookingId,
  }) async {
    debugLog('🔍 DEBUG: deductCommission called');
    debugLog('   └─ Timestamp: ${DateTime.now()}');
    debugLog('💰 กำลังหักค่าบริการระบบ...');
    debugLog('   └─ คนขับ: $driverId');
    debugLog('   └─ ราคางาน: $jobPrice บาท');
    debugLog('   └─ Booking: $bookingId');

    try {
      // ดึงข้อมูล wallet
      final wallet = await getDriverWallet(driverId);
      if (wallet == null) {
        throw Exception('ไม่พบกระเป๋าเงินของคนขับ');
      }

      // คำนวณค่าบริการระบบ
      final commission = _configService.calculateCommission(jobPrice);
      debugLog('   └─ อัตราค่าบริการระบบ: ${_configService.commissionRate}%');
      debugLog('   └─ ค่าบริการระบบ: $commission บาท');

      // ยอดเงินใหม่
      final newBalance = wallet.balance - commission;
      debugLog('   └─ ยอดเงินเดิม: ${wallet.balance} บาท');
      debugLog('   └─ ยอดเงินใหม่: $newBalance บาท');

      // Atomic deduction via RPC (Phase 2)
      final rpcResult = await _supabase.rpc('wallet_deduct', params: {
        'p_user_id': driverId,
        'p_amount': commission,
        'p_description': 'หักค่าบริการระบบ จากงาน $bookingId',
        'p_type': 'commission',
        'p_related_booking_id': bookingId,
      });
      if (rpcResult is Map && rpcResult['success'] != true) {
        throw Exception(rpcResult['error'] ?? 'wallet_deduct failed');
      }

      debugLog('✅ หักค่าบริการระบบสำเร็จ');
      return true;
    } catch (e) {
      debugLog('❌ Error deducting commission: $e');
      return false;
    }
  }

  /// เติมเงินเข้ากระเป๋า (สำหรับทดสอบหรือระบบเติมเงินจริง)
  Future<bool> topUpWallet({
    required String driverId,
    required double amount,
    String? description,
  }) async {
    try {
      debugLog('💵 กำลังเติมเงิน...');
      debugLog('   └─ คนขับ: $driverId');
      debugLog('   └─ จำนวน: $amount บาท');

      // ดึงข้อมูล wallet
      final wallet = await getDriverWallet(driverId);
      if (wallet == null) {
        throw Exception('ไม่พบกระเป๋าเงินของคนขับ');
      }

      // Atomic top-up via RPC (Phase 2)
      final rpcResult = await _supabase.rpc('wallet_topup', params: {
        'p_user_id': driverId,
        'p_amount': amount,
        'p_description': description ?? 'เติมเงินเข้ากระเป๋า',
      });
      final newBalance = (rpcResult is Map) ? rpcResult['new_balance'] ?? (wallet.balance + amount) : wallet.balance + amount;
      if (rpcResult is Map && rpcResult['success'] != true) {
        throw Exception(rpcResult['error'] ?? 'wallet_topup failed');
      }

      debugLog('✅ เติมเงินสำเร็จ: ยอดเงินใหม่ $newBalance บาท');
      return true;
    } catch (e) {
      debugLog('❌ Error topping up wallet: $e');
      return false;
    }
  }

  /// ดึงยอดเงินคงเหลือปัจจุบัน
  Future<double> getBalance(String userId) async {
    try {
      final wallet = await getDriverWallet(userId);
      return wallet?.balance ?? 0.0;
    } catch (e) {
      debugLog('❌ Error fetching balance: $e');
      return 0.0;
    }
  }

  /// ดึงประวัติการทำรายการ (แบบ Map สำหรับ UI)
  Future<List<Map<String, dynamic>>> getTransactions(String userId) async {
    try {
      // ดึงข้อมูล wallet
      final wallet = await getDriverWallet(userId);
      if (wallet == null) {
        return [];
      }

      // ดึงประวัติการทำรายการ
      final response = await _supabase
          .from('wallet_transactions')
          .select('id, amount, type, description, related_booking_id, created_at')
          .eq('wallet_id', wallet.id)
          .order('created_at', ascending: false)
          .limit(50);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugLog('❌ Error fetching transactions: $e');
      return [];
    }
  }

  /// ดึงประวัติการทำรายการ (แบบ Model เดิม)
  Future<List<WalletTransaction>> getTransactionHistory({
    required String driverId,
    int limit = 50,
  }) async {
    try {
      // ดึงข้อมูล wallet
      final wallet = await getDriverWallet(driverId);
      if (wallet == null) {
        return [];
      }

      // ดึงประวัติการทำรายการ
      final response = await _supabase
          .from('wallet_transactions')
          .select('id, wallet_id, amount, type, description, related_booking_id, created_at')
          .eq('wallet_id', wallet.id)
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List)
          .map((json) => WalletTransaction.fromJson(json))
          .toList();
    } catch (e) {
      debugLog('❌ Error fetching transaction history: $e');
      return [];
    }
  }
}

/// Model สำหรับกระเป๋าเงินคนขับ
class DriverWallet {
  final String id;
  final String userId;
  final double balance;
  final DateTime updatedAt;

  DriverWallet({
    required this.id,
    required this.userId,
    required this.balance,
    required this.updatedAt,
  });

  factory DriverWallet.fromJson(Map<String, dynamic> json) {
    return DriverWallet(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      balance: (json['balance'] as num).toDouble(),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'balance': balance,
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  @override
  String toString() {
    return 'DriverWallet(id: $id, balance: $balance฿)';
  }
}

/// Model สำหรับประวัติการทำรายการ
class WalletTransaction {
  final String id;
  final String walletId;
  final double amount;
  final String type;
  final String? description;
  final String? relatedBookingId;
  final DateTime createdAt;

  WalletTransaction({
    required this.id,
    required this.walletId,
    required this.amount,
    required this.type,
    this.description,
    this.relatedBookingId,
    required this.createdAt,
  });

  factory WalletTransaction.fromJson(Map<String, dynamic> json) {
    return WalletTransaction(
      id: json['id'] as String,
      walletId: json['wallet_id'] as String,
      amount: (json['amount'] as num).toDouble(),
      type: json['type'] as String,
      description: json['description'] as String?,
      relatedBookingId: json['related_booking_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'wallet_id': walletId,
      'amount': amount,
      'type': type,
      'description': description,
      'related_booking_id': relatedBookingId,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// แสดงผลเป็นข้อความ
  String get displayText {
    final amountText = amount >= 0 ? '+${amount.toStringAsFixed(2)}' : amount.toStringAsFixed(2);
    final typeText = _getTypeText();
    return '$typeText: $amountText บาท';
  }

  String _getTypeText() {
    switch (type) {
      case 'topup':
        return 'เติมเงิน';
      case 'commission':
        return 'หักค่าบริการระบบ';
      case 'food_commission':
        return 'หักค่าบริการระบบอาหาร';
      case 'job_income':
        return 'รายได้จากงาน';
      case 'penalty':
        return 'ค่าปรับ';
      default:
        return type;
    }
  }

  @override
  String toString() {
    return 'WalletTransaction(type: $type, amount: $amount฿, date: $createdAt)';
  }
}
