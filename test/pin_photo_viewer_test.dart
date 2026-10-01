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
    Future<List<String>?> Function()? onAdd,
    Future<List<String>?> Function(int)? onDelete,
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
          onAdd: () async => null,
          onDelete: (_) async => null);
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
        onDelete: (i) async {
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
        onDelete: (_) async => <String>[],
      );
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('No photos on this pin'), findsOneWidget);
    });

    testWidgets('adding lands on the new photo', (tester) async {
      await pump(
        tester,
        images: photos(2),
        onAdd: () async => [...photos(2), 'data:image/jpeg;base64,ZZZZ'],
      );
      await tester.tap(find.byIcon(Icons.add_a_photo_outlined));
      await tester.pumpAndSettle();
      expect(find.text('3 / 3'), findsOneWidget);
    });

    testWidgets('a cancelled delete changes nothing', (tester) async {
      await pump(tester, images: photos(3), onDelete: (_) async => null);
      await tester.tap(find.byIcon(Icons.delete_outline));
      await tester.pumpAndSettle();
      expect(find.text('1 / 3'), findsOneWidget);
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
    testWidgets('an unreadable photo says so instead of showing nothing',
        (tester) async {
      await pump(tester, images: ['not a data uri at all']);
      expect(find.text('Photo unavailable'), findsOneWidget);
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
