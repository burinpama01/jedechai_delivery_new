import 'dart:convert';

class NotificationTypes {
  static const customerBookingStatusChanged = 'customer.booking.status_changed';
  static const customerBookingDriverAssigned =
      'customer.booking.driver_assigned';
  static const driverJobAvailable = 'driver.job.available';
  static const driverJobAssigned = 'driver.job.assigned';
  static const merchantOrderCreated = 'merchant.order.created';
  static const merchantOrderAdminAction = 'merchant.order.admin_action';
  static const laundryQuoteRequested = 'laundry.quote_requested';
  static const adminOrderCreated = 'admin.order.created';
  static const newTicket = 'new_ticket';
  static const ticketUpdated = 'ticket_updated';

  static const legacyNewBooking = 'new_booking';
  static const legacyNewRideRequest = 'new_ride_request';
  static const legacyMerchantNewOrder = 'merchant_new_order';
  static const legacyDriverJobAvailable = 'driver_job_available';
}

class NotificationRoles {
  static const customer = 'customer';
  static const driver = 'driver';
  static const merchant = 'merchant';
  static const admin = 'admin';
}

class NotificationRouteScreens {
  static const login = 'login';
  static const customerOrder = 'customer_order';
  static const customerRideStatus = 'customer_ride_status';
  static const driverDashboard = 'driver_dashboard';
  static const merchantOrder = 'merchant_order';
  static const merchantDashboard = 'merchant_dashboard';
  static const rideService = 'ride_service';
  static const foodService = 'food_service';
  static const parcelService = 'parcel_service';
  static const map = 'map';
}

class NotificationNavigationTarget {
  final String routeName;
  final Object? arguments;

  const NotificationNavigationTarget({
    required this.routeName,
    this.arguments,
  });
}

class NotificationPayloadPolicy {
  static bool isMerchantNewOrder(Map<String, dynamic> data) {
    final type = _type(data);
    return type == NotificationTypes.merchantOrderCreated ||
        type == NotificationTypes.laundryQuoteRequested ||
        type == NotificationTypes.legacyMerchantNewOrder;
  }

  static bool isDriverJobAvailable(Map<String, dynamic> data) {
    final type = _type(data);
    return type == NotificationTypes.driverJobAvailable ||
        type == NotificationTypes.legacyDriverJobAvailable ||
        type == NotificationTypes.legacyNewBooking ||
        type == NotificationTypes.legacyNewRideRequest;
  }

  static Map<String, String> buildBookingPayload({
    required String type,
    required String recipientRole,
    required String bookingId,
    required String serviceType,
    String? screen,
    String? route,
    Map<String, dynamic>? routeArgs,
    Map<String, String>? extra,
  }) {
    return {
      'type': type,
      'recipient_role': recipientRole,
      'booking_id': bookingId,
      'service_type': serviceType,
      if (screen != null && screen.isNotEmpty) 'screen': screen,
      if (route != null && route.isNotEmpty) 'route': route,
      if (routeArgs != null && routeArgs.isNotEmpty)
        'route_args': jsonEncode(routeArgs),
      if (extra != null) ...extra,
    };
  }

  static NotificationNavigationTarget? resolveNavigationTarget(
    Map<String, dynamic> data,
  ) {
    final explicitRoute = _string(data['route']);
    final routeName = explicitRoute != null && explicitRoute.startsWith('/')
        ? explicitRoute
        : _routeFromScreenTypeRole(data);
    if (routeName == null) return null;

    return NotificationNavigationTarget(
      routeName: routeName,
      arguments: _buildArguments(data, routeName),
    );
  }

