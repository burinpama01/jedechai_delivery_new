import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/debug_logger.dart';

/// บริการจัดการแพ็กเกจ GP (gp_plans)
///
/// - ร้านค้าเลือกแพ็กเกจตอนสมัคร (ผ่าน RPC merchant_select_gp_plan)
/// - แอดมินจัดการแพลนผ่าน admin-web
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

  /// ร้านค้าเลือกแพลน — ค่า GP/ค่าส่งถูก copy ลง profile ฝั่ง server
  /// ใช้ได้เฉพาะร้านที่ยังไม่ผ่านการอนุมัติ (หลังอนุมัติให้ติดต่อแอดมิน)
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
}
