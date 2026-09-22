// T1.D — widget test หน้าลูกค้ากลุ่มเดินทาง/บริการอื่น/แผนที่ หลัง redesign
// ต้องเปิดได้ไม่พัง layout ทั้งจอเล็กสุด แท็บเล็ต มือถือแนวนอน และโหมดมืด
//
// ใช้สูตรเตรียม environment เดียวกับ test/jdc_merchant_screens_test.dart
// (dotenv + SharedPreferences + Supabase ปลอม + provider ที่หน้าจอต้องใช้)
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/apps/customer/providers/cart_provider.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/map_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/ride/ride_home_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/delivery_map_picker_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/help_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/laundry_service_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/parcel_service_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/ride_service_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/saved_addresses_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/support_tickets_screen.dart';
import 'package:jedechai_delivery_new/common/providers/auth_provider.dart';
import 'package:jedechai_delivery_new/common/providers/language_provider.dart';
import 'package:jedechai_delivery_new/l10n/app_localizations.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// error ของชั้นข้อมูล/ปลั๊กอินที่เกิดจากสภาพแวดล้อม test ไม่ใช่ของที่เทสต์นี้ตรวจ
const _dataErrors = [
  'unauthenticated',
  'User not found',
  'PostgrestException',
  'AuthRetryableFetchException',
  'SocketException',
  'Failed host lookup',
  'ClientException',
  'Connection refused',
  'MissingPluginException',
  'Multiple exceptions',
];

/// ร่องรอยปัญหา layout ที่ต้องทำให้เทสต์ตกเสมอ ต่อให้มี error อื่นปนมา
const _layoutErrors = [
  'overflowed',
  'RenderFlex',
  'RenderBox was not laid out',
  'Incorrect use of ParentData',
];

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

  final screens = <String, Widget Function()>{
    'เรียกรถ': () => const RideHomeScreen(),
    'บริการเรียกรถ': () => const RideServiceScreen(),
    'ส่งพัสดุ': () => const ParcelServiceScreen(),
    'ซักรีด': () => const LaundryServiceScreen(),
    'แผนที่': () => const MapScreen(),
    'ปักหมุดที่อยู่': () => const DeliveryMapPickerScreen(),
    'ที่อยู่ที่บันทึกไว้': () => const SavedAddressesScreen(),
    'ช่วยเหลือ': () => const HelpScreen(),
    'แจ้งปัญหา': () => const SupportTicketsScreen(),
  };

  void expectNoLayoutError(WidgetTester tester) {
    final error = tester.takeException();
    if (error == null) return;
    final text = error.toString();
    if (_layoutErrors.any(text.contains)) {
      fail('เจอปัญหา layout: $text');
    }
    expect(_dataErrors.any(text.contains), isTrue,
        reason: 'เจอ error ที่ไม่ใช่เรื่องข้อมูล: $text');
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
    await tester.pump(const Duration(milliseconds: 300));
  }

  /// เปิดหน้า ตรวจ layout แล้วปิดหน้าให้เรียบร้อยภายในเทสต์เดียว
  /// (บางหน้าตั้ง timer/stream ไว้ ถ้าปล่อยค้างจะตกด้วย "Pending timers")
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

  testWidgets('เรียกรถ เปิดได้ในโหมดมืดบนจอเล็ก 360x640', (tester) async {
    await openAndCheck(tester, const Size(360, 640), const RideHomeScreen(),
        theme: AppTheme.darkTheme);
  });
}
