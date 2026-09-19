import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/debug_logger.dart';

/// สถานะแพ็กเกจ GP ของร้าน (จาก RPC merchant_gp_plan_status)
class GpPlanStatus {
  final String? planId;
  final String? approvalStatus;
  final bool isCustomDeal;
  final bool canChange;

  /// null | 'custom_deal' | 'cooldown' | 'active_orders'
  final String? blockedReason;
  final DateTime? nextChangeAt;
  final bool hasActiveOrders;
  final int cooldownDays;

  /// server_now - เวลาเครื่อง ใช้ชดเชยนาฬิกาเครื่องที่ไม่ตรงตอนนับถอยหลัง
  final Duration clockOffset;
  final double? gpRate;
  final double? baseFare;
  final double? baseDistanceKm;
  final double? perKm;

  const GpPlanStatus({
    required this.planId,
    required this.approvalStatus,
    required this.isCustomDeal,
    required this.canChange,
    required this.blockedReason,
    required this.nextChangeAt,
    required this.hasActiveOrders,
    required this.cooldownDays,
    required this.clockOffset,
    required this.gpRate,
    required this.baseFare,
    required this.baseDistanceKm,
    required this.perKm,
  });

  bool get isApproved => approvalStatus == 'approved';

  static double? _num(dynamic v) => v == null ? null : (v as num).toDouble();

  factory GpPlanStatus.fromJson(Map<String, dynamic> json, {DateTime? now}) {
    final serverNow = DateTime.tryParse(json['server_now']?.toString() ?? '');
    final localNow = now ?? DateTime.now();
    return GpPlanStatus(
      planId: json['plan_id']?.toString(),
      approvalStatus: json['approval_status']?.toString(),
      isCustomDeal: json['is_custom_deal'] == true,
      canChange: json['can_change'] == true,
      blockedReason: json['blocked_reason']?.toString(),
      nextChangeAt: DateTime.tryParse(json['next_change_at']?.toString() ?? ''),
      hasActiveOrders: json['has_active_orders'] == true,
      cooldownDays: (json['cooldown_days'] as num?)?.toInt() ?? 30,
      clockOffset:
          serverNow == null ? Duration.zero : serverNow.difference(localNow),
      gpRate: _num(json['gp_rate']),
      baseFare: _num(json['custom_base_fare']),
      baseDistanceKm: _num(json['custom_base_distance']),
      perKm: _num(json['custom_per_km']),
    );
  }

  /// เวลาที่เหลือก่อนเปลี่ยนได้ (อิงเวลา server) — null ถ้าไม่ติด cooldown
  Duration? remainingCooldown({DateTime? now}) {
    final next = nextChangeAt;
    if (next == null) return null;
    final serverNow = (now ?? DateTime.now()).add(clockOffset);
    final left = next.difference(serverNow);
    return left.isNegative ? Duration.zero : left;
  }
}

/// บริการจัดการแพ็กเกจ GP (gp_plans)
///
/// - ร้านค้าเลือกแพ็กเกจตอนสมัคร และเปลี่ยนเองได้เดือนละ 1 ครั้งหลังอนุมัติ
///   (ผ่าน RPC merchant_select_gp_plan — server ตรวจ cooldown/ดีลตรง/ออเดอร์ค้าง)
/// - แอดมินจัดการแพลนผ่าน admin-web (การเปลี่ยนโดยแอดมินไม่นับ cooldown)
class GpPlanService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// ดึงแพลนที่เปิดใช้งาน เรียงตาม sort_order
  static Future<List<Map<String, dynamic>>> fetchActivePlans() async {
    final rows = await _client
        .from('gp_plans')
        .select()
        .eq('is_active', true)
        .order('sort_order', ascending: true);
    return (rows as List).cast<Map<String, dynamic>>();
  }

  /// สถานะแพ็กเกจปัจจุบันของร้าน + cooldown
  static Future<GpPlanStatus> fetchStatus() async {
    final res = await _client.rpc('merchant_gp_plan_status');
    return GpPlanStatus.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// ร้านค้าเลือก/เปลี่ยนแพลน — ค่า GP/ค่าส่งถูก copy ลง profile ฝั่ง server
  static Future<void> selectPlan(String planId) async {
    try {
      await _client.rpc(
        'merchant_select_gp_plan',
        params: {'p_plan_id': planId},
      );
      debugLog('✅ GP plan selected: $planId');
    } catch (e) {
      debugLog('❌ Error selecting GP plan: $e');
      rethrow;
    }
  }

  /// แปลง error จาก RPC เป็นข้อความภาษาไทยสำหรับร้าน
  static String errorMessage(Object error) {
    final raw = error is PostgrestException ? error.message : error.toString();
    if (raw.contains('gp_plan_cooldown')) {
      return 'เปลี่ยนแพ็กเกจได้เดือนละ 1 ครั้ง กรุณารอให้ครบกำหนด';
    }
    if (raw.contains('custom_deal_contact_admin')) {
      return 'ร้านของคุณใช้เงื่อนไขพิเศษ กรุณาติดต่อแอดมินเพื่อเปลี่ยนแพ็กเกจ';
    }
    if (raw.contains('active_orders_exist')) {
      return 'มีออเดอร์ที่กำลังดำเนินการ กรุณารอให้เสร็จก่อนเปลี่ยนแพ็กเกจ';
    }
    if (raw.contains('same_plan')) return 'คุณใช้แพ็กเกจนี้อยู่แล้ว';
    if (raw.contains('plan_not_found')) return 'ไม่พบแพ็กเกจนี้ หรือแพ็กเกจถูกปิดใช้งาน';
    if (raw.contains('already_approved_contact_admin')) {
      return 'กรุณาติดต่อแอดมินเพื่อเปลี่ยนแพ็กเกจ';
    }
    return 'เปลี่ยนแพ็กเกจไม่สำเร็จ กรุณาลองใหม่';
  }
}
