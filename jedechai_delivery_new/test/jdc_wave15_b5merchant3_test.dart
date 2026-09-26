// Wave 1.5 b5merchant3 widget tests — MerchantSettingsScreen
// ทดสอบขนาด: 390x844, 360x640, 834x1112, 844x390 (แนวนอน), โหมดมืด
// และตรวจว่า checklist ฟีเจอร์/ข้อความยังแสดงอยู่ในหน้า
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/merchant_settings_screen.dart';
import 'package:jedechai_delivery_new/common/providers/language_provider.dart';
import 'package:jedechai_delivery_new/l10n/app_localizations.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';

// ────────────────────────────────────────────────────────────────────────────
// Fixture
// ────────────────────────────────────────────────────────────────────────────

Map<String, dynamic> _fixture() => {
      'full_name': 'ครัวป้าน้อย',
      'phone_number': '081-234-5678',
      'email': 'panoi.kitchen@example.com',
      'shop_address': '12/3 ถ.พระราม 9 แขวงห้วยขวาง กรุงเทพฯ 10320',
      'shop_status': true,
      'shop_open_time': '09:00',
      'shop_close_time': '21:00',
      'shop_open_days': ['mon', 'tue', 'wed', 'thu', 'fri', 'sat'],
      'order_accept_mode': 'manual',
      'shop_auto_schedule_enabled': true,
      'min_order_amount': 80.0,
      'approval_status': 'approved',
      'merchant_service_types': ['food'],
      'avatar_url': null,
      'shop_photo_url': null,
      'fcm_token': null,
    };

// ────────────────────────────────────────────────────────────────────────────
// Helper
// ────────────────────────────────────────────────────────────────────────────

Widget _wrap(
  Widget screen, {
  bool dark = false,
  Size size = const Size(390, 844),
}) {
  return ChangeNotifierProvider(
    create: (_) => LanguageProvider(),
    child: MaterialApp(
      theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: const Locale('th'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: screen,
      ),
    ),
  );
}

Widget _screen({bool dark = false, Size size = const Size(390, 844)}) => _wrap(
      MerchantSettingsScreen(previewProfile: _fixture()),
      dark: dark,
      size: size,
    );

// ────────────────────────────────────────────────────────────────────────────
// Setup
// ────────────────────────────────────────────────────────────────────────────

void main() {
  setUpAll(() async {
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

  // ──────────────────────────────────────────────────────────────────────────
  // Size / overflow tests
  // ──────────────────────────────────────────────────────────────────────────

  group('MerchantSettingsScreen — ขนาดและ overflow', () {
    testWidgets('390x844 โหมดสว่าง — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_screen());
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('360x640 โหมดสว่าง — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_screen(size: const Size(360, 640)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('834x1112 tablet — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(834, 1112);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_screen(size: const Size(834, 1112)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('844x390 แนวนอน — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_screen(size: const Size(844, 390)));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('390x844 โหมดมืด — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_screen(dark: true));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Checklist feature visibility tests
  // ──────────────────────────────────────────────────────────────────────────

  group('MerchantSettingsScreen — checklist ฟีเจอร์ยังแสดง', () {
    testWidgets('การรับออร์เดอร์อยู่ก่อนข้อมูลโปรไฟล์ร้าน', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();
      final operation = find.text('การรับออร์เดอร์');
      final profile = find.text('ข้อมูลร้านค้า');
      expect(operation, findsOneWidget);
      expect(profile, findsOneWidget);
      expect(tester.getTopLeft(operation).dy,
          lessThan(tester.getTopLeft(profile).dy));
    });

    for (final size in [const Size(360, 640), const Size(844, 390)]) {
      testWidgets(
          'แตะเวลาทำการเปิด dialog และเข้าถึงบันทึกบนจอ ${size.width.toInt()}x${size.height.toInt()}',
          (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_screen(size: size));
        await tester.pump();
        await tester.tap(find.text('เวลาเปิด-ปิดร้าน'));
        await tester.pumpAndSettle();
        expect(find.byType(AlertDialog), findsOneWidget);
        await tester
            .ensureVisible(find.text('เปิด-ปิดร้านอัตโนมัติตามวันและเวลา'));
        await tester.pumpAndSettle();
        expect(find.text('บันทึก').hitTestable(), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('AppBar title = ตั้งค่าร้าน', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();
      expect(find.text('ตั้งค่าร้าน'), findsOneWidget);
    });

    testWidgets('shop name จาก fixture แสดงใน AppBar subtitle', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();
      // AppBar subtitle แสดงชื่อร้านจาก fixture
      expect(find.text('ครัวป้าน้อย'), findsWidgets);
    });

    testWidgets('info card title ข้อมูลร้านค้า แสดง', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();
      expect(find.text('ข้อมูลร้านค้า'), findsOneWidget);
    });

    testWidgets('StoreOS Connect card แสดง', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();
      expect(find.text('StoreOS Connect'), findsOneWidget);
    });

    testWidgets('เมนู accountMenuTitle แสดง', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();
      expect(find.text('เมนู'), findsOneWidget);
    });

    testWidgets('แก้ไขข้อมูลร้าน menu item แสดง', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();
      expect(find.text('แก้ไขข้อมูลร้าน'), findsOneWidget);
    });

    testWidgets('คูปองร้านค้า menu item แสดง', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();
      expect(find.text('คูปองร้านค้า'), findsOneWidget);
    });

    testWidgets('ออกจากระบบ logout button แสดง', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();
      expect(find.text('ออกจากระบบ'), findsOneWidget);
    });

    testWidgets('shop open time จาก fixture แสดง', (tester) async {
      await tester.pumpWidget(_screen());
      await tester.pump();
      expect(find.textContaining('09:00'), findsWidgets);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Contrast tests
  // ──────────────────────────────────────────────────────────────────────────

  group('MerchantSettingsScreen — คอนทราสต์ ≥ 4.5:1', () {
    double luminance(Color c) {
      final r = c.r;
      final g = c.g;
      final b = c.b;
      double lin(double v) => v <= 0.04045
          ? v / 12.92
          : ((v + 0.055) / 1.055) * ((v + 0.055) / 1.055);
      return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
    }

    double contrastRatio(Color fg, Color bg) {
      final lFg = luminance(fg);
      final lBg = luminance(bg);
      final lighter = lFg > lBg ? lFg : lBg;
      final darker = lFg < lBg ? lFg : lBg;
      return (lighter + 0.05) / (darker + 0.05);
    }

    for (final dark in [false, true]) {
      testWidgets(
          '${dark ? 'โหมดมืด' : 'โหมดสว่าง'} — สีข้อความที่ render บน AppBar และ card',
          (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_screen(dark: dark));
        await tester.pump();

        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        final title = tester.widget<Text>(find.text('ตั้งค่าร้าน'));
        expect(contrastRatio(title.style!.color!, appBar.backgroundColor!),
            greaterThanOrEqualTo(4.5));

        final cardTitle = find.text('ข้อมูลร้านค้า');
        final cardText = tester.widget<Text>(cardTitle);
        final card = tester.widget<Container>(
          find.ancestor(of: cardTitle, matching: find.byType(Container)).first,
        );
        final cardColor = (card.decoration! as BoxDecoration).color!;
        expect(contrastRatio(cardText.style!.color!, cardColor),
            greaterThanOrEqualTo(4.5));
      });
    }
  });
}
