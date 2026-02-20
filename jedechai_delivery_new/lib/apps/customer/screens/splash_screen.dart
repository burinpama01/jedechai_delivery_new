import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import '../../../common/widgets/app_network_image.dart';
import '../../../common/services/auth_service.dart';
import '../../../common/services/system_config_service.dart';
import '../../../theme/app_theme.dart';

/// Splash Screen
/// Checks authentication status and navigates accordingly
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _logoUrl;

  @override
  void initState() {
    super.initState();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    // Fetch logo + wait in parallel
    await Future.wait([
      _fetchLogo(),
      Future.delayed(const Duration(milliseconds: 1500)),
    ]);

    if (!mounted) return;

    // Check if user has an active session using AuthService
    final isAuthenticated = AuthService.isAuthenticated;
    debugLog('🔍 Splash: Auth status = $isAuthenticated');
    
    // Navigate to AuthGate which handles role-based routing
    debugLog('🏠 Splash: Navigating to AuthGate (isAuthenticated=$isAuthenticated)');
    Navigator.of(context).pushReplacementNamed('/');
  }

  Future<void> _fetchLogo() async {
    try {
      final configService = SystemConfigService();
      await configService.fetchSettings();
      if (mounted && configService.logoUrl != null) {
        setState(() => _logoUrl = configService.logoUrl);
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryGreen,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // App Logo/Icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(30),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(30),
                child: AppNetworkImage(
                  imageUrl: _logoUrl,
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                  backgroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 24),
            // App Name
            const Text(
              'Jedechai Delivery',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 48),
            // Loading Indicator
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
