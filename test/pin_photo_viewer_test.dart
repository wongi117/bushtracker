// One viewer serves the pin detail sheet and the AR sheet. These cover the
// behaviour both rely on — the counter, the caption, zooming, and the index
// staying inside the list when a photo is deleted out from under it.
import 'package:bush_track/features/map/widgets/pin_photo_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Valid base64, though not a real JPEG: these render as "Photo unavailable",
  // which is the right outcome for bytes that are not an image and is not what
  // is under test here — the chrome around them is.
  List<String> photos(int n) => List.generate(
      n, (i) => 'data:image/jpeg;base64,${'ABCD' * (i + 1)}');

  Future<void> pump(
    WidgetTester tester, {
    required List<String> images,
    int initialIndex = 0,
    String? title,
    String? notes,
    DateTime? takenAt,
    Future<List<String>?> Function(List<String>)? onAdd,
    Future<List<String>?> Function(List<String>, int)? onDelete,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: PinPhotoViewer(
        photos: images,
        initialIndex: initialIndex,
        title: title,
        notes: notes,
        takenAt: takenAt,
        onAdd: onAdd,
        onDelete: onDelete,
      ),
    ));
    await tester.pumpAndSettle();
  }

  group('the counter', () {
    testWidgets('shows which photo of how many', (tester) async {
      await pump(tester, images: photos(5));
      expect(find.text('1 / 5'), findsOneWidget);
    });

    testWidgets('starts where it was opened', (tester) async {
      await pump(tester, images: photos(5), initialIndex: 2);
      expect(find.text('3 / 5'), findsOneWidget);
    });

    testWidgets('a single photo still shows a counter', (tester) async {
      // Unlike the thumbnail badge, which stays quiet at one, the counter is
      // the only thing saying where you are, so it is always there.
      await pump(tester, images: photos(1));
      expect(find.text('1 / 1'), findsOneWidget);
    });

    testWidgets('an out-of-range index is pulled back in', (tester) async {
      await pump(tester, images: photos(3), initialIndex: 99);
      expect(find.text('3 / 3'), findsOneWidget);
    });
  });

  group('swiping', () {
    testWidgets('moves to the next photo and the counter follows',
        (tester) async {
      await pump(tester, images: photos(3));
      await tester.drag(find.byType(PageView), const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(find.text('2 / 3'), findsOneWidget);
    });

    testWidgets('and back again', (tester) async {
      await pump(tester, images: photos(3), initialIndex: 1);
      await tester.drag(find.byType(PageView), const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
    });
  });

  group('pinch to zoom', () {
    testWidgets('every photo gets its own InteractiveViewer', (tester) async {
      // One each, so zooming into a photo does not carry over to the next.
      await pump(tester, images: photos(3));
      expect(find.byType(InteractiveViewer), findsWidgets);
      final viewer =
          tester.widget<InteractiveViewer>(find.byType(InteractiveViewer).first);
      expect(viewer.maxScale, greaterThan(1));
    });
  });

  group('caption and date', () {
    testWidgets('the pin name is along the top', (tester) async {
      await pump(tester, images: photos(2), title: 'Old shaft');
      expect(find.text('Old shaft'), findsOneWidget);
    });

    testWidgets('the notes are the caption', (tester) async {
      await pump(tester,
          images: photos(2), notes: 'collapsed on the north side');
      expect(find.text('collapsed on the north side'), findsOneWidget);
    });

    testWidgets('the date taken is shown', (tester) async {
      await pump(tester,
          images: photos(1), takenAt: DateTime(2026, 3, 4, 14, 30));
      expect(find.textContaining('Mar 4, 2026'), findsOneWidget);
      expect(find.textContaining('2:30pm'), findsOneWidget);
    });

    testWidgets('no notes means no empty caption line', (tester) async {
      await pump(tester, images: photos(1), notes: '   ');
      // Only the counter, no blank caption taking up room.
      expect(find.text('1 / 1'), findsOneWidget);
    });

    testWidgets('a pin with no name still opens', (tester) async {
      await pump(tester, images: photos(1));
      expect(find.text('Photos'), findsOneWidget);
    });
  });

  group('editing', () {
    testWidgets('no add or delete button when the callbacks are absent',
        (tester) async {
      // Which is how a pin someone else owns will be handled once there are
      // shared pins to be read-only about.
      await pump(tester, images: photos(2));
      expect(find.byIcon(Icons.add_a_photo_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });

    testWidgets('both appear when they are given', (tester) async {
      await pump(tester,
          images: photos(2),
          onAdd: (_) async => null,
          onDelete: (_, __) async => null);
      expect(find.byIcon(Icons.add_a_photo_outlined), findsOneWidget);
      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
    });

    testWidgets('deleting drops the count and keeps the index in range',
        (tester) async {
      var images = photos(3);
      await pump(
        tester,
        images: images,
        initialIndex: 2,
        onDelete: (_, i) async {
          images = [...images]..removeAt(i);
          return images;
        },
      );
      expect(find.text('3 / 3'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      // Was on the last photo; after deleting it the index must come back
      // inside the list rather than reading off the end.
      expect(find.text('2 / 2'), findsOneWidget);
    });

    testWidgets('deleting the last photo leaves a plain message',
        (tester) async {
      await pump(
        tester,
        images: photos(1),
        onDelete: (_, __) async => <String>[],
      );
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('No photos on this pin'), findsOneWidget);
    });

    testWidgets('adding lands on the new photo', (tester) async {
      await pump(
        tester,
        images: photos(2),
        onAdd: (current) async => [...current, 'data:image/jpeg;base64,ZZZZ'],
      );
      await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
    });

    testWidgets('a cancelled delete changes nothing', (tester) async {
      await pump(tester, images: photos(3), onDelete: (_, __) async => null);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
    });
  });

  // Both sheets used to save from their own copy of the list, which does not
  // move while this viewer is open. So the second add in here was saved as the
  // original photos plus the second batch -- the first batch gone -- and a
  // delete after an add took the new photos with it. [saved] stands in for the
  // database: each callback writes what it was handed plus its change, exactly
  // as PinPhotoEditing does.
  group('a run of changes in the viewer keeps every photo', () {
    var n = 0;
    String shot() => 'data:image/jpeg;base64,${'Q' * 4 * ++n}';

    testWidgets('two adds keep both', (tester) async {
      var saved = photos(1);
      await pump(tester, images: saved, onAdd: (current) async {
        return saved = [...current, shot()];
      });

      await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
      await tester.pumpAndSettle();

      expect(saved, hasLength(3));
      expect(find.text('3 / 3'), findsOneWidget);
    });

    testWidgets('a delete after an add keeps the added photo', (tester) async {
      var saved = photos(2);
      await pump(
        tester,
        images: saved,
        onAdd: (current) async => saved = [...current, shot()],
        onDelete: (current, i) async => saved = [...current]..removeAt(i),
      );

      await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
      await tester.pumpAndSettle();
      final added = saved.last;
      // Back to the first and delete it.
      await tester.drag(find.byType(PageView), const Offset(1000, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.byType(PageView), const Offset(1000, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();

      expect(saved, hasLength(2));
      expect(saved, contains(added));
    });

    testWidgets('the callback is handed what is on screen', (tester) async {
      final seen = <int>[];
      var saved = photos(1);
      await pump(tester, images: saved, onAdd: (current) async {
        seen.add(current.length);
        return saved = [...current, shot()];
      });
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
        await tester.pumpAndSettle();
      }
      expect(seen, [1, 2, 3]);
    });
  });

  group('closing', () {
    testWidgets('there is a close button', (tester) async {
      await pump(tester, images: photos(2));
      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('closing hands back the photo list, so the caller can update',
        (tester) async {
      // This is what lets the sheet underneath refresh its badge and strip
      // without reopening.
      List<String>? handedBack;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () async {
              handedBack = await Navigator.push<List<String>>(
                context,
                MaterialPageRoute(
                    builder: (_) => PinPhotoViewer(photos: photos(2))),
              );
            },
            child: const Text('open'),
          ),
        ),
      ));

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(handedBack, hasLength(2));
    });
  });

  group('bad photos', () {
    testWidgets('a file reference does not throw while it resolves',
        (tester) async {
      // Not a data URI, so it is treated as a file on disk. A widget test has
      // no photo directory, exactly as web has none, and the viewer has to
      // cope rather than take the screen down. The "Photo unavailable" wording
      // for a missing file is covered in pin_photo_image_test, which injects a
      // store instead of relying on a platform channel.
      await pump(tester, images: ['not-a-real-file.jpg']);
      expect(tester.takeException(), isNull);
      expect(find.text('1 / 1'), findsOneWidget);
    });

    testWidgets('a shredded data URI is caught too', (tester) async {
      // The old storage bug's leftovers: a header with no payload.
      await pump(tester, images: ['data:image/jpeg;base64']);
      expect(find.text('Photo unavailable'), findsOneWidget);
    });

    testWidgets('no photos at all does not crash', (tester) async {
      await pump(tester, images: const []);
      expect(find.text('No photos on this pin'), findsOneWidget);
    });
  });
}
