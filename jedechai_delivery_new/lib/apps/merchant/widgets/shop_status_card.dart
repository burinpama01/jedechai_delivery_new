import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';

class MerchantShopStatusCard extends StatelessWidget {
  const MerchantShopStatusCard({
    super.key,
    required this.isShopOpen,
    required this.isAutoAcceptMode,
    required this.isAutoScheduleEnabled,
    required this.onShopStatusChanged,
  });

  final bool isShopOpen;
  final bool isAutoAcceptMode;
  final bool isAutoScheduleEnabled;
  final ValueChanged<bool> onShopStatusChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final localizations = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isShopOpen
              ? [
                  AppTheme.accentOrange,
                  AppTheme.accentOrange.withValues(alpha: 0.8),
                ]
              : [
                  colorScheme.outline,
                  colorScheme.outline.withValues(alpha: 0.8),
                ],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isShopOpen ? AppTheme.accentOrange : colorScheme.outline)
                .withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isShopOpen ? Icons.store : Icons.store_mall_directory,
                color: colorScheme.onPrimary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  localizations.merchantShopStatus,
                  style: TextStyle(
                    color: colorScheme.onPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Switch(
                value: isShopOpen,
                onChanged: onShopStatusChanged,
                activeThumbColor: colorScheme.onPrimary,
                inactiveThumbColor: colorScheme.surfaceContainerHighest,
                activeTrackColor: colorScheme.onPrimary.withValues(alpha: 0.5),
                inactiveTrackColor:
                    colorScheme.onPrimary.withValues(alpha: 0.3),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isShopOpen
                ? localizations.merchantShopOpen
                : localizations.merchantShopClosed2,
            style: TextStyle(
              color: colorScheme.onPrimary,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isShopOpen
                ? localizations.merchantShopOpenDesc
                : localizations.merchantShopClosedDesc,
            style: TextStyle(
              color: colorScheme.onPrimary.withValues(alpha: 0.9),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(
                isAutoAcceptMode
                    ? Icons.auto_mode_outlined
                    : Icons.pan_tool_alt_outlined,
                color: colorScheme.onPrimary.withValues(alpha: 0.9),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                isAutoAcceptMode
                    ? localizations.merchantAcceptModeAuto
                    : localizations.merchantAcceptModeManual,
                style: TextStyle(
                  color: colorScheme.onPrimary.withValues(alpha: 0.95),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Icon(
                isAutoScheduleEnabled
                    ? Icons.av_timer
                    : Icons.av_timer_outlined,
                color: colorScheme.onPrimary.withValues(alpha: 0.9),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                isAutoScheduleEnabled
                    ? localizations.merchantAutoScheduleOn
                    : localizations.merchantAutoScheduleOff,
                style: TextStyle(
                  color: colorScheme.onPrimary.withValues(alpha: 0.95),
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
