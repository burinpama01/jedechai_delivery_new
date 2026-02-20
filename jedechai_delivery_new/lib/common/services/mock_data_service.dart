import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import '../models/booking.dart';
import '../../utils/supabase_health_checker.dart';

/// Mock Data Service
/// 
/// Provides mock data when Supabase is not available
class MockDataService {
  static List<Booking> getMockBookings() {
    return [
      Booking(
        id: 'mock-1',
        customerId: 'mock-customer-1',
        serviceType: 'Ride',
        originLat: 13.7563,
        originLng: 100.5018,
        destLat: 13.7468,
        destLng: 100.5350,
        status: 'completed',
        pickupAddress: '123 Main Street, Bangkok',
        destinationAddress: '456 Sukhumvit Road, Bangkok',
        price: 85.50,
        distanceKm: 5.2,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      Booking(
        id: 'mock-2',
        customerId: 'mock-customer-1',
        serviceType: 'Food',
        originLat: 13.7468,
        originLng: 100.5350,
        destLat: 13.7563,
        destLng: 100.5018,
        status: 'completed',
        pickupAddress: 'Central World, Bangkok',
        destinationAddress: '789 Ratchada Road, Bangkok',
        price: 45.00,
        distanceKm: 3.1,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
        updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      Booking(
        id: 'mock-3',
        customerId: 'mock-customer-1',
        serviceType: 'Parcel',
        originLat: 13.7563,
        originLng: 100.5018,
        destLat: 13.7563,
        destLng: 100.5018,
        status: 'cancelled',
        pickupAddress: 'Siam Paragon, Bangkok',
        destinationAddress: 'Chatuchak Market, Bangkok',
        price: 120.00,
        distanceKm: 8.7,
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
        updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
      Booking(
        id: 'mock-4',
        customerId: 'mock-customer-1',
        serviceType: 'Ride',
        originLat: 13.7468,
        originLng: 100.5350,
        destLat: 13.7563,
        destLng: 100.5018,
        status: 'in_transit',
        pickupAddress: 'BTS Asoke Station, Bangkok',
        destinationAddress: 'Terminal 21, Bangkok',
        price: 65.00,
        distanceKm: 2.3,
        createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
        updatedAt: DateTime.now().subtract(const Duration(minutes: 10)),
      ),
    ];
  }

  static Map<String, dynamic> getMockUserProfile() {
    return {
      'full_name': 'John Doe',
      'phone': '+66 123 456 7890',
      'email': 'john.doe@example.com',
    };
  }

  static bool isSupabaseAvailable() {
    // Try to detect if Supabase is available
    // For now, we'll return true to test real connection
    // In production, you might want to implement proper health checking
    return true;
  }

  static Future<bool> checkRealConnection() async {
    try {
      final result = await SupabaseHealthChecker.checkConnection();
      debugLog('🔍 Supabase connection check: $result');
      return result;
    } catch (e) {
      debugLog('❌ Error checking Supabase connection: $e');
      return false;
    }
  }
}
