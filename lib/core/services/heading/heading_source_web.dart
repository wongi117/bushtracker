import 'dart:async';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:web/web.dart' as web;

import 'heading_reading.dart';
import 'heading_source.dart';

HeadingSource makeHeadingSource() => BrowserHeadingSource();

/// Non-standard members we need off the orientation event.
extension type _OrientationEvent(JSObject _) implements JSObject {
  /// Compass rotation, counter-clockwise from north, 0–360.
  external double? get alpha;

  /// True when [alpha] is referenced to magnetic north rather than to
  /// wherever the device happened to be pointing when the page loaded.
  external bool? get absolute;

  /// iOS/Safari only, and already clockwise from north — no conversion needed.
  external double? get webkitCompassHeading;
}

/// Compass for the web build (pinagemaps.com).
///
/// sensors_plus has no magnetometer on web, so the previous code either bailed
/// out on `kIsWeb` or subscribed to a stream that never emitted — which is why
/// the rose sat frozen on north in the browser. The browser's own
/// `deviceorientationabsolute` event is the only compass available here.
///
/// Requires a secure origin (https), which pinagemaps.com already is.
class BrowserHeadingSource implements HeadingSource {
  static const double _headingSmoothing = 0.25;

  /// If the browser delivers nothing in this window, there is no compass —
  /// desktop, a blocked sensor, or iOS waiting on a permission tap.
  static const Duration _firstEventTimeout = Duration(seconds: 4);

  /// Browsers fire orientation events far faster than the UI needs. Cap the
  /// redraws at 20 Hz to keep the map smooth on a mid-range phone.
  static const Duration _minInterval = Duration(milliseconds: 50);
  static const double _minDegreeChange = 0.2;

  final StreamController<HeadingReading> _controller =
      StreamController<HeadingReading>.broadcast();

  JSFunction? _absoluteListener;
  JSFunction? _fallbackListener;
  Timer? _watchdog;

  double? _smoothedDegrees;
  bool _started = false;
  bool _gotEvent = false;
  bool _absoluteSeen = false;

  final Stopwatch _sinceEmit = Stopwatch();
  double? _lastEmittedDegrees;
  HeadingQuality? _lastEmittedQuality;

  @override
  Stream<HeadingReading> get readings => _controller.stream;

  @override
  void start() {
    if (_started) return;
    _started = true;
    _emit(const HeadingReading.waiting(HeadingSourceKind.browser));

    _absoluteListener = ((JSObject event) => _onEvent(event, absolute: true)).toJS;
    _fallbackListener = ((JSObject event) => _onEvent(event, absolute: false)).toJS;

    // Chrome on Android fires `deviceorientationabsolute`; Safari fires
    // `deviceorientation` carrying webkitCompassHeading. Listen for both.
    web.window.addEventListener('deviceorientationabsolute', _absoluteListener);
    web.window.addEventListener('deviceorientation', _fallbackListener);

    _watchdog = Timer(_firstEventTimeout, () {
      if (!_gotEvent) {
        _emit(const HeadingReading.unavailable(HeadingSourceKind.browser));
      }
    });
  }

  @override
  Future<bool> requestPermission() async {
    try {
      final ctor =
          globalContext.getProperty<JSObject?>('DeviceOrientationEvent'.toJS);
      if (ctor == null) return false;

      // Android/desktop Chrome has no requestPermission — events just flow.
      final request = ctor.getProperty<JSAny?>('requestPermission'.toJS);
      if (request == null) return true;

      final promise =
          ctor.callMethod<JSPromise<JSString>>('requestPermission'.toJS);
      final state = (await promise.toDart).toDart;
      if (state != 'granted') {
        _emit(const HeadingReading.unavailable(HeadingSourceKind.browser));
        return false;
      }
      // Permission just landed — give the events another chance to arrive.
      _watchdog?.cancel();
      _watchdog = Timer(_firstEventTimeout, () {
        if (!_gotEvent) {
          _emit(const HeadingReading.unavailable(HeadingSourceKind.browser));
        }
      });
      return true;
    } catch (_) {
      return false;
    }
  }

  void _onEvent(JSObject raw, {required bool absolute}) {
    final event = _OrientationEvent(raw);
    double heading;

    final webkitHeading = event.webkitCompassHeading;
    if (webkitHeading != null && !webkitHeading.isNaN) {
      // iOS already reports a true compass heading.
      heading = webkitHeading;
    } else {
      // Once usable absolute events are arriving, ignore the relative ones —
      // their alpha drifts from an arbitrary zero and would fight the real
      // bearing. Some browsers register the absolute listener but never send
      // a usable alpha, so only lock this in once one actually lands.
      if (!absolute && _absoluteSeen) return;

      final isAbsolute = absolute || (event.absolute ?? false);
      final alpha = event.alpha;
      // A non-absolute alpha is measured from wherever the page started, so it
      // is not a compass bearing. Better to show nothing than to point wrong.
      if (!isAbsolute || alpha == null || alpha.isNaN) return;

      if (absolute) _absoluteSeen = true;
      heading = HeadingReading.normalize(360.0 - alpha + _screenAngle());
    }

    _gotEvent = true;
    _watchdog?.cancel();

    heading = HeadingReading.normalize(heading);
    _smoothedDegrees = _smoothedDegrees == null
        ? heading
        : HeadingReading.normalize(
            _smoothedDegrees! +
                HeadingReading.delta(_smoothedDegrees!, heading) *
                    _headingSmoothing,
          );

    if (!_shouldEmit(_smoothedDegrees!, HeadingQuality.good)) return;

    _emit(HeadingReading(
      degrees: _smoothedDegrees!,
      quality: HeadingQuality.good,
      source: HeadingSourceKind.browser,
    ));
  }

  /// Rate-limit the stream — see the same guard in the native source.
  bool _shouldEmit(double degrees, HeadingQuality quality) {
    if (quality != _lastEmittedQuality) return true;
    if (!_sinceEmit.isRunning) return true;
    if (_sinceEmit.elapsed < _minInterval) return false;
    final last = _lastEmittedDegrees;
    if (last != null &&
        HeadingReading.delta(last, degrees).abs() < _minDegreeChange) {
      return false;
    }
    return true;
  }

  /// The event's alpha is relative to the device, not to what the user is
  /// looking at — rotate the phone to landscape and the bearing is off by 90
  /// unless we add the screen angle back in.
  double _screenAngle() {
    try {
      return web.window.screen.orientation.angle.toDouble();
    } catch (_) {
      return 0.0;
    }
  }

  void _emit(HeadingReading reading) {
    if (_controller.isClosed) return;
    _lastEmittedDegrees = reading.degrees;
    _lastEmittedQuality = reading.quality;
    _sinceEmit
      ..reset()
      ..start();
    _controller.add(reading);
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    final absolute = _absoluteListener;
    final fallback = _fallbackListener;
    if (absolute != null) {
      web.window.removeEventListener('deviceorientationabsolute', absolute);
    }
    if (fallback != null) {
      web.window.removeEventListener('deviceorientation', fallback);
    }
    _controller.close();
  }
}
