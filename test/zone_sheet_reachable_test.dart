// The reported bug: CANCEL and SAVE on the "NAME THIS ZONE" sheet were drawn
// behind the Android navigation bar, so a boundary could not be saved at all.
//
// Verified here rather than by asking again, because this is checkable: pump
// the sheet with a navigation bar present and assert the buttons are inside the
// usable area. What a test cannot prove is that a real finger on real hardware
// gets the tap — the system bar consumes touches in its own strip regardless of
// what is painted under it — so that one still needs eyes. What it does prove
// is that nothing is painted under it any more.
import 'package:bush_track/features/geofence/presentation/zone_drawing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// A 360x780 phone with a three-button navigation bar — the tallest common
  /// case, and the one the bug showed up on.
  const screen = Size(360, 780);
  const navBar = 48.0;

  /// Opens the sheet with real window metrics.
  ///
  /// Set on tester.view, not with a MediaQuery wrapper. showModalBottomSheet
  /// opens a new route, and that route takes its MediaQuery from the app — so a
  /// wrapper around the page underneath never reaches the sheet. The first
  /// version of this test did exactly that, and its assertions passed while the
  /// sheet saw no insets at all: SAVE sat at 568 on a 780 px screen, which is
  /// comfortably above a 48 px bar whether or not anything had been fixed.
  Future<void> openSheet(
    WidgetTester tester, {
    double bottomInset = navBar,
    double keyboard = 0,
  }) async {
    tester.view
      ..devicePixelRatio = 1.0
      ..physicalSize = screen
      ..viewPadding = FakeViewPadding(bottom: bottomInset)
      ..padding =
          FakeViewPadding(bottom: keyboard > 0 ? 0 : bottomInset)
      ..viewInsets = FakeViewPadding(bottom: keyboard);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () =>
                  showZoneDetailsSheet(context, summary: '200 m radius'),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ));

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group('the buttons are inside the usable area', () {
    testWidgets('SAVE is above the navigation bar', (tester) async {
      await openSheet(tester);

      final save = find.text('SAVE');
      expect(save, findsOneWidget, reason: 'the sheet should be open');

      // Scrolled to first, or the assertion passes on a SAVE that happens to
      // be sitting off the bottom of the scroll view and proves nothing. The
      // first version of this test did exactly that.
      await tester.ensureVisible(save);
      await tester.pumpAndSettle();

      final box = tester.getRect(save);
      expect(box.bottom, lessThanOrEqualTo(screen.height - navBar),
          reason: 'SAVE is ${screen.height - box.bottom} px from the bottom '
              'with a ${navBar}px bar — it is underneath it');
    });

    testWidgets('CANCEL is too', (tester) async {
      await openSheet(tester);
      await tester.ensureVisible(find.text('CANCEL'));
      await tester.pumpAndSettle();
      final box = tester.getRect(find.text('CANCEL'));
      expect(box.bottom, lessThanOrEqualTo(screen.height - navBar));
    });

    testWidgets('and on a gesture-nav phone, with its thinner inset',
        (tester) async {
      await openSheet(tester, bottomInset: 24);
      await tester.ensureVisible(find.text('SAVE'));
      await tester.pumpAndSettle();
      final box = tester.getRect(find.text('SAVE'));
      expect(box.bottom, lessThanOrEqualTo(screen.height - 24));
    });

    testWidgets('and on a phone with no bar at all', (tester) async {
      await openSheet(tester, bottomInset: 0);
      await tester.ensureVisible(find.text('SAVE'));
      await tester.pumpAndSettle();
      final box = tester.getRect(find.text('SAVE'));
      expect(box.bottom, lessThanOrEqualTo(screen.height));
    });
  });

  group('with the keyboard open', () {
    testWidgets('SAVE can be scrolled to, and lands above the keyboard',
        (tester) async {
      // Typing is exactly when the buttons are needed. "Reachable" means
      // scrollable into view and then visible — not that a long form fits on
      // screen all at once, which it cannot with a keyboard taking 300 px.
      await openSheet(tester, keyboard: 300);

      final save = find.text('SAVE');
      expect(save, findsOneWidget);

      await tester.ensureVisible(save);
      await tester.pumpAndSettle();

      final box = tester.getRect(save);
      expect(box.bottom, lessThanOrEqualTo(screen.height - 300),
          reason: 'after scrolling to it, SAVE is still behind the keyboard '
              'at ${box.bottom} on a ${screen.height} px screen');
    });

    testWidgets('the sheet does not overflow when the keyboard takes half the '
        'screen', (tester) async {
      await openSheet(tester, keyboard: 390);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull,
          reason: 'a RenderFlex overflow means the content was squeezed '
              'instead of scrolling');
    });
  });

  group('the sheet itself', () {
    testWidgets('offers the categories, so a colour can be chosen',
        (tester) async {
      await openSheet(tester);
      expect(find.text('NAME THIS ZONE'), findsOneWidget);
      expect(find.text('Heritage'), findsOneWidget);
    });

    testWidgets('does not run off the top of a short screen', (tester) async {
      await openSheet(tester);
      final sheet = tester.getRect(find.text('NAME THIS ZONE'));
      expect(sheet.top, greaterThanOrEqualTo(0));
    });
  });
}
