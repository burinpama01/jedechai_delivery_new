List<String> laundryOrderCustomerIds(List<Map<String, dynamic>> orders) {
  final ids = <String>{};
  for (final order in orders) {
    final id = order['customer_id']?.toString().trim();
    if (id != null && id.isNotEmpty) {
      ids.add(id);
    }
  }
  return ids.toList(growable: false);
}

List<Map<String, dynamic>> attachLaundryOrderCustomers({
  required List<Map<String, dynamic>> orders,
  required List<Map<String, dynamic>> customers,
}) {
  final customersById = <String, Map<String, dynamic>>{};
  for (final customer in customers) {
    final id = customer['id']?.toString();
    if (id != null && id.isNotEmpty) {
      customersById[id] = Map<String, dynamic>.from(customer);
    }
  }

  return [
    for (final order in orders)
      () {
        final copy = Map<String, dynamic>.from(order);
        final customerId = copy['customer_id']?.toString();
        final customer = customersById[customerId];
        if (customer != null) {
          copy['customer'] = customer;
        }
        return copy;
      }(),
  ];
}
