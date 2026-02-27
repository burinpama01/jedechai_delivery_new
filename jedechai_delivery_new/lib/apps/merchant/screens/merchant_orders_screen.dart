import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:async';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:vibration/vibration.dart';
import '../../../common/services/auth_service.dart';
import '../../../common/services/location_service.dart';
import '../../../common/services/notification_sender.dart';
import '../../../common/utils/order_code_formatter.dart';
import '../../../common/widgets/location_disclosure_dialog.dart';
import 'order_detail_screen.dart';

/// Merchant Orders Screen
///
/// Displays incoming food orders for merchants with Parallel Flow
/// Features: Shop open/close toggle, order management, driver status
class MerchantOrdersScreen extends StatefulWidget {
  const MerchantOrdersScreen({super.key});

  @override
  State<MerchantOrdersScreen> createState() => _MerchantOrdersScreenState();
}

class _MerchantOrdersScreenState extends State<MerchantOrdersScreen> {
  static const MethodChannel _merchantAlarmChannel =
      MethodChannel('jedechai/alarm_sound');

  bool _isShopOpen = false;
  bool _isLoading = true;
  String? _error;
  List<Map<String, dynamic>> _orders = [];
  StreamSubscription<List<Map<String, dynamic>>>? _ordersStreamSubscription;
  SharedPreferences? _prefs;
  bool _showHistory = false; // Toggle between active and history
  Timer? _autoRefreshTimer;

  // Alarm notification state variables
  Set<String> _notifiedOrderIds = {}; // Track alerted orders
  bool _isAlarmPlaying = false;
  Timer? _alarmReplayTimer;

  // Auto shop schedule timer
  Timer? _shopScheduleTimer;
  String? _shopOpenTime;
  String? _shopCloseTime;
  List<String> _shopOpenDays = [];
  bool _shopAutoScheduleEnabled = true;
  String _orderAcceptMode = _acceptModeManual;
  final Set<String> _autoAcceptingOrderIds = <String>{};

  static const String _acceptModeManual = 'manual';
  static const String _acceptModeAuto = 'auto';
  static const List<String> _weekdayKeys = [
    'mon',
    'tue',
    'wed',
    'thu',
    'fri',
    'sat',
    'sun'
  ];

  @override
  void initState() {
    super.initState();
    _initializePrefs();
    _requestLocationPermissionAndUpdateProfile();
    _fetchShopStatus();
    _fetchShopSchedule();
    _setupOrdersStream();
    _startAutoRefresh();
    _startShopScheduleTimer();
  }

  Future<void> _autoAcceptPendingOrders(
      List<Map<String, dynamic>> orders) async {
    if (!_isShopOpen) return;
    if (_orderAcceptMode != _acceptModeAuto) return;

    for (final order in orders) {
      final orderId = order['id']?.toString();
      final status = order['status']?.toString() ?? '';
      if (orderId == null || orderId.isEmpty) continue;
      if (!(status == 'pending_merchant' || status == 'pending')) continue;
      if (_autoAcceptingOrderIds.contains(orderId)) continue;

      _autoAcceptingOrderIds.add(orderId);
      try {
        debugLog(
            '🤖 Auto-accepting order: $orderId (mode=$_orderAcceptMode, shopOpen=$_isShopOpen)');
        await _acceptOrder(orderId, triggeredAutomatically: true);
      } finally {
        _autoAcceptingOrderIds.remove(orderId);
      }
    }
  }

  @override
  void dispose() {
    _ordersStreamSubscription?.cancel();
    _autoRefreshTimer?.cancel();
    _shopScheduleTimer?.cancel();
    _stopAlarm(); // Stop alarm when screen is disposed
    super.dispose();
  }

  Future<void> _initializePrefs() async {
    _prefs = await SharedPreferences.getInstance();
    _loadSavedShopStatus();
  }

