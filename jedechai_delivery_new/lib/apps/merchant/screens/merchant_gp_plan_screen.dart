import 'dart:async';

import 'package:flutter/material.dart';

import '../../../common/services/gp_plan_service.dart';
import '../../../theme/app_theme.dart';

/// หน้าจอแพ็กเกจ GP ของร้าน — ดูแพ็กเกจปัจจุบัน และเปลี่ยนเองได้เดือนละ 1 ครั้ง
class MerchantGpPlanScreen extends StatefulWidget {
  const MerchantGpPlanScreen({super.key});

  @override
  State<MerchantGpPlanScreen> createState() => _MerchantGpPlanScreenState();
}

/// ข้อความนับถอยหลัง เช่น "12 วัน 03:21:09" หรือ "03:21:09"
String formatGpCooldown(Duration d) {
  final days = d.inDays;
  final h = d.inHours.remainder(24).toString().padLeft(2, '0');
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return days > 0 ? '$days วัน $h:$m:$s' : '$h:$m:$s';
}

String _pct(num? rate) {
  if (rate == null) return '-';
  final v = rate * 100;
  return v == v.roundToDouble() ? '${v.toInt()}%' : '${v.toStringAsFixed(1)}%';
}

String _num(num? v) {
  if (v == null) return '-';
  return v == v.roundToDouble() ? '${v.toInt()}' : v.toStringAsFixed(1);
}

