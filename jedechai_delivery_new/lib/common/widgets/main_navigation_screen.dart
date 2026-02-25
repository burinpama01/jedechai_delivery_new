import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Universal Main Navigation Screen
/// 
/// Provides consistent bottom navigation across all roles
/// Reduces code duplication and maintains consistent UX
class MainNavigationScreen extends StatefulWidget {
  final List<Widget> screens;
  final List<BottomNavigationBarItem> bottomNavItems;
  final int initialIndex;
  final Widget? appBar;
  final bool showAppBar;

  const MainNavigationScreen({
    super.key,
    required this.screens,
    required this.bottomNavItems,
    this.initialIndex = 0,
    this.appBar,
    this.showAppBar = true,
  });

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late int _currentIndex;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  void _onPopInvoked(bool didPop) {
    if (didPop) return;
    // ถ้าไม่ได้อยู่หน้าแรก ให้กลับไปหน้าแรกก่อน
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      return;
    }

    // กดซ้ำภายใน 2 วินาที → ออกจากแอป
    final now = DateTime.now();
    if (_lastBackPressTime != null &&
        now.difference(_lastBackPressTime!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }

    _lastBackPressTime = now;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('กดอีกครั้งเพื่อออกจากแอป'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final navShadowColor = colorScheme.shadow.withValues(alpha: 0.12);
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _onPopInvoked(didPop),
      child: Scaffold(
      appBar: widget.showAppBar && widget.appBar != null 
          ? PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: widget.appBar!,
            )
          : null,
      body: IndexedStack(
        index: _currentIndex,
        children: widget.screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: navShadowColor,
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          type: BottomNavigationBarType.fixed,
          backgroundColor: colorScheme.surface,
          selectedItemColor: colorScheme.primary,
          unselectedItemColor: colorScheme.onSurfaceVariant,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
          unselectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.w400,
            fontSize: 12,
          ),
          items: widget.bottomNavItems,
        ),
      ),
    ),
    );
  }
}

/// Factory constructor for Customer Main Screen
class CustomerMainNavigationScreen extends StatelessWidget {
  const CustomerMainNavigationScreen({
    super.key,
    required this.homeScreen,
    required this.activityScreen,
    required this.accountScreen,
  });

  final Widget homeScreen;
  final Widget activityScreen;
  final Widget accountScreen;

  @override
  Widget build(BuildContext context) {
    return MainNavigationScreen(
      screens: [
        homeScreen,
        activityScreen,
        accountScreen,
      ],
      bottomNavItems: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home_outlined),
          activeIcon: Icon(Icons.home),
          label: 'หน้าแรก',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.history_outlined),
          activeIcon: Icon(Icons.history),
          label: 'กิจกรรม',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'บัญชี',
        ),
      ],
    );
  }
}

/// Factory constructor for Driver Main Screen
class DriverMainNavigationScreen extends StatelessWidget {
  const DriverMainNavigationScreen({
    super.key,
    required this.dashboardScreen,
    required this.earningsScreen,
    required this.profileScreen,
  });

  final Widget dashboardScreen;
  final Widget earningsScreen;
  final Widget profileScreen;

  @override
  Widget build(BuildContext context) {
    return MainNavigationScreen(
      screens: [
        dashboardScreen,
        earningsScreen,
        profileScreen,
      ],
      bottomNavItems: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.work_outline),
          activeIcon: Icon(Icons.work),
          label: 'งาน',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.attach_money_outlined),
          activeIcon: Icon(Icons.attach_money),
          label: 'รายได้',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'โปรไฟล์',
        ),
      ],
    );
  }
}

/// Factory constructor for Merchant Main Screen
class MerchantMainNavigationScreen extends StatelessWidget {
  const MerchantMainNavigationScreen({
    super.key,
    required this.dashboardScreen,
    required this.ordersScreen,
    required this.profileScreen,
  });

  final Widget dashboardScreen;
  final Widget ordersScreen;
  final Widget profileScreen;

  @override
  Widget build(BuildContext context) {
    return MainNavigationScreen(
      screens: [
        dashboardScreen,
        ordersScreen,
        profileScreen,
      ],
      bottomNavItems: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.store_outlined),
          activeIcon: Icon(Icons.store),
          label: 'แดชบอร์ด',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.receipt_long_outlined),
          activeIcon: Icon(Icons.receipt_long),
          label: 'ออเดอร์',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person_outline),
          activeIcon: Icon(Icons.person),
          label: 'บัญชี',
        ),
      ],
    );
  }
}
