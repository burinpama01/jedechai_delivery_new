import 'package:flutter/material.dart';
import '../services/auth_service.dart';

/// หน้ารอการอนุมัติจากแอดมิน
/// แสดงเมื่อคนขับหรือร้านค้าลงทะเบียนแล้วแต่ยังไม่ได้รับการอนุมัติ
class PendingApprovalScreen extends StatelessWidget {
  final String role;
  final String approvalStatus;
  final String? rejectionReason;

  const PendingApprovalScreen({
    super.key,
    required this.role,
    this.approvalStatus = 'pending',
    this.rejectionReason,
  });

  @override
  Widget build(BuildContext context) {
    final isSuspended = approvalStatus == 'suspended';
    final isRejected = approvalStatus == 'rejected';
    final hasReason = rejectionReason != null && rejectionReason!.isNotEmpty;
    final roleText = role == 'driver' ? 'คนขับ' : 'ร้านค้า';

    // Determine colors/icons based on status
    final Color statusColor = isSuspended ? Colors.red.shade700 : isRejected ? Colors.red : Colors.orange;
    final IconData statusIcon = isSuspended ? Icons.block : isRejected ? Icons.cancel_outlined : Icons.hourglass_top;
    final String titleText = isSuspended ? 'บัญชีถูกระงับ' : isRejected ? 'การสมัครถูกปฏิเสธ' : 'รอการอนุมัติ';
    final String subtitleText = isSuspended
        ? 'บัญชี$roleTextของคุณถูกระงับการใช้งาน\nกรุณาติดต่อแอดมินเพื่อดำเนินการ'
        : isRejected
            ? 'การสมัครเป็น$roleTextของคุณถูกปฏิเสธ'
            : 'บัญชี$roleTextของคุณกำลังรอการอนุมัติจากแอดมิน';

    return Scaffold(
      backgroundColor: const Color(0xFFF6F2EE),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Icon(statusIcon, size: 64, color: statusColor),
                ),
                const SizedBox(height: 32),
                Text(
                  titleText,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A2E),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  subtitleText,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
                if ((isRejected || isSuspended) && hasReason) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.red, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'เหตุผล: $rejectionReason',
                            style: const TextStyle(
                              color: Colors.red,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (isSuspended) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.support_agent, color: Colors.blue, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'ติดต่อแอดมินเพื่อขอข้อมูลเพิ่มเติม\nหรืออุทธรณ์การระงับ',
                            style: TextStyle(
                              color: Colors.blue[700],
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (!isRejected && !isSuspended) ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.2)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Colors.orange, size: 20),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'แอดมินจะตรวจสอบข้อมูลของคุณ\nและอนุมัติโดยเร็วที่สุด',
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                              height: 1.4,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      await AuthService.signOut();
                    },
                    icon: const Icon(Icons.logout),
                    label: const Text(
                      'ออกจากระบบ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.grey[700],
                      side: BorderSide(color: Colors.grey[300]!),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
