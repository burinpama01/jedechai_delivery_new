import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';
import '../../../common/screens/notification_center_screen.dart';
import '../../../common/utils/profile_completion_policy.dart';
import '../../../common/widgets/notification_badge_icon.dart';
import '../utils/merchant_main_nav_policy.dart';
import 'merchant_dashboard_screen.dart';
import 'merchant_orders_screen.dart';
import 'merchant_laundry_screen.dart';
import 'menu_management_screen.dart';
import 'merchant_settings_screen.dart';

/// Merchant Main Screen
///
/// Main navigation wrapper for merchant app with 4 tabs:
/// 1. ออเดอร์ (Orders) — real-time order management
/// 2. เมนู (Menu) — menu item management
/// 3. แดชบอร์ด (Dashboard) — stats overview
/// 4. ตั้งค่า (Settings) — shop profile & settings
class MerchantMainScreen extends StatefulWidget {
  const MerchantMainScreen({super.key});

  @override
  State<MerchantMainScreen> createState() => _MerchantMainScreenState();
}

class _MerchantMainScreenState extends State<MerchantMainScreen> {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;
  bool _isLoadingServiceType = true;
  String? _merchantServiceType;
  String? _serviceTypeError;

  @override
  void initState() {
    super.initState();
    _loadMerchantServiceType();
  }

  Future<void> _loadMerchantServiceType() async {
    setState(() {
      _isLoadingServiceType = true;
      _serviceTypeError = null;
    });

    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        throw StateError('unauthenticated');
      }

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('merchant_service_types')
          .eq('id', userId)
          .maybeSingle();
      final serviceType = normalizeMerchantServiceType(
        profile?['merchant_service_types'],
      );
      if (serviceType == null) {
        throw StateError('missing merchant_service_types');
      }
      if (!mounted) return;
      setState(() {
        _merchantServiceType = serviceType;
        _currentIndex = 0;
        _isLoadingServiceType = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _serviceTypeError = e.toString();
        _isLoadingServiceType = false;
      });
    }
  }

  void _onPopInvoked(bool didPop) {
    if (didPop) return;
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return;
    }
    final now = DateTime.now();
    if (_lastBackPressTime != null &&
        now.difference(_lastBackPressTime!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBackPressTime = now;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(AppLocalizations.of(context)!.merchantPressBackAgain),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    if (_isLoadingServiceType) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_serviceTypeError != null || _merchantServiceType == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.storefront_outlined, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'โหลดประเภทร้านไม่สำเร็จ',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  _serviceTypeError ?? 'missing merchant_service_types',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: _loadMerchantServiceType,
                  icon: const Icon(Icons.refresh),
                  label: const Text('ลองใหม่'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final navFeatures = merchantMainNavFeaturesForServiceType(
      _merchantServiceType,
    );
    final currentIndex =
        _currentIndex >= navFeatures.length ? 0 : _currentIndex;
    final screens = navFeatures.map(_screenForFeature).toList();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _onPopInvoked(didPop),
      child: Scaffold(
        body: IndexedStack(
          index: currentIndex,
          children: screens,
        ),
        bottomNavigationBar: SafeArea(
          top: false,
          child: Container(
            decoration: BoxDecoration(
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: BottomNavigationBar(
              currentIndex: currentIndex,
              onTap: (index) => setState(() => _currentIndex = index),
              type: BottomNavigationBarType.fixed,
              backgroundColor: colorScheme.surface,
              selectedItemColor: AppTheme.accentOrange,
              unselectedItemColor: colorScheme.onSurfaceVariant,
              selectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              unselectedLabelStyle:
                  const TextStyle(fontWeight: FontWeight.w400, fontSize: 13),
              items: navFeatures.map(_navItemForFeature).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _screenForFeature(MerchantMainNavFeature feature) {
    switch (feature) {
      case MerchantMainNavFeature.orders:
        return const MerchantOrdersScreen();
      case MerchantMainNavFeature.laundry:
        return const MerchantLaundryScreen();
      case MerchantMainNavFeature.menu:
        return const MenuManagementScreen();
      case MerchantMainNavFeature.report:
        return const MerchantDashboardScreen();
      case MerchantMainNavFeature.notifications:
        return const NotificationCenterScreen(role: 'merchant');
      case MerchantMainNavFeature.account:
        return const MerchantSettingsScreen();
    }
  }

  BottomNavigationBarItem _navItemForFeature(MerchantMainNavFeature feature) {
    switch (feature) {
      case MerchantMainNavFeature.orders:
        return BottomNavigationBarItem(
          icon: const Icon(Icons.receipt_long_outlined),
          activeIcon: const Icon(Icons.receipt_long),
          label: AppLocalizations.of(context)!.merchantNavOrders,
        );
      case MerchantMainNavFeature.laundry:
        return const BottomNavigationBarItem(
          icon: Icon(Icons.local_laundry_service_outlined),
          activeIcon: Icon(Icons.local_laundry_service),
          label: 'ซักผ้า',
        );
      case MerchantMainNavFeature.menu:
        return BottomNavigationBarItem(
          icon: const Icon(Icons.restaurant_menu_outlined),
          activeIcon: const Icon(Icons.restaurant_menu),
          label: AppLocalizations.of(context)!.merchantNavMenu,
        );
      case MerchantMainNavFeature.report:
        return BottomNavigationBarItem(
          icon: const Icon(Icons.bar_chart_outlined),
          activeIcon: const Icon(Icons.bar_chart),
          label: AppLocalizations.of(context)!.merchantNavReport,
        );
      case MerchantMainNavFeature.notifications:
        return const BottomNavigationBarItem(
          icon: NotificationBadgeIcon(
            icon: Icons.notifications_none,
          ),
          activeIcon: NotificationBadgeIcon(
            icon: Icons.notifications,
          ),
          label: 'แจ้งเตือน',
        );
      case MerchantMainNavFeature.account:
        return BottomNavigationBarItem(
          icon: const Icon(Icons.person_outline),
          activeIcon: const Icon(Icons.person),
          label: AppLocalizations.of(context)!.merchantNavAccount,
        );
    }
  }
}
