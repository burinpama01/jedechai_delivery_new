import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/debug_logger.dart';

/// MapsService — เรียก Google Maps Web Service ผ่าน Edge Function `maps-proxy`
///
/// ISSUE-120: เดิมทุกหน้าจอยิง `https://maps.googleapis.com/maps/api/...`
/// ตรงจากเครื่องผู้ใช้ด้วย `EnvConfig.googleMapsApiKey` ซึ่งอยู่ใน `.env.client` ที่ถูก
/// bundle เป็น Flutter asset — key ของ Web Service ผูก application restriction
/// ไม่ได้ ใครแตก APK ก็เอาไปยิงบิลเข้าโปรเจคได้ไม่จำกัด
///
/// ตอนนี้ทุก call ไปที่ Edge Function ที่ถือ `GOOGLE_MAPS_SERVER_KEY` ฝั่ง
/// server (ตั้ง IP restriction ได้) และรับเฉพาะ operation ที่ allowlist ไว้
///
/// หมายเหตุ: `GOOGLE_MAPS_API_KEY` ฝั่งแอปยังจำเป็นอยู่สำหรับ Maps SDK
/// (แสดงแผนที่ใน `google_maps_flutter`) ซึ่ง key ตัวนั้นผูก application
/// restriction ได้ จึงคนละเรื่องกับ key ของ Web Service
class MapsService {
  const MapsService._();

  static const String _functionName = 'maps-proxy';

  /// เส้นทางขับรถระหว่างสองจุด — คืน payload ดิบของ Google Directions API
  /// (`status`, `routes`, ...) หรือ null เมื่อเรียกไม่สำเร็จ
  static Future<Map<String, dynamic>?> directions({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
  }) {
    return _invoke('directions', {
      'origin_lat': originLat,
      'origin_lng': originLng,
      'destination_lat': destinationLat,
      'destination_lng': destinationLng,
    });
  }

  /// แปลงข้อความที่อยู่เป็นพิกัด — คืน payload ดิบของ Google Geocoding API
  static Future<Map<String, dynamic>?> geocode(String address) {
    return _invoke('geocode', {'address': address});
  }

  /// แปลงพิกัดเป็นที่อยู่ — คืน payload ดิบของ Google Geocoding API
  static Future<Map<String, dynamic>?> reverseGeocode({
    required double lat,
    required double lng,
  }) {
    return _invoke('reverse_geocode', {'lat': lat, 'lng': lng});
  }

  /// ค้นหาสถานที่จากข้อความ — คืน payload ดิบของ Google Places Text Search
  static Future<Map<String, dynamic>?> placeTextSearch(String query) {
    return _invoke('place_text_search', {'query': query});
  }

  static Future<Map<String, dynamic>?> _invoke(
    String operation,
    Map<String, dynamic> payload,
  ) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        _functionName,
        body: {'operation': operation, ...payload},
      );

      if (response.status >= 400) {
        debugLog('❌ maps-proxy $operation: HTTP ${response.status}');
        return null;
      }

      final body = response.data;
      if (body is! Map) {
        debugLog('❌ maps-proxy $operation: unexpected response shape');
        return null;
      }

      if (body['success'] != true) {
        debugLog('❌ maps-proxy $operation: ${body['error']}');
        return null;
      }

      final data = body['data'];
      if (data is! Map) {
        debugLog('❌ maps-proxy $operation: missing data');
        return null;
      }

      return Map<String, dynamic>.from(data);
    } catch (e) {
      debugLog('❌ maps-proxy $operation failed: $e');
      return null;
    }
  }
}
