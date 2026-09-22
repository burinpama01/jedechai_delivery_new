// T1.C — widget test หน้าจอ customer food/order หลัง redesign
// ตรวจว่าเปิดได้ไม่พัง layout บน 4 สภาวะ:
//   360x640 (จอเล็ก), 834x1112 (แท็บเล็ต), 640x360 (แนวนอน), dark 390x844
//
// เทสต์นี้ตรวจเฉพาะ layout ไม่ตรวจ business logic
// Error จากชั้นข้อมูล (unauthenticated, SocketException ฯลฯ) ปล่อยผ่านได้
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/food_details_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/booking_confirmation_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/cancellation_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/customer_order_detail_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/driver_assigned_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/food_checkout_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/food_home_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/food_service_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/payment_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/rating_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/restaurant_detail_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/tracking_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/waiting_for_driver_screen.dart';
import 'package:jedechai_delivery_new/common/models/booking.dart';
import 'package:jedechai_delivery_new/common/models/menu_item.dart';
import 'package:jedechai_delivery_new/apps/customer/providers/cart_provider.dart';
import 'package:jedechai_delivery_new/common/providers/auth_provider.dart';
import 'package:jedechai_delivery_new/common/providers/language_provider.dart';
import 'package:jedechai_delivery_new/l10n/app_localizations.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- Fake data -------------------------------------------------------

final _fakeBooking = Booking.empty();

final _fakeMenuItem = MenuItem(
  id: 'test-item-1',
  merchantId: 'test-merchant-1',
  name: 'ข้าวผัด',
  description: 'ข้าวผัดหมู',
  price: 60.0,
  isAvailable: true,
  createdAt: DateTime(2025, 1, 1),
);

// --- Screens to test -------------------------------------------------

Map<String, Widget Function()> get _screens => {
      'FoodHomeScreen': () => const FoodHomeScreen(),
      'FoodServiceScreen': () => const FoodServiceScreen(),
      'FoodCheckoutScreen': () => const FoodCheckoutScreen(),
      'FoodDetailsScreen': () => FoodDetailsScreen(
            menuItem: _fakeMenuItem,
            restaurantName: 'ร้านทดสอบ',
          ),
      'RestaurantDetailScreen': () => const RestaurantDetailScreen(
            merchantId: 'test-merchant-1',
            merchantName: 'ร้านทดสอบ',
          ),
      'PaymentScreen': () => PaymentScreen(booking: _fakeBooking),
      'TrackingScreen': () => TrackingScreen(booking: _fakeBooking),
      'DriverAssignedScreen': () => DriverAssignedScreen(booking: _fakeBooking),
      'WaitingForDriverScreen': () =>
          WaitingForDriverScreen(booking: _fakeBooking),
      'RatingScreen': () => RatingScreen(booking: _fakeBooking),
      'CancellationScreen': () => CancellationScreen(booking: _fakeBooking),
      'CustomerOrderDetailScreen': () =>
          CustomerOrderDetailScreen(booking: _fakeBooking),
      'BookingConfirmationScreen': () =>
          BookingConfirmationScreen(booking: _fakeBooking),
    };

// --- Test helpers ----------------------------------------------------

const _dataErrors = [
  'unauthenticated',
  'User not found',
  'AuthRetryableFetchException',
  'SocketException',
  'Failed host lookup',
  'ClientException',
  'Connection refused',
  'PostgrestException',
];

/// ร่องรอยของปัญหา layout ที่เทสต์ชุดนี้ต้องจับให้ได้
const _layoutErrors = [
  'overflowed',
  'RenderFlex',
  'RenderBox was not laid out',
  'Incorrect use of ParentData',
  'constraints',
];

void _expectNoLayoutError(WidgetTester tester) {
  final error = tester.takeException();
  if (error == null) return;
  final text = error.toString();
  // ถ้าเป็นปัญหา layout ต้องตกทันที ไม่ว่าจะมี error อื่นปนมาด้วยหรือไม่
  final isLayoutError = _layoutErrors.any(text.contains);
  if (isLayoutError) {
    fail('เจอปัญหา layout: $text');
  }
  final isDataError =
      _dataErrors.any(text.contains) || text.contains('Multiple exceptions');
  expect(isDataError, isTrue, reason: 'เจอ error ที่ไม่ใช่เรื่องข้อมูล: $text');
}

Future<void> _pumpAt(
  WidgetTester tester,
  Size size,
  Widget screen, {
  ThemeData? theme,
  CartProvider? cart,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => cart ?? CartProvider()),
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
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _openAndCheck(
  WidgetTester tester,
  Size size,
  Widget screen, {
  ThemeData? theme,
}) async {
  await _pumpAt(tester, size, screen, theme: theme);
  _expectNoLayoutError(tester);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 4));
}

// --- Tests -----------------------------------------------------------

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.testLoad(fileInput: '''
SUPABASE_URL=https://test.invalid
SUPABASE_ANON_KEY=test-anon-key
''');
    SharedPreferences.setMockInitialValues(const {});
    await Supabase.initialize(
      url: 'https://test.invalid',
      anonKey: 'test-anon-key',
    );
  });

  const sizes = {
    'จอเล็ก 360x640': Size(360, 640),
    'แท็บเล็ต 834x1112': Size(834, 1112),
  };
  const landscape = Size(640, 360);

  for (final entry in _screens.entries) {
    final name = entry.key;

    for (final sizeEntry in sizes.entries) {
      testWidgets('$name เปิดได้บน${sizeEntry.key}', (tester) async {
        await _openAndCheck(tester, sizeEntry.value, entry.value());
      });
    }

    testWidgets('$name เปิดได้บนมือถือแนวนอน 640x360', (tester) async {
      await _openAndCheck(tester, landscape, entry.value());
    });

    testWidgets('$name เปิดได้ในโหมดมืด 390x844', (tester) async {
      await _openAndCheck(
        tester,
        const Size(390, 844),
        entry.value(),
        theme: AppTheme.darkTheme,
      );
    });
  }

  // Wave 1.5 regression: แถบตะกร้าเคยยืดเต็มจอเพราะ Center ใน bottomNavigationBar
  for (final size in const [Size(390, 844), Size(834, 1112), Size(640, 360)]) {
    testWidgets(
        'FoodHomeScreen แถบตะกร้าสูงเท่าเนื้อหา ${size.width.toInt()}x${size.height.toInt()}',
        (tester) async {
      final cart = CartProvider()
        ..addItem(
          merchantId: 'm1',
          merchantName: 'ครัวป้าน้อย',
          item: CartItem(
              menuItemId: 'a', name: 'กะเพรา', basePrice: 60, quantity: 2),
        )
        ..addItem(
          merchantId: 'm1',
          merchantName: 'ครัวป้าน้อย',
          item: CartItem(menuItemId: 'b', name: 'ชาเย็น', basePrice: 55),
        );
      await _pumpAt(tester, size, const FoodHomeScreen(), cart: cart);
      _expectNoLayoutError(tester);

      final price = find.text('฿175');
      expect(price, findsOneWidget);
      // ราคาต้องอยู่ช่วงล่างของจอ ไม่ใช่กลางจอ (แถบสูงราว 90px + safe area)
      expect(tester.getCenter(price).dy, greaterThan(size.height - 110));

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(seconds: 4));
    });
  }
}
