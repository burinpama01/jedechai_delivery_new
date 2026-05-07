import 'package:flutter/material.dart';

import '../utils/notification_payload_policy.dart';

/// Centralized app navigation helpers (used by background services)
class AppNavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static void openFromNotification(Map<String, dynamic> data) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    final target = NotificationPayloadPolicy.resolveNavigationTarget(data);
    if (target == null) return;

    navigator.pushNamed(target.routeName, arguments: target.arguments);
  }
}
