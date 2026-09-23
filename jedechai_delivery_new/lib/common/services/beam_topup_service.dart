import 'dart:convert';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../utils/debug_logger.dart';

/// ผลการสร้าง QR เติมเงินผ่าน Beam
class BeamTopupCharge {
  final String requestId;
  final double amount;
  final Uint8List? qrImageBytes;
  final DateTime? expiresAt;
  final String environment;

  const BeamTopupCharge({
    required this.requestId,
    required this.amount,
    required this.qrImageBytes,
    required this.expiresAt,
    required this.environment,
  });

  bool get isPlayground => environment != 'production';

  factory BeamTopupCharge.fromJson(Map<String, dynamic> json) {
    final b64 = json['qr_image_base64']?.toString();
    Uint8List? bytes;
    if (b64 != null && b64.isNotEmpty) {
      try {
        bytes = base64Decode(b64);
      } catch (_) {
        bytes = null;
      }
    }
    return BeamTopupCharge(
      requestId: json['request_id'].toString(),
      amount: (json['amount'] as num).toDouble(),
      qrImageBytes: bytes,
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
      environment: json['environment']?.toString() ?? 'playground',
    );
  }
}

/// ข้อผิดพลาดจาก beam-topup พร้อมเหตุผลจาก server
class BeamTopupException implements Exception {
  final String reason;
  const BeamTopupException(this.reason);

  String get message {
    switch (reason) {
      case 'beam_disabled':
        return 'ช่องทาง Beam ถูกปิดอยู่ กรุณาลองใหม่';
      case 'beam_not_configured':
        return 'ระบบชำระเงินยังไม่พร้อม กรุณาติดต่อแอดมิน';
      case 'invalid_amount':
        return 'จำนวนเงินไม่ถูกต้อง';
      case 'rate_limited':
        return 'สร้าง QR บ่อยเกินไป กรุณารอสักครู่';
      case 'beam_charge_failed':
        return 'สร้าง QR ไม่สำเร็จ กรุณาลองใหม่';
      default:
        return 'เกิดข้อผิดพลาด กรุณาลองใหม่';
    }
  }

  @override
  String toString() => 'BeamTopupException($reason)';
}

/// เติมเงิน Wallet ผ่าน Beam Checkout (QR PromptPay) — เรียก Edge Function beam-topup
/// คีย์ Beam อยู่ฝั่ง server เท่านั้น
class BeamTopupService {
  static SupabaseClient get _client => Supabase.instance.client;

  /// 'admin_approve' (แนบสลิป) | 'beam'
  static Future<String> fetchTopupMode() async {
    try {
      final row = await _client
          .from('system_config')
          .select('topup_mode')
          .eq('id', 1)
          .maybeSingle();
      final mode = row?['topup_mode']?.toString();
      return mode == 'beam' ? 'beam' : 'admin_approve';
    } catch (e) {
      debugLog('⚠️ load topup_mode failed: $e');
      return 'admin_approve';
    }
  }

  static String _reasonFrom(Object e) {
    if (e is FunctionException) {
      final details = e.details;
      if (details is Map && details['reason'] != null) {
        return details['reason'].toString();
      }
    }
    return 'unknown';
  }

  static Future<BeamTopupCharge> createCharge(double amount) async {
    try {
      final res = await _client.functions.invoke(
        'beam-topup',
        body: {'action': 'create', 'amount': amount},
      );
      final data = Map<String, dynamic>.from(res.data as Map);
      if (data['ok'] != true) {
        throw BeamTopupException(data['reason']?.toString() ?? 'unknown');
      }
      return BeamTopupCharge.fromJson(data);
    } on BeamTopupException {
      rethrow;
    } catch (e) {
      debugLog('❌ beam-topup create error: $e');
      throw BeamTopupException(_reasonFrom(e));
    }
  }

  /// คืนสถานะ: awaiting_payment | completed | failed | expired | manual_review
  static Future<String> checkStatus(String requestId) async {
    final res = await _client.functions.invoke(
      'beam-topup',
      body: {'action': 'status', 'request_id': requestId},
    );
    final data = Map<String, dynamic>.from(res.data as Map);
    return data['status']?.toString() ?? 'awaiting_payment';
  }
}
