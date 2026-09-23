// Dev-only entrypoint: batch b2ride Wave 1.5 Layout Fidelity preview
// เปิดหน้าจอ customer (เรียกรถ/แผนที่/พัสดุ/ซักรีด) ตรง ๆ โดยไม่ผ่าน AuthGate
//
// build:
//   flutter build web -t dev_preview/b2ride_preview_main.dart \
//     -o build/web_preview --release --no-tree-shake-icons
//
// URL params: ?screen=Rating|Cancellation|RideHome|RideService|RideStatus|
//                     MapPicker|Map|BookingConfirm|Parcel|Laundry
//             &theme=dark  &lang=en
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jedechai_delivery_new/apps/customer/providers/cart_provider.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/map_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/ride/ride_home_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/booking_confirmation_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/cancellation_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/customer_ride_status_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/delivery_map_picker_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/laundry_service_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/parcel_service_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/rating_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/ride_service_screen.dart';
import 'package:jedechai_delivery_new/common/config/env_config.dart';
import 'package:jedechai_delivery_new/common/models/booking.dart';
import 'package:jedechai_delivery_new/common/providers/auth_provider.dart';
import 'package:jedechai_delivery_new/common/providers/language_provider.dart';
import 'package:jedechai_delivery_new/l10n/app_localizations.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';

/// งานตัวอย่างสำหรับพรีวิว (ไม่ได้ดึงข้อมูลจริงเพราะหน้าเหล่านี้ต้อง login)
Booking _mockBooking({String status = 'driver_accepted'}) {
  final now = DateTime.now();
  return Booking(
    id: 'preview-ride-0001',
    customerId: 'preview-customer',
    driverId: 'preview-driver',
    serviceType: 'ride',
    originLat: 13.7563,
    originLng: 100.5018,
    pickupAddress: 'จุดรับ · ถ.หน้าเมือง ซ.3',
    destLat: 13.748,
    destLng: 100.496,
    destinationAddress: 'ปลายทาง · หมู่บ้านสวนธน ซ.12',
    distanceKm: 6.4,
    price: 120,
    status: status,
    driverName: 'สมชาย ว.',
    driverPhone: '0812345678',
    createdAt: now.subtract(const Duration(minutes: 20)),
    updatedAt: now,
  );
}

Widget _screenFor(String name) {
  switch (name) {
    case 'Rating':
      return RatingScreen(booking: _mockBooking(status: 'completed'));
    case 'Cancellation':
      return CancellationScreen(booking: _mockBooking());
    case 'RideService':
      return const RideServiceScreen(
        originAddress: 'จุดรับ · ถ.หน้าเมือง ซ.3',
        destinationAddress: 'ปลายทาง · หมู่บ้านสวนธน ซ.12',
        distanceKm: 6.4,
        baseFare: 95,
      );
    case 'RideStatus':
      return CustomerRideStatusScreen(
          booking: _mockBooking(status: 'in_transit'));
    case 'MapPicker':
      return const DeliveryMapPickerScreen();
    case 'Map':
      return const MapScreen();
    case 'BookingConfirm':
      return BookingConfirmationScreen(booking: _mockBooking());
    case 'Parcel':
      return const ParcelServiceScreen();
    case 'Laundry':
      return const LaundryServiceScreen();
    case 'RideHome':
    default:
      return const RideHomeScreen();
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env.client');
  await initializeDateFormatting('th');
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );

  final params = Uri.base.queryParameters;
  final screen = params['screen'] ?? 'RideHome';
  final dark = params['theme'] == 'dark';
  final locale = params['lang'] == 'en' ? const Locale('en') : const Locale('th');

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        locale: locale,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: _screenFor(screen),
      ),
    ),
  );
}
