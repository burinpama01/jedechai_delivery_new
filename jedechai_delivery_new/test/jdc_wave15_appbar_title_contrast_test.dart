import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/saved_addresses_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/support_tickets_screen.dart';
import 'package:jedechai_delivery_new/common/providers/language_provider.dart';
import 'package:jedechai_delivery_new/l10n/app_localizations.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

// AppBar พื้นสว่าง (jdc.surface) ต้องไม่ใช้ titleTextStyle สีขาวจาก theme
// (บั๊กเดิม: foregroundColor ถูก theme.titleTextStyle ทับ → ชื่อหน้าขาวบนขาว)
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    dotenv.testLoad(fileInput: 'SUPABASE_URL=https://test.invalid\nSUPABASE_ANON_KEY=test-anon-key');
    SharedPreferences.setMockInitialValues(const {});
    await Supabase.initialize(url: 'https://test.invalid', anonKey: 'test-anon-key');
  });

  final screens = <String, Widget Function()>{
    'SupportTickets': () => const SupportTicketsScreen(),
    'SavedAddresses': () => const SavedAddressesScreen(),
  };

  for (final dark in [false, true]) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} ชื่อหน้าอ่านได้ในโหมด${dark ? 'มืด' : 'สว่าง'}', (tester) async {
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
            home: entry.value(),
          ),
        ));
        await tester.pump();
        final appBar = tester.widget<AppBar>(find.byType(AppBar));
        final title = find.descendant(
          of: find.byType(AppBar),
          matching: find.byWidget(appBar.title!),
        );
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: title, matching: find.byType(RichText)).first,
        );
        final color = paragraph.text.style!.color!;
        expect(_contrast(color, appBar.backgroundColor!), greaterThanOrEqualTo(4.5));
      });
    }
  }
}
