// Photos exist in two forms at once while the migration rolls out: base64 in
// the database, and files on disk. Every place that draws one has to handle
// both, and this is the single widget that does.
//
// The file resolver is injected rather than hitting a real disk: real file I/O
// does not run under the fake clock a widget test uses, so a test that wrote a
// file and waited for it simply hung. What this widget is responsible for is
// choosing the right branch and saying the right thing when there is nothing to
// show; the file behaviour itself is covered against a real directory in
// photo_migration_test.
import 'dart:convert';
import 'dart:io';

import 'package:bush_track/features/map/widgets/pin_photo_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// A one-pixel PNG, so a data URI has something real in it.
  final onePixelPng = base64Encode(base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFAAH/'
      'q842iQAAAABJRU5ErkJggg=='));

  Future<void> pump(
    WidgetTester tester,
    String reference, {
    double size = 200,
    bool showLabel = true,
    File? resolvesTo,
  }) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: size,
            height: size,
            child: PinPhotoImage(
              reference: reference,
              showLabel: showLabel,
              resolve: (_) async => resolvesTo,
            ),
          ),
        ),
      ),
    ));
    // Fixed pumps rather than pumpAndSettle: a file-backed Image never
    // finishes decoding under a fake clock, so settling spins until it times
    // out. Two pumps is enough for the resolve future to land.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  group('a photo stored as base64 in the database', () {
    testWidgets('draws, and needs no file system at all', (tester) async {
      await pump(tester, 'data:image/png;base64,$onePixelPng');
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Photo unavailable'), findsNothing);
    });

    testWidgets('draws on the first frame, with no placeholder flicker',
        (tester) async {
      // A data URI needs no await, and a thumbnail in a scrolling list must
      // not flash grey on every frame.
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 200,
            child: PinPhotoImage(
              reference: 'data:image/png;base64,$onePixelPng',
            ),
          ),
        ),
      ));
      // One pump, no settle.
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('a shredded data URI says so', (tester) async {
      // The leftovers of the old comma-joined column: a header, no payload.
      await pump(tester, 'data:image/jpeg;base64');
      expect(find.text('Photo unavailable'), findsOneWidget);
    });

    testWidgets('a header with nothing after the comma says so',
        (tester) async {
      await pump(tester, 'data:image/jpeg;base64,');
      expect(find.text('Photo unavailable'), findsOneWidget);
    });

    testWidgets('rubbish base64 says so rather than throwing', (tester) async {
      await pump(tester, 'data:image/jpeg;base64,!!!not base64!!!');
      expect(tester.takeException(), isNull);
      expect(find.text('Photo unavailable'), findsOneWidget);
    });

    testWidgets('a broken data URI never reaches the resolver', (tester) async {
      // It must not be mistaken for a file name and sent to disk.
      var asked = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 200,
            child: PinPhotoImage(
              reference: 'data:image/jpeg;base64',
              resolve: (_) async {
                asked = true;
                return null;
              },
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(asked, isFalse);
    });
  });

  group('a photo stored as a file', () {
    testWidgets('takes the file branch when it resolves', (tester) async {
      await pump(tester, 'photo.png', resolvesTo: File('photo.png'));
      expect(find.byType(Image), findsOneWidget);
      expect(find.text('Photo unavailable'), findsNothing);
    });

    testWidgets('a missing file says so', (tester) async {
      await pump(tester, 'gone.jpg');
      expect(find.text('Photo unavailable'), findsOneWidget);
    });

    testWidgets('the reference is what gets looked up', (tester) async {
      String? asked;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            height: 200,
            child: PinPhotoImage(
              reference: 'abc123.jpg',
              resolve: (r) async {
                asked = r;
                return null;
              },
            ),
          ),
        ),
      ));
      await tester.pump();
      expect(asked, 'abc123.jpg');
    });
  });

  group('the unavailable notice fits its box', () {
    testWidgets('a thumbnail gets the icon alone', (tester) async {
      // The words overflowed a 56 px tile by about 80 px.
      await pump(tester, 'gone.jpg', size: 56);
      expect(tester.takeException(), isNull);
      expect(find.text('Photo unavailable'), findsNothing);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });

    testWidgets('a viewer gets the words', (tester) async {
      await pump(tester, 'gone.jpg', size: 200);
      expect(find.text('Photo unavailable'), findsOneWidget);
    });

    testWidgets('showLabel false keeps it quiet even where there is room',
        (tester) async {
      await pump(tester, 'gone.jpg', size: 200, showLabel: false);
      expect(find.text('Photo unavailable'), findsNothing);
      expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    });
  });

  group('a recycled tile', () {
    testWidgets('looks up the new photo, not the previous one', (tester) async {
      // A list tile is reused with a different reference rather than rebuilt
      // from scratch; without didUpdateWidget it would keep the old file.
      final asked = <String>[];

      Widget tile(String reference) => MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 200,
                child: PinPhotoImage(
                  reference: reference,
                  resolve: (r) async {
                    asked.add(r);
                    return null;
                  },
                ),
              ),
            ),
          );

      await tester.pumpWidget(tile('first.jpg'));
      await tester.pump();
      await tester.pumpWidget(tile('second.jpg'));
      await tester.pump();

      expect(asked, ['first.jpg', 'second.jpg']);
    });

    testWidgets('and does not re-resolve when nothing changed',
        (tester) async {
      // The resolve used to happen in build, so it fired again on every frame
      // — a photo in a scrolling list hitting the file system continuously.
      var calls = 0;

      Widget tile() => MaterialApp(
            home: Scaffold(
              body: SizedBox(
                width: 200,
                height: 200,
                child: PinPhotoImage(
                  reference: 'same.jpg',
                  resolve: (_) async {
                    calls++;
                    return null;
                  },
                ),
              ),
            ),
          );

      await tester.pumpWidget(tile());
      await tester.pump();
      await tester.pumpWidget(tile());
      await tester.pump();
      await tester.pumpWidget(tile());
      await tester.pump();

      expect(calls, 1);
    });
  });
}
