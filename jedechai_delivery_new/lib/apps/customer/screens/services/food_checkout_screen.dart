import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../../common/config/env_config.dart';
import '../../../../common/services/geocoding_service.dart';
import '../../../../common/services/notification_sender.dart';
import '../../../../theme/app_theme.dart';
import '../../providers/cart_provider.dart';
import 'delivery_map_picker_screen.dart';
import '../../../../common/widgets/coupon_entry_widget.dart';
import '../../../../common/models/coupon.dart';
import '../../../../common/services/coupon_service.dart';
import '../../../../common/services/merchant_food_config_service.dart';
import '../../../../common/services/system_config_service.dart';
import '../../../../common/utils/platform_adaptive.dart';
import 'saved_addresses_screen.dart';
import '../../../../common/models/saved_address.dart';

/// Food Checkout Screen — หน้ายืนยันคำสั่งซื้อ
///
/// แสดงรายการอาหาร, ที่อยู่จัดส่ง (ตำแหน่งปัจจุบัน/ปักหมุด),
/// คำนวณค่าส่งจากระยะทางจริง, วิธีชำระเงิน, สรุปราคา
class FoodCheckoutScreen extends StatefulWidget {
  const FoodCheckoutScreen({super.key});

  @override
  State<FoodCheckoutScreen> createState() => _FoodCheckoutScreenState();
}

class _FoodCheckoutScreenState extends State<FoodCheckoutScreen> {
  bool _isPlacingOrder = false;
  bool _isCalculatingFee = true;
  String _paymentMethod = 'cash';
  final TextEditingController _noteController = TextEditingController();
  bool _isScheduledOrder = false;
  DateTime? _scheduledAt;

  // ── ข้อมูลตำแหน่ง ──
  // 'current' = ตำแหน่งปัจจุบัน, 'pin' = ปักหมุดบนแผนที่
  String _deliveryMode = 'current';
  double? _customerLat;
  double? _customerLng;
  String _customerAddress = 'ตำแหน่งปัจจุบัน';

  // ── ข้อมูลร้านค้า ──
  double? _merchantLat;
  double? _merchantLng;

  // ── ค่าส่ง + ระยะทาง ──
  double _distanceKm = 0;
  double _deliveryFee = 0;

  // ── คูปอง ──
  Coupon? _appliedCoupon;
  double _couponDiscount = 0;

  bool get _hideCouponBreakdown {
    final code = _appliedCoupon?.code.trim().toUpperCase();
    if (code == null || code.isEmpty) return false;
    return code == 'WELCOME20' || code == 'REFERRER20' || code == 'REFFERER20';
  }

  // ── อัตราค่าส่ง (โหลดจาก service_rates table — อาจถูก override โดยค่าเฉพาะร้าน) ──
  double _baseFare = 15.0; // ค่าเริ่มต้น (fallback)
  double _baseDistance = 2.0; // ระยะเริ่มต้น (กม.) (fallback)
  double _perKmCharge = 10.0; // ต่อ กม. (fallback)
  double _minDeliveryFee = 15.0;
  double _maxDeliveryRadius = 20.0;
  bool _distanceWarningShown = false;
  MerchantFoodConfig? _merchantFoodConfig;

  double _calculateFinalTotal(double subtotal, double deliveryFee) {
    final total = subtotal + deliveryFee - _couponDiscount;
    return total < 0 ? 0 : total;
  }

  @override
  void initState() {
    super.initState();
    _initLocationAndFee();
  }

