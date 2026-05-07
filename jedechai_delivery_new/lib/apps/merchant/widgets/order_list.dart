import 'package:flutter/material.dart';

import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';

class MerchantOrderList extends StatelessWidget {
  const MerchantOrderList({
    super.key,
    required this.orders,
    required this.isLoading,
    required this.error,
    required this.isShopOpen,
    required this.onRetry,
    required this.orderBuilder,
  });

  final List<Map<String, dynamic>> orders;
  final bool isLoading;
  final String? error;
  final bool isShopOpen;
  final VoidCallback onRetry;
  final Widget Function(Map<String, dynamic> order) orderBuilder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final localizations = AppLocalizations.of(context)!;

    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentOrange),
        ),
      );
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              error!,
              style: TextStyle(color: colorScheme.error),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              child: Text(localizations.merchantRetry),
            ),
          ],
        ),
      );
    }

    if (orders.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.12),
              blurRadius: 4,
              spreadRadius: 1,
            ),
          ],
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.accentOrange.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.restaurant_outlined,
                size: 64,
                color: AppTheme.accentOrange,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              localizations.merchantNoOrders,
              style: TextStyle(
                fontSize: 20,
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isShopOpen
                  ? localizations.merchantOrdersWillAppear
                  : localizations.merchantOpenShopToReceive,
              style: TextStyle(
                fontSize: 14,
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: orders.map(orderBuilder).toList(),
    );
  }
}
