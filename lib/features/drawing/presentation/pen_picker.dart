import 'package:flutter/material.dart';

import 'package:bush_track/core/models/waypoint.dart';
import 'package:bush_track/theme/app_colors.dart';

/// Pen colours: picked to stand out on satellite imagery and on the topo map.
const penColours = ['#FF6B00', '#FF1744', '#FFEA00', '#00E5FF', '#FFFFFF'];

/// Thin, medium, thick, in logical pixels.
const penWidths = [2.0, 4.0, 7.0];

/// Colour swatches and line widths, shared by the line tool, freehand, and
/// the sheet that recolours a saved drawing -- one picker, so the three
/// cannot drift into offering different pens.
class PenPicker extends StatelessWidget {
  final String colour;
  final double width;
  final ValueChanged<String> onColour;
  final ValueChanged<double> onWidth;

  const PenPicker({
    super.key,
    required this.colour,
    required this.width,
    required this.onColour,
    required this.onWidth,
  });

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (final c in penColours)
        GestureDetector(
          key: ValueKey('pen-colour-$c'),
          onTap: () => onColour(c),
          child: Container(
            width: 28,
            height: 28,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: WaypointColors.fromHex(c),
              shape: BoxShape.circle,
              border: Border.all(
                color: colour == c ? Colors.white : Colors.white24,
                width: colour == c ? 3 : 1,
              ),
            ),
          ),
        ),
      const Spacer(),
      for (final w in penWidths)
        GestureDetector(
          key: ValueKey('pen-width-${w.round()}'),
          onTap: () => onWidth(w),
          child: Container(
            width: 34,
            height: 28,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: width == w ? AppColors.primaryOrange : Colors.transparent,
              ),
            ),
            child: Container(width: 20, height: w, color: Colors.white),
          ),
        ),
    ]);
  }
}
