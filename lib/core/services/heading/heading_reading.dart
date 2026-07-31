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
  /// 0–360, clockwise from north.
  final double degrees;
  final HeadingQuality quality;
  final HeadingSourceKind source;

  /// Magnetic field strength in microtesla, when the source can measure it.
  /// Earth's field is roughly 25–65 uT; well outside that means interference.
  final double? fieldStrengthUt;

  const HeadingReading({
    required this.degrees,
    required this.quality,
    required this.source,
    this.fieldStrengthUt,
  });

  const HeadingReading.waiting(HeadingSourceKind source)
      : this(degrees: 0, quality: HeadingQuality.waiting, source: source);

  const HeadingReading.unavailable([
    HeadingSourceKind source = HeadingSourceKind.none,
  ]) : this(degrees: 0, quality: HeadingQuality.unavailable, source: source);

  /// True once we have a real bearing to show, trustworthy or not.
  bool get isLive =>
      quality == HeadingQuality.good || quality == HeadingQuality.interference;

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
