import 'package:flutter/material.dart';
import '../../../common/services/admin_service.dart';
import '../../../utils/debug_logger.dart';
import '../theme/admin_theme.dart';

/// Admin Driver Approval Screen
///
/// แสดงรายชื่อคนขับรอการอนุมัติ + คนขับทั้งหมด
/// Admin สามารถอนุมัติ/ปฏิเสธ/ระงับคนขับได้
class AdminDriverApprovalScreen extends StatefulWidget {
  const AdminDriverApprovalScreen({super.key});

  @override
  State<AdminDriverApprovalScreen> createState() => _AdminDriverApprovalScreenState();
}

class _AdminDriverApprovalScreenState extends State<AdminDriverApprovalScreen>
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  late TabController _tabController;

  List<Map<String, dynamic>> _pendingDrivers = [];
  List<Map<String, dynamic>> _allDrivers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadDrivers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDrivers() async {
    setState(() => _isLoading = true);
    try {
      final pending = await _adminService.getPendingDrivers();
      final all = await _adminService.getAllDrivers();
      if (mounted) {
        setState(() {
          _pendingDrivers = pending;
          _allDrivers = all;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugLog('❌ Error loading drivers: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveDriver(String driverId) async {
    final confirmed = await _showConfirmDialog(
      'อนุมัติคนขับ',
      'ต้องการอนุมัติคนขับคนนี้หรือไม่?',
    );
    if (confirmed != true) return;

    final success = await _adminService.approveDriver(driverId);
    if (success) {
      _showSnackBar('อนุมัติคนขับสำเร็จ', Colors.green);
      _loadDrivers();
    } else {
      _showSnackBar('เกิดข้อผิดพลาด', Colors.red);
    }
  }

  Future<void> _rejectDriver(String driverId) async {
    final reason = await _showReasonDialog('ปฏิเสธคนขับ');
    if (reason == null || reason.isEmpty) return;

    final success = await _adminService.rejectDriver(driverId, reason);
    if (success) {
      _showSnackBar('ปฏิเสธคนขับสำเร็จ', Colors.orange);
      _loadDrivers();
    } else {
      _showSnackBar('เกิดข้อผิดพลาด', Colors.red);
    }
  }

  Future<void> _suspendDriver(String driverId) async {
    final reason = await _showReasonDialog('ระงับคนขับ');
    if (reason == null || reason.isEmpty) return;

    final success = await _adminService.suspendUser(driverId, reason);
    if (success) {
      _showSnackBar('ระงับคนขับสำเร็จ', Colors.orange);
      _loadDrivers();
    } else {
      _showSnackBar('เกิดข้อผิดพลาด', Colors.red);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AdminTheme.background,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Page header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              children: [
                const Icon(Icons.directions_car_rounded, color: AdminTheme.primary, size: 28),
                const SizedBox(width: 12),
                const Text(
                  'จัดการคนขับ',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AdminTheme.textPrimary),
                ),
                const Spacer(),
                IconButton(onPressed: _loadDrivers, icon: const Icon(Icons.refresh_rounded), tooltip: 'รีเฟรช'),
              ],
            ),
          ),
          // Tab bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              controller: _tabController,
              indicatorColor: AdminTheme.primary,
              labelColor: AdminTheme.primary,
              unselectedLabelColor: AdminTheme.textSecondary,
              tabs: [
                Tab(text: 'รออนุมัติ (${_pendingDrivers.length})'),
                Tab(text: 'ทั้งหมด (${_allDrivers.length})'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AdminTheme.primary))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildDriverList(_pendingDrivers, isPending: true),
                      _buildDriverList(_allDrivers, isPending: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverList(List<Map<String, dynamic>> drivers, {required bool isPending}) {
    if (drivers.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.directions_car, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              isPending ? 'ไม่มีคนขับรออนุมัติ' : 'ยังไม่มีคนขับในระบบ',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadDrivers,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: drivers.length,
        itemBuilder: (context, index) => _buildDriverCard(drivers[index], isPending),
      ),
    );
  }

  Widget _buildDriverCard(Map<String, dynamic> driver, bool isPending) {
    final name = driver['full_name'] ?? 'ไม่ระบุชื่อ';
    final phone = driver['phone_number'] ?? '-';
    final status = driver['approval_status'] ?? 'pending';
    final vehicleType = driver['vehicle_type'] ?? '-';
    final vehiclePlate = driver['vehicle_plate'] ?? '-';
    final driverId = driver['id'] as String;

    Color statusColor;
    String statusText;
    switch (status) {
      case 'approved':
        statusColor = Colors.green;
        statusText = 'อนุมัติแล้ว';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'ปฏิเสธ';
        break;
      case 'suspended':
        statusColor = Colors.orange;
        statusText = 'ระงับ';
        break;
      default:
        statusColor = Colors.blue;
        statusText = 'รออนุมัติ';
    }

    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blue[50],
                  child: const Icon(Icons.person, color: Colors.blue, size: 28),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      Text(phone, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                _infoChip(Icons.directions_car, vehicleType),
                const SizedBox(width: 8),
                _infoChip(Icons.confirmation_number, vehiclePlate),
              ],
            ),
            if (driver['driver_license_url'] != null) ...[
              const SizedBox(height: 8),
              _infoChip(Icons.badge, 'มีใบขับขี่'),
            ],
            if (driver['rejection_reason'] != null && status == 'rejected') ...[
              const SizedBox(height: 8),
              Text(
                'เหตุผล: ${driver['rejection_reason']}',
                style: const TextStyle(fontSize: 12, color: Colors.red),
              ),
            ],
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectDriver(driverId),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('ปฏิเสธ'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveDriver(driverId),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('อนุมัติ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (status == 'approved') ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _suspendDriver(driverId),
                  icon: const Icon(Icons.block, size: 18),
                  label: const Text('ระงับ'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.orange,
                    side: const BorderSide(color: Colors.orange),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _infoChip(IconData icon, String text) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: Colors.grey[600]),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<bool?> _showConfirmDialog(String title, String message) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Future<String?> _showReasonDialog(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'ระบุเหตุผล',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
