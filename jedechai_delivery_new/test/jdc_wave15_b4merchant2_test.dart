// Wave 1.5 b4merchant batch-2 widget tests
// ทดสอบ 3 หน้า: MerchantOrderDetailScreen, MerchantLaundryScreen, MerchantAddEditMenuScreen
// ขนาด: 390x844, 360x640, 834x1112, 844x390 (แนวนอน) + โหมดมืด
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/order_detail_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/merchant_laundry_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/menu/merchant_add_edit_menu_screen.dart';
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

// Fixture data
final _now = DateTime.now();

Map<String, dynamic> _orderFixture({String status = 'pending_merchant'}) => {
  'id': 'ord-test-001',
  'status': status,
  'price': 160.0,
  'delivery_fee': 30.0,
  'created_at': _now.subtract(const Duration(minutes: 2)).toIso8601String(),
  'updated_at': _now.subtract(const Duration(minutes: 2)).toIso8601String(),
  'notes': 'เผ็ดน้อยนะคะ',
  'service_type': 'food',
  'customer_id': 'cust-test-001',
  'merchant_id': 'merch-test-001',
  'driver_id': null,
  'payment_method': 'wallet',
};

Map<String, dynamic> _menuItemFixture() => {
  'id': 'item-test-001',
  'name': 'ข้าวกะเพราหมูสับ',
  'description': 'สูตรเด็ด ปรุงสดทุกจาน',
  'price': 55.0,
  'prep_time_minutes': 15,
  'category': 'อาหารตามสั่ง',
  'category_id': 'cat-1',
  'is_available': true,
  'image_url': null,
  'merchant_id': 'merch-test-001',
};

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
  // MerchantOrderDetailScreen
  // ──────────────────────────────────────────────────────────────────────────

  group('MerchantOrderDetailScreen', () {
    testWidgets('390x844 pending — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(MerchantOrderDetailScreen(
        order: _orderFixture(),
        loadRemoteData: false,
        enableRealtimeListener: false,
        enableAutoRefresh: false,
      )));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('360x640 pending — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(
        MerchantOrderDetailScreen(
          order: _orderFixture(),
          loadRemoteData: false,
          enableRealtimeListener: false,
          enableAutoRefresh: false,
        ),
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
        MerchantOrderDetailScreen(
          order: _orderFixture(),
          loadRemoteData: false,
          enableRealtimeListener: false,
          enableAutoRefresh: false,
        ),
        size: const Size(834, 1112),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('844x390 landscape — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(
        MerchantOrderDetailScreen(
          order: _orderFixture(),
          loadRemoteData: false,
          enableRealtimeListener: false,
          enableAutoRefresh: false,
        ),
        size: const Size(844, 390),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('dark mode — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(
        MerchantOrderDetailScreen(
          order: _orderFixture(),
          loadRemoteData: false,
          enableRealtimeListener: false,
          enableAutoRefresh: false,
        ),
        dark: true,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('390x844 preparing status — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(MerchantOrderDetailScreen(
        order: _orderFixture(status: 'preparing'),
        loadRemoteData: false,
        enableRealtimeListener: false,
        enableAutoRefresh: false,
      )));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // MerchantLaundryScreen
  // ──────────────────────────────────────────────────────────────────────────

  group('MerchantLaundryScreen', () {
    testWidgets('390x844 โหมดสว่าง — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(const MerchantLaundryScreen()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('360x640 โหมดสว่าง — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(
        const MerchantLaundryScreen(),
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
        const MerchantLaundryScreen(),
        size: const Size(834, 1112),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('844x390 landscape — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(
        const MerchantLaundryScreen(),
        size: const Size(844, 390),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('dark mode — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(
        const MerchantLaundryScreen(),
        dark: true,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // MerchantAddEditMenuScreen
  // ──────────────────────────────────────────────────────────────────────────

  group('MerchantAddEditMenuScreen', () {
    testWidgets('390x844 Add mode — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(const MerchantAddEditMenuScreen()));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('390x844 Edit mode — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(MerchantAddEditMenuScreen(
        item: _menuItemFixture(),
      )));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('360x640 Add mode — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(
        const MerchantAddEditMenuScreen(),
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
        const MerchantAddEditMenuScreen(),
        size: const Size(834, 1112),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('844x390 landscape — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(
        const MerchantAddEditMenuScreen(),
        size: const Size(844, 390),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });

    testWidgets('dark mode — render ไม่ overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(
        const MerchantAddEditMenuScreen(),
        dark: true,
      ));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  });
}
