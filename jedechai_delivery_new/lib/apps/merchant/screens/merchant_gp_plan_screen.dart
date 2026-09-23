import 'dart:async';

import 'package:flutter/material.dart';
import '../../../theme/jdc_colors.dart';
import '../../../theme/jdc_layout.dart';

import '../../../common/services/gp_plan_service.dart';
import '../../../l10n/app_localizations.dart';

/// หน้าจอแผน GP ของร้าน — artboard Merchant-GpPlan
/// Layout: panel header (พื้นเข้ม) + current plan card + list of plans + bottom button
class MerchantGpPlanScreen extends StatefulWidget {
  /// Fixture สำหรับ dev_preview เท่านั้น — ไม่กระทบ production เพราะ default null
  final List<Map<String, dynamic>>? fixturePlans;
  final GpPlanStatus? fixtureStatus;

  const MerchantGpPlanScreen({
    super.key,
    this.fixturePlans,
    this.fixtureStatus,
  });

  @override
  State<MerchantGpPlanScreen> createState() => _MerchantGpPlanScreenState();
}

/// ข้อความนับถอยหลัง เช่น "12 วัน 03:21:09"
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

/// ส่วนต่าง GP พร้อมเครื่องหมาย (+5% / -7%)
String _signedPct(num? diff) {
  final text = _pct(diff);
  return diff != null && diff > 0 ? '+$text' : text;
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
    // Fixture override สำหรับ dev_preview
    if (widget.fixturePlans != null && widget.fixtureStatus != null) {
      setState(() {
        _plans = widget.fixturePlans!;
        _status = widget.fixtureStatus;
        _loading = false;
        _error = null;
      });
      return;
    }
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
        _error = AppLocalizations.of(context)!.gpPlanLoadFailed;
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
        _load();
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
        title: Text(AppLocalizations.of(ctx)!.gpPlanConfirmTitle(name)),
        content: Text(
          AppLocalizations.of(ctx)!.gpPlanConfirmBody(
                _pct(plan['gp_rate'] as num?),
                _num(plan['base_delivery_fee'] as num?),
                _num(plan['base_distance_km'] as num?),
                _num(plan['per_km_charge'] as num?),
              ) +
              (status.isApproved
                  ? '\n${AppLocalizations.of(ctx)!.gpPlanConfirmCooldown(status.cooldownDays.toString())}'
                  : ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(ctx)!.gpPlanConfirmCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(ctx)!.gpPlanConfirmOk),
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
        SnackBar(content: Text(AppLocalizations.of(context)!.gpPlanChanged(name))),
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(GpPlanService.errorMessage(e)),
          backgroundColor: JdcColors.of(context).danger,
        ),
      );
      await _load();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ─── helpers ────────────────────────────────────────────────────────────────

  TextStyle _txt(Color color, double size, {double w = 400, double? height}) {
    return TextStyle(
      color: color,
      fontSize: size,
      height: height,
      fontWeight: FontWeight.values[(w.round() ~/ 100) - 1],
      fontVariations: [FontVariation('wght', w)],
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

  // ─── layout ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    return Scaffold(
      backgroundColor: jdc.paper,
      body: _loading
          ? Column(
              children: [
                _buildPanelHeader(null),
                Expanded(
                  child: Center(child: CircularProgressIndicator(color: jdc.cta)),
                ),
              ],
            )
          : _error != null
              ? Column(
                  children: [
                    _buildPanelHeader(null),
                    Expanded(child: _buildError()),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildPanelHeader(_status),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _load,
                        color: jdc.cta,
                        child: _buildPlanList(),
                      ),
                    ),
                    _buildBottomBar(),
                  ],
                ),
    );
  }

  /// Panel header: พื้น panel (เข้ม) + ปุ่มย้อนกลับ + title + subtitle + current plan card
  Widget _buildPanelHeader(GpPlanStatus? status) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Container(
      color: jdc.panel,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              JdcSpacing.xl, JdcSpacing.lg + 2, JdcSpacing.xl, JdcSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // แถว: ปุ่มย้อนกลับ + title column
              Row(
                children: [
                  SizedBox(
                    width: JdcTouch.minTarget,
                    height: JdcTouch.minTarget,
                    child: Material(
                      color: jdc.panelSoft2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(JdcRadius.field),
                        side: BorderSide(color: jdc.panelLine),
                      ),
                      child: InkWell(
                        onTap: () => Navigator.of(context).maybePop(),
                        borderRadius: BorderRadius.circular(JdcRadius.field),
                        child: Icon(Icons.chevron_left,
                            size: 20, color: jdc.onPanel),
                      ),
                    ),
                  ),
                  const SizedBox(width: JdcSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.gpPlanTitle,
                            style: _txt(jdc.onPanel, 18, w: 700)),
                        const SizedBox(height: 2),
                        Text(l10n.gpPlanSubtitle,
                            style: _txt(jdc.panelDim, 12)),
                      ],
                    ),
                  ),
                ],
              ),
              if (status != null) ...[
                const SizedBox(height: JdcSpacing.lg),
                _buildCurrentPlanCard(status),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// การ์ดแผนปัจจุบันใน panel header
  Widget _buildCurrentPlanCard(GpPlanStatus status) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    // ชื่อแผน: ถ้าเป็น custom deal ใช้ข้อความพิเศษ ถ้าไม่มีแผนใช้ข้อความ fallback
    // ไม่ต่อ GP% ท้ายชื่อเพราะชื่อแผนในระบบมักมี GP อยู่แล้ว เช่น "มาตรฐาน · GP 18%"
    final name = status.isCustomDeal
        ? l10n.gpPlanCustomDealName
        : (_currentPlanName() ?? l10n.gpPlanNoneSelected);
    return Container(
      padding: const EdgeInsets.all(JdcSpacing.lg),
      decoration: BoxDecoration(
        color: jdc.panelSoft2,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.panelLine),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.gpPlanCurrentLabel,
                    style: _txt(jdc.panelDim, 12)),
                const SizedBox(height: 3),
                Text(
                  name,
                  style: _txt(jdc.onPanel, 22, w: 700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: JdcSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(
                horizontal: JdcSpacing.sm + 3, vertical: 6),
            decoration: BoxDecoration(
              color: jdc.successPanel,
              borderRadius: BorderRadius.circular(JdcRadius.chip),
              border: Border.all(color: jdc.successPanelLine),
            ),
            child: Text(l10n.gpPlanActiveStatus,
                style: _txt(jdc.successOnPanel, 11, w: 700)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanList() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
          JdcSpacing.xl, JdcSpacing.md, JdcSpacing.xl, JdcSpacing.lg),
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // status banner (cooldown / blocked reason / can change)
        _buildStatusBanner(),
        const SizedBox(height: JdcSpacing.md),
        // available plans header
        Text(l10n.gpPlanAvailableTitle,
            style: _txt(jdc.text, 14, w: 700)),
        const SizedBox(height: JdcSpacing.sm),
        ..._plans.map(_buildPlanCard),
        const SizedBox(height: JdcSpacing.sm),
        // info note
      ],
    );
  }

  Widget _buildError() {
    final jdc = JdcColors.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(_error!),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _load,
            style: FilledButton.styleFrom(backgroundColor: jdc.cta),
            child: Text(AppLocalizations.of(context)!.accountRetry),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner() {
    final s = _status!;
    final jdc = JdcColors.of(context);
    IconData icon = Icons.info_outline;
    String text;
    Color tone = jdc.successInk;
    Color toneBg = jdc.successSoft;

    if (!s.isApproved) {
      text = AppLocalizations.of(context)!.gpPlanBannerPendingApproval;
    } else if (s.blockedReason == 'custom_deal') {
      icon = Icons.handshake_outlined;
      text = AppLocalizations.of(context)!.gpPlanBannerCustomDeal;
      tone = jdc.muted;
      toneBg = jdc.sunken;
    } else if (s.blockedReason == 'cooldown') {
      icon = Icons.timer_outlined;
      tone = jdc.cta;
      toneBg = jdc.brandSoft;
      final left = s.remainingCooldown() ?? Duration.zero;
      text = AppLocalizations.of(context)!.gpPlanBannerCooldown(formatGpCooldown(left));
    } else if (s.blockedReason == 'active_orders') {
      icon = Icons.receipt_long_outlined;
      tone = jdc.cta;
      toneBg = jdc.brandSoft;
      text = AppLocalizations.of(context)!.gpPlanBannerActiveOrders;
    } else {
      icon = Icons.check_circle_outline;
      text = AppLocalizations.of(context)!.gpPlanBannerCanChange;
    }

    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: JdcSpacing.md, vertical: JdcSpacing.md),
      decoration: BoxDecoration(
        color: toneBg,
        borderRadius: BorderRadius.circular(JdcRadius.small),
        border: Border.all(color: jdc.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: tone),
          const SizedBox(width: JdcSpacing.sm),
          Expanded(
            child: Text(
              text,
              style: _txt(tone, 12, height: 1.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard(Map<String, dynamic> plan) {
    final s = _status!;
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isCurrent = plan['id']?.toString() == s.planId;
    final canSelect = !_saving && !isCurrent && s.canChange;
    final gpRate = plan['gp_rate'] as num?;

    return GestureDetector(
      onTap: canSelect ? () => _confirmAndSelect(plan) : null,
      child: Container(
        margin: const EdgeInsets.only(bottom: JdcSpacing.md),
        padding: const EdgeInsets.all(JdcSpacing.md + 2),
        decoration: BoxDecoration(
          color: jdc.surface,
          borderRadius: BorderRadius.circular(JdcRadius.card),
          border: Border.all(
            color: isCurrent ? jdc.brandLine : jdc.line,
          ),
          boxShadow: isCurrent ? jdc.shadowBrand : jdc.shadowCard,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    plan['name']?.toString() ?? '',
                    style: _txt(jdc.text, 14, w: 700),
                  ),
                ),
                if (isCurrent)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: JdcSpacing.sm + 2, vertical: 5),
                    decoration: BoxDecoration(
                      color: jdc.brandSoft,
                      borderRadius: BorderRadius.circular(JdcRadius.chip),
                    ),
                    child: Text(l10n.gpPlanCurrentBadge,
                        style: _txt(jdc.brandOnSoft, 11, w: 700)),
                  )
                else
                  Text(
                    _signedPct((gpRate != null && s.gpRate != null) ? gpRate - s.gpRate! : null),
                    style: _txt(jdc.muted, 13, w: 700),
                  ),
              ],
            ),
            const SizedBox(height: JdcSpacing.sm),
            Text(
              plan['description']?.toString() ??
                  'ค่าส่ง ${_num(plan['base_delivery_fee'] as num?)} ฿ '
                  'ในระยะ ${_num(plan['base_distance_km'] as num?)} กม. '
                  'เกิน ${_num(plan['per_km_charge'] as num?)} ฿/กม.',
              style: _txt(jdc.muted, 12, height: 1.5),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final canChange = _status?.canChange ?? false;
    final selectable = _plans
        .where((p) => p['id']?.toString() != _status?.planId)
        .toList();
    // ปุ่มนี้เป็นทางลัดเมื่อมีแผนให้เปลี่ยนแผนเดียว — หลายแผนให้แตะการ์ดในลิสต์
    if (selectable.length != 1) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: jdc.surface,
        border: Border(top: BorderSide(color: jdc.line)),
        boxShadow: jdc.shadowSheet,
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              JdcSpacing.xl, JdcSpacing.md, JdcSpacing.xl, JdcSpacing.xl),
          child: SizedBox(
            width: double.infinity,
            height: JdcTouch.button,
            child: OutlinedButton(
              onPressed: canChange && !_saving
                  ? () => _confirmAndSelect(selectable.first)
                  : null,
              style: OutlinedButton.styleFrom(
                foregroundColor: jdc.text,
                side: BorderSide(
                    color: canChange ? jdc.line : jdc.line.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(JdcRadius.card),
                ),
              ),
              child: Text(l10n.gpPlanRequestChangeBtn,
                  style: _txt(
                    canChange ? jdc.text : jdc.muted,
                    15,
                    w: 700,
                  )),
            ),
          ),
        ),
      ),
    );
  }
}
