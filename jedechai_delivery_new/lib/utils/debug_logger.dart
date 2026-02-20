import 'package:flutter/foundation.dart';

/// Debug Logger Utility
/// 
/// Wraps print() calls so they only execute in debug mode.
/// In release builds, all log output is suppressed for performance and security.
void debugLog(String message) {
  if (kDebugMode) {
    print(message);
  }
}
