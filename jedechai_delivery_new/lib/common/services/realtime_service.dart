import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:http/http.dart' as http;
import 'supabase_service.dart';
import '../config/env_config.dart';

/// Realtime Service
/// 
/// Handles real-time subscriptions for driver locations and bookings
class RealtimeService {
  final _client = SupabaseService.client;
  RealtimeChannel? _driverLocationChannel;
  RealtimeChannel? _bookingChannel;
  StreamController<Map<String, dynamic>?>? _driverLocationController;
  StreamController<Map<String, dynamic>?>? _bookingController;
  String? _lastDriverId;
  String? _lastBookingId;
  bool _isRefreshingToken = false;

  bool _isJwtExpiredError(Object error) {
    final message = error.toString();
    return message.contains('InvalidJWTToken') ||
        message.contains('Token has expired') ||
        message.contains('JWT expired');
  }

  Future<void> _refreshSessionAndResubscribe() async {
    if (_isRefreshingToken) return;
    _isRefreshingToken = true;

    try {
      final refreshed = await _client.auth.refreshSession();
      if (refreshed.session == null) {
        debugPrint('❌ Unable to refresh session for realtime channels');
        return;
      }

      debugPrint('✅ Realtime session refreshed successfully');

      if (_lastDriverId != null) {
        subscribeToDriverLocation(_lastDriverId!);
      }
      if (_lastBookingId != null) {
        subscribeToBooking(_lastBookingId!);
      }
    } catch (e) {
      debugPrint('❌ Failed to refresh realtime auth session: $e');
    } finally {
      _isRefreshingToken = false;
    }
  }

  /// Subscribe to driver location updates
  Stream<Map<String, dynamic>?> subscribeToDriverLocation(String driverId) {
    _lastDriverId = driverId;
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
            if (_isJwtExpiredError(error)) {
              debugPrint('🔑 JWT Token expired in realtime subscription');
              unawaited(_refreshSessionAndResubscribe());
            }
          }
        });

    return _driverLocationController!.stream;
  }

  /// Subscribe to booking updates
  Stream<Map<String, dynamic>?> subscribeToBooking(String bookingId) {
    debugLog('🔍 RealtimeService: Setting up subscription for booking: $bookingId');
    _lastBookingId = bookingId;
    
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
            debugLog('📡 RealtimeService: Received payload event');
            debugLog('📡 RealtimeService: Event type: ${payload.eventType}');
            debugLog('📡 RealtimeService: New record: ${payload.newRecord}');
            debugLog('📡 RealtimeService: Old record: ${payload.oldRecord}');
            
            // For UPDATE and INSERT events, use newRecord
            // For DELETE events, use oldRecord (if available) or null
            // ignore: unnecessary_null_comparison
            if (payload.newRecord != null) {
              debugLog('📡 RealtimeService: Sending newRecord to stream: ${payload.newRecord}');
              _bookingController?.add(payload.newRecord);
            } else {
              debugLog('📡 RealtimeService: Sending null to stream (DELETE event)');
              _bookingController?.add(null);
            }
          },
        )
        .subscribe((status, [error]) {
          debugPrint('Booking channel status: $status');
          if (error != null) {
            debugPrint('Booking channel error: $error');
            if (_isJwtExpiredError(error)) {
              debugPrint('🔑 JWT Token expired in realtime subscription');
              unawaited(_refreshSessionAndResubscribe());
            }
          }
        });

    debugLog('✅ RealtimeService: Subscription setup complete for booking: $bookingId');
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
    final filteredDrivers = <Map<String, dynamic>>[];
    for (final driver in drivers) {
      final driverLat = (driver['location_lat'] as num).toDouble();
      final driverLng = (driver['location_lng'] as num).toDouble();
      final distance = await _calculateDistance(lat, lng, driverLat, driverLng);
      if (distance <= radiusKm) {
        filteredDrivers.add(driver);
      }
    }
    return filteredDrivers;
  }

  /// Calculate distance using Google Directions API for real road distance
  Future<double> _calculateDistance(
    double lat1,
    double lng1,
    double lat2,
    double lng2,
  ) async {
    try {
      final String googleApiKey = EnvConfig.googleMapsApiKey;
      
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=$lat1,$lng1'
        '&destination=$lat2,$lng2'
        '&mode=driving'
        '&key=$googleApiKey',
      );

      final response = await http.get(url);
      final data = json.decode(response.body);

      if (data['status'] == 'OK' && data['routes'].isNotEmpty) {
        final routes = data['routes'] as List;
        final route = routes[0] as Map<String, dynamic>;
        final legs = route['legs'] as List?;
        
        if (legs != null && legs.isNotEmpty) {
          final leg = legs[0] as Map<String, dynamic>;
          final distanceValue = leg['distance']?['value'] as int?;
          if (distanceValue != null) {
            final realDistance = distanceValue / 1000; // Convert meters to km
            return realDistance;
          }
        }
      }
      // Fallback to Haversine formula if no route/distance found
      return _calculateHaversineDistance(lat1, lng1, lat2, lng2);
    } catch (e) {
      // Fallback to Haversine formula
      return _calculateHaversineDistance(lat1, lng1, lat2, lng2);
    }
  }

  /// Calculate distance using Haversine formula (fallback)
  double _calculateHaversineDistance(
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