class _MerchantGpPlanScreenState extends State<MerchantGpPlanScreen> {
  List<Map<String, dynamic>> _plans = [];
  GpPlanStatus? _status;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        GpPlanService.fetchActivePlans(),
        GpPlanService.fetchStatus(),
      ]);
      if (!mounted) return;
      setState(() {
        _plans = results[0] as List<Map<String, dynamic>>;
        _status = results[1] as GpPlanStatus;
        _loading = false;
      });
      _syncTicker();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'โหลดข้อมูลแพ็กเกจไม่สำเร็จ';
      });
    }
  }

  void _syncTicker() {
    _ticker?.cancel();
    final remaining = _status?.remainingCooldown();
    if (remaining == null || remaining == Duration.zero) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final left = _status?.remainingCooldown();
      if (left == null || left == Duration.zero) {
        _ticker?.cancel();
        _load(); // ครบกำหนดแล้ว — ถามสถานะใหม่จาก server
        return;
      }
      setState(() {});
    });
  }

  Future<void> _confirmAndSelect(Map<String, dynamic> plan) async {
    final status = _status;
    if (status == null) return;
    final name = plan['name']?.toString() ?? '';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('เปลี่ยนเป็น $name?'),
        content: Text(
          'หัก GP ${_pct(plan['gp_rate'] as num?)} · ค่าส่ง ${_num(plan['base_delivery_fee'] as num?)} ฿ '
          'ในระยะ ${_num(plan['base_distance_km'] as num?)} กม. เกินคิด ${_num(plan['per_km_charge'] as num?)} ฿/กม.\n\n'
          'มีผลกับออเดอร์ใหม่ทันที'
          '${status.isApproved ? '\nหลังเปลี่ยนแล้ว จะเปลี่ยนได้อีกครั้งในอีก ${status.cooldownDays} วัน' : ''}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('ยืนยันเปลี่ยน'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _saving = true);
    try {
      await GpPlanService.selectPlan(plan['id'].toString());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('เปลี่ยนเป็น $name แล้ว')),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(GpPlanService.errorMessage(e)),
          backgroundColor: Colors.red,
        ),
      );
      await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('แพ็กเกจ GP')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _buildError()
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _buildCurrentCard(),
                      const SizedBox(height: 12),
                      _buildStatusBanner(),
                      const SizedBox(height: 16),
                      Text(
                        'แพ็กเกจทั้งหมด',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      ..._plans.map(_buildPlanCard),
                    ],
                  ),
                ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!),
          const SizedBox(height: 12),
          FilledButton(onPressed: _load, child: const Text('ลองใหม่')),
        ],
      ),
    );
  }

  String? _currentPlanName() {
    final id = _status?.planId;
    if (id == null) return null;
    for (final p in _plans) {
      if (p['id']?.toString() == id) return p['name']?.toString();
    }
    return null;
  }

  Widget _buildCurrentCard() {
    final s = _status!;
    final cs = Theme.of(context).colorScheme;
    final name = s.isCustomDeal
        ? 'เงื่อนไขพิเศษ (ตั้งค่าโดยแอดมิน)'
        : (_currentPlanName() ?? 'ยังไม่ได้เลือกแพ็กเกจ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.primaryGreen.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('แพ็กเกจปัจจุบัน',
              style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
          const SizedBox(height: 4),
          Text(name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('หัก GP ${_pct(s.gpRate)}'),
          Text(
            'ค่าส่ง ${_num(s.baseFare)} ฿ ในระยะ ${_num(s.baseDistanceKm)} กม. '
            '(เกินคิด ${_num(s.perKm)} ฿/กม.)',
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final s = _status!;
    final cs = Theme.of(context).colorScheme;
    IconData icon = Icons.info_outline;
    String text;
    Color tone = cs.primary;

    if (!s.isApproved) {
      text = 'ร้านยังรอการอนุมัติ — เปลี่ยนแพ็กเกจได้จนกว่าจะอนุมัติ '
          'หลังอนุมัติเปลี่ยนได้เดือนละ 1 ครั้ง';
    } else if (s.blockedReason == 'custom_deal') {
      icon = Icons.handshake_outlined;
      text = 'ร้านของคุณใช้เงื่อนไขพิเศษที่ตกลงกับแอดมิน '
          'หากต้องการเปลี่ยนแพ็กเกจ กรุณาติดต่อแอดมิน';
    } else if (s.blockedReason == 'cooldown') {
      icon = Icons.timer_outlined;
      tone = Colors.orange;
      final left = s.remainingCooldown() ?? Duration.zero;
      text = 'เปลี่ยนแพ็กเกจได้อีกครั้งใน ${formatGpCooldown(left)}';
    } else if (s.blockedReason == 'active_orders') {
      icon = Icons.receipt_long_outlined;
      tone = Colors.orange;
      text = 'มีออเดอร์ที่กำลังดำเนินการ — เปลี่ยนแพ็กเกจได้เมื่อออเดอร์เสร็จทั้งหมด';
    } else {
      icon = Icons.check_circle_outline;
      tone = Colors.green;
      text = 'เปลี่ยนแพ็กเกจได้ตอนนี้ (เดือนละ 1 ครั้ง มีผลกับออเดอร์ใหม่ทันที)';
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Icon(icon, color: tone),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final s = _status!;
    final cs = Theme.of(context).colorScheme;
    final isCurrent = plan['id']?.toString() == s.planId;
    final canSelect = !_saving && !isCurrent && s.canChange;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCurrent ? AppTheme.primaryGreen : cs.outlineVariant,
          width: isCurrent ? 2 : 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan['name']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(
                    'หักร้านค้า ${_pct(plan['gp_rate'] as num?)}',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryGreen,
                    ),
                  ),
                  Text(
                    'ค่าส่ง ${_num(plan['base_delivery_fee'] as num?)} ฿ ในระยะ '
                    '${_num(plan['base_distance_km'] as num?)} กม. จากร้าน',
                  ),
                  Text(
                    'เกินระยะคิด ${_num(plan['per_km_charge'] as num?)} ฿/กม.',
                    style: TextStyle(color: cs.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            isCurrent
                ? const Chip(label: Text('ใช้อยู่'))
                : FilledButton(
                    onPressed: canSelect ? () => _confirmAndSelect(plan) : null,
                    child: const Text('เลือก'),
                  ),
          ],
        ),
      ),
    );
  }
}
