import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/services/merchant_order_service.dart';

void main() {
  group('MerchantOrderService.nextAcceptedStatus', () {
    test('moves new merchant orders to preparing', () {
      expect(
        MerchantOrderService.nextAcceptedStatus('pending_merchant'),
        'preparing',
      );
      expect(MerchantOrderService.nextAcceptedStatus('pending'), 'preparing');
    });

    test('keeps parallel flow when driver accepted first', () {
      expect(
        MerchantOrderService.nextAcceptedStatus('driver_accepted'),
        'matched',
      );
    });

    test('marks ready when driver is already at merchant', () {
      expect(
        MerchantOrderService.nextAcceptedStatus('arrived_at_merchant'),
        'ready_for_pickup',
      );
    });

    test('rejects unsupported statuses', () {
      expect(MerchantOrderService.nextAcceptedStatus('completed'), isNull);
      expect(MerchantOrderService.nextAcceptedStatus('cancelled'), isNull);
      expect(MerchantOrderService.nextAcceptedStatus('preparing'), isNull);
    });
  });
}
