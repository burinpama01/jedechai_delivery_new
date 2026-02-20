import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../common/models/booking.dart';
import '../../../common/widgets/status_badge.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/connection_helper.dart';
import '../../../utils/mock_data_service.dart';
import 'services/waiting_for_driver_screen.dart';
import 'services/customer_order_detail_screen.dart';

enum _ActivityDateFilter {
  today,
  last7Days,
  thisMonth,
  all,
  custom,
}

/// Activity Screen
///
/// Shows booking history for the customer
class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  List<Booking> _bookings = [];
  bool _isLoading = true;
  String? _error;
  Map<String, Map<String, dynamic>> _couponUsageByBookingId = {};
  _ActivityDateFilter _dateFilter = _ActivityDateFilter.all;
  DateTimeRange? _customDateRange;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  String _getPaymentMethodText(String? paymentMethod) {
    switch ((paymentMethod ?? '').toLowerCase()) {
      case 'cash':
        return 'เงินสด';
      case 'transfer':
      case 'promptpay':
      case 'bank_transfer':
        return 'โอนเงิน';
      case 'card':
      case 'credit_card':
        return 'บัตรเครดิต';
      default:
        return 'ไม่ระบุการชำระ';
    }
  }

  Future<Map<String, Map<String, dynamic>>> _fetchCouponUsageMap(
      List<String> bookingIds) async {
    if (bookingIds.isEmpty) return {};

    try {
      final usageRows = await Supabase.instance.client
          .from('coupon_usages')
          .select('booking_id, coupon_id, discount_amount')
          .inFilter('booking_id', bookingIds);

      if (usageRows.isEmpty) return {};

      final couponIds = <String>{};
      for (final row in usageRows) {
        final couponId = row['coupon_id'] as String?;
        if (couponId != null && couponId.isNotEmpty) {
          couponIds.add(couponId);
        }
      }

      final couponCodeMap = <String, String>{};
      if (couponIds.isNotEmpty) {
        final couponRows = await Supabase.instance.client
            .from('coupons')
            .select('id, code')
            .inFilter('id', couponIds.toList());

        for (final row in couponRows) {
          final id = row['id'] as String?;
          final code = row['code'] as String?;
          if (id != null && code != null) {
            couponCodeMap[id] = code;
          }
        }
      }

      final result = <String, Map<String, dynamic>>{};
      for (final row in usageRows) {
        final bookingId = row['booking_id'] as String?;
        if (bookingId == null || bookingId.isEmpty) continue;
        final couponId = row['coupon_id'] as String?;
        result[bookingId] = {
          'discount_amount': row['discount_amount'],
          'coupon_code': couponId != null ? couponCodeMap[couponId] : null,
        };
      }

      return result;
    } catch (e) {
      debugLog('❌ Error fetching coupon usage map: $e');
      return {};
    }
  }

  DateTime _startOfDay(DateTime dateTime) {
    return DateTime(dateTime.year, dateTime.month, dateTime.day);
  }

  DateTime _endOfDay(DateTime dateTime) {
    return DateTime(
        dateTime.year, dateTime.month, dateTime.day, 23, 59, 59, 999);
  }

  DateTimeRange? _getActiveDateRange() {
    final now = DateTime.now();

    switch (_dateFilter) {
      case _ActivityDateFilter.today:
        return DateTimeRange(
          start: _startOfDay(now),
          end: _endOfDay(now),
        );
      case _ActivityDateFilter.last7Days:
        return DateTimeRange(
          start: _startOfDay(now.subtract(const Duration(days: 6))),
          end: _endOfDay(now),
        );
      case _ActivityDateFilter.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final end = DateTime(now.year, now.month + 1, 1)
            .subtract(const Duration(milliseconds: 1));
        return DateTimeRange(start: start, end: end);
      case _ActivityDateFilter.custom:
        return _customDateRange;
      case _ActivityDateFilter.all:
        return null;
    }
  }

  List<Booking> _getFilteredBookings() {
    final range = _getActiveDateRange();
    if (range == null) return List<Booking>.from(_bookings);

    return _bookings.where((booking) {
      final createdAt = booking.createdAt.toLocal();
      return !createdAt.isBefore(range.start) && !createdAt.isAfter(range.end);
    }).toList();
  }

  Future<void> _selectCustomDateRange() async {
    final now = DateTime.now();
    final initialRange = _customDateRange ??
        DateTimeRange(
          start: _startOfDay(now.subtract(const Duration(days: 6))),
          end: _endOfDay(now),
        );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2, 1, 1),
      lastDate: DateTime(now.year + 1, 12, 31),
      initialDateRange: initialRange,
      helpText: 'เลือกช่วงวันที่',
      saveText: 'ยืนยัน',
      cancelText: 'ยกเลิก',
    );

    if (picked == null) return;

    setState(() {
      _customDateRange = DateTimeRange(
        start: _startOfDay(picked.start),
        end: _endOfDay(picked.end),
      );
      _dateFilter = _ActivityDateFilter.custom;
    });
  }

  String _getDateFilterText() {
    switch (_dateFilter) {
      case _ActivityDateFilter.today:
        return 'วันนี้';
      case _ActivityDateFilter.last7Days:
        return '7 วันที่ผ่านมา';
      case _ActivityDateFilter.thisMonth:
        return 'เดือนนี้';
      case _ActivityDateFilter.all:
        return 'ทั้งหมด';
      case _ActivityDateFilter.custom:
        if (_customDateRange == null) return 'ช่วงวันที่';
        final formatter = DateFormat('dd/MM/yyyy');
        return '${formatter.format(_customDateRange!.start)} - ${formatter.format(_customDateRange!.end)}';
    }
  }

  bool _isCompletedStatus(String status) {
    return status.toLowerCase() == 'completed';
  }

  bool _isCancelledStatus(String status) {
    return status.toLowerCase() == 'cancelled';
  }

  int _getCompletedCount(List<Booking> bookings) {
    return bookings
        .where((booking) => _isCompletedStatus(booking.status))
        .length;
  }

  int _getCancelledCount(List<Booking> bookings) {
    return bookings
        .where((booking) => _isCancelledStatus(booking.status))
        .length;
  }

  double _getTotalSpent(List<Booking> bookings) {
    double total = 0;
    for (final booking in bookings) {
      if (_isCompletedStatus(booking.status)) {
        total += _getTotalPrice(booking);
      }
    }
    return total;
  }

  double _getTotalSavings(List<Booking> bookings) {
    double total = 0;
    for (final booking in bookings) {
      total += _getCouponDiscount(booking);
    }
    return total;
  }

  Future<void> _fetchBookings() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) {
        setState(() {
          _error = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Check real Supabase connection first
      final isRealSupabaseAvailable =
          await MockDataService.checkRealConnection();

      if (!isRealSupabaseAvailable) {
        await Future.delayed(
            const Duration(seconds: 1)); // Simulate network delay
        final mockBookings = MockDataService.getMockBookings();
        setState(() {
          _bookings = mockBookings;
          _isLoading = false;
        });
        return;
      }

      debugLog('🔗 Using real Supabase connection');

      // Add timeout and retry logic
      try {
        final response = await ConnectionHelper.withTimeout(() async {
          return await Supabase.instance.client
              .from('bookings')
              .select()
              .eq('customer_id', userId)
              .order('created_at', ascending: false)
              .limit(50);
        });

        debugLog(
            '🔗 Debug: Customer bookings response: ${response.length} items');
        for (var item in response) {
          debugLog(
              '📋 Booking: ${item['id']} - Status: ${item['status']} - Service: ${item['service_type']}');
        }

        final bookings =
            response.map((item) => Booking.fromJson(item)).toList();

        final bookingIds = bookings.map((b) => b.id).toList();
        final couponUsageByBookingId = await _fetchCouponUsageMap(bookingIds);

        setState(() {
          _bookings = bookings;
          _couponUsageByBookingId = couponUsageByBookingId;
          _isLoading = false;
        });
      } catch (supabaseError) {
        // Handle Supabase connection errors

        // Fallback to mock data on connection error
        if (ConnectionHelper.isConnectionError(supabaseError)) {
          final mockBookings = MockDataService.getMockBookings();
          setState(() {
            _bookings = mockBookings;
            _isLoading = false;
          });
        } else {
          setState(() {
            _error = ConnectionHelper.getErrorMessage(supabaseError);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // Fallback to mock data on any error
      final mockBookings = MockDataService.getMockBookings();
      setState(() {
        _bookings = mockBookings;
        _isLoading = false;
      });
    }
  }

  IconData _getServiceIcon(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'ride':
      case 'taxi':
        return Icons.motorcycle;
      case 'delivery':
      case 'parcel':
        return Icons.local_shipping;
      case 'food':
        return Icons.restaurant;
      default:
        return Icons.directions_car;
    }
  }

  Color _getServiceColor(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'ride':
      case 'taxi':
        return Colors.blue;
      case 'delivery':
      case 'parcel':
        return Colors.orange;
      case 'food':
        return Colors.red;
      default:
        return Colors.green;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      case 'confirmed':
      case 'accepted':
      case 'driver_assigned':
      case 'driver_accepted':
        return Colors.blue;
      case 'in_progress':
      case 'in_transit':
      case 'preparing':
      case 'ready_for_pickup':
        return Colors.purple;
      case 'arrived':
        return Colors.orange;
      case 'pending':
      case 'searching':
        return Colors.amber;
      default:
        return Colors.grey;
    }
  }

  String _formatDateTime(DateTime? dateTime) {
    if (dateTime == null) return 'ไม่ทราบ';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} ชั่วโมงที่แล้ว';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} นาทีที่แล้ว';
    } else {
      return 'เมื่อสักครู่';
    }
  }

  String _getServiceText(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'ride':
        return 'เรียกรถ';
      case 'food':
        return 'สั่งอาหาร';
      case 'parcel':
      case 'delivery':
        return 'ส่งพัสดุ';
      default:
        return serviceType;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredBookings = _getFilteredBookings();

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('ประวัติการใช้งาน'),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchBookings,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentBlue),
              ),
            )
          : _error != null
              ? _buildErrorWidget()
              : _bookings.isEmpty
                  ? _buildEmptyWidget()
                  : _buildActivityContent(filteredBookings),
    );
  }

  Widget _buildActivityContent(List<Booking> filteredBookings) {
    return RefreshIndicator(
      onRefresh: _fetchBookings,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  _buildDateFilterSection(),
                  const SizedBox(height: 12),
                  _buildStatsSection(filteredBookings),
                ],
              ),
            ),
          ),
          if (filteredBookings.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: _buildFilteredEmptyWidget(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.all(16),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final booking = filteredBookings[index];
                    return _buildHistoryCard(booking);
                  },
                  childCount: filteredBookings.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildDateFilterSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.filter_alt_rounded,
                  color: AppTheme.accentBlue, size: 18),
              SizedBox(width: 6),
              Text(
                'กรองตามวันที่',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildDateFilterChip(_ActivityDateFilter.today, 'วันนี้'),
                _buildDateFilterChip(_ActivityDateFilter.last7Days, '7 วัน'),
                _buildDateFilterChip(_ActivityDateFilter.thisMonth, 'เดือนนี้'),
                _buildDateFilterChip(_ActivityDateFilter.all, 'ทั้งหมด'),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      _dateFilter == _ActivityDateFilter.custom &&
                              _customDateRange != null
                          ? _getDateFilterText()
                          : 'ช่วงวันที่',
                    ),
                    selected: _dateFilter == _ActivityDateFilter.custom,
                    onSelected: (_) => _selectCustomDateRange(),
                    selectedColor: AppTheme.accentBlue,
                    labelStyle: TextStyle(
                      color: _dateFilter == _ActivityDateFilter.custom
                          ? Colors.white
                          : Colors.black87,
                      fontWeight: FontWeight.w600,
                    ),
                    backgroundColor: Colors.grey[100],
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateFilterChip(_ActivityDateFilter filter, String label) {
    final isSelected = _dateFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          if (!selected) return;
          setState(() => _dateFilter = filter);
        },
        selectedColor: AppTheme.accentBlue,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : Colors.black87,
          fontWeight: FontWeight.w600,
        ),
        backgroundColor: Colors.grey[100],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }

  Widget _buildStatsSection(List<Booking> filteredBookings) {
    final totalOrders = filteredBookings.length;
    final completedCount = _getCompletedCount(filteredBookings);
    final cancelledCount = _getCancelledCount(filteredBookings);
    final totalSpent = _getTotalSpent(filteredBookings);
    final totalSavings = _getTotalSavings(filteredBookings);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF3B82F6), Color(0xFF60A5FA)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF3B82F6).withValues(alpha: 0.25),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'สถิติการสั่งซื้อ',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ช่วงเวลา: ${_getDateFilterText()}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildStatChip('ทั้งหมด', '$totalOrders รายการ'),
              _buildStatChip('สำเร็จ', '$completedCount รายการ'),
              _buildStatChip('ยกเลิก', '$cancelledCount รายการ'),
              _buildStatChip('ยอดใช้จ่าย', '฿${totalSpent.ceil()}'),
              _buildStatChip('ประหยัดจากคูปอง', '฿${totalSavings.ceil()}'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: Colors.white70,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilteredEmptyWidget() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_busy,
                size: 48,
                color: AppTheme.accentBlue,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'ไม่พบรายการในช่วงวันที่ที่เลือก',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'ลองเปลี่ยนตัวกรองวันที่เพื่อดูประวัติการสั่งซื้อเพิ่มเติม',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return ConnectionHelper.buildErrorWidget(
      error: _error!,
      onRetry: _fetchBookings,
      title: 'โหลดข้อมูลไม่สำเร็จ',
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: AppTheme.accentBlue.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.history,
              size: 64,
              color: AppTheme.accentBlue,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'ยังไม่มีประวัติ',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'ประวัติการจองของคุณจะแสดงที่นี่',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Booking booking) {
    return GestureDetector(
      onTap: () {
        _handleBookingTap(booking);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              spreadRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Row
              Row(
                children: [
                  // Service Icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: _getServiceColor(booking.serviceType)
                          .withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _getServiceIcon(booking.serviceType),
                      color: _getServiceColor(booking.serviceType),
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Service Type and Date
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _getServiceText(booking.serviceType),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: _getServiceColor(booking.serviceType),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDateTime(booking.createdAt),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'รหัส #${_shortBookingId(booking.id)}',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.grey[500],
                            fontFamily: 'monospace',
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Status Badge
                  StatusBadge(
                    statusString: booking.status,
                    role: StatusRole.customer,
                    showIcon: false,
                    fontSize: 11,
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Destination
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: Colors.grey,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _formatAddress(booking.destinationAddress),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildMetaChip(Icons.payments_rounded,
                      _getPaymentMethodText(booking.paymentMethod)),
                  if (booking.distanceKm > 0)
                    _buildMetaChip(Icons.straighten_rounded,
                        '${booking.distanceKm.toStringAsFixed(1)} กม.'),
                ],
              ),

              if (booking.scheduledAt != null) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.shade300),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.schedule,
                          size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          booking.scheduledAt!.isAfter(DateTime.now())
                              ? 'นัดหมายรับบริการ: ${_formatScheduledDateTime(booking.scheduledAt!)}'
                              : 'ออเดอร์นัดหมาย: ${_formatScheduledDateTime(booking.scheduledAt!)}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 12),

              // Price and Status Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'ยอดชำระ',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                      Text(
                        '฿${_getTotalPrice(booking).ceil()}',
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      Text(
                        'ดูรายละเอียด',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right,
                        size: 18,
                        color: Colors.grey[500],
                      ),
                    ],
                  ),
                ],
              ),

              Text(
                _getStatusText(booking.status),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _getStatusColor(booking.status),
                ),
              ),

              if (_getCouponDiscount(booking) > 0) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                            color: Colors.green.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        _buildCouponLabel(booking),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _shortBookingId(String id) {
    if (id.length <= 8) return id;
    return id.substring(0, 8);
  }

  Widget _buildMetaChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[700]),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }

  String _getStatusText(String status) {
    switch (status.toLowerCase()) {
      case 'completed':
        return 'สำเร็จ';
      case 'cancelled':
        return 'ยกเลิก';
      case 'confirmed':
      case 'accepted':
        return 'ยืนยันแล้ว';
      case 'driver_assigned':
      case 'driver_accepted':
        return 'คนขับรับแล้ว';
      case 'in_progress':
      case 'in_transit':
        return 'กำลังจัดส่ง';
      case 'preparing':
        return 'กำลังเตรียมอาหาร';
      case 'ready_for_pickup':
        return 'อาหารพร้อมรับ';
      case 'arrived':
        return 'ถึงจุดหมาย';
      case 'pending':
      case 'searching':
        return 'รอดำเนินการ';
      default:
        return status;
    }
  }

  String _formatAddress(String? address) {
    if (address == null) return 'ไม่ระบุ';
    if (address.toString() == 'Instance of \'AddressPlacemark\'') {
      return 'ที่อยู่ปลายทาง'; // Fallback
    }
    return address;
  }

  String _formatScheduledDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');
    final year = local.year;
    final hour = local.hour.toString().padLeft(2, '0');
    final minute = local.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  double _getCouponDiscount(Booking booking) {
    final usage = _couponUsageByBookingId[booking.id];
    return (usage?['discount_amount'] as num?)?.toDouble() ?? 0.0;
  }

  String? _getCouponCode(Booking booking) {
    final usage = _couponUsageByBookingId[booking.id];
    return usage?['coupon_code'] as String?;
  }

  String _buildCouponLabel(Booking booking) {
    final code = _getCouponCode(booking);
    final discount = _getCouponDiscount(booking).ceil();
    if (code != null && code.isNotEmpty) {
      return 'ใช้คูปอง $code ลด ฿$discount';
    }
    return 'ใช้คูปอง ลด ฿$discount';
  }

  double _getTotalPrice(Booking booking) {
    final couponDiscount = _getCouponDiscount(booking);

    if (booking.serviceType == 'food') {
      final total =
          booking.price + (booking.deliveryFee ?? 0.0) - couponDiscount;
      return total < 0 ? 0 : total;
    }

    final total = booking.price - couponDiscount;
    return total < 0 ? 0 : total;
  }

  void _handleBookingTap(Booking booking) {
    debugLog('🔍 Booking tapped: ${booking.id} - Status: ${booking.status}');

    switch (booking.status.toLowerCase()) {
      case 'pending':
        // Go to WaitingForDriverScreen for pending orders
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => WaitingForDriverScreen(booking: booking),
          ),
        );
        break;

      case 'cancelled':
      case 'completed':
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CustomerOrderDetailScreen(booking: booking),
          ),
        );
        break;

      default:
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => CustomerOrderDetailScreen(booking: booking),
          ),
        );
        break;
    }
  }
}