  static String? _routeFromScreenTypeRole(Map<String, dynamic> data) {
    final screen = _string(data['screen']);
    switch (screen) {
      case NotificationRouteScreens.login:
        return '/login';
      case NotificationRouteScreens.driverDashboard:
        return '/driver_dashboard';
      case NotificationRouteScreens.merchantDashboard:
        return '/merchant_dashboard';
      case NotificationRouteScreens.merchantOrder:
        return '/merchant_order_detail';
      case NotificationRouteScreens.rideService:
        return '/ride_service';
      case NotificationRouteScreens.customerRideStatus:
        return '/customer_ride_status';
      case NotificationRouteScreens.foodService:
        return '/food_service';
      case NotificationRouteScreens.customerOrder:
        return '/customer_order_detail';
      case NotificationRouteScreens.parcelService:
        return '/parcel_service';
      case NotificationRouteScreens.map:
        return '/map';
    }

    final type = _type(data);
    switch (type) {
      case NotificationTypes.driverJobAvailable:
      case NotificationTypes.driverJobAssigned:
      case NotificationTypes.legacyNewBooking:
      case NotificationTypes.legacyNewRideRequest:
      case NotificationTypes.legacyDriverJobAvailable:
        return '/driver_job_detail';
      case NotificationTypes.merchantOrderCreated:
      case NotificationTypes.merchantOrderAdminAction:
      case NotificationTypes.legacyMerchantNewOrder:
        return '/merchant_order_detail';
      case NotificationTypes.customerBookingStatusChanged:
      case NotificationTypes.customerBookingDriverAssigned:
        return _customerDetailRouteForServiceType(
            _string(data['service_type']));
      case NotificationTypes.newTicket:
        return '/admin_tickets';
      case NotificationTypes.ticketUpdated:
        return '/my_tickets';
    }

    final role = _string(data['recipient_role']) ?? _string(data['role']);
    switch (role) {
      case NotificationRoles.driver:
        return '/driver_dashboard';
      case NotificationRoles.merchant:
        return '/merchant_dashboard';
      case NotificationRoles.customer:
        return _customerRouteForServiceType(_string(data['service_type']));
      default:
        return null;
    }
  }

  static String _customerRouteForServiceType(String? serviceType) {
    switch (serviceType) {
      case 'food':
        return '/food_service';
      case 'parcel':
        return '/parcel_service';
      case 'ride':
      default:
        return '/ride_service';
    }
  }

  static String _customerDetailRouteForServiceType(String? serviceType) {
    switch (serviceType) {
      case 'ride':
        return '/customer_ride_status';
      case 'food':
      case 'parcel':
      default:
        return '/customer_order_detail';
    }
  }

  static Object? _buildArguments(
    Map<String, dynamic> data,
    String routeName,
  ) {
    final args = <String, dynamic>{};
    final decodedArgs = _parseRouteArgs(data['route_args']);
    if (decodedArgs is Map) {
      args.addAll(decodedArgs.map((key, value) => MapEntry('$key', value)));
    }

    void copy(String key) {
      final value = _string(data[key]);
      if (value != null) args[key] = value;
    }

    copy('booking_id');
    copy('service_type');
    final inferredServiceType = _serviceTypeFromType(data);
    if (inferredServiceType != null) {
      args.putIfAbsent('service_type', () => inferredServiceType);
    }

    final role = _string(data['recipient_role']) ??
        _string(data['role']) ??
        _roleFromType(data);
    if (role != null) args['recipient_role'] = role;

    if ((routeName == '/driver_dashboard' ||
            routeName == '/driver_job_detail') &&
        args['booking_id'] != null) {
      args.putIfAbsent('highlight_booking_id', () => args['booking_id']);
    }

    return args.isEmpty ? null : args;
  }

  static dynamic _parseRouteArgs(dynamic rawArgs) {
    if (rawArgs == null) return null;
    if (rawArgs is Map || rawArgs is List) return rawArgs;
    if (rawArgs is String && rawArgs.trim().isNotEmpty) {
      try {
        return jsonDecode(rawArgs);
      } catch (_) {
        return rawArgs;
      }
    }
    return rawArgs;
  }

  static String? _type(Map<String, dynamic> data) {
    return _string(data['type']) ?? _string(data['notification_type']);
  }

  static String? _roleFromType(Map<String, dynamic> data) {
    final type = _type(data);
    switch (type) {
      case NotificationTypes.driverJobAvailable:
      case NotificationTypes.driverJobAssigned:
      case NotificationTypes.legacyNewBooking:
      case NotificationTypes.legacyNewRideRequest:
      case NotificationTypes.legacyDriverJobAvailable:
        return NotificationRoles.driver;
      case NotificationTypes.merchantOrderCreated:
      case NotificationTypes.merchantOrderAdminAction:
      case NotificationTypes.legacyMerchantNewOrder:
        return NotificationRoles.merchant;
      case NotificationTypes.customerBookingStatusChanged:
      case NotificationTypes.customerBookingDriverAssigned:
        return NotificationRoles.customer;
      default:
        return null;
    }
  }

  static String? _serviceTypeFromType(Map<String, dynamic> data) {
    final type = _type(data);
    switch (type) {
      case NotificationTypes.merchantOrderCreated:
      case NotificationTypes.merchantOrderAdminAction:
      case NotificationTypes.legacyMerchantNewOrder:
        return 'food';
      default:
        return null;
    }
  }

  static String? _string(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
