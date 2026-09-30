// Edit / Show on Map / Share / Delete shared one row, which on a 360 px phone
// left about 72 px a button while "Show on Map" needs over a hundred — so it ran
// into Share. Overflow is the kind of thing that is obvious in a screenshot and
// invisible in a review, so it gets a test at the width it broke at.
import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/features/map/widgets/pinage_viewer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // A data URI whose payload is valid base64, so Image.memory gets as far as
  // trying to decode it. These render as "Photo unavailable", which is the
  // right outcome for bytes that are not a JPEG and is not what is under test
  // here — the layout around them is.
  String jpeg(String payload) => 'data:image/jpeg;base64,$payload';

  Waypoint pin({List<String>? photos}) => Waypoint(
        id: 1,
        latitude: -28.8833,
        longitude: 121.3333,
        label: 'Old shaft',
        timestamp: DateTime.utc(2026, 3, 4, 8, 30),
        isPin: true,
        photoPaths: photos,
      );

  Future<void> pumpSheet(
    WidgetTester tester, {
    required Size size,
    bool withJumpToMap = true,
    List<String>? photos,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: PinageViewerSheet(
              waypoint: pin(photos: photos),
              onEdit: () {},
              onDelete: () {},
              onJumpToMap: withJumpToMap ? () {} : null,
              onTrack: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('the action buttons fit a small phone', () {
    testWidgets('no overflow at 360 px wide', (tester) async {
      await pumpSheet(tester, size: const Size(360, 780));
      // A RenderFlex overflow is reported as an exception by the framework.
      expect(tester.takeException(), isNull);
    });

    testWidgets('all four actions are present', (tester) async {
      await pumpSheet(tester, size: const Size(360, 780));
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Show on Map'), findsOneWidget);
      expect(find.text('Share'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('they are laid out two to a row, not four across',
        (tester) async {
      await pumpSheet(tester, size: const Size(360, 780));

      final edit = tester.getCenter(find.text('Edit'));
      final showOnMap = tester.getCenter(find.text('Show on Map'));
      final share = tester.getCenter(find.text('Share'));
      final delete = tester.getCenter(find.text('Delete'));

      // Row one and row two.
      expect(edit.dy, closeTo(showOnMap.dy, 1),
          reason: 'Edit and Show on Map should share a row');
      expect(share.dy, closeTo(delete.dy, 1),
          reason: 'Share and Delete should share a row');
      expect(share.dy, greaterThan(edit.dy + 20),
          reason: 'the second row must be below the first');
    });

    testWidgets('no label wraps to a second line', (tester) async {
      await pumpSheet(tester, size: const Size(360, 780));
      for (final label in ['Edit', 'Show on Map', 'Share', 'Delete']) {
        final widget = tester.widget<Text>(find.text(label));
        expect(widget.maxLines, 1, reason: '$label must stay on one line');
        expect(widget.softWrap, isFalse,
            reason: '$label must not break mid-word');
      }
    });

    testWidgets('each button gets enough room for its label', (tester) async {
      // Measured rather than asserted in prose. The widest label is "Show on
      // Map", about 88 px at 13 px bold in a proportional font, plus an 18 px
      // icon, a 7 px gap and 16 px of padding — call it 130. Anything at or
      // above that fits without shortening.
      //
      // Not checked by looking for an ellipsis: the test font gives every glyph
      // a square em box, so labels measure nearly twice their real width here
      // and would appear shortened no matter how much room they had.
      await pumpSheet(tester, size: const Size(360, 780));

      for (final label in ['Edit', 'Show on Map', 'Share', 'Delete']) {
        final button = find.ancestor(
          of: find.text(label),
          matching: find.byType(GestureDetector),
        );
        expect(tester.getSize(button.first).width, greaterThan(130),
            reason: '$label has too little room to render in full');
      }
    });

    testWidgets('narrower still, at 320 px, also does not overflow',
        (tester) async {
      await pumpSheet(tester, size: const Size(320, 700));
      expect(tester.takeException(), isNull);
    });
  });

  group('three buttons instead of four', () {
    testWidgets('the odd one out fills its row rather than half of it',
        (tester) async {
      // Show on Map is absent when the caller cannot jump the map, leaving
      // three: Edit and Share pair up, and Delete takes a row to itself.
      await pumpSheet(tester, size: const Size(360, 780), withJumpToMap: false);
      expect(tester.takeException(), isNull);
      expect(find.text('Show on Map'), findsNothing);

      final edit = tester.getCenter(find.text('Edit'));
      final share = tester.getCenter(find.text('Share'));
      final delete = tester.getCenter(find.text('Delete'));

      expect(share.dy, closeTo(edit.dy, 1),
          reason: 'Edit and Share should share the first row');
      expect(delete.dy, greaterThan(edit.dy + 20),
          reason: 'Delete should be on its own row below');

      // And it spans the row rather than sitting at half width beside a gap.
      final deleteButton = find
          .ancestor(
              of: find.text('Delete'), matching: find.byType(GestureDetector))
          .first;
      final editButton = find
          .ancestor(of: find.text('Edit'), matching: find.byType(GestureDetector))
          .first;
      expect(tester.getSize(deleteButton).width,
          greaterThan(tester.getSize(editButton).width * 1.8),
          reason: 'a lone button should fill its row');
    });
  });

  group('adding photos from inside the pin', () {
    testWidgets('a pin with no photos offers a big Add photo button',
        (tester) async {
      await pumpSheet(tester, size: const Size(360, 780));
      expect(find.text('Add photo'), findsOneWidget);
      expect(find.text('Camera or gallery'), findsOneWidget);
    });

    testWidgets('a pin with photos offers Add on the viewer', (tester) async {
      await pumpSheet(tester,
          size: const Size(360, 780), photos: [jpeg('AAAA')]);
      // The overlay button, mirroring the counter on the other side.
      expect(find.text('Add'), findsOneWidget);
      expect(find.text('Add photo'), findsNothing);
    });

    testWidgets('the thumbnail strip appears from the very first photo',
        (tester) async {
      // It used to appear only from the second, which would have left the +
      // tile out of reach on a pin with exactly one photo.
      await pumpSheet(tester,
          size: const Size(360, 780), photos: [jpeg('AAAA')]);
      expect(find.byIcon(Icons.add), findsOneWidget);
      expect(find.text('Long-press a photo to remove it'), findsOneWidget);
    });

    testWidgets('the counter reflects the number of photos', (tester) async {
      await pumpSheet(tester,
          size: const Size(360, 780),
          photos: [jpeg('AAAA'), jpeg('BBBB'), jpeg('CCCC')]);
      expect(find.text('1 / 3'), findsOneWidget);
      expect(find.text('3 photos'), findsOneWidget);
    });

    testWidgets('one photo is not pluralised', (tester) async {
      await pumpSheet(tester,
          size: const Size(360, 780), photos: [jpeg('AAAA')]);
      expect(find.text('1 photo'), findsOneWidget);
    });

    testWidgets('picking a source does not overflow the sheet',
        (tester) async {
      await pumpSheet(tester, size: const Size(360, 780));
      await tester.tap(find.text('Add photo'));
      await tester.pumpAndSettle();

      expect(find.text('Take photos'), findsOneWidget);
      expect(find.text('Choose from gallery'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('long-pressing a thumbnail asks before removing it',
        (tester) async {
      await pumpSheet(tester,
          size: const Size(360, 780), photos: [jpeg('AAAA'), jpeg('BBBB')]);

      await tester.longPress(find.byKey(const ValueKey('pin-thumb-0')));
      await tester.pumpAndSettle();

      expect(find.text('Remove this photo?'), findsOneWidget);
      expect(find.text('REMOVE'), findsOneWidget);
      expect(find.text('CANCEL'), findsOneWidget);
    });

    testWidgets('cancelling the removal keeps the photo', (tester) async {
      await pumpSheet(tester,
          size: const Size(360, 780), photos: [jpeg('AAAA'), jpeg('BBBB')]);

      await tester.longPress(find.byKey(const ValueKey('pin-thumb-0')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CANCEL'));
      await tester.pumpAndSettle();

      expect(find.text('2 photos'), findsOneWidget);
    });
  });

  group('the primary button keeps its place', () {
    testWidgets('TRACK TO THIS PIN is full width above the grid',
        (tester) async {
      await pumpSheet(tester, size: const Size(360, 780));
      final track = find.text('TRACK TO THIS PIN');
      expect(track, findsOneWidget);
      expect(tester.getCenter(track).dy,
          lessThan(tester.getCenter(find.text('Edit')).dy),
          reason: 'it is the primary action and belongs above the rest');
    });
  });
}
