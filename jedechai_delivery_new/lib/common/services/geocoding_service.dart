import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart' as geocoding;

/// Geocoding Service
/// 
/// Handles geocoding and reverse geocoding operations
class GeocodingService {
  static Future<String?> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      final placemarks = await geocoding.placemarkFromCoordinates(latitude, longitude);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = <String>[];
        if (p.name != null && p.name!.isNotEmpty && p.name != p.street) parts.add(p.name!);
        if (p.street != null && p.street!.isNotEmpty) parts.add(p.street!);
        if (p.subLocality != null && p.subLocality!.isNotEmpty) parts.add(p.subLocality!);
        if (p.locality != null && p.locality!.isNotEmpty) parts.add(p.locality!);
        if (p.administrativeArea != null && p.administrativeArea!.isNotEmpty) parts.add(p.administrativeArea!);
        if (parts.isNotEmpty) {
          return parts.join(', ');
        }
      }
      return null;
    } catch (e) {
      debugLog('Error getting address from coordinates: $e');
      return null;
    }
  }

  static Future<LatLng?> getCoordinatesFromAddress(String address) async {
    try {
      // In a real implementation, this would use Google Geocoding API
      // For now, return a mock location
      return const LatLng(13.7563, 100.5018); // Bangkok
    } catch (e) {
      debugLog('Error getting coordinates from address: $e');
      return null;
    }
  }

  static Future<List<LocationSuggestion>> searchPlaces(String query) async {
    try {
      // In a real implementation, this would use Google Places API
      // For now, return mock suggestions
      return [
        LocationSuggestion(
          placeId: 'mock_1',
          description: 'Siam Paragon, Bangkok',
          mainText: 'Siam Paragon',
          secondaryText: 'Bangkok, Thailand',
        ),
        LocationSuggestion(
          placeId: 'mock_2',
          description: 'Central World, Bangkok',
          mainText: 'Central World',
          secondaryText: 'Bangkok, Thailand',
        ),
      ];
    } catch (e) {
      debugLog('Error searching places: $e');
      return [];
    }
  }

  // ignore: unused_element
  static String _formatAddress(String address) {
    return address;
  }

  static String formatShortAddress(String address) {
    return address;
  }

  static String formatCityAddress(String address) {
    return address;
  }
}

class LocationSuggestion {
  final String placeId;
  final String description;
  final String mainText;
  final String secondaryText;

  LocationSuggestion({
    required this.placeId,
    required this.description,
    required this.mainText,
    required this.secondaryText,
  });

  factory LocationSuggestion.fromJson(Map<String, dynamic> json) {
    return LocationSuggestion(
      placeId: json['place_id'] as String,
      description: json['description'] as String,
      mainText: json['main_text'] as String,
      secondaryText: json['secondary_text'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'place_id': placeId,
      'description': description,
      'main_text': mainText,
      'secondary_text': secondaryText,
    };
  }
}
