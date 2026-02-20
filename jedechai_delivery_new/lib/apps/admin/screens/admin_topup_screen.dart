import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/services/admin_service.dart';
import '../../../common/services/notification_sender.dart';
import '../../../utils/debug_logger.dart';

/// Admin Top-Up Approval Screen
///
/// จัดการคำขอเติมเงินจากคนขับ
/// - ดูรายการรอดำเนินการ
/// - อนุมัติ (เติมเงินเข้า wallet)
/// - ปฏิเสธ
class AdminTopUpScreen extends StatefulWidget {
  const AdminTopUpScreen({super.key});

  @override
  State<AdminTopUpScreen> createState() => _AdminTopUpScreenState();
}

class _AdminTopUpScreenState extends State<AdminTopUpScreen>
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  late TabController _tabController;

  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _processedRequests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadRequests() async {
    setState(() => _isLoading = true);
    try {
      final pending = await _adminService.getTopUpRequests(status: 'pending');
      final completed = await _adminService.getTopUpRequests(status: 'completed');
      final rejected = await _adminService.getTopUpRequests(status: 'rejected');

      if (mounted) {
        setState(() {
          _pendingRequests = pending;
          _processedRequests = [...completed, ...rejected];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugLog('❌ Error loading topup requests: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveTopUp(Map<String, dynamic> request) async {
    final requestId = request['id'] as String;
    final amount = (request['amount'] as num).toDouble();
    final userId = request['user_id'] as String;
    final profile = request['profiles'] as Map<String, dynamic>?;
    final driverName = profile?['full_name'] ?? 'คนขับ';

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.check_circle_outline, color: Colors.green, size: 48),
        title: const Text('ยืนยันอนุมัติเติมเงิน', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$driverName', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              '฿${NumberFormat('#,##0').format(amount)}',
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.green),
            ),
            const SizedBox(height: 8),
            Text('เงินจะถูกเติมเข้ากระเป๋าของคนขับทันที',
                style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                textAlign: TextAlign.center),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('ยกเลิก'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green,
              foregroundColor: Colors.white,
            ),
            child: const Text('อนุมัติ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await _adminService.approveTopUp(requestId);
    if (success) {
      _showSnackBar('อนุมัติเติมเงิน ฿${amount.toStringAsFixed(0)} สำเร็จ', Colors.green);
      // แจ้งเตือนคนขับ
      try {
        await NotificationSender.sendToUser(
          userId: userId,
          title: '✅ เติมเงินสำเร็จ',
          body: 'คำขอเติมเงิน ฿${amount.toStringAsFixed(0)} ได้รับการอนุมัติแล้ว',
        );
      } catch (_) {}
      _loadRequests();
    } else {
      _showSnackBar('เกิดข้อผิดพลาด', Colors.red);
    }
  }

  Future<void> _rejectTopUp(Map<String, dynamic> request) async {
    final requestId = request['id'] as String;
    final amount = (request['amount'] as num).toDouble();
    final userId = request['user_id'] as String;

    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) {
        final controller = TextEditingController();
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          icon: const Icon(Icons.cancel_outlined, color: Colors.red, size: 48),
          title: const Text('ปฏิเสธคำขอเติมเงิน', style: TextStyle(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('฿${NumberFormat('#,##0').format(amount)}',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                decoration: InputDecoration(
                  labelText: 'เหตุผลที่ปฏิเสธ',
                  hintText: 'เช่น ไม่พบหลักฐานการโอน',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
                maxLines: 2,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, null),
              child: const Text('ยกเลิก'),
            ),
            ElevatedButton(
              onPressed: () {
                final text = controller.text.trim();
                Navigator.pop(ctx, text.isEmpty ? 'ไม่ระบุเหตุผล' : text);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('ปฏิเสธ'),
            ),
          ],
        );
      },
    );

    if (reason == null) return;

    final success = await _adminService.rejectTopUp(requestId, reason);
    if (success) {
      _showSnackBar('ปฏิเสธคำขอเติมเงินแล้ว', Colors.orange);
      // แจ้งเตือนคนขับ
      try {
        await NotificationSender.sendToUser(
          userId: userId,
          title: '❌ คำขอเติมเงินถูกปฏิเสธ',
          body: 'คำขอเติมเงิน ฿${amount.toStringAsFixed(0)} ถูกปฏิเสธ: $reason',
        );
      } catch (_) {}
      _loadRequests();
    } else {
      _showSnackBar('เกิดข้อผิดพลาด', Colors.red);
    }
  }

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: color,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
            child: Row(
              children: [
                const Icon(Icons.add_card_rounded, color: Color(0xFF1565C0), size: 28),
                const SizedBox(width: 12),
                const Text('อนุมัติเติมเงิน', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const Spacer(),
                IconButton(onPressed: _loadRequests, icon: const Icon(Icons.refresh_rounded), tooltip: 'รีเฟรช'),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF1565C0),
              labelColor: const Color(0xFF1565C0),
              unselectedLabelColor: const Color(0xFF64748B),
              tabs: [
                Tab(text: 'รอดำเนินการ (${_pendingRequests.length})'),
                Tab(text: 'ดำเนินการแล้ว (${_processedRequests.length})'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)))
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildRequestList(_pendingRequests, isPending: true),
                      _buildRequestList(_processedRequests, isPending: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestList(List<Map<String, dynamic>> requests, {required bool isPending}) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isPending ? Icons.hourglass_empty : Icons.check_circle_outline,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              isPending ? 'ไม่มีคำขอเติมเงินรอดำเนินการ' : 'ยังไม่มีรายการ',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: requests.length,
      itemBuilder: (context, index) {
        final request = requests[index];
        return _buildRequestCard(request, isPending: isPending);
      },
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request, {required bool isPending}) {
    final amount = (request['amount'] as num?)?.toDouble() ?? 0;
    final status = request['status'] as String? ?? 'pending';
    final createdAt = request['created_at'] != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(request['created_at']).toLocal())
        : '-';
    final processedAt = request['processed_at'] != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(request['processed_at']).toLocal())
        : null;
    final profile = request['profiles'] as Map<String, dynamic>?;
    final driverName = profile?['full_name'] ?? '-';
    final phone = profile?['phone_number'] ?? '';

    final statusColor = status == 'completed'
        ? Colors.green
        : status == 'rejected'
            ? Colors.red
            : Colors.orange;
    final statusText = status == 'completed'
        ? 'อนุมัติแล้ว'
        : status == 'rejected'
            ? 'ปฏิเสธ'
            : 'รอดำเนินการ';
    final statusIcon = status == 'completed'
        ? Icons.check_circle
        : status == 'rejected'
            ? Icons.cancel
            : Icons.hourglass_top;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: ชื่อ + สถานะ
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blue[50],
                  child: Icon(Icons.person, color: Colors.blue[400]),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driverName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      if (phone.isNotEmpty)
                        Text(phone, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 14, color: statusColor),
                      const SizedBox(width: 4),
                      Text(statusText,
                          style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // จำนวนเงิน
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.account_balance_wallet, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    '฿${NumberFormat('#,##0').format(amount)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // วันที่
            Row(
              children: [
                Icon(Icons.access_time, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text('แจ้งเมื่อ: $createdAt', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              ],
            ),
            if (processedAt != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.done_all, size: 14, color: Colors.grey[400]),
                  const SizedBox(width: 4),
                  Text('ดำเนินการเมื่อ: $processedAt',
                      style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ),
            ],
            // ปุ่มอนุมัติ/ปฏิเสธ
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectTopUp(request),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('ปฏิเสธ'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveTopUp(request),
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('อนุมัติ'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                      ),
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
}
