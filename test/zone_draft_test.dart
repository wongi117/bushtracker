// The drawing state machine: what a tap does, when a zone can be saved, and
// what switching shape throws away. Pure logic, so it is tested without a map.
import 'package:bush_track/core/models/geofence.dart';
import 'package:bush_track/features/geofence/presentation/zone_drawing.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const a = LatLng(-28.900, 121.300);
  const b = LatLng(-28.900, 121.310);
  const c = LatLng(-28.890, 121.310);

  test('a circle keeps only the latest centre', () {
    const draft = ZoneDraft();
    final moved = draft.withTap(a).withTap(b);

    expect(moved.points, hasLength(1));
    expect(moved.centre, b, reason: 'tapping again moves the centre');
  });

  test('a boundary collects every corner in order', () {
    const draft = ZoneDraft(shape: ZoneShape.polygon);
    final drawn = draft.withTap(a).withTap(b).withTap(c);

    expect(drawn.points, [a, b, c]);
  });

  test('a circle can be saved as soon as its centre is placed', () {
    const draft = ZoneDraft();
    expect(draft.isSaveable, isFalse);
    expect(draft.withTap(a).isSaveable, isTrue);
  });

  test('a boundary needs three corners before it encloses anything', () {
    const draft = ZoneDraft(shape: ZoneShape.polygon);
    expect(draft.withTap(a).isSaveable, isFalse);
    expect(draft.withTap(a).withTap(b).isSaveable, isFalse);
    expect(draft.withTap(a).withTap(b).withTap(c).isSaveable, isTrue);
  });

  test('undo removes the last corner and stops at empty', () {
    const draft = ZoneDraft(shape: ZoneShape.polygon);
    final two = draft.withTap(a).withTap(b);

    expect(two.undoLastPoint().points, [a]);
    expect(two.undoLastPoint().undoLastPoint().points, isEmpty);
    // Undoing an empty draft must not throw or go negative.
    expect(two.undoLastPoint().undoLastPoint().undoLastPoint().points, isEmpty);
  });

  test('switching shape clears points that do not carry over', () {
    const draft = ZoneDraft(shape: ZoneShape.polygon);
    final drawn = draft.withTap(a).withTap(b).withTap(c);

    final asCircle = drawn.withShape(ZoneShape.circle);
    expect(asCircle.points, isEmpty,
        reason: 'three corners are not a circle centre');
    expect(asCircle.isSaveable, isFalse);
  });

  test('switching to the shape already selected changes nothing', () {
    const draft = ZoneDraft(shape: ZoneShape.polygon);
    final drawn = draft.withTap(a).withTap(b);

    expect(drawn.withShape(ZoneShape.polygon).points, [a, b],
        reason: 'tapping the selected mode must not wipe the work so far');
  });

  group('radius slider scale', () {
    test('the ends of the slider are the smallest and largest zone', () {
      expect(sliderTToRadius(0), closeTo(kZoneMinRadius, 0.001));
      expect(sliderTToRadius(1), closeTo(kZoneMaxRadius, 0.001));
      expect(radiusToSliderT(kZoneMinRadius), closeTo(0, 1e-9));
      expect(radiusToSliderT(kZoneMaxRadius), closeTo(1, 1e-9));
    });

    test('converting a radius to a slider position and back is lossless', () {
      for (final metres in [20.0, 75.0, 200.0, 1500.0, 12000.0, 50000.0]) {
        expect(sliderTToRadius(radiusToSliderT(metres)), closeTo(metres, 0.01),
            reason: '$metres m should survive the round trip');
      }
    });

    test('small sizes get half the slider, not a sliver of it', () {
      // The point of the log scale: on a linear 20 m - 50 km slider, 1 km sits
      // at 2% of the travel and every useful small size is unreachable.
      final oneKm = radiusToSliderT(1000);
      expect(oneKm, greaterThan(0.4));
      expect(oneKm, lessThan(0.6));
    });

    test('anything out of range is pulled back to the limits', () {
      expect(radiusToSliderT(1), closeTo(0, 1e-9));
      expect(radiusToSliderT(999999), closeTo(1, 1e-9));
      expect(sliderTToRadius(-1), closeTo(kZoneMinRadius, 0.001));
      expect(sliderTToRadius(2), closeTo(kZoneMaxRadius, 0.001));
    });
  });

  test('area reflects the shape being drawn', () {
    const circle = ZoneDraft(radiusMetres: 100);
    // A 100 m circle is about 31,400 square metres.
    expect(circle.withTap(a).areaSqMetres, closeTo(31415, 50));

    const poly = ZoneDraft(shape: ZoneShape.polygon);
    expect(poly.withTap(a).withTap(b).areaSqMetres, 0,
        reason: 'two corners enclose no ground');
  });
}
