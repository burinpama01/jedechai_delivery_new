import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/debug_logger.dart';
import 'auth_service.dart';
import 'wallet_service.dart';

/// WithdrawalService - บริการแจ้งถอนเงินสำหรับ driver/merchant
///
/// ฟีเจอร์:
/// - สร้างคำขอถอนเงิน (หักจาก wallet ทันที)
/// - ดูประวัติคำขอถอนเงิน
/// - ยกเลิกคำขอ (คืนเงินเข้า wallet)
class WithdrawalService {
  final SupabaseClient _client = Supabase.instance.client;
  final WalletService _walletService = WalletService();

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
      // 1. ตรวจสอบยอดเงินคงเหลือ
      final balance = await _walletService.getBalance(userId);
      if (balance < amount) {
        debugLog('❌ ยอดเงินไม่เพียงพอ: $balance < $amount');
        return false;
      }

      // 2. สร้างคำขอถอนเงินก่อน (ถ้า insert ล้มเหลว เงินจะไม่หาย)
      await _client.from('withdrawal_requests').insert({
        'user_id': userId,
        'amount': amount,
        'bank_name': bankName,
        'account_number': bankAccountNumber,
        'status': 'pending',
      });

      // 3. Phase 2: Atomic wallet deduction via RPC
      final rpcResult = await _client.rpc('wallet_deduct', params: {
        'p_user_id': userId,
        'p_amount': amount,
        'p_description': 'แจ้งถอนเงิน ฿${amount.ceil()} ไปยัง $bankName $bankAccountNumber',
        'p_type': 'withdrawal',
      });
      if (rpcResult is Map && rpcResult['success'] != true) {
        debugLog('❌ Wallet deduction failed: ${rpcResult['error']}');
        return false;
      }

      debugLog('✅ Withdrawal request created: ฿$amount');
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

  /// ยกเลิกคำขอถอนเงิน (เฉพาะสถานะ pending)
  Future<bool> cancelWithdrawalRequest(String requestId) async {
    final userId = AuthService.userId;
    if (userId == null) return false;

    try {
      // ดึงข้อมูลคำขอ
      final request = await _client
          .from('withdrawal_requests')
          .select()
          .eq('id', requestId)
          .eq('user_id', userId)
          .eq('status', 'pending')
          .maybeSingle();

      if (request == null) {
        debugLog('❌ ไม่พบคำขอถอนเงินที่สามารถยกเลิกได้');
        return false;
      }

      final amount = (request['amount'] as num).toDouble();

      // คืนเงินเข้า wallet
      final wallet = await _walletService.getDriverWallet(userId);
      if (wallet == null) return false;

      final newBalance = wallet.balance + amount;

      await _client.from('wallet_transactions').insert({
        'wallet_id': wallet.id,
        'amount': amount,
        'type': 'withdrawal_refund',
        'description': 'ยกเลิกคำขอถอนเงิน ฿${amount.ceil()}',
      });

      await _client
          .from('wallets')
          .update({'balance': newBalance})
          .eq('id', wallet.id);

      // อัปเดตสถานะคำขอ
      await _client
          .from('withdrawal_requests')
          .update({'status': 'cancelled'})
          .eq('id', requestId);

      debugLog('✅ Withdrawal request cancelled, refunded ฿$amount');
      return true;
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
