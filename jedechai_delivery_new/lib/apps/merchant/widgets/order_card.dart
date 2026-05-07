import 'package:flutter/material.dart';

import '../../../common/utils/order_code_formatter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/app_theme.dart';

class MerchantOrderCard extends StatelessWidget {
  const MerchantOrderCard({
    super.key,
    required this.order,
    required this.onTap,
    required this.onAcceptOrder,
    required this.statusTextBuilder,
  });

  final Map<String, dynamic> order;
  final VoidCallback onTap;
  final ValueChanged<String> onAcceptOrder;
  final String Function(String status) statusTextBuilder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = order['status'] as String? ?? '';
    final price = order['price'] is int
        ? (order['price'] as int).toDouble()
        : (order['price'] as num?)?.toDouble() ?? 0.0;
    final distanceKm = order['distance_km'] is int
        ? (order['distance_km'] as int).toDouble()
        : (order['distance_km'] as num?)?.toDouble() ?? 0.0;
    final createdAtStr = order['created_at'] as String?;
    final scheduledAtStr = order['scheduled_at'] as String?;
    final scheduledAt = scheduledAtStr != null
        ? DateTime.tryParse(scheduledAtStr)?.toLocal()
        : null;

    if (createdAtStr == null) {
      return const SizedBox.shrink();
    }

