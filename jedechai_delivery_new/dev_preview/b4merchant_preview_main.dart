// Dev-only Wave 1.5 preview for merchant b4 artboards.
// เลือกหน้าด้วย ?screen=Dashboard|MenuCategories|Menu
// หน้าร้านค้าต้อง login จึงใช้ fixture ผ่าน optional constructor parameter
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/merchant_dashboard_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/menu/merchant_menu_categories_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/menu_management_screen.dart';
import 'package:jedechai_delivery_new/common/config/env_config.dart';
import 'package:jedechai_delivery_new/common/providers/language_provider.dart';
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
  final params = Uri.base.queryParameters;
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      builder: jdcTextScaleGuard,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: params['theme'] == 'dark' ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(params['lang'] ?? 'th'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: _PreviewScreen(screen: params['screen'] ?? 'Dashboard'),
    ),
  ));
}

// ── Fixture data ──────────────────────────────────────────────────────────────

final _now = DateTime.now();

/// Fixture สำหรับ Dashboard
MerchantDashboardFixture _dashboardFixture() {
  final days = List.generate(7, (i) {
    final date = DateTime(_now.year, _now.month, _now.day)
        .subtract(Duration(days: 6 - i));
    final revenues = [4200.0, 5800.0, 4600.0, 7200.0, 6900.0, 7500.0, 5060.0];
    return DailySalesPoint(date: date, revenue: revenues[i], orders: (revenues[i] / 160).ceil());
  });
  return MerchantDashboardFixture(
    shopName: 'ครัวป้าน้อย',
    grossRevenue: 6420,
    totalRevenue: 5264,
    systemGP: 1156,
    vsLastPeriod: 12.0,
    totalOrders: 42,
    completedOrders: 38,
    cancelledOrders: 4,
    avgOrderValue: 138.5,
    merchantSystemRate: 0.18,
    merchantDriverRate: 0.0,
    deliverySystemRate: 0.02,
    salesChart: days,
    topItems: const [
      TopItemReport(name: 'ข้าวกะเพราหมูสับ', orderCount: 42, revenue: 2730),
      TopItemReport(name: 'ชาเย็นสูตรร้าน', orderCount: 31, revenue: 1085),
      TopItemReport(name: 'ข้าวผัดอเมริกัน', orderCount: 18, revenue: 1530),
    ],
    orderHistory: [
      {
        'id': 'aaa-001',
        'status': 'completed',
        'price': 110.0,
        'delivery_fee': 25.0,
        'created_at': _now.subtract(const Duration(hours: 1)).toIso8601String(),
        'updated_at': _now.subtract(const Duration(hours: 1)).toIso8601String(),
        'notes': 'ข้าวกะเพรา + ชาเย็น',
        'service_type': 'food',
        'customer_id': 'cust-001',
      },
      {
        'id': 'aaa-002',
        'status': 'completed',
        'price': 85.0,
        'delivery_fee': 30.0,
        'created_at': _now.subtract(const Duration(hours: 2)).toIso8601String(),
        'updated_at': _now.subtract(const Duration(hours: 2)).toIso8601String(),
        'notes': null,
        'service_type': 'food',
        'customer_id': 'cust-002',
      },
      {
        'id': 'aaa-003',
        'status': 'cancelled',
        'price': 65.0,
        'delivery_fee': 20.0,
        'created_at': _now.subtract(const Duration(hours: 3)).toIso8601String(),
        'updated_at': _now.subtract(const Duration(hours: 3)).toIso8601String(),
        'notes': 'ยกเลิกโดยลูกค้า',
        'service_type': 'food',
        'customer_id': 'cust-003',
      },
    ],
  );
}

/// Fixture สำหรับ MenuCategories
List<Map<String, dynamic>> _categoriesFixture() => [
  {'id': 'cat-1', 'name': 'อาหารตามสั่ง', 'sort_order': 0, 'is_active': true, 'merchant_id': 'demo'},
  {'id': 'cat-2', 'name': 'ก๋วยเตี๋ยว',   'sort_order': 1, 'is_active': true, 'merchant_id': 'demo'},
  {'id': 'cat-3', 'name': 'เครื่องดื่ม',  'sort_order': 2, 'is_active': true, 'merchant_id': 'demo'},
  {'id': 'cat-4', 'name': 'ของหวาน',      'sort_order': 3, 'is_active': true, 'merchant_id': 'demo'},
  {'id': 'cat-5', 'name': 'ฟาสต์ฟู้ด',   'sort_order': 4, 'is_active': true, 'merchant_id': 'demo'},
  {'id': 'cat-6', 'name': 'อื่นๆ',        'sort_order': 5, 'is_active': false,'merchant_id': 'demo'},
];

/// Fixture สำหรับ Menu
List<Map<String, dynamic>> _menuFixture() => [
  {
    'id': 'item-1', 'name': 'ข้าวกะเพราหมูสับ', 'category': 'อาหารตามสั่ง',
    'price': 55.0, 'is_available': true, 'merchant_id': 'demo',
    'description': '3 ตัวเลือกเสริม · ขายดี', 'image_url': null,
  },
  {
    'id': 'item-2', 'name': 'ข้าวกะเพราหมูสับไข่ดาว', 'category': 'อาหารตามสั่ง',
    'price': 65.0, 'is_available': true, 'merchant_id': 'demo',
    'description': '3 ตัวเลือกเสริม', 'image_url': null,
  },
  {
    'id': 'item-3', 'name': 'ข้าวผัดอเมริกัน', 'category': 'อาหารตามสั่ง',
    'price': 85.0, 'is_available': true, 'merchant_id': 'demo',
    'description': '2 ตัวเลือกเสริม', 'image_url': null,
  },
  {
    'id': 'item-4', 'name': 'ข้าวหมูกรอบ', 'category': 'อาหารตามสั่ง',
    'price': 70.0, 'is_available': false, 'merchant_id': 'demo',
    'description': 'ของหมด · ซ่อนจากลูกค้า', 'image_url': null,
  },
  {
    'id': 'item-5', 'name': 'ข้าวไข่เจียวหมูสับ', 'category': 'อาหารตามสั่ง',
    'price': 50.0, 'is_available': true, 'merchant_id': 'demo',
    'description': '1 ตัวเลือกเสริม', 'image_url': null,
  },
  {
    'id': 'item-6', 'name': 'ชาเย็นสูตรร้าน', 'category': 'เครื่องดื่ม',
    'price': 35.0, 'is_available': true, 'merchant_id': 'demo',
    'description': null, 'image_url': null,
  },
  {
    'id': 'item-7', 'name': 'โอเลี้ยง', 'category': 'เครื่องดื่ม',
    'price': 25.0, 'is_available': true, 'merchant_id': 'demo',
    'description': null, 'image_url': null,
  },
];

// ── Preview Screen ─────────────────────────────────────────────────────────────

/// หน้าที่ต้อง login: ส่ง fixture ผ่าน optional constructor parameter
/// ไม่กระทบ production path เพราะ parameter มี default null
class _PreviewScreen extends StatelessWidget {
  final String screen;
  const _PreviewScreen({required this.screen});

  @override
  Widget build(BuildContext context) => switch (screen) {
    'Dashboard' => MerchantDashboardScreen(
        fixtureData: _dashboardFixture(),
      ),
    'MenuCategories' => MerchantMenuCategoriesScreen(
        fixtureCategories: _categoriesFixture(),
      ),
    'Menu' => MenuManagementScreen(
        fixtureMenuItems: _menuFixture(),
      ),
    _ => Scaffold(
        body: Center(
          child: Text('Unknown preview screen: $screen'),
        ),
      ),
  };
}
