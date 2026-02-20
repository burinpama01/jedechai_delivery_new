import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../utils/debug_logger.dart';
import '../config/env_config.dart';

/// Payment Gateway Service
///
/// Scaffold for integrating with payment gateways (Omise, Stripe, GB Prime Pay)
/// Currently supports:
/// - Creating charges (credit card, PromptPay, mobile banking)
/// - Checking charge status
/// - Webhook handling for auto-confirmation
///
/// IMPORTANT: Set the following in .env:
///   PAYMENT_GATEWAY_PUBLIC_KEY=pkey_xxx
///   PAYMENT_GATEWAY_SECRET_KEY=skey_xxx
///   PAYMENT_GATEWAY_PROVIDER=omise  (or 'stripe' or 'gbprimepay')
///
/// For production, webhook endpoint should be configured at:
///   POST /functions/v1/payment-webhook (Supabase Edge Function)
class PaymentGatewayService {
  static String get _provider =>
      const String.fromEnvironment('PAYMENT_GATEWAY_PROVIDER', defaultValue: 'omise');

  static String get _publicKey {
    if (_provider == 'omise') return EnvConfig.omisePublicKey;
    return '';
  }

  static String get _createChargeFunction =>
      const String.fromEnvironment(
        'PAYMENT_CREATE_CHARGE_FUNCTION',
        defaultValue: 'payment-create-charge',
      );

  static String get _checkStatusFunction =>
      const String.fromEnvironment(
        'PAYMENT_CHECK_STATUS_FUNCTION',
        defaultValue: 'payment-check-status',
      );

  // ── Omise API Base URL ──
  // ignore: unused_field
  static const String _omiseApiBase = 'https://api.omise.co';
  static const String _omiseVaultBase = 'https://vault.omise.co';

  // ── Stripe API Base URL ──
  // ignore: unused_field
  static const String _stripeApiBase = 'https://api.stripe.com/v1';

  /// Create a token from card details (client-side, uses public key)
  /// This should ideally be done via the official SDK, but this shows the flow.
  static Future<String?> createCardToken({
    required String cardNumber,
    required String expMonth,
    required String expYear,
    required String cvc,
    required String name,
  }) async {
    try {
      if (_provider == 'omise') {
        return await _omiseCreateToken(
          cardNumber: cardNumber,
          expMonth: expMonth,
          expYear: expYear,
          cvc: cvc,
          name: name,
        );
      } else if (_provider == 'stripe') {
        return await _stripeCreateToken(
          cardNumber: cardNumber,
          expMonth: expMonth,
          expYear: expYear,
          cvc: cvc,
        );
      }
      return null;
    } catch (e) {
      debugLog('❌ Error creating card token: $e');
      return null;
    }
  }

  /// Create a charge (server-side, uses secret key)
  /// In production, this should be called from a Supabase Edge Function
  /// to keep the secret key secure.
  static Future<PaymentResult> createCharge({
    required double amount,
    required String currency,
    required String method, // 'card', 'promptpay', 'mobile_banking'
    String? token, // Card token (for card payments)
    String? returnUrl, // For redirect-based payments
    String? bookingId, // For reference
  }) async {
    try {
      if (_provider == 'omise') {
        return await _omiseCreateCharge(
          amount: amount,
          currency: currency,
          method: method,
          token: token,
          returnUrl: returnUrl,
          bookingId: bookingId,
        );
      } else if (_provider == 'stripe') {
        return await _stripeCreatePaymentIntent(
          amount: amount,
          currency: currency,
          method: method,
          bookingId: bookingId,
        );
      }

      return PaymentResult(
        success: false,
        errorMessage: 'ไม่รองรับ payment provider: $_provider',
      );
    } catch (e) {
      debugLog('❌ Error creating charge: $e');
      return PaymentResult(
        success: false,
        errorMessage: 'เกิดข้อผิดพลาดในการชำระเงิน: $e',
      );
    }
  }

  /// Check charge status
  static Future<PaymentStatus> checkChargeStatus(String chargeId) async {
    try {
      if (_provider == 'omise') {
        return await _omiseCheckCharge(chargeId);
      }
      return PaymentStatus.unknown;
    } catch (e) {
      debugLog('❌ Error checking charge: $e');
      return PaymentStatus.unknown;
    }
  }

  // ══════════════════════════════════════════
  // ── Omise Implementation ──
  // ══════════════════════════════════════════

