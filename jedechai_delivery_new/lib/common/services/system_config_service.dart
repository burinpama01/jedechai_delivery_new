import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// SystemConfigService - Singleton Service สำหรับจัดการการตั้งค่าระบบและคำนวณราคา
///
/// ฟีเจอร์หลัก:
/// - โหลดและ cache ข้อมูลจาก service_rates และ system_config
/// - คำนวณค่าบริการตามประเภทและระยะทาง
/// - รองรับการปัดเศษระยะทางแบบมาตรฐาน
class SystemConfigService {
  // Singleton pattern
  static final SystemConfigService _instance = SystemConfigService._internal();
  factory SystemConfigService() => _instance;
  SystemConfigService._internal();

  // Supabase client
  final SupabaseClient _supabase = Supabase.instance.client;

  // Cache สำหรับเก็บข้อมูลการตั้งค่า
  Map<String, ServiceRate>? _serviceRates;
  SystemConfig? _systemConfig;
  DateTime? _lastFetchTime;

  // ระยะเวลา cache (5 นาที)
  final Duration _cacheDuration = const Duration(minutes: 5);

  /// โหลดการตั้งค่าจากฐานข้อมูล
  /// จะ cache ข้อมูลไว้ในหน่วยความจำเพื่อลดการเรียก API
  Future<void> fetchSettings({bool forceRefresh = false}) async {
    try {
      // ตรวจสอบว่าต้อง refresh หรือไม่
      if (!forceRefresh && _isCacheValid()) {
        debugLog('✅ ใช้ข้อมูล cache ที่มีอยู่');
        return;
      }

      debugLog('🔄 กำลังโหลดการตั้งค่าระบบ...');

      // โหลด service_rates
      final serviceRatesResponse = await _supabase
          .from('service_rates')
          .select('service_type, base_price, base_distance, price_per_km');

      // โหลด system_config
      final systemConfigResponse =
          await _supabase.from('system_config').select('*').maybeSingle();

      // แปลงข้อมูล service_rates เป็น Map
      _serviceRates = {};
      for (final rate in serviceRatesResponse) {
        final serviceType = rate['service_type'] as String;
        _serviceRates![serviceType] = ServiceRate.fromJson(rate);
      }

      // แปลงข้อมูล system_config
      if (systemConfigResponse != null) {
        _systemConfig = SystemConfig.fromJson(systemConfigResponse);
      } else {
        // ใช้ค่าเริ่มต้นถ้าไม่มีข้อมูลในฐานข้อมูล
        _systemConfig = SystemConfig(
          driverMinWallet: 50,
          commissionRate: 15.0,
          platformFeeRate: 0.15,
          merchantGpRate: 0.10,
          maxDeliveryRadius: 30.0,
        );
        debugLog(
            '⚠️ ใช้ค่าเริ่มต้นสำหรับ system_config (ไม่พบข้อมูลในฐานข้อมูล)');
      }

      // บันทึกเวลาที่โหลด
      _lastFetchTime = DateTime.now();

      debugLog('✅ โหลดการตั้งค่าสำเร็จ:');
      debugLog('   └─ Service Rates: ${_serviceRates!.keys.join(', ')}');
      debugLog('   └─ Min Wallet: ${_systemConfig!.driverMinWallet} บาท');
      debugLog('   └─ Commission: ${_systemConfig!.commissionRate}%');
    } catch (e) {
      debugLog('❌ Error loading system settings: $e');
      rethrow;
    }
  }

  /// ตรวจสอบว่า cache ยังใช้ได้หรือไม่
  bool _isCacheValid() {
    if (_serviceRates == null ||
        _systemConfig == null ||
        _lastFetchTime == null) {
      return false;
    }

    final now = DateTime.now();
    final difference = now.difference(_lastFetchTime!);
    return difference < _cacheDuration;
  }

