import 'dart:async';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import '../../utils/debug_logger.dart';

/// Foreground Service สำหรับ Driver Location Tracking
///
/// แสดง persistent notification "JDC Delivery: กำลังติดตามตำแหน่งคนขับ..."
/// เมื่อคนขับออนไลน์ — แม้จะกด Home ออกไปหน้าจอหลักก็ยังเห็น notification
class DriverForegroundService {
  static bool _initialized = false;
  static bool _isRunning = false;

  /// เริ่มต้น foreground task configuration (เรียกครั้งเดียวตอน init)
  static void init() {
    if (_initialized) return;
    _initialized = true;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'jdc_driver_tracking',
        channelName: 'การติดตามตำแหน่งคนขับ',
        channelDescription: 'แจ้งเตือนเมื่อกำลังติดตามตำแหน่งคนขับ',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
        showWhen: false,
        enableVibration: false,
        playSound: false,
        visibility: NotificationVisibility.VISIBILITY_PUBLIC,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: false,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );
  }

  /// เริ่ม foreground service — แสดง persistent notification
  static Future<void> start() async {
    if (_isRunning) return;

    init();

    // ขอ notification permission ก่อน (Android 13+)
    final notifPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notifPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    try {
      final result = await FlutterForegroundTask.startService(
        notificationTitle: 'JDC Delivery',
        notificationText: 'กำลังติดตามตำแหน่งคนขับ...',
        notificationIcon: null,
        callback: _startCallback,
      );

      if (result is ServiceRequestSuccess) {
        _isRunning = true;
        debugLog('✅ Foreground service started');
      } else {
        debugLog('⚠️ Foreground service start result: $result');
      }
    } catch (e) {
      // ServiceAlreadyStartedException — ถือว่า running อยู่แล้ว
      _isRunning = true;
      debugLog('⚠️ Foreground service start (already running or error): $e');
    }
  }

  /// หยุด foreground service — ซ่อน notification
  static Future<void> stop() async {
    if (!_isRunning) return;

    try {
      final result = await FlutterForegroundTask.stopService();
      if (result is ServiceRequestSuccess) {
        _isRunning = false;
        debugLog('✅ Foreground service stopped');
      } else {
        debugLog('⚠️ Foreground service stop result: $result');
      }
    } catch (e) {
      _isRunning = false;
      debugLog('⚠️ Foreground service stop error: $e');
    }
  }

  /// อัพเดตข้อความ notification
  static Future<void> updateNotification(String text) async {
    if (!_isRunning) return;
    try {
      await FlutterForegroundTask.updateService(
        notificationTitle: 'JDC Delivery',
        notificationText: text,
      );
    } catch (e) {
      debugLog('⚠️ Failed to update foreground notification: $e');
    }
  }

  static bool get isRunning => _isRunning;
}

// Top-level callback function required by flutter_foreground_task
@pragma('vm:entry-point')
void _startCallback() {
  FlutterForegroundTask.setTaskHandler(_DriverTrackingTaskHandler());
}

/// Task handler ทำงานใน foreground service isolate
class _DriverTrackingTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    // Service started — ไม่ต้องทำอะไรเพิ่ม (location tracking จัดการโดย main isolate)
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    // Heartbeat — ให้ service ยังคงทำงานอยู่
    // Location tracking หลักจัดการโดย Geolocator stream ใน main isolate
  }

  @override
  Future<void> onDestroy(DateTime timestamp) async {
    // Service destroyed
  }

  @override
  void onReceiveData(Object data) {
    // รับข้อมูลจาก main isolate (ถ้าต้องการ)
  }

  @override
  void onNotificationButtonPressed(String id) {
    // ผู้ใช้กดปุ่มใน notification (ถ้ามี)
  }

  @override
  void onNotificationPressed() {
    // ผู้ใช้กด notification — กลับเข้าแอป
    FlutterForegroundTask.launchApp();
  }

  @override
  void onNotificationDismissed() {
    // notification ถูกปัดออก (sticky notification จะไม่ถูกปัดได้)
  }
}
