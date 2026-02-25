import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/booking.dart';
import 'mock_auth_service.dart';
import 'auth_service.dart';
import 'wallet_service.dart';
import 'system_config_service.dart';
import 'merchant_food_config_service.dart';
import 'fare_adjustment_service.dart';
import 'notification_sender.dart';

/// Booking Service
/// 
/// Handles all booking-related database operations
class BookingService {
  SupabaseClient get _client {
    if (MockAuthService.useMockMode) {
      throw Exception('Mock mode active - Booking operations not available');
    }
    return Supabase.instance.client;
  }

  Future<Map<String, double>?> _getFoodCouponFinanceContext({
    required String bookingId,
    required String? merchantId,
    required double deliveryFee,
  }) async {
    try {
      final usage = await _client
          .from('coupon_usages')
          .select('coupon_id, discount_amount')
          .eq('booking_id', bookingId)
          .maybeSingle();

      if (usage == null) return null;

      final couponId = usage['coupon_id'] as String?;
      final discountAmount = (usage['discount_amount'] as num?)?.toDouble() ?? 0;
      if (couponId == null || couponId.isEmpty) return null;

      final coupon = await _client
          .from('coupons')
          .select('discount_type, merchant_id, merchant_gp_charge_rate, merchant_gp_system_rate, merchant_gp_driver_rate')
          .eq('id', couponId)
          .maybeSingle();

      if (coupon == null) return null;

      final isMerchantCoupon =
          (coupon['merchant_id'] as String?) != null && (coupon['merchant_id'] as String?) == merchantId;
      final isFreeDelivery = coupon['discount_type'] == 'free_delivery';
      final fullyWaivedDelivery = deliveryFee <= 0 || discountAmount >= deliveryFee;

      if (!isMerchantCoupon || !isFreeDelivery || !fullyWaivedDelivery) {
        return null;
      }

      final configService = SystemConfigService();
      await configService.fetchSettings();
      final systemRateDefault = configService.merchantGpRate;
      const totalRateDefault = 0.25;
      final driverRateDefault = (totalRateDefault - systemRateDefault) > 0
          ? (totalRateDefault - systemRateDefault)
          : 0.0;

      final chargeRate = (coupon['merchant_gp_charge_rate'] as num?)?.toDouble() ?? totalRateDefault;
      final systemRate = (coupon['merchant_gp_system_rate'] as num?)?.toDouble() ?? systemRateDefault;
      final driverRate = (coupon['merchant_gp_driver_rate'] as num?)?.toDouble() ?? driverRateDefault;

      return {
        'chargeRate': chargeRate,
        'systemRate': systemRate,
        'driverRate': driverRate,
      };
    } catch (e) {
      debugLog('⚠️ Failed to load coupon finance context: $e');
      return null;
    }
  }

  Future<MerchantFoodConfig> _getMerchantFoodConfig({
    required String? merchantId,
    required SystemConfigService configService,
  }) async {
    Map<String, dynamic>? merchantProfile;

    if (merchantId != null && merchantId.isNotEmpty) {
      try {
        merchantProfile = await _client
            .from('profiles')
            .select(
              'gp_rate, merchant_gp_system_rate, merchant_gp_driver_rate, custom_base_fare, custom_base_distance, custom_per_km, custom_delivery_fee',
            )
            .eq('id', merchantId)
            .maybeSingle();
      } catch (e) {
        debugLog('⚠️ Failed to load merchant food config: $e');
      }
    }

    final splitDefaults = await _loadMerchantGpSplitDefaults(
      configService,
      merchantId: merchantId,
    );

    return MerchantFoodConfigService.resolve(
      merchantProfile: merchantProfile,
      defaultMerchantSystemRate: splitDefaults['systemRate']!,
      defaultMerchantDriverRate: splitDefaults['driverRate']!,
      defaultDeliverySystemRate: configService.platformFeeRate,
    );
  }

