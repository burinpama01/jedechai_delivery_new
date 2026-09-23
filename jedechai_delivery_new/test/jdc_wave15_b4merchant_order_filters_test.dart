import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/apps/merchant/screens/merchant_orders_screen.dart';

void main() {
  test('merchant order tabs group populated queue without changing source', () {
    final orders = <Map<String, dynamic>>[
      {'id': 'new', 'status': 'pending_merchant'},
      {'id': 'pending', 'status': 'pending'},
      {'id': 'preparing', 'status': 'preparing'},
      {'id': 'driver', 'status': 'driver_accepted'},
      {'id': 'arrived', 'status': 'arrived_at_merchant'},
      {'id': 'ready', 'status': 'ready_for_pickup'},
      {'id': 'picked', 'status': 'picking_up_order'},
    ];

    List<String> ids(int tab) => filterMerchantOrdersForTab(
          orders,
          tab,
        ).map((order) => order['id'] as String).toList();

    expect(ids(0), [
      'new',
      'pending',
      'preparing',
      'driver',
      'arrived',
      'ready',
      'picked'
    ]);
    expect(ids(1), ['new', 'pending']);
    expect(ids(2), ['preparing', 'driver', 'arrived']);
    expect(ids(3), ['ready']);
    expect(orders.length, 7);
  });

  test('a category can be empty while the active queue has orders', () {
    final orders = <Map<String, dynamic>>[
      {'id': 'new', 'status': 'pending_merchant'},
    ];
    expect(filterMerchantOrdersForTab(orders, 3), isEmpty);
    expect(filterMerchantOrdersForTab(orders, 0), hasLength(1));
  });
}
