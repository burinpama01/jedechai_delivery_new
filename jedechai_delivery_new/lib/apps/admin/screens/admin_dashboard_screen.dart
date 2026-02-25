import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/services/admin_service.dart';
import '../../../utils/debug_logger.dart';
import '../theme/admin_theme.dart';

/// Admin Dashboard Screen
///
/// แสดงภาพรวมระบบ:
/// - ออเดอร์วันนี้ / เสร็จวันนี้
/// - รายได้วันนี้
/// - คนขับ/ร้านค้ารอการอนุมัติ
/// - คำขอถอนเงินรอดำเนินการ
/// - กราฟรายได้ 7 วัน
class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final AdminService _adminService = AdminService();
  Map<String, dynamic> _stats = {};
  List<Map<String, dynamic>> _revenueChart = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Widget _buildUserTypeStatsSection() {
    final totalCustomers = _stats['total_customers'] ?? 0;
    final totalDrivers = _stats['total_drivers'] ?? 0;
    final totalMerchants = _stats['total_merchants'] ?? 0;
    final onlineCustomers = _stats['online_customers'] ?? 0;
    final onlineDrivers = _stats['online_drivers'] ?? 0;
    final onlineMerchants = _stats['online_merchants'] ?? 0;
    final onlineUsersTotal = _stats['online_users_total'] ?? 0;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.groups_2, color: Color(0xFF1565C0), size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'ผู้ใช้งานตามประเภท',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'ออนไลน์รวม $onlineUsersTotal',
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _buildUserTypeRow(
              title: 'ลูกค้า',
              total: totalCustomers,
              online: onlineCustomers,
              icon: Icons.person,
              color: Colors.blue,
            ),
            _buildUserTypeRow(
              title: 'คนขับ',
              total: totalDrivers,
              online: onlineDrivers,
              icon: Icons.directions_car,
              color: Colors.indigo,
            ),
            _buildUserTypeRow(
              title: 'ร้านค้า',
              total: totalMerchants,
              online: onlineMerchants,
              icon: Icons.store,
              color: Colors.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTypeRow({
    required String title,
    required int total,
    required int online,
    required IconData icon,
    required Color color,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            'ทั้งหมด $total',
            style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              'ออนไลน์ $online',
              style: const TextStyle(
                color: Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _loadDashboard() async {
    setState(() => _isLoading = true);
    try {
      final stats = await _adminService.getDashboardStats();
      final chart = await _adminService.getRevenueChart(days: 7);
      if (mounted) {
        setState(() {
          _stats = stats;
          _revenueChart = chart;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugLog('❌ Error loading dashboard: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTheme.background,
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AdminTheme.primary))
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Page header
                    Row(
                      children: [
                        const Icon(Icons.dashboard_rounded, color: AdminTheme.primary, size: 28),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'แดชบอร์ด',
                            style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: AdminTheme.textPrimary,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: _loadDashboard,
                          icon: const Icon(Icons.refresh_rounded),
                          tooltip: 'รีเฟรช',
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    _buildWelcomeCard(),
                    const SizedBox(height: 16),
                    _buildStatsGrid(),
                    const SizedBox(height: 20),
                    _buildUserTypeStatsSection(),
                    const SizedBox(height: 20),
                    _buildRevenueChartSection(),
                    const SizedBox(height: 20),
                    _buildPendingActionsSection(),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildWelcomeCard() {
    final now = DateTime.now();
    final dateStr = DateFormat('d MMMM yyyy', 'th').format(now);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AdminTheme.primary, AdminTheme.primaryDark],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          const Icon(Icons.admin_panel_settings, color: Colors.white, size: 48),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Admin Back-office',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  dateStr,
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossAxisCount = width >= 1100 ? 4 : width >= 700 ? 2 : 1;

        return GridView.count(
          crossAxisCount: crossAxisCount,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: width < 700 ? 2.4 : 1.5,
          children: [
            _buildStatCard(
              'ออเดอร์วันนี้',
              '${_stats['today_orders'] ?? 0}',
              Icons.receipt,
              Colors.blue,
            ),
            _buildStatCard(
              'เสร็จแล้ว',
              '${_stats['completed_today'] ?? 0}',
              Icons.check_circle,
              Colors.green,
            ),
            _buildStatCard(
              'รายได้วันนี้',
              '฿${NumberFormat('#,##0').format(_stats['revenue_today'] ?? 0)}',
              Icons.attach_money,
              Colors.orange,
            ),
            _buildStatCard(
              'ผู้ใช้ทั้งหมด',
              '${_stats['total_users'] ?? 0}',
              Icons.people,
              Colors.purple,
            ),
          ],
        );
      },
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.withValues(alpha: 0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(icon, color: color, size: 28),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                title,
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueChartSection() {
    if (_revenueChart.isEmpty) return const SizedBox.shrink();

    final maxRevenue = _revenueChart
        .map((e) => (e['revenue'] as num).toDouble())
        .reduce((a, b) => a > b ? a : b);

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'รายได้ 7 วันย้อนหลัง',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 160,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: _revenueChart.map((data) {
                  final revenue = (data['revenue'] as num).toDouble();
                  final orders = data['orders'] as int;
                  final date = data['date'] as String;
                  final dayStr = date.substring(8, 10);
                  final barHeight = maxRevenue > 0 ? (revenue / maxRevenue) * 120 : 0.0;

                  return Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            '${revenue.round()}',
                            style: TextStyle(fontSize: 9, color: Colors.grey[600]),
                          ),
                          const SizedBox(height: 4),
                          Container(
                            height: barHeight,
                            decoration: BoxDecoration(
                              color: const Color(0xFF1565C0).withValues(alpha: 0.8),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            dayStr,
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                          Text(
                            '($orders)',
                            style: TextStyle(fontSize: 9, color: Colors.grey[400]),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingActionsSection() {
    final pendingDrivers = _stats['pending_drivers'] ?? 0;
    final pendingMerchants = _stats['pending_merchants'] ?? 0;
    final pendingWithdrawals = _stats['pending_withdrawals'] ?? 0;

    if (pendingDrivers == 0 && pendingMerchants == 0 && pendingWithdrawals == 0) {
      return Card(
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: const Padding(
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 32),
              SizedBox(width: 12),
              Text('ไม่มีรายการรอดำเนินการ', style: TextStyle(fontSize: 15)),
            ],
          ),
        ),
      );
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.orange, size: 22),
                SizedBox(width: 8),
                Text(
                  'รอดำเนินการ',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (pendingDrivers > 0)
              _buildPendingItem(
                'คนขับรอการอนุมัติ',
                '$pendingDrivers คน',
                Icons.directions_car,
                Colors.blue,
              ),
            if (pendingMerchants > 0)
              _buildPendingItem(
                'ร้านค้ารอการอนุมัติ',
                '$pendingMerchants ร้าน',
                Icons.store,
                Colors.green,
              ),
            if (pendingWithdrawals > 0)
              _buildPendingItem(
                'คำขอถอนเงินรอดำเนินการ',
                '$pendingWithdrawals รายการ',
                Icons.account_balance_wallet,
                Colors.orange,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPendingItem(String title, String count, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: color.withValues(alpha: 0.1),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 14))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              count,
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
