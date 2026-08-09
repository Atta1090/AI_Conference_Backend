import 'package:flutter/foundation.dart';

/// Clear stage-by-stage logs in the Flutter terminal (`flutter run`).
class StageLog {
  StageLog._();

  static void step(String stage, String message, [Map<String, Object?>? extra]) {
    final buf = StringBuffer('[ConvoBridge][$stage] $message');
    if (extra != null && extra.isNotEmpty) {
      final detail = extra.entries.map((e) => '${e.key}=${e.value}').join(' | ');
      buf.write(' ($detail)');
    }
    debugPrint(buf.toString());
  }

  static void boot(String aiBaseUrl) {
    step('BOOT', 'App starting', {'aiServer': aiBaseUrl});
  }
}
