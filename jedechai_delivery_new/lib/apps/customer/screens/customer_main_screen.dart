import 'package:flutter/material.dart';
import '../../../common/services/app_ad_service.dart';
import '../../../common/widgets/app_ad_widgets.dart';
import '../../../common/widgets/main_navigation_screen.dart';
import '../../../common/screens/notification_center_screen.dart';
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
    return AppAdPopupHost(
      placement: AppAdPlacement.customerPopup,
      child: CustomerMainNavigationScreen(
        homeScreen: const CustomerHomeScreen(),
        activityScreen: const ActivityScreen(),
        notificationScreen: const NotificationCenterScreen(role: 'customer'),
        accountScreen: const AccountScreen(),
      ),
    );
  }
}
