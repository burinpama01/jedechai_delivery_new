import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'dart:convert';
import 'dart:async';
import 'package:googleapis_auth/auth_io.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../config/env_config.dart';

class NotificationSender {
  // --- 1. การตั้งค่า Service Account (Key V1) - loaded from .env ---
  static Map<String, String> get _serviceAccountJson =>
      EnvConfig.firebaseServiceAccountJson;

  static const String _kIosApnsTopic = 'com.burin.jdcdelivery';

  static const _scopes = ['https://www.googleapis.com/auth/firebase.messaging'];

  static AuthClient? _cachedAuthClient;
  static DateTime? _cachedAuthClientCreatedAt;
  static Completer<AuthClient>? _authClientInitCompleter;

  static bool _isMerchantNewOrder(Map<String, String>? data) {
    final type = (data?['type'] ?? data?['notification_type'])?.trim();
    return type == 'merchant_new_order';
  }

  static Future<AuthClient> _getAuthClient() async {
    final now = DateTime.now();

    // Reuse client for up to ~50 minutes (access tokens typically last 1 hour)
    if (_cachedAuthClient != null &&
        _cachedAuthClientCreatedAt != null &&
        now.difference(_cachedAuthClientCreatedAt!).inMinutes < 50) {
      return _cachedAuthClient!;
    }

    if (_authClientInitCompleter != null) {
      return _authClientInitCompleter!.future;
    }
    _authClientInitCompleter = Completer<AuthClient>();

    try {
      // Close previous client if any
      try {
        _cachedAuthClient?.close();
      } catch (_) {}

      final newClient = await clientViaServiceAccount(
        ServiceAccountCredentials.fromJson(_serviceAccountJson),
        _scopes,
      );

      _cachedAuthClient = newClient;
      _cachedAuthClientCreatedAt = now;
      _authClientInitCompleter!.complete(newClient);
      return newClient;
    } catch (e) {
      _authClientInitCompleter!.completeError(e);
      rethrow;
    } finally {
      _authClientInitCompleter = null;
    }
  }

