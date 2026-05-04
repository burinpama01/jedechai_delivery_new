import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import '../../../common/services/auth_service.dart';

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

  Color _getBadgeColor() {
    switch (_getBadgeLevel()) {
      case 'Platinum': return const Color(0xFF6366F1);
      case 'Gold': return const Color(0xFFF59E0B);
      case 'Silver': return const Color(0xFF94A3B8);
      default: return const Color(0xFFB45309);
    }
  }

  IconData _getBadgeIcon() {
    switch (_getBadgeLevel()) {
      case 'Platinum': return Icons.diamond;
      case 'Gold': return Icons.emoji_events;
      case 'Silver': return Icons.military_tech;
      default: return Icons.workspace_premium;
    }
  }

  int _getBadgeNextTarget() {
    if (_totalCompletedJobs >= 500) return 500;
    if (_totalCompletedJobs >= 200) return 500;
    if (_totalCompletedJobs >= 50) return 200;
    return 50;
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('ผลงานของฉัน'),
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
                        _buildBadgeHeader(),
                        _buildRatingSection(),
                        _buildProgressSection(),
                        _buildStatsGrid(),
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

  Widget _buildBadgeHeader() {
    final badge = _getBadgeLevel();
    final color = _getBadgeColor();
    final icon = _getBadgeIcon();
    final next = _getBadgeNextTarget();
    final progress = _totalCompletedJobs >= 500
        ? 1.0
        : _totalCompletedJobs / next.toDouble();

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color, color.withValues(alpha: 0.75)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Colors.white, size: 32),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('ระดับ $badge',
                        style: const TextStyle(
                            color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                    Text('งานสำเร็จทั้งหมด $_totalCompletedJobs ครั้ง',
                        style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          if (_totalCompletedJobs < 500) ...[
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('ความคืบหน้าสู่ระดับถัดไป',
                    style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12)),
                Text('$_totalCompletedJobs / $next',
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.white.withValues(alpha: 0.25),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 8,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingSection() {
    final colorScheme = Theme.of(context).colorScheme;
    final rating = _averageRating.clamp(0.0, 5.0);
    final fullStars = rating.floor();
    final hasHalf = (rating - fullStars) >= 0.5;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('คะแนนเฉลี่ย',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: colorScheme.onSurface)),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(rating.toStringAsFixed(1),
                  style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: Color(0xFFF59E0B))),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(5, (i) {
                      if (i < fullStars) return const Icon(Icons.star, color: Color(0xFFF59E0B), size: 24);
                      if (i == fullStars && hasHalf) return const Icon(Icons.star_half, color: Color(0xFFF59E0B), size: 24);
                      return Icon(Icons.star_border, color: Colors.grey[300], size: 24);
                    }),
                  ),
                  const SizedBox(height: 4),
                  Text('จากคะแนนเต็ม 5.0',
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          _buildProgressRow(
            'อัตราการรับงาน',
            _acceptanceRate / 100,
            '${_acceptanceRate.toStringAsFixed(1)}%',
            Colors.blue,
            Icons.thumb_up_outlined,
          ),
          const SizedBox(height: 16),
          _buildProgressRow(
            'อัตราการส่งสำเร็จ',
            _completionRate / 100,
            '${_completionRate.toStringAsFixed(1)}%',
            Colors.green,
            Icons.check_circle_outline,
          ),
        ],
      ),
    );
  }

  Widget _buildProgressRow(String label, double value, String valueText, Color color, IconData icon) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(label,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: colorScheme.onSurface)),
            ),
            Text(valueText,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            backgroundColor: color.withValues(alpha: 0.12),
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 10,
          ),
        ),
      ],
    );
  }

  Widget _buildStatsGrid() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(child: _buildStatCard('งานสำเร็จ', '$_totalCompletedJobs', Icons.check_circle, Colors.green, colorScheme)),
          const SizedBox(width: 12),
          Expanded(child: _buildStatCard('ระดับ', _getBadgeLevel(), _getBadgeIcon(), _getBadgeColor(), colorScheme)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color, ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}
