import 'package:flutter/material.dart';
import '../../../common/services/app_ad_service.dart';
import '../../../common/widgets/app_ad_widgets.dart';
import '../../../common/widgets/main_navigation_screen.dart';
import '../../../common/screens/notification_center_screen.dart';
import 'driver_dashboard_screen.dart';
import 'driver_earnings_screen.dart';
import 'profile/driver_profile_screen.dart';

/// Driver Main Screen
///
/// Main navigation wrapper for driver app using shared MainNavigationScreen
class DriverMainScreen extends StatelessWidget {
  const DriverMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AppAdPopupHost(
      placement: AppAdPlacement.driverPopup,
      child: DriverMainNavigationScreen(
        dashboardScreen: const DriverDashboardScreen(),
        earningsScreen: const DriverEarningsScreen(),
        notificationScreen: const NotificationCenterScreen(role: 'driver'),
        profileScreen: const DriverProfileScreen(),
      ),
    );
  }
}
