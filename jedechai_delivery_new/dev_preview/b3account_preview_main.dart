// Dev-only Wave 1.5 preview for customer account artboards.
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jedechai_delivery_new/apps/customer/providers/cart_provider.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/account_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/activity_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/customer_wallet_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/rewards/my_coupons_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/rewards/referral_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/help_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/saved_addresses_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/services/support_tickets_screen.dart';
import 'package:jedechai_delivery_new/apps/customer/screens/splash_screen.dart';
import 'package:jedechai_delivery_new/common/config/env_config.dart';
import 'package:jedechai_delivery_new/common/providers/auth_provider.dart';
import 'package:jedechai_delivery_new/common/providers/language_provider.dart';
import 'package:jedechai_delivery_new/common/screens/profile_screen.dart';
import 'package:jedechai_delivery_new/l10n/app_localizations.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import 'package:jedechai_delivery_new/theme/jdc_layout.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await dotenv.load(fileName: '.env.client');
  await Supabase.initialize(url: EnvConfig.supabaseUrl, anonKey: EnvConfig.supabaseAnonKey);
  final params = Uri.base.queryParameters;
  runApp(MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => AuthProvider()),
      ChangeNotifierProvider(create: (_) => CartProvider()),
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
      home: _PreviewScreen(screen: params['screen'] ?? 'Splash'),
    ),
  ));
}

class _PreviewScreen extends StatelessWidget {
  final String screen;
  const _PreviewScreen({required this.screen});

  @override
  Widget build(BuildContext context) => switch (screen) {
    'Activity' => const ActivityScreen(),
    'Account' => const AccountScreen(previewProfile: {
      'full_name': 'ผู้ทดสอบหน้าบัญชี',
      'phone_number': '081-234-5678',
    }),
    'Profile' => const ProfileScreen(),
    'Wallet' => const CustomerWalletScreen(),
    'Coupons' => const MyCouponsScreen(),
    'Referral' => const ReferralScreen(),
    'SavedAddresses' => const SavedAddressesScreen(),
    'Help' => const HelpScreen(),
    'SupportTickets' => const SupportTicketsScreen(),
    'Splash' => const SplashScreen(),
    _ => Scaffold(body: Center(child: Text('Unknown preview screen: $screen'))),
  };
}
