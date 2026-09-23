import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/services/beam_topup_service.dart';

void main() {
  group('BeamTopupCharge.fromJson', () {
    test('decodes QR image, expiry and environment', () {
      final png = [0x89, 0x50, 0x4E, 0x47];
      final charge = BeamTopupCharge.fromJson({
        'request_id': 'a1b2',
        'amount': 100,
        'qr_image_base64': base64Encode(png),
        'expires_at': '2026-09-20T10:15:00Z',
        'environment': 'production',
      });
      expect(charge.requestId, 'a1b2');
      expect(charge.amount, 100.0);
      expect(charge.qrImageBytes, png);
      expect(charge.expiresAt, DateTime.utc(2026, 9, 20, 10, 15));
      expect(charge.isPlayground, isFalse);
    });

    test('tolerates missing or invalid QR data and defaults to playground', () {
      final charge = BeamTopupCharge.fromJson({
        'request_id': 'x',
        'amount': 20.5,
        'qr_image_base64': '%%%not-base64%%%',
      });
      expect(charge.qrImageBytes, isNull);
      expect(charge.expiresAt, isNull);
      expect(charge.isPlayground, isTrue);
    });
  });

  group('BeamTopupException.message', () {
    test('maps server reasons to Thai messages', () {
      expect(const BeamTopupException('rate_limited').message, contains('บ่อยเกินไป'));
      expect(const BeamTopupException('beam_not_configured').message, contains('แอดมิน'));
      expect(const BeamTopupException('whatever').message, contains('ลองใหม่'));
    });
  });
}
