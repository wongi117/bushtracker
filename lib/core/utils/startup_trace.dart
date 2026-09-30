import 'package:flutter/foundation.dart';

/// Timestamps for each step of getting the app usable.
///
/// Startup felt like "about twenty seconds" with no idea which part was slow,
/// so the fix was guesswork. Each milestone prints milliseconds since launch,
/// which turns that into a measurement:
///
///   adb logcat | Select-String "STARTUP"
class StartupTrace {
  StartupTrace._();

  static final Stopwatch _since = Stopwatch()..start();
  static final Map<String, int> milestones = {};

  /// Record a milestone the first time it happens. Later calls are ignored,
  /// so "first tile" stays the first tile.
  static void mark(String name) {
    if (milestones.containsKey(name)) return;
    final ms = _since.elapsedMilliseconds;
    milestones[name] = ms;
    debugPrint('⏱️ STARTUP $name: ${ms}ms');
  }

  /// Everything so far, slowest gaps first — printed once the app is usable.
  static void report() {
    final entries = milestones.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final buffer = StringBuffer('⏱️ STARTUP summary:');
    var previous = 0;
    for (final e in entries) {
      buffer.write('\n   ${e.key}: ${e.value}ms (+${e.value - previous}ms)');
      previous = e.value;
    }
    debugPrint(buffer.toString());
  }

  static int get elapsedMs => _since.elapsedMilliseconds;
}
