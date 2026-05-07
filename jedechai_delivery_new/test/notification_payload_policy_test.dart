import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/utils/notification_payload_policy.dart';

void main() {
  group('NotificationPayloadPolicy routing', () {
    test('routes customer booking payloads by service type with booking id',
        () {
      final target = NotificationPayloadPolicy.resolveNavigationTarget({
        'type': NotificationTypes.customerBookingStatusChanged,
        'recipient_role': 'customer',
        'booking_id': 'booking-1',
        'service_type': 'food',
      });

      expect(target?.routeName, '/customer_order_detail');
      expect(target?.arguments, {
        'booking_id': 'booking-1',
        'service_type': 'food',
        'recipient_role': 'customer',
      });
    });

    test('maps legacy driver job types to driver dashboard with highlight args',
        () {
      final target = NotificationPayloadPolicy.resolveNavigationTarget({
        'type': 'new_ride_request',
        'booking_id': 'ride-1',
        'service_type': 'ride',
      });

      expect(target?.routeName, '/driver_job_detail');
      expect(target?.arguments, {
        'booking_id': 'ride-1',
        'service_type': 'ride',
        'recipient_role': 'driver',
        'highlight_booking_id': 'ride-1',
      });
    });

    test('maps merchant order types to merchant dashboard with order args', () {
      final target = NotificationPayloadPolicy.resolveNavigationTarget({
        'type': 'merchant_new_order',
        'booking_id': 'food-1',
      });

      expect(target?.routeName, '/merchant_order_detail');
      expect(target?.arguments, {
        'booking_id': 'food-1',
        'service_type': 'food',
        'recipient_role': 'merchant',
      });
    });

    test('keeps explicit route and merges decoded route args', () {
      final target = NotificationPayloadPolicy.resolveNavigationTarget({
        'route': '/driver_dashboard',
        'booking_id': 'job-1',
        'route_args': '{"tab":"jobs"}',
      });

      expect(target?.routeName, '/driver_dashboard');
      expect(target?.arguments, {
        'tab': 'jobs',
        'booking_id': 'job-1',
        'highlight_booking_id': 'job-1',
      });
    });
  });
}