  // --- 2. ฟังก์ชันหลัก: สั่งงานด้วย User ID (ใช้ง่ายสุดๆ) ---
  static Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, String>? data,
    bool persistInApp = true,
  }) async {
    try {
      if (persistInApp) {
        await _persistInAppNotification(
          userId: userId,
          title: title,
          body: body,
          data: data,
        );
      }

      debugLog('🔍 กำลังค้นหา Token ของ User: $userId');

      // ดึง Token จาก Supabase
      final response = await Supabase.instance.client
          .from('profiles')
          .select('fcm_token')
          .eq('id', userId)
          .maybeSingle();

      if (response == null || response['fcm_token'] == null) {
        debugLog(
            '⚠️ ไม่พบ Token ของผู้ใช้นี้ (เขาอาจจะยังไม่เคย Login หรือไม่ได้เปิด Net)');
        return;
      }

      String token = response['fcm_token'];
      await _sendViaV1(token, title, body, userId: userId, data: data);
    } catch (e) {
      debugLog('💥 Error ในการส่งแจ้งเตือน: $e');
    }
  }

  static Future<void> _persistInAppNotification({
    required String userId,
    required String title,
    required String body,
    Map<String, String>? data,
  }) async {
    try {
      await Supabase.instance.client.from('notifications').insert({
        'user_id': userId,
        'title': title,
        'body': body,
        'type': data?['type'],
        'data': data,
      });
    } catch (e) {
      // Best-effort only: notification feed insert failure should not block FCM delivery
      debugLog('⚠️ บันทึก in-app notification ไม่สำเร็จ: $e');
    }
  }

  // --- 3. ระบบส่ง V1 (Private Function) ---
  static Future<bool> _sendViaV1(String token, String title, String body,
      {String? userId, Map<String, String>? data}) async {
    try {
      final authClient = await _getAuthClient();

      final isMerchantNewOrder = _isMerchantNewOrder(data);
      final androidChannelId = isMerchantNewOrder
          ? 'merchant_new_order_channel_v1'
          : 'high_importance_channel';
      final androidSound = isMerchantNewOrder ? 'alert_new_order' : 'default';
      final iosSound = isMerchantNewOrder ? 'AlertNewOrder.caf' : 'default';

      final collapseId = isMerchantNewOrder
          ? 'merchant_new_order_${data?['booking_id'] ?? DateTime.now().millisecondsSinceEpoch}'
          : 'default_${DateTime.now().millisecondsSinceEpoch}';

      final mergedData = {
        'title': title,
        'body': body,
        "click_action": "FLUTTER_NOTIFICATION_CLICK",
        "sound": androidSound,
        "ios_sound": iosSound,
        if (data != null) ...data,
      };

      final apnsPayload = {
        'headers': {
          'apns-push-type': 'alert',
          'apns-priority': '10',
          'apns-topic': _kIosApnsTopic,
          // Reduce APNs collapsing which can suppress repeated sound
          'apns-collapse-id': collapseId,
        },
        'payload': {
          'aps': {
            'alert': {
              'title': title,
              'body': body,
            },
            'sound': iosSound,
          },
        },
      };

      final messagePayload = {
        'token': token,
        'data': mergedData,
        'android': {
          'priority': 'high',
          if (!isMerchantNewOrder)
            'notification': {
              'channel_id': androidChannelId,
              'sound': androidSound,
            },
        },
        if (!isMerchantNewOrder)
          'notification': {
            'title': title,
            'body': body,
          },
        'apns': apnsPayload,
      };

      final response = await authClient.post(
        Uri.parse(
            'https://fcm.googleapis.com/v1/projects/${_serviceAccountJson['project_id']}/messages:send'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "message": {
            ...messagePayload,
          }
        }),
      );

      if (response.statusCode == 200) {
        debugLog('✅ ส่ง Notification สำเร็จ! (V1)');
        debugLog('   └─ Token: ${token.substring(0, 20)}...');
        debugLog('   └─ Title: $title');
        debugLog('   └─ Body: $body');
        return true;
      } else {
        debugLog('❌ ส่งไม่สำเร็จ: ${response.statusCode}');
        debugLog('   └─ Response: ${response.body}');

        // ตรวจสอบว่าเป็น error 404 UNREGISTERED หรือไม่
        if (response.statusCode == 404 && userId != null) {
          final responseBody = jsonDecode(response.body);
          final details = responseBody['error']?['details'] as List?;

          if (details != null &&
              details.any((detail) => detail['errorCode'] == 'UNREGISTERED')) {
            debugLog('🗑️ Token ไม่ถูกต้อง/หมดอายุ กำลังลบจากฐานข้อมูล...');
            await _removeInvalidToken(userId);
          }
        }
      }
      return false;
    } catch (e) {
      debugLog('💥 Error V1 API: $e');
      return false;
    }
  }

  // --- 4. ลบ Token ที่ไม่ถูกต้อง ---
  static Future<void> _removeInvalidToken(String userId) async {
    try {
      await Supabase.instance.client
          .from('profiles')
          .update({'fcm_token': null}).eq('id', userId);
      debugLog('✅ ลบ Token ที่ไม่ถูกต้องเรียบร้อยแล้ว: $userId');
    } catch (e) {
      debugLog('❌ ไม่สามารถลบ Token ได้: $e');
    }
  }

  // --- 5. Compatibility Method (สำหรับโค้ดเก่า) ---
  static Future<bool> sendNotification({
    required String targetUserId,
    required String title,
    required String body,
    Map<String, String>? data,
    bool persistInApp = true,
  }) async {
    try {
      if (persistInApp) {
        await _persistInAppNotification(
          userId: targetUserId,
          title: title,
          body: body,
          data: data,
        );
      }

      debugLog('🔍 กำลังค้นหา Token ของ User: $targetUserId');
      final response = await Supabase.instance.client
          .from('profiles')
          .select('fcm_token')
          .eq('id', targetUserId)
          .maybeSingle();

      final token = response?['fcm_token'] as String?;
      if (token == null || token.trim().isEmpty) {
        debugLog('⚠️ ไม่พบ Token ของผู้ใช้นี้');
        return false;
      }

      return await _sendViaV1(token.trim(), title, body,
          userId: targetUserId, data: data);
    } catch (e) {
      debugLog('❌ Error in sendNotification: $e');
      return false;
    }
  }
}
