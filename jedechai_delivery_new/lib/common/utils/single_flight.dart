/// Shares one in-flight async operation among callers and permits later retry.
class SingleFlight {
  Future<void>? _running;

  Future<void> run(Future<void> Function() operation) {
    return _running ??= _runAndReset(operation);
  }

  Future<void> _runAndReset(Future<void> Function() operation) async {
    try {
      await operation();
    } finally {
      _running = null;
    }
  }
}
