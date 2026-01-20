  import 'package:flutter/material.dart';
import 'services/supabase_service.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase
  try {
    await SupabaseService.initialize();
    debugPrint('✅ Supabase initialized successfully');
  } catch (e) {
    debugPrint('❌ Error initializing Supabase: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Jedechai Delivery',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
