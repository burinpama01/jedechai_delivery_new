import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/debug_logger.dart';
import 'admin_telegram_notification_service.dart';

class AdminLineNotificationService {
  const AdminLineNotificationService._();

  /// Fires LINE and Telegram notifications in parallel.
  /// Each channel checks its own enabled flag server-side and skips if disabled.
  static Future<void> notify({
    required String eventType,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    final body = {
      'event_type': eventType,
      'title': title,
      'message': message,
      if (data != null) 'data': data,
    };

    await Future.wait([
      _sendLine(body, eventType),
      AdminTelegramNotificationService.notify(
        eventType: eventType,
        title: title,
        message: message,
        data: data,
      ),
    ]);
  }

  static Future<void> _sendLine(Map<String, dynamic> body, String eventType) async {
    try {
      final response = await Supabase.instance.client.functions.invoke('send-admin-line', body: body);

      if (response.status >= 400) {
        debugLog('LINE admin notification failed: HTTP ${response.status}');
        return;
      }

      final responseData = response.data;
      if (responseData is Map && responseData['success'] == false) {
        debugLog('LINE admin notification failed: ${responseData['error']}');
        return;
      }

      debugLog('LINE admin notification sent: $eventType');
    } catch (e) {
      debugLog('LINE admin notification failed: $e');
    }
  }
}
