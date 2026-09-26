import 'dart:async';

/// Bounds an optional platform startup step so it cannot hold the first frame.
Future<bool> runOptionalStartupTask(
  Future<void> Function() task, {
  required Duration timeout,
  required void Function(Object error) onFailure,
}) async {
  try {
    await task().timeout(timeout);
    return true;
  } catch (error) {
    onFailure(error);
    return false;
  }
}
