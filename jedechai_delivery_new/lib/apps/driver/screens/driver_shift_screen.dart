import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../../common/services/auth_service.dart';

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
          SnackBar(content: Text('เริ่มกะไม่สำเร็จ: $e'), backgroundColor: Colors.red));
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
          SnackBar(content: Text('หยุดกะไม่สำเร็จ: $e'), backgroundColor: Colors.red));
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

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('การจัดการกะ'),
        backgroundColor: AppTheme.accentBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentBlue)))
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppTheme.accentBlue,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      children: [
                        _buildShiftControl(),
                        _buildShiftHistory(),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            const Text('โหลดข้อมูลไม่สำเร็จ',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 13),
                textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
              style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accentBlue, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShiftControl() {
    final colorScheme = Theme.of(context).colorScheme;
    final isActive = _activeShift != null;
    final startStr = _activeShift?['shift_start_at'] as String?;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isActive
              ? [Colors.green[700]!, Colors.green[500]!]
              : [AppTheme.accentBlue, AppTheme.accentBlue.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isActive ? Colors.green : AppTheme.accentBlue).withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isActive ? Icons.work : Icons.work_off,
                  color: Colors.white,
                  size: 28,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isActive ? 'กะปัจจุบัน' : 'ยังไม่ได้เริ่มกะ',
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13),
                    ),
                    Text(
                      isActive ? _formatDuration(_elapsed) : '--:--:--',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold,
                          fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isActive && startStr != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'เริ่มเมื่อ ${_formatDateTime(startStr)}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isActionLoading ? null : (isActive ? _endShift : _startShift),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: isActive ? Colors.green[700] : AppTheme.accentBlue,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _isActionLoading
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        valueColor: AlwaysStoppedAnimation<Color>(
                            isActive ? Colors.green[700]! : AppTheme.accentBlue),
                      ),
                    )
                  : Text(
                      isActive ? 'หยุดกะ' : 'เริ่มกะ',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShiftHistory() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('ประวัติกะ 7 วัน',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
          const SizedBox(height: 12),
          if (_shiftHistory.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(Icons.history, size: 48,
                      color: colorScheme.onSurfaceVariant.withValues(alpha: 0.45)),
                  const SizedBox(height: 12),
                  Text('ยังไม่มีประวัติกะ',
                      style: TextStyle(color: colorScheme.onSurfaceVariant)),
                ],
              ),
            )
          else
            ...List.generate(_shiftHistory.length, (i) => _buildShiftCard(_shiftHistory[i])),
        ],
      ),
    );
  }

  Widget _buildShiftCard(Map<String, dynamic> shift) {
    final colorScheme = Theme.of(context).colorScheme;
    final dur = _shiftDuration(shift);
    final jobs = (shift['total_jobs'] as num?)?.toInt() ?? 0;
    final earnings = (shift['total_earnings'] as num?)?.toDouble() ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.access_time, size: 16, color: AppTheme.accentBlue),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  '${_formatDateTime(shift['shift_start_at'] as String?)} → ${_formatDateTime(shift['shift_end_at'] as String?)}',
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurface, fontWeight: FontWeight.w500),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _buildShiftStat('ระยะเวลา', _formatDuration(dur), Icons.timer_outlined, Colors.blue)),
              const SizedBox(width: 10),
              Expanded(child: _buildShiftStat('งานทั้งหมด', '$jobs ครั้ง', Icons.work_outline, Colors.orange)),
              const SizedBox(width: 10),
              Expanded(child: _buildShiftStat('รายได้', '฿${earnings.toStringAsFixed(0)}', Icons.payments_outlined, Colors.green)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildShiftStat(String label, String value, IconData icon, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: TextStyle(fontSize: 10, color: colorScheme.onSurfaceVariant)),
      ],
    );
  }
}
