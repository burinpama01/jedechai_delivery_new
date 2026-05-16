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
import '../../../common/services/booking_service.dart';
import '../../../common/services/location_service.dart';
import '../../../common/services/merchant_order_service.dart';
import '../../../common/services/notification_sender.dart';
import '../../../common/models/booking.dart';
import '../../../common/utils/order_code_formatter.dart';
import '../../../common/widgets/location_disclosure_dialog.dart';
import '../widgets/order_alarm_widget.dart';
import '../widgets/order_card.dart';
import '../widgets/order_list.dart';
import '../widgets/shop_status_card.dart';
import 'order_detail_screen.dart';
import '../../../l10n/app_localizations.dart';
import '../../../common/utils/shop_schedule.dart';

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
  final MerchantOrderService _merchantOrderService = MerchantOrderService();
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

  Future<bool> _confirmManualCloseShopDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        return AlertDialog(
          title: Text(AppLocalizations.of(context)!.merchantCloseShopTitle),
          content: Text(
            AppLocalizations.of(context)!.merchantCloseShopBody,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                AppLocalizations.of(context)!.merchantCloseShopCancel,
                style: TextStyle(color: colorScheme.onSurfaceVariant),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: colorScheme.error,
                foregroundColor: colorScheme.onError,
              ),
              child:
                  Text(AppLocalizations.of(context)!.merchantCloseShopConfirm),
            ),
          ],
        );
      },
    );
    return result == true;
  }

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

  Map<String, dynamic> _merchantScheduleMap() => {
        'shop_auto_schedule_enabled': _shopAutoScheduleEnabled,
        'shop_status': _isShopOpen,
        'shop_open_time': _shopOpenTime,
        'shop_close_time': _shopCloseTime,
        'shop_open_days': _shopOpenDays,
      };

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
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => MerchantOrderAlarmDialog(
        onStopAlarm: _stopAlarm,
      ),
    );
  }

  void _setupOrdersStream() {
    final merchantId = AuthService.userId;
    if (merchantId == null) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _error = AppLocalizations.of(context)!.merchantUserNotFound;
        });
      }
      return;
    }

    debugLog('🏪 Setting up orders stream for merchant: $merchantId');

    _ordersStreamSubscription =
        _merchantOrderService.watchOrders(merchantId).listen((merchantOrders) {
      debugLog(
          '📡 Stream received data: ${merchantOrders.length} merchant bookings');

      debugLog('📊 Raw merchant orders data: ${merchantOrders.length} items');

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

      final data = await _merchantOrderService.fetchOrders(merchantId);

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
        throw Exception(AppLocalizations.of(context)!.merchantUserNotFound);
      }

      final response = await _merchantOrderService.fetchShopStatus(userId);

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
    final shouldBeOpen = isShopOpenNow(_merchantScheduleMap());
    if (shouldBeOpen != _isShopOpen) {
      debugLog(
          '⏰ Auto-toggle shop: ${_isShopOpen ? "เปิด→ปิด" : "ปิด→เปิด"} (Bangkok time)');
      _toggleShopStatus(shouldBeOpen, triggeredBySchedule: true);
    }
  }

  Future<void> _toggleShopStatus(
    bool value, {
    bool triggeredBySchedule = false,
    bool permanentlyDisableSchedule = false,
  }) async {
    try {
      if (!mounted) return;

      final bool isManualToggle = !triggeredBySchedule;
      if (isManualToggle && _shopAutoScheduleEnabled && permanentlyDisableSchedule) {
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
        throw Exception(AppLocalizations.of(context)!.merchantUserNotFound);
      }

      final updated = await _merchantOrderService.toggleShopStatus(
        userId,
        value,
        disableAutoSchedule: !triggeredBySchedule && permanentlyDisableSchedule,
      );

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
                  ? (autoDisabled
                      ? AppLocalizations.of(context)!.merchantShopOpenedAutoOff
                      : AppLocalizations.of(context)!.merchantShopOpened)
                  : (autoDisabled
                      ? AppLocalizations.of(context)!.merchantShopClosedAutoOff
                      : AppLocalizations.of(context)!.merchantShopClosed),
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
            content: Text(AppLocalizations.of(context)!
                .merchantShopStatusError(e.toString())),
            backgroundColor: Theme.of(context).colorScheme.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _acceptOrder(String bookingId,
      {bool triggeredAutomatically = false}) async {
    try {
      debugLog('🏪 Merchant accepting order: $bookingId');

      final result = await _merchantOrderService.acceptOrder(bookingId);
      if (result.errorCode == 'unavailable') {
        _showErrorSnackBar('Order not available for acceptance');
        return;
      }
      if (result.errorCode == 'taken' || !result.accepted) {
        _showErrorSnackBar('Order already taken or not available');
        return;
      }

      // Send notification to customer
      await _notifyCustomerOrderAccepted(result.booking!);

      if (mounted) {
        if (!triggeredAutomatically) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content:
                  Text(AppLocalizations.of(context)!.merchantOrderConfirmed),
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
      _showErrorSnackBar('Cannot accept order: ${e.toString()}');
    }
  }

  // ignore: unused_element
  Future<void> _markFoodReady(String bookingId) async {
    try {
      final merchantId = AuthService.userId;
      if (merchantId == null) {
        _showErrorSnackBar('Merchant not authenticated');
        return;
      }

      final result = await _merchantOrderService.markFoodReady(
        bookingId: bookingId,
        merchantId: merchantId,
      );

      if (!result.success) {
        _showErrorSnackBar(
          result.errorMessage ?? 'Order not available for marking ready',
        );
        return;
      }

      if (result.pendingDriverArrival) {
        _showSuccessSnackBar('บันทึกอาหารพร้อมแล้ว รอคนขับถึงร้าน');
        return;
      }

      _showSuccessSnackBar('Food marked as ready for pickup');

      await BookingService()
          .notifyDriversAboutNewBooking(Booking.fromJson(result.booking!));

      // Send notification to customer and driver
      await _notifyFoodReady(result.booking!);
    } catch (e) {
      debugLog('❌ Failed to mark food ready: $e');
      _showErrorSnackBar('Failed to mark food ready: $e');
    }
  }

  // ignore: unused_element
  Future<void> _finishOrder(String bookingId) async {
    try {
      final didFinish = await _merchantOrderService.finishOrder(bookingId);
      if (!didFinish) {
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
      return AppLocalizations.of(context)!.merchantDriverStatusWaiting;
    } else if (status == 'driver_accepted' || status == 'matched') {
      final driverName = booking['driver_name'] ??
          AppLocalizations.of(context)!.merchantDriverDefault;
      return AppLocalizations.of(context)!
          .merchantDriverStatusComing(driverName);
    } else if (status == 'in_transit') {
      final driverName = booking['driver_name'] ??
          AppLocalizations.of(context)!.merchantDriverDefault;
      return AppLocalizations.of(context)!
          .merchantDriverStatusArrived(driverName);
    } else if (status == 'preparing') {
      return AppLocalizations.of(context)!.merchantDriverStatusPreparing;
    } else if (status == 'ready_for_pickup') {
      return AppLocalizations.of(context)!.merchantDriverStatusReady;
    } else {
      return AppLocalizations.of(context)!.merchantDriverStatusDefault;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'pending_merchant':
        return AppLocalizations.of(context)!.merchantStatusNewOrder;
      case 'pending':
        return AppLocalizations.of(context)!.merchantStatusPending;
      case 'preparing':
        return AppLocalizations.of(context)!.merchantStatusPreparing;
      case 'driver_accepted':
        return AppLocalizations.of(context)!.merchantStatusDriverAccepted;
      case 'arrived_at_merchant':
        return AppLocalizations.of(context)!.merchantStatusArrivedAtMerchant;
      case 'matched':
        return AppLocalizations.of(context)!.merchantStatusMatched;
      case 'ready_for_pickup':
        return AppLocalizations.of(context)!.merchantStatusReadyForPickup;
      case 'picking_up_order':
        return AppLocalizations.of(context)!.merchantStatusPickingUp;
      case 'in_transit':
        return AppLocalizations.of(context)!.merchantStatusInTransit;
      case 'completed':
        return AppLocalizations.of(context)!.merchantStatusCompleted;
      case 'cancelled':
        return AppLocalizations.of(context)!.merchantStatusCancelled;
      default:
        return AppLocalizations.of(context)!.merchantStatusUnknown;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: Text(_showHistory
            ? AppLocalizations.of(context)!.merchantAppBarHistory
            : AppLocalizations.of(context)!.merchantAppBarOrders),
        backgroundColor: colorScheme.surface,
        elevation: 0,
        foregroundColor: colorScheme.onSurface,
        actions: [
          // Toggle between active and history
          IconButton(
            icon: Icon(_showHistory ? Icons.list : Icons.history),
            onPressed: _toggleView,
            tooltip: _showHistory
                ? AppLocalizations.of(context)!.merchantTooltipActiveOrders
                : AppLocalizations.of(context)!.merchantTooltipHistory,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () async {
              await _fetchShopStatus();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content:
                        Text(AppLocalizations.of(context)!.merchantRefreshed),
                    duration: const Duration(seconds: 1),
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
              AppLocalizations.of(context)!.merchantErrorOccurred,
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
              child: Text(AppLocalizations.of(context)!.merchantRetry),
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
    return MerchantOrderList(
      orders: _orders,
      isLoading: _isLoading,
      error: _error,
      isShopOpen: _isShopOpen,
      onRetry: () async {
        if (!mounted) return;

        setState(() {
          _error = null;
          _isLoading = true;
        });
        await _fetchShopStatus();
        _setupOrdersStream();
      },
      orderBuilder: _buildOrderCard,
    );
  }

  Widget _buildShopStatusCard() {
    return MerchantShopStatusCard(
      isShopOpen: _isShopOpen,
      isAutoAcceptMode: _orderAcceptMode == _acceptModeAuto,
      isAutoScheduleEnabled: _shopAutoScheduleEnabled,
      onShopStatusChanged: (value) async {
        if (!mounted) return;

        final isManualClose = value == false;
        if (isManualClose) {
          final confirmed = await _confirmManualCloseShopDialog();
          if (!confirmed) return;
        }

        // When toggling manually while auto-schedule is active, ask if
        // the override should be permanent or just for today.
        bool permanentlyDisable = false;
        if (_shopAutoScheduleEnabled) {
          final choice = await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('ปิด Auto-Schedule?'),
              content: const Text(
                'ต้องการปิด auto-schedule แบบใด?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Override วันนี้เท่านั้น'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                  child: const Text('ปิดถาวร'),
                ),
              ],
            ),
          );
          if (choice == null) return; // ยกเลิก
          permanentlyDisable = choice;
        }

        await _toggleShopStatus(value, permanentlyDisableSchedule: permanentlyDisable);
      },
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final createdAtStr = order['created_at'] as String?;
    if (createdAtStr == null) {
      debugLog('❌ Missing created_at for order: ${order['id']}');
      return const SizedBox.shrink();
    }
    return MerchantOrderCard(
      order: order,
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MerchantOrderDetailScreen(order: order),
          ),
        );
      },
      onAcceptOrder: _acceptOrder,
      statusTextBuilder: _getStatusText,
    );
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
      final merchantName = merchantProfile?['full_name'] ??
          AppLocalizations.of(context)!.merchantNotifMerchantDefault;

      final success = await NotificationSender.sendNotification(
        targetUserId: customerId,
        title: AppLocalizations.of(context)!.merchantNotifOrderAccepted,
        body: AppLocalizations.of(context)!
            .merchantNotifPreparingBody(merchantName),
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
      final merchantName = merchantProfile?['full_name'] ??
          AppLocalizations.of(context)!.merchantNotifMerchantDefault;

      // Notify customer
      if (customerId != null && customerId.isNotEmpty) {
        debugLog('📤 Sending food ready notification to customer: $customerId');
        await NotificationSender.sendNotification(
          targetUserId: customerId,
          title: AppLocalizations.of(context)!.merchantNotifFoodReadyCustomer,
          body: AppLocalizations.of(context)!
              .merchantNotifFoodReadyCustomerBody(merchantName),
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
          title: AppLocalizations.of(context)!.merchantNotifFoodReadyDriver,
          body: AppLocalizations.of(context)!
              .merchantNotifFoodReadyDriverBody(merchantName),
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
          content: Text(_showHistory
              ? AppLocalizations.of(context)!.merchantViewHistory
              : AppLocalizations.of(context)!.merchantViewActive),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }
}
