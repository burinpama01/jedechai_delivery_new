import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/services/wallet_service.dart';

DriverWallet wallet(double balance, double system) => DriverWallet.fromJson({
      'id': 'w1',
      'user_id': 'u1',
      'balance': balance,
      'balance_system': system,
      'updated_at': '2026-09-20T00:00:00Z',
    });

void main() {
  group('DriverWallet buckets (Batch 3)', () {
    test('splits balance into system and topup buckets', () {
      final w = wallet(500, 125);
      expect(w.availableSystem, 125);
      expect(w.availableTopup, 375);
    });

    test('system bucket cannot exceed usable balance', () {
      // คนขับติดลบจากค่าคอม แต่มีรางวัลค้างในถังระบบ
      final w = wallet(10, 20);
      expect(w.availableSystem, 10);
      expect(w.availableTopup, 0);
    });

    test('negative balance gives zero in both buckets', () {
      final w = wallet(-40, 20);
      expect(w.availableSystem, 0);
      expect(w.availableTopup, 0);
    });

    test('missing balance_system (old rows) counts as topup money', () {
      final w = DriverWallet.fromJson({
        'id': 'w1',
        'user_id': 'u1',
        'balance': 80,
        'updated_at': '2026-09-20T00:00:00Z',
      });
      expect(w.balanceSystem, 0);
      expect(w.availableTopup, 80);
      expect(w.availableSystem, 0);
    });
  });
}