  static Future<String?> _omiseCreateToken({
    required String cardNumber,
    required String expMonth,
    required String expYear,
    required String cvc,
    required String name,
  }) async {
    final response = await http.post(
      Uri.parse('$_omiseVaultBase/tokens'),
      headers: {
        'Authorization': 'Basic ${base64Encode(utf8.encode('$_publicKey:'))}',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'card[number]': cardNumber,
        'card[expiration_month]': expMonth,
        'card[expiration_year]': expYear,
        'card[security_code]': cvc,
        'card[name]': name,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['id'] as String?;
    }

    debugLog('❌ Omise token error: ${response.body}');
    return null;
  }

  static Future<PaymentResult> _omiseCreateCharge({
    required double amount,
    required String currency,
    required String method,
    String? token,
    String? returnUrl,
    String? bookingId,
  }) async {
    // NOTE: In production, this MUST be called from server-side (Edge Function)
    // to protect the secret key. This scaffold shows the API structure.

    final body = <String, String>{
      'amount': (amount * 100).toInt().toString(), // Omise uses satang (cents)
      'currency': currency,
      'metadata[booking_id]': bookingId ?? '',
    };

    if (method == 'card' && token != null) {
      body['card'] = token;
    } else if (method == 'promptpay') {
      body['source[type]'] = 'promptpay';
    } else if (method == 'mobile_banking') {
      body['source[type]'] = 'mobile_banking_bbl'; // Default to BBL
      if (returnUrl != null) body['return_uri'] = returnUrl;
    }

    debugLog('📤 Omise charge request via Edge Function: method=$method, amount=$amount $currency');

    final edgeResult = await _invokeCreateCharge(
      provider: 'omise',
      amount: amount,
      currency: currency,
      method: method,
      token: token,
      returnUrl: returnUrl,
      bookingId: bookingId,
      payload: body,
    );

    return edgeResult;
  }

  static Future<PaymentStatus> _omiseCheckCharge(String chargeId) async {
    debugLog('🔍 Checking Omise charge via Edge Function: $chargeId');
    return _invokeCheckStatus(provider: 'omise', chargeId: chargeId);
  }

  // ══════════════════════════════════════════
  // ── Stripe Implementation ──
  // ══════════════════════════════════════════

  static Future<String?> _stripeCreateToken({
    required String cardNumber,
    required String expMonth,
    required String expYear,
    required String cvc,
  }) async {
    final response = await http.post(
      Uri.parse('$_stripeApiBase/tokens'),
      headers: {
        'Authorization': 'Bearer $_publicKey',
        'Content-Type': 'application/x-www-form-urlencoded',
      },
      body: {
        'card[number]': cardNumber,
        'card[exp_month]': expMonth,
        'card[exp_year]': expYear,
        'card[cvc]': cvc,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['id'] as String?;
    }

    debugLog('❌ Stripe token error: ${response.body}');
    return null;
  }

  static Future<PaymentResult> _stripeCreatePaymentIntent({
    required double amount,
    required String currency,
    required String method,
    String? bookingId,
  }) async {
    debugLog('📤 Stripe payment intent via Edge Function: method=$method, amount=$amount $currency');

    return _invokeCreateCharge(
      provider: 'stripe',
      amount: amount,
      currency: currency,
      method: method,
      bookingId: bookingId,
    );
  }

  static Future<PaymentResult> _invokeCreateCharge({
    required String provider,
    required double amount,
    required String currency,
    required String method,
    String? token,
    String? returnUrl,
    String? bookingId,
    Map<String, String>? payload,
  }) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        _createChargeFunction,
        body: {
          'provider': provider,
          'amount': amount,
          'currency': currency,
          'method': method,
          if (token != null) 'token': token,
          if (returnUrl != null) 'return_url': returnUrl,
          if (bookingId != null) 'booking_id': bookingId,
          if (payload != null) 'gateway_payload': payload,
        },
      );

      final data = _normalizeResponse(response.data);
      final success = data['success'] == true;

      return PaymentResult(
        success: success,
        chargeId: data['charge_id'] as String?,
        status: _parseStatus(data['status']),
        authorizeUrl: data['authorize_url'] as String?,
        errorMessage: data['error'] as String?,
        message: data['message'] as String?,
      );
    } catch (e) {
      debugLog('❌ Edge Function create charge error: $e');
      return PaymentResult(
        success: false,
        status: PaymentStatus.failed,
        errorMessage:
            'ไม่สามารถเชื่อมต่อระบบชำระเงินได้ กรุณาตรวจสอบ Edge Function ($_createChargeFunction)',
      );
    }
  }

  static Future<PaymentStatus> _invokeCheckStatus({
    required String provider,
    required String chargeId,
  }) async {
    try {
      final response = await Supabase.instance.client.functions.invoke(
        _checkStatusFunction,
        body: {
          'provider': provider,
          'charge_id': chargeId,
        },
      );

      final data = _normalizeResponse(response.data);
      return _parseStatus(data['status']);
    } catch (e) {
      debugLog('❌ Edge Function check status error: $e');
      return PaymentStatus.unknown;
    }
  }

  static Map<String, dynamic> _normalizeResponse(dynamic raw) {
    if (raw is Map<String, dynamic>) return raw;
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
      } catch (_) {}
    }
    return <String, dynamic>{};
  }

  static PaymentStatus _parseStatus(dynamic status) {
    switch ((status ?? '').toString().toLowerCase()) {
      case 'successful':
      case 'success':
      case 'paid':
        return PaymentStatus.successful;
      case 'failed':
      case 'failure':
        return PaymentStatus.failed;
      case 'expired':
        return PaymentStatus.expired;
      case 'reversed':
      case 'refunded':
        return PaymentStatus.reversed;
      case 'pending':
      case 'processing':
        return PaymentStatus.pending;
      default:
        return PaymentStatus.unknown;
    }
  }
}

/// Payment charge result
class PaymentResult {
  final bool success;
  final String? chargeId;
  final PaymentStatus status;
  final String? authorizeUrl; // For redirect-based payments (3DS, mobile banking)
  final String? errorMessage;
  final String? message;

  const PaymentResult({
    required this.success,
    this.chargeId,
    this.status = PaymentStatus.pending,
    this.authorizeUrl,
    this.errorMessage,
    this.message,
  });
}

/// Payment status enum
enum PaymentStatus {
  pending,
  successful,
  failed,
  expired,
  reversed,
  unknown;

  String get text {
    switch (this) {
      case PaymentStatus.pending:
        return 'รอดำเนินการ';
      case PaymentStatus.successful:
        return 'สำเร็จ';
      case PaymentStatus.failed:
        return 'ล้มเหลว';
      case PaymentStatus.expired:
        return 'หมดอายุ';
      case PaymentStatus.reversed:
        return 'คืนเงินแล้ว';
      case PaymentStatus.unknown:
        return 'ไม่ทราบสถานะ';
    }
  }
}