  Future<Map<String, double>> _loadMerchantGpSplitDefaults(
    SystemConfigService configService,
    {String? merchantId}
  ) async {
    final fallbackSystem = configService.merchantGpRate;
    final fallbackDriver = 0.0;

    double systemRate = fallbackSystem;
    double driverRate = fallbackDriver;

    try {
      final row = await _client
          .from('system_config')
          .select('merchant_gp_system_rate_default, merchant_gp_driver_rate_default')
          .maybeSingle();
      if (row != null) {
        final columnSystem = row['merchant_gp_system_rate_default'];
        final columnDriver = row['merchant_gp_driver_rate_default'];
        if (columnSystem != null) {
          systemRate = _parseRate(columnSystem.toString(), systemRate);
        }
        if (columnDriver != null) {
          driverRate = _parseRate(columnDriver.toString(), driverRate);
        }
      }
    } catch (_) {
      // ignore column-based read errors and continue with fallback/key-value
    }

    try {
      final rows = await _client
          .from('system_config')
          .select('key, value')
          .inFilter('key', [
        if (merchantId != null && merchantId.trim().isNotEmpty)
          'merchant_gp_system_rate_${merchantId.trim()}',
        if (merchantId != null && merchantId.trim().isNotEmpty)
          'merchant_gp_driver_rate_${merchantId.trim()}',
        'merchant_gp_system_rate_default',
        'merchant_gp_driver_rate_default',
      ]);

      final map = <String, String>{};
      for (final row in rows) {
        final key = row['key'] as String?;
        final value = row['value'] as String?;
        if (key != null && value != null) {
          map[key] = value;
        }
      }

      final merchantIdKey = (merchantId ?? '').trim();
      final merchantSystemRaw = merchantIdKey.isNotEmpty
          ? map['merchant_gp_system_rate_$merchantIdKey']
          : null;
      final merchantDriverRaw = merchantIdKey.isNotEmpty
          ? map['merchant_gp_driver_rate_$merchantIdKey']
          : null;

      final resolvedSystemRate = _parseRate(
        merchantSystemRaw,
        _parseRate(
          map['merchant_gp_system_rate_default'],
          systemRate,
        ),
      );
      final resolvedDriverRate = _parseRate(
        merchantDriverRaw,
        _parseRate(
          map['merchant_gp_driver_rate_default'],
          driverRate,
        ),
      );

      return {
        'systemRate': resolvedSystemRate,
        'driverRate': resolvedDriverRate,
      };
    } catch (e) {
      debugLog('⚠️ Failed to load merchant GP split defaults: $e');
      return {
        'systemRate': systemRate,
        'driverRate': driverRate,
      };
    }
  }

  double _parseRate(String? raw, double fallback) {
    final parsed = double.tryParse((raw ?? '').trim());
    if (parsed == null || parsed.isNaN || parsed < 0) return fallback;
    if (parsed > 1) return 1.0;
    return parsed;
  }

  /// Get all bookings for current user
  Future<List<Booking>> getUserBookings() async {
    final userId = AuthService.userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await _client
          .from('bookings')
          .select()
          .eq('customer_id', userId)
          .order('created_at', ascending: false)
          .limit(20);

      return (response as List)
          .map((json) => Booking.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch bookings: $e');
    }
  }

  /// Get booking by ID
  Future<Booking?> getBookingById(String bookingId) async {
    try {
      final response = await _client
          .from('bookings')
          .select()
          .eq('id', bookingId)
          .single();
      return Booking.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch booking: $e');
    }
  }

  /// Get booking items with menu item details
  Future<List<Map<String, dynamic>>> getBookingItems(String bookingId) async {
    try {
      final response = await _client
          .from('booking_items')
          .select('*, menu_item:menu_items(name, image_url, price)')
          .eq('booking_id', bookingId);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugLog('Failed to fetch booking items: $e');
      return [];
    }
  }

