import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/debug_logger.dart';

class AdminTelegramNotificationService {
  const AdminTelegramNotificationService._();

  static Future<({bool success, String? error})> notify({
    required String eventType,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        'send-admin-telegram',
        body: {
          'event_type': eventType,
          'title': title,
          'message': message,
          if (data != null) 'data': data,
        },
      );

      if (response.status >= 400) {
        final errMsg = 'Telegram HTTP ${response.status}';
        debugLog('Telegram admin notification failed: $errMsg');
        return (success: false, error: errMsg);
      }

      final responseData = response.data;
      if (responseData is Map) {
        final skipped = responseData['skipped'] as String?;
        if (skipped != null) {
          debugLog('Telegram admin notification skipped: $skipped');
          return (success: true, error: null);
        }
        if (responseData['success'] == false) {
          final errMsg = responseData['error']?.toString() ?? 'success=false';
          debugLog('Telegram admin notification failed: $errMsg');
          return (success: false, error: errMsg);
        }
      }

      debugLog('Telegram admin notification sent: $eventType');
      return (success: true, error: null);
    } catch (e) {
      debugLog('Telegram admin notification failed: $e');
      return (success: false, error: e.toString());
    }
  }
}
