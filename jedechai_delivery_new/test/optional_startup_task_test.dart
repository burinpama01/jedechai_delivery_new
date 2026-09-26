import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:jedechai_delivery_new/common/utils/optional_startup_task.dart';

void main() {
  test('optional startup step stops waiting when platform call never replies',
      () async {
    final blocked = Completer<void>();
    Object? reported;

    final completed = await runOptionalStartupTask(
      () => blocked.future,
      timeout: const Duration(milliseconds: 10),
      onFailure: (error) => reported = error,
    );

    expect(completed, isFalse);
    expect(reported, isA<TimeoutException>());
  });

  test('optional startup step reports success when it completes', () async {
    final completed = await runOptionalStartupTask(
      () async {},
      timeout: const Duration(seconds: 1),
      onFailure: (_) => fail('unexpected failure'),
    );

    expect(completed, isTrue);
  });
}
