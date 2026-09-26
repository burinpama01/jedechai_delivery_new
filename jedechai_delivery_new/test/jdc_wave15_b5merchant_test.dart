// Wave 1.5 b5merchant widget tests
// ทดสอบ 3 หน้า: MerchantOptionLibraryScreen, MerchantCouponManagementScreen, MerchantGpPlanScreen
// ขนาด: 390x844, 360x640, 834x1112, 844x390 + โหมดมืด + contrast ≥4.5:1
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/menu/merchant_option_library_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/merchant_coupon_management_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/merchant_gp_plan_screen.dart';
import 'package:jedechai_delivery_new/common/models/coupon.dart';
import 'package:jedechai_delivery_new/common/models/menu_option.dart';
import 'package:jedechai_delivery_new/common/services/gp_plan_service.dart';
import 'package:jedechai_delivery_new/l10n/app_localizations.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

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

double _luminance(Color c) {
  double linearize(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * linearize(c.r) +
      0.7152 * linearize(c.g) +
      0.0722 * linearize(c.b);
}

double _contrast(Color fg, Color bg) {
  final lf = _luminance(fg);
  final lb = _luminance(bg);
  final lighter = math.max(lf, lb);
  final darker = math.min(lf, lb);
  return (lighter + 0.05) / (darker + 0.05);
}

// ────────────────────────────────────────────────────────────────────────────
// Fixtures
// ────────────────────────────────────────────────────────────────────────────

final _now = DateTime.now();

List<MenuOptionGroup> _optGroups() {
  MenuOption mkOpt(String gid, String id, String name, int price) => MenuOption(
        id: id, groupId: gid, name: name, price: price,
        isAvailable: true, createdAt: _now, updatedAt: _now);

  final g1 = MenuOptionGroup(
    id: 'g1', merchantId: 'demo', name: 'ระดับความเผ็ด',
    minSelection: 1, maxSelection: 1, createdAt: _now, updatedAt: _now);
  g1.options = [mkOpt('g1','o1','ไม่เผ็ด',0), mkOpt('g1','o2','เผ็ดน้อย',0),
                mkOpt('g1','o3','เผ็ดกลาง',0), mkOpt('g1','o4','เผ็ดมาก',0)];

  final g2 = MenuOptionGroup(
    id: 'g2', merchantId: 'demo', name: 'เพิ่มไข่ดาว',
    minSelection: 0, maxSelection: 2, createdAt: _now, updatedAt: _now);
  g2.options = [mkOpt('g2','o5','ไข่ดาว',10), mkOpt('g2','o6','ไข่เจียว',15)];

  final g3 = MenuOptionGroup(
    id: 'g3', merchantId: 'demo', name: 'ท็อปปิ้งเครื่องดื่ม',
    minSelection: 0, maxSelection: 3, createdAt: _now, updatedAt: _now);
  g3.options = [mkOpt('g3','o7','มุก',10), mkOpt('g3','o8','เยลลี่',10),
                mkOpt('g3','o9','วิปครีม',15)];
  return [g1, g2, g3];
}

List<Coupon> _coupons() => [
  Coupon(id: 'c1', code: 'DISC20', name: 'ลด 20 บาท',
    discountType: 'fixed', discountValue: 20, minOrderAmount: 150,
    usageLimit: 200, usedCount: 46, isActive: true,
    createdByRole: 'merchant',
    endDate: DateTime(_now.year + 1, 9, 30), createdAt: _now),
  Coupon(id: 'c2', code: 'PCNT10', name: 'ลด 10%',
    discountType: 'percentage', discountValue: 10, maxDiscountAmount: 50,
    usageLimit: 100, usedCount: 12, isActive: true,
    createdByRole: 'merchant',
    endDate: DateTime(_now.year + 1, 1, 31), createdAt: _now),
  Coupon(id: 'c3', code: 'FREEMON', name: 'ส่งฟรีวันจันทร์',
    discountType: 'free_delivery', discountValue: 0,
    usageLimit: 88, usedCount: 88, isActive: false,
    createdByRole: 'merchant',
    endDate: _now.subtract(const Duration(days: 10)), createdAt: _now),
];

List<Map<String, dynamic>> _gpPlans() => [
  {'id': 'p1', 'name': 'มาตรฐาน · GP 18%', 'gp_rate': 0.18,
   'base_delivery_fee': 25, 'base_distance_km': 3, 'per_km_charge': 8,
   'description': 'ไม่มีค่าแรกเข้า · รองรับคูปองส่วนกลาง'},
  {'id': 'p2', 'name': 'โปรโมท · GP 23%', 'gp_rate': 0.23,
   'base_delivery_fee': 25, 'base_distance_km': 3, 'per_km_charge': 8,
   'description': 'ปักหมุดร้านในหน้าแรก 1 ช่วงต่อวัน'},
];

GpPlanStatus _gpStatus() => GpPlanStatus(
  planId: 'p1', approvalStatus: 'approved', isCustomDeal: false,
  canChange: true, blockedReason: null, nextChangeAt: null,
  hasActiveOrders: false, cooldownDays: 30, clockOffset: Duration.zero,
  gpRate: 0.18, baseFare: 25, baseDistanceKm: 3, perKm: 8);

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
  // MerchantOptionLibraryScreen
  // ──────────────────────────────────────────────────────────────────────────

  group('MerchantOptionLibraryScreen', () {
    Widget screen() => MerchantOptionLibraryScreen(
        merchantId: 'demo', fixtureGroups: _optGroups());

    for (final sz in [
      const Size(390, 844), const Size(360, 640),
      const Size(834, 1112), const Size(844, 390),
    ]) {
      testWidgets('${sz.width.toInt()}x${sz.height.toInt()} สว่าง — ไม่ overflow', (tester) async {
        tester.view.physicalSize = sz;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_wrap(screen(), size: sz));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('โหมดมืด 390x844 — ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(screen(), dark: true));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('แสดงชื่อกลุ่มตัวเลือกจาก fixture', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(screen()));
      await tester.pump();
      expect(find.text('ระดับความเผ็ด'), findsOneWidget);
      expect(find.text('เพิ่มไข่ดาว'), findsOneWidget);
    });

    testWidgets('contrast ข้อความหลัก ≥4.5:1 โหมดสว่าง', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(screen()));
      await tester.pump();
      final theme = AppTheme.lightTheme;
      final bg = theme.colorScheme.surface;
      final fg = theme.colorScheme.onSurface;
      expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5));
    });

    testWidgets('contrast ข้อความหลัก ≥4.5:1 โหมดมืด', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(screen(), dark: true));
      await tester.pump();
      final theme = AppTheme.darkTheme;
      final bg = theme.colorScheme.surface;
      final fg = theme.colorScheme.onSurface;
      expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // MerchantCouponManagementScreen
  // ──────────────────────────────────────────────────────────────────────────

  group('MerchantCouponManagementScreen', () {
    Widget screen() => MerchantCouponManagementScreen(fixtureCoupons: _coupons());

    for (final sz in [
      const Size(390, 844), const Size(360, 640),
      const Size(834, 1112), const Size(844, 390),
    ]) {
      testWidgets('${sz.width.toInt()}x${sz.height.toInt()} สว่าง — ไม่ overflow', (tester) async {
        tester.view.physicalSize = sz;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_wrap(screen(), size: sz));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('โหมดมืด 390x844 — ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(screen(), dark: true));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('แสดง coupon card จาก fixture', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(screen()));
      await tester.pump();
      expect(find.text('ลด 20 บาท'), findsOneWidget);
      expect(find.text('ลด 10%'), findsOneWidget);
      expect(find.text('ส่งฟรีวันจันทร์'), findsOneWidget);
    });

    testWidgets('แสดง status badge กำลังใช้งาน/หมดอายุ', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(screen()));
      await tester.pump();
      expect(find.text('กำลังใช้งาน'), findsNWidgets(2));
      expect(find.text('หมดอายุ'), findsOneWidget);
    });

    testWidgets('เงื่อนไขคูปองแสดงวันหมดอายุได้สองบรรทัด', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(screen()));
      await tester.pump();
      final condition = tester.widget<Text>(find.textContaining('ซื้อครบ ฿150'));
      expect(condition.data, contains('30/09'));
      expect(condition.maxLines, 2);
      expect(tester.takeException(), isNull);
    });

    for (final dark in [false, true]) {
      testWidgets('แบนเนอร์ข้อมูลคอนทราสต์จากสีที่ render ${dark ? 'มืด' : 'สว่าง'}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_wrap(screen(), dark: dark));
        await tester.pump();
        final noteFinder = find.textContaining('คูปองส่งฟรีของร้าน');
        final note = tester.widget<Text>(noteFinder);
        final banner = tester.widget<Container>(
          find.ancestor(of: noteFinder, matching: find.byType(Container)).first,
        );
        final background = (banner.decoration! as BoxDecoration).color!;
        expect(_contrast(note.style!.color!, background), greaterThanOrEqualTo(4.5));
      });
    }

    testWidgets('contrast ข้อความหลัก ≥4.5:1 โหมดสว่าง', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(screen()));
      await tester.pump();
      final theme = AppTheme.lightTheme;
      final bg = theme.colorScheme.surface;
      final fg = theme.colorScheme.onSurface;
      expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5));
    });

    testWidgets('contrast ข้อความหลัก ≥4.5:1 โหมดมืด', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(screen(), dark: true));
      await tester.pump();
      final theme = AppTheme.darkTheme;
      final bg = theme.colorScheme.surface;
      final fg = theme.colorScheme.onSurface;
      expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5));
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // MerchantGpPlanScreen
  // ──────────────────────────────────────────────────────────────────────────

  group('MerchantGpPlanScreen', () {
    Widget screen() => MerchantGpPlanScreen(
        fixturePlans: _gpPlans(), fixtureStatus: _gpStatus());

    for (final sz in [
      const Size(390, 844), const Size(360, 640),
      const Size(834, 1112), const Size(844, 390),
    ]) {
      testWidgets('${sz.width.toInt()}x${sz.height.toInt()} สว่าง — ไม่ overflow', (tester) async {
        tester.view.physicalSize = sz;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_wrap(screen(), size: sz));
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('โหมดมืด 390x844 — ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(screen(), dark: true));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('แสดงชื่อแผนจาก fixture', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(screen()));
      await tester.pump();
      expect(find.text('มาตรฐาน · GP 18%'), findsWidgets);
      expect(find.text('โปรโมท · GP 23%'), findsOneWidget);
    });

    testWidgets('contrast ข้อความหลัก ≥4.5:1 โหมดสว่าง', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(screen()));
      await tester.pump();
      final theme = AppTheme.lightTheme;
      final bg = theme.colorScheme.surface;
      final fg = theme.colorScheme.onSurface;
      expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5));
    });

    testWidgets('contrast ข้อความหลัก ≥4.5:1 โหมดมืด', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(screen(), dark: true));
      await tester.pump();
      final theme = AppTheme.darkTheme;
      final bg = theme.colorScheme.surface;
      final fg = theme.colorScheme.onSurface;
      expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5));
    });
  });
}
