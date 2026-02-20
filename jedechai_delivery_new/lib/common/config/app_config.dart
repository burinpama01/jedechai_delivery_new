/// App Configuration
/// 
/// Contains application-wide configuration settings
class AppConfig {
  static const String appName = 'Jedechai Delivery';
  static const String appVersion = '1.0.0';
  static const String appDescription = 'Super App for Food Delivery, Parcel Delivery, and Passenger Transport';
  
  // API Configuration
  static const String apiBaseUrl = 'https://api.jedechai-delivery.com';
  static const Duration apiTimeout = Duration(seconds: 30);
  
  // App Configuration
  static const bool enableDebugMode = false;
  static const bool enableAnalytics = true;
  static const bool enableCrashReporting = true;
  
  // Map Configuration
  static const double defaultMapZoom = 14.0;
  static const double defaultMapZoomForNavigation = 16.0;
  
  // Service Configuration
  static const Duration driverSearchTimeout = Duration(minutes: 5);
  static const Duration bookingConfirmationTimeout = Duration(minutes: 2);
  
  // Notification Configuration
  static const Duration notificationDisplayTime = Duration(seconds: 3);
  
  // UI Configuration
  static const double defaultPadding = 16.0;
  static const double defaultBorderRadius = 12.0;
  
  // Rate Limiting
  static const int maxBookingAttempts = 3;
  static const Duration bookingCooldown = Duration(minutes: 1);
}
