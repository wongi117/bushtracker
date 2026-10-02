import 'dart:math' as math;

import 'package:flutter/material.dart';

/// How far a bottom sheet must hold its content clear of the bottom edge.
///
/// There are two different measurements and handling only one of them is the
/// bug this exists to stop:
///
///  * `viewInsets.bottom` is the **keyboard**.
///  * `viewPadding.bottom` is the **system navigation bar**.
///
/// A sheet that pads for `viewInsets` alone looks correct in every screenshot
/// taken while typing and draws its buttons underneath the navigation bar the
/// rest of the time. That is how the zone-naming sheet shipped with an
/// unreachable SAVE button — and it is why grepping for "does this file
/// mention insets" is not an audit: the broken file mentioned them.
///
/// The two are combined with `max`, not `+`. While a keyboard is open its
/// inset is measured from the bottom of the screen and already covers the
/// navigation bar's strip, so adding them over-pads by the height of the bar
/// and leaves a visible gap under the buttons.
double sheetBottomInset(BuildContext context) {
  final media = MediaQuery.of(context);
  return math.max(media.viewInsets.bottom, media.viewPadding.bottom);
}

/// Content padding for a sheet, with the bottom worked out by
/// [sheetBottomInset].
EdgeInsets sheetPadding(
  BuildContext context, {
  double left = 18,
  double top = 10,
  double right = 18,
  double bottom = 18,
}) =>
    EdgeInsets.fromLTRB(
        left, top, right, bottom + sheetBottomInset(context));

/// A bottom sheet that keeps its content reachable.
///
/// Wraps the usual rounded panel, applies [sheetPadding], and scrolls when the
/// keyboard leaves too little room — so the buttons at the bottom of a form
/// stay pressable while someone is typing into it, which is exactly when they
/// are needed.
class SafeSheet extends StatelessWidget {
  const SafeSheet({
    super.key,
    required this.child,
    this.background = const Color(0xFF13162A),
    this.scrollable = true,
    this.maxHeightFraction = 0.9,
  });

  final Widget child;
  final Color background;

  /// Whether the content scrolls. On for anything with a text field.
  final bool scrollable;

  /// Stops a tall sheet growing past this much of the screen.
  final double maxHeightFraction;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);

    final panel = Container(
      decoration: BoxDecoration(
        color: background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      padding: sheetPadding(context),
      child: child,
    );

    if (!scrollable) return panel;

    return ConstrainedBox(
      constraints: BoxConstraints(
        // The keyboard's height comes off the available room, so a form that
        // would otherwise be taller than the screen scrolls instead of pushing
        // its own buttons off the bottom.
        maxHeight: (media.size.height - media.viewInsets.bottom) *
            maxHeightFraction,
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.zero,
        child: panel,
      ),
    );
  }
}

/// The drag handle every sheet in this app starts with.
class SheetGrip extends StatelessWidget {
  const SheetGrip({super.key});

  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      );
}
