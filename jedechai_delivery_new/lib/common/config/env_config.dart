import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment Configuration
///
/// Centralized access to all environment variables from .env file
/// All secrets/keys are loaded from .env instead of being hardcoded
class EnvConfig {
  // Supabase
  static String get supabaseUrl => dotenv.env['SUPABASE_URL'] ?? '';
  static String get supabaseAnonKey => dotenv.env['SUPABASE_ANON_KEY'] ?? '';
  static String get supabaseServiceKey =>
      dotenv.env['SUPABASE_SERVICE_KEY'] ?? '';

  // Google Maps
  static String get googleMapsApiKey => dotenv.env['GOOGLE_MAPS_API_KEY'] ?? '';

  // Auth
  static String get passwordResetRedirectUrl =>
      dotenv.env['PASSWORD_RESET_REDIRECT_URL'] ?? '';

  // Firebase
  static String get firebaseProjectId =>
      dotenv.env['FIREBASE_PROJECT_ID'] ?? '';

  // Omise Payment Gateway
  static String get omisePublicKey => dotenv.env['OMISE_PUBLIC_KEY'] ?? '';
  static String get omiseSecretKey => dotenv.env['OMISE_SECRET_KEY'] ?? '';

  static bool get isOmiseConfigured =>
      omisePublicKey.isNotEmpty && omiseSecretKey.isNotEmpty;

  // Validation
  static bool get isSupabaseConfigured =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get isServiceKeyConfigured => supabaseServiceKey.isNotEmpty;

  static bool get isGoogleMapsConfigured => googleMapsApiKey.isNotEmpty;

  static bool get isPasswordResetRedirectConfigured =>
      passwordResetRedirectUrl.isNotEmpty;

  static bool get isFirebaseConfigured => firebaseProjectId.isNotEmpty;
}
