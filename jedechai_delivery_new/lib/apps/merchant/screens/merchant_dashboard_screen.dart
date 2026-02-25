import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/services/auth_service.dart';
import '../../../common/services/system_config_service.dart';
import '../../../common/utils/order_code_formatter.dart';
import '../../../theme/app_theme.dart';
import 'order_detail_screen.dart';

/// Merchant Sales Report Screen
///
/// แสดงรายงานและประวัติการขาย พร้อมสรุปยอดขาย
class MerchantDashboardScreen extends StatefulWidget {
  const MerchantDashboardScreen({super.key});

  @override
  State<MerchantDashboardScreen> createState() => _MerchantDashboardScreenState();
}

class _MerchantDashboardScreenState extends State<MerchantDashboardScreen> {
  bool _isLoading = true;
  String? _error;

  // Date filter
  int _selectedPeriod = 0; // 0=วันนี้, 1=สัปดาห์นี้, 2=เดือนนี้, 3=ทั้งหมด, 4=ระบุวันที่
  final List<String> _periodLabels = ['วันนี้', 'สัปดาห์นี้', 'เดือนนี้', 'ทั้งหมด', 'ระบุวันที่'];
  DateTimeRange? _customDateRange;

  // Stats
  double _totalRevenue = 0;
  int _totalOrders = 0;
  int _completedOrders = 0;
  int _cancelledOrders = 0;
  double _avgOrderValue = 0;

  // Order history
  List<Map<String, dynamic>> _orderHistory = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  DateTime _getStartDate() {
    final now = DateTime.now();
    switch (_selectedPeriod) {
      case 0: // วันนี้
        return DateTime(now.year, now.month, now.day);
      case 1: // สัปดาห์นี้
        return DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      case 2: // เดือนนี้
        return DateTime(now.year, now.month, 1);
      case 4: // ระบุวันที่
        return _customDateRange?.start ?? DateTime(now.year, now.month, now.day);
      default: // ทั้งหมด
        return DateTime(2020, 1, 1);
    }
  }

