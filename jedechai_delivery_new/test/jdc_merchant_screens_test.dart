// T1.B — widget test หน้าจอร้านค้าหลัง redesign: ต้องเปิดได้ไม่พัง layout
// ทั้งจอเล็กสุด (360x640) แท็บเล็ต (834x1112) มือถือแนวนอน และโหมดมืด
// ตามเกณฑ์ปิดงาน Wave 1 + ภาคผนวก responsive
//
// ใช้สูตรเตรียม environment ชุดเดียวกับ test/jdc_driver_screens_test.dart
// (dotenv + SharedPreferences + Supabase ปลอม) เพราะหน้าจอโหลดข้อมูลใน
// initState ซึ่งจะ fail ใน test — ทุก loader ครอบ try/catch ไว้แล้ว
// จึงเหลือแค่ render สถานะ error/ว่าง ซึ่งพอสำหรับตรวจว่าโครง layout ไม่พัง
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/menu/merchant_add_edit_menu_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/menu/merchant_menu_categories_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/menu_management_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/merchant_coupon_management_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/merchant_dashboard_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/merchant_gp_plan_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/merchant_laundry_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/merchant_orders_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/merchant_settings_screen.dart';
import 'package:jedechai_delivery_new/l10n/app_localizations.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import 'package:jedechai_delivery_new/common/providers/auth_provider.dart';
import 'package:jedechai_delivery_new/common/providers/language_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  // หน้าที่สร้างได้โดยไม่ต้องมี order/menu item จากภายนอก
  final screens = <String, Widget Function()>{
    'ออเดอร์เข้า': () => const MerchantOrdersScreen(),
    'แดชบอร์ด': () => const MerchantDashboardScreen(),
    'งานซักรีด': () => const MerchantLaundryScreen(),
    'จัดการเมนู': () => const MenuManagementScreen(),
    'เพิ่มเมนูใหม่': () => const MerchantAddEditMenuScreen(),
    'หมวดหมู่เมนู': () => const MerchantMenuCategoriesScreen(),
    'คูปองร้าน': () => const MerchantCouponManagementScreen(),
    'แผน GP': () => const MerchantGpPlanScreen(),
    'ตั้งค่าร้าน': () => const MerchantSettingsScreen(),
  };

  // หน้าจอโหลดข้อมูลจาก Supabase ที่ไม่มี session ใน test — error พวกนี้เป็น
  // เรื่องของชั้นข้อมูล ไม่ใช่สิ่งที่เทสต์นี้ตรวจ ปล่อยผ่านเฉพาะรายการนี้
  // ส่วน error เรื่อง layout (overflow, constraint) ต้องทำให้เทสต์ตก
  const dataErrors = [
    'unauthenticated',
    'User not found',
    'AuthRetryableFetchException',
    'SocketException',
    'Failed host lookup',
  ];

  void expectNoLayoutError(WidgetTester tester) {
    final error = tester.takeException();
    if (error == null) return;
    final text = error.toString();
    final isDataError = dataErrors.any(text.contains);
    expect(isDataError, isTrue, reason: 'เจอ error ที่ไม่ใช่เรื่องข้อมูล: $text');
  }

  Future<void> pumpAt(
    WidgetTester tester,
    Size size,
    Widget screen, {
    ThemeData? theme,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    // หน้าร้านค้าบางหน้ามี LanguageSwitcher ที่อ่าน provider จาก context
    // ถ้าไม่ครอบจะได้ ProviderNotFoundException แทนที่จะได้ผลตรวจ layout จริง
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
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
    // ให้ loader ที่ fail settle ลงสถานะ error/ว่างก่อนตรวจ
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// เปิดหน้า ตรวจ layout แล้วปิดหน้าให้เรียบร้อยในเทสต์เดียว
  ///
  /// ต้องปิดหน้าภายใน test body เพราะบางหน้าตั้ง `Timer.periodic` (auto refresh)
  /// และ `Future.delayed(3 วินาที)` ไว้ ถ้าปล่อยค้าง เทสต์จะตกด้วย
  /// "Pending timers" ซึ่งไม่เกี่ยวกับ layout ที่ต้องการตรวจ
  Future<void> openAndCheck(
    WidgetTester tester,
    Size size,
    Widget screen, {
    ThemeData? theme,
  }) async {
    await pumpAt(tester, size, screen, theme: theme);
    expectNoLayoutError(tester);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(const Duration(seconds: 4));
  }

  for (final entry in screens.entries) {
    for (final sizeEntry in sizes.entries) {
      testWidgets('${entry.key} เปิดได้บน${sizeEntry.key}', (tester) async {
        await openAndCheck(tester, sizeEntry.value, entry.value());
      });
    }

    testWidgets('${entry.key} เปิดได้บนมือถือแนวนอน 640x360', (tester) async {
      await openAndCheck(tester, landscape, entry.value());
    });

    testWidgets('${entry.key} เปิดได้ในโหมดมืด', (tester) async {
      await openAndCheck(tester, const Size(390, 844), entry.value(),
          theme: AppTheme.darkTheme);
    });
  }

  // จอเล็กสุด + โหมดมืด เป็นคู่ที่เจอปัญหาบ่อยที่สุดในหน้าที่มีตารางตัวเลข
  testWidgets('แดชบอร์ด เปิดได้ในโหมดมืดบนจอเล็ก 360x640', (tester) async {
    await openAndCheck(tester, const Size(360, 640), const MerchantDashboardScreen(),
        theme: AppTheme.darkTheme);
  });
}
