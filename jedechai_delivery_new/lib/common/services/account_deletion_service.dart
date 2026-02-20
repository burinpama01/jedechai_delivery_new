import 'package:jedechai_delivery_new/utils/debug_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'auth_service.dart';

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

    // สร้างคำขอลบ
    await _supabase.from('account_deletion_requests').insert({
      'user_id': userId,
      'user_email': user?.email ?? '',
      'user_role': profile?['role'] ?? 'customer',
      'user_name': profile?['full_name'] ?? '',
      'reason': reason ?? '',
      'status': 'pending',
      'profile_backup': profile,
    });

    // อัปเดตสถานะใน profiles
    await _supabase
        .from('profiles')
        .update({'deletion_status': 'pending'})
        .eq('id', userId);

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
    final baseQuery = _supabase
        .from('account_deletion_requests')
        .select('*');

    final filtered = (statusFilter != null && statusFilter.isNotEmpty)
        ? baseQuery.eq('status', statusFilter)
        : baseQuery;

    final response = await filtered.order('requested_at', ascending: false);
    return List<Map<String, dynamic>>.from(response);
  }

  /// อนุมัติคำขอลบบัญชี
  static Future<void> approveRequest(int requestId) async {
    final adminId = AuthService.userId;

    // ดึงข้อมูลคำขอ
    final request = await _supabase
        .from('account_deletion_requests')
        .select('*')
        .eq('id', requestId)
        .single();

    final targetUserId = request['user_id'] as String;

    // อัปเดตสถานะคำขอ
    await _supabase.from('account_deletion_requests').update({
      'status': 'approved',
      'reviewed_at': DateTime.now().toIso8601String(),
      'reviewed_by': adminId,
    }).eq('id', requestId);

    // อัปเดตสถานะใน profiles
    await _supabase
        .from('profiles')
        .update({'deletion_status': 'approved'})
        .eq('id', targetUserId);

    debugLog('✅ Account deletion approved for $targetUserId by $adminId');
  }

  /// ปฏิเสธคำขอลบบัญชี
  static Future<void> rejectRequest(int requestId, {String? reason}) async {
    final adminId = AuthService.userId;

    // ดึงข้อมูลคำขอ
    final request = await _supabase
        .from('account_deletion_requests')
        .select('user_id')
        .eq('id', requestId)
        .single();

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
        .update({'deletion_status': null})
        .eq('id', targetUserId);

    debugLog('❌ Account deletion rejected for $targetUserId by $adminId');
  }
}
