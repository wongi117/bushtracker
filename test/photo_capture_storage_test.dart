// Photos taken on a pin, and where they end up.
//
// Every capture path wrote a base64 data URI into the pin's row. Measured on
// real phone photos through compressForStorage, that is 217-417 KB a photo,
// and Android reads a row through a 2 MB CursorWindow: about six photos on one
// pin and the platform will not hand the row back. The photo migration moved
// old photos to disk, but nothing stopped new ones going straight back in.
import 'dart:io';
import 'dart:typed_data';

import 'package:bush_track/core/models/photo_paths_codec.dart';
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/core/services/photo_capture_service.dart';
import 'package:bush_track/core/services/photo_file_store.dart';
import 'package:bush_track/features/map/widgets/waypoint_marker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // The size of a real compressed photo, so the arithmetic below is the
  // arithmetic on the phone.
  final photo = Uint8List.fromList(List.generate(300 * 1024, (i) => i % 251));

  group('a captured photo is kept as a file', () {
    late Directory temp;
    late PhotoFileStore store;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('capture_test');
      store = PhotoFileStore(baseDirectory: temp);
    });
    tearDown(() => temp.delete(recursive: true));

    test('the reference is a file, not the picture itself', () async {
      final reference = await PhotoCaptureService.keep(photo, store: store);
      expect(PhotoFileStore.isDataUri(reference), isFalse);
      expect(await store.read(reference), photo);
    });

    test('thirty photos on one pin is a small row', () async {
      // _maxInOneGo is 30. As data URIs that is around 12 MB in one row; as
      // references it is about a kilobyte.
      final refs = <String>[
        for (var i = 0; i < 30; i++)
          await PhotoCaptureService.keep(photo, store: store),
      ];
      final row = PhotoPathsCodec.encode(refs)!;
      expect(row.length, lessThan(4 * 1024));
      expect(refs.toSet(), hasLength(30), reason: 'every photo its own file');
    });
  });

  group('when there is nowhere to put a file, the photo is still kept', () {
    test('it falls back to the data URI, intact', () async {
      // A widget test has no platform channels, exactly as web has no
      // documents directory: the store has no directory at all.
      final reference =
          await PhotoCaptureService.keep(photo, store: PhotoFileStore());
      expect(PhotoFileStore.isDataUri(reference), isTrue);
      expect(PhotoFileStore.decodeDataUri(reference), photo);
    });
  });

  // The sheet an ordinary pin opens. It showed one photo -- the thumbnail or
  // the first -- and only while it was base64, so once photos moved to disk
  // it showed none.
  group('the pin sheet shows every photo', () {
    List<String> refs(int n) => List.generate(n, (i) => 'photo_$i.jpg');

    Future<void> pump(WidgetTester tester, List<String> photos) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: WaypointPhotoStrip(
            waypoint: Waypoint(
                latitude: -28.88, longitude: 121.33, photoPaths: photos),
          ),
        ),
      ));
      await tester.pump();
    }

    testWidgets('one thumbnail per photo, and a counter', (tester) async {
      await pump(tester, refs(5));
      expect(find.text('1 / 5'), findsOneWidget);
      for (var i = 0; i < 5; i++) {
        expect(find.byKey(ValueKey('waypoint-thumb-$i')), findsOneWidget);
      }
    });

    testWidgets('tapping a thumbnail shows that photo', (tester) async {
      await pump(tester, refs(3));
      await tester.tap(find.byKey(const ValueKey('waypoint-thumb-2')));
      await tester.pump();
      expect(find.text('3 / 3'), findsOneWidget);
    });

    testWidgets('a single photo has no strip and no counter', (tester) async {
      await pump(tester, refs(1));
      expect(find.byKey(const ValueKey('waypoint-thumb-0')), findsNothing);
      expect(find.text('1 / 1'), findsNothing);
    });

    testWidgets('file references do not throw while they resolve',
        (tester) async {
      await pump(tester, refs(3));
      expect(tester.takeException(), isNull);
    });
  });
}
