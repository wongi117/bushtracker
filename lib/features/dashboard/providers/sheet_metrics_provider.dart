import 'package:flutter_riverpod/flutter_riverpod.dart';

/// How tall the collapsed bottom sheet is, not counting the system bar.
///
/// Shared so the map controls can sit above it instead of guessing. Every
/// right-hand control used a hardcoded `bottom:` chosen by eye, which is why
/// the compass ended up half under the sheet on a phone whose navigation bar is
/// a different height from the one it was eyeballed on.
const double kCollapsedSheetContentHeight = 120.0;

/// Clearance between the top of the sheet and the lowest control.
const double kSheetControlGap = 12.0;

/// The bottom sheet's current height in logical pixels.
///
/// Published by the sheet as it is dragged so the controls can move with it,
/// rather than being overlapped. Starts at the collapsed height because that is
/// what is on screen before anyone touches it.
final sheetHeightProvider =
    StateProvider<double>((ref) => kCollapsedSheetContentHeight);

/// Where the lowest right-hand map control should sit, given the sheet's
/// current height and the system navigation bar.
///
/// Based on measurements rather than constants so it is right on any handset:
/// a phone with gesture navigation has a ~24 px inset, three-button more like
/// 48, and a hardcoded offset is wrong on at least one of them.
double controlsBottom(double sheetHeight, double systemInset) =>
    sheetHeight + systemInset + kSheetControlGap;

/// Whether the map controls should get out of the way entirely.
///
/// Once the sheet is past about a third of the screen there is no room left to
/// stack controls above it, and sliding them up into the weather card and the
/// tracking panel is worse than hiding them. They come back as it closes.
bool hideControlsFor(double sheetHeight, double screenHeight) =>
    sheetHeight > screenHeight * 0.34;
