import 'package:flutter/material.dart';
import '../../../common/models/booking.dart';

/// Displays the list of scheduled (pre-booked) jobs in the driver dashboard.
class ScheduledJobsSection extends StatelessWidget {
  final List<Booking> jobs;
  final bool isLoading;

  const ScheduledJobsSection({
    super.key,
    required this.jobs,
    this.isLoading = false,
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

  String _getServiceLabel(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'food':
        return 'ส่งอาหาร';
      case 'ride':
        return 'รับส่งผู้โดยสาร';
      case 'parcel':
        return 'ส่งพัสดุ';
      default:
        return serviceType;
    }
  }

  String _formatScheduledText(DateTime scheduledAt) {
    final local = scheduledAt.toLocal();
    final thaiMonths = ['', 'ม.ค.', 'ก.พ.', 'มี.ค.', 'เม.ย.', 'พ.ค.', 'มิ.ย.', 'ก.ค.', 'ส.ค.', 'ก.ย.', 'ต.ค.', 'พ.ย.', 'ธ.ค.'];
    final day = local.day;
    final month = thaiMonths[local.month];
    final year = local.year + 543;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day $month $year $hour:$minute น.';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        Row(
          children: [
            Text('งานนัดหมาย',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.amber.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text('${jobs.length}',
                  style: const TextStyle(fontSize: 12, color: Colors.orange, fontWeight: FontWeight.w600)),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (isLoading)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF3B82F6))),
            ),
          )
        else if (jobs.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                Icon(Icons.event_available, size: 40, color: colorScheme.onSurfaceVariant.withValues(alpha: 0.4)),
                const SizedBox(height: 8),
                Text('ไม่มีงานนัดหมาย', style: TextStyle(color: colorScheme.onSurfaceVariant)),
              ],
            ),
          )
        else
          ...jobs.map((job) => _ScheduledJobCard(
                job: job,
                scheduledText: job.scheduledAt != null ? _formatScheduledText(job.scheduledAt!) : '-',
                serviceIcon: _getServiceIcon(job.serviceType),
                serviceColor: _getServiceColor(job.serviceType),
                serviceLabel: _getServiceLabel(job.serviceType),
              )),
      ],
    );
  }
}

class _ScheduledJobCard extends StatelessWidget {
  final Booking job;
  final String scheduledText;
  final IconData serviceIcon;
  final Color serviceColor;
  final String serviceLabel;

  const _ScheduledJobCard({
    required this.job,
    required this.scheduledText,
    required this.serviceIcon,
    required this.serviceColor,
    required this.serviceLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade300.withValues(alpha: 0.5)),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: serviceColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                child: Icon(serviceIcon, color: serviceColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(serviceLabel,
                        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
                    Row(
                      children: [
                        const Icon(Icons.schedule, size: 12, color: Colors.orange),
                        const SizedBox(width: 4),
                        Text(scheduledText,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.orange)),
                      ],
                    ),
                  ],
                ),
              ),
              Text('฿${job.price.toStringAsFixed(0)}',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green[700])),
            ],
          ),
          if (job.pickupAddress != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    job.pickupAddress ?? '-',
                    style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
