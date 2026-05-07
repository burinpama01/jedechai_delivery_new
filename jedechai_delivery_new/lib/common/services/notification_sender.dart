import 'dart:convert';

import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../utils/notification_payload_policy.dart';

class NotificationSender {
  static bool _isMerchantNewOrder(Map<String, String>? data) {
    return NotificationPayloadPolicy.isMerchantNewOrder(
      data == null ? const {} : Map<String, dynamic>.from(data),
    );
  }

  static Future<void> sendToUser({
    required String userId,
    required String title,
    required String body,
    Map<String, String>? data,
    bool persistInApp = true,
  }) async {
    try {
      await _sendViaEdgeFunction(
        targetUserId: userId,
        title: title,
        body: body,
        data: data,
        persistInApp: persistInApp,
      );
    } catch (e) {
      debugLog('Error sending notification: $e');
    }
  }

  static Future<bool> _sendViaEdgeFunction({
    required String targetUserId,
    required String title,
    required String body,
    Map<String, String>? data,
    String? notificationId,
    bool persistInApp = true,
  }) async {
    try {
      final mergedData = {
        'title': title,
        'body': body,
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
        'sound': _isMerchantNewOrder(data) ? 'alert_new_order' : 'default',
        if (data != null) ...data,
      };

      final response = await Supabase.instance.client.functions.invoke(
        'send-fcm-notification',
        body: {
          'user_ids': [targetUserId],
          'title': title,
          'message': body,
          'data': mergedData,
          if (notificationId != null) 'notification_id': notificationId,
          'persist_in_app': persistInApp,
        },
      );

      final result = response.data;
      if (result is Map && result['success'] == true) {
        debugLog('Notification sent via Edge Function');
        return true;
      }

      debugLog('Edge Function notification failed: ${jsonEncode(result)}');
      return false;
    } catch (e) {
      debugLog('Edge FCM API error: $e');
      return false;
    }
  }

  static Future<bool> sendNotification({
    required String targetUserId,
    required String title,
    required String body,
    Map<String, String>? data,
    bool persistInApp = true,
    String? notificationId,
  }) async {
    try {
      return await _sendViaEdgeFunction(
        targetUserId: targetUserId,
        title: title,
        body: body,
        data: data,
        notificationId: notificationId,
        persistInApp: persistInApp,
      );
    } catch (e) {
      debugLog('Error in sendNotification: $e');
      return false;
    }
  }
}