  /// Create a new ride booking
  /// 
  /// Throws Exception if user is not authenticated or creation fails
  /// Price is calculated automatically based on distance
  Future<Booking?> createRideBooking({
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    required double distanceKm,
    Object? pickupAddress,      // Phase 6: Accept Object? instead of dynamic for type safety
    Object? destinationAddress, // Phase 6: Accept Object? instead of dynamic for type safety
    String? notes,
    DateTime? scheduledAt,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) {
      debugLog('User not authenticated');
      return null;
    }

    try {
      // ✅ ฟังก์ชันช่วยแปลงที่อยู่ (Copy Logic มาจาก createFoodBooking)
      String formatAddress(dynamic addressInput) {
        if (addressInput == null) return '';
        String addrStr = addressInput.toString();
        
        // ถ้าเป็น Object หรือ String ที่มีคำว่า Instance of...
        if (addrStr.contains('AddressPlacemark') || addrStr.contains('Instance of')) {
          if (addressInput is Map) {
             final parts = <String>[];
             if (addressInput['address']?.toString().isNotEmpty == true) parts.add(addressInput['address']);
             if (addressInput['street']?.toString().isNotEmpty == true) parts.add(addressInput['street']);
             if (addressInput['locality']?.toString().isNotEmpty == true) parts.add(addressInput['locality']);
             return parts.isNotEmpty ? parts.join(', ') : 'Selected Location';
          }
          // ถ้าเป็น Object แต่ไม่ใช่ Map ให้คืนค่า Default (หรือชื่อสถานที่ถ้ามี)
          return 'Selected Location'; 
        }
        return addrStr; // ถ้าเป็น String ปกติก็คืนค่าเลย
      }

      final cleanPickup = formatAddress(pickupAddress);
      final cleanDest = formatAddress(destinationAddress);

      // Calculate price automatically
      final configService = SystemConfigService();
      await configService.fetchSettings();
      final calculatedPrice = await configService.calculateDeliveryFee(
        serviceType: 'ride',
        distanceKm: distanceKm,
      );

      debugLog('💰 Calculated ride price: $calculatedPrice THB');
      debugLog('📍 Cleaned Addresses -> Pickup: $cleanPickup, Dest: $cleanDest');

      final response = await _client.from('bookings').insert({
        'customer_id': userId,
        'service_type': 'ride',
        'origin_lat': originLat,
        'origin_lng': originLng,
        'dest_lat': destLat,
        'dest_lng': destLng,
        'distance_km': distanceKm,
        'price': calculatedPrice,
        'pickup_address': cleanPickup,      // ใช้ค่าที่ Clean แล้ว
        'destination_address': cleanDest,   // ใช้ค่าที่ Clean แล้ว
        'notes': notes,
        'status': 'pending',
        'payment_method': 'cash',
        'scheduled_at': scheduledAt?.toIso8601String(),
      }).select().single();

      final booking = Booking.fromJson(response);
      
      // Notify drivers
      debugLog('📤 Sending new ride booking notification to drivers...');
      await _notifyDriversAboutNewRide(booking);

      return booking;
    } catch (e) {
      debugLog('Failed to create ride booking: $e');
      return null;
    }
  }

  /// Create a new booking (unified method for all services)
  /// 
  /// Throws Exception if user is not authenticated or creation fails
  /// Price is calculated automatically based on service type and distance
  Future<Booking?> createBooking({
    required String customerId,
    required String serviceType,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String? pickupAddress,
    String? destinationAddress,
    String? merchantId,
    required double distanceKm,
    String? notes,
    String? paymentMethod,
    double? deliveryFee,
    DateTime? scheduledAt,
  }) async {
    try {
      double calculatedPrice;
      
      if (serviceType == 'food' && deliveryFee != null) {
        // For food orders, price should be food cost only (delivery fee stored separately)
        calculatedPrice = deliveryFee; // This will be overridden by the calling code
        debugLog('💰 Food order - delivery fee: $deliveryFee THB');
      } else {
        // Calculate price automatically for non-food orders
        final configService = SystemConfigService();
        await configService.fetchSettings();
        calculatedPrice = (await configService.calculateDeliveryFee(
          serviceType: serviceType,
          distanceKm: distanceKm,
        )).toDouble();
        debugLog('💰 Calculated $serviceType price: $calculatedPrice THB');
      }

      final response = await _client.from('bookings').insert({
        'customer_id': customerId,
        'service_type': serviceType,
        'merchant_id': merchantId,
        'origin_lat': originLat,
        'origin_lng': originLng,
        'pickup_address': pickupAddress,
        'dest_lat': destLat,
        'dest_lng': destLng,
        'destination_address': destinationAddress,
        'distance_km': distanceKm,
        'price': calculatedPrice,
        'delivery_fee': serviceType == 'food' ? deliveryFee : null,
        'notes': notes,
        'status': 'pending',
        'payment_method': paymentMethod ?? 'cash',
        'scheduled_at': scheduledAt?.toIso8601String(),
      }).select().single();

      return Booking.fromJson(response);
    } catch (e) {
      debugLog('Failed to create booking: $e');
      return null;
    }
  }

