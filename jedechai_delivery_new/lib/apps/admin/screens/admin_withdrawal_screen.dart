import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/services/admin_service.dart';
import '../../../common/services/image_picker_service.dart';
import '../../../common/services/storage_service.dart';
import '../../../utils/debug_logger.dart';

/// Admin Withdrawal Screen
///
/// จัดการคำขอถอนเงินจากคนขับ/ร้านค้า
/// - ดูรายการรอดำเนินการ
/// - อนุมัติ (แนบสลิปโอนเงิน)
/// - ปฏิเสธ (คืนเงินเข้ากระเป๋า)
class AdminWithdrawalScreen extends StatefulWidget {
  const AdminWithdrawalScreen({super.key});

  @override
  State<AdminWithdrawalScreen> createState() => _AdminWithdrawalScreenState();
}

class _AdminWithdrawalScreenState extends State<AdminWithdrawalScreen>
    with SingleTickerProviderStateMixin {
  final AdminService _adminService = AdminService();
  late TabController _tabController;

  List<Map<String, dynamic>> _pendingRequests = [];
  List<Map<String, dynamic>> _completedRequests = [];
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
      final pending =
          await _adminService.getWithdrawalRequests(status: 'pending');
      final completed =
          await _adminService.getWithdrawalRequests(status: 'completed');
      final rejected =
          await _adminService.getWithdrawalRequests(status: 'rejected');

      if (mounted) {
        setState(() {
          _pendingRequests = pending;
          _completedRequests = [...completed, ...rejected];
          _isLoading = false;
        });
      }
    } catch (e) {
      debugLog('❌ Error loading withdrawal requests: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _approveWithdrawal(Map<String, dynamic> request) async {
    final requestId = request['id'] as String;
    final amount = (request['amount'] as num).toDouble();
    final bankName = request['bank_name'] ?? '';
    final accountNumber = request['bank_account_number'] ?? '';
    final accountName = request['bank_account_name'] ?? '';

    // แสดง dialog ยืนยัน + แนบสลิป
    final result = await showDialog<Map<String, String?>>(
      context: context,
      builder: (ctx) => _ApproveWithdrawalDialog(
        amount: amount,
        bankName: bankName,
        accountNumber: accountNumber,
        accountName: accountName,
      ),
    );

    if (result == null) return;

    final success = await _adminService.approveWithdrawal(
      requestId: requestId,
      transferSlipUrl: result['slip_url'],
      adminNote: result['note'],
    );

    if (success) {
      _showSnackBar('อนุมัติถอนเงินสำเร็จ', Colors.green);
      _loadRequests();
    } else {
      _showSnackBar('เกิดข้อผิดพลาด', Colors.red);
    }
  }

  Future<void> _rejectWithdrawal(String requestId) async {
    final reason = await _showReasonDialog('ปฏิเสธคำขอถอนเงิน');
    if (reason == null || reason.isEmpty) return;

    final success = await _adminService.rejectWithdrawal(
      requestId: requestId,
      reason: reason,
    );

    if (success) {
      _showSnackBar('ปฏิเสธคำขอถอนเงิน (คืนเงินเข้ากระเป๋าแล้ว)', Colors.orange);
      _loadRequests();
    } else {
      _showSnackBar('เกิดข้อผิดพลาด', Colors.red);
    }
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
                const Icon(Icons.account_balance_wallet_rounded, color: Color(0xFF1565C0), size: 28),
                const SizedBox(width: 12),
                const Text('จัดการถอนเงิน', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
                Tab(text: 'ดำเนินการแล้ว (${_completedRequests.length})'),
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
                      _buildRequestList(_completedRequests, isPending: false),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestList(List<Map<String, dynamic>> requests,
      {required bool isPending}) {
    if (requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.account_balance_wallet, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 12),
            Text(
              isPending ? 'ไม่มีคำขอรอดำเนินการ' : 'ยังไม่มีรายการ',
              style: TextStyle(fontSize: 16, color: Colors.grey[500]),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: requests.length,
        itemBuilder: (context, index) =>
            _buildRequestCard(requests[index], isPending),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request, bool isPending) {
    final amount = (request['amount'] as num).toDouble();
    final bankName = request['bank_name'] ?? '-';
    final accountNumber = request['bank_account_number'] ?? '-';
    final accountName = request['bank_account_name'] ?? '-';
    final status = request['status'] ?? 'pending';
    final createdAt = request['created_at'] != null
        ? DateFormat('dd/MM/yyyy HH:mm')
            .format(DateTime.parse(request['created_at']).toLocal())
        : '-';

    // ข้อมูลผู้ขอ
    final profile = request['profiles'] as Map<String, dynamic>?;
    final userName = profile?['full_name'] ?? 'ไม่ระบุ';
    final userRole = profile?['role'] ?? '-';

    Color statusColor;
    String statusText;
    switch (status) {
      case 'completed':
        statusColor = Colors.green;
        statusText = 'โอนแล้ว';
        break;
      case 'rejected':
        statusColor = Colors.red;
        statusText = 'ปฏิเสธ';
        break;
      default:
        statusColor = Colors.orange;
        statusText = 'รอดำเนินการ';
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
                  radius: 22,
                  backgroundColor: Colors.orange[50],
                  child: const Icon(Icons.account_balance_wallet,
                      color: Colors.orange, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(userName,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.bold)),
                      Text('$userRole | $createdAt',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey[500])),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 12),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            // จำนวนเงิน
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('จำนวนเงิน',
                    style: TextStyle(fontSize: 13, color: Colors.grey)),
                Text(
                  '฿${NumberFormat('#,##0').format(amount.ceil())}',
                  style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // ข้อมูลบัญชี
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('ธนาคาร: $bankName',
                      style: const TextStyle(fontSize: 13)),
                  Text('เลขบัญชี: $accountNumber',
                      style: const TextStyle(fontSize: 13)),
                  Text('ชื่อบัญชี: $accountName',
                      style: const TextStyle(fontSize: 13)),
                ],
              ),
            ),
            if (request['admin_note'] != null) ...[
              const SizedBox(height: 8),
              Text('หมายเหตุ: ${request['admin_note']}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600])),
            ],
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          _rejectWithdrawal(request['id'] as String),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('ปฏิเสธ'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red,
                        side: const BorderSide(color: Colors.red),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _approveWithdrawal(request),
                      icon: const Icon(Icons.send, size: 18),
                      label: const Text('โอนเงิน'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8)),
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

  void _showSnackBar(String message, Color color) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: color),
    );
  }

  Future<String?> _showReasonDialog(String title) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title:
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: InputDecoration(
            labelText: 'ระบุเหตุผล',
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
            child:
                const Text('ยืนยัน', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}

/// Dialog สำหรับอนุมัติถอนเงิน + แนบสลิป
class _ApproveWithdrawalDialog extends StatefulWidget {
  final double amount;
  final String bankName;
  final String accountNumber;
  final String accountName;

  const _ApproveWithdrawalDialog({
    required this.amount,
    required this.bankName,
    required this.accountNumber,
    required this.accountName,
  });

  @override
  State<_ApproveWithdrawalDialog> createState() =>
      _ApproveWithdrawalDialogState();
}

class _ApproveWithdrawalDialogState extends State<_ApproveWithdrawalDialog> {
  final _noteController = TextEditingController();
  String? _slipUrl;
  bool _isUploading = false;

  Future<void> _uploadSlip() async {
    setState(() => _isUploading = true);
    try {
      final file = await ImagePickerService.showImageSourceDialog(context);
      if (file != null) {
        final url = await StorageService.uploadImage(
          imageFile: file,
          folder: 'withdrawal_slips',
          metadata: {'type': 'transfer_slip'},
        );
        if (mounted) {
          setState(() => _slipUrl = url);
        }
      }
    } catch (e) {
      debugLog('❌ Error uploading slip: $e');
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('ยืนยันโอนเงิน',
          style: TextStyle(fontWeight: FontWeight.bold)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '฿${NumberFormat('#,##0').format(widget.amount.ceil())}',
              style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.orange),
            ),
            const SizedBox(height: 8),
            Text('ธนาคาร: ${widget.bankName}'),
            Text('เลขบัญชี: ${widget.accountNumber}'),
            Text('ชื่อบัญชี: ${widget.accountName}'),
            const SizedBox(height: 16),
            // แนบสลิป
            OutlinedButton.icon(
              onPressed: _isUploading ? null : _uploadSlip,
              icon: _isUploading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(_slipUrl != null ? Icons.check : Icons.upload),
              label: Text(_slipUrl != null ? 'แนบสลิปแล้ว' : 'แนบสลิปโอนเงิน'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: 'หมายเหตุ (ไม่บังคับ)',
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(null),
          child: const Text('ยกเลิก'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop({
              'slip_url': _slipUrl,
              'note': _noteController.text.isNotEmpty
                  ? _noteController.text
                  : null,
            });
          },
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('ยืนยันโอนเงิน',
              style: TextStyle(color: Colors.white)),
        ),
      ],
    );
  }
}