  /// คำนวณค่าบริการตามประเภทและระยะทาง
  ///
  /// [serviceType] - ประเภทบริการ: 'ride', 'food', 'parcel'
  /// [distanceKm] - ระยะทาง (กิโลเมตร)
  ///
  /// Returns: ค่าบริการเป็นจำนวนเต็ม (บาท)
  Future<int> calculateDeliveryFee({
    required String serviceType,
    required double distanceKm,
  }) async {
    try {
      // ตรวจสอบว่ามีข้อมูล cache หรือไม่
      if (_serviceRates == null || _systemConfig == null) {
        await fetchSettings();
      }

      // ดึงข้อมูลอัตราค่าบริการ
      final rate = _serviceRates![serviceType];
      if (rate == null) {
        throw Exception('ไม่พบอัตราค่าบริการสำหรับ $serviceType');
      }

      // Step 1: ปัดเศษระยะทาง (2.4->2, 2.5->3)
      final roundedDistance = distanceKm.round();

      debugLog('💰 คำนวณค่าบริการ:');
      debugLog('   └─ ประเภท: $serviceType');
      debugLog('   └─ ระยะทางจริง: ${distanceKm.toStringAsFixed(2)} กม.');
      debugLog('   └─ ระยะทางปัดเศษ: $roundedDistance กม.');

      // Step 2 & 3: คำนวณค่าบริการ
      int fee;

      if (roundedDistance <= rate.baseDistance) {
        // ถ้าระยะทางไม่เกินระยะพื้นฐาน ใช้ราคาพื้นฐาน
        fee = rate.basePrice;
        debugLog('   └─ สูตร: ราคาพื้นฐาน = ${rate.basePrice} บาท');
      } else {
        // ถ้าระยะทางเกิน คำนวณค่าระยะทางเพิ่ม
        final extraDistance = roundedDistance - rate.baseDistance;
        final extraFee = extraDistance * rate.pricePerKm;
        fee = rate.basePrice + extraFee;

        debugLog(
            '   └─ สูตร: ${rate.basePrice} + (($roundedDistance - ${rate.baseDistance}) × ${rate.pricePerKm})');
        debugLog(
            '   └─ สูตร: ${rate.basePrice} + ($extraDistance × ${rate.pricePerKm})');
        debugLog('   └─ สูตร: ${rate.basePrice} + $extraFee');
      }

      debugLog('   └─ ค่าบริการรวม: $fee บาท');
      return fee;
    } catch (e) {
      debugLog('❌ Error calculating delivery fee: $e');
      rethrow;
    }
  }

  /// ดึงข้อมูลอัตราค่าบริการตามประเภท
  ServiceRate? getServiceRate(String serviceType) {
    return _serviceRates?[serviceType];
  }

  /// ดึงข้อมูลการตั้งค่าระบบ
  SystemConfig? get systemConfig => _systemConfig;

  /// ดึงค่าเงินขั้นต่ำที่คนขับต้องมี
  int get driverMinWallet => _systemConfig?.driverMinWallet ?? 50;

  /// ดึงอัตราค่าคอมมิชชั่น
  double get commissionRate => _systemConfig?.commissionRate ?? 15.0;

  /// ดึงอัตรา Platform Fee (สำหรับ food delivery)
  double get platformFeeRate => _systemConfig?.platformFeeRate ?? 0.15;

  /// ดึงอัตรา Merchant GP (สำหรับ food delivery)
  double get merchantGpRate => _systemConfig?.merchantGpRate ?? 0.10;

  /// ดึง URL โลโก้แอป
  String? get logoUrl => _systemConfig?.logoUrl;

  /// ดึง URL หน้า Splash
  String? get splashUrl => _systemConfig?.splashUrl;

  /// ดึงรัศมีจัดส่งสูงสุด (กิโลเมตร)
  double get maxDeliveryRadius => _systemConfig?.maxDeliveryRadius ?? 30.0;

  /// คนขับ -> ลูกค้า (ride matching)
  double get driverToCustomerRadiusKm =>
      _systemConfig?.detectionRadiusConfig.driverToCustomerKm ?? 20.0;

  /// ลูกค้า -> คนขับ (ค้นหาคนขับใกล้ลูกค้า)
  double get customerToDriverRadiusKm =>
      _systemConfig?.detectionRadiusConfig.customerToDriverKm ?? 30.0;

  /// ลูกค้า -> ร้านค้า (แสดงร้านใกล้ลูกค้า)
  double get customerToMerchantRadiusKm =>
      _systemConfig?.detectionRadiusConfig.customerToMerchantKm ?? 30.0;

  /// คนขับ -> ออเดอร์ (หน้ารับงานคนขับ)
  double get driverToOrderRadiusKm =>
      _systemConfig?.detectionRadiusConfig.driverToOrderKm ?? 20.0;

  /// คนขับพัสดุ -> จุดรับ
  double get parcelDriverToPickupRadiusKm =>
      _systemConfig?.detectionRadiusConfig.parcelDriverToPickupKm ?? 30.0;

  /// คำนวณค่าคอมมิชชั่นจากราคางาน
  double calculateCommission(int jobPrice) {
    final commission = jobPrice * (commissionRate / 100);
    return commission.ceilToDouble();
  }

  /// ล้าง cache
  void clearCache() {
    _serviceRates = null;
    _systemConfig = null;
    _lastFetchTime = null;
    debugLog('🗑️ ล้าง cache การตั้งค่าระบบแล้ว');
  }
}

/// Model สำหรับเก็บข้อมูลอัตราค่าบริการ
class ServiceRate {
  final String serviceType;
  final int basePrice;
  final int baseDistance;
  final int pricePerKm;

