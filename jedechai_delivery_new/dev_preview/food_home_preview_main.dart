// Dev-only entrypoint: เปิด FoodHomeScreen ตรง ๆ โดยไม่ผ่าน AuthGate
// ใช้เทียบหน้าจอกับ artboard ด้วยข้อมูลร้านจริง (profiles ของร้านอ่านได้ด้วย anon key)
// build: flutter build web -t dev_preview/food_home_preview_main.dart -o build/web_preview
// ?cart=1 = ใส่ของตัวอย่างในตะกร้าเพื่อดูแถบตะกร้าล่าง · ?theme=dark = โหมดมืด
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jedechai_delivery_new/apps/customer/providers/cart_provider.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/food_home_screen.dart';
import 'package:jedechai_delivery_new/common/config/env_config.dart';
import 'package:jedechai_delivery_new/l10n/app_localizations.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import 'package:jedechai_delivery_new/theme/jdc_layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env.client');
  await Supabase.initialize(
    url: EnvConfig.supabaseUrl,
    anonKey: EnvConfig.supabaseAnonKey,
  );
  await initializeDateFormatting('th');

  final params = Uri.base.queryParameters;
  final cart = CartProvider();
  if (params['cart'] == '1') {
    cart.addItem(
      merchantId: 'preview',
      merchantName: 'ครัวป้าน้อย',
      item: CartItem(
          menuItemId: 'p1', name: 'กะเพราหมูกรอบ', basePrice: 60, quantity: 2),
    );
    cart.addItem(
      merchantId: 'preview',
      merchantName: 'ครัวป้าน้อย',
      item: CartItem(menuItemId: 'p2', name: 'ชาเย็น', basePrice: 55),
    );
  }

  runApp(ChangeNotifierProvider.value(
    value: cart,
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: jdcTextScaleGuard,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: params['theme'] == 'dark' ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(params['lang'] ?? 'th'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: const FoodHomeScreen(),
    ),
  ));
}
