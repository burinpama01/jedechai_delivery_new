import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../common/services/auth_service.dart';
import '../../../l10n/app_localizations.dart';
import '../../../theme/jdc_colors.dart';
import '../../../theme/jdc_layout.dart';

class DriverShiftScreen extends StatefulWidget {
  const DriverShiftScreen({super.key});

  @override
  State<DriverShiftScreen> createState() => _DriverShiftScreenState();
}

class _DriverShiftScreenState extends State<DriverShiftScreen> {
  bool _isLoading = true;
  String? _error;
  bool _isActionLoading = false;

  Map<String, dynamic>? _activeShift;
  List<Map<String, dynamic>> _shiftHistory = [];

  Timer? _timer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final userId = AuthService.userId;
      if (userId == null) throw Exception('User not found');

      // Query active shift (shift_end_at IS NULL)
      final activeResult = await Supabase.instance.client
          .from('driver_shifts')
          .select()
          .eq('driver_id', userId)
          .isFilter('shift_end_at', null)
          .order('shift_start_at', ascending: false)
          .limit(1)
          .maybeSingle();

      // Query 7 days shift history
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
      final historyResult = await Supabase.instance.client
          .from('driver_shifts')
          .select()
          .eq('driver_id', userId)
          .not('shift_end_at', 'is', null)
          .gte('shift_start_at', sevenDaysAgo.toIso8601String())
          .order('shift_start_at', ascending: false);

