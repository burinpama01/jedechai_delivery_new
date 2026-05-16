import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'l10n/app_localizations.dart';
import 'common/config/env_config.dart';
import 'common/providers/auth_provider.dart';
import 'common/providers/language_provider.dart';
import 'common/services/services.dart';
import 'common/services/mock_auth_service.dart';
import 'utils/auth_helper.dart';
import 'theme/app_theme.dart';
import 'common/widgets/auth_gate.dart';
import 'common/screens/notification_center_screen.dart';
import 'apps/customer/customer.dart';
import 'apps/driver/driver.dart';
import 'apps/merchant/merchant.dart';
import 'apps/driver/screens/driver_job_detail_screen.dart';
import 'apps/merchant/screens/order_detail_screen.dart';
import 'common/models/models.dart';
import 'apps/landing/landing_screen.dart';
import 'apps/admin/screens/admin_tickets_screen.dart';
import 'apps/customer/screens/services/support_tickets_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Google Maps renderer (Hybrid Composition / SurfaceView)
  // Fixes blank map tiles on MIUI/Xiaomi devices using TextureView
  if (defaultTargetPlatform == TargetPlatform.android) {
    final mapsImplementation = GoogleMapsFlutterPlatform.instance;
    if (mapsImplementation is GoogleMapsFlutterAndroid) {
      mapsImplementation.useAndroidViewSurface = true;
      await mapsImplementation
          .initializeWithRenderer(AndroidMapRenderer.latest);
    }
  }

  // Load environment variables from .env file
  await dotenv.load(fileName: '.env');

  // Initialize Supabase with credentials from .env
  try {
    await Supabase.initialize(
      url: EnvConfig.supabaseUrl,
      anonKey: EnvConfig.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.implicit,
      ),
      debug: false, // Set to false in production
    );
  } catch (e) {
    await MockAuthService.initialize();
  }

  // Initialize AuthService
  await AuthService.initialize();

  // Initialize automatic token refresh
  AuthHelper.initializeAutoRefresh();

  // Initialize Thai locale for date formatting
  await initializeDateFormatting('th');

  // Initialize FCM Notification Service
  await FCMNotificationService().initialize();

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  @override
  void dispose() {
    // Cleanup auth helper when app is disposed
    AuthHelper.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: Consumer<LanguageProvider>(
        builder: (context, languageProvider, _) {
          if (!languageProvider.loaded) {
            return const MaterialApp(
              home: Scaffold(body: Center(child: CircularProgressIndicator())),
            );
          }
          return MaterialApp(
            title: 'JDC Delivery',
            debugShowCheckedModeBanner: false,
            navigatorKey: AppNavigationService.navigatorKey,
            restorationScopeId: 'app',
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.system,
            locale: languageProvider.localeOverride,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const AuthGate(),
            routes: {
              '/landing': (context) => const PublicLandingScreen(),
              '/login': (context) => const LoginScreen(),
              '/map': (context) => const MapScreen(),
              '/driver_dashboard': (context) => const DriverDashboardScreen(),
              '/merchant_dashboard': (context) =>
                  const MerchantDashboardScreen(),
              '/ride_service': (context) => const RideServiceScreen(),
              '/food_service': (context) => const FoodHomeScreen(),
              '/parcel_service': (context) => const ParcelServiceScreen(),
              '/customer_order_detail': (context) =>
                  const _NotificationBookingRoute(
                    destination: _NotificationBookingDestination.customerOrder,
                  ),
              '/customer_ride_status': (context) =>
                  const _NotificationBookingRoute(
                    destination:
                        _NotificationBookingDestination.customerRideStatus,
                  ),
              '/driver_job_detail': (context) =>
                  const _NotificationBookingRoute(
                    destination: _NotificationBookingDestination.driverJob,
                  ),
              '/merchant_order_detail': (context) =>
                  const _NotificationBookingRoute(
                    destination: _NotificationBookingDestination.merchantOrder,
                  ),
              '/admin_tickets': (context) => const AdminTicketsScreen(),
              '/my_tickets': (context) => const SupportTicketsScreen(),
              '/notifications': (context) {
                final arguments = ModalRoute.of(context)?.settings.arguments;
                final role = arguments is Map
                    ? arguments['role']?.toString() ?? 'user'
                    : 'user';
                return NotificationCenterScreen(role: role);
              },
              '/driver_assigned': (context) {
                final arguments = ModalRoute.of(context)?.settings.arguments;
                if (arguments == null || arguments is! Booking) {
                  // Fallback to login if booking is not provided
                  return const LoginScreen();
                }
                return WaitingForDriverScreen(booking: arguments);
              },
            },
            onUnknownRoute: (settings) {
              // Handle unknown routes
              return MaterialPageRoute(
                builder: (context) => const LoginScreen(),
              );
            },
          );
        },
      ),
    );
  }
}

enum _NotificationBookingDestination {
  customerOrder,
  customerRideStatus,
  driverJob,
  merchantOrder,
}

class _NotificationBookingRoute extends StatelessWidget {
  final _NotificationBookingDestination destination;

  const _NotificationBookingRoute({required this.destination});

  @override
  Widget build(BuildContext context) {
    final bookingId = _bookingIdFromArguments(
      ModalRoute.of(context)?.settings.arguments,
    );
    if (bookingId == null) {
      return _fallbackScreen();
    }

    return FutureBuilder<Booking?>(
      future: BookingService().getBookingById(bookingId),
      builder: (context, snapshot) {
        final booking = snapshot.data;
        if (booking != null) {
          switch (destination) {
            case _NotificationBookingDestination.customerOrder:
              return CustomerOrderDetailScreen(booking: booking);
            case _NotificationBookingDestination.customerRideStatus:
              return CustomerRideStatusScreen(booking: booking);
            case _NotificationBookingDestination.driverJob:
              return DriverJobDetailScreen(booking: booking);
            case _NotificationBookingDestination.merchantOrder:
              return MerchantOrderDetailScreen(order: booking.toJson());
          }
        }

        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        return _fallbackScreen();
      },
    );
  }

  Widget _fallbackScreen() {
    switch (destination) {
      case _NotificationBookingDestination.customerOrder:
        return const FoodHomeScreen();
      case _NotificationBookingDestination.customerRideStatus:
        return const RideServiceScreen();
      case _NotificationBookingDestination.driverJob:
        return const DriverDashboardScreen();
      case _NotificationBookingDestination.merchantOrder:
        return const MerchantDashboardScreen();
    }
  }

  String? _bookingIdFromArguments(Object? arguments) {
    if (arguments is Map) {
      final bookingId = arguments['booking_id']?.toString().trim();
      return bookingId == null || bookingId.isEmpty ? null : bookingId;
    }
    final bookingId = arguments?.toString().trim();
    return bookingId == null || bookingId.isEmpty ? null : bookingId;
  }
}
