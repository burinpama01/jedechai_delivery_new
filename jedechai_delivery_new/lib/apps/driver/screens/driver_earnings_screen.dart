import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:jedechai_delivery_new/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'driver_wallet_screen.dart';
import 'driver_job_detail_screen.dart';
import '../../../common/models/booking.dart';
import '../../../common/services/wallet_service.dart';
import '../../../common/services/auth_service.dart';

/// Driver Earnings Screen
///
/// แสดงรายได้และประวัติงาน พร้อมสรุปยอด (รูปแบบเดียวกับหน้ารายงานร้านค้า)
class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  bool _isLoading = true;
  String? _error;

  // Date filter
  int _selectedPeriod = 0; // 0=วันนี้, 1=สัปดาห์นี้, 2=เดือนนี้, 3=ทั้งหมด, 4=ระบุวันที่
  final List<String> _periodLabels = ['วันนี้', 'สัปดาห์นี้', 'เดือนนี้', 'ทั้งหมด', 'ระบุวันที่'];
  DateTimeRange? _customDateRange;

  // Stats
  double _totalEarnings = 0;
  int _totalJobs = 0;
  int _completedJobs = 0;
  int _cancelledJobs = 0;
  double _avgEarnings = 0;

  // Job history
  List<Map<String, dynamic>> _jobHistory = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 0: return DateTime(now.year, now.month, now.day);
      case 1: return DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      case 2: return DateTime(now.year, now.month, 1);
      case 4: return _customDateRange?.start ?? DateTime(now.year, now.month, now.day);
      default: return DateTime(2020, 1, 1);
    }
  }

  DateTime _getEndDate() {
    if (_selectedPeriod == 4 && _customDateRange != null) {
      final end = _customDateRange!.end;
      return DateTime(end.year, end.month, end.day, 23, 59, 59);
    }
    return DateTime.now().add(const Duration(days: 1));
  }

  Future<void> _pickCustomDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: now,
      initialDateRange: _customDateRange ?? DateTimeRange(
        start: DateTime(now.year, now.month, now.day).subtract(const Duration(days: 7)),
        end: now,
      ),
      locale: const Locale('th', 'TH'),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppTheme.accentBlue,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black87,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _customDateRange = picked;
        _selectedPeriod = 4;
      });
      _loadData();
    }
  }

  Future<void> _loadData() async {
    setState(() { _isLoading = true; _error = null; });

    try {
      final userId = AuthService.userId;
      if (userId == null) throw Exception('ไม่พบข้อมูลผู้ใช้');

      final startStr = _getStartDate().toIso8601String();
      final endStr = _getEndDate().toIso8601String();
      final hasEndFilter = _selectedPeriod == 4 && _customDateRange != null;

      // Fetch completed bookings in period
      var completedQuery = Supabase.instance.client
          .from('bookings')
          .select('*')
          .eq('driver_id', userId)
          .eq('status', 'completed')
          .gte('updated_at', startStr);
      if (hasEndFilter) completedQuery = completedQuery.lte('updated_at', endStr);
      final completedResponse = await completedQuery.order('updated_at', ascending: false);

      // Fetch cancelled bookings in period
      var cancelledQuery = Supabase.instance.client
          .from('bookings')
          .select('id')
          .eq('driver_id', userId)
          .eq('status', 'cancelled')
          .gte('updated_at', startStr);
      if (hasEndFilter) cancelledQuery = cancelledQuery.lte('updated_at', endStr);
      final cancelledResponse = await cancelledQuery;

      // Fetch all jobs in period for history
      var allQuery = Supabase.instance.client
          .from('bookings')
          .select('*')
          .eq('driver_id', userId)
          .inFilter('status', ['completed', 'cancelled', 'picked_up', 'delivering'])
          .gte('created_at', startStr);
      if (hasEndFilter) allQuery = allQuery.lte('created_at', endStr);
      final allJobsResponse = await allQuery.order('created_at', ascending: false).limit(50);

      // Calculate stats
      double totalEarn = 0;
      for (final job in completedResponse) {
        totalEarn += (job['driver_earnings'] as num?)?.toDouble() ?? 0;
      }

      if (mounted) {
        setState(() {
          _totalEarnings = totalEarn;
          _totalJobs = completedResponse.length + cancelledResponse.length;
          _completedJobs = completedResponse.length;
          _cancelledJobs = cancelledResponse.length;
          _avgEarnings = _completedJobs > 0 ? totalEarn / _completedJobs : 0;
          _jobHistory = List<Map<String, dynamic>>.from(allJobsResponse);
          _isLoading = false;
        });
      }

      debugLog('📊 Earnings loaded: Total=$_totalEarnings, Jobs=$_completedJobs');
    } catch (e) {
      debugLog('❌ Error loading earnings: $e');
      if (mounted) {
        setState(() { _error = e.toString(); _isLoading = false; });
      }
    }
  }

  String _formatCurrency(double amount) {
    return '฿${NumberFormat('#,##0.00').format(amount)}';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd/MM/yy HH:mm').format(date);
    } catch (_) { return '-'; }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed': return 'สำเร็จ';
      case 'cancelled': return 'ยกเลิก';
      case 'picked_up': return 'รับแล้ว';
      case 'delivering': return 'กำลังส่ง';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      case 'picked_up': return Colors.indigo;
      case 'delivering': return Colors.teal;
      default: return Colors.grey;
    }
  }

  String _getServiceIcon(String serviceType) {
    switch (serviceType) {
      case 'ride': return '🚗';
      case 'food': return '🍔';
      case 'parcel': return '📦';
      default: return '📋';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('รายได้'),
        backgroundColor: AppTheme.accentBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_wallet),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverWalletScreen())),
            tooltip: 'กระเป๋าเงิน',
          ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _loadData, tooltip: 'รีเฟรช'),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentBlue)))
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppTheme.accentBlue,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildPeriodFilter(),
                        _buildRevenueSummary(),
                        _buildStatsGrid(),
                        const SizedBox(height: 8),
                        _buildWalletCard(),
                        _buildJobHistorySection(),
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
            const Text('ไม่สามารถโหลดข้อมูลได้', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(_error ?? '', style: TextStyle(color: Colors.grey[500], fontSize: 13), textAlign: TextAlign.center),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentBlue, foregroundColor: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // Period Filter (same as merchant)
  // ============================================================

  Widget _buildPeriodFilter() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: List.generate(_periodLabels.length, (index) {
            final isSelected = _selectedPeriod == index;
            String chipLabel = _periodLabels[index];
            if (index == 4 && _customDateRange != null && isSelected) {
              final fmt = DateFormat('d/M/yy');
              chipLabel = '${fmt.format(_customDateRange!.start)} - ${fmt.format(_customDateRange!.end)}';
            }
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (index == 4) ...[
                      const Icon(Icons.calendar_today, size: 14),
                      const SizedBox(width: 4),
                    ],
                    Text(chipLabel),
                  ],
                ),
                selected: isSelected,
                onSelected: (selected) {
                  if (selected) {
                    if (index == 4) {
                      _pickCustomDateRange();
                    } else {
                      setState(() => _selectedPeriod = index);
                      _loadData();
                    }
                  }
                },
                selectedColor: AppTheme.accentBlue,
                labelStyle: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
                backgroundColor: Colors.grey[100],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
            );
          }),
        ),
      ),
    );
  }

  // ============================================================
  // Revenue Summary (same style as merchant)
  // ============================================================

  Widget _buildRevenueSummary() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.accentBlue, AppTheme.accentBlue.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: AppTheme.accentBlue.withValues(alpha: 0.3), blurRadius: 12, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text('รายได้${_periodLabels[_selectedPeriod]}', style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatCurrency(_totalEarnings),
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'เฉลี่ย ${_formatCurrency(_avgEarnings)} / งาน',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Stats Grid (same style as merchant)
  // ============================================================

  Widget _buildStatsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _buildStatCard('งานทั้งหมด', '$_totalJobs', Icons.work, Colors.blue)),
          const SizedBox(width: 10),
          Expanded(child: _buildStatCard('สำเร็จ', '$_completedJobs', Icons.check_circle, Colors.green)),
          const SizedBox(width: 10),
          Expanded(child: _buildStatCard('ยกเลิก', '$_cancelledJobs', Icons.cancel, Colors.red)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          const SizedBox(height: 4),
          Text(title, style: TextStyle(fontSize: 11, color: Colors.grey[600]), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  // ============================================================
  // Wallet Card (compact)
  // ============================================================

  Widget _buildWalletCard() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.blue[50], borderRadius: BorderRadius.circular(10)),
            child: Icon(Icons.account_balance_wallet, color: Colors.blue[600], size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('กระเป๋าเงิน', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.grey[800])),
                const SizedBox(height: 2),
                FutureBuilder<double>(
                  future: WalletService().getBalance(AuthService.userId!),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Text('กำลังโหลด...', style: TextStyle(fontSize: 12, color: Colors.grey[500]));
                    }
                    final balance = snapshot.data ?? 0.0;
                    return Text(
                      '${balance.toStringAsFixed(2)} บาท',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: balance >= 50 ? Colors.green : Colors.orange),
                    );
                  },
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverWalletScreen())),
            child: Text('ดูทั้งหมด', style: TextStyle(color: Colors.blue[600], fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // Job History (same style as merchant order history)
  // ============================================================

  Widget _buildJobHistorySection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('ประวัติงาน', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary)),
          const SizedBox(height: 12),
          if (_jobHistory.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                children: [
                  Icon(Icons.work_outline, size: 48, color: Colors.grey[300]),
                  const SizedBox(height: 12),
                  Text('ไม่มีงานในช่วงเวลานี้', style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            )
          else
            ...List.generate(_jobHistory.length, (index) => _buildJobCard(_jobHistory[index])),
        ],
      ),
    );
  }

  Widget _buildJobCard(Map<String, dynamic> job) {
    final status = job['status'] as String? ?? 'unknown';
    final driverEarnings = (job['driver_earnings'] as num?)?.toDouble() ?? 0;
    final appEarnings = (job['app_earnings'] as num?)?.toDouble() ?? 0;
    // final price = (job['price'] as num?)?.toDouble() ?? 0;
    // final deliveryFee = (job['delivery_fee'] as num?)?.toDouble() ?? 0;
    final serviceType = job['service_type'] as String? ?? 'unknown';
    final jobId = (job['id'] as String?)?.substring(0, 8) ?? '-';
    final createdAt = _formatDate(job['created_at']);
    // final totalCollect = serviceType == 'food' ? price + deliveryFee : price;

    return GestureDetector(
      onTap: () => _showJobDetail(job),
      child: Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(status).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _getStatusText(status),
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: _getStatusColor(status)),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${_getServiceIcon(serviceType)} ${serviceType == 'ride' ? 'รับส่ง' : serviceType == 'food' ? 'อาหาร' : serviceType == 'parcel' ? 'พัสดุ' : 'อื่นๆ'}',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
              const Spacer(),
              Text('#$jobId', style: TextStyle(fontSize: 12, color: Colors.grey[500], fontFamily: 'monospace')),
            ],
          ),
          const SizedBox(height: 10),

          // Earnings and date
          Row(
            children: [
              Text(
                _formatCurrency(driverEarnings),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.accentBlue),
              ),
              if (appEarnings > 0) ...[
                const SizedBox(width: 8),
                Text('(ค่าบริการระบบ ${_formatCurrency(appEarnings)})', style: TextStyle(fontSize: 12, color: Colors.red[400])),
              ],
              const Spacer(),
              Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
              const SizedBox(width: 4),
              Text(createdAt, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
            ],
          ),

          // Route info
          if (job['pickup_address'] != null || job['destination_address'] != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.location_on_outlined, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    '${job['pickup_address'] ?? '?'} → ${job['destination_address'] ?? '?'}',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ),
    );
  }

  void _showJobDetail(Map<String, dynamic> job) {
    try {
      final booking = Booking.fromJson(job);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => DriverJobDetailScreen(booking: booking),
        ),
      );
    } catch (e) {
      debugLog('❌ Error opening job detail: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ไม่สามารถเปิดรายละเอียดงานได้')),
      );
    }
  }

}
