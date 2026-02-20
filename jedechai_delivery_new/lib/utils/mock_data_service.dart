import '../common/models/booking.dart';

/// Mock Data Service
/// 
/// Provides mock data for development and testing
class MockDataService {
  static Future<bool> checkRealConnection() async {
    try {
      // Try to connect to a reliable endpoint
      await Future.delayed(const Duration(milliseconds: 500));
      return true; // Assume connection is available
    } catch (e) {
      return false;
    }
  }

  static List<Booking> getMockBookings() {
    return [
      Booking(
        id: 'mock-1',
        customerId: 'customer-1',
        merchantId: 'merchant-1',
        driverId: 'driver-1',
        serviceType: 'food',
        status: 'completed',
        price: 150.0,
        distanceKm: 5.2,
        originLat: 13.7563,
        originLng: 100.5018,
        destLat: 13.7463,
        destLng: 100.5118,
        pickupAddress: '123 Main St',
        destinationAddress: '456 Oak Ave',
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        updatedAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
      Booking(
        id: 'mock-2',
        customerId: 'customer-1',
        merchantId: 'merchant-2',
        driverId: 'driver-2',
        serviceType: 'ride',
        status: 'in_transit',
        price: 200.0,
        distanceKm: 8.7,
        originLat: 13.7563,
        originLng: 100.5018,
        destLat: 13.7663,
        destLng: 100.5218,
        pickupAddress: '789 Elm St',
        destinationAddress: '321 Pine Rd',
        createdAt: DateTime.now().subtract(const Duration(minutes: 30)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 15)),
      ),
      Booking(
        id: 'mock-3',
        customerId: 'customer-1',
        merchantId: 'merchant-3',
        driverId: null,
        serviceType: 'parcel',
        status: 'confirmed',
        price: 80.0,
        distanceKm: 3.4,
        originLat: 13.7363,
        originLng: 100.4918,
        destLat: 13.7563,
        destLng: 100.5018,
        pickupAddress: '555 Maple Dr',
        destinationAddress: '999 Cedar Ln',
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  static Map<String, dynamic> getMockUserProfile() {
    return {
      'full_name': 'John Doe',
      'phone': '+66 123 456 7890',
      'email': 'john.doe@example.com',
      'role': 'customer',
      'created_at': DateTime.now().toIso8601String(),
    };
  }
}
