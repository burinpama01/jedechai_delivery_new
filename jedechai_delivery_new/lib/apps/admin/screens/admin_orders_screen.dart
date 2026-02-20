import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../utils/debug_logger.dart';
import '../theme/admin_theme.dart';

/// Admin Orders Screen
///
/// แสดงรายการออเดอร์ทั้งหมดในระบบ
/// - กรองตาม service_type (ride, food, parcel)
/// - กรองตามสถานะ
/// - ดูรายละเอียดออเดอร์
class AdminOrdersScreen extends StatefulWidget {
  const AdminOrdersScreen({super.key});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final _client = Supabase.instance.client;

  List<Map<String, dynamic>> _orders = [];
  bool _isLoading = true;
  String _filterService = 'all';
  String _filterStatus = 'all';

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    try {
      var query = _client.from('bookings').select();

      if (_filterService != 'all') {
        query = query.eq('service_type', _filterService);
      }
      if (_filterStatus != 'all') {
        query = query.eq('status', _filterStatus);
      }

      final response = await query.order('created_at', ascending: false).limit(100);

      if (mounted) {
        setState(() {
          _orders = (response as List).cast<Map<String, dynamic>>();
          _isLoading = false;
        });
      }
    } catch (e) {
      debugLog('❌ Error loading orders: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTheme.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              children: [
                const Icon(Icons.receipt_long_rounded, color: AdminTheme.primary, size: 28),
                const SizedBox(width: 12),
                const Text('ออเดอร์ทั้งหมด', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AdminTheme.textPrimary)),
                const Spacer(),
                IconButton(onPressed: _loadOrders, icon: const Icon(Icons.refresh_rounded), tooltip: 'รีเฟรช'),
              ],
            ),
          ),
          _buildFilters(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AdminTheme.primary))
                : _orders.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.receipt_long, size: 64, color: Colors.grey[300]),
                            const SizedBox(height: 12),
                            Text('ไม่พบออเดอร์', style: TextStyle(fontSize: 16, color: Colors.grey[500])),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadOrders,
                        child: ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _orders.length,
                          itemBuilder: (context, index) => _buildOrderCard(_orders[index]),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: Colors.grey[50],
      child: Row(
        children: [
          // Service type filter
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _filterService,
              decoration: InputDecoration(
                labelText: 'บริการ',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                DropdownMenuItem(value: 'ride', child: Text('รับส่ง')),
                DropdownMenuItem(value: 'food', child: Text('อาหาร')),
                DropdownMenuItem(value: 'parcel', child: Text('พัสดุ')),
              ],
              onChanged: (v) {
                setState(() => _filterService = v!);
                _loadOrders();
              },
            ),
          ),
          const SizedBox(width: 8),
          // Status filter
          Expanded(
            child: DropdownButtonFormField<String>(
              initialValue: _filterStatus,
              decoration: InputDecoration(
                labelText: 'สถานะ',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(value: 'all', child: Text('ทั้งหมด')),
                DropdownMenuItem(value: 'pending', child: Text('รอ')),
                DropdownMenuItem(value: 'in_progress', child: Text('กำลังดำเนินการ')),
                DropdownMenuItem(value: 'completed', child: Text('เสร็จ')),
                DropdownMenuItem(value: 'cancelled', child: Text('ยกเลิก')),
              ],
              onChanged: (v) {
                setState(() => _filterStatus = v!);
                _loadOrders();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final serviceType = order['service_type'] ?? '-';
    final status = order['status'] ?? '-';
    final price = (order['price'] as num?)?.toDouble() ?? 0;
    final distanceKm = (order['distance_km'] as num?)?.toDouble() ?? 0;
    final pickupAddress = order['pickup_address'] ?? order['origin_address'] ?? '-';
    final destAddress =
        order['destination_address'] ?? order['dest_address'] ?? '-';
    final createdAt = order['created_at'] != null
        ? DateFormat('dd/MM/yyyy HH:mm')
            .format(DateTime.parse(order['created_at']).toLocal())
        : '-';

    // Service icon & color
    IconData serviceIcon;
    Color serviceColor;
    String serviceText;
    switch (serviceType) {
      case 'ride':
        serviceIcon = Icons.directions_car;
        serviceColor = Colors.blue;
        serviceText = 'รับส่ง';
        break;
      case 'food':
        serviceIcon = Icons.restaurant;
        serviceColor = Colors.orange;
        serviceText = 'อาหาร';
        break;
      case 'parcel':
        serviceIcon = Icons.local_shipping;
        serviceColor = Colors.purple;
        serviceText = 'พัสดุ';
        break;
      default:
        serviceIcon = Icons.receipt;
        serviceColor = Colors.grey;
        serviceText = serviceType;
    }

    // Status color
    Color statusColor;
    String statusText;
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusText = 'เสร็จ';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'ยกเลิก';
        break;
      case 'pending':
        statusColor = Colors.orange;
        statusText = 'รอ';
        break;
      case 'in_progress':
      case 'in_transit':
        statusColor = Colors.blue;
        statusText = 'กำลังดำเนินการ';
        break;
      default:
        statusColor = Colors.grey;
        statusText = status;
    }

    return Card(
      elevation: 1,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundColor: serviceColor.withValues(alpha: 0.1),
                  child: Icon(serviceIcon, color: serviceColor, size: 20),
                ),
                const SizedBox(width: 10),
                Text(serviceText,
                    style: TextStyle(
                        color: serviceColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(statusText,
                      style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 11)),
                ),
                const SizedBox(width: 8),
                Text(
                  '฿${price.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.my_location, size: 12, color: Colors.green[400]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(pickupAddress,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.location_on, size: 12, color: Colors.red[400]),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(destAddress,
                      style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Text('${distanceKm.toStringAsFixed(1)} กม.',
                    style: TextStyle(fontSize: 11, color: Colors.grey[500])),
                const Spacer(),
                Text(createdAt,
                    style: TextStyle(fontSize: 11, color: Colors.grey[400])),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
