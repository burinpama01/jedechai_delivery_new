// Dev-only Wave 1.5 preview for merchant b5 artboards.
// เลือกหน้าด้วย ?screen=OptionLibrary|Coupons|GpPlan|Settings|Profile|ForgotPassword
// หน้าเหล่านี้ต้อง login จึงใช้ fixture ผ่าน optional constructor parameter
// ไม่กระทบ production เพราะ parameter default null
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/auth/forgot_password_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/menu/merchant_option_library_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/merchant_coupon_management_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/merchant_gp_plan_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/merchant_settings_screen.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/profile/merchant_profile_screen.dart';
import 'package:jedechai_delivery_new/common/config/env_config.dart';
import 'package:jedechai_delivery_new/common/models/coupon.dart';
import 'package:jedechai_delivery_new/common/models/menu_option.dart';
import 'package:jedechai_delivery_new/common/providers/language_provider.dart';
import 'package:jedechai_delivery_new/common/services/gp_plan_service.dart';
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
      home: _SizedPreview(screen: params['screen'] ?? 'OptionLibrary'),
    ),
  ));
}

// ── Fixture data ──────────────────────────────────────────────────────────────

final _now = DateTime.now();

/// Fixture สำหรับ OptionLibrary
List<MenuOptionGroup> _optionGroupsFixture() {
  MenuOption mkOpt(String gid, String id, String name, int price) => MenuOption(
        id: id,
        groupId: gid,
        name: name,
        price: price,
        isAvailable: true,
        createdAt: _now,
        updatedAt: _now,
      );

  final g1 = MenuOptionGroup(
    id: 'grp-1',
    merchantId: 'demo',
    name: 'ระดับความเผ็ด',
    minSelection: 1,
    maxSelection: 1,
    createdAt: _now,
    updatedAt: _now,
  );
  g1.options = [
    mkOpt('grp-1', 'opt-1-1', 'ไม่เผ็ด', 0),
    mkOpt('grp-1', 'opt-1-2', 'เผ็ดน้อย', 0),
    mkOpt('grp-1', 'opt-1-3', 'เผ็ดกลาง', 0),
    mkOpt('grp-1', 'opt-1-4', 'เผ็ดมาก', 0),
  ];

  final g2 = MenuOptionGroup(
    id: 'grp-2',
    merchantId: 'demo',
    name: 'เพิ่มไข่ดาว',
    minSelection: 0,
    maxSelection: 2,
    createdAt: _now,
    updatedAt: _now,
  );
  g2.options = [
    mkOpt('grp-2', 'opt-2-1', 'ไข่ดาว', 10),
    mkOpt('grp-2', 'opt-2-2', 'ไข่เจียว', 15),
  ];

  final g3 = MenuOptionGroup(
    id: 'grp-3',
    merchantId: 'demo',
    name: 'ระดับความหวาน',
    minSelection: 1,
    maxSelection: 1,
    createdAt: _now,
    updatedAt: _now,
  );
  g3.options = [
    mkOpt('grp-3', 'opt-3-1', 'หวานน้อย', 0),
    mkOpt('grp-3', 'opt-3-2', 'หวานปกติ', 0),
    mkOpt('grp-3', 'opt-3-3', 'ไม่ใส่น้ำตาล', 0),
  ];

  final g4 = MenuOptionGroup(
    id: 'grp-4',
    merchantId: 'demo',
    name: 'ท็อปปิ้งเครื่องดื่ม',
    minSelection: 0,
    maxSelection: 3,
    createdAt: _now,
    updatedAt: _now,
  );
  g4.options = [
    mkOpt('grp-4', 'opt-4-1', 'มุก', 10),
    mkOpt('grp-4', 'opt-4-2', 'เยลลี่', 10),
    mkOpt('grp-4', 'opt-4-3', 'วิปครีม', 15),
  ];

  return [g1, g2, g3, g4];
}

