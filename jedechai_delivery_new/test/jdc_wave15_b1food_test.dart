// Wave 1.5 b1food — widget test หน้าจอ flow สั่งอาหารหลังประกอบ layout ใหม่ตาม artboard
//
// ต่างจาก test/jdc_customer_food_screens_test.dart ตรงที่ชุดนี้ **ใส่ข้อมูลจริงเข้าไป**
// (booking ที่มีคนขับ/ราคา/ที่อยู่ และตะกร้าที่มีของ) เพราะบทเรียนจาก FoodHome คือ
// หน้าจอสถานะว่างไม่มีทางจับ overflow ของการ์ดที่มีข้อมูลได้
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/apps/customer/providers/cart_provider.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/customer_home_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/food_details_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/customer_order_detail_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/driver_assigned_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/food_checkout_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/food_service_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/payment_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/restaurant_detail_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/tracking_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/waiting_for_driver_screen.dart';
import 'package:jedechai_delivery_new/common/models/booking.dart';
import 'package:jedechai_delivery_new/common/models/menu_item.dart';
import 'package:jedechai_delivery_new/common/providers/auth_provider.dart';
import 'package:jedechai_delivery_new/common/providers/language_provider.dart';
import 'package:jedechai_delivery_new/l10n/app_localizations.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- ข้อมูลตัวอย่างที่ "มีของ" จริง ----------------------------------

Booking _booking({String status = 'driver_accepted'}) {
  final now = DateTime(2026, 9, 23, 18, 4);
  return Booking(
    id: 'b1food-test-booking',
    customerId: 'customer-1',
    driverId: 'driver-1',
    serviceType: 'food',
    merchantId: 'merchant-1',
    originLat: 13.7563,
    originLng: 100.5018,
    pickupAddress: 'ครัวป้าน้อย · ถ.หน้าเมือง ซ.3 ต.ในเมือง',
    destLat: 13.748,
    destLng: 100.496,
    destinationAddress: 'บ้าน · ถ.หน้าเมือง ซ.3 ต.ในเมือง อ.เมือง',
    distanceKm: 1.8,
    price: 175,
    deliveryFee: 15,
    status: status,
    driverName: 'สมชาย วงศ์ใหญ่ทดสอบชื่อยาว',
    driverPhone: '0812345678',
    createdAt: now.subtract(const Duration(minutes: 45)),
    updatedAt: now,
  );
}

final _menuItem = MenuItem(
  id: 'menu-1',
  merchantId: 'merchant-1',
  name: 'ข้าวกะเพราหมูสับไข่ดาว',
  description: 'หมูสับผัดใบกะเพราไฟแรง เสิร์ฟพร้อมไข่ดาวกรอบ',
  price: 65,
  isAvailable: true,
  createdAt: DateTime(2026, 1, 1),
);

CartProvider _cartWithItems() {
  final cart = CartProvider();
  cart.addItem(
    merchantId: 'merchant-1',
    merchantName: 'ครัวป้าน้อย',
    item: CartItem(
      menuItemId: 'menu-1',
      name: 'ข้าวกะเพราหมูสับไข่ดาว',
      basePrice: 65,
      quantity: 2,
    ),
  );
  return cart;
}

Map<String, Widget Function()> get _screens => {
      'Main': () => const CustomerHomeScreen(),
      'FoodService': () => const FoodServiceScreen(),
      'Restaurant': () => const RestaurantDetailScreen(
            merchantId: 'merchant-1',
            merchantName: 'ครัวป้าน้อย',
            distanceKm: 1.2,
          ),
      'FoodDetails': () => FoodDetailsScreen(
            menuItem: _menuItem,
            restaurantName: 'ครัวป้าน้อย',
          ),
      'Checkout': () => const FoodCheckoutScreen(),
      'Payment': () => PaymentScreen(booking: _booking()),
      'WaitingDriver': () =>
          WaitingForDriverScreen(booking: _booking(status: 'pending')),
      'DriverAssigned': () => DriverAssignedScreen(booking: _booking()),
      'Tracking': () => TrackingScreen(booking: _booking(status: 'in_transit')),
      'OrderDetail': () =>
          CustomerOrderDetailScreen(booking: _booking(status: 'completed')),
    };

// --- helper ----------------------------------------------------------

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

const _layoutErrors = [
  'overflowed',
  'RenderFlex',
  'RenderBox was not laid out',
  'Incorrect use of ParentData',
];

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
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => _cartWithItems()),
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
  _expectNoLayoutError(tester);
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 4));
}

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
    'มือถือ 390x844': Size(390, 844),
    'จอเล็ก 360x640': Size(360, 640),
    'แท็บเล็ต 834x1112': Size(834, 1112),
    'แนวนอน 844x390': Size(844, 390),
  };

  for (final entry in _screens.entries) {
    group('b1food ${entry.key}', () {
      for (final size in sizes.entries) {
        testWidgets('${size.key} มีข้อมูลในตะกร้า/ออเดอร์', (tester) async {
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
