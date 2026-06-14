import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/utils/laundry_order_customer_mapper.dart';

void main() {
  group('laundry order customer mapper', () {
    test('extracts unique customer ids from orders', () {
      final ids = laundryOrderCustomerIds([
        {'id': 'order-1', 'customer_id': 'customer-1'},
        {'id': 'order-2', 'customer_id': 'customer-1'},
        {'id': 'order-3', 'customer_id': 'customer-2'},
        {'id': 'order-4', 'customer_id': ''},
      ]);

      expect(ids, ['customer-1', 'customer-2']);
    });

    test('attaches matching profile rows as customer objects', () {
      final orders = attachLaundryOrderCustomers(
        orders: [
          {'id': 'order-1', 'customer_id': 'customer-1'},
          {'id': 'order-2', 'customer_id': 'customer-missing'},
        ],
        customers: [
          {
            'id': 'customer-1',
            'full_name': 'ลูกค้าทดสอบ',
            'phone_number': '0999999999',
          },
        ],
      );

      expect(orders[0]['customer'], {
        'id': 'customer-1',
        'full_name': 'ลูกค้าทดสอบ',
        'phone_number': '0999999999',
      });
      expect(orders[1].containsKey('customer'), isFalse);
    });
  });
}
