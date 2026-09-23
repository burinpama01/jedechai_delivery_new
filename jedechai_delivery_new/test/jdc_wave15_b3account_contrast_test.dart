import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/rewards/referral_screen.dart';
import 'package:jedechai_delivery_new/common/providers/language_provider.dart';
import 'package:jedechai_delivery_new/l10n/app_localizations.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import 'package:jedechai_delivery_new/theme/jdc_colors.dart';
import 'package:jedechai_delivery_new/utils/connection_helper.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

double _contrast(Color a, Color b) {
  final light = a.computeLuminance() > b.computeLuminance() ? a : b;
  final dark = identical(light, a) ? b : a;
  return (light.computeLuminance() + 0.05) / (dark.computeLuminance() + 0.05);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.testLoad(fileInput: 'SUPABASE_URL=https://test.invalid\nSUPABASE_ANON_KEY=test-anon-key');
    SharedPreferences.setMockInitialValues(const {});
    await Supabase.initialize(url: 'https://test.invalid', anonKey: 'test-anon-key');
  });

  for (final dark in [false, true]) {
    testWidgets('ปุ่มใช้โค้ดอ่านได้ในโหมด${dark ? 'มืด' : 'สว่าง'}', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ChangeNotifierProvider(
        create: (_) => LanguageProvider(),
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: dark ? ThemeMode.dark : ThemeMode.light,
          locale: const Locale('th'),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: const ReferralScreen(),
        ),
      ));
      await tester.pump();
      final button = tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'ใช้โค้ด'));
      final bg = button.style!.backgroundColor!.resolve({})!;
      final fg = button.style!.foregroundColor!.resolve({})!;
      expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5));
      final loadingBg = button.style!.backgroundColor!.resolve({WidgetState.disabled})!;
      expect(_contrast(fg, loadingBg), greaterThanOrEqualTo(3));
    });
    testWidgets('ปุ่มลองอีกครั้งอ่านได้ในโหมด${dark ? 'มืด' : 'สว่าง'}', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        locale: const Locale('th'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: ConnectionHelper.buildErrorWidget(
          error: 'offline', onRetry: () {}, title: 'Error')),
      ));
      final button = tester.widget<ElevatedButton>(find.byWidgetPredicate(
        (widget) => widget is ElevatedButton));
      final bg = button.style!.backgroundColor!.resolve({})!;
      final fg = button.style!.foregroundColor!.resolve({})!;
      expect(_contrast(fg, bg), greaterThanOrEqualTo(4.5));
      final detail = tester.widget<Text>(find.text(ConnectionHelper.getErrorMessage('offline')));
      final paper = dark ? JdcColors.dark.paper : JdcColors.light.paper;
      expect(_contrast(detail.style!.color!, paper), greaterThanOrEqualTo(4.5));
    });
  }
}
