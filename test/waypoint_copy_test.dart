// Changing a pin's colour used to take it out of its project.
//
// The update methods rebuilt a Waypoint by hand, listing the fields they knew
// about. fileId, rating and weatherConditions were added to the model later and
// never added to those lists, so every one of them was silently dropped — a pin
// recoloured after being filed quietly left the project it was filed under.
// That is exactly the kind of thing that gets reported as "the app lost my
// pins", so it gets a test rather than a promise.
import 'package:bush_track/core/models/waypoint.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Waypoint full() => Waypoint(
        id: 12,
        latitude: -28.8812,
        longitude: 121.3312,
        altitude: 376,
        accuracy: 4.2,
        speed: 1.1,
        label: 'Old shaft',
        notes: 'Collapsed on the north side',
        timestamp: DateTime.utc(2026, 3, 4, 8, 30),
        type: WaypointType.pinage,
        photoPaths: const ['a.jpg', 'b.jpg'],
        thumbnailPath: 't.jpg',
        color: WaypointColors.emberOrange,
        icon: WaypointIcon.hazard,
        order: 3,
        isPin: true,
        fileId: 9,
        rating: 4,
        weatherConditions: 'Clear, 31C',
      );

  void expectSameExcept(Waypoint before, Waypoint after,
      {Set<String> changed = const {}}) {
    void same(String field, Object? a, Object? b) {
      if (changed.contains(field)) return;
      expect(b, a, reason: '$field should have survived the copy');
    }

    same('id', before.id, after.id);
    same('latitude', before.latitude, after.latitude);
    same('longitude', before.longitude, after.longitude);
    same('altitude', before.altitude, after.altitude);
    same('accuracy', before.accuracy, after.accuracy);
    same('speed', before.speed, after.speed);
    same('label', before.label, after.label);
    same('notes', before.notes, after.notes);
    same('timestamp', before.timestamp, after.timestamp);
    same('type', before.type, after.type);
    same('photoPaths', before.photoPaths, after.photoPaths);
    same('thumbnailPath', before.thumbnailPath, after.thumbnailPath);
    same('color', before.color, after.color);
    same('icon', before.icon, after.icon);
    same('order', before.order, after.order);
    same('isPin', before.isPin, after.isPin);
    same('fileId', before.fileId, after.fileId);
    same('rating', before.rating, after.rating);
    same('weatherConditions', before.weatherConditions, after.weatherConditions);
  }

  group('a copy keeps everything it was not asked to change', () {
    test('recolouring changes the colour and nothing else', () {
      final before = full();
      final after = before.copyWith(color: WaypointColors.neonCyan);
      expect(after.color, WaypointColors.neonCyan);
      expectSameExcept(before, after, changed: {'color'});
    });

    test('recolouring keeps the pin in its project', () {
      // The bug, stated directly.
      expect(full().copyWith(color: WaypointColors.white).fileId, 9);
    });

    test('recolouring keeps the rating and the weather note', () {
      final after = full().copyWith(color: WaypointColors.white);
      expect(after.rating, 4);
      expect(after.weatherConditions, 'Clear, 31C');
    });

    test('changing the icon changes the icon and nothing else', () {
      final before = full();
      final after = before.copyWith(icon: WaypointIcon.water);
      expect(after.icon, WaypointIcon.water);
      expectSameExcept(before, after, changed: {'icon'});
    });

    test('moving a pin changes the position and nothing else', () {
      final before = full();
      final after = before.copyWith(latitude: -29.0, longitude: 122.0);
      expect(after.latitude, -29.0);
      expect(after.longitude, 122.0);
      expectSameExcept(before, after, changed: {'latitude', 'longitude'});
    });

    test('a copy with no arguments is the same pin over again', () {
      final before = full();
      expectSameExcept(before, before.copyWith());
    });

    test('nulls on the original stay null rather than being invented', () {
      final bare = Waypoint(id: 1, latitude: 1, longitude: 2);
      final after = bare.copyWith(color: WaypointColors.white);
      expect(after.fileId, isNull);
      expect(after.rating, isNull);
      expect(after.notes, isNull);
      expect(after.weatherConditions, isNull);
    });
  });

  group('filing', () {
    test('a pin can be put into a project', () {
      expect(full().copyWith(fileId: 4).fileId, 4);
    });

    test('an unfiled pin can be filed', () {
      final loose = Waypoint(id: 1, latitude: 1, longitude: 2);
      expect(loose.copyWith(fileId: 7).fileId, 7);
    });

    test('taking a pin out of every project needs clearFile', () {
      // A null fileId cannot mean "remove it": null is what you pass for
      // "leave this field alone", so removal needs saying out loud.
      expect(full().copyWith(fileId: null).fileId, 9);
      expect(full().copyWith(clearFile: true).fileId, isNull);
    });

    test('clearFile wins over a fileId given at the same time', () {
      expect(full().copyWith(fileId: 3, clearFile: true).fileId, isNull);
    });

    test('unfiling leaves the rest of the pin alone', () {
      final before = full();
      final after = before.copyWith(clearFile: true);
      expectSameExcept(before, after, changed: {'fileId'});
    });
  });
}
