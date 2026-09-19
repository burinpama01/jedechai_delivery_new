import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/debug_logger.dart';
import 'admin_line_notification_service.dart';
import 'auth_service.dart';

/// WithdrawalService - บริการแจ้งถอนเงินสำหรับ driver/merchant
///
/// ฟีเจอร์:
/// - สร้างคำขอถอนเงิน (หักจาก wallet ทันที)
/// - ดูประวัติคำขอถอนเงิน
/// - ยกเลิกคำขอ (คืนเงินเข้า wallet)
class WithdrawalService {
  final SupabaseClient _client = Supabase.instance.client;

  /// สร้างคำขอถอนเงิน
  ///
  /// หักเงินจาก wallet ทันที แล้วรอ admin อนุมัติ
  /// ถ้า admin ปฏิเสธ จะคืนเงินเข้า wallet
  Future<bool> createWithdrawalRequest({
    required double amount,
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountName,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) {
      debugLog('❌ User not authenticated');
      return false;
    }

    // Phase 6: Validate withdrawal amount (min/max)
    const double minWithdrawal = 100.0;
    const double maxWithdrawal = 50000.0;
    if (amount < minWithdrawal) {
      debugLog('❌ จำนวนเงินต่ำกว่าขั้นต่ำ: $amount < $minWithdrawal');
      return false;
    }
    if (amount > maxWithdrawal) {
      debugLog('❌ จำนวนเงินเกินขีดจำกัด: $amount > $maxWithdrawal');
      return false;
    }

    try {
      final rpcResult =
          await _client.rpc('create_wallet_withdrawal_request', params: {
        'p_user_id': userId,
        'p_amount': amount,
        'p_bank_name': bankName,
        'p_bank_account_number': bankAccountNumber,
        'p_bank_account_name': bankAccountName,
      });
      if (rpcResult is Map && rpcResult['success'] != true) {
        debugLog('❌ Withdrawal request failed: ${rpcResult['error']}');
        return false;
      }

      debugLog('✅ Withdrawal request created: ฿$amount');
      await AdminLineNotificationService.notify(
        eventType: 'withdrawal_request',
        title: 'JDC: คำขอถอนเงินใหม่',
        message:
            'มีคำขอถอนเงินใหม่ จำนวน ฿${amount.toStringAsFixed(0)} รอแอดมินตรวจสอบ',
        data: {
          'user_id': userId,
          'amount': amount.toStringAsFixed(0),
          'bank_name': bankName,
          'account_number': bankAccountNumber,
          'account_name': bankAccountName,
        },
      );

      return true;
    } catch (e) {
      debugLog('❌ Error creating withdrawal request: $e');
      return false;
    }
  }

  /// ดูประวัติคำขอถอนเงินของตัวเอง
  Future<List<Map<String, dynamic>>> getMyWithdrawalRequests() async {
    final userId = AuthService.userId;
    if (userId == null) return [];

    try {
      final response = await _client
          .from('withdrawal_requests')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugLog('❌ Error fetching withdrawal requests: $e');
      return [];
    }
  }

  /// ยกเลิกคำขอถอนเงิน (เฉพาะสถานะ pending) — คืนเงินผ่าน RPC แบบ atomic
  Future<bool> cancelWithdrawalRequest(String requestId) async {
    if (AuthService.userId == null) return false;
    try {
      final result = await _client.rpc(
        'cancel_wallet_withdrawal_request',
        params: {'p_request_id': requestId},
      );
      if (result is Map && result['success'] == true) {
        debugLog('✅ Withdrawal request cancelled, refunded ฿${result['amount']}');
        return true;
      }
      debugLog('❌ Cancel withdrawal failed: $result');
      return false;
    } catch (e) {
      debugLog('❌ Error cancelling withdrawal request: $e');
      return false;
    }
  }

  /// ดึงข้อมูลบัญชีธนาคารจาก profile
  Future<Map<String, String?>> getBankInfo() async {
    final userId = AuthService.userId;
    if (userId == null) return {};

    try {
      final profile = await _client
          .from('profiles')
          .select('bank_name, bank_account_number, bank_account_name')
          .eq('id', userId)
          .maybeSingle();

      if (profile == null) return {};

      return {
        'bank_name': profile['bank_name'] as String?,
        'bank_account_number': profile['bank_account_number'] as String?,
        'bank_account_name': profile['bank_account_name'] as String?,
      };
    } catch (e) {
      debugLog('❌ Error fetching bank info: $e');
      return {};
    }
  }

  /// บันทึกข้อมูลบัญชีธนาคารใน profile
  Future<bool> saveBankInfo({
    required String bankName,
    required String bankAccountNumber,
    required String bankAccountName,
  }) async {
    final userId = AuthService.userId;
    if (userId == null) return false;

    try {
      await _client.from('profiles').update({
        'bank_name': bankName,
        'bank_account_number': bankAccountNumber,
        'bank_account_name': bankAccountName,
      }).eq('id', userId);

      return true;
    } catch (e) {
      debugLog('❌ Error saving bank info: $e');
      return false;
    }
  }
}
