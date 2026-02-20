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
  static String get firebasePrivateKeyId =>
      dotenv.env['FIREBASE_PRIVATE_KEY_ID'] ?? '';
  static String get firebasePrivateKey =>
      (dotenv.env['FIREBASE_PRIVATE_KEY'] ?? '').replaceAll('\\n', '\n');
  static String get firebaseClientEmail =>
      dotenv.env['FIREBASE_CLIENT_EMAIL'] ?? '';
  static String get firebaseClientId => dotenv.env['FIREBASE_CLIENT_ID'] ?? '';

  /// Get Firebase Service Account JSON map
  static Map<String, String> get firebaseServiceAccountJson => {
        "type": "service_account",
        "project_id": firebaseProjectId,
        "private_key_id": firebasePrivateKeyId,
        "private_key": firebasePrivateKey,
        "client_email": firebaseClientEmail,
        "client_id": firebaseClientId,
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "auth_provider_x509_cert_url":
            "https://www.googleapis.com/oauth2/v1/certs",
        "client_x509_cert_url":
            "https://www.googleapis.com/robot/v1/metadata/x509/${Uri.encodeComponent(firebaseClientEmail)}",
      };

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

  static bool get isFirebaseConfigured =>
      firebaseProjectId.isNotEmpty && firebasePrivateKey.isNotEmpty;
}
