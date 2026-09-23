// Dev-only entrypoint: batch b1food Wave 1.5 Layout Fidelity preview
// เปิดหน้าจอ customer ตรง ๆ โดยไม่ผ่าน AuthGate เพื่อเทียบกับ artboard
//
// build:
//   flutter build web -t dev_preview/b1food_preview_main.dart \
//     -o build/web_preview --release --no-tree-shake-icons
//
// serve: cd build/web_preview && npx serve -l 4391
// URL params:
//   ?screen=Main|FoodService|Restaurant|FoodDetails|Checkout|Payment|
//           WaitingDriver|DriverAssigned|Tracking|OrderDetail
//   ?theme=dark
//   ?cart=1   (เพิ่มรายการตัวอย่างในตะกร้า)

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jedechai_delivery_new/apps/customer/providers/cart_provider.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/customer_home_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/food_details_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/driver_assigned_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/food_checkout_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/food_service_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/payment_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/restaurant_detail_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/tracking_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/waiting_for_driver_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/customer_order_detail_screen.dart';
import 'package:jedechai_delivery_new/common/config/env_config.dart';
import 'package:jedechai_delivery_new/common/models/booking.dart';
import 'package:jedechai_delivery_new/common/models/menu_item.dart';
import 'package:jedechai_delivery_new/l10n/app_localizations.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import 'package:jedechai_delivery_new/theme/jdc_layout.dart';

// ── Mock Booking สำหรับ preview (ไม่ดึงข้อมูลจริง) ──
Booking _mockBooking({
  String status = 'pending',
  String serviceType = 'food',
}) {
  final now = DateTime.now();
  return Booking(
    id: 'preview-booking-0001',
    customerId: 'preview-customer',
    driverId: 'preview-driver',
    serviceType: serviceType,
    merchantId: 'preview-merchant',
    originLat: 13.7563,
    originLng: 100.5018,
    pickupAddress: 'ครัวป้าน้อย · ถ.หน้าเมือง',
    destLat: 13.7480,
    destLng: 100.4960,
    destinationAddress: 'บ้าน · ถ.หน้าเมือง ซ.3',
    distanceKm: 1.8,
    price: 175,
    status: status,
    createdAt: now.subtract(const Duration(minutes: 45)),
    updatedAt: now,
    driverName: 'สมชาย ว.',
    driverVehicle: 'Honda Wave ทะเบียน กข-1234',
    paymentMethod: 'wallet',
    deliveryFee: 15,
  );
}

// ── Mock MenuItem สำหรับ FoodDetails preview ──
final _mockMenuItem = MenuItem(
  id: 'preview-item-001',
  merchantId: 'preview-merchant',
  name: 'ข้าวกะเพราหมูสับไข่ดาว',
  description: 'หมูสับผัดใบกะเพราไฟแรง เสิร์ฟพร้อมไข่ดาวกรอบ',
  price: 65,
  isAvailable: true,
  category: 'ข้าวจานเดียว',
  createdAt: DateTime(2025, 1, 1),
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env.client');
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );
  await initializeDateFormatting('th');

  final params = Uri.base.queryParameters;
  final screen = params['screen'] ?? 'Main';
  final isDark = params['theme'] == 'dark';

  final cart = CartProvider();
  if (params['cart'] == '1') {
    cart.addItem(
      merchantId: 'preview-merchant',
      merchantName: 'ครัวป้าน้อย',
      item: CartItem(
          menuItemId: 'p1',
          name: 'ข้าวกะเพราหมูสับไข่ดาว',
          basePrice: 65,
          quantity: 1),
    );
    cart.addItem(
      merchantId: 'preview-merchant',
      merchantName: 'ครัวป้าน้อย',
      item: CartItem(menuItemId: 'p2', name: 'ชาเย็นสูตรร้าน', basePrice: 55, quantity: 2),
    );
  }

  runApp(ChangeNotifierProvider.value(
    value: cart,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: jdcTextScaleGuard,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(params['lang'] ?? 'th'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: _B1FoodPreviewHome(screen: screen),
    ),
  ));
}

class _B1FoodPreviewHome extends StatelessWidget {
  final String screen;
  const _B1FoodPreviewHome({required this.screen});

  @override
  Widget build(BuildContext context) {
    switch (screen) {
      case 'Main':
        return const CustomerHomeScreen();
      case 'FoodService':
        return const FoodServiceScreen();
      case 'Restaurant':
        return RestaurantDetailScreen(
          merchantId: 'preview-merchant',
          merchantName: 'ครัวป้าน้อย',
          distanceKm: 1.2,
        );
      case 'FoodDetails':
        return FoodDetailsScreen(
          menuItem: _mockMenuItem,
          restaurantName: 'ครัวป้าน้อย',
        );
      case 'Checkout':
        return const FoodCheckoutScreen();
      case 'Payment':
        return PaymentScreen(booking: _mockBooking(status: 'pending'));
      case 'WaitingDriver':
        return WaitingForDriverScreen(
          booking: _mockBooking(status: 'pending'),
        );
      case 'DriverAssigned':
        return DriverAssignedScreen(
          booking: _mockBooking(status: 'assigned'),
        );
      case 'Tracking':
        return TrackingScreen(
          booking: _mockBooking(status: 'in_progress'),
        );
      case 'OrderDetail':
        return CustomerOrderDetailScreen(
          booking: _mockBooking(status: 'completed'),
        );
      default:
        return Scaffold(
          body: Center(
            child: Text(
              'Unknown screen: $screen\n\nAvailable:\nMain, FoodService, Restaurant, FoodDetails,\nCheckout, Payment, WaitingDriver,\nDriverAssigned, Tracking, OrderDetail',
              textAlign: TextAlign.center,
            ),
          ),
        );
    }
  }
}