  Widget _buildScheduleOptionTile({
    required IconData icon,
    required String label,
    required String subtitle,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.orange.withValues(alpha: 0.08)
              : colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppTheme.accentOrange : colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(icon,
                color: isSelected ? AppTheme.accentOrange : colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            if (isSelected)
              const Icon(Icons.check_circle,
                  color: AppTheme.accentOrange, size: 20),
          ],
        ),
      ),
    );
  }

  String _formatScheduledDateTime(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy HH:mm', 'th_TH').format(dateTime.toLocal());
  }

  Future<void> _pickScheduledDateTime() async {
    final now = DateTime.now();
    final initialDate =
        (_scheduledAt ?? now.add(const Duration(hours: 1))).toLocal();
    final firstDate = DateTime(now.year, now.month, now.day);
    final lastDate = firstDate.add(const Duration(days: 14));

    final pickedDate = await PlatformAdaptive.pickDate(
      context: context,
      initialDate: initialDate,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('th', 'TH'),
      title: 'เลือกวันที่จัดส่ง',
    );

    if (pickedDate == null) return;

    final pickedTime = await PlatformAdaptive.pickTime(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initialDate),
      title: 'เลือกเวลาจัดส่ง',
    );

    if (pickedTime == null) return;

    final selected = DateTime(
      pickedDate.year,
      pickedDate.month,
      pickedDate.day,
      pickedTime.hour,
      pickedTime.minute,
    );

    if (selected.isBefore(now.add(const Duration(minutes: 20)))) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('กรุณาเลือกเวลาอย่างน้อย 20 นาทีจากเวลาปัจจุบัน'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (!mounted) return;
    setState(() {
      _isScheduledOrder = true;
      _scheduledAt = selected;
    });
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  /// โหลดตำแหน่งลูกค้า + ร้านค้า แล้วคำนวณค่าส่ง
  Future<void> _initLocationAndFee() async {
    setState(() => _isCalculatingFee = true);

    // 0. โหลดอัตราค่าส่งจาก service_rates
    await _loadFoodRatesFromConfig();

    // 1. ดึงตำแหน่งร้านค้า
    await _fetchMerchantLocation();

    // 2. ดึงตำแหน่งปัจจุบันลูกค้า
    await _fetchCurrentLocation();

    // 3. คำนวณค่าส่ง
    await _calculateDeliveryFee();

    if (mounted) setState(() => _isCalculatingFee = false);

    // 4. ตรวจสอบระยะทางเกินรัศมีที่กำหนด
    if (mounted && _distanceKm > _maxDeliveryRadius && !_distanceWarningShown) {
      _distanceWarningShown = true;
      _showDistanceWarningDialog();
    }
  }

  /// โหลดอัตราค่าส่งจาก service_rates table (ค่าที่ admin ตั้งไว้)
  Future<void> _loadFoodRatesFromConfig() async {
    try {
      final configService = SystemConfigService();
      await configService.fetchSettings();
      _maxDeliveryRadius = configService.customerToMerchantRadiusKm;
      final rate = configService.getServiceRate('food');
      if (rate != null) {
        _baseFare = rate.basePrice.toDouble();
        _baseDistance = rate.baseDistance.toDouble();
        _perKmCharge = rate.pricePerKm.toDouble();
        _minDeliveryFee = rate.basePrice.toDouble();
        debugLog(
            '📊 Loaded food rates from DB: base=฿$_baseFare for ${_baseDistance}km, perKm=฿$_perKmCharge');
      } else {
        debugLog(
            '⚠️ No food rate in DB, using defaults: base=฿$_baseFare, perKm=฿$_perKmCharge');
      }
      debugLog('📏 Customer-to-merchant radius: ${_maxDeliveryRadius}km');
    } catch (e) {
      debugLog('⚠️ Error loading food rates: $e (using defaults)');
    }
  }

  Future<void> _fetchMerchantLocation() async {
    try {
      final cart = context.read<CartProvider>();
      final merchantId = cart.merchantId;
      if (merchantId == null) return;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select(
              'latitude, longitude, shop_address, gp_rate, merchant_gp_system_rate, merchant_gp_driver_rate, custom_delivery_fee, custom_service_fee, custom_base_fare, custom_base_distance, custom_per_km')
          .eq('id', merchantId)
          .maybeSingle();

      if (profile != null) {
        _merchantLat = (profile['latitude'] as num?)?.toDouble();
        _merchantLng = (profile['longitude'] as num?)?.toDouble();
        debugLog('📍 Merchant location: $_merchantLat, $_merchantLng');

        final configService = SystemConfigService();
        await configService.fetchSettings();
        _merchantFoodConfig = MerchantFoodConfigService.resolve(
          merchantProfile: profile,
          defaultMerchantSystemRate: configService.merchantGpRate,
          defaultMerchantDriverRate: 0.0,
          defaultDeliverySystemRate: configService.platformFeeRate,
        );

        final merchantConfig = _merchantFoodConfig!;
        debugLog('🏠 Merchant food config: ${merchantConfig.summary}');

        if (merchantConfig.baseFare != null) {
          _baseFare = merchantConfig.baseFare!;
          _minDeliveryFee = merchantConfig.baseFare!;
          debugLog('🏠 Merchant base fare: ฿${merchantConfig.baseFare}');
        }
        if (merchantConfig.baseDistanceKm != null) {
          _baseDistance = merchantConfig.baseDistanceKm!;
          debugLog('🏠 Merchant base distance: ${merchantConfig.baseDistanceKm}km');
        }
        if (merchantConfig.perKmCharge != null) {
          _perKmCharge = merchantConfig.perKmCharge!;
          debugLog('🏠 Merchant per-km: ฿${merchantConfig.perKmCharge}');
        }
        if (merchantConfig.fixedDeliveryFee != null) {
          // Fixed delivery fee overrides distance-based calculation
          _baseFare = merchantConfig.fixedDeliveryFee!;
          _perKmCharge = 0;
          _minDeliveryFee = merchantConfig.fixedDeliveryFee!;
          debugLog(
            '🏠 Merchant fixed delivery fee: ฿${merchantConfig.fixedDeliveryFee} (ignores distance)',
          );
        }

        final customServiceFee =
            (profile['custom_service_fee'] as num?)?.toDouble();
        if (customServiceFee != null) {
          debugLog('🏠 Merchant custom service fee: ฿$customServiceFee');
        }
      }
    } catch (e) {
      debugLog('❌ Error fetching merchant location: $e');
    }
  }

  Future<void> _fetchCurrentLocation() async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      _customerLat = position.latitude;
      _customerLng = position.longitude;
      debugLog('📍 Customer location: $_customerLat, $_customerLng');

      // Reverse geocode to get actual address
      try {
        final addr = await GeocodingService.getAddressFromCoordinates(
          position.latitude,
          position.longitude,
        );
        _customerAddress = addr ?? 'ตำแหน่งปัจจุบัน';
        debugLog('📍 Reverse geocoded address: $_customerAddress');
      } catch (_) {
        _customerAddress = 'ตำแหน่งปัจจุบัน';
      }
    } catch (e) {
      debugLog('⚠️ Cannot get current location: $e');
      _customerLat = 13.7563;
      _customerLng = 100.5018;
      _customerAddress = 'ตำแหน่งปัจจุบัน (ไม่สามารถระบุได้)';
    }
  }

  /// คำนวณค่าส่งจากระยะทางจริง (Google Directions API)
  Future<void> _calculateDeliveryFee() async {
    if (_merchantLat == null ||
        _merchantLng == null ||
        _customerLat == null ||
        _customerLng == null) {
      // ไม่มีพิกัด → ใช้ค่าเริ่มต้น
      _distanceKm = 3.0;
      _deliveryFee = _calculateFeeFromDistance(_distanceKm);
      return;
    }

    try {
      final apiKey = EnvConfig.googleMapsApiKey;
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=$_merchantLat,$_merchantLng'
        '&destination=$_customerLat,$_customerLng'
        '&mode=driving'
        '&key=$apiKey',
      );

      debugLog('🗺️ Calculating real distance: merchant → customer');
      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK' && (data['routes'] as List).isNotEmpty) {
        final leg = (data['routes'][0]['legs'] as List)[0];
        final distanceMeters = leg['distance']['value'] as int;
        _distanceKm = distanceMeters / 1000.0;
        debugLog('✅ Real road distance: ${_distanceKm.toStringAsFixed(2)} km');
      } else {
        // Fallback: straight-line
        _distanceKm = Geolocator.distanceBetween(
              _merchantLat!,
              _merchantLng!,
              _customerLat!,
              _customerLng!,
            ) /
            1000.0;
        debugLog(
            '⚠️ Directions API failed, using straight-line: ${_distanceKm.toStringAsFixed(2)} km');
      }
    } catch (e) {
      debugLog('❌ Distance calculation error: $e');
      _distanceKm = Geolocator.distanceBetween(
            _merchantLat!,
            _merchantLng!,
            _customerLat!,
            _customerLng!,
          ) /
          1000.0;
    }

    // คำนวณค่าส่ง (สูตรเดียวกับ SystemConfigService.calculateDeliveryFee)
    _deliveryFee = _calculateFeeFromDistance(_distanceKm);

    debugLog(
        '💰 Delivery fee: ฿$_deliveryFee (distance: ${_distanceKm.toStringAsFixed(2)} km)');
  }

  /// คำนวณค่าส่งจากระยะทาง (สูตรเดียวกับ SystemConfigService.calculateDeliveryFee)
  /// ถ้าระยะทาง <= baseDistance → baseFare
  /// ถ้าระยะทาง > baseDistance → baseFare + (extraKm * perKmCharge)
  double _calculateFeeFromDistance(double distanceKm) {
    double fee;
    if (distanceKm <= _baseDistance) {
      fee = _baseFare;
    } else {
      final extraKm = distanceKm - _baseDistance;
      fee = _baseFare + (extraKm * _perKmCharge);
    }
    if (fee < _minDeliveryFee) fee = _minDeliveryFee;
    return double.parse(fee.toStringAsFixed(0));
  }

  void _showDistanceWarningDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(Icons.warning_amber_rounded,
            color: Colors.orange[700], size: 48),
        title: const Text(
          'อยู่นอกระยะทางที่กำหนด',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'ตำแหน่งจัดส่งของคุณอยู่ห่างจากร้านค้า ${_distanceKm.toStringAsFixed(1)} กม.\n'
              'ซึ่งเกินระยะเริ่มต้นที่กำหนดไว้ ${_maxDeliveryRadius.toStringAsFixed(0)} กม.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(Icons.delivery_dining,
                      color: Colors.orange[700], size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'ค่าส่งจะคิดตามระยะทางจริง: ฿${_deliveryFee.ceil()}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.orange[800],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange[700],
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text('รับทราบ', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  /// เปิดหน้าปักหมุดบนแผนที่
  Future<void> _openMapPicker() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(
        builder: (_) => DeliveryMapPickerScreen(
          initialPosition: _customerLat != null && _customerLng != null
              ? LatLng(_customerLat!, _customerLng!)
              : null,
        ),
      ),
    );

    if (result != null) {
      setState(() {
        _deliveryMode = 'pin';
        _customerLat = result['lat'] as double;
        _customerLng = result['lng'] as double;
        _customerAddress = result['address'] as String;
        _isCalculatingFee = true;
      });

      await _calculateDeliveryFee();
      if (mounted) setState(() => _isCalculatingFee = false);

      // ตรวจสอบระยะทางเกินรัศมี
      if (mounted && _distanceKm > _maxDeliveryRadius) {
        _showDistanceWarningDialog();
      }
    }
  }

  /// เปลี่ยนกลับเป็นตำแหน่งปัจจุบัน
  Future<void> _useCurrentLocation() async {
    setState(() {
      _deliveryMode = 'current';
      _isCalculatingFee = true;
    });

    await _fetchCurrentLocation();
    await _calculateDeliveryFee();

    if (mounted) setState(() => _isCalculatingFee = false);

    // ตรวจสอบระยะทางเกินรัศมี
    if (mounted && _distanceKm > _maxDeliveryRadius) {
      _showDistanceWarningDialog();
    }
  }

  /// เปิดหน้าเลือกที่อยู่ที่บันทึกไว้
  Future<void> _openSavedAddresses() async {
    final result = await Navigator.of(context).push<SavedAddress>(
      MaterialPageRoute(
        builder: (_) => const SavedAddressesScreen(pickMode: true),
      ),
    );

    if (result != null) {
      setState(() {
        _deliveryMode = 'saved';
        _customerLat = result.latitude;
        _customerLng = result.longitude;
        _customerAddress = '${result.name} — ${result.address}';
        _isCalculatingFee = true;
      });

      await _calculateDeliveryFee();
      if (mounted) setState(() => _isCalculatingFee = false);

      // ตรวจสอบระยะทางเกินรัศมี
      if (mounted && _distanceKm > _maxDeliveryRadius) {
        _showDistanceWarningDialog();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CartProvider>(
      builder: (context, cart, _) {
        final colorScheme = Theme.of(context).colorScheme;
        return Scaffold(
          backgroundColor: colorScheme.surface,
          appBar: AppBar(
            title: const Text('ยืนยันคำสั่งซื้อ'),
            backgroundColor: AppTheme.accentOrange,
            foregroundColor: Colors.white,
            elevation: 0,
          ),
          body: cart.isEmpty
              ? const Center(child: Text('ตะกร้าว่างเปล่า'))
              : SingleChildScrollView(
                  child: Column(
                    children: [
                      // Restaurant info
                      _buildSection(
                        icon: Icons.store,
                        title: 'ร้านอาหาร',
                        child: Text(cart.merchantName ?? '',
                            style: const TextStyle(fontSize: 15)),
                      ),
                      // ── ที่อยู่จัดส่ง (เลือกได้ 2 แบบ) ──
                      _buildSection(
                        icon: Icons.location_on,
                        title: 'ที่อยู่จัดส่ง',
                        child: _buildDeliveryAddressSelector(),
                      ),
                      // Order items
                      _buildSection(
                        icon: Icons.receipt_long,
                        title: 'รายการอาหาร (${cart.totalItems} รายการ)',
                        child: Column(
                          children: cart.items.map((item) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Text('${item.quantity}x',
                                      style: TextStyle(
                                          color: AppTheme.accentOrange,
                                          fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(item.name,
                                            style:
                                                const TextStyle(fontSize: 14)),
                                        if (item.selectedOptions.isNotEmpty)
                                          Text(
                                            item.selectedOptions.join(', '),
                                            style: TextStyle(
                                                fontSize: 12,
                                                color: colorScheme.onSurfaceVariant),
                                          ),
                                      ],
                                    ),
                                  ),
                                  Text('฿${item.totalPrice.ceil()}'),
                                ],
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                      // Note
                      _buildSection(
                        icon: Icons.schedule,
                        title: 'เวลาจัดส่ง',
                        child: Column(
                          children: [
                            _buildScheduleOptionTile(
                              icon: Icons.flash_on,
                              label: 'จัดส่งทันที',
                              subtitle:
                                  'ร้านจะเริ่มเตรียมอาหารทันทีหลังยืนยันออเดอร์',
                              isSelected: !_isScheduledOrder,
                              onTap: () {
                                setState(() {
                                  _isScheduledOrder = false;
                                  _scheduledAt = null;
                                });
                              },
                            ),
                            const SizedBox(height: 8),
                            _buildScheduleOptionTile(
                              icon: Icons.calendar_today,
                              label: 'ตั้งเวลาจัดส่ง',
                              subtitle: _scheduledAt == null
                                  ? 'เลือกวันและเวลาที่ต้องการรับอาหาร'
                                  : 'กำหนดไว้: ${_formatScheduledDateTime(_scheduledAt!)}',
                              isSelected: _isScheduledOrder,
                              onTap: () async {
                                setState(() => _isScheduledOrder = true);
                                await _pickScheduledDateTime();
                              },
                            ),
                          ],
                        ),
                      ),

                      _buildSection(
                        icon: Icons.note_alt_outlined,
                        title: 'หมายเหตุถึงร้าน',
                        child: TextField(
                          controller: _noteController,
                          decoration: InputDecoration(
                            hintText: 'เช่น ไม่ใส่ผัก, เผ็ดน้อย...',
                            hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                          maxLines: 2,
                        ),
                      ),
                      // Payment method
                      _buildSection(
                        icon: Icons.payment,
                        title: 'วิธีชำระเงิน',
                        child: Column(
                          children: [
                            _buildPaymentOption('cash', 'เงินสด', Icons.money),
                            _buildPaymentOption(
                                'transfer', 'โอนเงิน', Icons.account_balance),
                          ],
                        ),
                      ),
                      // ── คูปองส่วนลด ──
                      _buildSection(
                        icon: Icons.local_offer,
                        title: 'โค้ดส่วนลด',
                        child: CouponEntryWidget(
                          serviceType: 'food',
                          orderAmount: cart.subtotal,
                          deliveryFee: _deliveryFee,
                          merchantId: cart.merchantId,
                          onCouponApplied: (coupon) {
                            setState(() => _appliedCoupon = coupon);
                          },
                          onDiscountChanged: (discount) {
                            setState(() => _couponDiscount = discount);
                          },
                        ),
                      ),
                      // ── สรุปราคา ──
                      _buildPriceSummary(cart),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
          bottomNavigationBar: cart.isEmpty
              ? null
              : Container(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainer,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, -2),
                      ),
                    ],
                  ),
                  child: SafeArea(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: (_isPlacingOrder || _isCalculatingFee)
                            ? null
                            : () => _placeOrder(context, cart),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14)),
                          elevation: 0,
                        ),
                        child: _isPlacingOrder
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white),
                              )
                            : Text(
                                'ยืนยันสั่งอาหาร — ฿${_calculateFinalTotal(cart.subtotal, _deliveryFee).ceil()}',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ),
                ),
        );
      },
    );
  }

  // ── Widget: เลือกที่อยู่จัดส่ง ──
  Widget _buildDeliveryAddressSelector() {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        // ตัวเลือก 1: ตำแหน่งปัจจุบัน
        _buildAddressOption(
          icon: Icons.my_location,
          label: 'ตำแหน่งปัจจุบัน',
          isSelected: _deliveryMode == 'current',
          onTap: _useCurrentLocation,
        ),
        const SizedBox(height: 8),
        // ตัวเลือก 2: ปักหมุดบนแผนที่
        _buildAddressOption(
          icon: Icons.pin_drop,
          label: 'ปักหมุดบนแผนที่',
          isSelected: _deliveryMode == 'pin',
          onTap: _openMapPicker,
        ),
        const SizedBox(height: 8),
        // ตัวเลือก 3: ที่อยู่ที่บันทึกไว้
        _buildAddressOption(
          icon: Icons.bookmark_outline,
          label: 'ที่อยู่ที่บันทึกไว้',
          isSelected: _deliveryMode == 'saved',
          onTap: _openSavedAddresses,
        ),
        // แสดงที่อยู่ที่เลือก
        if ((_deliveryMode == 'pin' || _deliveryMode == 'saved') &&
            _customerAddress != 'ตำแหน่งปัจจุบัน') ...[
          const SizedBox(height: 10),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle,
                    size: 16, color: Colors.green.shade600),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _customerAddress,
                    style:
                        TextStyle(fontSize: 12, color: Colors.green.shade800),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
        // แสดงระยะทาง
        if (!_isCalculatingFee && _distanceKm > 0) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.directions_car, size: 14, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                'ระยะทาง: ${_distanceKm.toStringAsFixed(1)} กม.',
                style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildAddressOption({
    required IconData icon,
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppTheme.accentOrange : colorScheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? AppTheme.accentOrange.withValues(alpha: 0.05)
              : colorScheme.surfaceContainer,
        ),
        child: Row(
          children: [
            Icon(icon,
                size: 20,
                color: isSelected ? AppTheme.accentOrange : colorScheme.onSurfaceVariant),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AppTheme.accentOrange : colorScheme.onSurface,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, size: 20, color: AppTheme.accentOrange),
          ],
        ),
      ),
    );
  }

  // ── Widget: สรุปราคา ──
  Widget _buildPriceSummary(CartProvider cart) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildPriceRow('ค่าอาหาร', '฿${cart.subtotal.ceil()}'),
          const SizedBox(height: 8),
          _isCalculatingFee
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('ค่าจัดส่ง',
                        style:
                            TextStyle(fontSize: 14, color: colorScheme.onSurfaceVariant)),
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: colorScheme.onSurfaceVariant),
                    ),
                  ],
                )
              : _buildPriceRow(
                  'ค่าจัดส่ง (${_distanceKm.toStringAsFixed(1)} กม.)',
                  '฿${_deliveryFee.ceil()}',
                ),
          if (_couponDiscount > 0) ...[
            const SizedBox(height: 8),
            _buildPriceRow(
              _hideCouponBreakdown ? 'ส่วนลดจากคูปอง' : 'ส่วนลดคูปอง',
              '-฿${_couponDiscount.ceil()}',
              isGreen: true,
            ),
          ],
          const Divider(height: 20),
          _buildPriceRow(
            'รวมทั้งหมด',
            _isCalculatingFee
                ? 'กำลังคำนวณ...'
                : '฿${_calculateFinalTotal(cart.subtotal, _deliveryFee).ceil()}',
            isBold: true,
            isOrange: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
      {required IconData icon, required String title, required Widget child}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AppTheme.accentOrange),
              const SizedBox(width: 8),
              Text(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildPaymentOption(String value, String label, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return RadioListTile<String>(
      value: value,
      groupValue: _paymentMethod,
      onChanged: (v) => setState(() => _paymentMethod = v!),
      title: Row(
        children: [
          Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(label),
        ],
      ),
      activeColor: AppTheme.accentOrange,
      contentPadding: EdgeInsets.zero,
      dense: true,
    );
  }

  Widget _buildPriceRow(String label, String price,
      {bool isBold = false, bool isGreen = false, bool isOrange = false}) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Flexible(
          child: Text(label,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: isBold ? 16 : 14,
                color: isGreen
                    ? Colors.green[700]
                    : (isBold ? null : colorScheme.onSurfaceVariant),
              )),
        ),
        Text(price,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 18 : 14,
              color: isOrange
                  ? AppTheme.accentOrange
                  : (isGreen ? Colors.green[700] : null),
            )),
      ],
    );
  }

  Future<void> _placeOrder(BuildContext context, CartProvider cart) async {
    setState(() => _isPlacingOrder = true);

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('กรุณาเข้าสู่ระบบ');

      if (_customerLat == null || _customerLng == null) {
        throw Exception('ไม่สามารถระบุตำแหน่งจัดส่งได้ กรุณาเลือกตำแหน่ง');
      }

      final note = _noteController.text.trim();
      if (note.isNotEmpty) {
        cart.setNote(note);
      }

      if (_isScheduledOrder && _scheduledAt == null) {
        throw Exception('กรุณาเลือกวันเวลาจัดส่ง');
      }

      final scheduledAt = _isScheduledOrder ? _scheduledAt : null;
      final finalTotal = _calculateFinalTotal(cart.subtotal, _deliveryFee);
      final merchantVisibleTotal = cart.subtotal;

      final booking = await createFoodOrder(
        userId: userId,
        merchantId: cart.merchantId!,
        merchantName: cart.merchantName!,
        cartItems: cart.toCartList(),
        subtotal: cart.subtotal,
        deliveryFee: _deliveryFee,
        distanceKm: _distanceKm,
        customerLat: _customerLat!,
        customerLng: _customerLng!,
        customerAddress: _customerAddress,
        paymentMethod: _paymentMethod,
        note: cart.note,
        scheduledAt: scheduledAt,
        couponCode: _appliedCoupon?.code,
        couponDiscount: _couponDiscount,
      );

      if (booking == null)
        throw Exception('ไม่ได้รับข้อมูลออเดอร์จากเซิร์ฟเวอร์');

      // Record coupon usage if applied
      if (_appliedCoupon != null && _couponDiscount > 0) {
        try {
          final couponService = CouponService();
          await couponService.recordUsage(
            couponId: _appliedCoupon!.id,
            bookingId: booking['id'] as String,
            discountAmount: _couponDiscount,
          );
        } catch (e) {
          debugLog('⚠️ Failed to record coupon usage: $e');
        }
      }

      // Send notification to merchant about new order
      try {
        final merchantId = cart.merchantId;
        if (merchantId != null && merchantId.isNotEmpty) {
          debugLog(
              '📤 Sending new order notification to merchant: $merchantId');
          await NotificationSender.sendToUser(
            userId: merchantId,
            title: '🍔 มีออเดอร์ใหม่!',
            body: _isScheduledOrder && _scheduledAt != null
                ? 'มีลูกค้าสั่งอาหารล่วงหน้า ฿${merchantVisibleTotal.ceil()} เวลา ${_formatScheduledDateTime(_scheduledAt!)}'
                : 'มีลูกค้าสั่งอาหาร ฿${merchantVisibleTotal.ceil()} กรุณายืนยันออเดอร์',
            data: {
              'type': 'merchant_new_order',
              'booking_id': booking['id']?.toString() ?? '',
            },
          );
        }
      } catch (e) {
        debugLog('⚠️ Failed to send merchant notification: $e');
      }

      cart.clearCart();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isScheduledOrder && _scheduledAt != null
                  ? '✅ ตั้งเวลาสั่งอาหารสำเร็จ (${_formatScheduledDateTime(_scheduledAt!)})'
                  : '✅ สั่งอาหารสำเร็จ! รอร้านค้ายืนยัน',
            ),
            backgroundColor: Colors.green,
          ),
        );
        // Pop back to home
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      debugLog('❌ สั่งอาหารล้มเหลว: $e');
      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.error_outline, color: Colors.red, size: 48),
            title: const Text('สั่งอาหารไม่สำเร็จ'),
            content: Text('$e'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('ตกลง'),
              ),
            ],
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isPlacingOrder = false);
    }
  }

  /// สร้าง food order ใน Supabase
  /// status = 'pending_merchant' เพื่อให้ร้านค้าเห็นออเดอร์ทันที
  static Future<Map<String, dynamic>?> createFoodOrder({
    required String userId,
    required String merchantId,
    required String merchantName,
    required List<Map<String, dynamic>> cartItems,
    required double subtotal,
    required double deliveryFee,
    required double distanceKm,
    required double customerLat,
    required double customerLng,
    required String customerAddress,
    required String paymentMethod,
    required String note,
    DateTime? scheduledAt,
    String? couponCode,
    double couponDiscount = 0,
  }) async {
    try {
      final client = Supabase.instance.client;

      final merchantLat = 13.7563;
      final merchantLng = 100.5018;

      debugLog('📝 Creating food order:');
      debugLog('   └─ merchant: $merchantName ($merchantId)');
      debugLog('   └─ merchant location: $merchantLat, $merchantLng');
      debugLog('   └─ customer location: $customerLat, $customerLng');
      debugLog('   └─ customer address: $customerAddress');
      debugLog('   └─ distance: ${distanceKm.toStringAsFixed(2)} km');
      debugLog('   └─ items: ${cartItems.length}');
      debugLog('   └─ subtotal: ฿$subtotal');
      debugLog('   └─ delivery fee: ฿$deliveryFee');
      if (couponCode != null && couponDiscount > 0) {
        debugLog(
            '   └─ coupon: $couponCode (-฿${couponDiscount.toStringAsFixed(2)})');
      }
      if (scheduledAt != null) {
        debugLog('   └─ scheduled_at: ${scheduledAt.toIso8601String()}');
      }
      debugLog('   └─ status: pending_merchant');

      final mergedNote = note.isNotEmpty ? note : 'สั่งอาหารจาก $merchantName';
      final normalizedCoupon = couponCode?.trim().toUpperCase();
      final hideBreakdown = normalizedCoupon == 'WELCOME20' ||
          normalizedCoupon == 'REFERRER20' ||
          normalizedCoupon == 'REFFERER20';
      final noteWithCoupon = (couponCode != null && couponDiscount > 0 && !hideBreakdown)
          ? '$mergedNote\n[คูปอง: $couponCode | ส่วนลด: ฿${couponDiscount.toStringAsFixed(2)}]'
          : mergedNote;

      // Create booking with status 'pending_merchant'
      final response = await client
          .from('bookings')
          .insert({
            'customer_id': userId,
            'service_type': 'food',
            'merchant_id': merchantId,
            'origin_lat': merchantLat,
            'origin_lng': merchantLng,
            'dest_lat': customerLat,
            'dest_lng': customerLng,
            'pickup_address': merchantName,
            'destination_address': customerAddress,
            'distance_km': distanceKm,
            'price': subtotal,
            'delivery_fee': deliveryFee,
            'notes': noteWithCoupon,
            'status': 'pending_merchant',
            'payment_method': paymentMethod,
            'scheduled_at': scheduledAt?.toIso8601String(),
          })
          .select()
          .single();

      final bookingId = response['id'] as String;
      debugLog('✅ Booking created: $bookingId');

      // Insert booking items (DB columns: booking_id, menu_item_id, quantity, price, name)
      final items = cartItems.map((item) {
        final qty = item['quantity'] ?? 1;
        final basePrice = (item['base_price'] ?? item['price']) as num;
        return {
          'booking_id': bookingId,
          'menu_item_id': item['id'],
          'name': item['name'] ?? '',
          'price': basePrice,
          'quantity': qty,
        };
      }).toList();

      if (items.isNotEmpty) {
        await client.from('booking_items').insert(items);
        debugLog('✅ ${items.length} booking items inserted');
      }

      debugLog('✅ Food order completed: $bookingId');
      return response;
    } catch (e) {
      debugLog('❌ Error creating food order: $e');
      rethrow;
    }
  }
}
