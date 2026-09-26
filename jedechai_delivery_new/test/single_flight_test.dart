import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/utils/single_flight.dart';

void main() {
  test('concurrent initialization shares one operation', () async {
    final gate = SingleFlight();
    final blocked = Completer<void>();
    var calls = 0;
    Future<void> operation() {
      calls++;
      return blocked.future;
    }

    final first = gate.run(operation);
    final second = gate.run(operation);
    expect(calls, 1);
    blocked.complete();
    await Future.wait([first, second]);
    await gate.run(operation);
    expect(calls, 2);
  });
}
