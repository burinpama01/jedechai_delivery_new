import 'package:flutter/material.dart';
import '../../../common/widgets/main_navigation_screen.dart';
import 'activity_screen.dart';
import 'account_screen.dart';
import 'customer_home_screen.dart';

/// Customer Main Screen
/// 
/// Main navigation wrapper for customer app using shared MainNavigationScreen
class CustomerMainScreen extends StatelessWidget {
  const CustomerMainScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomerMainNavigationScreen(
      homeScreen: const CustomerHomeScreen(),
      activityScreen: const ActivityScreen(),
      accountScreen: const AccountScreen(),
    );
  }
}
