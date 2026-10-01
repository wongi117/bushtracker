// A pin's colour is only worth choosing if it survives being stored, shared
// and re-imported, and if every screen that draws the pin actually uses it.
// These cover the palette and the round trip; the screens are checked by eye.
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/core/services/gpx_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the palette', () {
    test('offers ten colours, as asked', () {
      expect(WaypointColors.allColors, hasLength(10));
    });

    test('they are all different', () {
      expect(WaypointColors.allColors.toSet(),
          hasLength(WaypointColors.allColors.length));
    });

    test('every one has a name', () {
      for (final c in WaypointColors.allColors) {
        expect(WaypointColors.names[c], isNotNull, reason: '$c has no name');
      }
    });

    test('every one parses to a real colour', () {
      for (final c in WaypointColors.allColors) {
        final parsed = WaypointColors.fromHex(c);
        expect(parsed.a, 1.0, reason: '$c should be fully opaque');
      }
    });

    test('they are spread out, not near-duplicates', () {
      // The point of the palette is telling pins apart on a map. Two colours a
      // few values away from each other would defeat it.
      final colours = WaypointColors.allColors.map(WaypointColors.fromHex).toList();
      for (var i = 0; i < colours.length; i++) {
        for (var j = i + 1; j < colours.length; j++) {
          final a = colours[i];
          final b = colours[j];
          final gap = (a.r - b.r).abs() + (a.g - b.g).abs() + (a.b - b.b).abs();
          expect(gap, greaterThan(0.25),
              reason: '${WaypointColors.allColors[i]} and '
                  '${WaypointColors.allColors[j]} are too close');
        }
      }
    });
  });

  group('naming a colour', () {
    test('a preset gets its own name', () {
      expect(WaypointColors.nameFor(WaypointColors.dangerRed), 'Red');
      expect(WaypointColors.nameFor(WaypointColors.neonCyan), 'Cyan');
    });

    test('case does not matter', () {
      expect(WaypointColors.nameFor('#ff2d55'), 'Red');
      expect(WaypointColors.nameFor('ff2d55'), 'Red');
    });

    test('a hand-picked colour is described, not dumped as hex', () {
      // Nobody can use "#E63148" on the radio.
      final name = WaypointColors.nameFor('#E63148');
      expect(name, contains('Red'));
      expect(name, isNot(contains('#')));
    });

    test('no colour at all says so', () {
      expect(WaypointColors.nameFor(null), 'Default');
      expect(WaypointColors.nameFor(''), 'Default');
    });
  });

  group('custom colours', () {
    test('a preset is not custom', () {
      for (final c in WaypointColors.allColors) {
        expect(WaypointColors.isCustom(c), isFalse);
      }
    });

    test('anything else is', () {
      expect(WaypointColors.isCustom('#123456'), isTrue);
    });

    test('nothing chosen is not custom either', () {
      expect(WaypointColors.isCustom(null), isFalse);
      expect(WaypointColors.isCustom(''), isFalse);
    });

    test('a colour survives being turned into hex and back', () {
      for (final c in [
        const Color(0xFF123456),
        const Color(0xFFFFFFFF),
        const Color(0xFF000000),
        const Color(0xFF7B2FFF),
      ]) {
        final hex = WaypointColors.toHex(c);
        final back = WaypointColors.fromHex(hex);
        expect(back.r, closeTo(c.r, 0.01), reason: hex);
        expect(back.g, closeTo(c.g, 0.01), reason: hex);
        expect(back.b, closeTo(c.b, 0.01), reason: hex);
      }
    });

    test('toHex always gives six digits with a hash', () {
      expect(WaypointColors.toHex(const Color(0xFF000000)), '#000000');
      expect(WaypointColors.toHex(const Color(0xFF0A0B0C)), '#0A0B0C');
    });
  });

  group('a colour survives a GPX round trip', () {
    Waypoint pin(String? colour) => Waypoint(
          latitude: -28.8833,
          longitude: 121.3333,
          label: 'Old shaft',
          notes: 'collapsed on the north side',
          timestamp: DateTime.utc(2026, 3, 4, 8, 30),
          color: colour,
          isPin: true,
        );

    test('a preset colour comes back', () {
      final gpx = GPXService.exportWaypoints([pin(WaypointColors.sunYellow)]);
      final back = GPXService.parseGPX(gpx);
      expect(back, hasLength(1));
      expect(back.single.color, WaypointColors.sunYellow);
    });

    test('a hand-picked colour comes back too', () {
      final gpx = GPXService.exportWaypoints([pin('#E63148')]);
      expect(GPXService.parseGPX(gpx).single.color, '#E63148');
    });

    test('the file also carries a name other software can read', () {
      // GPX has no colour field, so the hex goes in extensions. <sym> is what
      // other GPS software actually reads, and a word is more use to it.
      final gpx = GPXService.exportWaypoints([pin(WaypointColors.neonCyan)]);
      expect(gpx, contains('<sym>Cyan</sym>'));
      expect(gpx, contains('<bushtrack:color>#00E5FF</bushtrack:color>'));
    });

    test('a pin with no colour writes no colour tags', () {
      final gpx = GPXService.exportWaypoints([pin(null)]);
      expect(gpx, isNot(contains('bushtrack:color')));
      expect(GPXService.parseGPX(gpx).single.color, isNull);
    });

    test('someone else\'s GPX still imports, just without a colour', () {
      const plain = '''
<?xml version="1.0"?>
<gpx version="1.1">
  <wpt lat="-28.88" lon="121.33">
    <name>Their waypoint</name>
  </wpt>
</gpx>''';
      final back = GPXService.parseGPX(plain);
      expect(back, hasLength(1));
      expect(back.single.label, 'Their waypoint');
      expect(back.single.color, isNull);
    });

    test('several pins keep their own colours', () {
      final gpx = GPXService.exportWaypoints([
        pin(WaypointColors.dangerRed),
        pin(WaypointColors.skyBlue),
        pin(WaypointColors.charcoal),
      ]);
      final back = GPXService.parseGPX(gpx);
      expect(back.map((w) => w.color), [
        WaypointColors.dangerRed,
        WaypointColors.skyBlue,
        WaypointColors.charcoal,
      ]);
    });
  });

  group('existing pins are left alone', () {
    test('an old colour outside the palette is kept, not snapped to it', () {
      // "Existing pins keep their current colour unless edited."
      final old = Waypoint(id: 1, latitude: 1, longitude: 2, color: '#ABCDEF');
      expect(old.copyWith(label: 'renamed').color, '#ABCDEF');
    });

    test('and it still draws and still has a name', () {
      expect(WaypointColors.fromHex('#ABCDEF').a, 1.0);
      expect(WaypointColors.nameFor('#ABCDEF'), isNotEmpty);
    });
  });
}