      if (mounted) {
        setState(() {
          _activeShift = activeResult;
          _shiftHistory = List<Map<String, dynamic>>.from(historyResult);
          _isLoading = false;
        });
        _restartTimer();
      }
      debugLog('🕐 Shift loaded: active=${activeResult != null}, history=${historyResult.length}');
    } catch (e) {
      debugLog('❌ Error loading shift: $e');
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  void _restartTimer() {
    _timer?.cancel();
    _timer = null;
    if (_activeShift == null) {
      setState(() => _elapsed = Duration.zero);
      return;
    }
    final startStr = _activeShift!['shift_start_at'] as String?;
    if (startStr == null) return;
    final start = DateTime.parse(startStr).toLocal();
    _elapsed = DateTime.now().difference(start);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed += const Duration(seconds: 1));
    });
  }

  Future<void> _startShift() async {
    setState(() => _isActionLoading = true);
    try {
      final userId = AuthService.userId;
      if (userId == null) throw Exception('User not found');

      await Supabase.instance.client.from('driver_shifts').insert({
        'driver_id': userId,
        'shift_start_at': DateTime.now().toUtc().toIso8601String(),
      });
      debugLog('✅ Shift started');
      await _loadData();
    } catch (e) {
      debugLog('❌ Error starting shift: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.driverShiftStartError(e.toString())), backgroundColor: context.jdc.danger));
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _endShift() async {
    if (_activeShift == null) return;
    setState(() => _isActionLoading = true);
    try {
      final shiftId = _activeShift!['id'];
      await Supabase.instance.client
          .from('driver_shifts')
          .update({'shift_end_at': DateTime.now().toUtc().toIso8601String()})
          .eq('id', shiftId);
      debugLog('✅ Shift ended: $shiftId');
      await _loadData();
    } catch (e) {
      debugLog('❌ Error ending shift: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(AppLocalizations.of(context)!.driverShiftEndError(e.toString())), backgroundColor: context.jdc.danger));
      }
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  String _formatDuration(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatDateTime(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final dt = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd/MM/yy HH:mm').format(dt);
    } catch (_) { return '-'; }
  }

  Duration _shiftDuration(Map<String, dynamic> shift) {
    final start = shift['shift_start_at'] as String?;
    final end = shift['shift_end_at'] as String?;
    if (start == null || end == null) return Duration.zero;
    try {
      return DateTime.parse(end).difference(DateTime.parse(start));
    } catch (_) { return Duration.zero; }
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
                              child: _buildShiftHistory(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  /// ส่วนหัวสีเข้ม (hero2) ตาม artboard Driver-Shift —
  /// ปุ่มย้อนกลับ 44x44 + ไทต์เติล + ปุ่มรีเฟรช + สถิติย่อย + การ์ดควบคุมกะ
  Widget _buildHeader() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isActive = _activeShift != null;

    // ตัวเลขสรุป 7 วัน คำนวณจากข้อมูลจริงที่โหลดมา (ไม่มีข้อมูลรายเดือน/ตรงเวลา → ดู known gap)
    final weekMinutes = _shiftHistory.fold<int>(
          0,
          (sum, s) => sum + _shiftDuration(s).inMinutes,
        ) + (isActive ? _elapsed.inMinutes : 0);
    final weekShifts = _shiftHistory.length + (isActive ? 1 : 0);
    final weekJobs = _shiftHistory.fold<int>(
      0,
      (sum, s) => sum + ((s['total_jobs'] as num?)?.toInt() ?? 0),
    );

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
                    child: Text(
                      l10n.driverShiftTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _txt(jdc.onPanel, 18, w: 700),
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
              Row(
                children: [
                  Expanded(
                    child: _buildHeroStat(
                      l10n.driverShiftWeeklyHours,
                      l10n.driverShiftHoursMinutes(
                          (weekMinutes ~/ 60).toString(), (weekMinutes % 60).toString()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: _buildHeroStat(l10n.driverShiftWeeklyShifts, '$weekShifts')),
                  const SizedBox(width: 10),
                  Expanded(child: _buildHeroStat(l10n.driverShiftWeeklyJobs, '$weekJobs')),
                ],
              ),
              const SizedBox(height: JdcSpacing.xl),
              _buildShiftControl(),
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

  Widget _buildHeroStat(String label, String value) {
    final jdc = JdcColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: JdcSpacing.md,
        vertical: 11,
      ),
      decoration: BoxDecoration(
        color: jdc.panelSoft,
        borderRadius: BorderRadius.circular(JdcRadius.field),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _txt(jdc.onPanel, 16, w: 700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: _txt(jdc.panelDim, 11),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftControl() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final isActive = _activeShift != null;
    final startStr = _activeShift?['shift_start_at'] as String?;

    return Container(
      padding: const EdgeInsets.all(JdcSpacing.lg),
      decoration: BoxDecoration(
        color: jdc.panelSoft2,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.panelLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isActive ? l10n.driverShiftActive : l10n.driverShiftNotStarted,
                  style: _txt(jdc.panelDim, 12),
                ),
              ),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: jdc.successPanel,
                    borderRadius: BorderRadius.circular(JdcRadius.chip),
                    border: Border.all(color: jdc.successPanelLine),
                  ),
                  child: Text(l10n.driverShiftActiveBadge, style: _txt(jdc.successOnPanel, 11, w: 700)),
                ),
            ],
          ),
          const SizedBox(height: JdcSpacing.xs),
          Text(
            isActive ? _formatDuration(_elapsed) : '--:--:--',
            style: _txt(jdc.onPanel, 34, w: 700, fontFeatures: [
              FontFeature.tabularFigures(),
            ]),
          ),
          if (isActive && startStr != null) ...[
            const SizedBox(height: JdcSpacing.xs),
            Text(
              l10n.driverShiftStartedAt(_formatDateTime(startStr)),
              style: _txt(jdc.panelDim, 12),
            ),
          ],
          const SizedBox(height: JdcSpacing.md),
          SizedBox(
            width: double.infinity,
            height: JdcTouch.button,
            child: ElevatedButton(
              onPressed: _isActionLoading ? null : (isActive ? _endShift : _startShift),
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? jdc.surface : jdc.cta,
                foregroundColor: isActive ? jdc.danger : jdc.onCta,
                disabledBackgroundColor: isActive ? jdc.sunken : jdc.brandSoft2,
                disabledForegroundColor: isActive ? jdc.muted : jdc.brandOnSoft,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(JdcRadius.field),
                  side: isActive ? BorderSide(color: jdc.dangerLine) : BorderSide.none,
                ),
              ),
              child: _isActionLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: isActive ? jdc.danger : jdc.onCta,
                      ),
                    )
                  : Text(
                      isActive ? l10n.driverShiftEnd : l10n.driverShiftStart,
                      style: _txt(isActive ? jdc.danger : jdc.onCta, 17, w: 700),
                    ),
            ),
          ),
        ],
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

  Widget _buildShiftHistory() {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.driverShiftHistoryTitle, style: _txt(jdc.text, 14, w: 700)),
        const SizedBox(height: JdcSpacing.md),
        if (_shiftHistory.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(JdcSpacing.xxxl),
            decoration: BoxDecoration(
              color: jdc.surface,
              borderRadius: BorderRadius.circular(JdcRadius.card),
              border: Border.all(color: jdc.line),
              boxShadow: jdc.shadowCard,
            ),
            child: Column(
              children: [
                Icon(Icons.history, size: 48, color: jdc.muted),
                const SizedBox(height: JdcSpacing.md),
                Text(l10n.driverShiftHistoryEmpty, style: _txt(jdc.muted, 13)),
              ],
            ),
          )
        else
          ...List.generate(_shiftHistory.length, (i) => _buildShiftCard(_shiftHistory[i])),
      ],
    );
  }

  Widget _buildShiftCard(Map<String, dynamic> shift) {
    final jdc = JdcColors.of(context);
    final l10n = AppLocalizations.of(context)!;
    final dur = _shiftDuration(shift);
    final jobs = (shift['total_jobs'] as num?)?.toInt() ?? 0;
    final earnings = (shift['total_earnings'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(JdcSpacing.lg),
      decoration: BoxDecoration(
        color: jdc.surface,
        borderRadius: BorderRadius.circular(JdcRadius.card),
        border: Border.all(color: jdc.line),
        boxShadow: jdc.shadowCard,
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: jdc.sunken,
              borderRadius: BorderRadius.circular(JdcRadius.small),
            ),
            child: Icon(Icons.access_time, size: 19, color: jdc.text),
          ),
          const SizedBox(width: JdcSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_formatDateTime(shift['shift_start_at'] as String?)} → ${_formatDateTime(shift['shift_end_at'] as String?)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _txt(jdc.text, 14, w: 700),
                ),
                const SizedBox(height: 3),
                Text(
                  l10n.driverShiftCardSummary(_formatDuration(dur), jobs.toString()),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: _txt(jdc.muted, 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: JdcSpacing.md),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: jdc.successSoft,
              borderRadius: BorderRadius.circular(JdcRadius.chip),
            ),
            child: Text(
              l10n.driverEarningsBaht(earnings.toStringAsFixed(0)),
              style: _txt(jdc.successInk, 11, w: 700),
            ),
          ),
        ],
      ),
    );
  }
}