    final createdAt = DateTime.parse(createdAtStr).toLocal();
    final isNewOrder = status == 'pending_merchant' || status == 'pending';
    final statusColor = _getStatusColor(context, status);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          border: isNewOrder
              ? Border.all(
                  color: colorScheme.error.withValues(alpha: 0.4),
                  width: 2,
                )
              : null,
          boxShadow: [
            BoxShadow(
              color: (isNewOrder ? colorScheme.error : colorScheme.shadow)
                  .withValues(alpha: 0.08),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isNewOrder
                      ? [
                          colorScheme.error,
                          colorScheme.error.withValues(alpha: 0.7),
                        ]
                      : [statusColor, statusColor.withValues(alpha: 0.7)],
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isNewOrder
                        ? Icons.notifications_active
                        : _getStatusIcon(status),
                    color: colorScheme.onPrimary,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    statusTextBuilder(status),
                    style: TextStyle(
                      color: colorScheme.onPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    OrderCodeFormatter.format(order['id']?.toString()),
                    style: TextStyle(
                      color: colorScheme.onPrimary.withValues(alpha: 0.85),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.accentOrange.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.receipt_long,
                              size: 16,
                              color: AppTheme.accentOrange,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '฿${price.toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppTheme.accentOrange,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getTimeAgo(
                          context,
                          DateTime.now().difference(createdAt),
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (scheduledAt != null) ...[
                    _ScheduledOrderBanner(scheduledAt: scheduledAt),
                    const SizedBox(height: 14),
                  ],
                  _AddressDistanceBlock(
                    address: order['destination_address'],
                    distanceKm: distanceKm,
                  ),
                  const SizedBox(height: 14),
                  _OrderActionStatus(
                    status: status,
                    orderId: order['id']?.toString() ?? '',
                    onAcceptOrder: onAcceptOrder,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ScheduledOrderBanner extends StatelessWidget {
  const _ScheduledOrderBanner({required this.scheduledAt});

  final DateTime scheduledAt;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final localizations = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.tertiaryContainer.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: colorScheme.tertiary.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 16, color: colorScheme.tertiary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              scheduledAt.isAfter(DateTime.now())
                  ? localizations
                      .merchantScheduledOrder(_formatDateTime(scheduledAt))
                  : localizations.merchantPickupTime(
                      _formatDateTime(scheduledAt),
                    ),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AddressDistanceBlock extends StatelessWidget {
  const _AddressDistanceBlock({
    required this.address,
    required this.distanceKm,
  });

  final dynamic address;
  final double distanceKm;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: colorScheme.errorContainer.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child:
                    Icon(Icons.location_on, size: 14, color: colorScheme.error),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _formatAddress(context, address),
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurface),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (distanceKm > 0) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color:
                        colorScheme.secondaryContainer.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    Icons.straighten,
                    size: 14,
                    color: colorScheme.secondary,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppLocalizations.of(context)!
                      .merchantDistance(distanceKm.toStringAsFixed(1)),
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _OrderActionStatus extends StatelessWidget {
  const _OrderActionStatus({
    required this.status,
    required this.orderId,
    required this.onAcceptOrder,
  });

  final String status;
  final String orderId;
  final ValueChanged<String> onAcceptOrder;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final localizations = AppLocalizations.of(context)!;

    switch (status) {
      case 'pending_merchant':
      case 'pending':
        return Row(
          children: [
            Expanded(
              child: ElevatedButton(
                onPressed:
                    orderId.isEmpty ? null : () => onAcceptOrder(orderId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue,
                  foregroundColor: colorScheme.onPrimary,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  localizations.merchantAcceptOrder,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        );
      case 'preparing':
        return _StatusInfoBox(
          icon: Icons.restaurant,
          color: colorScheme.secondary,
          backgroundColor: colorScheme.secondaryContainer,
          title: localizations.merchantPreparingFood,
          subtitle: localizations.merchantTapForDetails,
        );
      case 'driver_accepted':
        return _StatusInfoBox(
          icon: Icons.person,
          color: colorScheme.primary,
          backgroundColor: colorScheme.primaryContainer,
          title: localizations.merchantDriverAcceptedCard,
          subtitle: localizations.merchantCookingFood,
        );
      case 'matched':
        return _StatusInfoBox(
          icon: Icons.check_circle,
          color: colorScheme.secondary,
          backgroundColor: colorScheme.secondaryContainer,
          title: localizations.merchantDriverMatchedCard,
          subtitle: localizations.merchantTapForDetails,
        );
      case 'traveling_to_merchant':
        return _StatusInfoBox(
          icon: Icons.directions_car,
          color: colorScheme.tertiary,
          backgroundColor: colorScheme.tertiaryContainer,
          title: localizations.merchantDriverTravelingToShop,
          subtitle: localizations.merchantPrepareFood,
        );
      case 'arrived_at_merchant':
        return _StatusInfoBox(
          icon: Icons.store,
          color: colorScheme.tertiary,
          backgroundColor: colorScheme.tertiaryContainer,
          title: localizations.merchantDriverArrivedCard,
          subtitle: localizations.merchantTapForDetails,
        );
      case 'picking_up_order':
        return _StatusInfoBox(
          icon: Icons.delivery_dining,
          color: colorScheme.secondary,
          backgroundColor: colorScheme.secondaryContainer,
          title: localizations.merchantDriverPickingUpCard,
          subtitle: localizations.merchantDeliveringToCustomer,
        );
      case 'in_transit':
        return _StatusInfoBox(
          icon: Icons.local_shipping,
          color: colorScheme.primary,
          backgroundColor: colorScheme.primaryContainer,
          title: localizations.merchantDelivering,
          subtitle: localizations.merchantOrderEnRoute,
        );
      case 'ready_for_pickup':
        return _StatusInfoBox(
          icon: Icons.delivery_dining,
          color: colorScheme.secondary,
          backgroundColor: colorScheme.secondaryContainer,
          title: localizations.merchantDriverPickedUpCard,
          subtitle: localizations.merchantOrderDoneForMerchant,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

class _StatusInfoBox extends StatelessWidget {
  const _StatusInfoBox({
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 14, color: color),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

IconData _getStatusIcon(String status) {
  switch (status) {
    case 'pending_merchant':
    case 'pending':
      return Icons.notifications_active;
    case 'preparing':
      return Icons.restaurant;
    case 'driver_accepted':
    case 'matched':
      return Icons.person_pin_circle;
    case 'arrived_at_merchant':
      return Icons.store;
    case 'ready_for_pickup':
      return Icons.check_circle;
    case 'picking_up_order':
      return Icons.delivery_dining;
    case 'in_transit':
      return Icons.local_shipping;
    case 'completed':
      return Icons.done_all;
    case 'cancelled':
      return Icons.cancel;
    default:
      return Icons.receipt_long;
  }
}

Color _getStatusColor(BuildContext context, String status) {
  final colorScheme = Theme.of(context).colorScheme;
  switch (status) {
    case 'pending_merchant':
      return colorScheme.error;
    case 'pending':
      return colorScheme.tertiary;
    case 'preparing':
      return colorScheme.primary;
    case 'ready_for_pickup':
    case 'driver_accepted':
    case 'matched':
    case 'arrived_at_merchant':
    case 'completed':
      return colorScheme.secondary;
    case 'cancelled':
    default:
      return colorScheme.outline;
  }
}

String _formatAddress(BuildContext context, dynamic address) {
  final localizations = AppLocalizations.of(context)!;
  if (address == null) {
    return localizations.merchantAddressNotSpecified;
  }
  if (address is String) {
    if (address.contains('Instance of') ||
        address.contains('AddressPlacemark')) {
      return localizations.merchantAddressPinLocation;
    }
    return address;
  }
  if (address.toString() == 'Instance of \'AddressPlacemark\'') {
    return localizations.merchantAddressPinLocation;
  }
  return address.toString();
}

String _getTimeAgo(BuildContext context, Duration duration) {
  final localizations = AppLocalizations.of(context)!;
  if (duration.inMinutes < 1) {
    return localizations.merchantTimeJustNow;
  } else if (duration.inMinutes < 60) {
    return localizations.merchantTimeMinutesAgo(duration.inMinutes.toString());
  } else if (duration.inHours < 24) {
    return localizations.merchantTimeHoursAgo(duration.inHours.toString());
  } else {
    return localizations.merchantTimeDaysAgo(duration.inDays.toString());
  }
}

String _formatDateTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final day = local.day.toString().padLeft(2, '0');
  final month = local.month.toString().padLeft(2, '0');
  final year = local.year;
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$day/$month/$year $hour:$minute';
}
