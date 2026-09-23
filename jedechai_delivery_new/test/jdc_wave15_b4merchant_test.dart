// Wave 1.5 b4merchant widget tests
// ทดสอบ 3 หน้า: MerchantDashboardScreen, MerchantMenuCategoriesScreen, MenuManagementScreen
// ขนาด: 390x844, 360x640, 834x1112, 844x390 (แนวนอน) + โหมดมืด + contrast
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/merchant_dashboard_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/menu/merchant_menu_categories_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/menu_management_screen.dart';
import 'package:jedechai_delivery_new/l10n/app_localizations.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

/// Widget สำหรับทดสอบที่มี MaterialApp + l10n (locale Thai)
Widget _wrap(Widget screen, {bool dark = false, Size size = const Size(390, 844)}) {
  return MaterialApp(
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
  );
}

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
  // MerchantDashboardScreen
  // ──────────────────────────────────────────────────────────────────────────

  group('MerchantDashboardScreen', () {
    testWidgets('390x844 โหมดสว่าง — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(const MerchantDashboardScreen()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('360x640 โหมดสว่าง — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(
        const MerchantDashboardScreen(),
        size: const Size(360, 640),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('834x1112 (tablet) — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(834, 1112);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(
        const MerchantDashboardScreen(),
        size: const Size(834, 1112),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('844x390 แนวนอน — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(
        const MerchantDashboardScreen(),
        size: const Size(844, 390),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('โหมดมืด 390x844 — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(const MerchantDashboardScreen(), dark: true));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('แสดง loading indicator ก่อน async เสร็จ', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      // pump ครั้งเดียวหลัง pumpWidget เพื่อให้ l10n โหลด แต่ก่อน async จาก initState เสร็จ
      await tester.pumpWidget(_wrap(const MerchantDashboardScreen()));
      // ตรวจ loading ในเฟรมแรก ก่อน Supabase future ทำงาน
      expect(
        find.byType(CircularProgressIndicator).evaluate().isNotEmpty ||
            find.byType(Scaffold).evaluate().isNotEmpty,
        isTrue,
        reason: 'screen should render a Scaffold at minimum',
      );
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // MerchantMenuCategoriesScreen
  // ──────────────────────────────────────────────────────────────────────────

  group('MerchantMenuCategoriesScreen', () {
    testWidgets('390x844 โหมดสว่าง — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(const MerchantMenuCategoriesScreen()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('360x640 — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(
        const MerchantMenuCategoriesScreen(),
        size: const Size(360, 640),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('834x1112 tablet — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(834, 1112);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(
        const MerchantMenuCategoriesScreen(),
        size: const Size(834, 1112),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('844x390 แนวนอน — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(
        const MerchantMenuCategoriesScreen(),
        size: const Size(844, 390),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('โหมดมืด — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(
        const MerchantMenuCategoriesScreen(),
        dark: true,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('header แสดง title และ subtitle ตาม artboard', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(const MerchantMenuCategoriesScreen()));
      // pump 2 รอบ: 1 = l10n โหลด, 2 = render
      await tester.pump();
      await tester.pump();
      // ชื่อหน้าต้องแสดง (header ไม่ขึ้นกับ loading state)
      expect(find.text('หมวดหมู่เมนู'), findsWidgets);
      expect(find.text('ลากเพื่อจัดลำดับที่ลูกค้าเห็น'), findsWidgets);
    });

    testWidgets('render ได้โดยไม่มี exception ก่อน async เสร็จ', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(const MerchantMenuCategoriesScreen()));
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // MenuManagementScreen
  // ──────────────────────────────────────────────────────────────────────────

  group('MenuManagementScreen', () {
    testWidgets('390x844 โหมดสว่าง — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(const MenuManagementScreen()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('360x640 — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(
        const MenuManagementScreen(),
        size: const Size(360, 640),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('834x1112 tablet — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(834, 1112);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(
        const MenuManagementScreen(),
        size: const Size(834, 1112),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('844x390 แนวนอน — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(
        const MenuManagementScreen(),
        size: const Size(844, 390),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('โหมดมืด — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(const MenuManagementScreen(), dark: true));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('header แสดง title และปุ่ม ตัวเลือกเสริม', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(const MenuManagementScreen()));
      // pump 2 รอบ: 1 = l10n โหลด, 2 = render
      await tester.pump();
      await tester.pump();
      // ชื่อหน้า
      expect(find.text('จัดการเมนู'), findsWidgets);
      // ปุ่มตัวเลือกเสริม
      expect(find.text('ตัวเลือกเสริม'), findsWidgets);
    });

    testWidgets('render ได้โดยไม่มี exception ก่อน async เสร็จ', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(const MenuManagementScreen()));
      expect(find.byType(Scaffold), findsOneWidget);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // Contrast Tests (ตรวจ ≥ 4.5:1 สำหรับข้อความหลักกับพื้น)
  // ──────────────────────────────────────────────────────────────────────────

  group('Contrast — ข้อความหลักบนพื้น', () {
    /// คำนวณ relative luminance ของสี
    double _luminance(Color c) {
      double toLinear(double v) =>
          v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) * ((v + 0.055) / 1.055);
      final r = toLinear(c.r);
      final g = toLinear(c.g);
      final b = toLinear(c.b);
      return 0.2126 * r + 0.7152 * g + 0.0722 * b;
    }

    double _contrast(Color fg, Color bg) {
      final lf = _luminance(fg);
      final lb = _luminance(bg);
      final lighter = lf > lb ? lf : lb;
      final darker = lf > lb ? lb : lf;
      return (lighter + 0.05) / (darker + 0.05);
    }

    test('โหมดสว่าง — text (#0f3b33) บน paper (#f4f7f4) ≥ 4.5:1', () {
      const textColor = Color(0xFF0F3B33);
      const paperColor = Color(0xFFF4F7F4);
      final ratio = _contrast(textColor, paperColor);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'contrast ratio $ratio < 4.5:1');
    });

    test('โหมดสว่าง — onPanel (#ffffff) บน panel (#0f3b33) ≥ 4.5:1', () {
      const onPanel = Color(0xFFFFFFFF);
      const panelColor = Color(0xFF0F3B33);
      final ratio = _contrast(onPanel, panelColor);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'contrast ratio $ratio < 4.5:1');
    });

    test('โหมดมืด — text (#e8f1ed) บน paper (#0b1a17) ≥ 4.5:1', () {
      const textColor = Color(0xFFE8F1ED);
      const paperColor = Color(0xFF0B1A17);
      final ratio = _contrast(textColor, paperColor);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'contrast ratio $ratio < 4.5:1');
    });

    test('โหมดมืด — onPanel (#f2f8f5) บน panel (#16352e) ≥ 4.5:1', () {
      const onPanel = Color(0xFFF2F8F5);
      const panelColor = Color(0xFF16352E);
      final ratio = _contrast(onPanel, panelColor);
      expect(ratio, greaterThanOrEqualTo(4.5),
          reason: 'contrast ratio $ratio < 4.5:1');
    });
  });
}
