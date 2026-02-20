import 'package:flutter/material.dart';
import '../../../common/widgets/main_navigation_screen.dart';
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
    return DriverMainNavigationScreen(
      dashboardScreen: const DriverDashboardScreen(),
      earningsScreen: const DriverEarningsScreen(),
      profileScreen: const DriverProfileScreen(),
    );
  }
}
