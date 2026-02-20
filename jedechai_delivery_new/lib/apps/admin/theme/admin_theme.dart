import 'package:flutter/material.dart';

/// Admin Theme — Dark sidebar + Blue accent design
/// Clearly separated from customer brass-gold theme
class AdminTheme {
  // Primary — Admin Blue
  static const Color primary = Color(0xFF1565C0);
  static const Color primaryDark = Color(0xFF0D47A1);
  static const Color primaryLight = Color(0xFF42A5F5);

  // Sidebar
  static const Color sidebarBg = Color(0xFF0F172A);
  static const Color sidebarText = Color(0xFFCBD5E1);
  static const Color sidebarActive = Color(0xFF1E40AF);
  static const Color sidebarHover = Color(0xFF1E293B);

  // Surface
  static const Color background = Color(0xFFF1F5F9);
  static const Color surface = Colors.white;
  static const Color divider = Color(0xFFE2E8F0);

  // Text
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textMuted = Color(0xFF94A3B8);

  // Status
  static const Color success = Color(0xFF16A34A);
  static const Color warning = Color(0xFFEAB308);
  static const Color danger = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  // Radius
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;

  // Sidebar width
  static const double sidebarWidth = 240;
  static const double sidebarCollapsed = 72;

  /// Sidebar menu items definition
  static List<AdminMenuItem> get menuItems => [
        AdminMenuItem(icon: Icons.dashboard_rounded, label: 'แดชบอร์ด', index: 0),
        AdminMenuItem(icon: Icons.map_rounded, label: 'แผนที่คนขับ', index: 1),
        AdminMenuItem(icon: Icons.directions_car_rounded, label: 'จัดการคนขับ', index: 2),
        AdminMenuItem(icon: Icons.store_rounded, label: 'จัดการร้านค้า', index: 3),
        AdminMenuItem(icon: Icons.receipt_long_rounded, label: 'ออเดอร์', index: 4),
        AdminMenuItem(icon: Icons.account_balance_wallet_rounded, label: 'ถอนเงิน', index: 5),
        AdminMenuItem(icon: Icons.add_card_rounded, label: 'เติมเงิน', index: 6),
        AdminMenuItem(icon: Icons.tune_rounded, label: 'ค่าธรรมเนียม', index: 7),
        AdminMenuItem(icon: Icons.person_off_rounded, label: 'ลบบัญชี', index: 8),
      ];
}

class AdminMenuItem {
  final IconData icon;
  final String label;
  final int index;
  const AdminMenuItem({required this.icon, required this.label, required this.index});
}
