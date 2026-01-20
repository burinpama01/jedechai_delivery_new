import 'supabase_service.dart';
import '../models/booking.dart';

/// Booking Service
/// 
/// Handles all booking-related database operations
class BookingService {
  final _client = SupabaseService.client;

  /// Get all bookings for current user
  Future<List<Booking>> getUserBookings() async {
    final userId = SupabaseService.userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await _client
          .from('bookings')
          .select()
          .eq('customer_id', userId)
          .order('created_at', ascending: false)
          .limit(20);

      return (response as List)
          .map((json) => Booking.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Failed to fetch bookings: $e');
    }
  }

  /// Get booking by ID
  Future<Booking?> getBookingById(String bookingId) async {
    try {
      final response = await _client
          .from('bookings')
          .select()
          .eq('id', bookingId)
          .single();
      return Booking.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch booking: $e');
    }
  }

  /// Create a new booking
  /// 
  /// Throws Exception if user is not authenticated or creation fails
  Future<Booking> createBooking({
    required String serviceId,
    required double originLat,
    required double originLng,
    required double destLat,
    required double destLng,
    String? originAddress,
    String? destAddress,
    String? merchantId,
    double? distanceKm,
    required double deliveryFee,
    double? foodCost,
    required double totalAmount,
    Map<String, dynamic>? details,
  }) async {
    final userId = SupabaseService.userId;
    if (userId == null) {
      throw Exception('User not authenticated');
    }

    try {
      final response = await _client.from('bookings').insert({
      'customer_id': userId,
      'service_id': serviceId,
      'merchant_id': merchantId,
      'origin_lat': originLat,
      'origin_lng': originLng,
      'origin_address': originAddress,
      'dest_lat': destLat,
      'dest_lng': destLng,
      'dest_address': destAddress,
      'distance_km': distanceKm,
      'delivery_fee': deliveryFee,
      'food_cost': foodCost,
      'total_amount': totalAmount,
      'details': details ?? {},
      'status': 'pending',
    }).select().single();

      return Booking.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create booking: $e');
    }
  }

  /// Update booking status
  Future<void> updateBookingStatus(
    String bookingId,
    String newStatus,
  ) async {
    await _client
        .from('bookings')
        .update({'status': newStatus})
        .eq('id', bookingId);
  }

  /// Cancel booking
  Future<void> cancelBooking(String bookingId, {String? reason}) async {
    await _client.from('bookings').update({
      'status': 'cancelled',
      'cancellation_reason': reason,
    }).eq('id', bookingId);
  }

  /// Get pending bookings (for drivers)
  Future<List<Booking>> getPendingBookings() async {
      final response = await _client
          .from('bookings')
          .select()
          .eq('status', 'pending')
          .filter('driver_id', 'is', 'null')
          .order('created_at', ascending: false)
          .limit(50);

    return (response as List)
        .map((json) => Booking.fromJson(json))
        .toList();
  }

  /// Accept booking (for drivers)
  Future<void> acceptBooking(String bookingId) async {
    final driverId = SupabaseService.userId;
    if (driverId == null) throw Exception('Driver not authenticated');

    await _client.from('bookings').update({
      'driver_id': driverId,
      'status': 'accepted',
    }).eq('id', bookingId);
  }

  /// Subscribe to booking updates (Real-time)
  Stream<Booking?> subscribeToBooking(String bookingId) {
    return _client
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('id', bookingId)
        .map((data) {
      if (data.isEmpty) return null;
      return Booking.fromJson(data.first);
    });
  }
}
