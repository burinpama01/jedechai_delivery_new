import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/debug_logger.dart';

class AdminLineNotificationService {
  const AdminLineNotificationService._();

  static Future<void> notify({
    required String eventType,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    try {
      await Supabase.instance.client.functions.invoke(
        'send-admin-line',
        body: {
          'event_type': eventType,
          'title': title,
          'message': message,
          if (data != null) 'data': data,
        },
      );
      debugLog('LINE admin notification sent: $eventType');
    } catch (e) {
      debugLog('LINE admin notification failed: $e');
    }
  }
}
