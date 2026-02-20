import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../config/env_config.dart';
import '../widgets/location_disclosure_dialog.dart';

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

  static Future<double> _getRealRoadDistance(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) async {
    try {
      final String googleApiKey = EnvConfig.googleMapsApiKey;
      
      final url = Uri.parse(
        'https://maps.googleapis.com/maps/api/directions/json'
        '?origin=$startLat,$startLng'
        '&destination=$endLat,$endLng'
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

  static Future<List<AddressPlacemark>> getAddressFromCoordinates(
    double latitude,
    double longitude,
  ) async {
    try {
      // Mock implementation for now
      return [
        AddressPlacemark(
          street: 'Mock Street',
          locality: 'Bangkok',
          administrativeArea: 'Bangkok',
          country: 'Thailand',
        ),
      ];
    } catch (e) {
      return [];
    }
  }

  static Future<List<Location>> searchPlaces(String query) async {
    if (query.trim().isEmpty) return [];

    final apiKey = EnvConfig.googleMapsApiKey;
    if (apiKey.isEmpty) return [];

    try {
      final autocompleteUri = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/autocomplete/json'
        '?input=${Uri.encodeQueryComponent(query)}'
        '&language=th'
        '&components=country:th'
        '&key=$apiKey',
      );

      final autocompleteResponse = await http.get(autocompleteUri);
      final autocompleteData =
          json.decode(autocompleteResponse.body) as Map<String, dynamic>;

      if (autocompleteData['status'] != 'OK') {
        return [];
      }

      final predictions =
          (autocompleteData['predictions'] as List<dynamic>? ?? []).take(5);

      final results = <Location>[];
      for (final item in predictions) {
        final prediction = item as Map<String, dynamic>;
        final placeId = prediction['place_id'] as String?;
        if (placeId == null || placeId.isEmpty) continue;

        final detailsUri = Uri.parse(
          'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=${Uri.encodeQueryComponent(placeId)}'
          '&fields=place_id,name,formatted_address,geometry'
          '&language=th'
          '&key=$apiKey',
        );

        final detailsResponse = await http.get(detailsUri);
        final detailsData =
            json.decode(detailsResponse.body) as Map<String, dynamic>;

        if (detailsData['status'] != 'OK') continue;

        final place = detailsData['result'] as Map<String, dynamic>?;
        final geometry = place?['geometry'] as Map<String, dynamic>?;
        final location = geometry?['location'] as Map<String, dynamic>?;
        final lat = (location?['lat'] as num?)?.toDouble();
        final lng = (location?['lng'] as num?)?.toDouble();
        if (place == null || lat == null || lng == null) continue;

        results.add(
          Location(
            id: place['place_id'] as String? ?? placeId,
            name: place['name'] as String? ??
                prediction['description'] as String? ??
                query,
            latitude: lat,
            longitude: lng,
            address: place['formatted_address'] as String? ??
                prediction['description'] as String?,
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

    final apiKey = EnvConfig.googleMapsApiKey;
    if (apiKey.isEmpty) return null;

    try {
      final geocodeUri = Uri.parse(
        'https://maps.googleapis.com/maps/api/geocode/json'
        '?address=${Uri.encodeQueryComponent(address)}'
        '&language=th'
        '&key=$apiKey',
      );

      final response = await http.get(geocodeUri);
      final data = json.decode(response.body) as Map<String, dynamic>;

      if (data['status'] != 'OK') return null;

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

class AddressPlacemark {
  final String? street;
  final String? locality;
  final String? administrativeArea;
  final String? country;

  AddressPlacemark({
    this.street,
    this.locality,
    this.administrativeArea,
    this.country,
  });
}
