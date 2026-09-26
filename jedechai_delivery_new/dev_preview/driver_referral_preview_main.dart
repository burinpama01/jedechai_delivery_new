// Dev-only preview ของหน้าแชร์โค้ดคนขับ ใช้ fixture เพื่อเทียบ layout เท่านั้น
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/rewards/referral_screen.dart';
import 'package:jedechai_delivery_new/common/config/env_config.dart';
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
  final query = Uri.base.queryParameters;
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    builder: jdcTextScaleGuard,
    theme: AppTheme.lightTheme,
    darkTheme: AppTheme.darkTheme,
    themeMode: query['theme'] == 'dark' ? ThemeMode.dark : ThemeMode.light,
    locale: Locale(query['lang'] ?? 'th'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: const ReferralScreen(
      forDriver: true,
      referralCodeFixture: 'JDCDEMO8',
      referralSummaryFixture: {
        'current_tier': 2,
        'current_multiplier': 1.25,
        'referrals_to_next_tier': 7,
        'successful_referrals': 8,
        'total_earned': 175,
        'pending_review': 0,
        'withdrawal_min': {'system': 200},
        'base': {
          'driver_invite_merchant': 20,
          'driver_invite_driver_referrer': 20,
          'driver_invite_driver_newdriver': 20,
        },
        'tiers': [
          {'from': 1, 'to': 5, 'multiplier': 1.0},
          {'from': 6, 'to': 15, 'multiplier': 1.25},
          {'from': 16, 'to': null, 'multiplier': 1.5},
        ],
      },
    ),
  ));
}
