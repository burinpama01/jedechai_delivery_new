import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'common/config/env_config.dart';
import 'common/providers/auth_provider.dart';
import 'common/services/services.dart';
import 'common/services/mock_auth_service.dart';
import 'utils/auth_helper.dart';
import 'theme/app_theme.dart';
import 'common/widgets/auth_gate.dart';
import 'apps/customer/customer.dart';
import 'apps/driver/driver.dart';
import 'apps/merchant/merchant.dart';
import 'common/models/models.dart';
import 'apps/landing/landing_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Google Maps renderer (Hybrid Composition / SurfaceView)
  // Fixes blank map tiles on MIUI/Xiaomi devices using TextureView
  if (defaultTargetPlatform == TargetPlatform.android) {
    final mapsImplementation = GoogleMapsFlutterPlatform.instance;
    if (mapsImplementation is GoogleMapsFlutterAndroid) {
      mapsImplementation.useAndroidViewSurface = true;
      await mapsImplementation.initializeWithRenderer(AndroidMapRenderer.latest);
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
      ],
      child: MaterialApp(
        title: 'Jedechai Delivery',
        debugShowCheckedModeBanner: false,
        navigatorKey: AppNavigationService.navigatorKey,
        restorationScopeId: 'app',
        theme: AppTheme.lightTheme,
        locale: const Locale('th', 'TH'),
        supportedLocales: const [
          Locale('th', 'TH'),
          Locale('en', 'US'),
        ],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const AuthGate(),
        routes: {
          '/landing': (context) => const PublicLandingScreen(),
          '/login': (context) => const LoginScreen(),
          '/map': (context) => const MapScreen(),
          '/driver_dashboard': (context) => const DriverDashboardScreen(),
          '/merchant_dashboard': (context) => const MerchantDashboardScreen(),
          '/ride_service': (context) => const RideServiceScreen(),
          '/food_service': (context) => const FoodHomeScreen(),
          '/parcel_service': (context) => const ParcelServiceScreen(),
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
      ),
    );
  }
}
