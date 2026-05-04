import 'package:flutter/material.dart';
import '../../../theme/app_theme.dart';

/// Step progress bar and action row shown in the driver navigation bottom panel.
class NavigationStatusBar extends StatelessWidget {
  final String bookingStatus;
  final String serviceType;
  final String statusText;
  final IconData statusIcon;
  final bool isUpdatingStatus;
  final String actionButtonText;
  final IconData actionButtonIcon;
  final Color actionButtonColor;
  final VoidCallback onAction;
  final VoidCallback onNavigate;
  final VoidCallback onChat;
  final VoidCallback onCall;
  final String navTooltip;
  final String chatTooltip;
  final String callTooltip;

  const NavigationStatusBar({
    super.key,
    required this.bookingStatus,
    required this.serviceType,
    required this.statusText,
    required this.statusIcon,
    required this.isUpdatingStatus,
    required this.actionButtonText,
    required this.actionButtonIcon,
    required this.actionButtonColor,
    required this.onAction,
    required this.onNavigate,
    required this.onChat,
    required this.onCall,
    this.navTooltip = 'นำทาง',
    this.chatTooltip = 'แชท',
    this.callTooltip = 'โทร',
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Step progress bar
        StepProgressBar(bookingStatus: bookingStatus, serviceType: serviceType),
        const SizedBox(height: 10),

        // Status + action buttons row
        Row(
          children: [
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(statusIcon, size: 18, color: AppTheme.accentBlue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(statusText,
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                          overflow: TextOverflow.ellipsis),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            _CircleButton(icon: Icons.navigation_rounded, color: colorScheme.secondary, onPressed: onNavigate, tooltip: navTooltip),
            const SizedBox(width: 6),
            _CircleButton(icon: Icons.chat_rounded, color: colorScheme.tertiary, onPressed: onChat, tooltip: chatTooltip),
            const SizedBox(width: 6),
            _CircleButton(icon: Icons.phone_rounded, color: AppTheme.accentBlue, onPressed: onCall, tooltip: callTooltip),
          ],
        ),
        const SizedBox(height: 10),

        // Main action button
        SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton.icon(
            onPressed: isUpdatingStatus ? null : onAction,
            icon: isUpdatingStatus
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: colorScheme.onPrimary),
                  )
                : Icon(actionButtonIcon, size: 22),
            label: Text(actionButtonText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: actionButtonColor,
              foregroundColor: colorScheme.onPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 2,
            ),
          ),
        ),
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;
  final String tooltip;

  const _CircleButton({required this.icon, required this.color, required this.onPressed, required this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: color.withValues(alpha: 0.15),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, size: 22, color: color),
          ),
        ),
      ),
    );
  }
}

/// Step progress indicator for the delivery flow.
class StepProgressBar extends StatelessWidget {
  final String bookingStatus;
  final String serviceType;

  const StepProgressBar({super.key, required this.bookingStatus, required this.serviceType});

  int _currentStep() {
    if (['accepted', 'driver_accepted'].contains(bookingStatus)) return 0;
    if (['arrived_at_merchant', 'arrived'].contains(bookingStatus)) return 1;
    if (['picking_up_order', 'in_transit', 'ready_for_pickup'].contains(bookingStatus)) return 2;
    if (bookingStatus == 'completed') return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final steps = serviceType == 'food'
        ? ['รับงาน', 'มาถึงร้าน', 'รับอาหาร', 'ส่งแล้ว']
        : ['รับงาน', 'มาถึงจุดรับ', 'กำลังส่ง', 'เสร็จสิ้น'];
    final current = _currentStep();

    return Row(
      children: List.generate(steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final active = i ~/ 2 < current;
          return Expanded(child: Container(height: 2, color: active ? AppTheme.accentBlue : colorScheme.outlineVariant));
        }
        final stepIndex = i ~/ 2;
        final active = stepIndex <= current;
        final isCurrent = stepIndex == current;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: active ? AppTheme.accentBlue : colorScheme.surfaceContainerHighest,
                shape: BoxShape.circle,
                border: isCurrent ? Border.all(color: AppTheme.accentBlue, width: 2) : null,
              ),
              child: Icon(
                stepIndex < current ? Icons.check : Icons.circle,
                color: active ? Colors.white : colorScheme.outlineVariant,
                size: 10,
              ),
            ),
            const SizedBox(height: 2),
            Text(steps[stepIndex],
                style: TextStyle(
                    fontSize: 8,
                    color: active ? AppTheme.accentBlue : colorScheme.onSurfaceVariant,
                    fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal)),
          ],
        );
      }),
    );
  }
}
