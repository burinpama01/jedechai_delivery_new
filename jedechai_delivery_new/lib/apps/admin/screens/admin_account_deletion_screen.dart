import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../common/services/account_deletion_service.dart';
import '../../../theme/app_theme.dart';
import '../../../utils/debug_logger.dart';

/// Admin Account Deletion Management Screen
class AdminAccountDeletionScreen extends StatefulWidget {
  const AdminAccountDeletionScreen({super.key});

  @override
  State<AdminAccountDeletionScreen> createState() => _AdminAccountDeletionScreenState();
}

class _AdminAccountDeletionScreenState extends State<AdminAccountDeletionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _requests = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _loadRequests();
    });
    _loadRequests();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String get _currentFilter {
    switch (_tabController.index) {
      case 0: return 'pending';
      case 1: return 'approved';
      case 2: return 'rejected';
      default: return 'pending';
    }
  }

  Future<void> _loadRequests() async {
    setState(() { _isLoading = true; _error = null; });
    try {
      final data = await AccountDeletionService.getAllRequests(statusFilter: _currentFilter);
      if (mounted) setState(() { _requests = data; _isLoading = false; });
    } catch (e) {
      debugLog('❌ Error loading deletion requests: $e');
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  Future<void> _approveRequest(Map<String, dynamic> request) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('อนุมัติลบบัญชี?'),
        content: Text(
          'ยืนยันอนุมัติลบบัญชีของ\n${request['user_name'] ?? ''} (${request['user_email'] ?? ''})\n\nข้อมูลโปรไฟล์จะถูกเก็บไว้เป็น backup',
          textAlign: TextAlign.center,
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
            child: const Text('อนุมัติ'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AccountDeletionService.approveRequest(request['id'] as int);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('✅ อนุมัติลบบัญชีแล้ว'), backgroundColor: Colors.green),
          );
        }
        _loadRequests();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ ไม่สามารถอนุมัติได้: $e'), backgroundColor: Colors.red),
          );
        }
      }
    }
  }

  Future<void> _rejectRequest(Map<String, dynamic> request) async {
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        icon: Icon(Icons.cancel, color: Colors.red[700], size: 48),
        title: const Text('ปฏิเสธคำขอลบบัญชี?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('ปฏิเสธคำขอลบบัญชีของ\n${request['user_name'] ?? ''} (${request['user_email'] ?? ''})', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'เหตุผลในการปฏิเสธ (ไม่บังคับ)',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
          ],
        ),
        actionsAlignment: MainAxisAlignment.center,
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('ยกเลิก')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: const Text('ปฏิเสธ'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await AccountDeletionService.rejectRequest(request['id'] as int, reason: reasonController.text.trim());
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('❌ ปฏิเสธคำขอลบบัญชีแล้ว (บัญชีกลับมาใช้งานได้)'), backgroundColor: Colors.orange),
          );
        }
        _loadRequests();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('❌ ไม่สามารถปฏิเสธได้: $e'), backgroundColor: Colors.red),
          );
        }
      }
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
                const Icon(Icons.person_off_rounded, color: Color(0xFF1565C0), size: 28),
                const SizedBox(width: 12),
                const Text('จัดการคำขอลบบัญชี', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
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
              tabs: const [
                Tab(text: 'รออนุมัติ'),
                Tab(text: 'อนุมัติแล้ว'),
                Tab(text: 'ปฏิเสธ'),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF1565C0)))
                : _error != null
                    ? Center(child: Text('เกิดข้อผิดพลาด: $_error'))
                    : _requests.isEmpty
                        ? _buildEmptyState()
                        : RefreshIndicator(
                            onRefresh: _loadRequests,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: _requests.length,
                              itemBuilder: (ctx, idx) => _buildRequestCard(_requests[idx]),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final labels = ['ไม่มีคำขอที่รออนุมัติ', 'ไม่มีคำขอที่อนุมัติแล้ว', 'ไม่มีคำขอที่ปฏิเสธ'];
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text(labels[_tabController.index], style: TextStyle(fontSize: 16, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> request) {
    final colorScheme = Theme.of(context).colorScheme;
    final status = request['status'] as String? ?? 'pending';
    final isPending = status == 'pending';
    final isApproved = status == 'approved';
    final role = request['user_role'] as String? ?? '';
    final roleLabels = {'customer': 'ลูกค้า', 'driver': 'คนขับ', 'merchant': 'ร้านค้า'};
    final roleColors = {'customer': Colors.blue, 'driver': AppTheme.primaryGreen, 'merchant': AppTheme.accentOrange};

    final requestedAt = request['requested_at'] != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(request['requested_at']).toLocal())
        : '-';
    final reviewedAt = request['reviewed_at'] != null
        ? DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(request['reviewed_at']).toLocal())
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8, offset: const Offset(0, 2))],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: name + role badge
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: (roleColors[role] ?? Colors.grey).withValues(alpha: 0.15),
                  child: Icon(
                    role == 'driver' ? Icons.directions_car : role == 'merchant' ? Icons.store : Icons.person,
                    color: roleColors[role] ?? Colors.grey,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request['user_name'] ?? 'ไม่ทราบชื่อ',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        request['user_email'] ?? '',
                        style: TextStyle(fontSize: 13, color: Colors.grey[500]),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (roleColors[role] ?? Colors.grey).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    roleLabels[role] ?? role,
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: roleColors[role] ?? Colors.grey),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Reason
            if ((request['reason'] as String? ?? '').isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.grey[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'เหตุผล: ${request['reason']}',
                  style: TextStyle(fontSize: 13, color: colorScheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Rejection reason
            if ((request['rejection_reason'] as String? ?? '').isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'เหตุผลปฏิเสธ: ${request['rejection_reason']}',
                  style: TextStyle(fontSize: 13, color: Colors.red[700]),
                ),
              ),
              const SizedBox(height: 10),
            ],

            // Dates
            Row(
              children: [
                Icon(Icons.schedule, size: 14, color: Colors.grey[400]),
                const SizedBox(width: 4),
                Text('ส่งคำขอ: $requestedAt', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                if (reviewedAt != null) ...[
                  const Spacer(),
                  Icon(isApproved ? Icons.check : Icons.close, size: 14, color: isApproved ? Colors.green : Colors.red),
                  const SizedBox(width: 4),
                  Text('ตรวจสอบ: $reviewedAt', style: TextStyle(fontSize: 12, color: Colors.grey[500])),
                ],
              ],
            ),

            // Action buttons (only for pending)
            if (isPending) ...[
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _rejectRequest(request),
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
                      onPressed: () => _approveRequest(request),
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
