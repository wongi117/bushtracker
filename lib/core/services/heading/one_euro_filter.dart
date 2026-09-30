import 'dart:math' as math;

/// Smoothing that does not trade jitter for lag.
///
/// A plain exponential filter has one setting, and it is always the wrong
/// one: smooth enough to stop AR markers shivering while you stand still
/// means they lag behind when you turn, and responsive enough to keep up
/// while turning means they shiver.
///
/// This is the "one euro" filter (Casiez, Roussel & Vogel, 2012). It adapts:
/// when the signal is barely changing it filters hard, and the faster the
/// signal moves the more it lets through. So a beam sits still when the phone
/// does, and still keeps up when you swing around.
class OneEuroFilter {
  OneEuroFilter({
    // The trap here is beta: the derivative of a noisy signal is huge (two
    // units of noise across a 20 ms step reads as a hundred units a second),
    // so a large beta keeps opening the filter up in response to noise rather
    // than movement — raising beta on its own made the shimmer worse.
    //
    // Smoothing the speed estimate hard was the first answer, and it worked,
    // but it cost responsiveness for no good reason. [speedFloor] is the
    // better one: noise and movement differ in size, so a floor tells them
    // apart directly, which frees the speed estimate to be quick.
    //
    // Measured against a 50 Hz signal with two units of noise, worst error:
    //
    //                      still  25/s  60/s  120/s  250/s
    //   before (b .02)      0.49   3.1   5.2    7.8   12.5
    //   now    (b .06)      0.39   2.2   3.3    4.4    7.1
    //
    // Better on every count, which is the only reason to change tuning that
    // already worked.
    this.minCutoff = 0.15,
    this.beta = 0.06,
    this.derivativeCutoff = 1.0,
    this.speedFloor = 20.0,
  });

  /// The same filter for a signal in radians rather than degrees.
  ///
  /// [beta] and [speedFloor] multiply a rate, so they carry units. A tilt
  /// changing at one radian a second is the same physical motion as
  /// 57 degrees a second, so feeding radians into a filter tuned for degrees
  /// leaves the adaptation 57 times too weak — which is a horizon, and every
  /// marker hung off it, sliding a long way behind the phone whenever you
  /// raise or lower it.
  factory OneEuroFilter.radians() => OneEuroFilter(
        beta: 0.06 * 180 / math.pi,
        speedFloor: 20.0 * math.pi / 180,
      );

  /// Cutoff frequency (Hz) when the signal is still. Lower is smoother.
  final double minCutoff;

  /// How much speed opens the filter up. Higher means less lag when moving.
  final double beta;

  final double derivativeCutoff;

  /// Apparent speed below this is treated as noise and ignored by [beta].
  ///
  /// The hole in the plain filter: the derivative of a noisy signal is not
  /// small. Two units of noise across a 20 ms step reads as a hundred units a
  /// second, and smoothing the speed estimate enough to hide that is what
  /// made the filter too slow to notice a real turn starting. Noise and
  /// movement differ in size, though — the smoothed speed sits around four or
  /// five units while standing still and runs to a hundred and twenty when
  /// you sweep the phone around — so a floor separates them cleanly. Below it
  /// the filter stays at [minCutoff] and holds a still marker dead steady;
  /// above it, adaptation gets the full rate.
  ///
  /// Set from measurement, not arithmetic: on a 50 Hz signal carrying two
  /// units of noise the smoothed speed estimate peaks around fourteen units a
  /// second, so twenty clears it. Slower real movement than that loses the
  /// adaptation, which is why the floor is not higher — a deliberate slow pan
  /// looking for a waypoint is only a few tens of degrees a second, and it
  /// still needs to keep up.
  ///
  /// In the signal's own units per second: degrees for a bearing, radians for
  /// a tilt.
  final double speedFloor;

  double? _lastValue;
  double? _lastDerivative;

  /// Feed a new reading, get the smoothed one back.
  ///
  /// [dt] is the time since the previous reading in seconds.
  double filter(double value, double dt) {
    if (dt <= 0 || !dt.isFinite) dt = 1 / 50;

    final previous = _lastValue;
    if (previous == null) {
      _lastValue = value;
      _lastDerivative = 0;
      return value;
    }

    // Rate of change, itself smoothed — a noisy derivative would make the
    // filter flap between smooth and responsive.
    final rawDerivative = (value - previous) / dt;
    final derivative = _lowPass(
      rawDerivative,
      _lastDerivative ?? 0,
      _alpha(derivativeCutoff, dt),
    );
    _lastDerivative = derivative;

    // Fast movement raises the cutoff, letting more of the real signal past.
    // Sensor noise does not count as movement: see [speedFloor].
    final speed = math.max(0.0, derivative.abs() - speedFloor);
    final cutoff = minCutoff + beta * speed;
    final smoothed = _lowPass(value, previous, _alpha(cutoff, dt));
    _lastValue = smoothed;
    return smoothed;
  }

  void reset() {
    _lastValue = null;
    _lastDerivative = null;
  }

  static double _lowPass(double value, double previous, double alpha) =>
      alpha * value + (1 - alpha) * previous;

  static double _alpha(double cutoff, double dt) {
    final tau = 1 / (2 * math.pi * cutoff);
    return 1 / (1 + tau / dt);
  }
}

/// The same filter for a compass bearing.
///
/// Angles wrap, so smoothing 359 and 1 as plain numbers averages to 180 —
/// the needle swinging right around the dial as you cross north. This
/// filters the shortest signed step instead, and wraps the result.
class OneEuroAngleFilter {
  OneEuroAngleFilter({double minCutoff = 0.15, double beta = 0.06})
      : _inner = OneEuroFilter(minCutoff: minCutoff, beta: beta);


  final OneEuroFilter _inner;

  /// The bearing as a continuous number that is allowed to run past 360 or
  /// below 0. Turning twice clockwise from north reads 720, not 0 — which
  /// means the filter sees steady movement rather than a jump at every
  /// crossing, and adapts on real turn speed.
  double? _unwrapped;

  double filter(double degrees, double dt) {
    final previous = _unwrapped;
    if (previous == null) {
      _unwrapped = degrees;
      return _normalize(_inner.filter(degrees, dt));
    }

    // Step to the new reading the short way round, then keep accumulating.
    var delta = (degrees - previous) % 360;
    if (delta > 180) delta -= 360;
    if (delta < -180) delta += 360;
    _unwrapped = previous + delta;

    return _normalize(_inner.filter(_unwrapped!, dt));
  }

  void reset() {
    _unwrapped = null;
    _inner.reset();
  }

  static double _normalize(double deg) => (deg % 360 + 360) % 360;
}