/// Fixture สำหรับ Coupons
List<Coupon> _couponsFixture() => [
      Coupon(
        id: 'coup-1',
        code: 'DISCOUNT20',
        name: 'ลด 20 บาท',
        discountType: 'fixed',
        discountValue: 20,
        minOrderAmount: 150,
        usageLimit: 200,
        usedCount: 46,
        isActive: true,
        createdByRole: 'merchant',
        endDate: DateTime(_now.year, 9, 30),
        createdAt: _now.subtract(const Duration(days: 30)),
      ),
      Coupon(
        id: 'coup-2',
        code: 'NEWUSER10',
        name: 'ลด 10%',
        discountType: 'percentage',
        discountValue: 10,
        maxDiscountAmount: 50,
        description: 'เฉพาะลูกค้าใหม่',
        usageLimit: 100,
        usedCount: 12,
        isActive: true,
        createdByRole: 'merchant',
        endDate: DateTime(_now.year + 1, 1, 31),
        createdAt: _now.subtract(const Duration(days: 14)),
      ),
      Coupon(
        id: 'coup-3',
        code: 'FREEMON',
        name: 'ส่งฟรีวันจันทร์',
        discountType: 'free_delivery',
        discountValue: 0,
        usageLimit: 88,
        usedCount: 88,
        isActive: false,
        createdByRole: 'merchant',
        endDate: DateTime(_now.year, 9, 15),
        createdAt: _now.subtract(const Duration(days: 60)),
      ),
    ];

/// Fixture สำหรับ GpPlan — แผน GP มาตรฐาน (ไม่มี live data)
List<Map<String, dynamic>> _gpPlansFixture() => [
      {
        'id': 'plan-standard',
        'name': 'มาตรฐาน · GP 18%',
        'gp_rate': 0.18,
        'base_delivery_fee': 25,
        'base_distance_km': 3,
        'per_km_charge': 8,
        'description': 'ไม่มีค่าแรกเข้า · อยู่ในหน้าแนะนำร้านตามปกติ · รองรับคูปองส่วนกลาง',
      },
      {
        'id': 'plan-promote',
        'name': 'โปรโมท · GP 23%',
        'gp_rate': 0.23,
        'base_delivery_fee': 25,
        'base_distance_km': 3,
        'per_km_charge': 8,
        'description': 'ปักหมุดร้านในหน้าแรก 1 ช่วงต่อวัน · ร่วมแคมเปญส่งฟรีของ JDC อัตโนมัติ',
      },
    ];

GpPlanStatus _gpStatusFixture() => GpPlanStatus(
      planId: 'plan-standard',
      approvalStatus: 'approved',
      isCustomDeal: false,
      canChange: true,
      blockedReason: null,
      nextChangeAt: null,
      hasActiveOrders: false,
      cooldownDays: 30,
      clockOffset: Duration.zero,
      gpRate: 0.18,
      baseFare: 25,
      baseDistanceKm: 3,
      perKm: 8,
    );

// ── Sized wrapper — บังคับ MediaQuery ให้ 390x844 เพื่อให้ Chrome headless จับภาพถูก ──

class _SizedPreview extends StatelessWidget {
  final String screen;
  const _SizedPreview({required this.screen});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: 390,
          height: 844,
          child: MediaQuery(
            data: const MediaQueryData(size: Size(390, 844)),
            child: _PreviewScreen(screen: screen),
          ),
        ),
      ),
    );
  }
}

// ── Preview Screen ─────────────────────────────────────────────────────────────

class _PreviewScreen extends StatelessWidget {
  final String screen;
  const _PreviewScreen({required this.screen});

  @override
  Widget build(BuildContext context) => switch (screen) {
        'OptionLibrary' => MerchantOptionLibraryScreen(
            merchantId: 'demo',
            fixtureGroups: _optionGroupsFixture(),
          ),
        'Coupons' => MerchantCouponManagementScreen(
            fixtureCoupons: _couponsFixture(),
          ),
        'GpPlan' => MerchantGpPlanScreen(
            fixturePlans: _gpPlansFixture(),
            fixtureStatus: _gpStatusFixture(),
          ),
        // b5merchant batch 2 screens — ต้องการ auth session จริง
        // (merchant_settings + merchant_profile ใช้ ProfileService ดึงข้อมูลจาก Supabase)
        'Settings' => const MerchantSettingsScreen(),
        'Profile' => const MerchantProfileScreen(),
        'ForgotPassword' => const ForgotPasswordScreen(),
        _ => Scaffold(
            body: Center(
              child: Text('Unknown preview screen: $screen'),
            ),
          ),
      };
}
