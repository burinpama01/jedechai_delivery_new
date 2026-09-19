import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment Configuration
///
/// Centralized access to all environment variables from .env file
/// All secrets/keys are loaded from .env instead of being hardcoded
class EnvConfig {
  // Supabase
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  // ISSUE-102: ห้ามอ่าน SUPABASE_SERVICE_KEY จากฝั่งแอปเด็ดขาด
  // .env ถูก bundle เป็น Flutter asset (pubspec.yaml) จึงถูกแตกออกจาก
  // APK/IPA ได้แบบ plaintext — service role key bypass RLS ทั้งระบบ
  // งานที่ต้องใช้สิทธิ์ service role ต้องไปอยู่ใน Supabase Edge Function

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

  // Omise Payment Gateway
  // ISSUE-102: อ่านได้เฉพาะ public key — secret key ต้องอยู่ฝั่ง Edge Function
  // (payment-create-charge / payment-check-status) เท่านั้น
  static String get omisePublicKey => dotenv.env['OMISE_PUBLIC_KEY'] ?? '';

  static bool get isOmiseConfigured => omisePublicKey.isNotEmpty;

  // Validation
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get isGoogleMapsConfigured => googleMapsApiKey.isNotEmpty;

  static bool get isPasswordResetRedirectConfigured =>
      passwordResetRedirectUrl.isNotEmpty;

  static bool get isFirebaseConfigured => firebaseProjectId.isNotEmpty;
}