  /// Update booking status
  /// 
  /// Automatically handles financial logic when status is 'completed':
  /// - Food orders: Platform Fee (15% of delivery_fee) + Merchant GP (10% of food price)
  /// - Other orders: Standard commission deduction (from system_config)
  /// 
  /// Saves driver_earnings and app_earnings to booking record.
  Future<void> updateBookingStatus(
    String bookingId,
    String newStatus,
  ) async {
    debugLog('🔍 DEBUG: updateBookingStatus called');
    debugLog('   └─ Booking ID: $bookingId');
    debugLog('   └─ New Status: $newStatus');
    debugLog('   └─ Timestamp: ${DateTime.now()}');

    // Phase 4A: Authorization check — verify caller is involved in this booking
    final currentUserId = AuthService.userId;
    if (currentUserId == null) throw Exception('Not authenticated');

    final booking = await getBookingById(bookingId);
    if (booking == null) throw Exception('Booking not found');

    final isCustomer = booking.customerId == currentUserId;
    final isDriver = booking.driverId == currentUserId;
    final isMerchant = booking.merchantId == currentUserId;
    final callerRole = AuthService.currentUserRole;
    final isAdmin = callerRole == 'admin';

    if (!isCustomer && !isDriver && !isMerchant && !isAdmin) {
      throw Exception('ไม่มีสิทธิ์เปลี่ยนสถานะออเดอร์นี้');
    }

    // Update the booking status
    await _client
        .from('bookings')
        .update({'status': newStatus})
        .eq('id', bookingId);
    
    debugLog('✅ DEBUG: Booking status updated in database');

    // If job is completed, handle financial deductions
    if (newStatus == 'completed') {
      try {
        debugLog('🔍 DEBUG: Job completed, processing financial logic...');
        debugLog('   └─ Booking ID: $bookingId');
        
        // Fetch booking details
        final booking = await getBookingById(bookingId);
        debugLog('   └─ Booking data: ${booking?.toJson()}');
        
        if (booking == null || booking.driverId == null) {
          debugLog('❌ Missing required data for commission deduction:');
          debugLog('   └─ Booking exists: ${booking != null}');
          debugLog('   └─ Driver ID exists: ${booking?.driverId != null}');
          return;
        }

        final walletService = WalletService();

        if (booking.serviceType == 'food') {
          final configService = SystemConfigService();
          await configService.fetchSettings();
          final merchantFoodConfig = await _getMerchantFoodConfig(
            merchantId: booking.merchantId,
            configService: configService,
          );

          // ── Food Order Financial Logic ──
          // price = food cost (menu items total)
          // delivery_fee = delivery fee
          final foodPrice = booking.price;
          final deliveryFee = booking.deliveryFee ?? 0;
          final couponFinance = await _getFoodCouponFinanceContext(
            bookingId: bookingId,
            merchantId: booking.merchantId,
            deliveryFee: deliveryFee,
          );
          final applyFreeDeliveryAdjustment = couponFinance != null;

          debugLog('💰 Food Order Completion:');
          debugLog('   └─ Food Price: $foodPrice');
          debugLog('   └─ Delivery Fee: $deliveryFee');
          debugLog('   └─ Merchant mode: ${merchantFoodConfig.summary}');
          if (applyFreeDeliveryAdjustment) {
            debugLog('   └─ Applying merchant free-delivery GP split');
          }

          final result = await walletService.deductFoodCommission(
            driverId: booking.driverId!,
            deliveryFee: deliveryFee,
            foodPrice: foodPrice,
            bookingId: bookingId,
            deliverySystemRateOverride: merchantFoodConfig.deliverySystemRate,
            merchantGpSystemRateOverride: merchantFoodConfig.merchantGpSystemRate,
            merchantGpDriverRateOverride: merchantFoodConfig.merchantGpDriverRate,
            applyMerchantFreeDeliveryAdjustment: applyFreeDeliveryAdjustment,
            merchantFreeDeliveryChargeRate: couponFinance?['chargeRate'] ?? 0.25,
            merchantFreeDeliverySystemRate: couponFinance?['systemRate'] ?? 0.10,
            merchantFreeDeliveryDriverRate: couponFinance?['driverRate'] ?? 0.15,
          );

          if (result != null) {
            // Update booking with earnings breakdown
            await _client.from('bookings').update({
              'driver_earnings': result['driverNetIncome'],
              'app_earnings': result['appEarnings'] ?? result['totalDeduction'],
            }).eq('id', bookingId);

            debugLog('✅ Food commission deducted & earnings saved:');
            debugLog('   └─ Delivery System Fee: ${result['deliverySystemFee'] ?? result['platformFee']}');
            debugLog('   └─ Merchant GP (System): ${result['merchantSystemGP'] ?? result['merchantGP']}');
            debugLog('   └─ Merchant GP (Driver): ${result['merchantDriverGP'] ?? 0}');
            debugLog('   └─ Total Deduction: ${result['totalDeduction']}');
            debugLog('   └─ Driver Net Income: ${result['driverNetIncome']}');
          } else {
            debugLog('❌ Food commission deduction failed for job: $bookingId');
          }
        } else {
          // ── Ride/Parcel: Standard commission logic ──
          debugLog('   └─ Driver ID: ${booking.driverId}');
          debugLog('   └─ Job Price: ${booking.price}');

          final success = await walletService.deductCommission(
            driverId: booking.driverId!,
            jobPrice: booking.price.toInt(),
            bookingId: bookingId,
          );

          if (success) {
            // Calculate and save earnings for ride/parcel
            final configService = SystemConfigService();
            await configService.fetchSettings();
            final commission = configService.calculateCommission(booking.price.toInt());
            final driverNet = booking.price - commission;

            await _client.from('bookings').update({
              'driver_earnings': driverNet,
              'app_earnings': commission,
            }).eq('id', bookingId);

            debugLog('✅ Commission deducted for completed job: $bookingId');
            debugLog('   └─ Commission: $commission');
            debugLog('   └─ Driver Net: $driverNet');
          } else {
            debugLog('❌ Commission deduction failed for job: $bookingId');
          }
        }
      } catch (e) {
        debugLog('❌ ERROR: Failed to process completion financials: $e');
        debugLog('   └─ Stack trace: ${StackTrace.current}');
      }
    }
  }

