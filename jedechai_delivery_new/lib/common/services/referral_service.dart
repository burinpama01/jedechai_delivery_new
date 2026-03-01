import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/debug_logger.dart';
import 'auth_service.dart';

class ReferralService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<String> getOrCreateMyReferralCode() async {
    final userId = AuthService.userId;
    if (userId == null) throw Exception('กรุณาเข้าสู่ระบบ');

    try {
      final existing = await _client
          .from('referral_codes')
          .select('code')
          .eq('user_id', userId)
          .maybeSingle();

      final existingCode = existing?['code']?.toString();
      if (existingCode != null && existingCode.isNotEmpty) {
        return existingCode;
      }

      // Create a new code. We retry on unique conflict.
      for (var attempt = 0; attempt < 5; attempt++) {
        final code = _generateReferralCode();
        try {
          await _client.from('referral_codes').insert({
            'user_id': userId,
            'code': code,
          });
          return code;
        } catch (e) {
          // If it's a unique violation on code, retry with a new random code.
          debugLog('⚠️ Referral code insert failed (attempt $attempt): $e');
        }
      }

      throw Exception('ไม่สามารถสร้างโค้ดชวนเพื่อนได้ กรุณาลองใหม่');
    } catch (e) {
      debugLog('❌ Error getOrCreateMyReferralCode: $e');
      rethrow;
    }
  }

  Future<void> submitReferralCode(String referralCode) async {
    final userId = AuthService.userId;
    if (userId == null) throw Exception('กรุณาเข้าสู่ระบบ');

    final code = referralCode.trim().toUpperCase();
    if (code.isEmpty) return;

    try {
      final res = await _client.rpc('process_referral', params: {
        'p_referee_id': userId,
        'p_referral_code': code,
      });

      if (res is Map) {
        final success = res['success'] == true;
        if (!success) {
          final err = res['error']?.toString();
          throw Exception(err?.isNotEmpty == true ? err : 'ไม่สามารถใช้โค้ดได้');
        }
        return;
      }

      throw Exception('ไม่สามารถใช้โค้ดได้');
    } catch (e) {
      debugLog('❌ Error submitReferralCode: $e');
      rethrow;
    }
  }

  Future<int> getMyTotalReferrals() async {
    final userId = AuthService.userId;
    if (userId == null) return 0;

    try {
      final res = await _client
          .from('referrals')
          .select('id')
          .eq('referrer_id', userId)
          .eq('status', 'qualified');

      return (res as List).length;
    } catch (e) {
      debugLog('❌ Error getMyTotalReferrals: $e');
      return 0;
    }
  }

  String _generateReferralCode() {
    const alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final rng = Random.secure();

    final suffix = List.generate(
      8,
      (_) => alphabet[rng.nextInt(alphabet.length)],
    ).join();

    return 'REF-$suffix';
  }
}
