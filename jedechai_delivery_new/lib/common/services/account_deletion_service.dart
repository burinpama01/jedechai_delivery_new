import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';
import 'admin_line_notification_service.dart';
import 'notification_sender.dart';

/// Service สำหรับจัดการคำขอลบบัญชีผู้ใช้
class AccountDeletionService {
  static final _supabase = Supabase.instance.client;

  /// ส่งคำขอลบบัญชี
  static Future<void> requestDeletion({String? reason}) async {
    final userId = AuthService.userId;
    if (userId == null) throw Exception('ไม่พบข้อมูลผู้ใช้');

    // ดึงข้อมูลโปรไฟล์สำหรับ backup
    final profile = await _supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .maybeSingle();

    final user = AuthService.currentUser;

    // ตรวจสอบว่ามีคำขอที่รอดำเนินการอยู่แล้วหรือไม่
    final existing = await _supabase
        .from('account_deletion_requests')
        .select('id')
        .eq('user_id', userId)
        .eq('status', 'pending')
        .maybeSingle();
    if (existing != null) throw Exception('มีคำขอลบบัญชีที่รอดำเนินการอยู่แล้ว');

    // INSERT คำขอลบ แล้ว UPDATE profiles — ถ้า UPDATE ล้มเหลวให้ rollback INSERT
    final inserted = await _supabase.from('account_deletion_requests').insert({
      'user_id': userId,
      'user_email': user?.email ?? '',
      'user_role': profile?['role'] ?? 'customer',
      'user_name': profile?['full_name'] ?? '',
      'reason': reason ?? '',
      'status': 'pending',
      'profile_backup': profile,
    }).select('id').single();

    final newRequestId = inserted['id'];
    try {
      await _supabase
          .from('profiles')
          .update({'deletion_status': 'pending'}).eq('id', userId);
    } catch (e) {
      // Rollback: ลบ request ที่เพิ่งสร้าง
      await _supabase
          .from('account_deletion_requests')
          .delete()
          .eq('id', newRequestId);
      rethrow;
    }

    await AdminLineNotificationService.notify(
      eventType: 'account_deletion_request',
      title: 'JDC: มีคำขอลบบัญชีใหม่',
      message:
          'มีคำขอลบบัญชีใหม่จาก ${profile?['full_name'] ?? user?.email ?? userId}',
      data: {
        'user_id': userId,
        'email': user?.email ?? '',
        'role': profile?['role'] ?? 'customer',
        'name': profile?['full_name'] ?? '',
        'reason': reason ?? '',
      },
    );

    debugLog('🗑️ Account deletion requested for $userId');
  }

  /// ตรวจสอบสถานะการลบบัญชีของผู้ใช้ปัจจุบัน
  /// Returns: null = ปกติ, 'pending' = รอลบ, 'approved' = อนุมัติแล้ว
  static Future<String?> checkDeletionStatus() async {
    final userId = AuthService.userId;
    if (userId == null) return null;

    try {
      final profile = await _supabase
          .from('profiles')
          .select('deletion_status')
          .eq('id', userId)
          .maybeSingle();

      return profile?['deletion_status'] as String?;
    } catch (e) {
      debugLog('⚠️ Error checking deletion status: $e');
      return null;
    }
  }

  // ─── Admin Methods ───

  /// ดึงคำขอลบบัญชีทั้งหมด (สำหรับ admin)
  static Future<List<Map<String, dynamic>>> getAllRequests({
    String? statusFilter,
  }) async {
    final baseQuery = _supabase.from('account_deletion_requests').select('*');

    final filtered = (statusFilter != null && statusFilter.isNotEmpty)
        ? baseQuery.eq('status', statusFilter)
        : baseQuery;

    final response = await filtered.order('requested_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// อนุมัติคำขอลบบัญชี — เรียก Edge Function เพื่อลบ auth user ด้วย
  static Future<void> approveRequest(int requestId) async {
    final response = await _supabase.functions.invoke(
      'admin-actions',
      body: {'action': 'approve_account_deletion', 'id': requestId},
    );

    if (response.status != 200) {
      final body = response.data;
      final message = (body is Map ? body['error'] : null) ?? 'Approval failed (${response.status})';
      throw Exception(message);
    }

    debugLog('✅ Account deletion approved via Edge Function (request $requestId)');
  }

  /// ปฏิเสธคำขอลบบัญชี
  static Future<void> rejectRequest(int requestId, {String? reason}) async {
    final adminId = AuthService.userId;

    // ดึงข้อมูลคำขอ
    final request = await _supabase
        .from('account_deletion_requests')
        .select('user_id, status')
        .eq('id', requestId)
        .single();

    if ((request['status'] as String?) != 'pending') {
      throw Exception('คำขอนี้ไม่อยู่ในสถานะรอดำเนินการ (${request['status']})');
    }

    final targetUserId = request['user_id'] as String;

    // อัปเดตสถานะคำขอ
    await _supabase.from('account_deletion_requests').update({
      'status': 'rejected',
      'reviewed_at': DateTime.now().toIso8601String(),
      'reviewed_by': adminId,
      'rejection_reason': reason ?? '',
    }).eq('id', requestId);

    // ลบสถานะ deletion ใน profiles (กลับไปใช้งานได้ปกติ)
    await _supabase
        .from('profiles')
        .update({'deletion_status': null}).eq('id', targetUserId);

    // แจ้งเตือน user ว่าคำขอถูกปฏิเสธ
    await NotificationSender.sendToUser(
      userId: targetUserId,
      title: 'คำขอลบบัญชีถูกปฏิเสธ',
      body: reason != null && reason.isNotEmpty
          ? 'เหตุผล: $reason'
          : 'คำขอลบบัญชีของคุณถูกปฏิเสธ คุณสามารถเข้าใช้งานได้ตามปกติ',
      data: {
        'type': 'account.deletion.rejected',
        'reason': reason ?? '',
      },
    );

    debugLog('❌ Account deletion rejected for $targetUserId by $adminId');
  }
}
