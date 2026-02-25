import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/debug_logger.dart';
import 'auth_service.dart';

/// AdminService - บริการจัดการระบบ Admin Back-office
///
/// ฟีเจอร์:
/// - อนุมัติ/ปฏิเสธคนขับ
/// - อนุมัติ/ปฏิเสธร้านค้า
/// - จัดการคำขอถอนเงิน
/// - ดูภาพรวมระบบ (Dashboard)
/// - บันทึก admin actions
class AdminService {
  final SupabaseClient _client = Supabase.instance.client;

  /// Phase 3C: Verify caller is admin before executing any privileged method.
  /// Throws if the current user is not an admin.
  Future<void> _ensureAdmin() async {
    final role = await AuthService.getUserRole();
    if (role != 'admin') {
      throw Exception('Forbidden: admin role required (current: $role)');
    }
  }

  // ========================================
  // Dashboard / Overview
  // ========================================

  /// ดึงข้อมูลภาพรวมระบบ
  Future<Map<String, dynamic>> getDashboardStats() async {
    await _ensureAdmin();
    try {
      // จำนวนออเดอร์วันนี้
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day).toIso8601String();

      final todayBookings = await _client
          .from('bookings')
          .select('id')
          .gte('created_at', startOfDay);

      // จำนวนออเดอร์ที่เสร็จวันนี้
      final completedToday = await _client
          .from('bookings')
          .select('id')
          .gte('created_at', startOfDay)
          .eq('status', 'completed');

      // รายได้วันนี้
      final revenueToday = await _client
          .from('bookings')
          .select('price')
          .gte('created_at', startOfDay)
          .eq('status', 'completed');

      double totalRevenue = 0;
      for (final row in revenueToday) {
        totalRevenue += (row['price'] as num?)?.toDouble() ?? 0;
      }

      // คนขับรอการอนุมัติ
      final pendingDrivers = await _client
          .from('profiles')
          .select('id')
          .eq('role', 'driver')
          .eq('approval_status', 'pending');

      // ร้านค้ารอการอนุมัติ
      final pendingMerchants = await _client
          .from('profiles')
          .select('id')
          .eq('role', 'merchant')
          .eq('approval_status', 'pending');

      // คำขอถอนเงินรอดำเนินการ
      final pendingWithdrawals = await _client
          .from('withdrawal_requests')
          .select('id')
          .eq('status', 'pending');

      // คำขอเติมเงินรอดำเนินการ
      List pendingTopups = [];
      try {
        pendingTopups = await _client
            .from('topup_requests')
            .select('id')
            .eq('status', 'pending');
      } catch (_) {}

      // จำนวนผู้ใช้ทั้งหมด
      final totalUsers = await _client.from('profiles').select('id');

      // จำนวนผู้ใช้/ออนไลน์ตามประเภท
      final profileRows = await _client.from('profiles').select('role, is_online');
      final profiles = (profileRows as List).cast<Map<String, dynamic>>();

      bool isOnline(dynamic val) {
        if (val is bool) return val;
        if (val is String) return val.toLowerCase() == 'true';
        return false;
      }
      int countByRole(String role) => profiles.where((p) => p['role'] == role).length;
      int countOnlineByRole(String role) => profiles
          .where((p) => p['role'] == role && isOnline(p['is_online']))
          .length;

      final totalCustomers = countByRole('customer');
      final totalDrivers = countByRole('driver');
      final totalMerchants = countByRole('merchant');
      final onlineCustomers = countOnlineByRole('customer');
      final onlineDrivers = countOnlineByRole('driver');
      final onlineMerchants = countOnlineByRole('merchant');

      return {
        'today_orders': (todayBookings as List).length,
        'completed_today': (completedToday as List).length,
        'revenue_today': totalRevenue,
        'pending_drivers': (pendingDrivers as List).length,
        'pending_merchants': (pendingMerchants as List).length,
        'pending_withdrawals': (pendingWithdrawals as List).length,
        'pending_topups': pendingTopups.length,
        'total_users': (totalUsers as List).length,
        'total_customers': totalCustomers,
        'total_drivers': totalDrivers,
        'total_merchants': totalMerchants,
        'online_customers': onlineCustomers,
        'online_drivers': onlineDrivers,
        'online_merchants': onlineMerchants,
        'online_users_total': onlineCustomers + onlineDrivers + onlineMerchants,
      };
    } catch (e) {
      debugLog('❌ Error fetching dashboard stats: $e');
      return {};
    }
  }

  /// ดึงข้อมูลรายได้ย้อนหลัง 7 วัน
  Future<List<Map<String, dynamic>>> getRevenueChart({int days = 7}) async {
    try {
      final results = <Map<String, dynamic>>[];
      final now = DateTime.now();

      for (int i = days - 1; i >= 0; i--) {
        final date = DateTime(now.year, now.month, now.day - i);
        final nextDate = date.add(const Duration(days: 1));

        final bookings = await _client
            .from('bookings')
            .select('price')
            .gte('created_at', date.toIso8601String())
            .lt('created_at', nextDate.toIso8601String())
            .eq('status', 'completed');

        double dayRevenue = 0;
        int dayOrders = 0;
        for (final row in bookings) {
          dayRevenue += (row['price'] as num?)?.toDouble() ?? 0;
          dayOrders++;
        }

        results.add({
          'date': date.toIso8601String().substring(0, 10),
          'revenue': dayRevenue,
          'orders': dayOrders,
        });
      }

      return results;
    } catch (e) {
      debugLog('❌ Error fetching revenue chart: $e');
      return [];
    }
  }

  // ========================================
  // Driver Approval
  // ========================================

  /// ดึงรายชื่อคนขับรอการอนุมัติ
  Future<List<Map<String, dynamic>>> getPendingDrivers() async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('role', 'driver')
          .eq('approval_status', 'pending')
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugLog('❌ Error fetching pending drivers: $e');
      return [];
    }
  }

  /// ดึงรายชื่อคนขับทั้งหมด
  Future<List<Map<String, dynamic>>> getAllDrivers() async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('role', 'driver')
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugLog('❌ Error fetching all drivers: $e');
      return [];
    }
  }

  /// อนุมัติคนขับ
  Future<bool> approveDriver(String driverId) async {
    try {
      final adminId = AuthService.userId;
      if (adminId == null) return false;

      await _client.from('profiles').update({
        'approval_status': 'approved',
        'approved_at': DateTime.now().toIso8601String(),
        'approved_by': adminId,
      }).eq('id', driverId);

      await _logAction(
        actionType: 'approve_driver',
        targetUserId: driverId,
        details: {'status': 'approved'},
      );

      debugLog('✅ Driver approved: $driverId');
      return true;
    } catch (e) {
      debugLog('❌ Error approving driver: $e');
      return false;
    }
  }

  /// ปฏิเสธคนขับ
  Future<bool> rejectDriver(String driverId, String reason) async {
    try {
      final adminId = AuthService.userId;
      if (adminId == null) return false;

      await _client.from('profiles').update({
        'approval_status': 'rejected',
        'rejection_reason': reason,
        'approved_by': adminId,
      }).eq('id', driverId);

      await _logAction(
        actionType: 'reject_driver',
        targetUserId: driverId,
        details: {'status': 'rejected', 'reason': reason},
      );

      debugLog('❌ Driver rejected: $driverId');
      return true;
    } catch (e) {
      debugLog('❌ Error rejecting driver: $e');
      return false;
    }
  }

  // ========================================
  // Merchant Approval
  // ========================================

  /// ดึงรายชื่อร้านค้ารอการอนุมัติ
  Future<List<Map<String, dynamic>>> getPendingMerchants() async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('role', 'merchant')
          .eq('approval_status', 'pending')
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugLog('❌ Error fetching pending merchants: $e');
      return [];
    }
  }

  /// ดึงรายชื่อร้านค้าทั้งหมด
  Future<List<Map<String, dynamic>>> getAllMerchants() async {
    try {
      final response = await _client
          .from('profiles')
          .select()
          .eq('role', 'merchant')
          .order('created_at', ascending: false);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugLog('❌ Error fetching all merchants: $e');
      return [];
    }
  }

  /// อนุมัติร้านค้า
  Future<bool> approveMerchant(String merchantId) async {
    try {
      final adminId = AuthService.userId;
      if (adminId == null) return false;

      await _client.from('profiles').update({
        'approval_status': 'approved',
        'approved_at': DateTime.now().toIso8601String(),
        'approved_by': adminId,
      }).eq('id', merchantId);

      await _logAction(
        actionType: 'approve_merchant',
        targetUserId: merchantId,
        details: {'status': 'approved'},
      );

      debugLog('✅ Merchant approved: $merchantId');
      return true;
    } catch (e) {
      debugLog('❌ Error approving merchant: $e');
      return false;
    }
  }

  /// ปฏิเสธร้านค้า
  Future<bool> rejectMerchant(String merchantId, String reason) async {
    try {
      final adminId = AuthService.userId;
      if (adminId == null) return false;

      await _client.from('profiles').update({
        'approval_status': 'rejected',
        'rejection_reason': reason,
        'approved_by': adminId,
      }).eq('id', merchantId);

      await _logAction(
        actionType: 'reject_merchant',
        targetUserId: merchantId,
        details: {'status': 'rejected', 'reason': reason},
      );

      debugLog('❌ Merchant rejected: $merchantId');
      return true;
    } catch (e) {
      debugLog('❌ Error rejecting merchant: $e');
      return false;
    }
  }

  /// อัปเดตตำแหน่งร้านค้า (สำหรับแอดมิน)
  Future<bool> updateMerchantLocation({
    required String merchantId,
    required double latitude,
    required double longitude,
    String? shopAddress,
  }) async {
    try {
      final adminId = AuthService.userId;
      if (adminId == null) return false;

      await _client.from('profiles').update({
        'latitude': latitude,
        'longitude': longitude,
        if (shopAddress != null && shopAddress.trim().isNotEmpty)
          'shop_address': shopAddress.trim(),
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', merchantId);

      await _logAction(
        actionType: 'update_merchant_location',
        targetUserId: merchantId,
        details: {
          'latitude': latitude,
          'longitude': longitude,
          if (shopAddress != null && shopAddress.trim().isNotEmpty)
            'shop_address': shopAddress.trim(),
        },
      );

      debugLog('✅ Merchant location updated: $merchantId ($latitude,$longitude)');
      return true;
    } catch (e) {
      debugLog('❌ Error updating merchant location: $e');
      return false;
    }
  }

  /// อัปเดตเวลาเปิด-ปิดร้านค้า (สำหรับแอดมิน)
  Future<bool> updateMerchantShopHours({
    required String merchantId,
    required String shopOpenTime,
    required String shopCloseTime,
    List<String>? shopOpenDays,
  }) async {
    try {
      final adminId = AuthService.userId;
      if (adminId == null) return false;

      await _client.from('profiles').update({
        'shop_open_time': shopOpenTime,
        'shop_close_time': shopCloseTime,
        if (shopOpenDays != null) 'shop_open_days': shopOpenDays,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', merchantId);

      await _logAction(
        actionType: 'update_merchant_shop_hours',
        targetUserId: merchantId,
        details: {
          'shop_open_time': shopOpenTime,
          'shop_close_time': shopCloseTime,
          if (shopOpenDays != null) 'shop_open_days': shopOpenDays,
        },
      );

      debugLog('✅ Merchant shop hours updated: $merchantId ($shopOpenTime-$shopCloseTime)');
      return true;
    } catch (e) {
      debugLog('❌ Error updating merchant shop hours: $e');
      return false;
    }
  }

  /// อัปเดตสถานะเปิด/ปิดร้าน (แยกจากการระงับบัญชี)
  Future<bool> updateMerchantShopStatus({
    required String merchantId,
    required bool isOpen,
    String? reason,
  }) async {
    try {
      final adminId = AuthService.userId;
      if (adminId == null) return false;

      await _client.from('profiles').update({
        'shop_status': isOpen,
        'updated_at': DateTime.now().toIso8601String(),
      }).eq('id', merchantId);

      await _logAction(
        actionType: isOpen ? 'open_merchant_shop' : 'close_merchant_shop',
        targetUserId: merchantId,
        details: {
          'shop_status': isOpen,
          if (reason != null && reason.trim().isNotEmpty)
            'reason': reason.trim(),
        },
      );

      debugLog(
          '✅ Merchant shop status updated: $merchantId (${isOpen ? 'open' : 'closed'})');
      return true;
    } catch (e) {
      debugLog('❌ Error updating merchant shop status: $e');
      return false;
    }
  }

  // ========================================
  // Withdrawal Management
  // ========================================

  /// ดึงคำขอถอนเงินทั้งหมด
  Future<List<Map<String, dynamic>>> getWithdrawalRequests({
    String? status,
  }) async {
    try {
      var query = _client
          .from('withdrawal_requests')
          .select('*, profiles!inner(full_name, role, phone_number)');

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugLog('❌ Error fetching withdrawal requests: $e');
      return [];
    }
  }

  /// อนุมัติคำขอถอนเงิน
  Future<bool> approveWithdrawal({
    required String requestId,
    String? transferSlipUrl,
    String? adminNote,
  }) async {
    try {
      final adminId = AuthService.userId;
      if (adminId == null) return false;

      await _client.from('withdrawal_requests').update({
        'status': 'completed',
        'processed_by': adminId,
        'processed_at': DateTime.now().toIso8601String(),
        'transfer_slip_url': transferSlipUrl,
        'admin_note': adminNote,
      }).eq('id', requestId);

      await _logAction(
        actionType: 'approve_withdrawal',
        targetEntityId: requestId,
        details: {'status': 'completed', 'note': adminNote},
      );

      debugLog('✅ Withdrawal approved: $requestId');
      return true;
    } catch (e) {
      debugLog('❌ Error approving withdrawal: $e');
      return false;
    }
  }

  /// ปฏิเสธคำขอถอนเงิน
  Future<bool> rejectWithdrawal({
    required String requestId,
    required String reason,
  }) async {
    try {
      final adminId = AuthService.userId;
      if (adminId == null) return false;

      // คืนเงินเข้ากระเป๋า
      final request = await _client
          .from('withdrawal_requests')
          .select('user_id, amount')
          .eq('id', requestId)
          .single();

      final userId = request['user_id'] as String;
      final amount = (request['amount'] as num).toDouble();

      // คืนเงินเข้า wallet
      final wallet = await _client
          .from('wallets')
          .select('id, balance')
          .eq('user_id', userId)
          .single();

      final newBalance = (wallet['balance'] as num).toDouble() + amount;
      await _client
          .from('wallets')
          .update({'balance': newBalance})
          .eq('id', wallet['id']);

      // อัปเดตสถานะ
      await _client.from('withdrawal_requests').update({
        'status': 'rejected',
        'processed_by': adminId,
        'processed_at': DateTime.now().toIso8601String(),
        'admin_note': reason,
      }).eq('id', requestId);

      await _logAction(
        actionType: 'reject_withdrawal',
        targetUserId: userId,
        targetEntityId: requestId,
        details: {'status': 'rejected', 'reason': reason, 'refunded': amount},
      );

      debugLog('❌ Withdrawal rejected: $requestId (refunded $amount)');
      return true;
    } catch (e) {
      debugLog('❌ Error rejecting withdrawal: $e');
      return false;
    }
  }

  // ========================================
  // Top-Up Request Management
  // ========================================

  /// ดึงคำขอเติมเงินทั้งหมด
  Future<List<Map<String, dynamic>>> getTopUpRequests({
    String? status,
  }) async {
    try {
      var query = _client
          .from('topup_requests')
          .select('*, profiles!inner(full_name, role, phone_number)');

      if (status != null) {
        query = query.eq('status', status);
      }

      final response = await query.order('created_at', ascending: false);
      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugLog('❌ Error fetching topup requests: $e');
      return [];
    }
  }

  /// อนุมัติคำขอเติมเงิน (เติมเงินเข้า wallet)
  Future<bool> approveTopUp(String requestId) async {
    try {
      final adminId = AuthService.userId;
      if (adminId == null) return false;

      // ดึงข้อมูลคำขอ
      final request = await _client
          .from('topup_requests')
          .select('user_id, amount')
          .eq('id', requestId)
          .single();

      final userId = request['user_id'] as String;
      final amount = (request['amount'] as num).toDouble();

      // เติมเงินเข้า wallet
      final walletRes = await _client
          .from('wallets')
          .select('id, balance')
          .eq('user_id', userId)
          .maybeSingle();

      if (walletRes != null) {
        final newBalance = (walletRes['balance'] as num).toDouble() + amount;
        await _client
            .from('wallets')
            .update({'balance': newBalance})
            .eq('id', walletRes['id']);

        // บันทึก transaction
        await _client.from('wallet_transactions').insert({
          'wallet_id': walletRes['id'],
          'amount': amount,
          'type': 'topup',
          'description': 'เติมเงิน ฿${amount.toStringAsFixed(0)} (อนุมัติโดย Admin)',
        });
      }

      // อัปเดตสถานะ
      await _client.from('topup_requests').update({
        'status': 'completed',
        'processed_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      await _logAction(
        actionType: 'approve_topup',
        targetUserId: userId,
        targetEntityId: requestId,
        details: {'status': 'completed', 'amount': amount},
      );

      debugLog('✅ TopUp approved: $requestId (฿$amount → $userId)');
      return true;
    } catch (e) {
      debugLog('❌ Error approving topup: $e');
      return false;
    }
  }

  /// ปฏิเสธคำขอเติมเงิน
  Future<bool> rejectTopUp(String requestId, String reason) async {
    try {
      final adminId = AuthService.userId;
      if (adminId == null) return false;

      final request = await _client
          .from('topup_requests')
          .select('user_id, amount')
          .eq('id', requestId)
          .single();

      await _client.from('topup_requests').update({
        'status': 'rejected',
        'processed_at': DateTime.now().toIso8601String(),
      }).eq('id', requestId);

      await _logAction(
        actionType: 'reject_topup',
        targetUserId: request['user_id'],
        targetEntityId: requestId,
        details: {'status': 'rejected', 'reason': reason},
      );

      debugLog('❌ TopUp rejected: $requestId');
      return true;
    } catch (e) {
      debugLog('❌ Error rejecting topup: $e');
      return false;
    }
  }

  // ========================================
  // Admin Actions Log
  // ========================================

  Future<void> _logAction({
    required String actionType,
    String? targetUserId,
    String? targetEntityId,
    Map<String, dynamic>? details,
  }) async {
    try {
      final adminId = AuthService.userId;
      if (adminId == null) return;

      await _client.from('admin_actions').insert({
        'admin_id': adminId,
        'action_type': actionType,
        'target_user_id': targetUserId,
        'target_entity_id': targetEntityId,
        'details': details ?? {},
      });
    } catch (e) {
      debugLog('⚠️ Error logging admin action: $e');
    }
  }

  /// ดึงประวัติ admin actions
  Future<List<Map<String, dynamic>>> getAdminActions({int limit = 50}) async {
    try {
      final response = await _client
          .from('admin_actions')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return (response as List).cast<Map<String, dynamic>>();
    } catch (e) {
      debugLog('❌ Error fetching admin actions: $e');
      return [];
    }
  }

  // ========================================
  // Utility
  // ========================================

  /// ตรวจสอบว่าผู้ใช้ปัจจุบันเป็น admin หรือไม่
  Future<bool> isCurrentUserAdmin() async {
    try {
      final userId = AuthService.userId;
      if (userId == null) return false;

      final profile = await _client
          .from('profiles')
          .select('role')
          .eq('id', userId)
          .maybeSingle();

      return profile?['role'] == 'admin';
    } catch (e) {
      debugLog('❌ Error checking admin role: $e');
      return false;
    }
  }

  /// ระงับผู้ใช้
  Future<bool> suspendUser(String userId, String reason) async {
    try {
      final adminId = AuthService.userId;
      if (adminId == null) return false;

      await _client.from('profiles').update({
        'approval_status': 'suspended',
        'rejection_reason': reason,
      }).eq('id', userId);

      await _logAction(
        actionType: 'suspend_user',
        targetUserId: userId,
        details: {'reason': reason},
      );

      return true;
    } catch (e) {
      debugLog('❌ Error suspending user: $e');
      return false;
    }
  }
}
