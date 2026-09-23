// Wave 1.5 b2ride — widget test หน้าจอเรียกรถ/แผนที่/พัสดุ/ซักรีด หลังประกอบ layout ใหม่
//
// ใส่ข้อมูลจริงเข้าไป (booking ที่มีคนขับ/ราคา/ที่อยู่) เพราะหน้าจอสถานะว่างจับ overflow ไม่ได้
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
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
import 'package:jedechai_delivery_new/common/models/booking.dart';
import 'package:jedechai_delivery_new/common/providers/auth_provider.dart';
import 'package:jedechai_delivery_new/common/providers/language_provider.dart';
import 'package:jedechai_delivery_new/l10n/app_localizations.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Booking _booking({
  String status = 'driver_accepted',
  String serviceType = 'ride',
}) {
  final now = DateTime(2026, 9, 23, 18, 4);
  return Booking(
    id: 'b2ride-test-booking',
    customerId: 'customer-1',
    driverId: 'driver-1',
    serviceType: serviceType,
    originLat: 13.7563,
    originLng: 100.5018,
    pickupAddress: 'จุดรับ · ถ.หน้าเมือง ซ.3 ต.ในเมือง อ.เมือง',
    destLat: 13.748,
    destLng: 100.496,
    destinationAddress: 'ปลายทาง · หมู่บ้านทดสอบชื่อยาวมาก ซ.12 ต.ในเมือง',
    distanceKm: 6.4,
    price: 120,
    status: status,
    driverName: 'สมชาย วงศ์ใหญ่ทดสอบชื่อยาว',
    driverPhone: '0812345678',
    createdAt: now.subtract(const Duration(minutes: 20)),
    updatedAt: now,
  );
}

Map<String, Widget Function()> get _screens => {
      'Rating': () => RatingScreen(booking: _booking(status: 'completed')),
      'Cancellation': () => CancellationScreen(booking: _booking()),
      'RideHome': () => const RideHomeScreen(),
      'RideService': () => const RideServiceScreen(),
      'RideStatus': () =>
          CustomerRideStatusScreen(booking: _booking(status: 'in_transit')),
      'MapPicker': () => const DeliveryMapPickerScreen(),
      'Map': () => const MapScreen(),
      'BookingConfirm': () => BookingConfirmationScreen(booking: _booking()),
      'Parcel': () => const ParcelServiceScreen(),
      'Laundry': () => const LaundryServiceScreen(),
    };

const _dataErrors = [
  'unauthenticated',
  'User not found',
  'AuthRetryableFetchException',
  'SocketException',
  'Failed host lookup',
  'ClientException',
  'Connection refused',
  'PostgrestException',
  'MissingPluginException',
  'google_maps',
];

const _layoutErrors = [
  'overflowed',
  'RenderFlex',
  'RenderBox was not laid out',
  'Incorrect use of ParentData',
];

/// เก็บ layout error ที่ framework โยนออกมาทุกเฟรม (บางอันไม่ถูกส่งผ่าน takeException)
final List<String> _caughtLayoutErrors = [];

void _installLayoutErrorRecorder() {
  final previous = FlutterError.onError;
  FlutterError.onError = (details) {
    final text = details.toString();
    if (_layoutErrors.any(text.contains)) {
      _caughtLayoutErrors.add(text.split('\n').first);
    }
    previous?.call(details);
  };
}

void _expectNoLayoutError(WidgetTester tester) {
  final error = tester.takeException();
  if (error == null) return;
  final text = error.toString();
  if (_layoutErrors.any(text.contains)) {
    fail('เจอปัญหา layout: $text');
  }
  final isDataError =
      _dataErrors.any(text.contains) || text.contains('Multiple exceptions');
  expect(isDataError, isTrue, reason: 'เจอ error ที่ไม่ใช่เรื่องข้อมูล: $text');
}

Future<void> _openAndCheck(
  WidgetTester tester,
  Size size,
  Widget screen, {
  ThemeData? theme,
}) async {
  _installLayoutErrorRecorder();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: MaterialApp(
        theme: theme ?? AppTheme.lightTheme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: screen,
      ),
    ),
  );
  // ตรวจหลายเฟรม: overflow บางจุดโผล่หลัง data/animation เข้ามา ไม่ใช่เฟรมแรก
  for (final step in const [300, 500, 1200]) {
    await tester.pump(Duration(milliseconds: step));
    _expectNoLayoutError(tester);
  }
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 4));
  if (_caughtLayoutErrors.isNotEmpty) {
    final errors = _caughtLayoutErrors.join(' | ');
    _caughtLayoutErrors.clear();
    fail('เจอปัญหา layout: $errors');
  }
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.testLoad(fileInput: '''
SUPABASE_URL=https://test.invalid
SUPABASE_ANON_KEY=test-anon-key
GOOGLE_MAPS_API_KEY=test-key
''');
    SharedPreferences.setMockInitialValues(const {});
    await Supabase.initialize(
      url: 'https://test.invalid',
      anonKey: 'test-anon-key',
    );
  });

  const sizes = {
    'มือถือ 390x844': Size(390, 844),
    'จอเล็ก 360x640': Size(360, 640),
    'แท็บเล็ต 834x1112': Size(834, 1112),
    'แนวนอน 844x390': Size(844, 390),
  };

  for (final entry in _screens.entries) {
    group('b2ride ${entry.key}', () {
      for (final size in sizes.entries) {
        testWidgets('${size.key} มีข้อมูลในงาน', (tester) async {
          await _openAndCheck(tester, size.value, entry.value());
        });
      }

      testWidgets('โหมดมืด 390x844', (tester) async {
        await _openAndCheck(
          tester,
          const Size(390, 844),
          entry.value(),
          theme: AppTheme.darkTheme,
        );
      });
    });
  }
}
