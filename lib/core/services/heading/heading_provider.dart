import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'heading_reading.dart';
import 'heading_source.dart';

// Order matters: the first satisfied condition wins, so keep dart.library.io
// ahead of js_interop to be certain the Android/iOS build never picks web.
import 'heading_source_stub.dart'
    if (dart.library.io) 'heading_source_native.dart'
    if (dart.library.js_interop) 'heading_source_web.dart';

export 'heading_reading.dart';

/// The single live compass for the whole app. Every screen that shows a
/// bearing reads this, so the map, the dashboard and the AR overlays can no
/// longer disagree with each other about which way is north.
final headingSourceProvider = Provider<HeadingSource>((ref) {
  final source = makeHeadingSource()..start();
  ref.onDispose(source.dispose);
  return source;
});

/// Live heading. Watch this, don't subscribe to sensors directly.
final headingProvider = StreamProvider<HeadingReading>((ref) {
  return ref.watch(headingSourceProvider).readings;
});

/// Convenience for widgets that only want the number: degrees clockwise from
/// north, holding at 0 until the first real fix lands.
final headingDegreesProvider = Provider<double>((ref) {
  final reading = ref.watch(headingProvider).valueOrNull;
  return reading != null && reading.isLive ? reading.degrees : 0.0;
});

/// Same, in radians — what `Transform.rotate` and `CompassRose` take.
final headingRadiansProvider = Provider<double>((ref) {
  final reading = ref.watch(headingProvider).valueOrNull;
  return reading != null && reading.isLive ? reading.radians : 0.0;
});

/// Ask the browser for orientation permission. Must be triggered by a tap on
/// iOS Safari; harmless everywhere else.
Future<bool> requestHeadingPermission(WidgetRef ref) =>
    ref.read(headingSourceProvider).requestPermission();
