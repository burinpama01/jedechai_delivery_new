import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/services/auth_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/jdc_colors.dart';
import '../../../theme/jdc_layout.dart';

class DriverPerformanceScreen extends StatefulWidget {
  const DriverPerformanceScreen({super.key});

  @override
  State<DriverPerformanceScreen> createState() => _DriverPerformanceScreenState();
}

class _DriverPerformanceScreenState extends State<DriverPerformanceScreen> {
  bool _isLoading = true;
  String? _error;

  double _averageRating = 0;
  double _acceptanceRate = 0;
  double _completionRate = 0;
  int _totalCompletedJobs = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final userId = AuthService.userId;
      if (userId == null) throw Exception('User not found');

      final profile = await Supabase.instance.client
          .from('profiles')
          .select('average_rating, acceptance_rate, completion_rate, total_completed_jobs')
          .eq('id', userId)
          .maybeSingle();

      if (mounted) {
        setState(() {
          _averageRating = (profile?['average_rating'] as num?)?.toDouble() ?? 0;
          _acceptanceRate = (profile?['acceptance_rate'] as num?)?.toDouble() ?? 0;
          _completionRate = (profile?['completion_rate'] as num?)?.toDouble() ?? 0;
          _totalCompletedJobs = (profile?['total_completed_jobs'] as num?)?.toInt() ?? 0;
          _isLoading = false;
        });
      }
      debugLog('📊 Performance loaded: rating=$_averageRating, completion=$_completionRate%');
    } catch (e) {
      debugLog('❌ Error loading performance: $e');
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  String _getBadgeLevel() {
    if (_totalCompletedJobs >= 500) return 'Platinum';
    if (_totalCompletedJobs >= 200) return 'Gold';
    if (_totalCompletedJobs >= 50) return 'Silver';
    return 'Bronze';
  }

  /// สีของระดับ — ใช้ token เชิงความหมายของ JDC เท่านั้น
  Color _getBadgeColor(JdcColors jdc) {
    switch (_getBadgeLevel()) {
      case 'Platinum': return jdc.infoInk;
      case 'Gold': return jdc.brandOnSoft;
      case 'Silver': return jdc.muted;
      default: return jdc.link;
    }
  }

  int _getBadgeNextTarget() {
    if (_totalCompletedJobs >= 500) return 500;
    if (_totalCompletedJobs >= 200) return 500;
    if (_totalCompletedJobs >= 50) return 200;
    return 50;
  }

  /// สร้าง TextStyle พร้อม fontVariations คู่กับ fontWeight ตามกฎดีไซน์
  TextStyle _txt(
    Color color,
    double size, {
    double w = 400,
    double? height,
    List<FontFeature>? fontFeatures,
  }) {
    return TextStyle(
      color: color,
      fontSize: size,
      height: height,
      fontWeight: FontWeight.values[(w.round() ~/ 100) - 1],
      fontVariations: [FontVariation('wght', w)],
      fontFeatures: fontFeatures,
    );
  }

  @override
  Widget build(BuildContext context) {
    final jdc = JdcColors.of(context);
    return Scaffold(
      backgroundColor: jdc.paper,
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: jdc.cta))
          : _error != null
              ? _buildErrorState()
              : Column(
                  children: [
                    _buildHeader(),
                    Expanded(
                      child: RefreshIndicator(
                        onRefresh: _loadData,
                        color: jdc.cta,
                        child: SingleChildScrollView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          child: JdcContentFrame(
                            child: Padding(
                              padding: const EdgeInsets.only(
                                top: JdcSpacing.lg,
                                bottom: JdcSpacing.xxl,
                              ),
                              child: _buildMetrics(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  /// ส่วนหัวสีเข้ม (hero2) ตาม artboard Driver-Performance —
  /// ปุ่มย้อนกลับ + ไทต์เติล + การ์ดคะแนนบนพื้นเข้ม
  Widget _buildHeader() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final rating = _averageRating.clamp(0.0, 5.0);

    return Container(
      decoration: BoxDecoration(gradient: jdc.hero2),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            JdcSpacing.xl, JdcSpacing.lg, JdcSpacing.xl, JdcSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _buildBackButton(),
                  const SizedBox(width: JdcSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.driverPerfTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _txt(jdc.onPanel, 18, w: 700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          l10n.driverPerfBadgeLevel(_getBadgeLevel()),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: _txt(jdc.panelDim, 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.driverDashRefresh,
                    icon: Icon(Icons.refresh, color: jdc.onPanel),
                    onPressed: _loadData,
                  ),
                ],
              ),
              const SizedBox(height: JdcSpacing.xl),
              Container(
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
                          Text(l10n.driverPerfAvgRating, style: _txt(jdc.panelDim, 12)),
                          const SizedBox(height: 3),
                          Text(
                            rating.toStringAsFixed(2),
                            style: _txt(jdc.onPanel, 26, w: 700, fontFeatures: [
                              FontFeature.tabularFigures(),
                            ]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: JdcSpacing.md),
                    Row(
                      children: [
                        Icon(Icons.star, size: 14, color: jdc.brandHi),
                        const SizedBox(width: 5),
                        Text(l10n.driverPerfOutOfFive, style: _txt(jdc.brandHi, 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBackButton() {
    final jdc = JdcColors.of(context);
    return SizedBox(
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
          child: Icon(Icons.chevron_left, size: 20, color: jdc.onPanel),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(JdcSpacing.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: jdc.danger),
            const SizedBox(height: JdcSpacing.lg),
            Text(l10n.activityLoadFailed, style: _txt(jdc.text, 16, w: 700)),
            const SizedBox(height: JdcSpacing.sm),
            Text(
              _error ?? '',
              style: _txt(jdc.muted, 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: JdcSpacing.xl),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.earnRetry),
              style: ElevatedButton.styleFrom(
                backgroundColor: jdc.cta,
                foregroundColor: jdc.onCta,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(JdcRadius.field),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// การ์ดตัวชี้วัดตาม artboard — แถวชื่อ+คำใบ้ กับค่าทางขวา
  /// (กราฟแท่งรายวัน/รีวิวล่าสุดใน artboard ยังไม่มีข้อมูลรองรับ → known gap)
  Widget _buildMetrics() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final next = _getBadgeNextTarget();
    final badgeHint = _totalCompletedJobs >= 500
        ? l10n.driverPerfMaxLevel
        : l10n.driverPerfBadgeProgress(
            _totalCompletedJobs.toString(), next.toString());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.driverPerfMetrics, style: _txt(jdc.text, 14, w: 700)),
        const SizedBox(height: JdcSpacing.md),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: JdcSpacing.lg,
            vertical: JdcSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: jdc.surface,
            borderRadius: BorderRadius.circular(JdcRadius.card),
            border: Border.all(color: jdc.line),
            boxShadow: jdc.shadowCard,
          ),
          child: Column(
            children: [
              _buildMetricRow(
                l10n.driverPerfAcceptanceRate,
                l10n.driverPerfTarget90,
                '${_acceptanceRate.toStringAsFixed(1)}%',
                jdc.successInk,
              ),
              const SizedBox(height: JdcSpacing.md),
              _buildMetricRow(
                l10n.driverPerfCompletionRate,
                l10n.driverPerfCompletionRateHint,
                '${_completionRate.toStringAsFixed(1)}%',
                jdc.successInk,
              ),
              const SizedBox(height: JdcSpacing.md),
              _buildMetricRow(
                l10n.driverPerfTotalCompleted,
                l10n.driverPerfTotalCompletedHint,
                l10n.driverPerfJobsCount(_totalCompletedJobs.toString()),
                jdc.successInk,
              ),
              const SizedBox(height: JdcSpacing.md),
              _buildMetricRow(
                l10n.driverPerfLevel,
                badgeHint,
                _getBadgeLevel(),
                _getBadgeColor(jdc),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricRow(String label, String hint, String value, Color valueColor) {
    final jdc = JdcColors.of(context);
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: _txt(jdc.text, 13, w: 700)),
              const SizedBox(height: 2),
              Text(
                hint,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _txt(jdc.muted, 12),
              ),
            ],
          ),
        ),
        const SizedBox(width: JdcSpacing.md),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: _txt(valueColor, 15, w: 700),
        ),
      ],
    );
  }
}
