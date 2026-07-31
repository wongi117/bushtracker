import 'heading_reading.dart';

/// A live compass. One implementation per platform:
///
/// * `heading_source_native.dart` — tilt-compensated magnetometer +
///   accelerometer via sensors_plus (Android / iOS builds).
/// * `heading_source_web.dart` — browser DeviceOrientation events, which is
///   the only compass available to the PWA at pinagemaps.com.
///
/// Pick one with `makeHeadingSource()` — see `heading_provider.dart`.
abstract class HeadingSource {
  /// Broadcast stream of readings. Emits a [HeadingQuality.waiting] reading
  /// immediately on [start] so the UI can show "acquiring" instead of a lie.
  Stream<HeadingReading> get readings;

  /// Begin listening to the underlying sensors. Safe to call more than once.
  void start();

  /// iOS Safari 13+ refuses to deliver orientation events until the page asks,
  /// and it only honours the ask inside a user gesture — so this has to be
  /// driven by a tap. Returns true when readings are allowed to flow.
  /// Everywhere else this is a no-op that returns true.
  Future<bool> requestPermission();

  void dispose();
}
