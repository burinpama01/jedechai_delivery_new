import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/admin_theme.dart';
import '../../../common/services/auth_service.dart';
import 'admin_dashboard_screen.dart';
import 'admin_driver_map_screen.dart';
import 'admin_driver_approval_screen.dart';
import 'admin_merchant_approval_screen.dart';
import 'admin_withdrawal_screen.dart';
import 'admin_orders_screen.dart';
import 'admin_fee_settings_screen.dart';
import 'admin_account_deletion_screen.dart';
import 'admin_topup_screen.dart';

/// Admin Main Screen
///
/// Web: Sidebar navigation + content area
/// Mobile: Bottom navigation
class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _currentIndex = 0;
  DateTime? _lastBackPressTime;

  final List<Widget> _screens = const [
    AdminDashboardScreen(),       // 0
    AdminDriverMapScreen(),       // 1
    AdminDriverApprovalScreen(),  // 2
    AdminMerchantApprovalScreen(),// 3
    AdminOrdersScreen(),          // 4
    AdminWithdrawalScreen(),      // 5
    AdminTopUpScreen(),           // 6
    AdminFeeSettingsScreen(),     // 7
    AdminAccountDeletionScreen(), // 8
  ];

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
      const SnackBar(
        content: Text('กดอีกครั้งเพื่อออกจากแอป'),
        duration: Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final isWide = width >= 800;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => _onPopInvoked(didPop),
      child: Scaffold(
        backgroundColor: AdminTheme.background,
        body: isWide ? _buildWebLayout() : _buildMobileLayout(),
      ),
    );
  }

  // ─── Web: Sidebar + Content ───────────────────────────
  Widget _buildWebLayout() {
    final menuItems = AdminTheme.menuItems;

    return Row(
      children: [
        // Sidebar
        Container(
          width: AdminTheme.sidebarWidth,
          color: AdminTheme.sidebarBg,
          child: Column(
            children: [
              // Logo header
              Container(
                height: 72,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                alignment: Alignment.centerLeft,
                child: const Row(
                  children: [
                    Icon(Icons.admin_panel_settings_rounded,
                        color: Colors.white, size: 28),
                    SizedBox(width: 10),
                    Text(
                      'Jedechai Admin',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(color: Color(0xFF1E293B), height: 1),
              const SizedBox(height: 8),

              // Menu items
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: menuItems.length,
                  itemBuilder: (context, index) {
                    final item = menuItems[index];
                    final isActive = _currentIndex == item.index;

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => setState(() => _currentIndex = item.index),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? AdminTheme.sidebarActive
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  item.icon,
                                  size: 20,
                                  color: isActive
                                      ? Colors.white
                                      : AdminTheme.sidebarText,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  item.label,
                                  style: TextStyle(
                                    color: isActive
                                        ? Colors.white
                                        : AdminTheme.sidebarText,
                                    fontSize: 14,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),

              // Logout
              const Divider(color: Color(0xFF1E293B), height: 1),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () async => await AuthService.signOut(),
                    child: const Padding(
                      padding:
                          EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      child: Row(
                        children: [
                          Icon(Icons.logout_rounded,
                              size: 20, color: Color(0xFFEF4444)),
                          SizedBox(width: 12),
                          Text(
                            'ออกจากระบบ',
                            style: TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Content area
        Expanded(
          child: _screens[_currentIndex],
        ),
      ],
    );
  }

  // ─── Mobile: Bottom Nav ──────────────────────────────
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: AdminTheme.background,
      body: _screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AdminTheme.primary,
        unselectedItemColor: AdminTheme.textMuted,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        iconSize: 22,
        items: AdminTheme.menuItems.map((item) {
          return BottomNavigationBarItem(
            icon: Icon(item.icon),
            label: item.label,
          );
        }).toList(),
      ),
    );
  }
}
