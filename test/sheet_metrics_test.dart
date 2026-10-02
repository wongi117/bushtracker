// Every right-hand map control used a hardcoded `bottom:` chosen by eye on one
// handset. That is why the compass came out half under the collapsed sheet on
// an A57: its navigation bar is a different height from the one the numbers
// were eyeballed against. These pin the positions to measurements instead.
import 'package:bush_track/features/dashboard/providers/sheet_metrics_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // Three real handset shapes.
  const gestureNav = 24.0; // a thin gesture pill
  const threeButton = 48.0; // the taller classic bar
  const noBar = 0.0; // older phones, and most emulators

  group('controls clear the collapsed sheet', () {
    test('on every navigation style', () {
      for (final inset in [noBar, gestureNav, threeButton]) {
        final bottom = controlsBottom(kCollapsedSheetContentHeight, inset);
        expect(bottom, greaterThan(kCollapsedSheetContentHeight + inset),
            reason: 'with a $inset px bar the control is still touching it');
      }
    });

    test('a taller navigation bar pushes them further up', () {
      expect(controlsBottom(kCollapsedSheetContentHeight, threeButton),
          greaterThan(controlsBottom(kCollapsedSheetContentHeight, gestureNav)));
    });

    test('there is a visible gap, not a hairline', () {
      final bottom = controlsBottom(kCollapsedSheetContentHeight, gestureNav);
      expect(bottom - (kCollapsedSheetContentHeight + gestureNav),
          greaterThanOrEqualTo(8));
    });

    test('the old hardcoded 150 was under the sheet on a three-button phone',
        () {
      // The bug, as a number: the compass sat at bottom 150, and a collapsed
      // sheet on this phone occupies 120 + 48 = 168.
      expect(kCollapsedSheetContentHeight + threeButton, greaterThan(150),
          reason: 'which is exactly why the compass was cut off');
    });
  });

  group('controls move as the sheet is dragged', () {
    test('dragging the sheet up lifts them with it', () {
      final low = controlsBottom(kCollapsedSheetContentHeight, gestureNav);
      final high = controlsBottom(300, gestureNav);
      expect(high, greaterThan(low));
    });

    test('they never sit underneath, at any sheet height', () {
      for (final height in [120.0, 200.0, 320.0, 500.0]) {
        expect(controlsBottom(height, gestureNav), greaterThan(height),
            reason: 'at $height the control overlaps the sheet');
      }
    });
  });

  group('and get out of the way when there is no room', () {
    test('they stay while the sheet is collapsed', () {
      // A 2340 px phone, as the A57 is.
      expect(hideControlsFor(kCollapsedSheetContentHeight, 2340), isFalse);
    });

    test('they hide once the sheet takes a third of the screen', () {
      // Stacking a compass and a locate button above a half-open sheet would
      // push them into the weather card and the tracking panel, which is worse
      // than hiding them.
      expect(hideControlsFor(2340 * 0.5, 2340), isTrue);
    });

    test('and come back as it closes', () {
      expect(hideControlsFor(2340 * 0.5, 2340), isTrue);
      expect(hideControlsFor(kCollapsedSheetContentHeight, 2340), isFalse);
    });

    test('a short screen hides them sooner, in proportion', () {
      // A 1280 px phone has less room to stack things in, so the threshold
      // moves with the screen rather than being a fixed pixel count.
      expect(hideControlsFor(500, 1280), isTrue);
      expect(hideControlsFor(500, 2340), isFalse);
    });
  });

  group('the stack fits a small screen', () {
    test('attribution, compass and locate all fit above a collapsed sheet',
        () {
      // 360x640 is about the smallest Android still in use.
      const screen = 640.0;
      const attributionHeight = 16.0;
      const compassSize = 60.0;
      const locateSize = 52.0;

      final base = controlsBottom(kCollapsedSheetContentHeight, threeButton);
      final topOfStack =
          base + attributionHeight + 6 + compassSize + 8 + locateSize;

      expect(topOfStack, lessThan(screen),
          reason: 'the stack is $topOfStack tall on a $screen px screen, so '
              'the locate button would be off the top');
    });
  });
}
