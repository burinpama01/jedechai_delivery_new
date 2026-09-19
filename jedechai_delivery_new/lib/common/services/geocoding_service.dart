import 'package:jedechai_delivery_new/utils/debug_logger.dart';
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

  // ISSUE-119: ลบ getCoordinatesFromAddress ที่คืนพิกัดกลางกรุงเทพ
  // (13.7563, 100.5018) เสมอไม่ว่าจะใส่ที่อยู่อะไร — ถ้าต้องการ geocoding
  // จากข้อความ ให้ใช้ LocationService.getCoordinatesFromAddress ซึ่งเรียก
  // Google Geocoding API จริง

  // ISSUE-119: ลบ searchPlaces ที่คืนผลลัพธ์ปลอมตายตัว
  // ('Siam Paragon' / 'Central World') — ถ้าต้องการค้นหาสถานที่จริง
  // ให้ใช้ LocationService.searchPlaces ซึ่งเรียก Google Places API

  static String formatShortAddress(String address) {
    return address;
  }

  static String formatCityAddress(String address) {
    return address;
  }
}
