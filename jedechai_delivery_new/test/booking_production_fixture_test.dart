// Regression harness: parse every production-shaped booking row (PII masked)
// for the test customer through Booking.fromJson — reproduces "orders don't
// show" if any row crashes the customer activity list fetch.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/models/booking.dart';

void main() {
  final raw =
      File('test/fixtures/customer_bookings_fixture.json').readAsStringSync();
  final rows = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();

  test('fixture contains masked production-shaped customer bookings', () {
    expect(rows, isNotEmpty);
  });

  test('every production booking parses via Booking.fromJson', () {
    final failures = <String>[];
    for (final row in rows) {
      try {
        final booking = Booking.fromJson(row);
        // Sanity: each parsed booking must keep its identity fields.
        if (booking.id.isEmpty || booking.status.isEmpty) {
          failures.add('empty id/status for row ${row['id']}');
        }
      } catch (e) {
        failures.add('row ${row['id']} (created ${row['created_at']}, '
            'service ${row['service_type']}, status ${row['status']}): $e');
      }
    }
    expect(
      failures,
      isEmpty,
      reason:
          'Booking.fromJson crashed on production rows — the customer order '
          'list would fail for these bookings:\n${failures.join('\n')}',
    );
  });
}
