import 'dart:async';

import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../theme/jdc_colors.dart';
import '../../../common/widgets/app_network_image.dart';
import '../../../common/services/auth_service.dart';
import '../../../common/services/system_config_service.dart';
import '../../../l10n/app_localizations.dart';

/// Splash Screen
/// Checks authentication status and navigates accordingly
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  String? _logoUrl;
  String? _version;

  @override
  void initState() {
    super.initState();
    unawaited(_fetchVersion());
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
    debugLog(
        '🏠 Splash: Navigating to AuthGate (isAuthenticated=$isAuthenticated)');
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

  Future<void> _fetchVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (mounted) setState(() => _version = info.version);
    } catch (_) {
      // Version is decorative; splash navigation must continue if unavailable.
    }
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: jdc.hero),
        child: SafeArea(
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 108,
                      height: 108,
                      decoration: BoxDecoration(
                        color: jdc.brand,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: _logoUrl == null
                          ? Icon(Icons.local_shipping_rounded,
                              size: 58, color: jdc.panel)
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(30),
                              child: AppNetworkImage(
                                imageUrl: _logoUrl,
                                width: 108,
                                height: 108,
                                fit: BoxFit.contain,
                                backgroundColor: jdc.brand,
                              ),
                            ),
                    ),
                    const SizedBox(height: 28),
                    Text(
                      l10n.appName,
                      style: TextStyle(
                        color: jdc.onPanel,
                        fontSize: 32,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.6,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.splashTagline,
                      style: TextStyle(color: jdc.panelDim, fontSize: 14),
                    ),
                    const SizedBox(height: 28),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var index = 0; index < 3; index++) ...[
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(
                              color: index == 0 ? jdc.brand : jdc.barDim,
                              shape: BoxShape.circle,
                            ),
                          ),
                          if (index < 2) const SizedBox(width: 7),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (_version != null)
                Positioned(
                  bottom: 36,
                  left: 0,
                  right: 0,
                  child: Text(
                    l10n.splashVersion(_version!),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: jdc.panelDim, fontSize: 11),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
