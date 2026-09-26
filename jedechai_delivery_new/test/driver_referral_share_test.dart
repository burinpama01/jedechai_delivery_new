import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/rewards/referral_screen.dart';
import 'package:jedechai_delivery_new/apps/driver/screens/profile/driver_profile_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/auth/register_screen.dart';
import 'package:jedechai_delivery_new/l10n/app_localizations.dart';
import 'package:jedechai_delivery_new/common/providers/language_provider.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import 'package:qr_flutter/qr_flutter.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
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

  final summary = <String, dynamic>{
    'current_tier': 2,
    'current_multiplier': 1.25,
    'referrals_to_next_tier': 3,
    'successful_referrals': 8,
    'total_earned': 150,
    'pending_review': 0,
    'withdrawal_min': {'system': 200},
    'base': {
      'driver_invite_merchant': 40,
      'driver_invite_customer': 20,
      'driver_invite_driver_referrer': 60,
      'driver_invite_driver_newdriver': 15,
    },
    'tiers': [
      {'from': 1, 'to': 5, 'multiplier': 1.0},
      {'from': 6, 'to': 15, 'multiplier': 1.25},
      {'from': 16, 'to': null, 'multiplier': 1.5},
    ],
  };

  for (final brightness in <Brightness>[Brightness.light, Brightness.dark]) {
    testWidgets('driver referral shows both qualifying paths in $brightness',
        (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('th'),
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        themeMode:
            brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ReferralScreen(
          forDriver: true,
          referralCodeFixture: 'JDC12345',
          referralSummaryFixture: summary,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('JDC12345'), findsOneWidget);
      expect(find.text('ชวนร้านค้า'), findsOneWidget);
      expect(find.text('ชวนลูกค้า'), findsOneWidget);
      expect(find.text('ชวนคนขับ'), findsOneWidget);
      expect(find.textContaining('฿50'), findsWidgets);
      expect(find.textContaining('฿75'), findsWidgets);
      expect(find.textContaining('฿15'), findsWidgets);
      expect(find.textContaining('6–15'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final invalidCode in <String>['-', '   ']) {
    testWidgets('driver cannot share invalid code "$invalidCode"',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        locale: Locale('th'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ReferralScreen(
          forDriver: true,
          referralCodeFixture: invalidCode,
          referralSummaryFixture: const {},
        ),
      ));
      await tester.pumpAndSettle();
      final shareButton = tester.widget<ElevatedButton>(
        find.byWidgetPredicate((widget) => widget is ElevatedButton).first,
      );
      expect(shareButton.onPressed, isNull);
      expect(find.textContaining('คุณรับ ฿'), findsNothing);
      expect(find.textContaining('฿20'), findsNothing);
      expect(find.byType(QrImageView), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('driver referral QR contains the shareable code', (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('th'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ReferralScreen(
        forDriver: true,
        referralCodeFixture: ' JDC12345 ',
        referralSummaryFixture: summary,
      ),
    ));
    await tester.pumpAndSettle();
    expect(tester.widget<QrImageView>(find.byType(QrImageView)).semanticsLabel,
        'JDC12345');
    expect(tester.takeException(), isNull);
  });

  testWidgets('customer can share QR and see merchant reward rule',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('th'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ReferralScreen(
        referralCodeFixture: 'JDC99999',
        referralSummaryFixture: {
          'current_multiplier': 1.25,
          'base': {
            'customer_invite_merchant': 40,
            'customer_invite_customer': 10,
            'customer_invite_driver': 10,
          },
        },
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('ชวนร้านค้า'), findsOneWidget);
    expect(find.text('ชวนลูกค้า'), findsOneWidget);
    expect(find.text('ชวนคนขับ'), findsOneWidget);
    expect(find.text('คุณรับ ฿50 ตามขั้นปัจจุบัน'), findsOneWidget);
    expect(find.text('คุณรับ ฿12.50 ตามขั้นปัจจุบัน'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });

  testWidgets('invite registration prefills the code for every role',
      (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
      child: MaterialApp(
        locale: const Locale('th'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const RegisterScreen(initialReferralCode: 'REF-AB12'),
      ),
    ));
    await tester.pumpAndSettle();
    final referralField = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'โค้ดแนะนำจากเพื่อน (ถ้ามี)'));
    expect(referralField.controller?.text, 'REF-AB12');
    await tester.tap(find.text('ร้านค้า').first);
    await tester.pump();
    expect(referralField.controller?.text, 'REF-AB12');
    await tester.tap(find.text('คนขับ').first);
    await tester.pump();
    expect(referralField.controller?.text, 'REF-AB12');
  });

  testWidgets('driver profile opens its referral page', (tester) async {
    await tester.pumpWidget(ChangeNotifierProvider(
      create: (_) => LanguageProvider(),
      child: MaterialApp(
        locale: const Locale('th'),
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const DriverProfileScreen(previewProfile: {
          'full_name': 'คนขับทดสอบ',
          'phone_number': '0800000000',
        }),
      ),
    ));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('ชวนเพื่อน'));
    await tester.tap(find.text('ชวนเพื่อน'));
    await tester.pumpAndSettle();
    expect(find.byType(ReferralScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
