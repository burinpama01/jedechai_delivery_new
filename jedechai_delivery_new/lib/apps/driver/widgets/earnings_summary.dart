import 'package:flutter/material.dart';
import '../../../l10n/app_localizations.dart';

/// Compact earnings summary shown in the driver dashboard header.
class EarningsSummary extends StatelessWidget {
  final double todayEarnings;
  final int todayCompletedJobs;
  final int availableJobsCount;
  final Map<String, double> earningsByType;

  const EarningsSummary({
    super.key,
    required this.todayEarnings,
    required this.todayCompletedJobs,
    required this.availableJobsCount,
    this.earningsByType = const {},
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _QuickStat(
              title: l10n.driverDashPendingJobs,
              value: '$availableJobsCount',
              icon: Icons.pending_actions,
              color: Colors.white,
            )),
            const SizedBox(width: 8),
            Expanded(child: _QuickStat(
              title: l10n.driverDashCompletedToday,
              value: '$todayCompletedJobs',
              icon: Icons.check_circle,
              color: Colors.white,
            )),
            const SizedBox(width: 8),
            Expanded(child: _QuickStat(
              title: l10n.driverDashEarningsToday,
              value: '฿${todayEarnings.toStringAsFixed(0)}',
              icon: Icons.payments,
              color: Colors.white,
            )),
          ],
        ),
        if (earningsByType.isNotEmpty) ...[
          const SizedBox(height: 8),
          _EarningsBreakdown(earningsByType: earningsByType),
        ],
      ],
    );
  }
}

class _QuickStat extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _QuickStat({required this.title, required this.value, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 4),
          Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          Text(title, style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.8))),
        ],
      ),
    );
  }
}

class _EarningsBreakdown extends StatelessWidget {
  final Map<String, double> earningsByType;

  const _EarningsBreakdown({required this.earningsByType});

  @override
  Widget build(BuildContext context) {
    const typeInfo = {
      'food': ('🍔', 'อาหาร'),
      'ride': ('🚗', 'เรียกรถ'),
      'parcel': ('📦', 'พัสดุ'),
    };
    final entries = earningsByType.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: entries.map((e) {
          final info = typeInfo[e.key] ?? ('•', e.key);
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(info.$1, style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 4),
              Text(
                '${info.$2} ฿${e.value.toStringAsFixed(0)}',
                style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w500),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
