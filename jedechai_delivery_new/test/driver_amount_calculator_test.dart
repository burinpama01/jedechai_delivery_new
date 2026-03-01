import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/models/booking.dart';
import 'package:jedechai_delivery_new/common/utils/driver_amount_calculator.dart';

void main() {
  group('DriverAmountCalculator', () {
    test('grossCollect for food = price + deliveryFee', () {
      final b = Booking.fromJson({
        'id': '1',
        'customer_id': 'c1',
        'driver_id': 'd1',
        'service_type': 'food',
        'merchant_id': 'm1',
        'origin_lat': 0,
        'origin_lng': 0,
        'dest_lat': 0,
        'dest_lng': 0,
        'distance_km': 0,
        'price': 100,
        'delivery_fee': 20,
        'status': 'completed',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      });

      expect(DriverAmountCalculator.grossCollect(b), 120);
    });

    test('netCollect subtracts coupon and clamps at 0', () {
      final b = Booking.fromJson({
        'id': '1',
        'customer_id': 'c1',
        'driver_id': 'd1',
        'service_type': 'ride',
        'merchant_id': null,
        'origin_lat': 0,
        'origin_lng': 0,
        'dest_lat': 0,
        'dest_lng': 0,
        'distance_km': 0,
        'price': 50,
        'status': 'completed',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      });

      expect(
        DriverAmountCalculator.netCollect(booking: b, couponDiscountAmount: 10),
        40,
      );
      expect(
        DriverAmountCalculator.netCollect(booking: b, couponDiscountAmount: 999),
        0,
      );
    });

    test('appFee prefers booking.appEarnings', () {
      final b = Booking.fromJson({
        'id': '1',
        'customer_id': 'c1',
        'driver_id': 'd1',
        'service_type': 'ride',
        'merchant_id': null,
        'origin_lat': 0,
        'origin_lng': 0,
        'dest_lat': 0,
        'dest_lng': 0,
        'distance_km': 0,
        'price': 50,
        'driver_earnings': 35,
        'app_earnings': 15,
        'status': 'completed',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      });

      expect(
        DriverAmountCalculator.appFee(booking: b, netCollectAmount: 50),
        15,
      );
    });

    test('appFee falls back to netCollect - driverEarnings if appEarnings missing', () {
      final b = Booking.fromJson({
        'id': '1',
        'customer_id': 'c1',
        'driver_id': 'd1',
        'service_type': 'ride',
        'merchant_id': null,
        'origin_lat': 0,
        'origin_lng': 0,
        'dest_lat': 0,
        'dest_lng': 0,
        'distance_km': 0,
        'price': 50,
        'driver_earnings': 40,
        'app_earnings': null,
        'status': 'completed',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      });

      expect(
        DriverAmountCalculator.appFee(booking: b, netCollectAmount: 50),
        10,
      );
    });

    test('netEarnings prefers booking.driverEarnings', () {
      final b = Booking.fromJson({
        'id': '1',
        'customer_id': 'c1',
        'driver_id': 'd1',
        'service_type': 'ride',
        'merchant_id': null,
        'origin_lat': 0,
        'origin_lng': 0,
        'dest_lat': 0,
        'dest_lng': 0,
        'distance_km': 0,
        'price': 50,
        'driver_earnings': 40,
        'app_earnings': null,
        'status': 'completed',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      });

      final net = DriverAmountCalculator.netEarnings(
        booking: b,
        netCollectAmount: 50,
        appFeeAmount: 10,
      );
      expect(net, 40);
    });

    test('netEarnings falls back to netCollect - appFee when driverEarnings missing', () {
      final b = Booking.fromJson({
        'id': '1',
        'customer_id': 'c1',
        'driver_id': 'd1',
        'service_type': 'ride',
        'merchant_id': null,
        'origin_lat': 0,
        'origin_lng': 0,
        'dest_lat': 0,
        'dest_lng': 0,
        'distance_km': 0,
        'price': 50,
        'driver_earnings': null,
        'app_earnings': null,
        'status': 'completed',
        'created_at': '2024-01-01T00:00:00.000Z',
        'updated_at': '2024-01-01T00:00:00.000Z',
      });

      final net = DriverAmountCalculator.netEarnings(
        booking: b,
        netCollectAmount: 50,
        appFeeAmount: 10,
      );
      expect(net, 40);
    });
  });
}
