import 'package:flutter/material.dart';
import '../models/booking_status.dart';

/// Reusable Status Badge Widget
/// 
/// Displays a booking status with consistent color, icon, and text
/// across all screens (customer, driver, merchant).
class StatusBadge extends StatelessWidget {
  final String statusString;
  final StatusRole role;
  final bool showIcon;
  final double fontSize;

  const StatusBadge({
    super.key,
    required this.statusString,
    this.role = StatusRole.customer,
    this.showIcon = true,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    final status = BookingStatus.fromString(statusString);
    final text = switch (role) {
      StatusRole.customer => status.customerText,
      StatusRole.driver => status.driverText,
      StatusRole.merchant => status.merchantText,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: status.color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: status.color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(status.icon, size: fontSize + 2, color: status.color),
            const SizedBox(width: 4),
          ],
          Text(
            text,
            style: TextStyle(
              color: status.color,
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

/// Role determines which text variant to display
enum StatusRole { customer, driver, merchant }
