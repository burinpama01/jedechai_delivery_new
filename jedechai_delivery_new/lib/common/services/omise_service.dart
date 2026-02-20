import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/env_config.dart';
import '../../utils/debug_logger.dart';

/// OmiseService — เชื่อมต่อ Omise Payment Gateway
///
/// รองรับ:
/// - สร้าง PromptPay Source (QR Code)
/// - สร้าง Charge จาก Source
/// - ตรวจสอบสถานะ Charge
///
/// ใช้ Basic Auth:
///   Public Key  → สร้าง Source (client-side safe)
///   Secret Key  → สร้าง Charge + ตรวจสถานะ (ควรอยู่ server-side ใน production)
class OmiseService {
  static const String _apiBase = 'https://api.omise.co';

  // ── Auth Headers ──

  /// สร้าง Basic Auth header จาก key
  static Map<String, String> _headers(String key) {
    final credentials = base64Encode(utf8.encode('$key:'));
    return {
      'Authorization': 'Basic $credentials',
      'Content-Type': 'application/x-www-form-urlencoded',
    };
  }

  // ══════════════════════════════════════════
  // Method 1: สร้าง PromptPay Source
  // ══════════════════════════════════════════

  /// สร้าง PromptPay Source สำหรับชำระเงิน
  ///
  /// [amountSatang] — จำนวนเงินในหน่วยสตางค์ (THB * 100)
  /// Returns: Map ของ source object จาก Omise
  ///   - source['id'] → ใช้สร้าง charge
  static Future<Map<String, dynamic>?> createPromptPaySource(int amountSatang) async {
    try {
      final publicKey = EnvConfig.omisePublicKey;
      if (publicKey.isEmpty) {
        debugLog('❌ OMISE_PUBLIC_KEY ไม่ได้ตั้งค่าใน .env');
        return null;
      }

      debugLog('📤 Omise: สร้าง PromptPay Source — $amountSatang สตางค์');

      final response = await http.post(
        Uri.parse('$_apiBase/sources'),
        headers: _headers(publicKey),
        body: {
          'type': 'promptpay',
          'amount': amountSatang.toString(),
          'currency': 'thb',
        },
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        debugLog('✅ Omise Source สร้างสำเร็จ: ${data['id']}');
        return data;
      } else {
        debugLog('❌ Omise Source error: ${data['message'] ?? response.body}');
        return null;
      }
    } catch (e) {
      debugLog('❌ Omise createPromptPaySource error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════
  // Method 2: สร้าง Charge จาก Source
  // ══════════════════════════════════════════

  /// สร้าง Charge จาก Source ID
  ///
  /// [sourceId] — ID ของ source ที่ได้จาก createPromptPaySource
  /// [amountSatang] — จำนวนเงินในหน่วยสตางค์ (ต้องตรงกับ source)
  /// Returns: Map ของ charge object จาก Omise
  ///   - charge['id'] → ใช้ตรวจสถานะ
  ///   - charge['source']['scannable_code']['image']['download_uri'] → QR Image URL
  ///   - charge['status'] → 'pending', 'successful', 'failed'
  static Future<Map<String, dynamic>?> createCharge(
    String sourceId,
    int amountSatang,
  ) async {
    try {
      final secretKey = EnvConfig.omiseSecretKey;
      if (secretKey.isEmpty) {
        debugLog('❌ OMISE_SECRET_KEY ไม่ได้ตั้งค่าใน .env');
        return null;
      }

      debugLog('📤 Omise: สร้าง Charge — source=$sourceId, amount=$amountSatang');

      final response = await http.post(
        Uri.parse('$_apiBase/charges'),
        headers: _headers(secretKey),
        body: {
          'source': sourceId,
          'amount': amountSatang.toString(),
          'currency': 'thb',
          'return_uri': 'http://localhost',
        },
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        debugLog('✅ Omise Charge สร้างสำเร็จ: ${data['id']} — status: ${data['status']}');
        return data;
      } else {
        debugLog('❌ Omise Charge error: ${data['message'] ?? response.body}');
        return null;
      }
    } catch (e) {
      debugLog('❌ Omise createCharge error: $e');
      return null;
    }
  }

  // ══════════════════════════════════════════
  // Method 3: ตรวจสอบสถานะ Charge
  // ══════════════════════════════════════════

  /// ตรวจสอบสถานะของ Charge
  ///
  /// [chargeId] — ID ของ charge ที่ได้จาก createCharge
  /// Returns: สถานะของ charge ('pending', 'successful', 'failed', 'expired')
  static Future<String> checkChargeStatus(String chargeId) async {
    try {
      final secretKey = EnvConfig.omiseSecretKey;
      if (secretKey.isEmpty) {
        debugLog('❌ OMISE_SECRET_KEY ไม่ได้ตั้งค่าใน .env');
        return 'failed';
      }

      debugLog('🔍 Omise: ตรวจสอบสถานะ Charge — $chargeId');

      final response = await http.get(
        Uri.parse('$_apiBase/charges/$chargeId'),
        headers: _headers(secretKey),
      );

      final data = jsonDecode(response.body) as Map<String, dynamic>;

      if (response.statusCode == 200) {
        final status = data['status'] as String? ?? 'pending';
        debugLog('📋 Omise Charge status: $status');
        return status;
      } else {
        debugLog('❌ Omise checkCharge error: ${data['message'] ?? response.body}');
        return 'failed';
      }
    } catch (e) {
      debugLog('❌ Omise checkChargeStatus error: $e');
      return 'failed';
    }
  }

  // ══════════════════════════════════════════
  // Helper: ดึง QR Image URL จาก charge object
  // ══════════════════════════════════════════

  /// ดึง URL ของ QR Code image จาก charge response
  ///
  /// Path: charge['source']['scannable_code']['image']['download_uri']
  static String? extractQrUrl(Map<String, dynamic> charge) {
    try {
      final source = charge['source'] as Map<String, dynamic>?;
      if (source == null) return null;

      final scannableCode = source['scannable_code'] as Map<String, dynamic>?;
      if (scannableCode == null) return null;

      final image = scannableCode['image'] as Map<String, dynamic>?;
      if (image == null) return null;

      return image['download_uri'] as String?;
    } catch (e) {
      debugLog('⚠️ ไม่สามารถดึง QR URL ได้: $e');
      return null;
    }
  }
}
