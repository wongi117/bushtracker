import 'dart:math' as math;

/// Where a live heading came from.
enum HeadingSourceKind {
  /// Device magnetometer + accelerometer (Android/iOS build).
  sensors,

  /// Browser DeviceOrientation events (web build / PWA).
  browser,

  /// Nothing available.
  none,
}

/// How much the current reading can be trusted.
enum HeadingQuality {
  /// Live and within a sane magnetic field range.
  good,

  /// Live, but the magnetic field is way off earth-normal — the user is next
  /// to a vehicle body, a UHF, or the compass needs a figure-8 calibration.
  interference,

  /// Source started, first event has not landed yet.
  waiting,

  /// No sensor, blocked by the browser, or permission denied.
  unavailable,
}

/// A single compass reading, always clockwise from north.
class HeadingReading {
  /// 0–360, clockwise from north: where the handset's top edge points.
  ///
  /// The right bearing for a compass rose on a phone held flat like a map.
  /// Not the right one for an AR camera — see [cameraDegrees].
  final double degrees;

  /// Where the lens is pointed, 0–360 clockwise from north, or null if it has
  /// not been measurable yet.
  ///
  /// A separate number because it answers a different question, and because
  /// [degrees] cannot answer this one: held up to look through the camera, the
  /// top edge points at the sky and its bearing is noise. Markers pinned to
  /// [degrees] drifted along with the camera instead of staying on their
  /// feature. See magnetic_bearing.dart.
  ///
  /// Null while the lens points at the ground or the sky and no earlier
  /// reading exists, where the bearing genuinely has no value.
  final double? cameraDegrees;
  final HeadingQuality quality;
  final HeadingSourceKind source;

  /// Magnetic field strength in microtesla, when the source can measure it.
  /// Earth's field is roughly 25–65 uT; well outside that means interference.
  final double? fieldStrengthUt;

  /// How far the camera is tilted up or down from level, in radians.
  /// Positive is up. Needed to put the horizon in the right place on screen —
  /// without it, AR markers sit at a fixed height regardless of how the phone
  /// is held.
  final double pitchRad;

  /// Rotation about the camera axis, in radians. Positive is the phone
  /// rolled clockwise from portrait.
  final double rollRad;

  const HeadingReading({
    required this.degrees,
    required this.quality,
    required this.source,
    this.cameraDegrees,
    this.fieldStrengthUt,
    this.pitchRad = 0,
    this.rollRad = 0,
  });

  const HeadingReading.waiting(HeadingSourceKind source)
      : this(degrees: 0, quality: HeadingQuality.waiting, source: source);

  /// True when the magnetic field says the compass cannot be trusted and a
  /// figure-of-eight would fix it.
  bool get needsCalibration => quality == HeadingQuality.interference;

  const HeadingReading.unavailable([
    HeadingSourceKind source = HeadingSourceKind.none,
  ]) : this(degrees: 0, quality: HeadingQuality.unavailable, source: source);

  /// True once we have a real bearing to show, trustworthy or not.
  bool get isLive =>
      quality == HeadingQuality.good || quality == HeadingQuality.interference;

  /// True once the lens bearing is good for anchoring an AR marker.
  bool get hasCameraBearing => isLive && cameraDegrees != null;

  /// Clockwise from north, in radians — what `Transform.rotate` wants.
  double get radians => degrees * math.pi / 180.0;

  static const _points = <String>[
    'N', 'NNE', 'NE', 'ENE',
    'E', 'ESE', 'SE', 'SSE',
    'S', 'SSW', 'SW', 'WSW',
    'W', 'WNW', 'NW', 'NNW',
  ];

  /// 16-point cardinal name, e.g. `NNE`.
  String get cardinal => _points[((normalize(degrees) / 22.5).round()) % 16];

  /// Wrap any angle into 0–360.
  static double normalize(double deg) => (deg % 360 + 360) % 360;

  /// Shortest signed difference from [from] to [to], in -180..180.
  static double delta(double from, double to) {
    var d = (to - from) % 360;
    if (d > 180) d -= 360;
    if (d < -180) d += 360;
    return d;
  }

  @override
  String toString() =>
      'HeadingReading(${degrees.toStringAsFixed(1)}deg $cardinal, '
      '$quality, $source)';
}
