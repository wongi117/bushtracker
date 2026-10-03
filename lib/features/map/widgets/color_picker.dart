import 'package:flutter/material.dart';
import '../../../core/models/waypoint.dart';
import '../../../core/models/trail.dart';

/// Horizontal scrolling color picker for trails and waypoints
class ColorPicker extends StatelessWidget {
  final String? selectedColor;
  final ValueChanged<String> onColorSelected;
  final double circleSize;
  final bool showNames;

  const ColorPicker({
    super.key,
    this.selectedColor,
    required this.onColorSelected,
    this.circleSize = 36,
    this.showNames = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors = TrailColors.allColors;
    final names = TrailColors.colorNames;
    
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (int i = 0; i < colors.length; i++) ...[
            GestureDetector(
              onTap: () => onColorSelected(colors[i]),
              child: Container(
                margin: EdgeInsets.only(
                  left: i == 0 ? 0 : 8,
                  right: i == colors.length - 1 ? 0 : 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: circleSize,
                      height: circleSize,
                      decoration: BoxDecoration(
                        color: WaypointColors.fromHex(colors[i]),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selectedColor == colors[i]
                              ? Colors.white
                              : Colors.transparent,
                          width: 3,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: WaypointColors.fromHex(colors[i])
                                .withValues(alpha: 0.4),
                            blurRadius: 8,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: selectedColor == colors[i]
                          ? const Icon(
                              Icons.check,
                              color: Colors.white,
                              size: 20,
                            )
                          : null,
                    ),
                    if (showNames) ...[
                      const SizedBox(height: 4),
                      Text(
                        names[i],
                        style: TextStyle(
                          color: selectedColor == colors[i]
                              ? Colors.white
                              : Colors.white70,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact color picker for small spaces
class CompactColorPicker extends StatelessWidget {
  final String? selectedColor;
  final ValueChanged<String> onColorSelected;

  /// Which palette to offer. Defaults to the trail colours this was written
  /// for; projects pass the pin palette, so a project and the pins filed under
  /// it can be given the same colour and read as one thing.
  final List<String>? palette;

  /// Adds a "no colour" swatch that calls [onCleared].
  ///
  /// Needed wherever the colour is optional: without it there is no way back
  /// to the default once a colour has been picked, which is a one-way door.
  final bool allowNone;
  final VoidCallback? onCleared;

  const CompactColorPicker({
    super.key,
    this.selectedColor,
    required this.onColorSelected,
    this.palette,
    this.allowNone = false,
    this.onCleared,
  });

  @override
  Widget build(BuildContext context) {
    final colors = palette ?? TrailColors.allColors;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (allowNone)
            GestureDetector(
              onTap: onCleared,
              child: Container(
                margin: const EdgeInsets.only(right: 6),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selectedColor == null
                        ? Colors.white
                        : Colors.white.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
                child: Icon(Icons.close_rounded,
                    size: 13, color: Colors.white.withValues(alpha: 0.7)),
              ),
            ),
          for (int i = 0; i < colors.length; i++) ...[
            GestureDetector(
              onTap: () => onColorSelected(colors[i]),
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: EdgeInsets.only(
                  left: i == 0 ? 0 : 6,
                  right: i == colors.length - 1 ? 0 : 6,
                ),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: WaypointColors.fromHex(colors[i]),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selectedColor == colors[i]
                        ? Colors.white
                        : Colors.transparent,
                    width: 2,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
