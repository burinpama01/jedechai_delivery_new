import 'package:flutter/material.dart';
import '../../../common/models/booking.dart';
import '../../../common/models/coupon.dart';
import '../../../common/utils/app_time.dart';
import '../../../l10n/app_localizations.dart';

/// Job card displayed in the driver dashboard job feed.
class JobCard extends StatelessWidget {
  final Booking job;
  final double couponDiscount;
  final String? couponCode;
  final bool isAccepting;
  final VoidCallback? onAccept;
  final VoidCallback? onNavigate;

  const JobCard({
    super.key,
    required this.job,
    this.couponDiscount = 0,
    this.couponCode,
    this.isAccepting = false,
    this.onAccept,
    this.onNavigate,
  });

  IconData _getServiceIcon(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'ride':
      case 'taxi':
        return Icons.motorcycle;
      case 'delivery':
      case 'parcel':
        return Icons.local_shipping;
      case 'food':
        return Icons.restaurant;
      default:
        return Icons.directions_car;
    }
  }

  Color _getServiceColor(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'ride':
      case 'taxi':
        return Colors.blue;
      case 'delivery':
      case 'parcel':
        return Colors.orange;
      case 'food':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  String _getServiceLabel(BuildContext context, String serviceType) {
    final l10n = AppLocalizations.of(context)!;
    switch (serviceType.toLowerCase()) {
      case 'food':
        return l10n.driverDashJobFood;
      case 'ride':
        return l10n.driverDashJobRide;
      case 'parcel':
        return l10n.driverDashJobParcel;
      default:
        return l10n.driverDashJobGeneral;
    }
  }

  String _getJobTypeText(BuildContext context, String? serviceType) {
    final l10n = AppLocalizations.of(context)!;
    switch (serviceType) {
      case 'food':
        return l10n.driverDashJobFood;
      case 'ride':
        return l10n.driverDashJobRide;
      case 'parcel':
        return l10n.driverDashJobParcel;
      default:
        return l10n.driverDashJobGeneral;
    }
  }

  String _formatTimeAgo(BuildContext context, Duration duration) {
    final l10n = AppLocalizations.of(context)!;
    if (duration.inMinutes < 1) return l10n.driverDashTimeJustNow;
    if (duration.inMinutes < 60) return l10n.driverDashTimeMinutes(duration.inMinutes.toString());
    if (duration.inHours < 24) return l10n.driverDashTimeHours(duration.inHours.toString());
    return l10n.driverDashTimeDays(duration.inDays.toString());
  }

  String _formatScheduledDateTime(DateTime dateTime) {
    return AppTime.formatBangkokDateTime(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final timeAgo = _formatTimeAgo(context, DateTime.now().difference(job.createdAt));
    final serviceIcon = _getServiceIcon(job.serviceType);
    final serviceColor = _getServiceColor(job.serviceType);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.grey.withValues(alpha: 0.1), blurRadius: 4, spreadRadius: 1),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: serviceColor.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(serviceIcon, color: serviceColor, size: 19),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_getJobTypeText(context, job.serviceType),
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: serviceColor)),
                      Text(_getServiceLabel(context, job.serviceType),
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                    ],
                  ),
                ),
                Text(timeAgo, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
              ],
            ),

            const SizedBox(height: 10),

            // Scheduled banner
            if (job.scheduledAt != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.schedule, size: 18, color: Colors.orange),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        job.scheduledAt!.isAfter(DateTime.now())
                            ? l10n.driverDashScheduledFrom(_formatScheduledDateTime(job.scheduledAt!))
                            : l10n.driverDashScheduledAt(_formatScheduledDateTime(job.scheduledAt!)),
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Financial summary
            _FinancialSummary(
              job: job,
              couponDiscount: couponDiscount,
              couponCode: couponCode,
            ),

            const SizedBox(height: 10),

            // Route
            Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.serviceType == 'food' ? l10n.driverDashPickupRestaurant : l10n.driverDashPickupPoint,
                            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            job.pickupAddress ?? (job.serviceType == 'food' ? l10n.driverDashPickupFoodFallback : l10n.driverDashPickupRideFallback),
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 7),
                  child: Container(width: 2, height: 14, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.35)),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            job.serviceType == 'food' ? l10n.driverDashDestCustomer : l10n.driverDashDestPoint,
                            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            job.destinationAddress ?? l10n.driverDashDestFallback,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: colorScheme.onSurface),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 10),

            // Action buttons
            _ActionButtons(
              job: job,
              isAccepting: isAccepting,
              onAccept: onAccept,
              onNavigate: onNavigate,
            ),
          ],
        ),
      ),
    );
  }
}

class _FinancialSummary extends StatelessWidget {
  final Booking job;
  final double couponDiscount;
  final String? couponCode;

