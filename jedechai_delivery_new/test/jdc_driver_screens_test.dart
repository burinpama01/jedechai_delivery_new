// T1.A — widget test หน้าจอคนขับหลัง redesign: ต้องเปิดได้ไม่พัง layout
// ทั้งจอเล็กสุด (360x640) และแท็บเล็ต (834x1112) ตามเกณฑ์ปิดงาน Wave 1
//
// หมายเหตุ: หน้าจอเหล่านี้โหลดข้อมูลจาก Supabase ใน initState ซึ่งจะ fail
// ทันทีในสภาพแวดล้อม test (ไม่มีการ initialize) — ทุก loader ของหน้าครอบ
// try/catch ไว้แล้ว จึงเหลือแค่ render สถานะ error/ว่าง ซึ่งเพียงพอต่อ
// การตรวจว่าโครง layout ใหม่ไม่ overflow ไม่ throw
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/apps/driver/screens/driver_earnings_screen.dart';
import 'package:jedechai_delivery_new/apps/driver/screens/driver_performance_screen.dart';
import 'package:jedechai_delivery_new/apps/driver/screens/driver_service_type_settings.dart';
import 'package:jedechai_delivery_new/apps/driver/screens/driver_shift_screen.dart';
import 'package:jedechai_delivery_new/apps/driver/screens/driver_wallet_screen.dart';
import 'package:jedechai_delivery_new/apps/driver/screens/wallet_topup_screen.dart';
import 'package:jedechai_delivery_new/apps/driver/screens/wallet_withdrawal_screen.dart';
import 'package:jedechai_delivery_new/l10n/app_localizations.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  // กัน Supabase.instance โยน NotInitializedError ตอน screen อ่าน userId —
  // ใช้ URL ปลอม ไม่มี user จริง หน้าจอจะเดินไปสถานะ error/ว่างตาม guard ของตัวเอง
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    // โค้ดแอปอ่าน config ผ่าน flutter_dotenv ทุกครั้งที่ว่า AuthService —
    // ไม่ load จะโดน NotInitializedError ของ dotenv ก่อนถึงมือ Supabase เลย
    dotenv.testLoad(fileInput: '''
SUPABASE_URL=https://test.invalid
SUPABASE_ANON_KEY=test-anon-key
''');
    // supabase_flutter ใช้ SharedPreferences เก็บ session — ใน test env
    // ต้อง mock ค่าเริ่มต้นไม่งั้น MissingPluginException ตอน initialize
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

  // มือถือแนวนอน — เนื้อหา sheet/ฟอร์มต้องไม่ล้นแนวตั้ง (เคยพบล้นที่
  // DriverServiceTypeSettings ก่อนใส่ SingleChildScrollView)
  const landscape = Size(640, 360);

  // หน้าที่สร้างได้โดยไม่ต้องมี booking/params จากภายนอก
  // (DriverServiceTypeSettings เป็นเนื้อหา bottom sheet ไม่มี Scaffold ของตัวเอง)
  final screens = <String, Widget Function()>{
    'กะทำงาน': () => const DriverShiftScreen(),
    'สถิติและคะแนน': () => const DriverPerformanceScreen(),
    'กระเป๋าเงิน': () => const DriverWalletScreen(),
    'รายได้': () => const DriverEarningsScreen(),
    'เติมเงิน': () => const WalletTopUpScreen(),
    'ถอนเงิน': () => const WalletWithdrawalScreen(),
    'ประเภทงานที่รับ': () => const DriverServiceTypeSettings(
          initialServiceTypes: ['food'],
          driverId: 'test-driver',
        ),
  };

  Future<void> pumpAt(WidgetTester tester, Size size, Widget screen,
      {ThemeData? theme}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
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
    );
    // ให้ loader ที่ fail ได้ settle ลงสถานะ error/ว่างก่อนตรวจ
    await tester.pump(const Duration(milliseconds: 300));
  }

  for (final entry in screens.entries) {
    for (final sizeEntry in sizes.entries) {
      testWidgets('${entry.key} เปิดได้บน${sizeEntry.key}', (tester) async {
        await pumpAt(tester, sizeEntry.value, entry.value());
        expect(tester.takeException(), isNull);
      });
    }
    testWidgets('${entry.key} เปิดได้บนมือถือแนวนอน 640x360', (tester) async {
      await pumpAt(tester, landscape, entry.value());
      expect(tester.takeException(), isNull);
    });
  }

  // โหมดมืดต้องครบทุกหน้าที่สร้างเองได้ ไม่ใช่แค่หน้าเดียว
  // (code review จับได้ว่าขาด — Major-2)
  for (final entry in screens.entries) {
    testWidgets('${entry.key} เปิดได้ในโหมดมืด', (tester) async {
      await pumpAt(tester, const Size(390, 844), entry.value(),
          theme: AppTheme.darkTheme);
      expect(tester.takeException(), isNull);
    });
  }

  // โหมดมืดบนจอเล็กสุดด้วย — พื้นเข้มกับเงาทำให้ระยะต่างจากโหมดสว่างได้
  testWidgets('รายได้ เปิดได้ในโหมดมืดบนจอเล็ก 360x640', (tester) async {
    await pumpAt(tester, const Size(360, 640), const DriverEarningsScreen(),
        theme: AppTheme.darkTheme);
    expect(tester.takeException(), isNull);
  });
}
