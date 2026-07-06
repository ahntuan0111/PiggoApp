import 'package:flutter/foundation.dart';

class AppLogger {
  static void success(String tag, dynamic result) {
    if (kDebugMode) {
      debugPrint("\n--- 🟢 SUCCESS: [$tag] ---");
      debugPrint("Response: ${result.toString()}");
      debugPrint("------------------------------------------\n");
    }
  }

  static void error(String tag, String message, [StackTrace? stack]) {
    if (kDebugMode) {
      debugPrint("\n--- 🔴 ERROR: [$tag] ---");
      debugPrint("Message: $message");
      if (stack != null) {
        debugPrint("Stack Trace:");
        debugPrintStack(stackTrace: stack);
      }
      debugPrint("------------------------------------------\n");
    }
  }

  static void info(String tag, String message) {
    if (kDebugMode) {
      debugPrint("🔵 INFO: [$tag] $message");
    }
  }
}
