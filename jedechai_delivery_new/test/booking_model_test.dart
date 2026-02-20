import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/models/booking.dart';

void main() {
  // Sample JSON data mimicking Supabase response
  final sampleJson = {
    'id': 'abc-123',
    'customer_id': 'cust-001',
    'driver_id': 'drv-001',
    'service_type': 'ride',
    'merchant_id': null,
    'origin_lat': 13.7563,
    'origin_lng': 100.5018,
    'pickup_address': 'Central World',
    'dest_lat': 13.7460,
    'dest_lng': 100.5347,
    'destination_address': 'Siam Paragon',
    'distance_km': 2.5,
    'price': 75.0,
    'status': 'pending',
    'created_at': '2024-01-15T10:30:00.000Z',
    'updated_at': '2024-01-15T10:30:00.000Z',
    'assigned_at': null,
    'started_at': null,
    'completed_at': null,
    'driver_name': 'สมชาย',
    'driver_phone': '0812345678',
    'driver_vehicle': 'รถจักรยานยนต์',
    'notes': 'รอหน้าตึก',
    'payment_method': 'cash',
    'delivery_fee': null,
    'driver_earnings': null,
    'app_earnings': null,
  };

  group('Booking.fromJson', () {
    test('parses all required fields correctly', () {
      final booking = Booking.fromJson(sampleJson);

      expect(booking.id, 'abc-123');
      expect(booking.customerId, 'cust-001');
      expect(booking.serviceType, 'ride');
      expect(booking.originLat, 13.7563);
      expect(booking.originLng, 100.5018);
      expect(booking.destLat, 13.7460);
      expect(booking.destLng, 100.5347);
      expect(booking.distanceKm, 2.5);
      expect(booking.price, 75.0);
      expect(booking.status, 'pending');
      expect(booking.createdAt, DateTime.parse('2024-01-15T10:30:00.000Z'));
      expect(booking.updatedAt, DateTime.parse('2024-01-15T10:30:00.000Z'));
    });

    test('parses nullable fields correctly', () {
      final booking = Booking.fromJson(sampleJson);

      expect(booking.driverId, 'drv-001');
      expect(booking.merchantId, isNull);
      expect(booking.pickupAddress, 'Central World');
      expect(booking.destinationAddress, 'Siam Paragon');
      expect(booking.driverName, 'สมชาย');
      expect(booking.driverPhone, '0812345678');
      expect(booking.driverVehicle, 'รถจักรยานยนต์');
      expect(booking.notes, 'รอหน้าตึก');
      expect(booking.paymentMethod, 'cash');
      expect(booking.assignedAt, isNull);
      expect(booking.startedAt, isNull);
      expect(booking.completedAt, isNull);
      expect(booking.deliveryFee, isNull);
      expect(booking.driverEarnings, isNull);
      expect(booking.appEarnings, isNull);
    });

    test('parses integer numeric values as double', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json['origin_lat'] = 14; // int instead of double
      json['origin_lng'] = 100;
      json['price'] = 50;
      json['distance_km'] = 3;

      final booking = Booking.fromJson(json);
      expect(booking.originLat, 14.0);
      expect(booking.originLng, 100.0);
      expect(booking.price, 50.0);
      expect(booking.distanceKm, 3.0);
    });

    test('parses optional DateTime fields when present', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json['assigned_at'] = '2024-01-15T10:35:00.000Z';
      json['started_at'] = '2024-01-15T10:40:00.000Z';
      json['completed_at'] = '2024-01-15T11:00:00.000Z';

      final booking = Booking.fromJson(json);
      expect(booking.assignedAt, DateTime.parse('2024-01-15T10:35:00.000Z'));
      expect(booking.startedAt, DateTime.parse('2024-01-15T10:40:00.000Z'));
      expect(booking.completedAt, DateTime.parse('2024-01-15T11:00:00.000Z'));
    });

    test('parses food order with delivery_fee and earnings', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json['service_type'] = 'food';
      json['merchant_id'] = 'merch-001';
      json['delivery_fee'] = 35.0;
      json['driver_earnings'] = 60.0;
      json['app_earnings'] = 15.0;

      final booking = Booking.fromJson(json);
      expect(booking.serviceType, 'food');
      expect(booking.merchantId, 'merch-001');
      expect(booking.deliveryFee, 35.0);
      expect(booking.driverEarnings, 60.0);
      expect(booking.appEarnings, 15.0);
    });
  });

  group('Booking.toJson', () {
    test('serializes all fields to correct keys', () {
      final booking = Booking.fromJson(sampleJson);
      final json = booking.toJson();

      expect(json['id'], 'abc-123');
      expect(json['customer_id'], 'cust-001');
      expect(json['driver_id'], 'drv-001');
      expect(json['service_type'], 'ride');
      expect(json['origin_lat'], 13.7563);
      expect(json['origin_lng'], 100.5018);
      expect(json['dest_lat'], 13.7460);
      expect(json['dest_lng'], 100.5347);
      expect(json['distance_km'], 2.5);
      expect(json['price'], 75.0);
      expect(json['status'], 'pending');
      expect(json['pickup_address'], 'Central World');
      expect(json['destination_address'], 'Siam Paragon');
      expect(json['notes'], 'รอหน้าตึก');
      expect(json['payment_method'], 'cash');
    });

    test('serializes DateTime fields as ISO8601 strings', () {
      final booking = Booking.fromJson(sampleJson);
      final json = booking.toJson();

      expect(json['created_at'], isA<String>());
      expect(json['updated_at'], isA<String>());
      expect(DateTime.tryParse(json['created_at']), isNotNull);
    });

    test('serializes null optional fields as null', () {
      final booking = Booking.fromJson(sampleJson);
      final json = booking.toJson();

      expect(json['merchant_id'], isNull);
      expect(json['assigned_at'], isNull);
      expect(json['started_at'], isNull);
      expect(json['completed_at'], isNull);
      expect(json['delivery_fee'], isNull);
      expect(json['driver_earnings'], isNull);
      expect(json['app_earnings'], isNull);
    });
  });

  group('Booking.fromJson → toJson roundtrip', () {
    test('roundtrip preserves all data', () {
      final booking1 = Booking.fromJson(sampleJson);
      final json1 = booking1.toJson();
      final booking2 = Booking.fromJson(json1);

      expect(booking2.id, booking1.id);
      expect(booking2.customerId, booking1.customerId);
      expect(booking2.driverId, booking1.driverId);
      expect(booking2.serviceType, booking1.serviceType);
      expect(booking2.originLat, booking1.originLat);
      expect(booking2.originLng, booking1.originLng);
      expect(booking2.destLat, booking1.destLat);
      expect(booking2.destLng, booking1.destLng);
      expect(booking2.distanceKm, booking1.distanceKm);
      expect(booking2.price, booking1.price);
      expect(booking2.status, booking1.status);
    });
  });

  group('Booking.empty', () {
    test('creates booking with empty/default values', () {
      final booking = Booking.empty();

      expect(booking.id, '');
      expect(booking.customerId, '');
      expect(booking.serviceType, '');
      expect(booking.status, '');
      expect(booking.originLat, 0.0);
      expect(booking.originLng, 0.0);
      expect(booking.destLat, 0.0);
      expect(booking.destLng, 0.0);
      expect(booking.distanceKm, 0.0);
      expect(booking.price, 0.0);
      expect(booking.driverId, isNull);
      expect(booking.merchantId, isNull);
      expect(booking.deliveryFee, isNull);
    });
  });

  group('Booking computed properties', () {
    test('totalAmount for ride = price', () {
      final booking = Booking.fromJson(sampleJson);
      expect(booking.totalAmount, 75.0);
    });

    test('totalAmount for food = price + deliveryFee', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json['service_type'] = 'food';
      json['price'] = 200.0;
      json['delivery_fee'] = 35.0;

      final booking = Booking.fromJson(json);
      expect(booking.totalAmount, 235.0);
    });

    test('totalAmount for food with null deliveryFee = price', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json['service_type'] = 'food';
      json['price'] = 200.0;
      json['delivery_fee'] = null;

      final booking = Booking.fromJson(json);
      expect(booking.totalAmount, 200.0);
    });

    test('netEarnings returns driverEarnings when set', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json['driver_earnings'] = 60.0;

      final booking = Booking.fromJson(json);
      expect(booking.netEarnings, 60.0);
    });

    test('netEarnings returns price when driverEarnings is null', () {
      final booking = Booking.fromJson(sampleJson);
      expect(booking.netEarnings, 75.0); // Falls back to price
    });

    test('foodCost returns price for food service', () {
      final json = Map<String, dynamic>.from(sampleJson);
      json['service_type'] = 'food';
      json['price'] = 200.0;

      final booking = Booking.fromJson(json);
      expect(booking.foodCost, 200.0);
    });

    test('foodCost returns null for non-food service', () {
      final booking = Booking.fromJson(sampleJson);
      expect(booking.foodCost, isNull);
    });

    test('legacy aliases work correctly', () {
      final booking = Booking.fromJson(sampleJson);
      expect(booking.serviceId, booking.serviceType);
      expect(booking.originAddress, booking.pickupAddress);
      expect(booking.destAddress, booking.destinationAddress);
      expect(booking.acceptedAt, booking.assignedAt);
    });
  });
}