  /// Cancel booking
  /// Phase 4B: Added authorization check — only the customer who created the
  /// booking (or admin) can cancel, and only from cancellable statuses.
  Future<void> cancelBooking(String bookingId, {String? reason}) async {
    final currentUserId = AuthService.userId;
    if (currentUserId == null) throw Exception('Not authenticated');

    final booking = await getBookingById(bookingId);
    if (booking == null) throw Exception('Booking not found');

    // Check ownership
    final isOwner = booking.customerId == currentUserId;
    final isAdmin = AuthService.currentUserRole == 'admin';
    if (!isOwner && !isAdmin) {
      throw Exception('ไม่มีสิทธิ์ยกเลิกออเดอร์นี้');
    }

    // Check cancellable status
    const cancellableStatuses = ['pending', 'pending_merchant', 'preparing'];
    if (!cancellableStatuses.contains(booking.status) && !isAdmin) {
      throw Exception('ไม่สามารถยกเลิกออเดอร์ที่สถานะ ${booking.status} ได้');
    }

    await _client.from('bookings').update({
      'status': 'cancelled',
      'notes': reason,
    }).eq('id', bookingId);
  }

  /// Get pending bookings (for drivers)
  /// Phase 4D: Fixed filter — drivers should NOT see pending_merchant or
  /// preparing orders. They should only see:
  /// - 'pending' (ride/parcel ready for pickup)
  /// - 'ready_for_pickup' (food orders where merchant finished preparing)
  Future<List<Booking>> getPendingBookings() async {
      final response = await _client
          .from('bookings')
          .select()
          .filter('driver_id', 'is', 'null')
          .or('status.in.(pending,ready_for_pickup)')
          .order('created_at', ascending: false)
          .limit(50);

    return (response as List)
        .map((json) => Booking.fromJson(json))
        .toList();
  }

