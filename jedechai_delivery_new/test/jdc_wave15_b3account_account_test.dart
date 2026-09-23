import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/apps/customer/providers/cart_provider.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/account_screen.dart';
import 'package:jedechai_delivery_new/common/providers/auth_provider.dart';
import 'package:jedechai_delivery_new/common/providers/language_provider.dart';
import 'package:jedechai_delivery_new/l10n/app_localizations.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import 'package:jedechai_delivery_new/theme/jdc_colors.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

double _contrast(Color a, Color b) {
  final aL = a.computeLuminance();
  final bL = b.computeLuminance();
  return (aL > bL ? aL + 0.05 : bL + 0.05) /
      (aL > bL ? bL + 0.05 : aL + 0.05);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.testLoad(fileInput: 'SUPABASE_URL=https://test.invalid\nSUPABASE_ANON_KEY=test-anon-key');
    SharedPreferences.setMockInitialValues(const {});
    await Supabase.initialize(url: 'https://test.invalid', anonKey: 'test-anon-key');
  });

  for (final dark in [false, true]) {
    testWidgets('บัญชีมีข้อมูลอ่านชัดในโหมด${dark ? 'มืด' : 'สว่าง'} 390x844', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => CartProvider()),
        ChangeNotifierProvider(create: (_) => LanguageProvider()),
      ],
      child: MaterialApp(
        theme: dark ? AppTheme.darkTheme : AppTheme.lightTheme,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        locale: const Locale('th'),
        supportedLocales: AppLocalizations.supportedLocales,
        home: const AccountScreen(previewProfile: {
          'full_name': 'ผู้ทดสอบหน้าบัญชีที่มีชื่อยาว',
          'phone_number': '081-234-5678',
        }),
      ),
    ));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('ผู้ทดสอบหน้าบัญชีที่มีชื่อยาว'), findsWidgets);
    expect(find.byIcon(Icons.edit_outlined), findsOneWidget);
    final gradientFinder = find.byWidgetPredicate(
      (widget) => widget is Container &&
          widget.decoration is BoxDecoration &&
          (widget.decoration! as BoxDecoration).gradient is LinearGradient,
    ).first;
    final phone = tester.widget<Text>(find.descendant(
      of: gradientFinder, matching: find.text('081-234-5678')));
    final gradientContainer = tester.widget<Container>(gradientFinder);
    final gradient = (gradientContainer.decoration! as BoxDecoration).gradient! as LinearGradient;
    for (final stopColor in gradient.colors) {
      expect(_contrast(phone.style!.color!, stopColor), greaterThanOrEqualTo(4.5));
    }
    final camera = tester.widget<Icon>(find.byIcon(Icons.camera_alt));
    final brand = dark ? JdcColors.dark.brand : JdcColors.light.brand;
    expect(_contrast(camera.color!, brand), greaterThanOrEqualTo(3));
    final jdc = dark ? JdcColors.dark : JdcColors.light;
    final language = tester.widget<DropdownButton<String>>(find.byType(DropdownButton<String>));
    expect(language.iconEnabledColor, jdc.onPanel);
    final selectedLanguage = tester.widget<Text>(find.text('ระบบ'));
    expect(_contrast(selectedLanguage.style!.color!, jdc.panel), greaterThanOrEqualTo(4.5));
    expect(tester.takeException(), isNull);
  });
  }
}
