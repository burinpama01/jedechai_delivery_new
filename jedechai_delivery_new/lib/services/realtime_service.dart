import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

/// Realtime Service
/// 
/// Handles real-time subscriptions for driver locations and bookings
class RealtimeService {
  final _client = SupabaseService.client;
  RealtimeChannel? _driverLocationChannel;
  RealtimeChannel? _bookingChannel;
  StreamController<Map<String, dynamic>?>? _driverLocationController;
  StreamController<Map<String, dynamic>?>? _bookingController;

  /// Subscribe to driver location updates
  Stream<Map<String, dynamic>?> subscribeToDriverLocation(String driverId) {
    _driverLocationChannel?.unsubscribe();
    _driverLocationController?.close();
    
    _driverLocationController = StreamController<Map<String, dynamic>?>.broadcast();
    
    _driverLocationChannel = _client
        .channel('driver_location_$driverId')
        .onPostgresChanges(
          event: PostgresChangeEvent.update,
          schema: 'public',
          table: 'driver_locations',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'driver_id',
            value: driverId,
          ),
          callback: (payload) {
            _driverLocationController?.add(payload.newRecord);
          },
        )
        .subscribe((status, [error]) {
          debugPrint('Driver location channel status: $status');
          if (error != null) {
            debugPrint('Driver location channel error: $error');
          }
        });

    return _driverLocationController!.stream;
  }

  /// Subscribe to booking updates
  Stream<Map<String, dynamic>?> subscribeToBooking(String bookingId) {
    _bookingChannel?.unsubscribe();
    _bookingController?.close();
    
    _bookingController = StreamController<Map<String, dynamic>?>.broadcast();
    
    _bookingChannel = _client
        .channel('booking_$bookingId')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'bookings',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'id',
            value: bookingId,
          ),
          callback: (payload) {
            // For UPDATE and INSERT events, use newRecord
            // For DELETE events, use oldRecord (if available) or null
            if (payload.newRecord != null) {
              _bookingController?.add(payload.newRecord);
            } else {
              _bookingController?.add(null);
            }
          },
        )
        .subscribe((status, [error]) {
          debugPrint('Booking channel status: $status');
          if (error != null) {
            debugPrint('Booking channel error: $error');
          }
        });

    return _bookingController!.stream;
  }

  /// Update driver location
  Future<void> updateDriverLocation({
    required double lat,
    required double lng,
    bool? isOnline,
    bool? isAvailable,
    double? heading,
    double? speed,
    String? currentBookingId,
  }) async {
    final driverId = SupabaseService.userId;
    if (driverId == null) throw Exception('Driver not authenticated');

    // Check if location exists
    final existing = await _client
        .from('driver_locations')
        .select()
        .eq('driver_id', driverId)
        .maybeSingle();

    if (existing != null) {
      // Update existing
      await _client.from('driver_locations').update({
        'location_lat': lat,
        'location_lng': lng,
        if (isOnline != null) 'is_online': isOnline,
        if (isAvailable != null) 'is_available': isAvailable,
        if (heading != null) 'heading': heading,
        if (speed != null) 'speed': speed,
        if (currentBookingId != null) 'current_booking_id': currentBookingId,
      }).eq('driver_id', driverId);
    } else {
      // Insert new
      await _client.from('driver_locations').insert({
        'driver_id': driverId,
        'location_lat': lat,
        'location_lng': lng,
        'is_online': isOnline ?? false,
        'is_available': isAvailable ?? false,
        if (heading != null) 'heading': heading,
        if (speed != null) 'speed': speed,
        if (currentBookingId != null) 'current_booking_id': currentBookingId,
      });
    }
  }

  /// Get available drivers near location
  Future<List<Map<String, dynamic>>> getAvailableDriversNearby({
    required double lat,
    required double lng,
    double radiusKm = 5.0,
  }) async {
    // Note: This uses a simple distance calculation
    // For production, consider using PostGIS functions in a database function
    final response = await _client
        .from('driver_locations')
        .select()
        .eq('is_online', true)
        .eq('is_available', true);

    final drivers = (response as List).cast<Map<String, dynamic>>();
    
    // Filter by distance (simple calculation)
    // In production, use PostGIS ST_DWithin in a database function
    return drivers.where((driver) {
      final driverLat = (driver['location_lat'] as num).toDouble();
      final driverLng = (driver['location_lng'] as num).toDouble();
      final distance = _calculateDistance(lat, lng, driverLat, driverLng);
      return distance <= radiusKm;
    }).toList();
  }

  /// Calculate distance using Haversine formula
  double _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) {
    const earthRadiusKm = 6371.0;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);

    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_toRadians(lat1)) *
            math.cos(_toRadians(lat2)) *
            math.sin(dLng / 2) *
            math.sin(dLng / 2);

    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _toRadians(double degrees) => degrees * (math.pi / 180.0);

  /// Cleanup - unsubscribe from all channels
  void dispose() {
    _driverLocationChannel?.unsubscribe();
    _bookingChannel?.unsubscribe();
    _driverLocationController?.close();
    _bookingController?.close();
  }
}