  const _FinancialSummary({required this.job, required this.couponDiscount, this.couponCode});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;
    final normalizedCode = couponCode?.trim().toUpperCase();
    final hideCouponBreakdown = Coupon.isSystemCouponCode(normalizedCode);

    if (job.serviceType == 'food') {
      final foodPrice = job.price;
      final deliveryFee = job.deliveryFee ?? 0;
      final gross = foodPrice + deliveryFee;
      final totalCollect = (gross - couponDiscount) < 0 ? 0.0 : (gross - couponDiscount);

      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.65)),
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(l10n.driverDashCollectCustomer,
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                Text('฿${totalCollect.toStringAsFixed(0)}',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green[700])),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(child: _MiniDetail(label: l10n.driverDashFoodCost, value: '฿${foodPrice.toStringAsFixed(0)}', color: Colors.orange)),
                const SizedBox(width: 8),
                Expanded(child: _MiniDetail(label: l10n.driverDashDeliveryFee, value: '฿${deliveryFee.toStringAsFixed(0)}', color: Colors.blue)),
                const SizedBox(width: 8),
                Expanded(child: _MiniDetail(label: l10n.driverDashDistance, value: l10n.driverDashDistanceKm(job.distanceKm.toStringAsFixed(1)), color: Colors.grey)),
              ],
            ),
            if (couponDiscount > 0) ...[
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(Icons.local_offer, size: 14, color: Colors.green[600]),
                  const SizedBox(width: 4),
                  Text(
                    hideCouponBreakdown
                        ? l10n.driverDashCouponDiscount(couponDiscount.toStringAsFixed(0))
                        : l10n.driverDashCouponDiscountCode(couponDiscount.toStringAsFixed(0)),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green[700]),
                  ),
                ],
              ),
            ],
          ],
        ),
      );
    } else {
      final netCollect = (job.price - couponDiscount) < 0 ? 0.0 : (job.price - couponDiscount);
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: colorScheme.outlineVariant.withValues(alpha: 0.65)),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l10n.driverDashCollectCustomer,
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                      Text('฿${netCollect.toStringAsFixed(0)}',
                          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green[700])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(color: colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(20)),
                  child: Text(l10n.driverDashDistanceKm(job.distanceKm.toStringAsFixed(1)),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                ),
              ],
            ),
            if (couponDiscount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Icon(Icons.local_offer, size: 14, color: Colors.green[600]),
                    const SizedBox(width: 4),
                    Text(
                      hideCouponBreakdown
                          ? l10n.driverDashCouponDiscount(couponDiscount.toStringAsFixed(0))
                          : l10n.driverDashCouponDiscountCode(couponDiscount.toStringAsFixed(0)),
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green[700]),
                    ),
                  ],
                ),
              ),
          ],
        ),
      );
    }
  }
}

class _MiniDetail extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniDetail({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final Booking job;
  final bool isAccepting;
  final VoidCallback? onAccept;
  final VoidCallback? onNavigate;

  const _ActionButtons({required this.job, required this.isAccepting, this.onAccept, this.onNavigate});

  String _formatScheduledDateTime(DateTime dateTime) {
    return AppTime.formatBangkokDateTime(dateTime);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isScheduledLocked = job.scheduledAt != null && job.scheduledAt!.isAfter(DateTime.now());

    switch (job.status) {
      case 'pending':
        if (job.serviceType != 'ride' && job.serviceType != 'parcel') return const SizedBox.shrink();
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (isAccepting || isScheduledLocked) ? null : onAccept,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              isScheduledLocked
                  ? l10n.driverDashAcceptAt(_formatScheduledDateTime(job.scheduledAt!))
                  : (job.serviceType == 'parcel' ? l10n.driverDashAcceptParcel : l10n.driverDashAcceptRide),
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        );

      case 'preparing':
        if (job.serviceType != 'food') return const SizedBox.shrink();
        return SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: (isAccepting || isScheduledLocked) ? null : onAccept,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3B82F6),
              foregroundColor: Colors.white,
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              isScheduledLocked
                  ? l10n.driverDashAcceptAt(_formatScheduledDateTime(job.scheduledAt!))
                  : l10n.driverDashAcceptFood,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        );

      case 'matched':
      case 'accepted':
      case 'driver_accepted':
      case 'ready_for_pickup':
      case 'traveling_to_merchant':
      case 'arrived_at_merchant':
      case 'picking_up_order':
      case 'in_transit':
        return Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                children: [
                  Icon(Icons.check_circle, color: Colors.blue[600], size: 32),
                  const SizedBox(height: 8),
                  Text(l10n.driverDashIncompleteJob,
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.blue[700]),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 4),
                  Text(l10n.driverDashInProgress,
                      style: TextStyle(fontSize: 14, color: Colors.blue[600]), textAlign: TextAlign.center),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: onNavigate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF3B82F6),
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(l10n.driverDashGoToNav, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