  /// Accept booking (for drivers)
  /// 
  /// Checks wallet balance before allowing driver to accept job.
  /// For food orders: calculates estimated deduction (Platform Fee 15% + Merchant GP 10%)
  /// and checks if driver has enough balance.
  /// For other orders: checks against minimum wallet threshold.
  Future<void> acceptBooking(String bookingId) async {
    final driverId = AuthService.userId;
    if (driverId == null) throw Exception('Driver not authenticated');

    // Fetch the booking first to check service_type and amounts
    final booking = await getBookingById(bookingId);
    if (booking == null) {
      throw Exception('Booking not found');
    }

    if (booking.scheduledAt != null && booking.scheduledAt!.isAfter(DateTime.now())) {
      throw Exception(
        'งานนี้ตั้งเวลารับไว้ที่ ${_formatScheduledDateTime(booking.scheduledAt!)} ยังไม่สามารถรับงานได้',
      );
    }

    // ── Risk Prevention: Per-job wallet balance check ──
    final walletService = WalletService();

    final updates = <String, dynamic>{};

    if (booking.serviceType == 'food') {
      // Food order: check against estimated deduction
      var deliveryFee = booking.deliveryFee ?? 0;
      final foodPrice = booking.price; // price field = food cost for food orders

      final foodPickupSurcharge = await FareAdjustmentService
          .calculateFoodFarPickupSurcharge(
        merchantId: booking.merchantId ?? '',
        driverId: driverId,
        merchantLat: booking.originLat,
        merchantLng: booking.originLng,
      );
      if (foodPickupSurcharge > 0) {
        deliveryFee += foodPickupSurcharge;
        updates['delivery_fee'] = deliveryFee;
      }

      // ตรวจสอบให้แน่ใจว่ามีข้อมูล config
      final configService = SystemConfigService();
      await configService.fetchSettings();
      final merchantFoodConfig = await _getMerchantFoodConfig(
        merchantId: booking.merchantId,
        configService: configService,
      );

      final couponFinance = await _getFoodCouponFinanceContext(
        bookingId: booking.id,
        merchantId: booking.merchantId,
        deliveryFee: deliveryFee,
      );
      
      var estimatedDeduction = WalletService.estimateFoodDeduction(
        deliveryFee: deliveryFee,
        foodPrice: foodPrice,
        deliverySystemRate: merchantFoodConfig.deliverySystemRate,
        merchantGpSystemRate: merchantFoodConfig.merchantGpSystemRate,
      );
      var extraCouponDeduction = 0.0;
      if (couponFinance != null) {
        extraCouponDeduction =
            (foodPrice * (couponFinance['systemRate'] ?? 0.10)).ceilToDouble();
        estimatedDeduction += extraCouponDeduction;
      }

      debugLog('🔍 Food job acceptance check:');
      debugLog('   └─ Delivery Fee: $deliveryFee');
      debugLog('   └─ Food Price: $foodPrice');
      debugLog('   └─ Merchant mode: ${merchantFoodConfig.summary}');
      debugLog('   └─ Far pickup surcharge: $foodPickupSurcharge');
      debugLog('   └─ Estimated Deduction: $estimatedDeduction');

      final canAccept = await walletService.canAcceptFoodJob(
        driverId: driverId,
        deliveryFee: deliveryFee,
        foodPrice: foodPrice,
        extraEstimatedDeduction: extraCouponDeduction,
        deliverySystemRateOverride: merchantFoodConfig.deliverySystemRate,
        merchantGpSystemRateOverride: merchantFoodConfig.merchantGpSystemRate,
      );

      if (!canAccept) {
        throw Exception(
          'ยอดเงินในกระเป๋าไม่เพียงพอ ค่าหักโดยประมาณ ฿${estimatedDeduction.ceil()} กรุณาเติมเงิน',
        );
      }
    } else {
      // Ride/Parcel: check against minimum wallet threshold
      final canAccept = await walletService.canAcceptJob(driverId);
      if (!canAccept) {
        final configService = SystemConfigService();
        await configService.fetchSettings();
        final minWallet = configService.driverMinWallet;
        throw Exception('ยอดเงินในกระเป๋าไม่พอรับงานนี้ กรุณาเติมเงินอย่างน้อย $minWallet บาท');
      }

      if (booking.serviceType == 'ride') {
        final config = await FareAdjustmentService.loadRideFarPickupConfig();
        final distanceKm = await FareAdjustmentService.getDriverToPickupDistanceKm(
          driverId: driverId,
          pickupLat: booking.originLat,
          pickupLng: booking.originLng,
        );
        if (distanceKm != null) {
          final surcharge = FareAdjustmentService.calculateRideFarPickupSurcharge(
            driverToPickupDistanceKm: distanceKm,
            vehicleType: booking.notes ?? booking.serviceType,
            config: config,
          );
          if (surcharge > 0) {
            final adjustedPrice = booking.price + surcharge;
            updates['price'] = adjustedPrice;
            updates['notes'] =
                '${booking.notes ?? ''} | ปรับราคาเพิ่มจากระยะคนขับ→จุดรับ ${distanceKm.toStringAsFixed(2)} กม. (+฿${surcharge.toStringAsFixed(2)})';
          }
        }
      }
    }

    // Determine new status based on service_type
    String newStatus;
    if (booking.serviceType == 'food') {
      newStatus = 'driver_accepted';
    } else if (booking.serviceType == 'ride') {
      newStatus = 'accepted';
    } else {
      newStatus = 'accepted'; // Default fallback
    }

    // Optimistic concurrency: use RPC to atomically claim the booking (Phase 2)
    // Only succeeds if booking still has no driver and expected status
    final expectedStatus = booking.status;
    final rpcResult = await _client.rpc('accept_booking', params: {
      'p_booking_id': bookingId,
      'p_driver_id': driverId,
      'p_expected_status': expectedStatus,
    });
    if (rpcResult is Map && rpcResult['success'] != true) {
      throw Exception(rpcResult['message'] ?? 'งานนี้ถูกรับไปแล้ว');
    }

    // Apply additional updates (surcharge, etc.) if any
    if (updates.isNotEmpty) {
      await _client.from('bookings').update(updates).eq('id', bookingId);
    }
    
    debugLog('✅ Driver accepted job: $bookingId with status: $newStatus');
  }

