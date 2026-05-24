import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/debug_logger.dart';

class AdminTelegramNotificationService {
  const AdminTelegramNotificationService._();

  static Future<void> notify({
    required String eventType,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'send-admin-telegram',
        body: {
          'event_type': eventType,
          'title': title,
          'message': message,
          if (data != null) 'data': data,
        },
      );
      debugLog('Telegram admin notification sent: $eventType');
    } catch (e) {
      debugLog('Telegram admin notification failed: $e');
    }
  }
}