  DateTime _getEndDate() {
    if (_selectedPeriod == 4 && _customDateRange != null) {
      // สิ้นสุดวันที่เลือก (23:59:59)
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
              primary: AppTheme.accentOrange,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Theme.of(context).colorScheme.onSurface,
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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final merchantId = AuthService.userId;
      if (merchantId == null) throw Exception('ไม่พบข้อมูลผู้ใช้');

      final startStr = _getStartDate().toIso8601String();
      final endStr = _getEndDate().toIso8601String();
      final hasDateFilter = _selectedPeriod != 3;

      // Fetch completed orders in period
      var completedQuery = Supabase.instance.client
          .from('bookings')
          .select('id, price, delivery_fee, status, created_at, updated_at, notes')
          .eq('merchant_id', merchantId)
          .eq('service_type', 'food')
          .eq('status', 'completed')
          .gte('updated_at', startStr);
      if (hasDateFilter) completedQuery = completedQuery.lte('updated_at', endStr);
      final completedResponse = await completedQuery.order('updated_at', ascending: false);

      // Fetch cancelled orders in period
      var cancelledQuery = Supabase.instance.client
          .from('bookings')
          .select('id')
          .eq('merchant_id', merchantId)
          .eq('service_type', 'food')
          .eq('status', 'cancelled')
          .gte('updated_at', startStr);
      if (hasDateFilter) cancelledQuery = cancelledQuery.lte('updated_at', endStr);
      final cancelledResponse = await cancelledQuery;

      // Fetch all orders in period for history
      var allQuery = Supabase.instance.client
          .from('bookings')
          .select('id, price, delivery_fee, status, created_at, updated_at, notes, customer_id')
          .eq('merchant_id', merchantId)
          .eq('service_type', 'food')
          .inFilter('status', ['completed', 'cancelled', 'preparing', 'ready', 'picked_up', 'delivering'])
          .gte('created_at', startStr);
      if (hasDateFilter) allQuery = allQuery.lte('created_at', endStr);
      final allOrdersResponse = await allQuery.order('created_at', ascending: false).limit(50);

      // Fetch merchant GP rate from system config
      final configService = SystemConfigService();
      await configService.fetchSettings();
      final gpRate = configService.merchantGpRate;

      // Try to fetch merchant's custom GP rate (column may not exist)
      double? customGp;
      try {
        final merchantProfile = await Supabase.instance.client
            .from('profiles')
            .select('custom_gp_rate')
            .eq('id', merchantId)
            .maybeSingle();
        customGp = (merchantProfile?['custom_gp_rate'] as num?)?.toDouble();
      } catch (_) {
        // Column doesn't exist yet — use system default
      }
      final effectiveGpRate = customGp ?? gpRate;

      // Calculate stats — ยอดขายหลังหัก GP
      double totalRevBeforeGP = 0;
      for (final order in completedResponse) {
        totalRevBeforeGP += (order['price'] as num?)?.toDouble() ?? 0;
      }
      final gpAmount = totalRevBeforeGP * effectiveGpRate;
      final netRevenue = totalRevBeforeGP - gpAmount;

      if (mounted) {
        setState(() {
          _totalRevenue = netRevenue;
          _totalOrders = completedResponse.length + cancelledResponse.length;
          _completedOrders = completedResponse.length;
          _cancelledOrders = cancelledResponse.length;
          _avgOrderValue = _completedOrders > 0 ? netRevenue / _completedOrders : 0;
          _orderHistory = List<Map<String, dynamic>>.from(allOrdersResponse);
          _isLoading = false;
        });
      }

      debugLog('📊 Sales report loaded: Revenue=$_totalRevenue, Orders=$_completedOrders');
    } catch (e) {
      debugLog('❌ Error loading sales data: $e');
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _formatCurrency(double amount) {
    return '฿${NumberFormat('#,##0').format(amount.ceil())}';
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null) return '-';
    try {
      final date = DateTime.parse(dateStr).toLocal();
      return DateFormat('dd/MM/yy HH:mm').format(date);
    } catch (_) {
      return '-';
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'completed': return 'สำเร็จ';
      case 'cancelled': return 'ยกเลิก';
      case 'preparing': return 'กำลังเตรียม';
      case 'ready': return 'พร้อมส่ง';
      case 'picked_up': return 'ไรเดอร์รับแล้ว';
      case 'delivering': return 'กำลังจัดส่ง';
      default: return status;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      case 'preparing': return Colors.orange;
      case 'ready': return Colors.blue;
      case 'picked_up': return Colors.indigo;
      case 'delivering': return Colors.teal;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('รายงานการขาย'),
        backgroundColor: AppTheme.accentOrange,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'รีเฟรช',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentOrange),
              ),
            )
          : _error != null
              ? _buildErrorState()
              : RefreshIndicator(
                  onRefresh: _loadData,
                  color: AppTheme.accentOrange,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Period Filter
                        _buildPeriodFilter(),

                        // Revenue Summary Card
                        _buildRevenueSummary(),

                        // Stats Grid
                        _buildStatsGrid(),

                        // Order History
                        _buildOrderHistorySection(),

                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
    );
  }

  Widget _buildErrorState() {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
            const SizedBox(height: 16),
            Text(
              'ไม่สามารถโหลดข้อมูลได้',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? '',
              style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _loadData,
              icon: const Icon(Icons.refresh),
              label: const Text('ลองใหม่'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentOrange,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPeriodFilter() {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
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
                    selectedColor: AppTheme.accentOrange,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : colorScheme.onSurface,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _pickCustomDateRange,
                icon: const Icon(Icons.date_range, size: 18),
                label: const Text('เลือกช่วงวันที่'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.accentOrange,
                  side: const BorderSide(color: AppTheme.accentOrange),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
              ),
              if (_selectedPeriod == 4 && _customDateRange != null)
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _customDateRange = null;
                      _selectedPeriod = 0;
                    });
                    _loadData();
                  },
                  icon: const Icon(Icons.clear, size: 18),
                  label: const Text('ล้างตัวกรองวันที่'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.red,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueSummary() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.accentOrange, AppTheme.accentOrange.withValues(alpha: 0.8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentOrange.withValues(alpha: 0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Text(
                'รายได้สุทธิ${_periodLabels[_selectedPeriod]}',
                style: TextStyle(color: Colors.white.withValues(alpha: 0.9), fontSize: 14),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _formatCurrency(_totalRevenue),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'เฉลี่ย ${_formatCurrency(_avgOrderValue)} / ออเดอร์',
            style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          Expanded(child: _buildStatCard('ออเดอร์ทั้งหมด', '$_totalOrders', Icons.receipt_long, Colors.blue)),
          const SizedBox(width: 10),
          Expanded(child: _buildStatCard('สำเร็จ', '$_completedOrders', Icons.check_circle, Colors.green)),
          const SizedBox(width: 10),
          Expanded(child: _buildStatCard('ยกเลิก', '$_cancelledOrders', Icons.cancel, Colors.red)),
        ],
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 24, color: color),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(fontSize: 11, color: colorScheme.onSurfaceVariant),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderHistorySection() {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ประวัติออเดอร์',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 12),
          if (_orderHistory.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainer,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.receipt_long,
                    size: 48,
                    color: colorScheme.onSurfaceVariant.withValues(alpha: 0.45),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'ไม่มีออเดอร์ในช่วงเวลานี้',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            )
          else
            ...List.generate(_orderHistory.length, (index) {
              final order = _orderHistory[index];
              return _buildOrderCard(order);
            }),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = order['status'] as String? ?? 'unknown';
    final price = (order['price'] as num?)?.toDouble() ?? 0;
    final orderId = OrderCodeFormatter.formatByServiceType(
      order['id']?.toString(),
      serviceType: order['service_type']?.toString(),
    );
    final createdAt = _formatDate(order['created_at']);
    final notes = order['notes'] as String?;

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MerchantOrderDetailScreen(order: order),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
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
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _getStatusColor(status),
                    ),
                  ),
                ),
                const Spacer(),
                Text(
                  '#$orderId',
                  style: TextStyle(
                    fontSize: 12,
                    color: colorScheme.onSurfaceVariant,
                    fontFamily: 'monospace',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Price and date
            Row(
              children: [
                Text(
                  _formatCurrency(price),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const Spacer(),
                Icon(Icons.access_time, size: 14, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 4),
                Text(
                  createdAt,
                  style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                ),
              ],
            ),

            // Notes
            if (notes != null && notes.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.note, size: 14, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      notes,
                      style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],

            // Tap hint
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('ดูรายละเอียด', style: TextStyle(fontSize: 12, color: AppTheme.accentOrange, fontWeight: FontWeight.w500)),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right, size: 16, color: AppTheme.accentOrange),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
