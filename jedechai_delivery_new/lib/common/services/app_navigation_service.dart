import 'dart:convert';

import 'package:flutter/material.dart';

/// Centralized app navigation helpers (used by background services)
class AppNavigationService {
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  static void openFromNotification(Map<String, dynamic> data) {
    final navigator = navigatorKey.currentState;
    if (navigator == null) return;

    final routeName = _resolveRouteName(data);
    if (routeName == null) return;

    final args = _parseRouteArgs(data['route_args']);
    navigator.pushNamed(routeName, arguments: args);
  }

  static String? _resolveRouteName(Map<String, dynamic> data) {
    final route = data['route']?.toString();
    if (route != null && route.startsWith('/')) return route;

    final screen = data['screen']?.toString();
    if (screen != null) {
      switch (screen) {
        case 'login':
          return '/login';
        case 'driver_dashboard':
          return '/driver_dashboard';
        case 'merchant_dashboard':
          return '/merchant_dashboard';
        case 'ride_service':
          return '/ride_service';
        case 'food_service':
          return '/food_service';
        case 'parcel_service':
          return '/parcel_service';
        case 'map':
          return '/map';
      }
    }

    final role = data['role']?.toString();
    switch (role) {
      case 'driver':
        return '/driver_dashboard';
      case 'merchant':
        return '/merchant_dashboard';
      case 'customer':
        return '/ride_service';
      default:
        return null;
    }
  }

  static Object? _parseRouteArgs(dynamic rawArgs) {
    if (rawArgs == null) return null;
    if (rawArgs is Map || rawArgs is List) return rawArgs;
    if (rawArgs is String) {
      try {
        return jsonDecode(rawArgs);
      } catch (_) {
        return rawArgs;
      }
    }
    return rawArgs;
  }
}
