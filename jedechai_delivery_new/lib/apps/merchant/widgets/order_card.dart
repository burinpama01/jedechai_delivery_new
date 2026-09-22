import 'package:flutter/material.dart';

import '../../../common/utils/order_code_formatter.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/jdc_colors.dart';
import '../../../theme/jdc_layout.dart';

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
    final jdc = JdcColors.of(context);
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

    // ออเดอร์ใหม่ = การ์ดทอง (brand-line + shadow-brand) ตาม artboard
    // ออเดอร์อื่น = การ์ดพื้น surface ขอบ line เงาการ์ดปกติ
    final accentFg = isNewOrder ? jdc.brandOnSoft : jdc.text;
    final headerBg = isNewOrder ? jdc.brandSoft : jdc.sunken;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: JdcSpacing.lg),
        decoration: BoxDecoration(
          color: jdc.surface,
          borderRadius: BorderRadius.circular(JdcRadius.card),
          border: Border.all(
            color: isNewOrder ? jdc.brandLine : jdc.line,
          ),
          boxShadow: isNewOrder ? jdc.shadowBrand : jdc.shadowCard,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            // แถบหัวการ์ด: สถานะ + รหัสออเดอร์
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: JdcSpacing.lg,
                vertical: JdcSpacing.sm + 2,
              ),
              color: headerBg,
              child: Row(
                children: [
                  Icon(
                    isNewOrder ? Icons.timer_outlined : _getStatusIcon(status),
                    color: isNewOrder ? jdc.brandOnSoft : jdc.muted,
                    size: 17,
                  ),
                  const SizedBox(width: JdcSpacing.sm - 1),
                  Expanded(
                    child: Text(
                      statusTextBuilder(status),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _jt(fontSize: 12, color: accentFg, weight: 700),
                    ),
                  ),
                  Text(
                    OrderCodeFormatter.format(order['id']?.toString()),
                    style: _jt(
                      fontSize: 12,
                      color: isNewOrder
                          ? jdc.brandOnSoft
                          : jdc.muted.withValues(alpha: 0.85),
                      weight: 700,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(JdcSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: JdcSpacing.md,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: jdc.brandSoft,
                          borderRadius:
                              BorderRadius.circular(JdcRadius.small),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.receipt_long,
                              size: 16,
                              color: jdc.brandOnSoft,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '฿${price.toStringAsFixed(0)}',
                              style: _jt(
                                fontSize: 20,
                                color: jdc.brandOnSoft,
                                weight: 700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: jdc.muted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _getTimeAgo(
                          context,
                          DateTime.now().difference(createdAt),
                        ),
                        style: _jt(fontSize: 12, color: jdc.muted),
                      ),
                    ],
                  ),
                  const SizedBox(height: JdcSpacing.md),
                  if (scheduledAt != null) ...[
                    _ScheduledOrderBanner(scheduledAt: scheduledAt),
                    const SizedBox(height: JdcSpacing.md),
                  ],
                  _AddressDistanceBlock(
                    address: order['destination_address'],
                    distanceKm: distanceKm,
                  ),
                  const SizedBox(height: JdcSpacing.md),
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
    final jdc = JdcColors.of(context);
    final localizations = AppLocalizations.of(context)!;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: JdcSpacing.sm,
        vertical: JdcSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: jdc.infoSoft,
        borderRadius: BorderRadius.circular(JdcRadius.small),
        border: Border.all(color: jdc.line),
      ),
      child: Row(
        children: [
          Icon(Icons.schedule, size: 16, color: jdc.infoInk),
          const SizedBox(width: JdcSpacing.sm),
          Expanded(
            child: Text(
              scheduledAt.isAfter(DateTime.now())
                  ? localizations
                      .merchantScheduledOrder(_formatDateTime(scheduledAt))
                  : localizations.merchantPickupTime(
                      _formatDateTime(scheduledAt),
                    ),
              style: _jt(fontSize: 12, color: jdc.infoInk, weight: 600),
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
    final jdc = JdcColors.of(context);

    return Container(
      padding: const EdgeInsets.all(JdcSpacing.sm),
      decoration: BoxDecoration(
        color: jdc.sunken,
        borderRadius: BorderRadius.circular(JdcRadius.small),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: jdc.dangerSoft,
                  borderRadius: BorderRadius.circular(JdcRadius.small),
                ),
                child: Icon(Icons.location_on, size: 14, color: jdc.danger),
              ),
              const SizedBox(width: JdcSpacing.sm),
              Expanded(
                child: Text(
                  _formatAddress(context, address),
                  style: _jt(fontSize: 12, color: jdc.text),
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
                    color: jdc.infoSoft,
                    borderRadius: BorderRadius.circular(JdcRadius.small),
                  ),
                  child: Icon(
                    Icons.straighten,
                    size: 14,
                    color: jdc.infoInk,
                  ),
                ),
                const SizedBox(width: JdcSpacing.sm),
                Expanded(
                  child: Text(
                    AppLocalizations.of(context)!
                        .merchantDistance(distanceKm.toStringAsFixed(1)),
                    style: _jt(fontSize: 12, color: jdc.muted),
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
    final jdc = JdcColors.of(context);
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
                  backgroundColor: jdc.cta,
                  foregroundColor: jdc.onCta,
                  disabledBackgroundColor: jdc.offTrack,
                  disabledForegroundColor: jdc.onCta,
                  minimumSize: Size.fromHeight(JdcTouch.field),
                  padding: const EdgeInsets.symmetric(vertical: JdcSpacing.md),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(JdcRadius.field),
                  ),
                ),
                child: Text(
                  localizations.merchantAcceptOrder,
                  style: _jt(fontSize: 14, color: jdc.onCta, weight: 700),
                ),
              ),
            ),
          ],
        );
      case 'preparing':
        return _StatusInfoBox(
          icon: Icons.restaurant,
          fg: jdc.infoInk,
          bg: jdc.infoSoft,
          border: jdc.line,
          title: localizations.merchantPreparingFood,
          subtitle: localizations.merchantTapForDetails,
        );
      case 'driver_accepted':
        return _StatusInfoBox(
          icon: Icons.person,
          fg: jdc.successInk,
          bg: jdc.successSoft,
          border: jdc.successLine,
          title: localizations.merchantDriverAcceptedCard,
          subtitle: localizations.merchantCookingFood,
        );
      case 'matched':
        return _StatusInfoBox(
          icon: Icons.check_circle,
          fg: jdc.successInk,
          bg: jdc.successSoft,
          border: jdc.successLine,
          title: localizations.merchantDriverMatchedCard,
          subtitle: localizations.merchantTapForDetails,
        );
      case 'traveling_to_merchant':
        return _StatusInfoBox(
          icon: Icons.directions_car,
          fg: jdc.infoInk,
          bg: jdc.infoSoft,
          border: jdc.line,
          title: localizations.merchantDriverTravelingToShop,
          subtitle: localizations.merchantPrepareFood,
        );
      case 'arrived_at_merchant':
        return _StatusInfoBox(
          icon: Icons.store,
          fg: jdc.successInk,
          bg: jdc.successSoft,
          border: jdc.successLine,
          title: localizations.merchantDriverArrivedCard,
          subtitle: localizations.merchantTapForDetails,
        );
      case 'picking_up_order':
        return _StatusInfoBox(
          icon: Icons.delivery_dining,
          fg: jdc.successInk,
          bg: jdc.successSoft,
          border: jdc.successLine,
          title: localizations.merchantDriverPickingUpCard,
          subtitle: localizations.merchantDeliveringToCustomer,
        );
      case 'in_transit':
        return _StatusInfoBox(
          icon: Icons.local_shipping,
          fg: jdc.infoInk,
          bg: jdc.infoSoft,
          border: jdc.line,
          title: localizations.merchantDelivering,
          subtitle: localizations.merchantOrderEnRoute,
        );
      case 'ready_for_pickup':
        return _StatusInfoBox(
          icon: Icons.delivery_dining,
          fg: jdc.successInk,
          bg: jdc.successSoft,
          border: jdc.successLine,
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
    required this.fg,
    required this.bg,
    required this.border,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final Color fg;
  final Color bg;
  final Color border;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(JdcSpacing.lg),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(JdcRadius.small),
        border: Border.all(color: border),
      ),
      child: Column(
        children: [
          Icon(icon, color: fg, size: 28),
          const SizedBox(height: JdcSpacing.sm),
          Text(
            title,
            style: _jt(fontSize: 15, color: fg, weight: 700),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: _jt(fontSize: 13, color: fg),
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

/// TextStyle มาตรฐานของกลุ่มหน้าออเดอร์ — ผูก fontWeight กับ fontVariations
/// ให้คู่กันเสมอตามธีม JDC
TextStyle _jt({
  double? fontSize,
  Color? color,
  double weight = 400,
  double? height,
  double? letterSpacing,
}) {
  const weightMap = <int, FontWeight>{
    400: FontWeight.w400,
    500: FontWeight.w500,
    600: FontWeight.w600,
    700: FontWeight.w700,
    800: FontWeight.w800,
    900: FontWeight.w900,
  };
  return TextStyle(
    fontSize: fontSize,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
    fontWeight: weightMap[weight.round()] ?? FontWeight.w400,
    fontVariations: [FontVariation('wght', weight)],
  );
}