  String _formatScheduledDateTime(DateTime scheduledAt) {
    final local = scheduledAt.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  /// Create a new food booking
  /// 
  /// Creates a booking with service_type='food' and status='pending_merchant'
  /// Price is calculated automatically based on distance
  Future<Booking?> createFoodBooking({
    required String merchantId,
    required double merchantLat,
    required double merchantLng,
    required double customerLat,
    required double customerLng,
    required double distanceKm,
    String? merchantAddress,
    String? customerAddress,
    String? notes,
    required double foodCost,
    required double deliveryFee,
    DateTime? scheduledAt,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) {
      debugLog('User not authenticated');
      return null;
    }

    try {
      debugLog('💰 Food order - food cost: $foodCost THB, delivery fee: $deliveryFee THB');
      debugLog('💰 Total: ${foodCost + deliveryFee} THB');

      // Format customer address to readable string
      String formattedCustomerAddress = '';
      if (customerAddress != null) {
        formattedCustomerAddress = customerAddress.toString();
      } else {
        formattedCustomerAddress = 'Current Location';
      }
      
      debugLog('📍 Address formatting:');
      debugLog('   └─ Original: $customerAddress');
      debugLog('   └─ Formatted: $formattedCustomerAddress');

      final bookingData = {
        'customer_id': userId,
        'service_type': 'food',
        'merchant_id': merchantId,
        'origin_lat': merchantLat,
        'origin_lng': merchantLng,
        'pickup_address': merchantAddress,
        'dest_lat': customerLat,
        'dest_lng': customerLng,
        'destination_address': formattedCustomerAddress,
        'distance_km': distanceKm,
        'price': foodCost, // Store food cost in price field
        'delivery_fee': deliveryFee, // Store delivery fee separately
        'notes': notes,
        'status': 'pending_merchant',
        'payment_method': 'cash',
        'scheduled_at': scheduledAt?.toIso8601String(),
      };
      
      debugLog('📝 Inserting booking data:');
      debugLog('   └─ price (food cost): ฿$foodCost');
      debugLog('   └─ delivery_fee: ฿$deliveryFee');
      debugLog('   └─ service_type: food');
      debugLog('   └─ status: pending_merchant');
      
      final response = await _client.from('bookings').insert(bookingData).select().single();

      return Booking.fromJson(response);
    } catch (e) {
      debugLog('Failed to create food booking: $e');
      return null;
    }
  }

  /// Insert booking items for food orders
  /// DB columns: booking_id, menu_item_id, name, price, quantity
  Future<void> insertBookingItems(String bookingId, List<Map<String, dynamic>> items) async {
    try {
      final bookingItems = items.map((item) => {
        'booking_id': bookingId,
        'menu_item_id': item['id'],
        'name': item['name'],
        'price': item['price'],
        'quantity': item['quantity'] ?? 1,
      }).toList();

      await _client.from('booking_items').insert(bookingItems);
      debugLog('Successfully inserted ${bookingItems.length} booking items');
    } catch (e) {
      debugLog('Failed to insert booking items: $e');
      throw Exception('Failed to insert booking items: $e');
    }
  }

  /// Notify available drivers about new ride booking
  Future<void> _notifyDriversAboutNewRide(Booking booking) async {
    try {
      debugLog('🔍 DEBUG: Notifying drivers about new ride booking');
      debugLog('   └─ Booking ID: ${booking.id}');
      debugLog('   └─ Service Type: ${booking.serviceType}');
      debugLog('   └─ Price: ${booking.price}');
      debugLog('   └─ Pickup: ${booking.pickupAddress}');
      debugLog('   └─ Destination: ${booking.destinationAddress}');
      
      // Get all available drivers (drivers with FCM tokens)
      final driversResponse = await _client
          .from('profiles')
          .select('id, email, fcm_token')
          .eq('role', 'driver')
          .not('fcm_token', 'is', null);
      
      debugLog('📊 Found ${driversResponse.length} drivers with FCM tokens');
      
      if (driversResponse.isEmpty) {
        debugLog('⚠️ No drivers found with FCM tokens');
        return;
      }
      
      int successCount = 0;
      int failCount = 0;
      
      for (final driver in driversResponse) {
        final driverId = driver['id'] as String;
        final driverToken = driver['fcm_token'] as String?;
        
        if (driverToken != null && driverToken.isNotEmpty) {
          debugLog('📤 Sending notification to driver: ${driver['email']}');
          
          final success = await NotificationSender.sendNotification(
            targetUserId: driverId,
            title: '🚨 งานใหม่! รับส่งผู้โดยสาร',
            body: 'มีคนเรียกรถจาก ${booking.pickupAddress ?? 'จุดเริ่มต้น'} ไป ${booking.destinationAddress ?? 'จุดหมาย'} - ราคา ฿${booking.price}',
            data: {
              'type': 'new_booking',
              'booking_id': booking.id,
              'customer_id': booking.customerId,
              'service_type': booking.serviceType,
              'origin_lat': booking.originLat.toString(),
              'origin_lng': booking.originLng.toString(),
              'dest_lat': booking.destLat.toString(),
              'dest_lng': booking.destLng.toString(),
              'price': booking.price.toString(),
              'pickup_address': booking.pickupAddress ?? '',
              'destination_address': booking.destinationAddress ?? '',
              'distance_km': booking.distanceKm.toString(),
            },
          );
          
          if (success) {
            successCount++;
            debugLog('✅ Notification sent successfully to: ${driver['email']}');
          } else {
            failCount++;
            debugLog('❌ Failed to send notification to: ${driver['email']}');
          }
        } else {
          failCount++;
          debugLog('❌ Driver ${driver['email']} has no FCM token');
        }
      }
      
      debugLog('📊 Notification summary:');
      debugLog('   └─ Total drivers: ${driversResponse.length}');
      debugLog('   └─ Successful: $successCount');
      debugLog('   └─ Failed: $failCount');
      
    } catch (e) {
      debugLog('❌ Error notifying drivers: $e');
      debugLog('   └─ Stack trace: ${StackTrace.current}');
    }
  }

  /// Subscribe to booking updates (Real-time)
  Stream<Booking?> subscribeToBooking(String bookingId) {
    return _client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('id', bookingId)
        .map((data) {
      if (data.isEmpty) return null;
      return Booking.fromJson(data.first);
    });
  }
}