  ServiceRate({
    required this.serviceType,
    required this.basePrice,
    required this.baseDistance,
    required this.pricePerKm,
  });

  factory ServiceRate.fromJson(Map<String, dynamic> json) {
    return ServiceRate(
      serviceType: json['service_type'] as String,
      basePrice: json['base_price'] as int,
      baseDistance: (json['base_distance'] as num).round(),
      pricePerKm: json['price_per_km'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'service_type': serviceType,
      'base_price': basePrice,
      'base_distance': baseDistance,
      'price_per_km': pricePerKm,
    };
  }

  @override
  String toString() {
    return 'ServiceRate(type: $serviceType, base: $basePrice฿ for ${baseDistance}km, extra: $pricePerKm฿/km)';
  }
}

/// Model สำหรับเก็บข้อมูลการตั้งค่าระบบ
class SystemConfig {
  final int driverMinWallet;
  final double commissionRate;
  final double platformFeeRate;
  final double merchantGpRate;
  final double maxDeliveryRadius;
  final DetectionRadiusConfig detectionRadiusConfig;
  final String? logoUrl;
  final String? splashUrl;

  SystemConfig({
    required this.driverMinWallet,
    required this.commissionRate,
    required this.platformFeeRate,
    required this.merchantGpRate,
    this.maxDeliveryRadius = 30.0,
    this.detectionRadiusConfig = const DetectionRadiusConfig(),
    this.logoUrl,
    this.splashUrl,
  });

  factory SystemConfig.fromJson(Map<String, dynamic> json) {
    return SystemConfig(
      driverMinWallet: (json['driver_min_wallet'] as num?)?.toInt() ?? 50,
      commissionRate: (json['commission_rate'] as num?)?.toDouble() ?? 15.0,
      platformFeeRate: (json['platform_fee_rate'] as num?)?.toDouble() ?? 0.15,
      merchantGpRate: (json['merchant_gp_rate'] as num?)?.toDouble() ?? 0.10,
      maxDeliveryRadius:
          (json['max_delivery_radius'] as num?)?.toDouble() ?? 30.0,
      detectionRadiusConfig:
          DetectionRadiusConfig.fromJson(json['detection_radius_config']),
      logoUrl: json['logo_url'] as String?,
      splashUrl: json['splash_url'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'driver_min_wallet': driverMinWallet,
      'commission_rate': commissionRate,
      'platform_fee_rate': platformFeeRate,
      'merchant_gp_rate': merchantGpRate,
      'max_delivery_radius': maxDeliveryRadius,
      'detection_radius_config': detectionRadiusConfig.toJson(),
      'logo_url': logoUrl,
      'splash_url': splashUrl,
    };
  }

  @override
  String toString() {
    return 'SystemConfig(minWallet: $driverMinWallet฿, commission: $commissionRate%, platformFee: $platformFeeRate%, merchantGP: $merchantGpRate%, maxRadius: ${maxDeliveryRadius}km, detectRadius: ${detectionRadiusConfig.toJson()}, logo: ${logoUrl != null}, splash: ${splashUrl != null})';
  }
}

class DetectionRadiusConfig {
  final double driverToCustomerKm;
  final double customerToDriverKm;
  final double customerToMerchantKm;
  final double driverToOrderKm;
  final double parcelDriverToPickupKm;

  const DetectionRadiusConfig({
    this.driverToCustomerKm = 20.0,
    this.customerToDriverKm = 30.0,
    this.customerToMerchantKm = 30.0,
    this.driverToOrderKm = 20.0,
    this.parcelDriverToPickupKm = 30.0,
  });

  static double _asDouble(dynamic value, double fallback) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  factory DetectionRadiusConfig.fromJson(dynamic json) {
    if (json is! Map) {
      return const DetectionRadiusConfig();
    }
    return DetectionRadiusConfig(
      driverToCustomerKm:
          _asDouble(json['driver_to_customer_km'], 20.0),
      customerToDriverKm:
          _asDouble(json['customer_to_driver_km'], 30.0),
      customerToMerchantKm:
          _asDouble(json['customer_to_merchant_km'], 30.0),
      driverToOrderKm: _asDouble(json['driver_to_order_km'], 20.0),
      parcelDriverToPickupKm:
          _asDouble(json['parcel_driver_to_pickup_km'], 30.0),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'driver_to_customer_km': driverToCustomerKm,
      'customer_to_driver_km': customerToDriverKm,
      'customer_to_merchant_km': customerToMerchantKm,
      'driver_to_order_km': driverToOrderKm,
      'parcel_driver_to_pickup_km': parcelDriverToPickupKm,
    };
  }
}
