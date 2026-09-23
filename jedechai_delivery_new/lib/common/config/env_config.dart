import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment Configuration
///
/// Centralized access to public client config from `.env.client`
/// (bundled into the app as a Flutter asset — anyone can read it from the APK/IPA).
/// NEVER add service keys, secret keys, private keys or database URLs here;
/// server-side secrets belong in Supabase secrets / Edge Functions.
class EnvConfig {
  // Supabase
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';

  // Google Maps
  // ISSUE-120: key ตัวนี้เหลือไว้สำหรับ Maps SDK (แสดงแผนที่ใน
  // google_maps_flutter) เท่านั้น ซึ่งผูก application restriction ได้
  // การเรียก Web Service (Directions / Geocoding / Places) ต้องไปที่
  // Edge Function `maps-proxy` ผ่าน MapsService เสมอ — ห้ามยิง
  // maps.googleapis.com ตรงจากแอปอีก
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // Auth
  static String get passwordResetRedirectUrl =>
      dotenv.env['PASSWORD_RESET_REDIRECT_URL'] ?? '';

  // Firebase
  static String get firebaseProjectId =>
      dotenv.env['FIREBASE_PROJECT_ID'] ?? '';

  // Omise Payment Gateway — ปิดแล้ว (กำลังเปลี่ยนเป็น Beam ผ่าน server)
  // คืนค่าว่างเสมอเพื่อไม่ให้ flow Omise ฝั่งแอปทำงาน
  static String get omisePublicKey => '';

  // Validation
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get isGoogleMapsConfigured => googleMapsApiKey.isNotEmpty;

  static bool get isPasswordResetRedirectConfigured =>
      passwordResetRedirectUrl.isNotEmpty;

  static bool get isFirebaseConfigured => firebaseProjectId.isNotEmpty;
}
