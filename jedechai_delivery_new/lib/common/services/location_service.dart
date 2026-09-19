import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../widgets/location_disclosure_dialog.dart';
import 'maps_service.dart';

/// Location Service
/// 
/// Handles location-related operations
class LocationService {
  static Future<Position?> getCurrentLocation({BuildContext? context}) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        // แสดง Prominent Disclosure ก่อนขอ permission จากระบบ (Google Play Policy)
        if (context != null && context.mounted) {
          final accepted = await LocationDisclosureHelper.showIfNeeded(context);
          if (!accepted) return null;
        }
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return null;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return null;
      }

      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }

  static Future<double> calculateDistance(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) async {
    // Use Google Directions API for real road distance
    return await _getRealRoadDistance(startLatitude, startLongitude, endLatitude, endLongitude);
  }

  /// Returns distance with metadata indicating whether this is a real road
  /// distance (from Directions API) or a straight-line fallback estimate.
  static Future<DistanceResult> calculateDistanceWithMeta(
    double startLatitude,
    double startLongitude,
    double endLatitude,
    double endLongitude,
  ) async {
    try {
      // ISSUE-120: ผ่าน Edge Function แทนการยิง Google ตรงจากเครื่องผู้ใช้
      final data = await MapsService.directions(
        originLat: startLatitude,
        originLng: startLongitude,
        destinationLat: endLatitude,
        destinationLng: endLongitude,
      );
      if (data != null &&
          data['status'] == 'OK' &&
          (data['routes'] as List).isNotEmpty) {
        final leg = (data['routes'][0]['legs'] as List?)?.firstOrNull as Map?;
        final value = leg?['distance']?['value'] as int?;
        if (value != null) {
          return DistanceResult(distanceKm: value / 1000, isStraightLine: false);
        }
      }
    } catch (_) {}
    final straight = Geolocator.distanceBetween(
            startLatitude, startLongitude, endLatitude, endLongitude) /
        1000;
    return DistanceResult(distanceKm: straight, isStraightLine: true);
  }

  static Future<double> _getRealRoadDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    try {
      // ISSUE-120: ผ่าน Edge Function แทนการยิง Google ตรงจากเครื่องผู้ใช้
      final data = await MapsService.directions(
        originLat: startLat,
        originLng: startLng,
        destinationLat: endLat,
        destinationLng: endLng,
      );

      if (data != null &&
          data['status'] == 'OK' &&
          (data['routes'] as List).isNotEmpty) {
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
      // Fallback to straight-line distance if API fails or no route found
      return Geolocator.distanceBetween(startLat, startLng, endLat, endLng) / 1000;
    } catch (e) {
      // Fallback to straight-line distance on error
      return Geolocator.distanceBetween(startLat, startLng, endLat, endLng) / 1000;
    }
  }

  static String formatDistance(double distanceInMeters) {
    if (distanceInMeters < 1000) {
      return '${distanceInMeters.round()} m';
    } else {
      return '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
    }
  }

  // ISSUE-119: ลบ getAddressFromCoordinates ที่คืน 'Mock Street, Bangkok'
  // เสมอ — ของจริงอยู่ที่ GeocodingService.getAddressFromCoordinates
  // (เคยมี object นี้หลุดไปถูก stringify เก็บลง DB จนต้องมีโค้ดกรอง
  // คำว่า 'AddressPlacemark' กระจายอยู่หลายหน้าจอ)

  /// ค้นหาสถานที่จากข้อความ
  ///
  /// ISSUE-120: เดิมยิง Places Autocomplete 1 ครั้ง แล้ววนยิง Place Details
  /// อีก 5 ครั้งเพื่อเอาพิกัด (N+1) ทำให้ทั้งช้าและเสียค่า API ต่อการค้นหา
  /// หนึ่งครั้งถึง 6 request — เปลี่ยนมาใช้ Places Text Search ซึ่งคืน
  /// geometry มาพร้อมผลลัพธ์ในคำขอเดียว
  static Future<List<Location>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];

    try {
      // ISSUE-120: ผ่าน Edge Function แทนการยิง Google ตรงจากเครื่องผู้ใช้
      final data = await MapsService.placeTextSearch(query);

      if (data == null || data['status'] != 'OK') return [];

      final places = (data['results'] as List<dynamic>? ?? []).take(5);

      final results = <Location>[];
      for (final item in places) {
        final place = item as Map<String, dynamic>;
        final geometry = place['geometry'] as Map<String, dynamic>?;
        final location = geometry?['location'] as Map<String, dynamic>?;
        final lat = (location?['lat'] as num?)?.toDouble();
        final lng = (location?['lng'] as num?)?.toDouble();
        final placeId = place['place_id'] as String?;
        if (lat == null || lng == null || placeId == null) continue;

        results.add(
          Location(
            id: placeId,
            name: place['name'] as String? ?? query,
            latitude: lat,
            longitude: lng,
            address: place['formatted_address'] as String?,
          ),
        );
      }

      return results;
    } catch (_) {
      return [];
    }
  }

  static Future<LatLng?> getCoordinatesFromAddress(String address) async {
    if (address.trim().isEmpty) return null;

    try {
      // ISSUE-120: ผ่าน Edge Function แทนการยิง Google ตรงจากเครื่องผู้ใช้
      final data = await MapsService.geocode(address);

      if (data == null || data['status'] != 'OK') return null;

      final results = data['results'] as List<dynamic>?;
      if (results == null || results.isEmpty) return null;

      final first = results.first as Map<String, dynamic>;
      final geometry = first['geometry'] as Map<String, dynamic>?;
      final location = geometry?['location'] as Map<String, dynamic>?;
      final lat = (location?['lat'] as num?)?.toDouble();
      final lng = (location?['lng'] as num?)?.toDouble();

      if (lat == null || lng == null) return null;
      return LatLng(lat, lng);
    } catch (_) {
      return null;
    }
  }
}

class DistanceResult {
  final double distanceKm;

  /// True when Directions API was unavailable and straight-line was used instead.
  final bool isStraightLine;

  const DistanceResult({required this.distanceKm, required this.isStraightLine});
}

class Location {
  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final String? address;

  Location({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.address,
  });

  factory Location.fromJson(Map<String, dynamic> json) {
    return Location(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      address: json['address'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    };
  }
}