  Future<void> _requestLocationPermissionAndUpdateProfile() async {
    try {
      debugLog('📍 Requesting location permission...');

      // Check if location services are enabled
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugLog('⚠️ Location services are disabled');
        return;
      }

      // Check location permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        if (mounted) {
          final accepted = await LocationDisclosureHelper.showIfNeeded(context);
          if (!accepted) return;
        }
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugLog('⚠️ Location permission denied');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        debugLog('⚠️ Location permission denied forever');
        return;
      }

      // Get current location
      debugLog('📍 Getting current location...');
      final position = await LocationService.getCurrentLocation();
      if (position == null) {
        debugLog('⚠️ Unable to get current location');
        return;
      }

      debugLog(
          '📍 Current location: ${position.latitude}, ${position.longitude}');

      // Update merchant profile with current location
      final userId = AuthService.userId;
      if (userId == null) {
        debugLog('⚠️ User ID is null, cannot update location');
        return;
      }

      await Supabase.instance.client.from('profiles').update({
        'latitude': position.latitude,
        'longitude': position.longitude,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', userId);

      debugLog(
          '✅ Merchant location updated: ${position.latitude}, ${position.longitude}');
    } catch (e) {
      debugLog(
          '❌ Error requesting location permission or updating profile: $e');
    }
  }

  bool _isTodayOpenDay() {
    final weekday = DateTime.now().weekday;
    final keyByWeekday = {
      DateTime.monday: 'mon',
      DateTime.tuesday: 'tue',
      DateTime.wednesday: 'wed',
      DateTime.thursday: 'thu',
      DateTime.friday: 'fri',
      DateTime.saturday: 'sat',
      DateTime.sunday: 'sun',
    };
    final todayKey = keyByWeekday[weekday];
    if (todayKey == null) return true;
    return _shopOpenDays.contains(todayKey);
  }

  Future<void> _loadSavedShopStatus() async {
    if (_prefs != null) {
      final savedStatus = _prefs!.getBool('shop_open') ?? false;
      if (mounted) {
        setState(() {
          _isShopOpen = savedStatus;
        });
      }
    }
  }

  Future<void> _saveShopStatus(bool status) async {
    if (_prefs != null) {
      await _prefs!.setBool('shop_open', status);
      debugLog('💾 Shop status saved: $status');
    }
  }

  // -------------------------------------------------------------------------
  // 🔊 ฟังก์ชันแจ้งเตือน (แก้ไขสำหรับ Version 4.0.0)
  // -------------------------------------------------------------------------
  Future<void> _startAlarm() async {
    if (_isAlarmPlaying) return;

    setState(() {
      _isAlarmPlaying = true;
    });

    debugLog('🚨 Starting alarm: Sound + Vibration');

    // ✅ 1. ส่วนของเสียง
    final usesCustomSound = await _playAlarmSound();
    if (!usesCustomSound) {
      _startAlarmReplayLoop();
    }

    // ✅ 2. ส่วนของการสั่น
    try {
      bool? hasVibrator = await Vibration.hasVibrator();
      if (hasVibrator == true) {
        Vibration.vibrate(
          pattern: [500, 1000, 500, 1000],
          repeat: 0,
        );
      }
    } catch (e) {
      debugLog('❌ Error vibrating: $e');
    }

    // ✅ 3. แสดง Dialog
    _showAlarmDialog();
  }

  Future<bool> _playAlarmSound() async {
    if (await _playCustomMerchantAlarmSound()) {
      return true;
    }

    try {
      await FlutterRingtonePlayer().playAlarm(
        looping: true,
        volume: 1.0,
        asAlarm: true,
      );
      return false;
    } catch (e) {
      debugLog('❌ Error playing alarm sound: $e');
      try {
        await FlutterRingtonePlayer().playRingtone(looping: true);
      } catch (e2) {
        debugLog('❌ Error playing backup ringtone: $e2');
      }
      return false;
    }
  }

  Future<bool> _playCustomMerchantAlarmSound() async {
    if (kIsWeb) {
      return false;
    }

    try {
      await _merchantAlarmChannel.invokeMethod('playMerchantAlarm');
      return true;
    } catch (e) {
      debugLog('⚠️ Custom merchant alarm sound unavailable, fallback: $e');
      return false;
    }
  }

  Future<void> _stopCustomMerchantAlarmSound() async {
    if (kIsWeb) {
      return;
    }

    try {
      await _merchantAlarmChannel.invokeMethod('stopMerchantAlarm');
    } catch (e) {
      debugLog('⚠️ Error stopping custom merchant alarm sound: $e');
    }
  }

  void _startAlarmReplayLoop() {
    _alarmReplayTimer?.cancel();
    _alarmReplayTimer = Timer.periodic(const Duration(seconds: 8), (_) async {
      if (!_isAlarmPlaying) return;

      // Keep-alive replay: some devices stop alarm audio unexpectedly.
      await _playAlarmSound();
    });
  }

  Future<void> _stopAlarm() async {
    _alarmReplayTimer?.cancel();
    _alarmReplayTimer = null;

    if (!_isAlarmPlaying) {
      return;
    }

    debugLog('🔇 Stopping alarm');

    setState(() {
      _isAlarmPlaying = false;
    });

    // ✅ สั่งหยุดเสียง (แก้เป็น Instance Method)
    await _stopCustomMerchantAlarmSound();

    try {
      await FlutterRingtonePlayer().stop();
    } catch (e) {
      debugLog('❌ Error stopping sound: $e');
    }

    // ✅ สั่งหยุดสั่น
    try {
      Vibration.cancel();
    } catch (e) {
      debugLog('❌ Error stopping vibration: $e');
    }
  }

  void _showAlarmDialog() {
    final colorScheme = Theme.of(context).colorScheme;
    showDialog(
      context: context,
      barrierDismissible: false, // Cannot dismiss by tapping outside
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.notifications_active,
                color: colorScheme.error,
                size: 32,
              ),
              const SizedBox(width: 12),
              Text(
                '🚨 ออเดอร์ใหม่!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.error,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.delivery_dining,
                size: 64,
                color: colorScheme.error,
              ),
              const SizedBox(height: 16),
              const Text(
                'คุณมีออเดอร์ใหม่รอการยืนยัน!',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'เสียงจะแจ้งเตือนซ้ำต่อเนื่องจนกว่าคุณกดหยุด',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop(); // Close dialog
                  _stopAlarm(); // Stop alarm
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.stop),
                    SizedBox(width: 8),
                    Text(
                      'หยุดเสียง / รับทราบ',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _setupOrdersStream() {
    final merchantId = AuthService.userId;
    if (merchantId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = 'ไม่พบข้อมูลผู้ใช้';
        });
      }
      return;
    }

    debugLog('🏪 Setting up orders stream for merchant: $merchantId');

    _ordersStreamSubscription = Supabase.instance.client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('service_type', 'food')
        .listen((data) {
          debugLog('📡 Stream received data: ${data.length} total bookings');

          final merchantId = AuthService.userId;
          final merchantOrders = data.where((item) {
            final itemMerchantId = item['merchant_id'];
            return itemMerchantId != null &&
                itemMerchantId.toString() == merchantId.toString();
          }).toList();

          debugLog(
              '📊 Raw merchant orders data: ${merchantOrders.length} items');

          // Log all orders with their status for debugging
          //for (final order in merchantOrders) {
          //  print('📦 Order ${OrderCodeFormatter.format(order['id']?.toString())}: status=${order['status']}, merchant_id=${order['merchant_id']}');
          //}

          // Filter based on whether we're showing active or history
          final filteredOrders = merchantOrders.where((item) {
            final status = item['status'] as String? ?? '';

            if (_showHistory) {
              // Show completed and cancelled orders for history
              return status == 'completed' || status == 'cancelled';
            } else {
              // Show only orders that merchant needs to handle
              // ร้านค้าจบงานเมื่อคนขับรับอาหารแล้ว (picking_up_order ไม่แสดง)
              final activeStatuses = [
                'pending_merchant', // รอร้านค้ายืนยัน (ออเดอร์ใหม่)
                'pending', // รอดำเนินการ
                'preparing', // กำลังเตรียมอาหาร
                'driver_accepted', // คนขับรับงานแล้ว (กำลังมาร้าน)
                'arrived_at_merchant', // คนขับถึงร้านแล้ว (รออาหารพร้อม)
                'ready_for_pickup', // อาหารพร้อมรับ
              ];
              final isActive = activeStatuses.contains(status);
              if (isActive) {
                debugLog(
                    '✅ Active order: ${OrderCodeFormatter.format(item['id']?.toString())} - $status');
              }
              return isActive;
            }
          }).toList();

          // Check for new pending_merchant orders and trigger alarm if needed
          debugLog('🔍 Checking for new orders - Shop is open: $_isShopOpen');
          debugLog('🔍 Notified orders count: ${_notifiedOrderIds.length}');

          _checkAndTriggerNewOrderAlarm(merchantOrders);
          _autoAcceptPendingOrders(merchantOrders);

          debugLog(
              '📋 Filtered orders (${_showHistory ? "history" : "active"}): ${filteredOrders.length} items');

          if (mounted) {
            setState(() {
              _orders = filteredOrders;
            });
          }
        });

    debugLog('✅ Stream setup complete');
  }

  void _startAutoRefresh() {
    _autoRefreshTimer?.cancel();
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) async {
      if (!mounted) return;

      debugLog('🔄 Auto refreshing merchant orders...');

      // Focus on orders only - don't refresh shop status to avoid UI flicker
      // Orders stream should handle real-time updates automatically

      // Refresh orders stream if needed
      if (_ordersStreamSubscription == null) {
        _setupOrdersStream();
      }

      // Fallback: fetch latest orders snapshot in case realtime misses events
      await _fetchLatestOrdersSnapshot();

      debugLog('🔄 Orders refresh completed');
    });

    debugLog('✅ Auto refresh started (2 seconds interval - orders only)');
  }

  Future<void> _fetchLatestOrdersSnapshot() async {
    try {
      final merchantId = AuthService.userId;
      if (merchantId == null) {
        debugLog('⚠️ Merchant ID is null, cannot fetch orders');
        return;
      }

      debugLog('📥 Fetching orders snapshot for merchant: $merchantId');

      final response = await Supabase.instance.client
          .from('bookings')
          .select()
          .eq('service_type', 'food')
          .eq('merchant_id', merchantId)
          .order('created_at', ascending: false);

      final data = List<Map<String, dynamic>>.from(response);

      debugLog('📊 Total orders fetched: ${data.length}');

      // Log all orders with their status
      //for (final order in data) {
      //  print('📦 Order ${OrderCodeFormatter.format(order['id']?.toString())}: status=${order['status']}, merchant_id=${order['merchant_id']}');
      //}

      final filteredOrders = data.where((item) {
        final status = item['status'] as String? ?? '';

        if (_showHistory) {
          return status == 'completed' || status == 'cancelled';
        } else {
          final activeStatuses = [
            'pending_merchant', // รอร้านค้ายืนยัน (ออเดอร์ใหม่)
            'pending', // รอดำเนินการ
            'preparing', // กำลังเตรียมอาหาร
            'driver_accepted', // คนขับรับงานแล้ว (กำลังมาร้าน)
            'arrived_at_merchant', // คนขับถึงร้านแล้ว (รออาหารพร้อม)
            'ready_for_pickup', // อาหารพร้อมรับ
            'picking_up_order', // คนขับรับอาหารแล้ว — จบงานร้านค้า
          ];
          final isActive = activeStatuses.contains(status);
          if (isActive) {
            debugLog(
                '✅ Active order found: ${OrderCodeFormatter.format(item['id']?.toString())} - $status');
          }
          return isActive;
        }
      }).toList();

      _checkAndTriggerNewOrderAlarm(data);
      _autoAcceptPendingOrders(data);

      debugLog('📋 Filtered active orders: ${filteredOrders.length}');

      if (mounted) {
        setState(() {
          _orders = filteredOrders;
        });
        debugLog('✅ UI updated with ${filteredOrders.length} orders');
      }
    } catch (e) {
      debugLog('❌ Failed to fetch latest orders snapshot: $e');
      debugLog('❌ Error type: ${e.runtimeType}');
    }
  }

  // ✅ ฟังก์ชันกลางสำหรับตรวจสอบและแจ้งเตือนออเดอร์ใหม่
  void _checkAndTriggerNewOrderAlarm(List<Map<String, dynamic>> orders) {
    if (!_isShopOpen) return;
    if (_orderAcceptMode == _acceptModeAuto) return;

    for (final order in orders) {
      final orderId = order['id']?.toString() ?? '';
      final status = order['status'] as String? ?? '';

      // ถ้าเป็นออเดอร์ใหม่ (pending_merchant) และยังไม่เคยแจ้งเตือน
      if (status == 'pending_merchant' &&
          !_notifiedOrderIds.contains(orderId)) {
        debugLog('🚨 NEW PENDING ORDER DETECTED: $orderId');

        // จดจำว่าเตือนแล้ว
        _notifiedOrderIds.add(orderId);

        // สั่งแจ้งเตือนทันที!
        _startAlarm();

        // เตือนแค่ออเดอร์ล่าสุดอันเดียวพอ (กันเสียงตีกัน)
        break;
      }
    }
  }

  Future<void> _fetchShopStatus() async {
    try {
      if (!mounted) return;

      setState(() {
        _isLoading = true;
        _error = null;
      });

      final userId = AuthService.userId;
      if (userId == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้');
      }

      final response = await Supabase.instance.client
          .from('profiles')
          .select('shop_status, order_accept_mode, shop_auto_schedule_enabled')
          .eq('id', userId)
          .single();

      if (mounted) {
        final raw = response['shop_status'];
        final bool serverStatus = raw == true || raw == 1 || raw == 'true';
        setState(() {
          _isShopOpen = serverStatus;
          _orderAcceptMode =
              (response['order_accept_mode'] as String?) ?? _acceptModeManual;
          _shopAutoScheduleEnabled =
              (response['shop_auto_schedule_enabled'] as bool?) ?? true;
          _isLoading = false;
        });

        // Save server status to local storage
        await _saveShopStatus(serverStatus);
        debugLog('🔄 Shop status synced from server: $serverStatus');
      }
    } catch (e) {
      debugLog('❌ Error fetching shop status: $e');
      // If server fails, use local saved status
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  /// ดึงเวลาเปิด-ปิดร้านจาก DB
  Future<void> _fetchShopSchedule() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return;

      final response = await Supabase.instance.client
          .from('profiles')
          .select(
              'shop_open_time, shop_close_time, shop_open_days, order_accept_mode, shop_auto_schedule_enabled')
          .eq('id', userId)
          .maybeSingle();

      if (response != null && mounted) {
        setState(() {
          _shopOpenTime = response['shop_open_time'] as String?;
          _shopCloseTime = response['shop_close_time'] as String?;
          final rawDays = response['shop_open_days'];
          if (rawDays is List) {
            _shopOpenDays = rawDays
                .map((e) => e.toString().toLowerCase().trim())
                .where((e) => _weekdayKeys.contains(e))
                .toList();
          } else {
            _shopOpenDays = [];
          }
          _orderAcceptMode =
              (response['order_accept_mode'] as String?) ?? _acceptModeManual;
          _shopAutoScheduleEnabled =
              (response['shop_auto_schedule_enabled'] as bool?) ?? true;
        });
        debugLog(
            '⏰ Shop schedule loaded: $_shopOpenTime - $_shopCloseTime, days=$_shopOpenDays, mode=$_orderAcceptMode, autoSchedule=$_shopAutoScheduleEnabled');
      }
    } catch (e) {
      debugLog('⚠️ Error fetching shop schedule: $e');
    }
  }

  /// ตรวจสอบเวลาเปิด-ปิดร้านทุก 60 วินาที
  void _startShopScheduleTimer() {
    _shopScheduleTimer?.cancel();
    _shopScheduleTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!mounted) return;
      _checkShopSchedule();
    });
    // ตรวจสอบครั้งแรกทันที (หลัง fetch เสร็จ)
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) _checkShopSchedule();
    });
  }

  void _checkShopSchedule() {
    if (!_shopAutoScheduleEnabled) return;
    if (_shopOpenTime == null || _shopCloseTime == null) return;

    final now = TimeOfDay.now();
    final openParts = _shopOpenTime!.split(':');
    final closeParts = _shopCloseTime!.split(':');
    if (openParts.length < 2 || closeParts.length < 2) return;

    final openTime = TimeOfDay(
      hour: int.tryParse(openParts[0]) ?? 8,
      minute: int.tryParse(openParts[1]) ?? 0,
    );
    final closeTime = TimeOfDay(
      hour: int.tryParse(closeParts[0]) ?? 22,
      minute: int.tryParse(closeParts[1]) ?? 0,
    );

    final nowMinutes = now.hour * 60 + now.minute;
    final openMinutes = openTime.hour * 60 + openTime.minute;
    final closeMinutes = closeTime.hour * 60 + closeTime.minute;

    bool shouldBeOpen;
    if (openMinutes <= closeMinutes) {
      // ปกติ เช่น 08:00 - 22:00
      shouldBeOpen = nowMinutes >= openMinutes && nowMinutes < closeMinutes;
    } else {
      // ข้ามวัน เช่น 22:00 - 06:00
      shouldBeOpen = nowMinutes >= openMinutes || nowMinutes < closeMinutes;
    }

    if (_shopOpenDays.isNotEmpty && !_isTodayOpenDay()) {
      shouldBeOpen = false;
    }

    if (shouldBeOpen != _isShopOpen) {
      debugLog(
          '⏰ Auto-toggle shop: ${_isShopOpen ? "เปิด→ปิด" : "ปิด→เปิด"} (now=$nowMinutes, open=$openMinutes, close=$closeMinutes)');
      _toggleShopStatus(shouldBeOpen, triggeredBySchedule: true);
    }
  }

  Future<void> _toggleShopStatus(
    bool value, {
    bool triggeredBySchedule = false,
  }) async {
    try {
      if (!mounted) return;

      // If merchant manually toggles shop status, disable auto schedule to avoid forced overrides.
      final bool isManualToggle = !triggeredBySchedule;
      if (isManualToggle && _shopAutoScheduleEnabled) {
        setState(() {
          _shopAutoScheduleEnabled = false;
        });
      }

      setState(() {
        _isShopOpen = value;
      });

      // Save to local storage
      await _saveShopStatus(value);

      final userId = AuthService.userId;
      if (userId == null) {
        throw Exception('ไม่พบข้อมูลผู้ใช้');
      }

      final updateData = {
        'shop_status': value,
        if (!triggeredBySchedule) 'shop_auto_schedule_enabled': false,
        'updated_at': DateTime.now().toIso8601String(),
      };

      final updated = await Supabase.instance.client
          .from('profiles')
          .update(updateData)
          .eq('id', userId)
          .select('shop_status, shop_auto_schedule_enabled')
          .maybeSingle();

      final updatedRaw = updated?['shop_status'];
      final bool updatedStatus =
          updatedRaw == true || updatedRaw == 1 || updatedRaw == 'true';
      debugLog(
          '✅ Shop status updated in DB: $updatedStatus (requested: $value)');

      if (mounted && updated != null && updatedStatus != value) {
        debugLog(
            '⚠️ Shop status mismatch after update. DB=$updatedStatus, requested=$value');
      }

      if (mounted) {
        final colorScheme = Theme.of(context).colorScheme;
        final autoDisabled = updated?['shop_auto_schedule_enabled'] == false;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              value
                  ? (autoDisabled ? 'เปิดร้านแล้ว (ปิดอัตโนมัติถูกปิด)' : 'เปิดร้านแล้ว')
                  : (autoDisabled ? 'ปิดร้านแล้ว (ปิดอัตโนมัติถูกปิด)' : 'ปิดร้านแล้ว'),
            ),
            backgroundColor:
                value ? AppTheme.accentOrange : colorScheme.outline,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      debugLog('❌ Error updating shop status: $e');
      // Revert on error
      if (mounted) {
        setState(() {
          _isShopOpen = !value;
        });
        // Revert saved status
        await _saveShopStatus(!value);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('ไม่สามารถเปลี่ยนสถานะร้าน: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _saveOrderStatus(String bookingId, String status) async {
    if (_prefs != null) {
      await _prefs!.setString('order_status_$bookingId', status);
      await _prefs!.setString(
          'order_updated_$bookingId', DateTime.now().toIso8601String());
      debugLog('💾 Order status saved: $bookingId -> $status');
    }
  }

  // ignore: unused_element
  Future<String?> _getSavedOrderStatus(String bookingId) async {
    if (_prefs != null) {
      return _prefs!.getString('order_status_$bookingId');
    }
    return null;
  }

  String? _getSavedOrderStatusSync(String bookingId) {
    // Synchronous version for UI building
    if (_prefs != null) {
      return _prefs!.getString('order_status_$bookingId');
    }
    return null;
  }

  Future<void> _clearOrderStatus(String bookingId) async {
    if (_prefs != null) {
      await _prefs!.remove('order_status_$bookingId');
      await _prefs!.remove('order_updated_$bookingId');
      debugLog('🗑️ Order status cleared: $bookingId');
    }
  }

  Future<void> _acceptOrder(String bookingId,
      {bool triggeredAutomatically = false}) async {
    try {
      debugLog('🏪 Merchant accepting order: $bookingId');

      // Save pending status immediately
      await _saveOrderStatus(bookingId, 'preparing');

      // Get current booking to check status
      final bookingData = await Supabase.instance.client
          .from('bookings')
          .select('status')
          .eq('id', bookingId)
          .single();

      final currentStatus = bookingData['status'] as String;
      String newStatus;

      // Parallel Flow Logic
      if (currentStatus == 'pending' || currentStatus == 'pending_merchant') {
        newStatus = 'preparing'; // Merchant accepts first
      } else if (currentStatus == 'driver_accepted') {
        newStatus = 'matched'; // Driver already accepted
      } else if (currentStatus == 'arrived_at_merchant') {
        newStatus =
            'ready_for_pickup'; // Driver arrived, merchant marks food ready
      } else {
        _showErrorSnackBar('Order not available for acceptance');
        await _clearOrderStatus(bookingId);
        return;
      }

      debugLog('🔄 Updating order status from $currentStatus to $newStatus');

      // Update booking with parallel flow logic
      final result = await Supabase.instance.client
          .from('bookings')
          .update({
            'status': newStatus,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', bookingId)
          .eq('status', currentStatus)
          .select();

      debugLog('✅ Order accepted successfully: $result');

      if (result.isEmpty) {
        _showErrorSnackBar('Order already taken or not available');
        await _clearOrderStatus(bookingId);
        return;
      }

      // Update saved status with confirmed status
      await _saveOrderStatus(bookingId, newStatus);

      // Send notification to customer
      await _notifyCustomerOrderAccepted(result[0]);

      if (mounted) {
        if (!triggeredAutomatically) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('ออเดอร์ได้รับการยืนยันแล้ว!'),
              backgroundColor: Theme.of(context).colorScheme.secondary,
              duration: const Duration(seconds: 2),
            ),
          );
        }

        // Don't force UI refresh - let stream handle updates naturally
        debugLog('🔄 Order accepted - stream will update UI automatically');
      }
    } catch (e) {
      debugLog('❌ Failed to accept order: $e');
      await _clearOrderStatus(bookingId);
      _showErrorSnackBar('Cannot accept order: ${e.toString()}');
    }
  }

  // ignore: unused_element
  Future<void> _markFoodReady(String bookingId) async {
    try {
      // Save pending status immediately
      await _saveOrderStatus(bookingId, 'ready_for_pickup');

      final result = await Supabase.instance.client
          .from('bookings')
          .update({'status': 'ready_for_pickup'})
          .eq('id', bookingId)
          .inFilter('status', ['matched', 'preparing'])
          .select();

      if (result.isEmpty) {
        _showErrorSnackBar('Order not available for marking ready');
        await _clearOrderStatus(bookingId);
        return;
      }

      _showSuccessSnackBar('Food marked as ready for pickup');

      // Send notification to customer and driver
      await _notifyFoodReady(result[0]);
    } catch (e) {
      debugLog('❌ Failed to mark food ready: $e');
      await _clearOrderStatus(bookingId);
      _showErrorSnackBar('Failed to mark food ready: $e');
    }
  }

  // ignore: unused_element
  Future<void> _finishOrder(String bookingId) async {
    try {
      final result = await Supabase.instance.client
          .from('bookings')
          .update({'status': 'completed'})
          .eq('id', bookingId)
          .inFilter('status', ['ready_for_pickup', 'in_transit'])
          .select();

      if (result.isEmpty) {
        _showErrorSnackBar('Order not available for finishing');
        return;
      }

      _showSuccessSnackBar('Order completed successfully');
    } catch (e) {
      _showErrorSnackBar('Failed to finish order: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    if (mounted) {
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: colorScheme.secondary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _showErrorSnackBar(String message) {
    if (mounted) {
      final colorScheme = Theme.of(context).colorScheme;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: colorScheme.error,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // ignore: unused_element
  String _getDriverStatus(String status, Map<String, dynamic> booking) {
    if (status == 'pending' || status == 'pending_merchant') {
      return 'คนขับ: รอคนขับรับงาน...';
    } else if (status == 'driver_accepted' || status == 'matched') {
      final driverName = booking['driver_name'] ?? 'คนขับ';
      return 'คนขับ: $driverName กำลังมา';
    } else if (status == 'in_transit') {
      final driverName = booking['driver_name'] ?? 'คนขับ';
      return 'คนขับ: $driverName ถึงร้านแล้ว';
    } else if (status == 'preparing') {
      return 'คนขับ: รอร้านทำอาหาร';
    } else if (status == 'ready_for_pickup') {
      return 'คนขับ: รออาหารพร้อม';
    } else {
      return 'คนขับ: รอดำเนินการ';
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending_merchant':
        return 'ออเดอร์ใหม่';
      case 'pending':
        return 'รอยืนยัน';
      case 'preparing':
        return 'กำลังทำอาหาร';
      case 'driver_accepted':
        return 'คนขับรับงานแล้ว';
      case 'arrived_at_merchant':
        return 'คนขับถึงร้านแล้ว';
      case 'matched':
        return 'จับคู่คนขับแล้ว';
      case 'ready_for_pickup':
        return 'อาหารพร้อมแล้ว';
      case 'picking_up_order':
        return 'คนขับกำลังรับอาหาร';
      case 'in_transit':
        return 'กำลังจัดส่ง';
      case 'completed':
        return 'เสร็จสิ้น';
      case 'cancelled':
        return 'ยกเลิก';
      default:
        return 'ไม่ทราบสถานะ';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(_showHistory ? 'ประวัติออเดอร์' : 'ออเดอร์'),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
        actions: [
          // Toggle between active and history
          IconButton(
            icon: Icon(_showHistory ? Icons.list : Icons.history),
            onPressed: _toggleView,
            tooltip: _showHistory
                ? 'ดูออเดอร์ที่กำลังดำเนินการ'
                : 'ดูประวัติออเดอร์',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _fetchShopStatus();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('รีเฟรชข้อมูลแล้ว'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }
            },
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    final colorScheme = Theme.of(context).colorScheme;
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentOrange),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'เกิดข้อผิดพลาด',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: colorScheme.error,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _fetchShopStatus,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentOrange,
                foregroundColor: colorScheme.onPrimary,
              ),
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Shop Status Card
          _buildShopStatusCard(),
          const SizedBox(height: 24),

          // Orders Section
          _buildOrdersList(),
        ],
      ),
    );
  }

  Widget _buildOrdersList() {
    final colorScheme = Theme.of(context).colorScheme;
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentOrange),
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              _error!,
              style: TextStyle(color: colorScheme.error),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                if (!mounted) return;

                setState(() {
                  _error = null;
                  _isLoading = true;
                });
                await _fetchShopStatus();
                _setupOrdersStream();
              },
              child: const Text('ลองใหม่'),
            ),
          ],
        ),
      );
    }

    if (_orders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.12),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restaurant_outlined,
                size: 64,
                color: AppTheme.accentOrange,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'ไม่มีออเดอร์ใหม่',
              style: TextStyle(
                fontSize: 20,
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isShopOpen
                  ? 'ออเดอร์ใหม่จะปรากฏที่นี่ทันที'
                  : 'เปิดร้านเพื่อรับออเดอร์',
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: _orders.map((order) {
        return _buildOrderCard(order);
      }).toList(),
    );
  }

  Widget _buildShopStatusCard() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: _isShopOpen
              ? [
                  AppTheme.accentOrange,
                  AppTheme.accentOrange.withValues(alpha: 0.8),
                ]
              : [
                  colorScheme.outline,
                  colorScheme.outline.withValues(alpha: 0.8),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (_isShopOpen ? AppTheme.accentOrange : colorScheme.outline)
                .withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _isShopOpen ? Icons.store : Icons.store_mall_directory,
                color: colorScheme.onPrimary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'สถานะร้าน',
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Switch(
                value: _isShopOpen,
                onChanged: _toggleShopStatus,
                activeThumbColor: colorScheme.onPrimary,
                inactiveThumbColor: colorScheme.surfaceContainerHighest,
                activeTrackColor: colorScheme.onPrimary.withValues(alpha: 0.5),
                inactiveTrackColor: colorScheme.onPrimary.withValues(alpha: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _isShopOpen ? 'ร้านเปิด' : 'ร้านปิด',
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isShopOpen
                ? 'ลูกค้าสามารถสั่งอาหารได้'
                : 'ร้านปิดให้บริการชั่วคราว',
            style: TextStyle(
              color: colorScheme.onPrimary.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                _orderAcceptMode == _acceptModeAuto
                    ? Icons.auto_mode_outlined
                    : Icons.pan_tool_alt_outlined,
                color: colorScheme.onPrimary.withValues(alpha: 0.9),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                _orderAcceptMode == _acceptModeAuto
                    ? 'รับออเดอร์อัตโนมัติ'
                    : 'รับออเดอร์ด้วยตนเอง',
                style: TextStyle(
                  color: colorScheme.onPrimary.withValues(alpha: 0.95),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                _shopAutoScheduleEnabled
                    ? Icons.av_timer
                    : Icons.av_timer_outlined,
                color: colorScheme.onPrimary.withValues(alpha: 0.9),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                _shopAutoScheduleEnabled
                    ? 'เปิด-ปิดร้านอัตโนมัติ: เปิดใช้งาน'
                    : 'เปิด-ปิดร้านอัตโนมัติ: ปิดใช้งาน',
                style: TextStyle(
                  color: colorScheme.onPrimary.withValues(alpha: 0.95),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = order['status'] as String? ?? '';
    final price = order['price'] is int
        ? (order['price'] as int).toDouble()
        : (order['price'] as num?)?.toDouble() ?? 0.0;
    final distanceKm = order['distance_km'] is int
        ? (order['distance_km'] as int).toDouble()
        : (order['distance_km'] as num?)?.toDouble() ?? 0.0;
    final createdAtStr = order['created_at'] as String?;
    final scheduledAtStr = order['scheduled_at'] as String?;
    final scheduledAt =
        scheduledAtStr != null ? DateTime.tryParse(scheduledAtStr)?.toLocal() : null;
    if (createdAtStr == null) {
      debugLog('❌ Missing created_at for order: ${order['id']}');
      return const SizedBox.shrink();
    }
    final createdAt = DateTime.parse(createdAtStr).toLocal();

    final savedStatus = _getSavedOrderStatusSync(order['id']);
    final displayStatus = savedStatus ?? status;
    final isNewOrder =
        displayStatus == 'pending_merchant' || displayStatus == 'pending';
    final statusColor = _getStatusColor(displayStatus);

    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MerchantOrderDetailScreen(order: order),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: isNewOrder
              ? Border.all(color: colorScheme.error.withValues(alpha: 0.4), width: 2)
              : null,
          boxShadow: [
            BoxShadow(
              color: (isNewOrder ? colorScheme.error : colorScheme.shadow)
                  .withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // ── Gradient Status Header ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isNewOrder
                      ? [
                          colorScheme.error,
                          colorScheme.error.withValues(alpha: 0.7),
                        ]
                      : [statusColor, statusColor.withValues(alpha: 0.7)],
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isNewOrder
                        ? Icons.notifications_active
                        : _getStatusIcon(displayStatus),
                    color: colorScheme.onPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _getStatusText(displayStatus),
                    style: TextStyle(
                        color: colorScheme.onPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    OrderCodeFormatter.format(order['id']?.toString()),
                    style: TextStyle(
                        color: colorScheme.onPrimary.withValues(alpha: 0.85),
                        fontSize: 12,
                        fontWeight: FontWeight.w500),
                  ),
                ],
              ),
            ),

            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Price + Time Row ──
                  Row(
                    children: [
                      // ยอดรวม
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.accentOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.receipt_long,
                                size: 16, color: AppTheme.accentOrange),
                            const SizedBox(width: 6),
                            Text(
                              '฿${price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.accentOrange),
                            ),
                          ],
                        ),
                      ),
                      // ค่าส่งไม่แสดงฝั่งร้านค้า (เป็นข้อมูลของลูกค้า/คนขับ)
                      const Spacer(),
                      Icon(Icons.access_time_rounded,
                          size: 14, color: colorScheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Text(
                        _getTimeAgo(DateTime.now().difference(createdAt)),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  if (scheduledAt != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: colorScheme.tertiary.withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.schedule,
                              size: 16, color: colorScheme.tertiary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              scheduledAt.isAfter(DateTime.now())
                                  ? 'ออเดอร์นัดเวลา: ${_formatScheduledDateTime(scheduledAt)}'
                                  : 'เวลานัดรับ: ${_formatScheduledDateTime(scheduledAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // ── Address + Distance ──
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 24,
                              height: 24,
                              decoration: BoxDecoration(
                                  color: colorScheme.errorContainer.withValues(alpha: 0.6),
                                  borderRadius: BorderRadius.circular(6)),
                              child: Icon(Icons.location_on,
                                  size: 14, color: colorScheme.error),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _formatAddress(order['destination_address']),
                                style: TextStyle(
                                    fontSize: 12, color: colorScheme.onSurface),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        if (distanceKm > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                    color: colorScheme.secondaryContainer.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(6)),
                                child: Icon(Icons.straighten,
                                    size: 14, color: colorScheme.secondary),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'ระยะทาง ${distanceKm.toStringAsFixed(1)} กม.',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: colorScheme.onSurfaceVariant),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),

                  // ── Action Buttons ──
                  _buildActionButtons(order, displayStatus),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'pending_merchant':
      case 'pending':
        return Icons.notifications_active;
      case 'preparing':
        return Icons.restaurant;
      case 'driver_accepted':
      case 'matched':
        return Icons.person_pin_circle;
      case 'arrived_at_merchant':
        return Icons.store;
      case 'ready_for_pickup':
        return Icons.check_circle;
      case 'picking_up_order':
        return Icons.delivery_dining;
      case 'in_transit':
        return Icons.local_shipping;
      case 'completed':
        return Icons.done_all;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.receipt_long;
    }
  }

  String _formatAddress(dynamic address) {
    if (address == null) return 'ไม่ระบุ';
    if (address is String) {
      // Check if address string contains "Instance of" or "AddressPlacemark"
      if (address.contains('Instance of') ||
          address.contains('AddressPlacemark')) {
        return '📍 ตำแหน่งตามหมุดปักของลูกค้า';
      }
      return address;
    }
    if (address.toString() == 'Instance of \'AddressPlacemark\'') {
      return '📍 ตำแหน่งตามหมุดปักของลูกค้า';
    }
    return address.toString();
  }

  Widget _buildActionButtons(Map<String, dynamic> order, String status) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'pending_merchant':
      case 'pending':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed: () => _acceptOrder(order['id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'รับออเดอร์',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ],
        );
      case 'preparing':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: colorScheme.secondary.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.restaurant,
                color: colorScheme.secondary,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'กำลังเตรียมอาหาร',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.secondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'กดเข้าไปดูรายละเอียด',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.secondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      case 'driver_accepted':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: colorScheme.primary.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.person,
                color: colorScheme.primary,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'คนขับรับงานแล้ว',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'กำลังประกอบอาหาร',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      case 'matched':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: colorScheme.secondary.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.check_circle,
                color: colorScheme.secondary,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'จับคู่คนขับแล้ว',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.secondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'กดเข้าไปดูรายละเอียด',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.secondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      case 'traveling_to_merchant':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: colorScheme.tertiary.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.directions_car,
                color: colorScheme.tertiary,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'คนขับกำลังเดินทางมาที่ร้าน',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.tertiary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'กรุณาเตรียมอาหารให้พร้อม',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.tertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      case 'arrived_at_merchant':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: colorScheme.tertiary.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.store,
                color: colorScheme.tertiary,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'คนขับถึงร้านแล้ว',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.tertiary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'กดเข้าไปดูรายละเอียด',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.tertiary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      case 'picking_up_order':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: colorScheme.secondary.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.delivery_dining,
                color: colorScheme.secondary,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'คนขับกำลังรับออเดอร์',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.secondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'กำลังนำส่งให้ลูกค้า',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.secondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      case 'in_transit':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: colorScheme.primary.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.local_shipping,
                color: colorScheme.primary,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'กำลังนำส่งอาหาร',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'ออเดอร์กำลังเดินทางถึงลูกค้า',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.primary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      case 'ready_for_pickup':
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.secondaryContainer.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: colorScheme.secondary.withValues(alpha: 0.35)),
          ),
          child: Column(
            children: [
              Icon(
                Icons.delivery_dining,
                color: colorScheme.secondary,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                'คนขับมารับออเดอร์แล้ว',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.secondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'ออเดอร์นี้เสร็จสิ้นสำหรับร้านค้า',
                style: TextStyle(
                  fontSize: 14,
                  color: colorScheme.secondary,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Color _getStatusColor(String status) {
    final colorScheme = Theme.of(context).colorScheme;
    switch (status) {
      case 'pending_merchant':
        return colorScheme.error; // Urgent/New Order
      case 'pending':
        return colorScheme.tertiary;
      case 'preparing':
        return colorScheme.primary;
      case 'ready_for_pickup':
        return colorScheme.secondary;
      case 'driver_accepted':
      case 'matched':
        return colorScheme.secondary; // ✅ Treat as Finished/Success
      case 'arrived_at_merchant':
        return colorScheme.secondary; // ✅ Also Success
      case 'completed':
        return colorScheme.secondary;
      case 'cancelled':
        return colorScheme.outline;
      default:
        return colorScheme.outline;
    }
  }

  String _getTimeAgo(Duration duration) {
    if (duration.inMinutes < 1) {
      return 'เมื่อสักครู่';
    } else if (duration.inMinutes < 60) {
      return 'เมื่อ ${duration.inMinutes} นาทีที่แล้ว';
    } else if (duration.inHours < 24) {
      return 'เมื่อ ${duration.inHours} ชั่วโมงที่แล้ว';
    } else {
      return 'เมื่อ ${duration.inDays} วันที่แล้ว';
    }
  }

  String _formatScheduledDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  // ignore: unused_element
  String _formatTimeAgo(Duration duration) {
    if (duration.inMinutes < 1) {
      return 'Just now';
    } else if (duration.inMinutes < 60) {
      return '${duration.inMinutes} mins ago';
    } else if (duration.inHours < 24) {
      return '${duration.inHours} hours ago';
    } else {
      return '${duration.inDays} days ago';
    }
  }

  /// Send notification to customer when merchant accepts order
  Future<void> _notifyCustomerOrderAccepted(
      Map<String, dynamic> booking) async {
    try {
      final customerId = booking['customer_id'] as String?;
      if (customerId == null || customerId.isEmpty) {
        debugLog('❌ No customer ID found in booking');
        return;
      }

      debugLog('📤 Sending notification to customer: $customerId');

      // Get merchant profile for notification
      final merchantProfile = await _getMerchantProfile();
      final merchantName = merchantProfile?['full_name'] ?? 'ร้านค้า';

      final success = await NotificationSender.sendNotification(
        targetUserId: customerId,
        title: '✅ ร้านยืนยันออเดอร์แล้ว!',
        body: '$merchantName กำลังเตรียมอาหารของคุณ',
        data: {
          'type': 'merchant_accepted',
          'booking_id': booking['id'] as String,
          'merchant_id': booking['merchant_id'] as String,
          'status': booking['status'] as String,
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      if (success) {
        debugLog('✅ Notification sent to customer successfully');
      } else {
        debugLog('❌ Failed to send notification to customer');
      }
    } catch (e) {
      debugLog('❌ Error notifying customer: $e');
    }
  }

  /// Send notification when food is ready
  Future<void> _notifyFoodReady(Map<String, dynamic> booking) async {
    try {
      final customerId = booking['customer_id'] as String?;
      final driverId = booking['driver_id'] as String?;

      // Get merchant profile
      final merchantProfile = await _getMerchantProfile();
      final merchantName = merchantProfile?['full_name'] ?? 'ร้านค้า';

      // Notify customer
      if (customerId != null && customerId.isNotEmpty) {
        debugLog('📤 Sending food ready notification to customer: $customerId');
        await NotificationSender.sendNotification(
          targetUserId: customerId,
          title: '🍔 อาหารพร้อมแล้ว!',
          body: '$merchantName เตรียมอาหารเสร็จแล้ว รอคนขับมารับ',
          data: {
            'type': 'food_ready',
            'booking_id': booking['id'] as String,
            'merchant_id': booking['merchant_id'] as String,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }

      // Notify driver
      if (driverId != null && driverId.isNotEmpty) {
        debugLog('📤 Sending food ready notification to driver: $driverId');
        await NotificationSender.sendNotification(
          targetUserId: driverId,
          title: '🍔 อาหารพร้อมรับแล้ว!',
          body: '$merchantName เตรียมอาหารเสร็จแล้ว พร้อมรับได้เลย',
          data: {
            'type': 'food_ready_driver',
            'booking_id': booking['id'] as String,
            'merchant_id': booking['merchant_id'] as String,
            'timestamp': DateTime.now().toIso8601String(),
          },
        );
      }
    } catch (e) {
      debugLog('❌ Error notifying food ready: $e');
    }
  }

  /// Get current merchant profile
  Future<Map<String, dynamic>?> _getMerchantProfile() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return null;

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('full_name, phone_number')
          .eq('id', userId)
          .single();

      return profile;
    } catch (e) {
      debugLog('❌ Error fetching merchant profile: $e');
      return null;
    }
  }

  void _toggleView() {
    if (!mounted) return;

    setState(() {
      _showHistory = !_showHistory;
    });
    // Re-setup stream with new filter
    _setupOrdersStream();

    // Show feedback
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              _showHistory ? 'ดูประวัติออเดอร์' : 'ดูออเดอร์ที่กำลังดำเนินการ'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
}
